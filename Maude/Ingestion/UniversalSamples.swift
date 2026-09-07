// UniversalSamples.swift — FR-ING-19: the universal HealthKit layer's catalog,
// persisted row, store, and pure browse derivation.
//
// CN directive (2026-08-19, verbatim): "I want all data from Apple HealthKit —
// every data point." This OVERRULES the coverage audit's named-consumer rule
// (docs/HealthKit_Coverage_Audit_20260818.md) — recorded in qms/DHF.md with the
// date. Purpose of the universal read: COMPLETENESS of the citizen's own record;
// the named consumer is DataBrowserView ("Everything you measure").
//
// BREADTH, not depth: the four core signals (sleep, glucose, heart, activity)
// keep their existing tuned pipelines; this layer is everything else. Universal
// rows NEVER enter those pipelines (T-UNI isolation suite) and no deriver ever
// judges them — the browser renders recorded values and nothing more, so
// FR-NDG-06 stays clean because no sentences are generated.
//
// Store discipline mirrors MaudeStore (Persistence.swift): SwiftData, on-device
// only (`cloudKitDatabase: .none`), file-protected at rest, erased by
// `UniversalHealthStore.eraseAll()` — the one-line `AppState.deleteAllData`
// hook, reported for the integration PR (AppState is owned elsewhere this wave).
import Foundation
import SwiftData

