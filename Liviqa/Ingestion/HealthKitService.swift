// HealthKitService.swift — L1 real on-device ingestion (iOS, HealthKit).
//
// READ-ONLY by design (FR-ARCH-04): the share/write set is **empty** and there
// is no method that writes back to HealthKit. Reads the MVP set (FR-ING-01) and
// returns the framework-free `HealthSamples` aggregate. Blood glucose is read
// directly in canonical mmol/L (OD-07). All readings are provenance = .real.
//
// Wrapped in `#if canImport(HealthKit)` so the module still compiles on
// platforms/toolchains without the SDK (the factory falls back to Mock there).
import Foundation

#if canImport(HealthKit)
import HealthKit

public struct HealthKitService: HealthDataProvider {
    public let kind: DataProviderKind = .healthKit
    let store = HKHealthStore()

    /// Encrypted, device-local persistence for HKQueryAnchors (FR-ING-03/04).
    /// Built from the device DEK + a device-local user scope (never a server id).
    let anchors: EncryptedAnchorStore?
    /// Retains live observer queries so background delivery can be torn down.
    let registry = ObserverRegistry()

    public init(anchors: EncryptedAnchorStore? = nil) {
        self.anchors = anchors
            ?? (try? EncryptedAnchorStore(keyVault: .shared, userScope: LocalUserScope.current()))
    }

    // MARK: Authorization scopes

    /// READ set — full HealthKit capture. Original MVP set (FR-ING-01) plus the
    /// extended panel (insulin, BP, AFib, body-comp, heart/respiratory). Any
    /// identifier the running OS doesn't know resolves to nil and is skipped, so
    /// this stays compile- and runtime-safe across SDK versions. Read-only.
    static var readTypes: Set<HKObjectType> {
        var t: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantityIds: [HKQuantityTypeIdentifier] = [
            // MVP set
            .heartRateVariabilitySDNN, .restingHeartRate, .stepCount,
            .activeEnergyBurned, .bloodGlucose,
            // Heart / respiratory panel
            .heartRate, .walkingHeartRateAverage, .heartRateRecoveryOneMinute,
            .respiratoryRate, .oxygenSaturation, .vo2Max,
            // Cardiometabolic + body
            .insulinDelivery, .atrialFibrillationBurden,
            .bloodPressureSystolic, .bloodPressureDiastolic,
            .bodyMass, .bodyFatPercentage, .leanBodyMass, .bodyMassIndex,
        ]
        for id in quantityIds {
            if let type = HKObjectType.quantityType(forIdentifier: id) { t.insert(type) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { t.insert(sleep) }
        return t
    }

    /// SHARE/WRITE set — intentionally EMPTY. Never write to HealthKit. (FR-ARCH-04)
    static let shareTypes: Set<HKSampleType> = []

    // MARK: HealthDataProvider

    public func requestReadAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }
        try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
    }

    public func fetchSamples(from start: Date, to end: Date) async throws -> HealthSamples {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        async let glucose = readGlucose(start, end)
        async let hrv = readDaily(.heartRateVariabilitySDNN, .hrvSDNN, unit: .secondUnit(with: .milli), start, end, tier: .good, cumulative: false)
        async let rhr = readDaily(.restingHeartRate, .restingHR, unit: bpm, start, end, tier: .good, cumulative: false)
        async let steps = readDaily(.stepCount, .steps, unit: .count(), start, end, tier: .estimate, cumulative: true)
        async let energy = readDaily(.activeEnergyBurned, .activeEnergy, unit: .kilocalorie(), start, end, tier: .estimate, cumulative: true)
        async let sleep = readSleep(start, end)
        async let workouts = readWorkouts(start, end)

        // Full-HealthKit capture — extended heart/respiratory panel + cardiometabolic.
        async let heartRate  = readDaily(.heartRate, .heartRate, unit: bpm, start, end, tier: .good, cumulative: false)
        async let walkingHR  = readDaily(.walkingHeartRateAverage, .walkingHR, unit: bpm, start, end, tier: .good, cumulative: false)
        async let hrRecovery = readDaily(.heartRateRecoveryOneMinute, .hrRecovery, unit: bpm, start, end, tier: .good, cumulative: false)
        async let respRate   = readDaily(.respiratoryRate, .respiratoryRate, unit: bpm, start, end, tier: .good, cumulative: false)
        async let spo2       = readSpO2(start, end)
        async let vo2        = readVO2Max(start, end)
        async let insulin    = readInsulin(start, end)
        async let bp         = readBloodPressure(start, end)
        async let afib       = readAFib(start, end)
        async let body       = readBodyComposition(start, end)

        let heartExtras = try await heartRate + walkingHR + hrRecovery + respRate + spo2 + vo2

        return try await HealthSamples(
            glucose: glucose, hrv: hrv, restingHR: rhr, steps: steps,
            activeEnergy: energy, sleep: sleep, workouts: workouts,
            heartExtras: heartExtras, insulin: insulin, bloodPressure: bp,
            afib: afib, bodyComposition: body)
    }

