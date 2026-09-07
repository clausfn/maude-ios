import Testing
import Foundation
import SwiftData
@testable import Maude

// T-EXP-01 / T-EXP-02 — FR-EXP-01 (record-quality export), defects A + B.
//
// (A) DATES: Sundhed-imported lab observations must carry the SPECIMEN/result
//     date, not the pull/import date. The parsers already read per-row dates;
//     the defect was `summarise()` flattening them away and `canonicalize()`
//     substituting Date() — the import date rendered as if it were the
//     specimen date. These tests pin the whole pipeline: parse → summarise
//     (readings keep dates) → canonicalize (specimenDate = the real date;
//     absent dates stay nil — NEVER the import date).
//
// (B) TYPING: a qualitative screen ("Negativ", "Ikke påvist") is stored as a
//     typed, worded result — never a numeric 0 + unit; zero-duration collection
//     rows are flagged artifacts and stay out of numeric surfaces and the
//     research payload.
@MainActor
struct SundhedRecordIntegrityTests {

    private func makeStore() throws -> HealthStore {
        HealthStore(context: ModelContext(try MaudeStore.makeContainer(inMemory: true)))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return cal.date(from: comps)!
    }

    // MARK: - (A) Path B: parse keeps real specimen dates

    @Test func parseLabsPreservesPerRowSpecimenDates() {
        let text = """
        Hæmatologi
        Hæmoglobin;B / mmol/L
        8,5  21.03.2024
        8,9  03.11.2023
        """
        let labs = SundhedParsers.parseLabs(text)
        #expect(labs.count == 2)
        #expect(labs[0].date != nil)
        #expect(labs[1].date != nil)
        let cal = Calendar(identifier: .iso8601)
        #expect(cal.component(.year, from: labs[0].date!) == 2024)
        #expect(cal.component(.year, from: labs[1].date!) == 2023)
    }

    @Test func parseLabsRowWithoutDateStaysNilNeverInvented() {
        let text = """
        Hæmoglobin;B / mmol/L
        8,5
        """
        let labs = SundhedParsers.parseLabs(text)
        #expect(labs.count == 1)
        #expect(labs[0].date == nil)
    }

    @Test func summariseCarriesReadingsNewestFirstWithTheirDates() {
        let text = """
        Hæmoglobin;B / mmol/L
        8,9  03.11.2023
        8,5  21.03.2024
        """
        let summary = SundhedPayloadBuilder.summarise(
            labs: SundhedParsers.parseLabs(text), meds: [], diagnoses: [])
        let row = try! #require(summary.labs.first)
        #expect(row.readings.count == 2)
        // Newest first, each with its OWN date.
        let cal = Calendar(identifier: .iso8601)
        #expect(cal.component(.year, from: row.readings[0].date!) == 2024)
        #expect(cal.component(.year, from: row.readings[1].date!) == 2023)
        #expect(row.readings[0].value == 8.5)
        #expect(row.readings[1].value == 8.9)
    }

    @Test func canonicalizeStampsTheRealSpecimenDateNotTheImportDate() {
        let importDay = date(2026, 8, 10)
        let text = """
        Hæmoglobin;B / mmol/L
        8,5  21.03.2024
        """
        let summary = SundhedPayloadBuilder.summarise(
            labs: SundhedParsers.parseLabs(text), meds: [], diagnoses: [])
        let rows = HealthStore.canonicalize(summary, source: .sundhedPdf, at: importDay)
        let o = try! #require(rows.obs.first)
        // The REAL date, on both fields — never the import day.
        #expect(o.specimenDate != nil)
        let cal = Calendar(identifier: .iso8601)
        #expect(cal.component(.year, from: o.specimenDate!) == 2024)
        #expect(cal.component(.year, from: o.effectiveDate) == 2024)
        #expect(!Calendar.current.isDate(o.effectiveDate, inSameDayAs: importDay))
    }

