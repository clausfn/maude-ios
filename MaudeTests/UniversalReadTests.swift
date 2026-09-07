import Testing
import Foundation
import SwiftData
@testable import Maude

// UniversalReadTests.swift — FR-ING-19 universal HealthKit layer (T-UNI-01..).
//
// CN directive 2026-08-19 ("I want all data from Apple HealthKit — every data
// point") — the override of the coverage audit's named-consumer rule is
// recorded in qms/DHF.md. Four guarantees pinned here:
//   1. the authorization-set enumeration is COMPLETE for the OS/SDK (snapshot +
//      re-derivation from the installed SDK header when one is locatable),
//   2. universal samples NEVER enter the four tuned pipelines (type-set
//      disjointness + structural source lint in both directions),
//   3. erase clears the universal store,
//   4. the browser renders values only — no verdict vocabulary exists in it.
//
// Two-hangs rule respected throughout: no HKHealthStore (or any live system
// store) is ever constructed and no live HealthKit path is awaited — only pure
// type lookups, pure derivation, source reading, and an in-memory container.

#if canImport(HealthKit)
import HealthKit

// MARK: - T-UNI-01..04 · catalog completeness (the enumeration snapshot)

@MainActor
struct UniversalCatalogTests {

    // T-UNI-01 — the manifest matches the pinned snapshot of the SDK it was
    // extracted from (iOS 26.5): 120 quantity, 70 category, 2 correlation,
    // 6 characteristic identifiers, no duplicates.
    @Test func manifestMatchesSnapshotCounts() {
        let c = UniversalTypeCatalog.snapshotCounts
        #expect(UniversalTypeCatalog.quantityIdentifiers.count == c.quantity)
        #expect(UniversalTypeCatalog.categoryIdentifiers.count == c.category)
        #expect(UniversalTypeCatalog.correlationIdentifiers.count == c.correlation)
        #expect(UniversalTypeCatalog.characteristicIdentifiers.count == c.characteristic)
        for list in [UniversalTypeCatalog.quantityIdentifiers,
                     UniversalTypeCatalog.categoryIdentifiers,
                     UniversalTypeCatalog.correlationIdentifiers,
                     UniversalTypeCatalog.characteristicIdentifiers] {
            #expect(Set(list).count == list.count)
        }
    }

    // T-UNI-02 — completeness against the INSTALLED SDK: re-derive the public
    // identifier lists from HKTypeIdentifiers.h and require exact equality with
    // the manifest, so a new OS's types cannot be silently missed and a typo'd
    // identifier cannot linger. When no SDK header is locatable (a stripped CI
    // box), the pinned snapshot in T-UNI-01 is the fallback guarantee.
    @Test func manifestMatchesInstalledSDKHeader() throws {
        guard let header = Self.sdkTypeIdentifiersHeader() else { return }
        func extract(_ prefix: String) -> Set<String> {
            var out = Set<String>()
            var search = header.startIndex
            while let r = header.range(of: "\(prefix)[A-Za-z0-9]+",
                                       options: .regularExpression,
                                       range: search..<header.endIndex) {
                out.insert(String(header[r]))
                search = r.upperBound
            }
            return out
        }
        #expect(extract("HKQuantityTypeIdentifier") == Set(UniversalTypeCatalog.quantityIdentifiers))
        #expect(extract("HKCategoryTypeIdentifier") == Set(UniversalTypeCatalog.categoryIdentifiers))
        #expect(extract("HKCorrelationTypeIdentifier") == Set(UniversalTypeCatalog.correlationIdentifiers))
        #expect(extract("HKCharacteristicTypeIdentifier") == Set(UniversalTypeCatalog.characteristicIdentifiers))
    }