    // MARK: Readers

    private func readGlucose(_ start: Date, _ end: Date) async throws -> [GlucoseReading] {
        guard let type = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return [] }
        // Canonical mmol/L (OD-07): mmol per litre.
        let mmolUnit = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose)
            .unitDivided(by: .liter())
        let samples = try await quantitySamples(type, start, end)
        return samples.map { s in
            GlucoseReading(
                ts: s.startDate,
                mmol: (s.quantity.doubleValue(for: mmolUnit) * 10).rounded() / 10,
                mealContext: nil,
                source: s.sourceRevision.source.name,
                tier: .good, provenance: .real)
        }
    }

    private func readDaily(_ id: HKQuantityTypeIdentifier, _ kind: DailyMetricKind,
                           unit: HKUnit, _ start: Date, _ end: Date,
                           tier: DataTier, cumulative: Bool) async throws -> [DailyMetric] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        let samples = try await quantitySamples(type, start, end)
        let cal = Calendar(identifier: .gregorian)
        var byDay: [Date: (sum: Double, count: Int, source: String)] = [:]
        for s in samples {
            let day = cal.startOfDay(for: s.startDate)
            let v = s.quantity.doubleValue(for: unit)
            let cur = byDay[day] ?? (0, 0, s.sourceRevision.source.name)
            byDay[day] = (cur.sum + v, cur.count + 1, cur.source)
        }
        return byDay.map { day, agg in
            let value = cumulative ? agg.sum : (agg.count > 0 ? agg.sum / Double(agg.count) : 0)
            return DailyMetric(date: day, kind: kind, value: value,
                               source: agg.source, tier: tier, provenance: .real)
        }.sorted { $0.date < $1.date }
    }

    private func readSleep(_ start: Date, _ end: Date) async throws -> [SleepReading] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let samples = try await categorySamples(type, start, end)
        let cal = Calendar(identifier: .gregorian)
        return samples.compactMap { s -> SleepReading? in
            let stage = Self.mapSleepStage(s.value)
            guard stage != .inBed, stage != .awake else { return nil }
            let hours = s.endDate.timeIntervalSince(s.startDate) / 3600
            return SleepReading(date: cal.startOfDay(for: s.startDate), stage: stage,
                                hours: (hours * 10).rounded() / 10,
                                source: s.sourceRevision.source.name,
                                tier: .estimate, provenance: .real)
        }
    }

    private func readWorkouts(_ start: Date, _ end: Date) async throws -> [WorkoutReading] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let samples = try await sampleQuery(HKObjectType.workoutType(), predicate)
        return samples.compactMap { $0 as? HKWorkout }.map { w in
            WorkoutReading(
                start: w.startDate, end: w.endDate,
                type: w.workoutActivityType.liviqaName,
                durMin: (w.duration / 60 * 10).rounded() / 10,
                kcal: w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?.doubleValue(for: .kilocalorie()),
                distKm: w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                    .sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)),
                source: w.sourceRevision.source.name,
                tier: .estimate, provenance: .real)
        }
    }

    // MARK: Extended readers (full HealthKit capture)

    /// SpO₂ daily mean. HealthKit stores oxygen saturation as a fraction; ×100 → %.
    private func readSpO2(_ start: Date, _ end: Date) async throws -> [DailyMetric] {
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return [] }
        return dailyMean(try await quantitySamples(type, start, end), kind: .spo2,
                         unit: .percent(), scale: 100)
    }

    /// VO₂max daily mean. Unit string "ml/kg*min" — verify against the SDK.
    private func readVO2Max(_ start: Date, _ end: Date) async throws -> [DailyMetric] {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return [] }
        return dailyMean(try await quantitySamples(type, start, end), kind: .vo2max,
                         unit: HKUnit(from: "ml/kg*min"), scale: 1)
    }

    /// Insulin delivery events. FR-REG-04: data-layer only (never a dose surface).
    /// Metadata reason: 1 = basal, 2 = bolus (HKInsulinDeliveryReason).
    private func readInsulin(_ start: Date, _ end: Date) async throws -> [InsulinReading] {
        guard let type = HKObjectType.quantityType(forIdentifier: .insulinDelivery) else { return [] }
        let samples = try await quantitySamples(type, start, end)
        return samples.map { s in
            let reason = (s.metadata?[HKMetadataKeyInsulinDeliveryReason] as? NSNumber)?.intValue
            let kind: InsulinKind = (reason == 1) ? .basal : .bolus
            return InsulinReading(ts: s.startDate, kind: kind,
                                  units: s.quantity.doubleValue(for: .internationalUnit()),
                                  source: s.sourceRevision.source.name,
                                  tier: .good, provenance: .real)
        }
    }

    /// Blood pressure via the systolic+diastolic correlation (paired reliably).
    private func readBloodPressure(_ start: Date, _ end: Date) async throws -> [BloodPressureReading] {
        guard let bpType = HKObjectType.correlationType(forIdentifier: .bloodPressure),
              let sysType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diaType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let raw = try await sampleQuery(bpType, predicate)
        let mmHg = HKUnit.millimeterOfMercury()
        return raw.compactMap { $0 as? HKCorrelation }.compactMap { corr -> BloodPressureReading? in
            guard let sys = corr.objects(for: sysType).first as? HKQuantitySample,
                  let dia = corr.objects(for: diaType).first as? HKQuantitySample else { return nil }
            return BloodPressureReading(
                ts: corr.startDate,
                sys: Int(sys.quantity.doubleValue(for: mmHg).rounded()),
                dia: Int(dia.quantity.doubleValue(for: mmHg).rounded()),
                source: corr.sourceRevision.source.name, tier: .good, provenance: .real)
        }
    }

    /// AFib burden %. OD-11: display-only — captured as the watch's own number.
    private func readAFib(_ start: Date, _ end: Date) async throws -> [AFibReading] {
        guard let type = HKObjectType.quantityType(forIdentifier: .atrialFibrillationBurden) else { return [] }
        let samples = try await quantitySamples(type, start, end)
        return samples.map { s in
            AFibReading(ts: s.startDate,
                        pct: s.quantity.doubleValue(for: .percent()) * 100,   // fraction → %
                        source: s.sourceRevision.source.name, tier: .good, provenance: .real)
        }
    }

    /// Body composition: weight / fat% / lean / BMI merged into one row per day.
    private func readBodyComposition(_ start: Date, _ end: Date) async throws -> [BodyCompositionReading] {
        let cal = Calendar(identifier: .gregorian)
        func perDay(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) async throws -> [(Date, Double, String)] {
            guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
            return try await quantitySamples(type, start, end).map {
                (cal.startOfDay(for: $0.startDate), $0.quantity.doubleValue(for: unit), $0.sourceRevision.source.name)
            }
        }
        var weight: [Date: (Double, String)] = [:], fat: [Date: Double] = [:]
        var lean: [Date: Double] = [:], bmi: [Date: Double] = [:]
        for (d, v, s) in try await perDay(.bodyMass, .gramUnit(with: .kilo)) { weight[d] = (v, s) }
        for (d, v, _) in try await perDay(.bodyFatPercentage, .percent()) { fat[d] = v * 100 }   // fraction → %
        for (d, v, _) in try await perDay(.leanBodyMass, .gramUnit(with: .kilo)) { lean[d] = v }
        for (d, v, _) in try await perDay(.bodyMassIndex, .count()) { bmi[d] = v }
        let days = Set(weight.keys).union(fat.keys).union(lean.keys).union(bmi.keys)
        return days.map { d in
            BodyCompositionReading(ts: d, weightKg: weight[d]?.0, fatPct: fat[d],
                                   leanKg: lean[d], bmi: bmi[d],
                                   source: weight[d]?.1 ?? "HealthKit",
                                   tier: .good, provenance: .real)
        }.sorted { $0.ts < $1.ts }
    }

    /// Daily mean of quantity samples → DailyMetric (used by SpO₂ / VO₂max).
    private func dailyMean(_ samples: [HKQuantitySample], kind: DailyMetricKind,
                           unit: HKUnit, scale: Double) -> [DailyMetric] {
        let cal = Calendar(identifier: .gregorian)
        var byDay: [Date: (sum: Double, n: Int, src: String)] = [:]
        for s in samples {
            let day = cal.startOfDay(for: s.startDate)
            let v = s.quantity.doubleValue(for: unit) * scale
            let cur = byDay[day] ?? (0, 0, s.sourceRevision.source.name)
            byDay[day] = (cur.sum + v, cur.n + 1, cur.src)
        }
        return byDay.map { day, a in
            DailyMetric(date: day, kind: kind, value: a.n > 0 ? a.sum / Double(a.n) : 0,
                        source: a.src, tier: .good, provenance: .real)
        }.sorted { $0.date < $1.date }
    }

    // MARK: Query wrappers (async over HKSampleQuery)

    private func quantitySamples(_ type: HKQuantityType, _ start: Date, _ end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let raw = try await sampleQuery(type, predicate)
        return raw.compactMap { $0 as? HKQuantitySample }
    }

    private func categorySamples(_ type: HKCategoryType, _ start: Date, _ end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let raw = try await sampleQuery(type, predicate)
        return raw.compactMap { $0 as? HKCategorySample }
    }

    private func sampleQuery(_ type: HKSampleType, _ predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { cont in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, results, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: results ?? []) }
            }
            store.execute(q)
        }
    }

    static func mapSleepStage(_ value: Int) -> SleepStage {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed: return .inBed
        case .awake: return .awake
        case .asleepREM: return .rem
        case .asleepCore: return .core
        case .asleepDeep: return .deep
        default: return .asleepUnspecified
        }
    }
}

private extension HKWorkoutActivityType {
    var liviqaName: String {
        switch self {
        case .cycling: return "Cycling"
        case .running: return "Running"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        default: return "Workout"
        }
    }
}
#endif