// MARK: - Catalog — every public HealthKit type identifier, as raw strings
//
// Raw strings, not enum cases, deliberately: `HKObjectType.quantityType(forIdentifier:)`
// returns nil for any identifier the RUNNING OS does not know, so one manifest is
// compile-safe on every SDK and resolves to exactly what this device offers.
// Extracted from the iOS 26.5 SDK header (HKTypeIdentifiers.h); the T-UNI catalog
// test re-derives the list from the installed SDK and fails on drift, so a new
// OS's types cannot be silently missed.
public nonisolated enum UniversalTypeCatalog {

    public static let quantityIdentifiers: [String] = [
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKQuantityTypeIdentifierAppleExerciseTime",
        "HKQuantityTypeIdentifierAppleMoveTime",
        "HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances",
        "HKQuantityTypeIdentifierAppleSleepingWristTemperature",
        "HKQuantityTypeIdentifierAppleStandTime",
        "HKQuantityTypeIdentifierAppleWalkingSteadiness",
        "HKQuantityTypeIdentifierAtrialFibrillationBurden",
        "HKQuantityTypeIdentifierBasalBodyTemperature",
        "HKQuantityTypeIdentifierBasalEnergyBurned",
        "HKQuantityTypeIdentifierBloodAlcoholContent",
        "HKQuantityTypeIdentifierBloodGlucose",
        "HKQuantityTypeIdentifierBloodPressureDiastolic",
        "HKQuantityTypeIdentifierBloodPressureSystolic",
        "HKQuantityTypeIdentifierBodyFatPercentage",
        "HKQuantityTypeIdentifierBodyMass",
        "HKQuantityTypeIdentifierBodyMassIndex",
        "HKQuantityTypeIdentifierBodyTemperature",
        "HKQuantityTypeIdentifierCrossCountrySkiingSpeed",
        "HKQuantityTypeIdentifierCyclingCadence",
        "HKQuantityTypeIdentifierCyclingFunctionalThresholdPower",
        "HKQuantityTypeIdentifierCyclingPower",
        "HKQuantityTypeIdentifierCyclingSpeed",
        "HKQuantityTypeIdentifierDietaryBiotin",
        "HKQuantityTypeIdentifierDietaryCaffeine",
        "HKQuantityTypeIdentifierDietaryCalcium",
        "HKQuantityTypeIdentifierDietaryCarbohydrates",
        "HKQuantityTypeIdentifierDietaryChloride",
        "HKQuantityTypeIdentifierDietaryCholesterol",
        "HKQuantityTypeIdentifierDietaryChromium",
        "HKQuantityTypeIdentifierDietaryCopper",
        "HKQuantityTypeIdentifierDietaryEnergyConsumed",
        "HKQuantityTypeIdentifierDietaryFatMonounsaturated",
        "HKQuantityTypeIdentifierDietaryFatPolyunsaturated",
        "HKQuantityTypeIdentifierDietaryFatSaturated",
        "HKQuantityTypeIdentifierDietaryFatTotal",
        "HKQuantityTypeIdentifierDietaryFiber",
        "HKQuantityTypeIdentifierDietaryFolate",
        "HKQuantityTypeIdentifierDietaryIodine",
        "HKQuantityTypeIdentifierDietaryIron",
        "HKQuantityTypeIdentifierDietaryMagnesium",
        "HKQuantityTypeIdentifierDietaryManganese",
        "HKQuantityTypeIdentifierDietaryMolybdenum",
        "HKQuantityTypeIdentifierDietaryNiacin",
        "HKQuantityTypeIdentifierDietaryPantothenicAcid",
        "HKQuantityTypeIdentifierDietaryPhosphorus",
        "HKQuantityTypeIdentifierDietaryPotassium",
        "HKQuantityTypeIdentifierDietaryProtein",
        "HKQuantityTypeIdentifierDietaryRiboflavin",
        "HKQuantityTypeIdentifierDietarySelenium",
        "HKQuantityTypeIdentifierDietarySodium",
        "HKQuantityTypeIdentifierDietarySugar",
        "HKQuantityTypeIdentifierDietaryThiamin",
        "HKQuantityTypeIdentifierDietaryVitaminA",
        "HKQuantityTypeIdentifierDietaryVitaminB12",
        "HKQuantityTypeIdentifierDietaryVitaminB6",
        "HKQuantityTypeIdentifierDietaryVitaminC",
        "HKQuantityTypeIdentifierDietaryVitaminD",
        "HKQuantityTypeIdentifierDietaryVitaminE",
        "HKQuantityTypeIdentifierDietaryVitaminK",
        "HKQuantityTypeIdentifierDietaryWater",
        "HKQuantityTypeIdentifierDietaryZinc",
        "HKQuantityTypeIdentifierDistanceCrossCountrySkiing",
        "HKQuantityTypeIdentifierDistanceCycling",
        "HKQuantityTypeIdentifierDistanceDownhillSnowSports",
        "HKQuantityTypeIdentifierDistancePaddleSports",
        "HKQuantityTypeIdentifierDistanceRowing",
        "HKQuantityTypeIdentifierDistanceSkatingSports",
        "HKQuantityTypeIdentifierDistanceSwimming",
        "HKQuantityTypeIdentifierDistanceWalkingRunning",
        "HKQuantityTypeIdentifierDistanceWheelchair",
        "HKQuantityTypeIdentifierElectrodermalActivity",
        "HKQuantityTypeIdentifierEnvironmentalAudioExposure",
        "HKQuantityTypeIdentifierEnvironmentalSoundReduction",
        "HKQuantityTypeIdentifierEstimatedWorkoutEffortScore",
        "HKQuantityTypeIdentifierFlightsClimbed",
        "HKQuantityTypeIdentifierForcedExpiratoryVolume1",
        "HKQuantityTypeIdentifierForcedVitalCapacity",
        "HKQuantityTypeIdentifierHeadphoneAudioExposure",
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierHeartRateRecoveryOneMinute",
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
        "HKQuantityTypeIdentifierHeight",
        "HKQuantityTypeIdentifierInhalerUsage",
        "HKQuantityTypeIdentifierInsulinDelivery",
        "HKQuantityTypeIdentifierLeanBodyMass",
        "HKQuantityTypeIdentifierNikeFuel",
        "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages",
        "HKQuantityTypeIdentifierNumberOfTimesFallen",
        "HKQuantityTypeIdentifierOxygenSaturation",
        "HKQuantityTypeIdentifierPaddleSportsSpeed",
        "HKQuantityTypeIdentifierPeakExpiratoryFlowRate",
        "HKQuantityTypeIdentifierPeripheralPerfusionIndex",
        "HKQuantityTypeIdentifierPhysicalEffort",
        "HKQuantityTypeIdentifierPushCount",
        "HKQuantityTypeIdentifierRespiratoryRate",
        "HKQuantityTypeIdentifierRestingHeartRate",
        "HKQuantityTypeIdentifierRowingSpeed",
        "HKQuantityTypeIdentifierRunningGroundContactTime",
        "HKQuantityTypeIdentifierRunningPower",
        "HKQuantityTypeIdentifierRunningSpeed",
        "HKQuantityTypeIdentifierRunningStrideLength",
        "HKQuantityTypeIdentifierRunningVerticalOscillation",
        "HKQuantityTypeIdentifierSixMinuteWalkTestDistance",
        "HKQuantityTypeIdentifierStairAscentSpeed",
        "HKQuantityTypeIdentifierStairDescentSpeed",
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierSwimmingStrokeCount",
        "HKQuantityTypeIdentifierTimeInDaylight",
        "HKQuantityTypeIdentifierUVExposure",
        "HKQuantityTypeIdentifierUnderwaterDepth",
        "HKQuantityTypeIdentifierVO2Max",
        "HKQuantityTypeIdentifierWaistCircumference",
        "HKQuantityTypeIdentifierWalkingAsymmetryPercentage",
        "HKQuantityTypeIdentifierWalkingDoubleSupportPercentage",
        "HKQuantityTypeIdentifierWalkingHeartRateAverage",
        "HKQuantityTypeIdentifierWalkingSpeed",
        "HKQuantityTypeIdentifierWalkingStepLength",
        "HKQuantityTypeIdentifierWaterTemperature",
        "HKQuantityTypeIdentifierWorkoutEffortScore",
    ]

    public static let categoryIdentifiers: [String] = [
        "HKCategoryTypeIdentifierAbdominalCramps",
        "HKCategoryTypeIdentifierAcne",
        "HKCategoryTypeIdentifierAppetiteChanges",
        "HKCategoryTypeIdentifierAppleStandHour",
        "HKCategoryTypeIdentifierAppleWalkingSteadinessEvent",
        "HKCategoryTypeIdentifierAudioExposureEvent",
        "HKCategoryTypeIdentifierBladderIncontinence",
        "HKCategoryTypeIdentifierBleedingAfterPregnancy",
        "HKCategoryTypeIdentifierBleedingDuringPregnancy",
        "HKCategoryTypeIdentifierBloating",
        "HKCategoryTypeIdentifierBreastPain",
        "HKCategoryTypeIdentifierCervicalMucusQuality",
        "HKCategoryTypeIdentifierChestTightnessOrPain",
        "HKCategoryTypeIdentifierChills",
        "HKCategoryTypeIdentifierConstipation",
        "HKCategoryTypeIdentifierContraceptive",
        "HKCategoryTypeIdentifierCoughing",
        "HKCategoryTypeIdentifierDiarrhea",
        "HKCategoryTypeIdentifierDizziness",
        "HKCategoryTypeIdentifierDrySkin",
        "HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent",
        "HKCategoryTypeIdentifierFainting",
        "HKCategoryTypeIdentifierFatigue",
        "HKCategoryTypeIdentifierFever",
        "HKCategoryTypeIdentifierGeneralizedBodyAche",
        "HKCategoryTypeIdentifierHairLoss",
        "HKCategoryTypeIdentifierHandwashingEvent",
        "HKCategoryTypeIdentifierHeadache",
        "HKCategoryTypeIdentifierHeadphoneAudioExposureEvent",
        "HKCategoryTypeIdentifierHeartburn",
        "HKCategoryTypeIdentifierHighHeartRateEvent",
        "HKCategoryTypeIdentifierHotFlashes",
        "HKCategoryTypeIdentifierHypertensionEvent",
        "HKCategoryTypeIdentifierInfrequentMenstrualCycles",
        "HKCategoryTypeIdentifierIntermenstrualBleeding",
        "HKCategoryTypeIdentifierIrregularHeartRhythmEvent",
        "HKCategoryTypeIdentifierIrregularMenstrualCycles",
        "HKCategoryTypeIdentifierLactation",
        "HKCategoryTypeIdentifierLossOfSmell",
        "HKCategoryTypeIdentifierLossOfTaste",
        "HKCategoryTypeIdentifierLowCardioFitnessEvent",
        "HKCategoryTypeIdentifierLowHeartRateEvent",
        "HKCategoryTypeIdentifierLowerBackPain",
        "HKCategoryTypeIdentifierMemoryLapse",
        "HKCategoryTypeIdentifierMenstrualFlow",
        "HKCategoryTypeIdentifierMindfulSession",
        "HKCategoryTypeIdentifierMoodChanges",
        "HKCategoryTypeIdentifierNausea",
        "HKCategoryTypeIdentifierNightSweats",
        "HKCategoryTypeIdentifierOvulationTestResult",
        "HKCategoryTypeIdentifierPelvicPain",
        "HKCategoryTypeIdentifierPersistentIntermenstrualBleeding",
        "HKCategoryTypeIdentifierPregnancy",
        "HKCategoryTypeIdentifierPregnancyTestResult",
        "HKCategoryTypeIdentifierProgesteroneTestResult",
        "HKCategoryTypeIdentifierProlongedMenstrualPeriods",
        "HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat",
        "HKCategoryTypeIdentifierRunnyNose",
        "HKCategoryTypeIdentifierSexualActivity",
        "HKCategoryTypeIdentifierShortnessOfBreath",
        "HKCategoryTypeIdentifierSinusCongestion",
        "HKCategoryTypeIdentifierSkippedHeartbeat",
        "HKCategoryTypeIdentifierSleepAnalysis",
        "HKCategoryTypeIdentifierSleepApneaEvent",
        "HKCategoryTypeIdentifierSleepChanges",
        "HKCategoryTypeIdentifierSoreThroat",
        "HKCategoryTypeIdentifierToothbrushingEvent",
        "HKCategoryTypeIdentifierVaginalDryness",
        "HKCategoryTypeIdentifierVomiting",
        "HKCategoryTypeIdentifierWheezing",
    ]

    public static let correlationIdentifiers: [String] = [
        "HKCorrelationTypeIdentifierBloodPressure",
        "HKCorrelationTypeIdentifierFood",
    ]

    public static let characteristicIdentifiers: [String] = [
        "HKCharacteristicTypeIdentifierActivityMoveMode",
        "HKCharacteristicTypeIdentifierBiologicalSex",
        "HKCharacteristicTypeIdentifierBloodType",
        "HKCharacteristicTypeIdentifierDateOfBirth",
        "HKCharacteristicTypeIdentifierFitzpatrickSkinType",
        "HKCharacteristicTypeIdentifierWheelchairUse",
    ]

    /// Snapshot of the manifest sizes for the iOS 26.5 SDK the catalog was
    /// extracted from. The T-UNI catalog test asserts these AND re-derives the
    /// lists from the installed SDK header when it can find one, so both the
    /// numbers and the names are pinned.
    public static let snapshotCounts = (quantity: 120, category: 70, correlation: 2, characteristic: 6)
}