    /// Contents of the newest iPhoneSimulator SDK's HKTypeIdentifiers.h, when
    /// an Xcode installation is visible from the test process; nil otherwise.
    private static func sdkTypeIdentifiersHeader() -> String? {
        let fm = FileManager.default
        var developerDirs = ["/Applications/Xcode.app/Contents/Developer"]
        // Xcode-beta / renamed installs.
        if let apps = try? fm.contentsOfDirectory(atPath: "/Applications") {
            developerDirs += apps.filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }
                .map { "/Applications/\($0)/Contents/Developer" }
        }
        for dev in developerDirs {
            let sdks = "\(dev)/Platforms/iPhoneSimulator.platform/Developer/SDKs"
            guard let names = try? fm.contentsOfDirectory(atPath: sdks) else { continue }
            for sdk in names.sorted().reversed() where sdk.hasSuffix(".sdk") {
                let path = "\(sdks)/\(sdk)/System/Library/Frameworks/HealthKit.framework/Headers/HKTypeIdentifiers.h"
                if let text = try? String(contentsOfFile: path, encoding: .utf8) { return text }
            }
        }
        return nil
    }

    // T-UNI-03 — every identifier the RUNNING OS resolves is in the
    // authorization set (nothing enumerable is left out), and the scoped object
    // types are all present. Pure type lookups; no store constructed.
    @Test func everyResolvableTypeIsInTheAuthorizationSet() {
        let full = UniversalHealthReader.fullReadSet
        for id in UniversalTypeCatalog.quantityIdentifiers {
            if let t = HKObjectType.quantityType(forIdentifier: .init(rawValue: id)) {
                #expect(full.contains(t), "missing quantity \(id)")
            }
        }
        for id in UniversalTypeCatalog.categoryIdentifiers {
            if let t = HKObjectType.categoryType(forIdentifier: .init(rawValue: id)) {
                #expect(full.contains(t), "missing category \(id)")
            }
        }
        for id in UniversalTypeCatalog.correlationIdentifiers {
            if let t = HKObjectType.correlationType(forIdentifier: .init(rawValue: id)) {
                #expect(full.contains(t), "missing correlation \(id)")
            }
        }
        for id in UniversalTypeCatalog.characteristicIdentifiers {
            if let t = HKObjectType.characteristicType(forIdentifier: .init(rawValue: id)) {
                #expect(full.contains(t), "missing characteristic \(id)")
            }
        }
        #expect(full.contains(HKObjectType.workoutType()))
        #expect(full.contains(HKObjectType.electrocardiogramType()))
        #expect(full.contains(HKObjectType.audiogramSampleType()))
        #expect(full.contains(HKObjectType.visionPrescriptionType()))
        #expect(full.contains(HKSeriesType.workoutRoute()))
        #expect(full.contains(HKSeriesType.heartbeat()))
        if #available(iOS 18.0, *) {
            #expect(full.contains(HKObjectType.stateOfMindType()))
        }
        // The tuned set is a SUBSET of the full authorization ask — one sheet
        // covers both layers; nothing the tuned pipelines read is dropped.
        #expect(HealthKitService.readTypes.isSubset(of: full))
    }

    // T-UNI-04 — the running OS resolves at least the floors of the snapshot
    // SDK's era (a regression here means the manifest stopped resolving).
    @Test func resolvedFloorsHold() {
        let resolvedQ = UniversalTypeCatalog.quantityIdentifiers
            .compactMap { HKObjectType.quantityType(forIdentifier: .init(rawValue: $0)) }
        let resolvedC = UniversalTypeCatalog.categoryIdentifiers
            .compactMap { HKObjectType.categoryType(forIdentifier: .init(rawValue: $0)) }
        #expect(resolvedQ.count >= 100)
        #expect(resolvedC.count >= 60)
    }
}

// MARK: - T-UNI-05..07 · isolation from the four tuned pipelines

@MainActor
struct UniversalIsolationTests {

    // T-UNI-05 — the universal STORAGE set is disjoint from every type the
    // tuned pipelines read (sleep, glucose, heart panel, activity, workouts):
    // the universal layer is breadth, never a second copy of a tuned signal.
    @Test func storedTypesNeverOverlapTunedPipelines() {
        let stored = Set(UniversalHealthReader.storedSampleTypes)
        let tuned = UniversalHealthReader.tunedTypes
        #expect(Set<HKObjectType>(stored).isDisjoint(with: tuned))
        // The named core types, spelled out.
        for id: HKQuantityTypeIdentifier in [.bloodGlucose, .heartRateVariabilitySDNN,
                                             .restingHeartRate, .stepCount, .activeEnergyBurned,
                                             .heartRate, .appleSleepingWristTemperature] {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                #expect(!stored.contains(t), "tuned type stored universally: \(id.rawValue)")
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            #expect(!stored.contains(sleep))
        }
        #expect(!stored.contains(HKObjectType.workoutType()))
    }

    // T-UNI-06 — anchor keys are namespaced: the universal reader can never
    // collide with the tuned pipeline's bare-identifier anchor keys. Checked
    // structurally: the prefix is non-empty, and the reader's single
    // AnchorSync call site uses it (no bare `key: type.identifier` exists).
    @Test func anchorKeysAreNamespaced() throws {
        #expect(UniversalHealthReader.anchorKeyPrefix == "universal.")
        let src = try SourceLint.text("Maude/Ingestion/UniversalHealthReader.swift")
        #expect(!SourceLint.matches(#"anchorKeyPrefix \+ type\.identifier"#, in: src).isEmpty)
        #expect(SourceLint.matches(#"key:\s*type\.identifier"#, in: src).isEmpty)
    }

