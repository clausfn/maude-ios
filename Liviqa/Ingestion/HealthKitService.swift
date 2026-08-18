// HealthKitService.swift — L1 real on-device ingestion (iOS, HealthKit).
//
// READ-ONLY by design (FR-ARCH-04): the share/write set is **empty** and there
// is no method that writes back to HealthKit. Reads the MVP set (FR-ING-01) and
// returns the framework-free `HealthSamples` aggregate. Blood glucose is read
// directly in canonical mmol/L (OD-07). All readings are provenance = .real.
//
// v03 · 2026-08-13 — two gaps closed so designed screens stop being demo-only:
//   • workout heart-rate in-interval (T-FIT-01) → per-workout average HR and
//     Z1–Z4 time-in-zone, both framed against the citizen's OWN observed max.
//   • sleep segment START times + the AWAKE stage, and night bucketing by the
//     day a night ends on → the depth chart, the wake-up moment and bedtime
//     consistency all render from real data when it exists.
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
            // Sleep-context (coverage audit 2026-08-18, FR-ING-16): the watch's
            // nightly sleeping wrist temperature.
            .appleSleepingWristTemperature,
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
        async let wristTemp  = readWristTemperature(start, end)

        let heartExtras = try await heartRate + walkingHR + hrRecovery + respRate + spo2 + vo2

        // T-FIT-01 — beats INSIDE each recent workout interval. Depends on the
        // workout list, so it runs after that await rather than in parallel.
        let sessions = try await workouts
        let workoutHR = try await readWorkoutHeartRate(sessions, windowEnd: end)

        let sleepRead = try await sleep
        return try await HealthSamples(
            glucose: glucose, hrv: hrv, restingHR: rhr, steps: steps,
            activeEnergy: energy, sleep: sleepRead.sleep,
            sleepInBed: sleepRead.inBed, workouts: sessions,
            heartExtras: heartExtras, workoutHeartRate: workoutHR,
            insulin: insulin, bloodPressure: bp,
            afib: afib, bodyComposition: body,
            wristTemperature: wristTemp)
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

    /// Daily figure per kind. The sample→day rule lives in the pure
    /// `DailyRollup` (coverage audit 2026-08-18): CUMULATIVE kinds take the
    /// best-covering single source's total per day — a raw sample query
    /// returns EVERY source's samples, and summing iPhone + Watch step samples
    /// together double-counted the day. MEAN kinds average, as before.
    private func readDaily(_ id: HKQuantityTypeIdentifier, _ kind: DailyMetricKind,
                           unit: HKUnit, _ start: Date, _ end: Date,
                           tier: DataTier, cumulative: Bool) async throws -> [DailyMetric] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        let samples = try await quantitySamples(type, start, end)
        let cal = Calendar(identifier: .gregorian)
        let rows = samples.map {
            DailyRollup.Row(day: cal.startOfDay(for: $0.startDate),
                            value: $0.quantity.doubleValue(for: unit),
                            source: $0.sourceRevision.source.name)
        }
        return DailyRollup.rollUp(rows, cumulative: cumulative).map {
            DailyMetric(date: $0.day, kind: kind, value: $0.value,
                        source: $0.source, tier: tier, provenance: .real)
        }
    }

    /// Sleep segments WITH their intra-night wall-clock times.
    ///
    /// Two deliberate properties, both required by the Sleep detail screen and
    /// both safe for every other consumer (each one filters by stage):
    ///
    /// • `start` carries the segment's real start, so a night recorded as many
    ///   short segments unions correctly (previously every segment of a night
    ///   shared the same start-of-day instant, which made the union collapse to
    ///   the longest segment instead of the night).
    /// • `date` is the NIGHT bucket (`nightDay`), not the calendar day of the
    ///   segment's start — otherwise a 23:04→06:14 night is split at midnight
    ///   into two half-nights on two different days.
    ///
    /// AWAKE is retained (it is part of the night's anatomy: the wake-up moment
    /// and the AWAKE total). Every asleep-total path filters on the asleep stage
    /// set, so awake segments can never inflate a sleep duration. IN-BED is
    /// retained too (sleep visualisation wave 2026-08) — but as `InBedSpan`, a
    /// SEPARATE stream by type, so it can never be summed into an asleep total:
    /// time-in-bed derives from it, nothing else does.
    struct SleepRead: Sendable {
        var sleep: [SleepReading] = []
        var inBed: [InBedSpan] = []
    }

    private func readSleep(_ start: Date, _ end: Date) async throws -> SleepRead {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return SleepRead() }
        let samples = try await categorySamples(type, start, end)
        var out = SleepRead()
        for s in samples {
            let stage = Self.mapSleepStage(s.value)
            let hours = s.endDate.timeIntervalSince(s.startDate) / 3600
            guard hours > 0 else { continue }
            if stage == .inBed {
                out.inBed.append(InBedSpan(date: Self.nightDay(s.startDate),
                                           start: s.startDate,
                                           hours: (hours * 100).rounded() / 100,
                                           source: s.sourceRevision.source.name,
                                           tier: .estimate, provenance: .real))
            } else {
                out.sleep.append(SleepReading(date: Self.nightDay(s.startDate), stage: stage,
                                              hours: (hours * 100).rounded() / 100,
                                              start: s.startDate,
                                              source: s.sourceRevision.source.name,
                                              tier: .estimate, provenance: .real))
            }
        }
        return out
    }

    /// The night a sleep segment belongs to: the day it ENDS on. Anything from
    /// 18:00 onwards counts towards the next morning, which is how a person
    /// reads "last night" — and how Apple's own Sleep app labels a night.
    /// Canonical rule lives in the portable `SleepNightRule` (sleep incident
    /// 2026-08) so derivation and diagnostics share ONE definition.
    static func nightDay(_ instant: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        SleepNightRule.nightDay(instant, calendar: calendar)
    }

    /// FR-DIAG-01 — the RAW sleep rows for the on-device diagnostics report:
    /// every `sleepAnalysis` sample in the window with its source bundle id and
    /// device name, NOTHING filtered — in-bed and zero-length rows are returned
    /// too and marked, so the report can show exactly what ingestion dropped.
    /// Timing data only (no other health types touched); read-only; the result
    /// is written to a text file the citizen shares themselves (no egress).
    public func readSleepDiagnostics(from start: Date, to end: Date) async throws -> [SleepRawSegment] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        return try await categorySamples(type, start, end).map { s in
            SleepRawSegment(
                sourceName: s.sourceRevision.source.name,
                bundleId: s.sourceRevision.source.bundleIdentifier,
                device: s.device?.name,
                stage: Self.mapSleepStage(s.value),
                start: s.startDate,
                end: s.endDate)
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

    /// How far back workout heart-rate is read. The Fitness screen only ever
    /// looks at four week-buckets of load and this week's zone card, so beats
    /// older than this can't change a single figure — and the bound keeps a
    /// 90-day first-run backfill from pulling tens of thousands of samples.
    static let hrWindowDays = 28

    /// T-FIT-01 — the beats inside each recent workout interval.
    ///
    /// One OR-compound predicate over the sessions' intervals (not one query
    /// per workout, and not a blanket 90-day heart-rate read). Samples that
    /// merely overlap an interval edge are excluded (`.strictStartDate` +
    /// `.strictEndDate`), so a beat is only ever attributed to a session it
    /// actually falls inside.
    private func readWorkoutHeartRate(_ workouts: [WorkoutReading],
                                      windowEnd: Date) async throws -> [HeartRateSample] {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }
        let cutoff = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -Self.hrWindowDays, to: windowEnd) ?? windowEnd
        let recent = workouts.filter { $0.end >= cutoff && $0.end > $0.start }
        guard !recent.isEmpty else { return [] }

        let intervals = recent.map {
            HKQuery.predicateForSamples(withStart: $0.start, end: $0.end,
                                        options: [.strictStartDate, .strictEndDate])
        }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: intervals)
        let raw = try await sampleQuery(type, predicate)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return raw.compactMap { $0 as? HKQuantitySample }.map { s in
            HeartRateSample(ts: s.startDate,
                            bpm: s.quantity.doubleValue(for: bpm),
                            source: s.sourceRevision.source.name,
                            tier: .good, provenance: .real)
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

    /// Nightly sleeping wrist temperature (°C) — FR-ING-16, coverage audit
    /// 2026-08-18. The watch writes one figure per night; samples are bucketed
    /// by the NIGHT they belong to (`nightDay`, the same rule sleep uses), so a
    /// night that starts at 23:30 lands on the morning it describes, and the
    /// day axis holds. Multiple samples/sources within one night average; the
    /// §2.3 tier arbitration then applies per night in `arbitrated()`.
    private func readWristTemperature(_ start: Date, _ end: Date) async throws -> [WristTemperatureReading] {
        guard let type = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) else { return [] }
        let samples = try await quantitySamples(type, start, end)
        var byNight: [Date: (sum: Double, n: Int, src: String)] = [:]
        for s in samples {
            let night = Self.nightDay(s.startDate)
            let v = s.quantity.doubleValue(for: .degreeCelsius())
            let cur = byNight[night] ?? (0, 0, s.sourceRevision.source.name)
            byNight[night] = (cur.sum + v, cur.n + 1, cur.src)
        }
        return byNight.map { night, a in
            WristTemperatureReading(date: night,
                                    celsius: ((a.sum / Double(a.n)) * 100).rounded() / 100,
                                    source: a.src, tier: .good, provenance: .real)
        }.sorted { $0.date < $1.date }
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