// MARK: - Persisted row (SwiftData)

/// One HealthKit data point, stored generically: the type identifier, the value
/// in a recorded unit, the interval, and WHERE it came from (source app +
/// device). `provenanceRaw` is the arbitration DATA field (always REAL here —
/// this layer only ever reads live HealthKit) and, as everywhere, never renders.
@Model
final class UniversalSampleRow {
    /// HealthKit's own sample UUID — the dedup key. An anchored query never
    /// re-delivers a sample, but a crash between insert and anchor-save may
    /// replay a batch; the unique constraint upserts instead of duplicating.
    @Attribute(.unique) var hkUUID: UUID
    var typeID: String          // e.g. "HKQuantityTypeIdentifierTimeInDaylight"
    var kindRaw: String         // UniversalSampleKind rawValue
    var value: Double           // quantity: value in `unit` · category: HK raw value
    var unit: String            // quantity: HKUnit string · category/characteristic: ""
    var valueLabel: String?     // characteristic snapshot label ("O positive")
    var start: Date
    var end: Date
    var sourceName: String      // the recording app's display name
    var sourceBundleID: String  // the recording app's bundle identifier
    var deviceName: String?     // hardware name when HealthKit carries one
    var isCumulative: Bool      // quantity aggregation style (sum vs mean days)
    var provenanceRaw: String   // Provenance.real.rawValue — data field, never renders