    @Test func canonicalizeKeepsAbsentDatesNilAndSaysSo() {
        let importDay = date(2026, 8, 10)
        let text = """
        Hæmoglobin;B / mmol/L
        8,5
        """
        let summary = SundhedPayloadBuilder.summarise(
            labs: SundhedParsers.parseLabs(text), meds: [], diagnoses: [])
        let rows = HealthStore.canonicalize(summary, source: .sundhedPdf, at: importDay)
        let o = try! #require(rows.obs.first)
        // Genuinely undated: specimenDate stays nil (effectiveDate only orders),
        // and the DISPLAY says "date not recorded" — not the import date.
        #expect(o.specimenDate == nil)
        #expect(HealthSummaryDocument.dateText(for: o) == HealthSummaryDocument.noDateText)
    }

    @Test func canonicalizeEmitsOneRowPerReadingSoHistorySurvives() throws {
        let text = """
        Hæmoglobin;B / mmol/L
        8,9  03.11.2023
        8,5  21.03.2024
        """
        let summary = SundhedPayloadBuilder.summarise(
            labs: SundhedParsers.parseLabs(text), meds: [], diagnoses: [])
        let rows = HealthStore.canonicalize(summary, source: .sundhedPdf)
        #expect(rows.obs.count == 2)

        let store = try makeStore()
        try store.ingest(observations: rows.obs, conditions: [], medications: [], source: .sundhedPdf)
        let history = store.observationHistory()["hemoglobin"] ?? []
        #expect(history.count == 2)
        #expect(history[0].value == 8.5)   // newest first
        #expect(history[1].value == 8.9)
    }

    // MARK: - (A) Path A: harvest readings keep their own dates

    @Test func harvestReadingsLandWithTheirOwnResultDates() {
        let harvest = SundhedWebHarvest(
            asOf: "2026-08-10T09:00:00Z",
            labs: [.init(component: "Hæmoglobin", specimen: "B", unit: "mmol/L",
                         latest: 8.5, mean: 8.7, n: 2, latestDate: "2024-03-21T08:00:00",
                         latestText: nil, refInterval: nil,
                         readings: [
                            .init(v: 8.5, d: "2024-03-21T08:00:00", t: nil),
                            .init(v: 8.9, d: "2023-11-03T08:00:00", t: nil),
                         ])],
            meds: [], conditions: [])
        let r = harvest.toParseResults()
        #expect(r.labs.count == 2)
        let cal = Calendar(identifier: .iso8601)
        #expect(cal.component(.year, from: r.labs[0].date!) == 2024)
        #expect(cal.component(.year, from: r.labs[1].date!) == 2023)
    }

    @Test func harvestDanishPrintedDatesStillParse() {
        let harvest = SundhedWebHarvest(
            asOf: "2026-08-10T09:00:00Z",
            labs: [.init(component: "Hæmoglobin", specimen: "B", unit: "mmol/L",
                         latest: 8.5, mean: 8.5, n: 1, latestDate: "21.03.2024",
                         latestText: nil, refInterval: nil, readings: nil)],
            meds: [], conditions: [])
        let r = harvest.toParseResults()
        #expect(r.labs.count == 1)
        #expect(r.labs[0].date != nil)
    }

    // MARK: - (B) Qualitative results are words, never 0 + unit

    @Test func parseLabsReadsQualitativeScreensAsWords() {
        let text = """
        Mikrobiologi
        Hepatitis B overflade antigen;P
        Ikke påvist  21.03.2024
        """
        let labs = SundhedParsers.parseLabs(text)
        #expect(labs.count == 1)
        let m = labs[0]
        #expect(m.kind == .qualitative)
        #expect(m.text == "Ikke påvist")
        #expect(m.date != nil)
        #expect(m.unit.isEmpty)     // no unit ever attaches to a worded result
    }

