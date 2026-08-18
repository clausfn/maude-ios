// UniversalHealthReader.swift — FR-ING-19: read EVERY HealthKit data point the
// citizen grants, as a parallel breadth layer beside the tuned pipelines.
//
// CN directive (2026-08-19): "I want all data from Apple HealthKit — every data
// point." Recorded in qms/DHF.md as an override of the coverage audit's
// named-consumer rule; the consumer here is DataBrowserView ("Everything you
// measure") and the purpose is completeness of the citizen's own record.
//
// DESIGN RULES (all tested in LiviqaTests/UniversalReadTests.swift):
//  · READ-ONLY: the share set is empty; nothing here can write to HealthKit
//    (FR-ARCH-04, same stance as HealthKitService).
//  · AUTHORIZATION asks for the FULL public set — every quantity, category,
//    correlation and characteristic type the running OS resolves, plus
//    workouts, ECG, audiogram, state of mind, scored assessments, vision
//    prescriptions and the two series types. Apple's own permission sheet then
//    lists every type, and the citizen chooses; that sheet is honest by
//    construction. Deliberately excluded: clinical records + CDA documents
//    (separate Apple flow, no consumer, regional) — the named refusal.
//  · STORAGE covers quantity + category samples plus a characteristics
//    snapshot. The four core signals' types (HealthKitService.readTypes +
//    workouts) are EXCLUDED from storage — they stay in their tuned pipelines,
//    and universal rows never enter those pipelines (T-UNI isolation).
//    ECG / audiogram / state-of-mind / series STORAGE is a named follow-up.
//  · Anchored incremental reads (FR-ING-03 discipline) with the anchor sealed
//    in the same EncryptedAnchorStore, under a "universal." key prefix so it
//    can never collide with the tuned pipeline's bare-identifier keys.
//  · Batched backfill: at most `batchLimit` samples per type per pass, the
//    anchor persists between passes, so "every data point" arrives across
//    passes without an unbounded first sync.
import Foundation

#if canImport(HealthKit)
import HealthKit
import SwiftData

/// Summary of one universal ingest pass — framework-free, like IngestDelta.
public nonisolated struct UniversalIngestDelta: Sendable, Equatable {
    public let changedTypes: [String]
    public let newSampleCount: Int
    public let deletedSampleCount: Int
    public init(changedTypes: [String], newSampleCount: Int, deletedSampleCount: Int) {
        self.changedTypes = changedTypes
        self.newSampleCount = newSampleCount
        self.deletedSampleCount = deletedSampleCount
    }
}

public struct UniversalHealthReader {

    let store = HKHealthStore()
    let anchors: EncryptedAnchorStore?

    /// Universal anchor keys are namespaced so they can NEVER collide with the
    /// tuned pipeline's anchor keys (which are bare HK type identifiers).
    nonisolated static let anchorKeyPrefix = "universal."

    public init(anchors: EncryptedAnchorStore? = nil) {
        self.anchors = anchors
            ?? (try? EncryptedAnchorStore(keyVault: .shared, userScope: LocalUserScope.current()))
    }

    // MARK: - Type sets (all pure type lookups — no HKHealthStore involved)

