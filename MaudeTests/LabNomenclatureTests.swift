import Testing
import Foundation
@testable import Maude

// T-EXP-03 — FR-EXP-01 (record-quality export), nomenclature layer (defect C):
// NPU system suffixes become a structured specimen field, HTML entities are
// decoded at parse/display time, Danish analyte names map to ONE English
// display name each, and the clinical-panel classification the exported
// summary groups by is a stable, judgement-free lookup.
struct LabNomenclatureTests {

    // MARK: - HTML entity decoding

    @Test func decodesNumericEntitiesWithAndWithoutSemicolon() {
        // The FMK defect: a drug name carrying a raw "&#32" (space).
        #expect(LabNomenclature.decodeHTMLEntities("Tabl&#32Metformin") == "Tabl Metformin")
        #expect(LabNomenclature.decodeHTMLEntities("A&#32;B") == "A B")
        #expect(LabNomenclature.decodeHTMLEntities("&#x41;BC") == "ABC")
    }

    @Test func decodesNamedEntitiesIncludingDanishLetters() {
        #expect(LabNomenclature.decodeHTMLEntities("H&aelig;moglobin") == "Hæmoglobin")
        #expect(LabNomenclature.decodeHTMLEntities("S&oslash;vn &amp; hvile") == "Søvn & hvile")
    }

    @Test func leavesUnknownEntitiesAndPlainTextUntouched() {
        #expect(LabNomenclature.decodeHTMLEntities("A &unknown; B") == "A &unknown; B")
        #expect(LabNomenclature.decodeHTMLEntities("Glukose") == "Glukose")
    }

    @Test func collapsesWhitespaceLeftByDecodedEntities() {
        #expect(LabNomenclature.decodeHTMLEntities("Novorapid&#32 FlexPen") == "Novorapid FlexPen")
    }

    // MARK: - Specimen (system suffix → structured label)

    @Test func mapsCoreSystemTokensToSpecimenLabels() {
        #expect(LabNomenclature.specimenLabel(forSystemToken: "P") == "plasma")
        #expect(LabNomenclature.specimenLabel(forSystemToken: "B") == "blood")
        #expect(LabNomenclature.specimenLabel(forSystemToken: "U") == "urine")
        #expect(LabNomenclature.specimenLabel(forSystemToken: "S") == "serum")
        // The compound tokens the old prefix(1) truncation destroyed:
        #expect(LabNomenclature.specimenLabel(forSystemToken: "Pt(U)") == "urine collection")
        #expect(LabNomenclature.specimenLabel(forSystemToken: "Hb(B)") == "blood")
    }

    @Test func unknownSystemTokenFallsBackToItselfNeverInvented() {
        #expect(LabNomenclature.specimenLabel(forSystemToken: "Xy") == "xy")
        #expect(LabNomenclature.specimenLabel(forSystemToken: nil) == nil)
        #expect(LabNomenclature.specimenLabel(forSystemToken: "") == nil)
    }

    @Test func splitsSystemSuffixIntoNameAndToken() {
        let (name, system) = LabNomenclature.splitSystemSuffix("Glukose;P")
        #expect(name == "Glukose")
        #expect(system == "P")
        let (plain, none) = LabNomenclature.splitSystemSuffix("eGFR")
        #expect(plain == "eGFR")
        #expect(none == nil)
    }

    // MARK: - Display names (Danish → one English name; suffixes never leak)

    @Test func displayNameNeverContainsSystemSuffixPunctuation() {
        for raw in ["Glukose;P", "Hæmoglobin;B", "Urin opsamlingstid;Pt(U)",
                    "Alanintransaminase [ALAT];P", "Basofilocytter;B"] {
            let name = LabNomenclature.displayName(forRawAnalyte: raw)
            #expect(!name.contains(";"), "suffix leaked in \(name)")
            #expect(!name.contains("["), "bracket abbreviation leaked in \(name)")
        }
    }

    @Test func mapsCommonDanishAnalytesToEnglish() {
        #expect(LabNomenclature.displayName(forRawAnalyte: "Glukose;P") == "Glucose")
        #expect(LabNomenclature.displayName(forRawAnalyte: "Hæmoglobin;B") == "Haemoglobin")
        #expect(LabNomenclature.displayName(forRawAnalyte: "Alanintransaminase [ALAT];P") == "ALT (alanine transaminase)")
        #expect(LabNomenclature.displayName(forRawAnalyte: "Basisk fosfatase;P") == "Alkaline phosphatase")
        #expect(LabNomenclature.displayName(forRawAnalyte: "Kreatinin;P") == "Creatinine")
        #expect(LabNomenclature.displayName(forRawAnalyte: "Urin opsamlingstid;Pt(U)") == "Urine collection time")
    }

    @Test func danishAndEnglishVariantsConvergeOnOneDisplayName() {
        // Defect C: the same analyte must not appear under two names.
        let danish = LabNomenclature.displayName(forRawAnalyte: "Kolesterol;P")
        let english = LabNomenclature.displayName(forRawAnalyte: "Cholesterol;P")
        #expect(danish == english)
        #expect(danish == "Total cholesterol")
    }

    @Test func egfrQualifierTailDoesNotBreakTheName() {
        #expect(LabNomenclature.displayName(forRawAnalyte: "eGFR / 1,73m²(CKD-EPI)") == "eGFR")
    }

    @Test func unknownAnalyteKeepsItsCleanedSourceName() {
        let name = LabNomenclature.displayName(forRawAnalyte: "Sjælden analyt;P")
        #expect(name == "Sjælden analyt")
    }

    @Test func decodesEntitiesInsideAnalyteNames() {
        #expect(LabNomenclature.displayName(forRawAnalyte: "H&aelig;moglobin;B") == "Haemoglobin")
    }

    // MARK: - Panel classification

    @Test func canonicalScopeKeysLandInTheirClinicalPanels() {
        #expect(LabNomenclature.panel(scopeKey: "hba1c") == .metabolic)
        #expect(LabNomenclature.panel(scopeKey: "glucose") == .metabolic)
        #expect(LabNomenclature.panel(scopeKey: "ldl_cholesterol") == .lipids)
        #expect(LabNomenclature.panel(scopeKey: "alat") == .liver)
        #expect(LabNomenclature.panel(scopeKey: "egfr") == .kidney)
        #expect(LabNomenclature.panel(scopeKey: "hemoglobin") == .bloodCount)
        #expect(LabNomenclature.panel(scopeKey: "tsh") == .thyroid)
        #expect(LabNomenclature.panel(scopeKey: "crp") == .inflammation)
        #expect(LabNomenclature.panel(scopeKey: "ferritin") == .vitaminsIron)
    }

    @Test func passthroughDanishNamesClassifyByPattern() {
        #expect(LabNomenclature.panel(scopeKey: "Basofilocytter;B") == .bloodCount)
        #expect(LabNomenclature.panel(scopeKey: "Karbamid;P") == .kidney)
        #expect(LabNomenclature.panel(scopeKey: "Borrelia antistof (IgG);P") == .serology)
        #expect(LabNomenclature.panel(scopeKey: "Glukose;U") == .metabolic)
    }

    @Test func qualitativeRowsWithNoOtherHomeDefaultToSerology() {
        #expect(LabNomenclature.panel(scopeKey: "Ukendt screening;P", isQualitative: true) == .serology)
    }

    @Test func unknownQuantitativeRowsFallToOther() {
        #expect(LabNomenclature.panel(scopeKey: "Helt ukendt;P") == .other)
    }
}