    @Test func qualitativeSourceWordingMapsToEnglishDisplayWords() {
        #expect(SundhedParsers.qualitativeDisplayWord("Ikke påvist") == "Not detected")
        #expect(SundhedParsers.qualitativeDisplayWord("Negativ") == "Negative")
        #expect(SundhedParsers.qualitativeDisplayWord("Positiv") == "Positive")
        #expect(SundhedParsers.qualitativeDisplayWord("Påvist") == "Detected")
        // Unknown wording renders as the source wrote it — never invented.
        #expect(SundhedParsers.qualitativeDisplayWord("Se svar") == "Se svar")
    }

    @Test func harvestZeroEncodedNegativeScreenBecomesQualitative() {
        // Sundhed encodes some negative screens as Vaerdi=0 + "Negativ" — the
        // exact rows that rendered as "0 <unit>" in the exported summary.
        let harvest = SundhedWebHarvest(
            asOf: "2026-08-10T09:00:00Z",
            labs: [.init(component: "HIV antistof/antigen", specimen: "P", unit: nil,
                         latest: 0, mean: 0, n: 1, latestDate: "2024-03-21T08:00:00",
                         latestText: "Negativ", refInterval: nil,
                         readings: [.init(v: 0, d: "2024-03-21T08:00:00", t: "Negativ")])],
            meds: [], conditions: [])
        let r = harvest.toParseResults()
        #expect(r.labs.count == 1)
        #expect(r.labs[0].kind == .qualitative)
        #expect(r.labs[0].text == "Negativ")
    }

    @Test func harvestValuelessWordedResultBecomesQualitative() {
        let harvest = SundhedWebHarvest(
            asOf: "2026-08-10T09:00:00Z",
            labs: [.init(component: "Borrelia antistof (IgG)", specimen: "P", unit: nil,
                         latest: nil, mean: nil, n: 1, latestDate: "2024-03-21T08:00:00",
                         latestText: "Ikke påvist", refInterval: nil, readings: nil)],
            meds: [], conditions: [])
        let r = harvest.toParseResults()
        #expect(r.labs.count == 1)
        #expect(r.labs[0].kind == .qualitative)
    }

    @Test func qualitativeRowsNeverEnterNumericAggregates() {
        let text = """
        Hepatitis B overflade antigen;P
        Ikke påvist  21.03.2024
        """
        let labs = SundhedParsers.parseLabs(text)
        let body = SundhedPayloadBuilder.build(citizenID: "c1", labs: labs, meds: [], diagnoses: [])
        // No labs block at all — a worded result is not a number.
        #expect(body.metrics.labs == nil)
        #expect(body.counts?["labs"] == 0)
    }

    // MARK: - (B) Collection artifacts

    @Test func zeroMinuteCollectionRowIsFlaggedArtifact() {
        let text = """
        Urin opsamlingstid;Pt(U) / min
        0  21.03.2024
        """
        let labs = SundhedParsers.parseLabs(text)
        #expect(labs.count == 1)
        #expect(labs[0].kind == .artifact)
        #expect(labs[0].specimen == "Pt(U)")   // full token, not truncated to "P"
    }

    @Test func genuineZeroCountStaysQuantitative() {
        // Basophils 0,00 × 10⁹/L is a REAL result — the artifact rule must not
        // swallow it.
        #expect(!SundhedParsers.isCollectionArtifact(component: "Basofilocytter", unit: "10^9/L", value: 0))
        #expect(SundhedParsers.isCollectionArtifact(component: "Urin opsamlingstid", unit: "min", value: 0))
        #expect(!SundhedParsers.isCollectionArtifact(component: "Urin opsamlingstid", unit: "min", value: 720))
    }

    // MARK: - (B) Store surfaces: typed rows gate every numeric display