    /// Every sample/characteristic type in the catalog that the RUNNING OS
    /// resolves, plus the scoped object types. This is the authorization set.
    static var fullReadSet: Set<HKObjectType> {
        var t = Set<HKObjectType>()
        for id in UniversalTypeCatalog.quantityIdentifiers {
            if let q = HKObjectType.quantityType(forIdentifier: .init(rawValue: id)) { t.insert(q) }
        }
        for id in UniversalTypeCatalog.categoryIdentifiers {
            if let c = HKObjectType.categoryType(forIdentifier: .init(rawValue: id)) { t.insert(c) }
        }
        for id in UniversalTypeCatalog.correlationIdentifiers {
            if let c = HKObjectType.correlationType(forIdentifier: .init(rawValue: id)) { t.insert(c) }
        }
        for id in UniversalTypeCatalog.characteristicIdentifiers {
            if let c = HKObjectType.characteristicType(forIdentifier: .init(rawValue: id)) { t.insert(c) }
        }
        t.insert(HKObjectType.workoutType())
        t.insert(HKObjectType.electrocardiogramType())
        t.insert(HKObjectType.audiogramSampleType())
        t.insert(HKObjectType.visionPrescriptionType())
        t.insert(HKSeriesType.workoutRoute())
        t.insert(HKSeriesType.heartbeat())
        if #available(iOS 18.0, *) {
            t.insert(HKObjectType.stateOfMindType())
            // Swift hides the ObjC factory (`scoredAssessmentTypeForIdentifier:`
            // is `#if !__swift__` in HKObjectType.h); the Swift surface is the
            // non-failable HKScoredAssessmentType(_:) initializer.
            t.insert(HKScoredAssessmentType(.GAD7))
            t.insert(HKScoredAssessmentType(.PHQ9))
        }
        return t
    }

    /// The types the four tuned pipelines own (sleep, glucose, heart, activity
    /// panels + workouts). The universal layer never STORES these — breadth,
    /// not a second copy of the tuned signals.
    static var tunedTypes: Set<HKObjectType> {
        var t = HealthKitService.readTypes
        t.insert(HKObjectType.workoutType())
        return t
    }

    /// What this layer actually reads and persists: resolved quantity +
    /// category types, minus the tuned pipeline's own set.
    static var storedSampleTypes: [HKSampleType] {
        var out: [HKSampleType] = []
        for id in UniversalTypeCatalog.quantityIdentifiers {
            if let q = HKObjectType.quantityType(forIdentifier: .init(rawValue: id)),
               !tunedTypes.contains(q) { out.append(q) }
        }
        for id in UniversalTypeCatalog.categoryIdentifiers {
            if let c = HKObjectType.categoryType(forIdentifier: .init(rawValue: id)),
               !tunedTypes.contains(c) { out.append(c) }
        }
        return out
    }

    // MARK: - Authorization

    /// One system sheet listing every type in `fullReadSet`. SHARE side is
    /// empty — read-only is structural, exactly as in HealthKitService.
    public func requestFullReadAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }
        try await store.requestAuthorization(toShare: [], read: Self.fullReadSet)
    }

    // MARK: - Units

    /// The user's preferred unit per quantity type (locale-aware), with a
    /// dimension-compatibility ladder as fallback. A type with NO resolvable
    /// unit is skipped honestly rather than guessed at.
    func resolveUnits() async -> [HKQuantityType: HKUnit] {
        let qtypes = Set(Self.storedSampleTypes.compactMap { $0 as? HKQuantityType })
        var out: [HKQuantityType: HKUnit] = [:]
        if let preferred = try? await store.preferredUnits(for: qtypes) {
            out = preferred
        }
        for t in qtypes where out[t] == nil {
            if let u = Self.fallbackUnit(for: t) { out[t] = u }
        }
        return out
    }

    /// First unit the type is dimension-compatible with. `count` and `percent`
    /// are both dimensionless, so percent-natured identifiers are routed by
    /// name before the ladder runs.
    nonisolated static func fallbackUnit(for type: HKQuantityType) -> HKUnit? {
        let id = type.identifier
        if id.contains("Percentage") || id.contains("Saturation")
            || id.contains("Content") || id.contains("Percent") {
            return type.is(compatibleWith: .percent()) ? .percent() : nil
        }
        let ladder: [HKUnit] = [
            HKUnit.count().unitDivided(by: .minute()),          // rates
            .count(),
            .secondUnit(with: .milli), .second(), .minute(), .hour(),
            .kilocalorie(),
            HKUnit.meter().unitDivided(by: .second()),          // speeds
            .meter(),
            HKUnit.liter().unitDivided(by: .minute()),          // flow
            .liter(),
            .millimeterOfMercury(), .degreeCelsius(),
            .gram(), .gramUnit(with: .milli), .gramUnit(with: .micro),
            .watt(),
            .decibelAWeightedSoundPressureLevel(), .decibelHearingLevel(),
            .internationalUnit(), .lux(),
            HKUnit(from: "ml/kg*min"),                          // VO2-class
        ]
        return ladder.first { type.is(compatibleWith: $0) }
    }

    // MARK: - Ingest (anchored, batched, deduplicated)

    /// Advance every stored type from its persisted (encrypted) anchor, write
    /// the new samples as `UniversalSampleRow`s, honour HealthKit deletions,
    /// and refresh the characteristics snapshot. Cheap when nothing is new.
    @MainActor
    public func ingestUniversalDelta(into container: ModelContainer,
                                     batchLimit: Int = 10_000) async throws -> UniversalIngestDelta {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }
        let context = container.mainContext
        let units = await resolveUnits()

        var changed: [String] = []
        var added = 0
        var deleted = 0

        for type in Self.storedSampleTypes {
            let key = Self.anchorKeyPrefix + type.identifier
            let unit = (type as? HKQuantityType).flatMap { units[$0] }
            if type is HKQuantityType && unit == nil { continue }   // no honest unit → skip

            let pass: (Int, Int)
            if let anchors {
                var passDeleted = 0
                let passAdded = try await AnchorSync.advance(store: anchors, key: key) { current in
                    let from = current.flatMap { try? AnchorCodec.decode($0) }
                    let r = try await self.queryAnchored(type, from: from, limit: batchLimit)
                    self.apply(samples: r.samples, deletions: r.deleted, type: type,
                               unit: unit, in: context)
                    passDeleted = r.deleted.count
                    return (r.samples.count, try r.anchor.map { try AnchorCodec.encode($0) })
                }
                pass = (passAdded, passDeleted)
            } else {
                // No encrypted anchor store → still read, just not resumable.
                let r = try await queryAnchored(type, from: nil, limit: batchLimit)
                apply(samples: r.samples, deletions: r.deleted, type: type,
                      unit: unit, in: context)
                pass = (r.samples.count, r.deleted.count)
            }
            if pass.0 > 0 || pass.1 > 0 {
                changed.append(type.identifier)
                added += pass.0
                deleted += pass.1
            }
        }

        try snapshotCharacteristics(in: context)
        try context.save()
        return UniversalIngestDelta(changedTypes: changed, newSampleCount: added,
                                    deletedSampleCount: deleted)
    }

    /// One anchored query: new samples + deletions + the advanced anchor.
    private func queryAnchored(_ type: HKSampleType, from anchor: HKQueryAnchor?, limit: Int)
        async throws -> (samples: [HKSample], deleted: [HKDeletedObject], anchor: HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { cont in
            let q = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: anchor,
                                          limit: limit) { _, samples, deleted, newAnchor, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (samples ?? [], deleted ?? [], newAnchor))
            }
            store.execute(q)
        }
    }

    /// Map one batch into rows. The unique `hkUUID` upserts a replayed batch
    /// instead of duplicating it; deletions remove the matching rows so the
    /// store mirrors what the citizen's HealthKit actually holds.
    @MainActor
    private func apply(samples: [HKSample], deletions: [HKDeletedObject],
                       type: HKSampleType, unit: HKUnit?, in context: ModelContext) {
        for s in samples {
            let row: UniversalSampleRow?
            if let q = s as? HKQuantitySample, let unit,
               q.quantity.is(compatibleWith: unit) {
                row = UniversalSampleRow(
                    hkUUID: q.uuid, typeID: type.identifier,
                    kindRaw: UniversalSampleKind.quantity.rawValue,
                    value: q.quantity.doubleValue(for: unit), unit: unit.unitString,
                    start: q.startDate, end: q.endDate,
                    sourceName: q.sourceRevision.source.name,
                    sourceBundleID: q.sourceRevision.source.bundleIdentifier,
                    deviceName: q.device?.name,
                    isCumulative: (type as? HKQuantityType)?.aggregationStyle == .cumulative,
                    provenanceRaw: Provenance.real.rawValue)
            } else if let c = s as? HKCategorySample {
                row = UniversalSampleRow(
                    hkUUID: c.uuid, typeID: type.identifier,
                    kindRaw: UniversalSampleKind.category.rawValue,
                    value: Double(c.value), unit: "",
                    start: c.startDate, end: c.endDate,
                    sourceName: c.sourceRevision.source.name,
                    sourceBundleID: c.sourceRevision.source.bundleIdentifier,
                    deviceName: c.device?.name,
                    isCumulative: false,
                    provenanceRaw: Provenance.real.rawValue)
            } else {
                row = nil
            }
            if let row { context.insert(row) }
        }
        if !deletions.isEmpty {
            let ids = deletions.map(\.uuid)
            let predicate = #Predicate<UniversalSampleRow> { ids.contains($0.hkUUID) }
            try? context.delete(model: UniversalSampleRow.self, where: predicate)
        }
    }

    // MARK: - Characteristics snapshot

    /// The six characteristic reads (each throws when not granted or not set —
    /// an absent characteristic stays absent, never defaulted). Snapshot
    /// semantics: previous characteristic rows are replaced.
    @MainActor
    private func snapshotCharacteristics(in context: ModelContext) throws {
        var rows: [(typeID: String, label: String)] = []

        if let dob = try? store.dateOfBirthComponents(),
           let y = dob.year, let m = dob.month, let d = dob.day {
            rows.append(("HKCharacteristicTypeIdentifierDateOfBirth",
                         String(format: "%04d-%02d-%02d", y, m, d)))
        }
        if let sex = try? store.biologicalSex().biologicalSex, sex != .notSet {
            let label: String
            switch sex {
            case .female: label = String(localized: "Female")
            case .male: label = String(localized: "Male")
            case .other: label = String(localized: "Other")
            default: label = String(localized: "Recorded")
            }
            rows.append(("HKCharacteristicTypeIdentifierBiologicalSex", label))
        }
        if let blood = try? store.bloodType().bloodType, blood != .notSet {
            let label: String
            switch blood {
            case .aPositive: label = "A+"; case .aNegative: label = "A−"
            case .bPositive: label = "B+"; case .bNegative: label = "B−"
            case .abPositive: label = "AB+"; case .abNegative: label = "AB−"
            case .oPositive: label = "O+"; case .oNegative: label = "O−"
            default: label = String(localized: "Recorded")
            }
            rows.append(("HKCharacteristicTypeIdentifierBloodType", label))
        }
        if let skin = try? store.fitzpatrickSkinType().skinType, skin != .notSet {
            rows.append(("HKCharacteristicTypeIdentifierFitzpatrickSkinType",
                         String(localized: "Type \(skin.rawValue)")))
        }
        if let wheelchair = try? store.wheelchairUse().wheelchairUse, wheelchair != .notSet {
            rows.append(("HKCharacteristicTypeIdentifierWheelchairUse",
                         wheelchair == .yes ? String(localized: "Yes") : String(localized: "No")))
        }
        if let move = try? store.activityMoveMode().activityMoveMode {
            rows.append(("HKCharacteristicTypeIdentifierActivityMoveMode",
                         move == .appleMoveTime ? String(localized: "Move time")
                                                : String(localized: "Active energy")))
        }

        guard !rows.isEmpty else { return }
        let kind = UniversalSampleKind.characteristic.rawValue
        let predicate = #Predicate<UniversalSampleRow> { $0.kindRaw == kind }
        try context.delete(model: UniversalSampleRow.self, where: predicate)
        let now = Date()
        for r in rows {
            context.insert(UniversalSampleRow(
                hkUUID: UUID(), typeID: r.typeID, kindRaw: kind,
                value: 0, unit: "", valueLabel: r.label, start: now, end: now,
                sourceName: String(localized: "Health app"),
                sourceBundleID: "com.apple.Health", deviceName: nil,
                isCumulative: false, provenanceRaw: Provenance.real.rawValue))
        }
    }
}
#endif