    init(hkUUID: UUID, typeID: String, kindRaw: String, value: Double, unit: String,
         valueLabel: String? = nil, start: Date, end: Date, sourceName: String,
         sourceBundleID: String, deviceName: String? = nil, isCumulative: Bool,
         provenanceRaw: String) {
        self.hkUUID = hkUUID; self.typeID = typeID; self.kindRaw = kindRaw
        self.value = value; self.unit = unit; self.valueLabel = valueLabel
        self.start = start; self.end = end; self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID; self.deviceName = deviceName
        self.isCumulative = isCumulative; self.provenanceRaw = provenanceRaw
    }
}

public nonisolated enum UniversalSampleKind: String, Sendable, CaseIterable {
    case quantity, category, characteristic
}

// MARK: - Store (parallel container, same discipline as MaudeStore)

/// The universal layer's own on-device SwiftData store. A SEPARATE container by
/// design this wave: `Persistence.swift` (MaudeStore) is owned by concurrent
/// workflows, and separation is also the isolation guarantee — nothing that
/// queries MaudeStore can ever fetch a universal row by accident.
enum UniversalHealthStore {
    static let models: [any PersistentModel.Type] = [UniversalSampleRow.self]
    static var schema: Schema { Schema(models) }

    /// `<Application Support>/universal-health.store`
    static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("universal-health.store")
    }

    /// Same construction rules as `MaudeStore.makeContainer`: on-device only,
    /// `cloudKitDatabase: .none`, and the lock-safe at-rest protection level
    /// applied to the store and its WAL/SHM siblings (see Persistence.swift for
    /// why `.completeUntilFirstUserAuthentication`, not `.complete`).
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                               allowsSave: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("UniversalHealth", schema: schema,
                                               url: storeURL, allowsSave: true,
                                               cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        if !inMemory { applyFileProtection(to: configuration.url) }
        return container
    }

    private static func applyFileProtection(to url: URL) {
        let level = FileProtectionType.completeUntilFirstUserAuthentication
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            try? FileManager.default.setAttributes([.protectionKey: level], ofItemAtPath: path)
        }
    }

    /// The app-lifetime container. nil when SwiftData cannot open the store —
    /// the browser then shows its honest unavailable state, never a crash.
    @MainActor static let shared: ModelContainer? = try? makeContainer()

    /// Delete every universal row in `context` (the unit the erase test covers).
    static func erase(in context: ModelContext) throws {
        try context.delete(model: UniversalSampleRow.self)
        try context.save()
    }

    /// GDPR erase hook — the ONE LINE `AppState.deleteAllData` must call in the
    /// integration PR (AppState.swift is owned by concurrent workflows this
    /// wave, so the hook is reported, not landed):
    ///     UniversalHealthStore.eraseAll()   // FR-ING-19 universal rows
    /// Until that PR the layer is dormant anyway: nothing calls the reader, so
    /// no universal row can exist on a device this erase would miss.
    @MainActor static func eraseAll() {
        guard let container = shared else { return }
        try? erase(in: container.mainContext)
    }
}