    @Test func storeKeepsQualitativeRowsOutOfNumericSurfacesAndResearch() throws {
        let store = try makeStore()
        let obs = [
            HealthObservation(scopeKey: "hba1c", value: 6.8, unit: "%",
                              effectiveDate: date(2026, 3, 12), source: "x",
                              specimenDate: date(2026, 3, 12),
                              resultKind: SundhedResultKind.quantitative.rawValue),
            HealthObservation(scopeKey: "Hepatitis B overflade antigen;P", value: 0, unit: "",
                              effectiveDate: date(2026, 3, 12), source: "x",
                              specimenDate: date(2026, 3, 12),
                              resultKind: SundhedResultKind.qualitative.rawValue,
                              resultText: "Ikke påvist", specimen: "P"),
            HealthObservation(scopeKey: "Urin opsamlingstid;Pt(U)", value: 0, unit: "min",
                              effectiveDate: date(2026, 3, 12), source: "x",
                              specimenDate: date(2026, 3, 12),
                              resultKind: SundhedResultKind.artifact.rawValue, specimen: "Pt(U)"),
        ]
        try store.ingest(observations: obs, conditions: [], medications: [], source: .sundhedLive)

        // Numeric surface: only the quantitative row.
        let latest = store.latestObservations()
        #expect(latest.count == 1)
        #expect(latest.first?.scopeKey == "hba1c")

        // History: qualitative included (words), artifact excluded by default.
        let history = store.observationHistory()
        #expect(history["Hepatitis B overflade antigen;P"]?.first?.kind == .qualitative)
        #expect(history["Urin opsamlingstid;Pt(U)"] == nil)
        #expect(store.artifactObservations().count == 1)

        // Research payload: no qualitative/artifact zeros anywhere.
        let body = store.researchPayload(citizenId: "c1")
        #expect(body.metrics.labs?.summary.byVariable.keys.contains("hba1c") == true)
        #expect(body.metrics.labs?.summary.byVariable.count == 1)
    }

    // MARK: - (C) Entities decoded at parse time

    @Test func parseMedsDecodesHTMLEntitiesInDrugNames() {
        let line = "Novorapid&#32FlexPen (Insulin aspart) / Injektionsvæske / Efter aftale / Mod diabetes"
        let meds = SundhedParsers.parseMeds(line)
        #expect(meds.count == 1)
        #expect(meds[0].brand == "Novorapid FlexPen")
        #expect(!meds[0].brand.contains("&#"))
    }

    @Test func harvestMedsDecodeEntitiesToo() {
        let harvest = SundhedWebHarvest(
            asOf: "2026-08-10T09:00:00Z", labs: [],
            meds: [.init(activeSubstance: "Insulin&#32aspart", brand: "Novorapid&#32FlexPen",
                         atc: nil, form: nil, startDate: nil)],
            conditions: [])
        let r = harvest.toParseResults()
        #expect(r.meds.first?.brand == "Novorapid FlexPen")
        #expect(r.meds.first?.activeSubstance == "Insulin aspart")
        // The crosswalk still resolves the decoded substance.
        #expect(r.meds.first?.atc == "A10AB01")
    }

    // MARK: - Regression: the existing quantitative path is unchanged

    @Test func hba1cConversionAndDateSurviveTogether() {
        let text = """
        HbA1c(IFCC);Hb(B) / mmol/mol
        51  21.03.2024
        """
        let labs = SundhedParsers.parseLabs(text)
        #expect(labs.count == 1)
        #expect(labs[0].catalogVar == "hba1c")
        #expect(labs[0].unit == "%")
        #expect(abs(labs[0].value - 6.8) < 0.05)
        #expect(labs[0].date != nil)
        #expect(labs[0].specimen == "Hb(B)")
    }

    @Test func pathBKeepsUnmappedAnalytesAsPassthrough() {
        let text = """
        Basofilocytter;B / 10^9/L
        0,02  21.03.2024
        """
        let labs = SundhedParsers.parseLabs(text)
        #expect(labs.count == 1)
        #expect(labs[0].catalogVar == "Basofilocytter;B")
        #expect(labs[0].kind == .quantitative)
        #expect(labs[0].value == 0.02)
    }
}