    // T-UNI-07 — structural isolation, both directions. The universal files
    // never construct the tuned pipelines' value types or call their
    // coordinators (universal rows cannot flow INTO derivers/nudges), and the
    // tuned pipeline files never reference the universal layer's types
    // (derivers cannot fetch universal rows). Comments are skipped, so history
    // notes can name things freely.
    @Test func sourceLintIsolationBothDirections() throws {
        let universalFiles = ["Maude/Ingestion/UniversalHealthReader.swift",
                              "Maude/Ingestion/UniversalSamples.swift"]
        // Construction/coordination of tuned-pipeline types. `DailyRollup` is
        // deliberately ALLOWED — it is the shared pure day rule (FR-ING-17),
        // not a pipeline.
        let intoTuned = #"HealthSamples\(|GlucoseReading\(|SleepReading\(|DailyMetric\(|BodyCompositionReading\(|WristTemperatureReading\(|SourceArbiter|IngestionCoordinator|TodaySignalsDeriver|SleepDeriver"#
        for f in universalFiles {
            let src = try SourceLint.text(f)
            #expect(SourceLint.matches(intoTuned, in: src).isEmpty,
                    "universal file references a tuned pipeline: \(f)")
        }
        // Reverse: the pipeline layers never touch universal types.
        let universalTypes = #"UniversalSampleRow|UniversalHealthStore|UniversalHealthReader|UniversalRowValue|UniversalBrowse|UniversalTypeCatalog"#
        for dir in ["Maude/Intelligence", "Maude/Health"] {
            for (path, src) in SourceLint.swiftFiles(in: dir) {
                #expect(SourceLint.matches(universalTypes, in: src).isEmpty,
                        "tuned layer references the universal layer: \(path)")
            }
        }
        for (path, src) in SourceLint.swiftFiles(in: "Maude/Ingestion")
        where !universalFiles.contains(path) {
            #expect(SourceLint.matches(universalTypes, in: src).isEmpty,
                    "tuned ingestion references the universal layer: \(path)")
        }
    }

    // T-UNI-08 — read-only stance: the reader's authorization request shares
    // NOTHING (empty toShare set), structurally, like FR-ARCH-04.
    @Test func readerNeverWritesToHealthKit() throws {
        let src = try SourceLint.text("Maude/Ingestion/UniversalHealthReader.swift")
        #expect(!SourceLint.matches(#"requestAuthorization\(toShare:\s*\[\]"#, in: src).isEmpty)
        #expect(SourceLint.matches(#"\.save\(.*HKObject|store\.save\("#, in: src).isEmpty)
    }
}
#endif

// MARK: - T-UNI-09 · erase clears the universal store

struct UniversalEraseTests {

    // T-UNI-09 — the erase unit `UniversalHealthStore.erase(in:)` (the body of
    // the reported one-line AppState.deleteAllData hook) removes every row.
    // In-memory container: no disk, no encryption, no system store.
    @Test @MainActor func eraseRemovesEveryUniversalRow() throws {
        let container = try UniversalHealthStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let day = Date(timeIntervalSince1970: 1_755_400_000)
        for i in 0..<3 {
            context.insert(UniversalSampleRow(
                hkUUID: UUID(), typeID: "HKQuantityTypeIdentifierTimeInDaylight",
                kindRaw: UniversalSampleKind.quantity.rawValue,
                value: Double(i), unit: "min", start: day, end: day,
                sourceName: "Watch", sourceBundleID: "com.apple.health",
                deviceName: nil, isCumulative: true,
                provenanceRaw: Provenance.real.rawValue))
        }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<UniversalSampleRow>()) == 3)

        try UniversalHealthStore.erase(in: context)
        #expect(try context.fetchCount(FetchDescriptor<UniversalSampleRow>()) == 0)
    }
}

// MARK: - T-UNI-10..12 · pure browse derivation (DailyRollup + DaySeries rules)

struct UniversalBrowseTests {