// MARK: - Pure browse derivation (framework-free, NFR-PORT-01)

/// Portable mirror of a stored row — what the derivation and its tests consume,
/// so no SwiftData is needed to verify the browse rules.
public nonisolated struct UniversalRowValue: Sendable, Equatable {
    public let typeID: String
    public let kind: UniversalSampleKind
    public let value: Double
    public let unit: String
    public let valueLabel: String?
    public let start: Date
    public let end: Date
    public let source: String
    public let isCumulative: Bool
    public init(typeID: String, kind: UniversalSampleKind, value: Double, unit: String,
                valueLabel: String? = nil, start: Date, end: Date, source: String,
                isCumulative: Bool) {
        self.typeID = typeID; self.kind = kind; self.value = value; self.unit = unit
        self.valueLabel = valueLabel; self.start = start; self.end = end
        self.source = source; self.isCumulative = isCumulative
    }
}

/// One browsable type: what the list row renders. VALUES ONLY — there is no
/// judgment field on this type, by construction. A day with nothing recorded is
/// a nil slot (DaySeries discipline), never a zero.
public nonisolated struct UniversalTypeSummary: Sendable, Equatable, Identifiable {
    public let typeID: String
    public let kind: UniversalSampleKind
    public let displayName: String
    public let latestValue: Double
    public let latestLabel: String?    // characteristic label when present
    public let unit: String
    public let latestDate: Date
    public let count: Int
    public let sources: [String]       // distinct, recency-first
    public let slots: [DaySlot]        // day-axis mini-chart (gaps stay gaps)
    /// Category mini-charts count ENTRIES per day (a tally of records, honestly
    /// labelled), because a category value is an enum code, not a magnitude.
    public let chartsEntries: Bool
    public var id: String { typeID }
}

