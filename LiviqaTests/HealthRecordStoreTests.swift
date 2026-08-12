import Testing
import Foundation
import SwiftData
@testable import Liviqa

// T-REC-01 / T-REC-02 — FR-REC-01 (canonical on-device record store) and
// FR-REC-02 (diagnoses presentation).
//
// T-REC-01 is behavioural: a real in-memory SwiftData container, the real
// `HealthStore`, the real `ingest()`. The two properties that matter to a
// citizen re-importing the same record every few weeks:
//   · DEDUP — one row per logical reading PER SOURCE, so a re-import doesn't
//     grow the record, and the same reading arriving from two sources is shown
//     ONCE while both rows keep their own provenance.
//   · SUPERSESSION — a newer value from the same source replaces the older one
//     rather than sitting beside it; a reading from an earlier DAY is kept as
//     history, and the newest one is what the record leads with.
//
// T-REC-02 covers the diagnoses presentation: tiering is a GROUPING, never a
// filter (the full list stays reachable), and the copy around it interprets
// nothing — cross-checked against the FR-NDG-06 designated control, and against
// the nudge engine having no knowledge of the record at all.
@MainActor
struct HealthRecordStoreTests {

    // MARK: - Fixtures

    /// Fresh in-memory store per test. `ModelContext` retains its container, so
    /// the store alone keeps the whole stack alive.
    private func makeStore() throws -> HealthStore {
        HealthStore(context: ModelContext(try LiviqaStore.makeContainer(inMemory: true)))
    }

    /// A stable local noon, so day-offset fixtures land on unambiguous days.
    private static let noon = Calendar.current
        .startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        .addingTimeInterval(12 * 3600)

