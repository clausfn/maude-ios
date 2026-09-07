import Testing
import Foundation
import SwiftData
@testable import Maude

// T-EXP-04 — FR-EXP-01: the redesigned exported health summary (defect D).
//
// The document model is built from a SYNTHETIC fixture record (invented,
// plausible values — no real citizen data) and asserted structurally: panel
// grouping, newest-first ordering with REAL dates, personal priors, qualitative
// words, artifact exclusion, honest header/source stamps, no judgements
// (framing strings pass the FR-NDG-06 designated control), and a GOLDEN test
// of the full plain-text rendering.
@MainActor
struct HealthSummaryDocumentTests {

    // MARK: - Fixture (synthetic; deterministic dates + importedAt)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return cal.date(from: comps)!
    }

    /// A store seeded DIRECTLY (fixed importedAt, no ingest stamping) so the
    /// rendered document is byte-deterministic.
    private func fixtureStore() throws -> HealthStore {
        let store = HealthStore(context: ModelContext(try MaudeStore.makeContainer(inMemory: true)))
        let pull = date(2026, 8, 10)                       // the Sundhed.dk pull
        let sundhed = HealthDataSource.sundhedLive.rawValue
        let manual = HealthDataSource.manual.rawValue

        func obs(_ key: String, _ v: Double, _ unit: String, _ specimen: Date?,
                 kind: SundhedResultKind = .quantitative, text: String? = nil,
                 system: String? = nil, ref: String? = nil, source: String) -> HealthObservation {
            HealthObservation(scopeKey: key, value: v, unit: unit,
                              effectiveDate: specimen ?? pull, source: source,
                              importedAt: pull, specimenDate: specimen,
                              resultKind: kind.rawValue, resultText: text,
                              specimen: system, sourceRefInterval: ref)
        }

        let rows: [HealthObservation] = [
            // Metabolic — with history (prior value + date).
            obs("hba1c", 6.8, "%", date(2026, 3, 12), system: "Hb(B)", source: sundhed),
            obs("hba1c", 7.1, "%", date(2025, 11, 3), system: "Hb(B)", source: sundhed),
            obs("glucose", 6.1, "mmol/L", date(2026, 3, 12), system: "P",
                ref: "4,2–6,3", source: sundhed),
            // Lipids + kidney.
            obs("ldl_cholesterol", 2.1, "mmol/L", date(2026, 3, 12), system: "P", source: sundhed),
            obs("ldl_cholesterol", 2.6, "mmol/L", date(2025, 11, 3), system: "P", source: sundhed),
            obs("egfr", 88, "mL/min", date(2026, 3, 12), source: sundhed),
            // Passthrough blood count row (Danish name, genuine small value).
            obs("Basofilocytter;B", 0.02, "10^9/L", date(2026, 3, 12), system: "B", source: sundhed),
            // Undated sundhed row — must say "date not recorded", never the pull date.
            obs("Karbamid;P", 5.2, "mmol/L", nil, system: "P", source: sundhed),
            // Qualitative screen — words, never 0 + unit.
            obs("Hepatitis B overflade antigen;P", 0, "", date(2026, 3, 12),
                kind: .qualitative, text: "Ikke påvist", system: "P", source: sundhed),
            // Collection artifact — excluded, listed in the appendix.
            obs("Urin opsamlingstid;Pt(U)", 0, "min", date(2026, 3, 12),
                kind: .artifact, system: "Pt(U)", source: sundhed),
            // Manual vitals — key-values band only, never a lab panel row.
            obs("systolic_bp", 128, "mmHg", nil, source: manual),
            obs("diastolic_bp", 82, "mmHg", nil, source: manual),
        ]
        for r in rows { store.context.insert(r) }

        store.context.insert(HealthCondition(
            icd10: "DE109", onsetDate: date(2019, 1, 1),
            source: sundhed, importedAt: pull))
        store.context.insert(HealthCondition(
            icd10: "DZ032", source: sundhed, importedAt: pull))

        store.context.insert(HealthMedication(
            atc: "A10AB01", name: "Novorapid&#32FlexPen", form: "Injektionsvæske",
            source: sundhed, importedAt: pull))
        store.context.insert(HealthMedication(
            atc: nil, name: "Magnesia", source: sundhed, importedAt: pull))

        try store.context.save()
        return store
    }

    private func fixtureDocument() throws -> HealthSummaryDocument {
        HealthSummaryDocument.build(store: try fixtureStore(),
                                    personName: "Astrid Eksempel",
                                    now: date(2026, 8, 15))
    }

    // MARK: - Header

    @Test func headerCarriesDeclaredNameGeneratedDateAndSourceFreshness() throws {
        let doc = try fixtureDocument()
        #expect(doc.personName == "Astrid Eksempel")
        #expect(doc.generatedText == "Generated 15 Aug 2026")
        // The pull date belongs HERE — one stamp per source.
        #expect(doc.sources.contains(HealthSummaryDocument.SourceStamp(
            label: "Sundhed.dk record as of 10 Aug 2026")))
        #expect(doc.includedText.contains("lab result"))
        #expect(doc.includedText.contains("2 diagnoses"))
        #expect(doc.includedText.contains("2 medicines"))
    }

    @Test func vitalsAreNotCountedOrListedAsLabResults() throws {
        let doc = try fixtureDocument()
        // 7 lab rows (2×hba1c, glucose, 2×ldl, egfr, basophils, urea, serology = 9
        // minus... counted explicitly): hba1c 2 + glucose 1 + ldl 2 + egfr 1 +
        // basophils 1 + urea 1 + serology 1 = 9. BP rows and the artifact excluded.
        #expect(doc.includedText.contains("9 lab results"))
        let allLineNames = doc.panels.flatMap { $0.lines.map(\.name) }
        #expect(!allLineNames.contains { $0.lowercased().contains("blood pressure") })
    }

    // MARK: - Page 1: diagnoses, medicines, key values

    @Test func majorDiagnosesLeadAndAdminEntriesMoveToTheAppendix() throws {
        let doc = try fixtureDocument()
        #expect(doc.majorDiagnoses.count == 1)
        #expect(doc.majorDiagnoses.first?.name == "Type 1 diabetes without complications")
        #expect(doc.majorDiagnoses.first?.code == "DE109")
        #expect(doc.majorDiagnoses.first?.sinceText == "since 2019")
        #expect(doc.appendixDiagnoses.count == 1)
        #expect(doc.appendixDiagnoses.first?.code == "DZ032")
    }

    @Test func medicinesAreCleanedAndCarryATC() throws {
        let doc = try fixtureDocument()
        let novo = try #require(doc.medicines.first { $0.atc == "A10AB01" })
        #expect(novo.name == "Novorapid FlexPen")       // "&#32" decoded even for legacy rows
        #expect(!novo.name.contains("&#"))
        let magnesia = try #require(doc.medicines.first { $0.name == "Magnesia" })
        #expect(magnesia.atc == nil)
    }

    @Test func keyValueBandLeadsWithTheClinicalHandful() throws {
        let doc = try fixtureDocument()
        let names = doc.keyValues.map(\.name)
        #expect(names == ["HbA1c", "Glucose", "LDL cholesterol", "eGFR", "Blood pressure"])
        let hba1c = doc.keyValues[0]
        #expect(hba1c.valueText == "6.8 %")
        #expect(hba1c.dateText == "12 Mar 2026")
        #expect(hba1c.priorText == "previous 7.1 % — 3 Nov 2025")
        // Undated manual BP renders its citizen-entered date honestly.
        #expect(doc.keyValues[4].valueText == "128/82 mmHg")
    }

    // MARK: - Panels

    @Test func labsGroupByClinicalPanelInFixedOrder() throws {
        let doc = try fixtureDocument()
        let titles = doc.panels.map(\.title)
        #expect(titles == ["Metabolic & glucose", "Lipids", "Kidney & electrolytes",
                           "Blood count", "Serology & screens"])
        let metabolic = doc.panels[0]
        #expect(metabolic.lines.map(\.name) == ["Glucose", "HbA1c"])
        let kidney = doc.panels[2]
        #expect(kidney.lines.map(\.name).contains("Urea"))     // "Karbamid;P" mapped
        let blood = doc.panels[3]
        #expect(blood.lines.map(\.name) == ["Basophils"])
    }

    @Test func entriesAreNewestFirstWithRealDatesAndPersonalPriors() throws {
        let doc = try fixtureDocument()
        let hba1c = try #require(doc.panels[0].lines.first { $0.name == "HbA1c" })
        #expect(hba1c.entries.count == 2)
        #expect(hba1c.entries[0].valueText == "6.8 %")
        #expect(hba1c.entries[0].dateText == "12 Mar 2026")
        #expect(hba1c.entries[1].valueText == "7.1 %")
        #expect(hba1c.entries[1].dateText == "3 Nov 2025")
        #expect(hba1c.specimenLabel == "blood")
    }

    @Test func undatedRowSaysDateNotRecordedNeverThePullDate() throws {
        let doc = try fixtureDocument()
        let urea = try #require(doc.panels.flatMap(\.lines).first { $0.name == "Urea" })
        #expect(urea.entries[0].dateText == "date not recorded")
        #expect(!urea.entries[0].dateText.contains("10 Aug 2026"))
    }

    @Test func qualitativeScreenRendersAsWordsNeverZeroPlusUnit() throws {
        let doc = try fixtureDocument()
        let serology = try #require(doc.panels.first { $0.title == "Serology & screens" })
        let screen = try #require(serology.lines.first)
        #expect(screen.entries[0].valueText == "Not detected")
        #expect(screen.entries[0].isQualitative)
        #expect(!screen.entries[0].valueText.contains("0"))
    }

    @Test func sourceReferenceIntervalShowsOnlyWhenCapturedAndLabelled() throws {
        let doc = try fixtureDocument()
        let glucose = try #require(doc.panels[0].lines.first { $0.name == "Glucose" })
        #expect(glucose.entries[0].sourceReference == "4,2–6,3")
        let egfr = try #require(doc.panels.flatMap(\.lines).first { $0.name == "eGFR" })
        #expect(egfr.entries[0].sourceReference == nil)
        // The rendered line labels it as the SOURCE's.
        #expect(doc.plainText().contains("source reference interval 4,2–6,3"))
    }

    @Test func artifactsAreExcludedFromPanelsAndListedInTheAppendix() throws {
        let doc = try fixtureDocument()
        let allNames = doc.panels.flatMap { $0.lines.map(\.name) }
        #expect(!allNames.contains("Urine collection time"))
        #expect(doc.excludedArtifactLines.count == 1)
        #expect(doc.excludedArtifactLines[0].contains("Urine collection time"))
    }

    // MARK: - Rails

    @Test func everyFramingStringPassesTheDesignatedControl() throws {
        // FR-NDG-06: the document contains no generated judgements — its fixed
        // framing copy must pass the nudge guard. (Result VALUES — including the
        // source's own wording like "Not detected" — are data, not sentences.)
        let framing = [
            HealthSummaryDocument.title,
            HealthSummaryDocument.noDateText,
            HealthSummaryDocument.diagnosesNote,
            HealthSummaryDocument.keyValuesTitle,
            HealthSummaryDocument.majorDiagnosesTitle,
            HealthSummaryDocument.medicinesTitle,
            HealthSummaryDocument.labsTitle,
            HealthSummaryDocument.appendixTitle,
            HealthSummaryDocument.artifactsTitle,
            HealthSummaryDocument.footer,
            HealthSummaryDocument.sourceReferencePrefix,
        ]
        let doc = try fixtureDocument()
        let dynamic = [doc.generatedText, doc.includedText] + doc.sources.map(\.label)
        for text in framing + dynamic {
            #expect(NudgeGuard.check(text) == nil, "framing failed the guard: \(text)")
        }
    }

    @Test func theDocumentNeverMentionsTheHiddenProvenanceField() throws {
        let text = try fixtureDocument().plainText()
        for forbidden in ["REAL", "SIMULATED", "EXTERNAL", "provenance"] {
            #expect(!text.contains(forbidden))
        }
    }

    @Test func summaryReportDelegatesToTheSameDocument() throws {
        let store = try fixtureStore()
        let report = store.summaryReport(personName: "Astrid Eksempel", now: date(2026, 8, 15))
        #expect(report == HealthSummaryDocument.build(
            store: store, personName: "Astrid Eksempel", now: date(2026, 8, 15)).plainText())
        // The no-argument legacy call still works (passport button).
        #expect(store.summaryReport().contains("MAUDE HEALTH SUMMARY"))
    }

    // MARK: - Golden file

    @Test func plainTextRenderingMatchesTheGolden() throws {
        let text = try fixtureDocument().plainText()
        #expect(text == Self.golden, "rendered:\n\(text)")
    }

    /// The frozen rendering of the synthetic fixture. Reviewed by hand — update
    /// ONLY deliberately, alongside a design review of the change.
    static let golden = """
    MAUDE HEALTH SUMMARY
    Astrid Eksempel
    Generated 15 Aug 2026
    Entered by hand, last updated 10 Aug 2026
    Sundhed.dk record as of 10 Aug 2026
    Includes 9 lab results · 2 diagnoses · 2 medicines

    DIAGNOSES — MAJOR & ONGOING
      Type 1 diabetes without complications (DE109) · since 2019 · Sundhed.dk
      Note: These entries are coded records from your hospital and GP journal, including past and closed episodes — a diagnosis listed here is not necessarily active today. The full story behind each entry is in your journal on sundhed.dk. Ask your doctor if something looks unfamiliar.

    CURRENT MEDICINES
      Magnesia · Sundhed.dk
      Novorapid FlexPen · Injektionsvæske · ATC A10AB01 · Sundhed.dk

    LATEST KEY VALUES
      HbA1c: 6.8 % — 12 Mar 2026 · previous 7.1 % — 3 Nov 2025
      Glucose: 6.1 mmol/L — 12 Mar 2026
      LDL cholesterol: 2.1 mmol/L — 12 Mar 2026 · previous 2.6 mmol/L — 3 Nov 2025
      eGFR: 88 mL/min — 12 Mar 2026
      Blood pressure: 128/82 mmHg — 10 Aug 2026

    LAB RESULTS
      Metabolic & glucose
        Glucose (plasma) · Sundhed.dk
          6.1 mmol/L — 12 Mar 2026 · source reference interval 4,2–6,3
        HbA1c (blood) · Sundhed.dk
          6.8 % — 12 Mar 2026
          previous 7.1 % — 3 Nov 2025
      Lipids
        LDL cholesterol (plasma) · Sundhed.dk
          2.1 mmol/L — 12 Mar 2026
          previous 2.6 mmol/L — 3 Nov 2025
      Kidney & electrolytes
        eGFR · Sundhed.dk
          88 mL/min — 12 Mar 2026
        Urea (plasma) · Sundhed.dk
          5.2 mmol/L — date not recorded
      Blood count
        Basophils (blood) · Sundhed.dk
          0.02 10^9/L — 12 Mar 2026
      Serology & screens
        Hepatitis B overflade antigen (plasma) · Sundhed.dk
          Not detected — 12 Mar 2026

    APPENDIX — PAST, MINOR & ADMINISTRATIVE ENTRIES
      Contact / administrative code (DZ032) · Sundhed.dk
      Note: These entries are coded records from your hospital and GP journal, including past and closed episodes — a diagnosis listed here is not necessarily active today. The full story behind each entry is in your journal on sundhed.dk. Ask your doctor if something looks unfamiliar.
      Rows excluded as collection artifacts:
        Urine collection time — 0 min — 12 Mar 2026

    Exported from Maude · your data, shared by you
    """
}