public nonisolated enum UniversalBrowse {

    /// Group rows into per-type summaries over a `windowDays` day axis ending
    /// today. Quantity day values follow the DailyRollup rule (FR-ING-17):
    /// cumulative kinds take the best-covering single source's total — an
    /// iPhone and a Watch both logging the same walk never sum; mean kinds
    /// average. Category kinds chart entries-per-day. Characteristics carry no
    /// chart (a single stated fact has no day axis).
    public static func summaries(rows: [UniversalRowValue], today: Date = Date(),
                                 windowDays: Int = 14,
                                 calendar: Calendar = DaySeries.calendar) -> [UniversalTypeSummary] {
        let window = DaySeries.days(endingOn: today, count: windowDays, calendar: calendar)
        var byType: [String: [UniversalRowValue]] = [:]
        for r in rows { byType[r.typeID, default: []].append(r) }

        return byType.map { typeID, rs in
            let sorted = rs.sorted { $0.start < $1.start }
            let latest = sorted.last!
            let kind = latest.kind

            var slots: [DaySlot] = []
            var chartsEntries = false
            switch kind {
            case .quantity:
                let rolled = DailyRollup.rollUp(
                    sorted.map { DailyRollup.Row(day: calendar.startOfDay(for: $0.start),
                                                 value: $0.value, source: $0.source) },
                    cumulative: latest.isCumulative)
                slots = DaySeries.slots(values: rolled.map(\.value),
                                        dates: rolled.map(\.day),
                                        over: window, calendar: calendar)
            case .category:
                // A tally of records per day — a count is the only honest
                // magnitude an enum-coded sample has.
                var perDay: [Date: Double] = [:]
                for r in sorted { perDay[calendar.startOfDay(for: r.start), default: 0] += 1 }
                let days = perDay.keys.sorted()
                slots = DaySeries.slots(values: days.map { perDay[$0]! }, dates: days,
                                        over: window, calendar: calendar)
                chartsEntries = true
            case .characteristic:
                slots = []
            }

            var seen = Set<String>()
            let sources = sorted.reversed().map(\.source).filter { seen.insert($0).inserted }

            return UniversalTypeSummary(
                typeID: typeID, kind: kind,
                displayName: displayName(forTypeID: typeID),
                latestValue: latest.value,
                latestLabel: latest.valueLabel ?? categoryValueLabel(typeID: typeID,
                                                                    value: latest.value,
                                                                    kind: kind),
                unit: latest.unit, latestDate: latest.start,
                count: rs.count, sources: sources, slots: slots,
                chartsEntries: chartsEntries)
        }
        .sorted { $0.latestDate > $1.latestDate }
    }

    /// "HKQuantityTypeIdentifierTimeInDaylight" → "Time In Daylight".
    /// Pure mechanical camel-case split of Apple's own identifier — naming a
    /// type is not judging it.
    public static func displayName(forTypeID id: String) -> String {
        var name = id
        for prefix in ["HKQuantityTypeIdentifier", "HKCategoryTypeIdentifier",
                       "HKCorrelationTypeIdentifier", "HKCharacteristicTypeIdentifier"] {
            if name.hasPrefix(prefix) { name.removeFirst(prefix.count); break }
        }
        var out = ""
        var prev: Character = " "
        for ch in name {
            if ch.isUppercase && (prev.isLowercase || prev.isNumber) { out.append(" ") }
            if ch.isNumber && prev.isLetter { out.append(" ") }
            out.append(ch)
            prev = ch
        }
        // Keep known all-caps runs readable ("VO 2 Max" → "VO2 Max").
        return out.replacingOccurrences(of: "VO 2", with: "VO2")
                  .replacingOccurrences(of: "UV ", with: "UV ")
    }

    /// Decode of a RECORDED category code into the words HealthKit defines for
    /// it — reading back what was written, never an assessment by Maude.
    /// Types without a decode here return nil and the row shows "recorded".
    public static func categoryValueLabel(typeID: String, value: Double,
                                          kind: UniversalSampleKind) -> String? {
        guard kind == .category else { return nil }
        let v = Int(value)
        if severityCategoryTypeIDs.contains(typeID) {
            switch v {                       // HKCategoryValueSeverity raw values
            case 1: return String(localized: "Not present")
            case 2: return String(localized: "Mild")
            case 3: return String(localized: "Moderate")
            case 4: return String(localized: "Severe")
            default: return String(localized: "Recorded")
            }
        }
        switch typeID {
        case "HKCategoryTypeIdentifierAppleStandHour":
            return v == 0 ? String(localized: "Stood") : String(localized: "Idle")
        case "HKCategoryTypeIdentifierMenstrualFlow":
            switch v { case 2: return String(localized: "Light")
                       case 3: return String(localized: "Medium")
                       case 4: return String(localized: "Heavy")
                       case 5: return String(localized: "None")
                       default: return String(localized: "Recorded") }
        default:
            return nil
        }
    }

    /// The symptom types that record HKCategoryValueSeverity.
    public static let severityCategoryTypeIDs: Set<String> = [
        "AbdominalCramps", "Acne", "BladderIncontinence", "Bloating", "BreastPain",
        "ChestTightnessOrPain", "Chills", "Constipation", "Coughing", "Diarrhea",
        "Dizziness", "DrySkin", "Fainting", "Fatigue", "Fever", "GeneralizedBodyAche",
        "HairLoss", "Headache", "Heartburn", "HotFlashes", "LossOfSmell", "LossOfTaste",
        "LowerBackPain", "MemoryLapse", "Nausea", "NightSweats", "PelvicPain",
        "RapidPoundingOrFlutteringHeartbeat", "RunnyNose", "ShortnessOfBreath",
        "SinusCongestion", "SkippedHeartbeat", "SoreThroat", "VaginalDryness",
        "Vomiting", "Wheezing",
    ].reduce(into: Set<String>()) { $0.insert("HKCategoryTypeIdentifier" + $1) }
}