    private let cal = Calendar(identifier: .gregorian)
    private var d0: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_755_400_000)) }
    private func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: d0)! }

    private func q(_ v: Double, day d: Date, source: String,
                   cumulative: Bool = true) -> UniversalRowValue {
        UniversalRowValue(typeID: "HKQuantityTypeIdentifierPushCount", kind: .quantity,
                          value: v, unit: "count", start: d, end: d,
                          source: source, isCumulative: cumulative)
    }

    // T-UNI-10 — cumulative day values follow FR-ING-17: two sources logging
    // the same day yield the best-covering source's total, never a cross-source
    // sum; a day only one device saw keeps that device's total; unrecorded days
    // are nil slots (gaps), never zero.
    @Test func cumulativeDaysNeverSumAcrossSources() {
        let rows = [q(5200, day: day(0), source: "Watch"),
                    q(2800, day: day(0), source: "Watch"),
                    q(5000, day: day(0), source: "iPhone"),
                    q(4200, day: day(1), source: "iPhone")]
        let out = UniversalBrowse.summaries(rows: rows, today: day(13))
        #expect(out.count == 1)
        let s = out[0]
        #expect(s.slots.count == 14)
        #expect(s.slots[0].value == 8000)         // watch total, NOT 13 000
        #expect(s.slots[1].value == 4200)         // single-source day kept
        #expect(s.slots[2].value == nil)          // gap stays a gap
        #expect(s.count == 4)
        #expect(Set(s.sources) == ["Watch", "iPhone"])
    }

    // T-UNI-11 — discrete (mean) kinds average within a day; the latest value
    // and unit come from the newest row.
    @Test func discreteDaysAverage() {
        let rows = [q(60, day: day(0), source: "Watch", cumulative: false),
                    q(64, day: day(0), source: "Oura", cumulative: false)]
        let out = UniversalBrowse.summaries(rows: rows, today: day(0))
        #expect(out[0].slots.last?.value == 62)
        #expect(out[0].unit == "count")
    }

    // T-UNI-12 — category types chart ENTRIES per day (a tally of records —
    // the only honest magnitude an enum-coded sample has), and known severity
    // codes decode to HealthKit's own words, never to a Maude judgment.
    @Test func categoryTypesTallyEntriesAndDecodeRecordedValues() {
        let rows = [
            UniversalRowValue(typeID: "HKCategoryTypeIdentifierHeadache", kind: .category,
                              value: 3, unit: "", start: day(0), end: day(0),
                              source: "Health", isCumulative: false),
            UniversalRowValue(typeID: "HKCategoryTypeIdentifierHeadache", kind: .category,
                              value: 2, unit: "", start: day(0).addingTimeInterval(3600),
                              end: day(0).addingTimeInterval(3600),
                              source: "Health", isCumulative: false),
        ]
        let out = UniversalBrowse.summaries(rows: rows, today: day(0))
        #expect(out[0].chartsEntries)
        #expect(out[0].slots.last?.value == 2)     // two entries that day
        #expect(out[0].latestLabel == "Mild")      // HKCategoryValueSeverity 2, decoded
        #expect(UniversalBrowse.categoryValueLabel(
            typeID: "HKCategoryTypeIdentifierHeadache", value: 4, kind: .category) == "Severe")
        #expect(UniversalBrowse.categoryValueLabel(
            typeID: "HKCategoryTypeIdentifierMindfulSession", value: 0, kind: .category) == nil)
    }

    // T-UNI-13 — display names are a mechanical split of Apple's identifier.
    @Test func displayNamesAreMechanical() {
        #expect(UniversalBrowse.displayName(forTypeID: "HKQuantityTypeIdentifierTimeInDaylight")
                == "Time In Daylight")
        #expect(UniversalBrowse.displayName(forTypeID: "HKCategoryTypeIdentifierHandwashingEvent")
                == "Handwashing Event")
        #expect(UniversalBrowse.displayName(forTypeID: "HKQuantityTypeIdentifierVO2Max")
                == "VO2 Max")
    }
}

// MARK: - T-UNI-14 · the browser renders values, never verdicts (source lint)

struct UniversalBrowserLintTests {

    /// Judgment vocabulary that must NOT exist in the browser's user-facing
    /// copy: the surface renders recorded values; it never assesses them
    /// (FR-NDG-06 stays clean because no sentences are generated).
    private static let judgmentLexicon =
        #"(?i)\b(good|bad|poor|normal|abnormal|healthy|unhealthy|risk|risky|"#
        + #"improve|improving|worse|better|warning|alert|elevated|optimal|"#
        + #"unusual|excessive|too high|too low|high|low)\b"#

    // T-UNI-14 — no judgment word appears in any string literal of the browser
    // file, and no NudgeGuard/verdict machinery is wired into it.
    @Test func browserCopyContainsNoJudgment() throws {
        let src = try SourceLint.text("Maude/Views/DataBrowserView.swift")
        for (n, line) in SourceLint.codeLines(src) {
            var search = line.startIndex
            while let r = line.range(of: #""(?:[^"\\]|\\.)*""#,
                                     options: .regularExpression,
                                     range: search..<line.endIndex) {
                let literal = String(line[r])
                #expect(literal.range(of: Self.judgmentLexicon,
                                      options: .regularExpression) == nil,
                        "judgment vocabulary in DataBrowserView.swift:\(n): \(literal)")
                search = r.upperBound
            }
        }
        #expect(SourceLint.matches(#"guarded\(|NudgeGuard|verdict"#, in: src).isEmpty)
    }
}