    private func day(_ ago: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -ago, to: Self.noon) ?? Self.noon
    }

    /// `source` is deliberately wrong here — `ingest()` is authoritative and must
    /// stamp the real one, which one of the tests below checks.
    private func obs(_ key: String, _ value: Double, ago: Int = 0,
                     unit: String = "mmol/mol") -> HealthObservation {
        HealthObservation(scopeKey: key, value: value, unit: unit,
                          effectiveDate: day(ago), source: "unstamped")
    }
    private func cond(_ icd10: String, label: String? = nil) -> HealthCondition {
        HealthCondition(icd10: icd10, label: label, source: "unstamped")
    }
    private func med(atc: String?, _ name: String) -> HealthMedication {
        HealthMedication(atc: atc, name: name, source: "unstamped")
    }

    private func rows<T: PersistentModel>(_ store: HealthStore, _ type: T.Type) throws -> [T] {
        try store.context.fetch(FetchDescriptor<T>())
    }

    // MARK: - T-REC-01 · dedup

    /// The same reading, ingested twice from the same source, stays one row.
    /// (A citizen who re-connects Sundhed.dk weekly must not accumulate copies.)
    @Test func reIngestingTheSameReadingFromOneSourceStaysOneRow() throws {
        let store = try makeStore()
        try store.ingest(observations: [obs("hba1c", 51)], conditions: [], medications: [],
                         source: .sundhedLive)
        try store.ingest(observations: [obs("hba1c", 51)], conditions: [], medications: [],
                         source: .sundhedLive)

        let stored = try rows(store, HealthObservation.self)
        #expect(stored.count == 1)
        #expect(store.latestObservations().count == 1)
    }

    /// The SAME observation arriving from TWO sources is counted once in the
    /// record the citizen reads, while both rows survive with their own source
    /// tag — provenance is never collapsed away.
    @Test func theSameObservationFromTwoSourcesIsCountedOnce() throws {
        let store = try makeStore()
        try store.ingest(observations: [obs("hba1c", 51)], conditions: [], medications: [],
                         source: .sundhedLive)
        try store.ingest(observations: [obs("hba1c", 52)], conditions: [], medications: [],
                         source: .sundhedPdf)

        let stored = try rows(store, HealthObservation.self)
        #expect(stored.count == 2, "both sources keep their own row")
        #expect(Set(stored.map(\.source)) == Set([HealthDataSource.sundhedLive.rawValue,
                                                  HealthDataSource.sundhedPdf.rawValue]))
        // …but the record shows the reading ONCE.
        let shown = store.latestObservations()
        #expect(shown.count == 1, "hba1c must appear once across sources, not twice")
        #expect(shown.first?.scopeKey == "hba1c")
    }

    /// Dedup is per (code, source) for diagnoses, and the research payload
    /// collapses the same code across sources to a single presence entry.
    @Test func conditionsDedupPerSourceAndCollapseAcrossSourcesForResearch() throws {
        let store = try makeStore()
        try store.ingest(observations: [], conditions: [cond("E11"), cond("E11")], medications: [],
                         source: .sundhedLive)
        let afterSameSource = try rows(store, HealthCondition.self)
        #expect(afterSameSource.count == 1, "same code, same source → one row")

        try store.ingest(observations: [], conditions: [cond("E11")], medications: [],
                         source: .sundhedPdf)
        let afterSecondSource = try rows(store, HealthCondition.self)
        #expect(afterSecondSource.count == 2, "a second source keeps its own row")

        let body = store.researchPayload(citizenId: "c-1")
        #expect(body.metrics.conditions?.summary.codedDist["E11"] == 1,
                "presence semantics: one entry per code regardless of how many sources filed it")
        #expect(body.metrics.conditions?.summary.count == 1)
    }

    /// Medications dedup on the ATC code when present, on the name otherwise —
    /// so the same product under two brand spellings is one row, and two real
    /// medicines stay two rows.
    @Test func medicationsDedupByAtcThenName() throws {
        let store = try makeStore()
        try store.ingest(observations: [], conditions: [],
                         medications: [med(atc: "A10BA02", "Metformin"),
                                       med(atc: "A10BA02", "Metformin Actavis")],
                         source: .sundhedLive)
        let coded = try rows(store, HealthMedication.self)
        #expect(coded.count == 1, "same ATC, same source → one row")
        #expect(coded.first?.name == "Metformin Actavis", "the later row supersedes the earlier name")

        try store.ingest(observations: [], conditions: [],
                         medications: [med(atc: nil, "Paracetamol"), med(atc: nil, "paracetamol")],
                         source: .sundhedLive)
        let withUncoded = try rows(store, HealthMedication.self)
        #expect(withUncoded.count == 2, "an uncoded medicine dedups case-insensitively by name")

        try store.ingest(observations: [], conditions: [],
                         medications: [med(atc: "B01AF02", "Apixaban")],
                         source: .sundhedLive)
        let withSecondCode = try rows(store, HealthMedication.self)
        #expect(withSecondCode.count == 3, "a different ATC is a different medicine")
    }

    // MARK: - T-REC-01 · supersession

    /// A corrected value for the SAME day and source replaces the old one in
    /// place — the record must not show both 51 and 48 as if they were two
    /// separate results.
    @Test func aNewerValueSupersedesTheOlderOneFromTheSameSource() throws {
        let store = try makeStore()
        try store.ingest(observations: [obs("hba1c", 51)], conditions: [], medications: [],
                         source: .sundhedLive)
        let firstImport = try #require(try rows(store, HealthObservation.self).first?.importedAt)

        try store.ingest(observations: [obs("hba1c", 48)], conditions: [], medications: [],
                         source: .sundhedLive)

        let stored = try rows(store, HealthObservation.self)
        #expect(stored.count == 1, "supersession replaces, it does not append")
        #expect(stored.first?.value == 48, "the newer value wins")
        #expect((stored.first?.importedAt ?? .distantPast) >= firstImport, "importedAt is refreshed")
        #expect(store.latestObservations().first?.value == 48)
    }

    /// A reading from an EARLIER day is history, not a duplicate: both rows are
    /// kept, the newest leads the record, and the earlier one is retrievable as
    /// the citizen's own previous value (never a population band).
    @Test func anEarlierDayIsKeptAsHistoryAndTheNewestLeads() throws {
        let store = try makeStore()
        try store.ingest(observations: [obs("hba1c", 55, ago: 90)], conditions: [], medications: [],
                         source: .sundhedLive)
        try store.ingest(observations: [obs("hba1c", 48, ago: 0)], conditions: [], medications: [],
                         source: .sundhedLive)

        let stored = try rows(store, HealthObservation.self)
        #expect(stored.count == 2, "different days are different readings")
        #expect(store.latestObservations().first?.value == 48, "the newest reading leads")

        let prior = store.priorObservation(scopeKey: "hba1c", before: day(0))
        #expect(prior?.value == 55, "the previous reading is the citizen's own earlier value")
        #expect(store.priorObservation(scopeKey: "hba1c", before: day(120)) == nil,
                "no earlier reading → nil, so the caller says so plainly instead of inventing one")
    }

    /// `ingest()` is authoritative about provenance: every row is stamped with
    /// the ingesting source, whatever the mapper set.
    @Test func ingestStampsTheSourceOnEveryRow() throws {
        let store = try makeStore()
        try store.ingest(observations: [obs("hba1c", 51)], conditions: [cond("E11")],
                         medications: [med(atc: "A10BA02", "Metformin")], source: .paperScan)

        let expected = HealthDataSource.paperScan.rawValue
        let o = try rows(store, HealthObservation.self)
        let c = try rows(store, HealthCondition.self)
        let m = try rows(store, HealthMedication.self)
        #expect(o.allSatisfy { $0.source == expected })
        #expect(c.allSatisfy { $0.source == expected })
        #expect(m.allSatisfy { $0.source == expected })
    }

    /// The real mapper (the one both Sundhed paths use) produces canonical,
    /// coded rows — catalog scopeKeys, uppercased ICD-10, ATC — and round-trips
    /// through ingest into the record the citizen reads.
    @Test func canonicalizeMapsADerivedSummaryIntoCodedRows() throws {
        let store = try makeStore()
        let summary = SundhedDerivedSummary(
            labs: [SundhedDerivedSummary.LabRow(catalogVar: "hba1c", component: "HbA1c",
                                                latest: 48, mean: 50, unit: "mmol/mol", n: 2)],
            meds: [SundhedDerivedSummary.MedRow(atc: "A10BA02", brand: "Metformin",
                                                substance: "metformin")],
            unmappedMeds: [],
            conditions: [SundhedDerivedSummary.ConditionRow(code: "e11")]
        )
        let mapped = HealthStore.canonicalize(summary, source: .sundhedPdf, at: day(0))
        try store.ingest(observations: mapped.obs, conditions: mapped.cond,
                         medications: mapped.med, source: .sundhedPdf)

        let o = try #require(store.latestObservations().first)
        #expect(o.scopeKey == "hba1c")
        #expect(o.value == 48, "the LATEST reading, not the mean, is the stored value")
        #expect(o.mpcScaled == Int((48 * SundhedParsers.scaleFactor(for: "hba1c")).rounded()))
        #expect(store.conditions().first?.icd10 == "E11", "codes are normalised to upper case")
        #expect(store.medications().first?.atc == "A10BA02")
    }

    // MARK: - T-REC-02 · display-only, tiered, no interpretation

    /// Tiering is a GROUPING decision on the citizen's own journal codes —
    /// ongoing conditions lead, injuries/symptoms/admin codes sit below. No
    /// clinical judgement is applied beyond the ICD-10 chapter.
    @Test func conditionTierGroupsWithoutInterpreting() {
        let cases: [(String, HealthDisplay.ConditionTier)] = [
            ("E11",   .major),      // type 2 diabetes — ongoing
            ("I48",   .major),      // rhythm record
            ("J44",   .major),      // COPD — chronic, not an acute J-code
            ("M420",  .major),
            ("DE104", .major),      // Danish SKS prefix normalises to E104
            ("Z03",   .admin),      // contact / administrative
            ("U071",  .admin),
            ("S82",   .pastMinor),  // injury
            ("T78",   .pastMinor),
            ("R51",   .pastMinor),  // symptom, not a disease
            ("B34",   .pastMinor),  // acute infection
            ("J06",   .pastMinor),  // acute respiratory infection
            ("N39",   .pastMinor),
            ("H660",  .pastMinor),
            ("K52",   .pastMinor),
        ]
        for (code, expected) in cases {
            #expect(HealthDisplay.conditionTier(for: code) == expected, "tier for \(code)")
        }
    }

    /// Presentation-only: the store never filters by tier, so the FULL untiered
    /// list stays reachable — including the entries the passport collapses into
    /// its secondary group. Hiding a citizen's own record entry would not be a
    /// display choice, it would be withholding their data.
    @Test func tieringNeverHidesAnEntryFromTheRecord() throws {
        let store = try makeStore()
        try store.ingest(observations: [],
                         conditions: [cond("E11"), cond("S82"), cond("Z03")],
                         medications: [], source: .sundhedLive)

        let all = store.conditions()
        #expect(all.count == 3, "every filed code is returned, whatever its tier")
        #expect(Set(all.map(\.icd10)) == Set(["E11", "S82", "Z03"]))

        let report = store.summaryReport()
        for code in ["E11", "S82", "Z03"] {
            #expect(report.contains(code), "the shareable summary must list \(code)")
        }
        #expect(report.contains("Past, minor & administrative entries"),
                "the lower-tier entries are grouped under their own heading, not dropped")
        #expect(report.contains(HealthDisplay.diagnosesExplainer),
                "the diagnoses list always carries its explainer")
    }

    /// DISPLAY-ONLY means the copy states what the journal says and nothing
    /// more. Every string the diagnoses surface can emit is run through the
    /// FR-NDG-06 designated control: no diagnostic claim, no normality verdict,
    /// no treatment directive may enter the record presentation by the back door.
    @Test func diagnosisPresentationCarriesNoClinicalInterpretation() {
        var copy: [String] = [HealthDisplay.diagnosesExplainer]

        // Codes with hand-written notes, one per tier-generic branch, and one
        // per ICD-10 chapter letter (exercising the chapter fallback).
        let codes = ["M420", "M42", "C759", "K429", "K42", "I489",
                     "E102", "E103", "E104", "E105", "E107", "E108", "G632", "H360",
                     "Z03", "S82", "R51", "E11"]
            + "ABCDEFGHIJKLMNOPQRSTUZ".map { "\($0)50" }

        for code in codes {
            copy.append(HealthDisplay.conditionName(for: code))
            if let context = HealthDisplay.conditionContext(for: code) { copy.append(context) }
        }

        for text in copy {
            let violation = NudgeGuard.check(text)
            #expect(violation == nil,
                    "diagnoses copy must not interpret (\(violation?.rawValue ?? "")): \"\(text)\"")
        }
    }

    /// The diagnoses record must not couple into the nudge engine: FR-NDG-06's
    /// guard is only meaningful while the engine cannot reason from a diagnosis.
    /// Source-lint — the regression is a REFERENCE to the record types from the
    /// intelligence layer, which no runtime assertion can observe.
    @Test func theRecordIsNotVisibleToTheNudgeEngine() {
        let forbidden = ["HealthCondition", "healthConditions", "conditionTier",
                         "HealthObservation", "healthObservations", "HealthStore", "icd10"]
        var hits: [String] = []
        for file in SourceLint.swiftFiles(in: "Liviqa/Intelligence") {
            for (n, line) in SourceLint.codeLines(file.source) {
                for token in forbidden where line.contains(token) {
                    hits.append("\(file.path):\(n) — \(token)")
                }
            }
        }
        #expect(hits.isEmpty,
                "the nudge engine must stay blind to the health record (FR-NDG-06): \(hits)")
    }
}
