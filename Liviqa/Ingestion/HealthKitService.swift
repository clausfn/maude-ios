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

    /// READ set — the MVP read set only. (FR-ING-01)
    static var readTypes: Set<HKObjectType> {
        var t: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { t.insert(hrv) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { t.insert(rhr) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { t.insert(steps) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { t.insert(energy) }
        if let glucose = HKObjectType.quantityType(forIdentifier: .bloodGlucose) { t.insert(glucose) }
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
        async let glucose = readGlucose(start, end)
        async let hrv = readDaily(.heartRateVariabilitySDNN, .hrvSDNN, unit: .secondUnit(with: .milli), start, end, tier: .good, cumulative: false)
        async let rhr = readDaily(.restingHeartRate, .restingHR, unit: HKUnit.count().unitDivided(by: .minute()), start, end, tier: .good, cumulative: false)
        async let steps = readDaily(.stepCount, .steps, unit: .count(), start, end, tier: .estimate, cumulative: true)
        async let energy = readDaily(.activeEnergyBurned, .activeEnergy, unit: .kilocalorie(), start, end, tier: .estimate, cumulative: true)
        async let sleep = readSleep(start, end)
        async let workouts = readWorkouts(start, end)

        return try await HealthSamples(
            glucose: glucose, hrv: hrv, restingHR: rhr, steps: steps,
            activeEnergy: energy, sleep: sleep, workouts: workouts)
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
