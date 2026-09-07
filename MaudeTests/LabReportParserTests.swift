import Testing
import Foundation
@testable import Maude

// T-REC-03 — the any-lab report importer (FR-REC-03, Bevel absorb ④).
//
// Four properties are load-bearing and tested here:
//   1. UNIT NORMALISATION — glucose lands in mmol/L and HbA1c in the NGSP %
//      headline (OD-07), whatever the report printed.
//   2. THE ALLOW-LIST — only the 15 declared analytes are read.
//   3. REFUSAL TO GUESS — unknown units, ambiguous numbers, censored values and
//      misread digits become unread lines, never stored numbers.
//   4. PRIOR-VALUE FRAMING — a result is framed against the citizen's OWN last
//      value, or plainly, and every framing sentence passes NudgeGuard
//      (FR-NDG-06: no dosing, no diagnostic claim, no normality verdict).
struct LabReportParserTests {

    private func lines(_ texts: [String], confidence: Double = 1.0) -> [LabReportLine] {
        texts.map { LabReportLine(text: $0, confidence: confidence) }
    }

    private func value(_ r: LabReportParseResult, _ a: LabAnalyte) -> ParsedLabValue? {
        r.values.first { $0.analyte == a }
    }

    // MARK: - 1. Unit normalisation (OD-07)

    @Test func glucoseInMgPerDeciliterBecomesMmolPerLitre() throws {
        let r = LabReportParser.parse(lines: lines([
            "Sample date 12-03-2026",
            "Glucose, fasting  99 mg/dL",
        ]))
        let g = try #require(value(r, .glucose))
        #expect(g.unit == "mmol/L")
        #expect(g.value == 5.5)                 // 99 / 18.0182 = 5.494 → 5.5
        #expect(g.reportedUnit == "mg/dL")
        #expect(g.wasConverted)
    }

    @Test func glucoseAlreadyCanonicalIsUntouched() throws {
        let r = LabReportParser.parse(lines: lines(["P-Glukose  5,4 mmol/L"]))
        let g = try #require(value(r, .glucose))
        #expect(g.value == 5.4)
        #expect(g.unit == "mmol/L")
        #expect(g.wasConverted == false)
    }

    @Test func hba1cIFCCBecomesTheNGSPHeadline() throws {
        let r = LabReportParser.parse(lines: lines(["HbA1c(IFCC)  53 mmol/mol"]))
        let h = try #require(value(r, .hba1c))
        #expect(h.unit == "%")
        // The SAME master equation Path B uses — no second standard.
        #expect(h.value == SundhedParsers.hba1cIFCCtoNGSP(53))
        #expect(h.wasConverted)
    }

    @Test func hba1cPercentIsKeptAsPrinted() throws {
        let r = LabReportParser.parse(lines: lines(["Hemoglobin A1c   6.2 %"]))
        let h = try #require(value(r, .hba1c))
        #expect(h.value == 6.2)
        #expect(h.unit == "%")
    }

    @Test func cholesterolAndHemoglobinConvertWithTheirOwnFactors() throws {
        let r = LabReportParser.parse(lines: lines([
            "LDL Cholesterol   120 mg/dL",
            "Haemoglobin       14.0 g/dL",
        ]))
        let ldl = try #require(value(r, .ldl))
        #expect(ldl.unit == "mmol/L")
        #expect(ldl.value == 3.1)               // 120 / 38.67
        let hb = try #require(value(r, .hemoglobin))
        #expect(hb.unit == "mmol/L")
        #expect(hb.value == 8.7)                // 14.0 × 0.6206
    }

    @Test func ldlNeverResolvesToTotalCholesterol() throws {
        let r = LabReportParser.parse(lines: lines([
            "Cholesterol, total   5.1 mmol/L",
            "LDL-cholesterol      3.0 mmol/L",
            "HDL-cholesterol      1.4 mmol/L",
        ]))
        #expect(value(r, .cholesterolTotal)?.value == 5.1)
        #expect(value(r, .ldl)?.value == 3.0)
        #expect(value(r, .hdl)?.value == 1.4)
    }

    // MARK: - 2. The allow-list

    @Test func onlyAllowListedAnalytesAreRead() throws {
        let r = LabReportParser.parse(lines: lines([
            "Ferritin        88 µg/L",
            "Magnesium      0.85 mmol/L",     // not on the list
            "Prolactin       12 µg/L",        // not on the list
        ]))
        #expect(r.values.count == 1)
        #expect(value(r, .ferritin)?.value == 88)
        // The two it doesn't know are SHOWN as unread, not silently dropped.
        #expect(r.unread.filter { $0.reason == .unknownAnalyte }.count == 2)
    }

    @Test func everyAllowListedAnalyteHasAKeyAndACanonicalUnit() throws {
        for a in LabAnalyte.allCases {
            #expect(!a.scopeKey.isEmpty)
            #expect(!a.canonicalUnit.isEmpty)
            #expect(!a.displayName.isEmpty)
            // The canonical unit must itself be an accepted printed unit,
            // otherwise a report in canonical units could not be read.
            #expect(a.unitRules[LabReportParser.normalizeUnit(a.canonicalUnit)] != nil)
        }
        #expect(LabAnalyte.allCases.count == 15)
    }

    @Test func scopeKeysMeetTheExistingCatalogWhereOneExists() throws {
        // Shared keys must be IDENTICAL to the Sundhed crosswalk's catalog vars,
        // so an OCR'd HbA1c and a Sundhed.dk HbA1c land on one row key.
        #expect(LabAnalyte.hba1c.scopeKey == "hba1c")
        #expect(LabAnalyte.glucose.scopeKey == "glucose")
        #expect(LabAnalyte.ldl.scopeKey == "ldl_cholesterol")
        #expect(LabAnalyte.egfr.scopeKey == "egfr")
        for a in LabAnalyte.allCases where SundhedParsers.knownCatalogVars.contains(a.scopeKey) {
            #expect(HealthDisplay.scopeKeyToName[a.scopeKey] != nil)
        }
        // The four keys with no catalog var yet still have a readable name.
        for key in ["triglycerides", "ferritin", "vitamin_d", "vitamin_b12"] {
            #expect(HealthDisplay.scopeKeyToName[key] != nil)
        }
    }

    // MARK: - 3. Refusal to guess

    @Test func aKnownAnalyteInAnUnknownUnitIsNotStored() throws {
        let r = LabReportParser.parse(lines: lines(["TSH   2.1 banana/L"]))
        #expect(r.values.isEmpty)
        #expect(r.unread.first?.reason == .unknownUnit)
    }

    @Test func anAmbiguousNumberIsRefusedRatherThanPicked() throws {
        // "1.234" — 1234 grouped, or 1.234 with a decimal point? Refuse.
        let r = LabReportParser.parse(lines: lines(["Ferritin  1.234 µg/L"]))
        #expect(r.values.isEmpty)
        #expect(r.unread.first?.reason == .ambiguousNumber)
        #expect(LabNumber.parse("1.234") == .ambiguous)
        // A leading zero cannot be a thousands group, so this one is decimal.
        #expect(LabNumber.parse("0.500") == .value(0.5))
        // Both separators present: the last one is the decimal point.
        #expect(LabNumber.parse("1.234,5") == .value(1234.5))
        #expect(LabNumber.parse("1,234.5") == .value(1234.5))
    }

    @Test func aCensoredValueIsNotAMeasurement() throws {
        let r = LabReportParser.parse(lines: lines(["CRP   <0.6 mg/L"]))
        #expect(r.values.isEmpty)
        #expect(r.unread.first?.reason == .censoredValue)
    }

    @Test func misreadDigitsFallOutsideTheReadableBound() throws {
        // A misread decimal point: HbA1c can never be 620 %.
        let r = LabReportParser.parse(lines: lines(["HbA1c   620 %"]))
        #expect(r.values.isEmpty)
        #expect(r.unread.first?.reason == .outsideReadableBound)
    }

    @Test func printedReferenceBandsAreNeverReadAsValues() throws {
        // The lab's own interval is present on the line; the parser takes the
        // measured value and ignores the band entirely.
        let r = LabReportParser.parse(lines: lines([
            "Creatinine   82 µmol/L   (ref 60 - 105)",
            "TSH  1.80 mIU/L  Reference interval 0.40 - 4.00 mIU/L",
        ]))
        #expect(value(r, .creatinine)?.value == 82)
        #expect(value(r, .tsh)?.value == 1.8)
    }

    @Test func aDateIsNeverReadAsAResult() throws {
        let r = LabReportParser.parse(lines: lines([
            "Prøvedato 21.03.2026",
            "ALAT  21.03.2026   34 U/L",
        ]))
        let alat = try #require(value(r, .alat))
        #expect(alat.value == 34)
        #expect(r.documentDate != nil)
    }

    @Test func dateOfBirthIsNotTheSampleDate() throws {
        let r = LabReportParser.parse(lines: lines([
            "Date of birth 04-11-1962",
            "Collected 02-06-2026",
            "Glucose 5.1 mmol/L",
        ]))
        let cal = Calendar(identifier: .gregorian)
        let d = try #require(r.documentDate)
        #expect(cal.component(.year, from: d) == 2026)
    }

    @Test func aUnitInternalNumberIsNotAResult() throws {
        let r = LabReportParser.parse(lines: lines(["eGFR  88 mL/min/1.73m²"]))
        let e = try #require(value(r, .egfr))
        #expect(e.value == 88)
        #expect(e.unit == "mL/min")
    }

    @Test func aValueOnTheNextLineIsPairedWithItsLabel() throws {
        let r = LabReportParser.parse(lines: lines([
            "Vitamin D (25-OH)",
            "62 nmol/L",
        ]))
        #expect(value(r, .vitaminD)?.value == 62)
    }

    @Test func emptyAndNoiseInputProduceNothing() throws {
        #expect(LabReportParser.parse(lines: []).isEmpty)
        let noise = LabReportParser.parse(lines: lines([
            "CITY HOSPITAL LABORATORY", "Page 1 of 2", "Tel. 33 12 44 00",
        ]))
        #expect(noise.values.isEmpty)
    }

    @Test func theSameAnalyteTwiceOnOneDayIsOneReading() throws {
        let r = LabReportParser.parse(lines: lines([
            "Sample date 12-03-2026",
            "HbA1c   6.2 %",
            "HbA1c   6.2 %",     // the report's own summary repeat
        ]))
        #expect(r.values.filter { $0.analyte == .hba1c }.count == 1)
    }

    @Test func lowConfidenceIsCarriedThroughForTheReviewScreen() throws {
        let r = LabReportParser.parse(lines: lines(["CRP  4.0 mg/L"], confidence: 0.31))
        #expect(value(r, .crp)?.confidence == 0.31)
    }

    // MARK: - 4. Prior-value framing (and FR-NDG-06)

    @Test func withoutAPriorTheValueIsStatedPlainly() throws {
        let text = LabPriorFraming.text(for: .hba1c, newValue: 6.2, prior: nil)
        #expect(text.contains("No earlier HbA1c"))
        #expect(NudgeGuard.check(text) == nil)
    }

    @Test func withAPriorTheFrameIsTheCitizensOwnLastValue() throws {
        let then = Date(timeIntervalSince1970: 1_772_000_000)   // 25 Feb 2026
        let up = LabPriorFraming.text(for: .hba1c, newValue: 6.5,
                                      prior: .init(value: 6.2, date: then))
        #expect(up.contains("Your previous HbA1c was 6.2"))
        #expect(up.contains("Up 0.3"))

        let down = LabPriorFraming.text(for: .hba1c, newValue: 5.9,
                                        prior: .init(value: 6.2, date: then))
        #expect(down.contains("Down 0.3"))

        let same = LabPriorFraming.text(for: .hba1c, newValue: 6.2,
                                        prior: .init(value: 6.2, date: then))
        #expect(same.contains("the same figure"))
    }

    /// The framing NEVER speaks in population terms: no reference band, no
    /// normality verdict, no dosing or treatment language, for ANY analyte or
    /// direction. NudgeGuard is the designated control (FR-NDG-06) and is run
    /// over every sentence this path can produce.
    @Test func everyFramingSentencePassesNudgeGuard() throws {
        let then = Date(timeIntervalSince1970: 1_772_000_000)
        for analyte in LabAnalyte.allCases {
            let mid = (analyte.readableBound.lowerBound + analyte.readableBound.upperBound) / 2
            let candidates = [
                LabPriorFraming.text(for: analyte, newValue: mid, prior: nil),
                LabPriorFraming.text(for: analyte, newValue: mid,
                                     prior: .init(value: mid, date: then)),
                LabPriorFraming.text(for: analyte, newValue: mid * 1.1,
                                     prior: .init(value: mid, date: then)),
                LabPriorFraming.text(for: analyte, newValue: mid * 0.9,
                                     prior: .init(value: mid, date: then)),
            ]
            for text in candidates {
                #expect(NudgeGuard.check(text) == nil,
                        "FR-NDG-06 violation in framing for \(analyte): \(text)")
                let lower = text.lowercased()
                for banned in ["normal", "reference", "healthy", "should", "recommend"] {
                    #expect(!lower.contains(banned),
                            "population/advice vocabulary in framing for \(analyte): \(text)")
                }
            }
        }
    }

    // MARK: - A whole (fictional) report, end to end

    @Test func aMixedReportReadsWhatItCanAndSaysWhatItCannot() throws {
        let r = LabReportParser.parse(lines: lines([
            "NORTHSIDE MEDICAL LABORATORY",
            "Patient: (name withheld)      Date of birth 04-11-1962",
            "Collected 02-06-2026        Reported 03-06-2026",
            "",
            "TEST                    RESULT      UNIT       REFERENCE",
            "Hemoglobin A1c          6.4         %          4.0 - 6.0",
            "Glucose, fasting        108         mg/dL      70 - 99",
            "Total cholesterol       5.4         mmol/L     < 5.0",
            "LDL cholesterol         3.5         mmol/L     < 3.0",
            "HDL cholesterol         1.2         mmol/L     > 1.0",
            "Triglycerides           1.8         mmol/L",
            "Creatinine              84          µmol/L     60 - 105",
            "eGFR                    82          mL/min",
            "ALAT                    29          U/L",
            "TSH                     2.10        mIU/L",
            "Ferritin                145         µg/L",
            "CRP                     2.4         mg/L",
            "Vitamin D (25-OH)       58          nmol/L",
            "Vitamin B12             310         pmol/L",
            "Magnesium               0.88        mmol/L",
            "Free T4                 15.2        pmol/L",
        ]))

        #expect(r.values.count == 14)
        #expect(value(r, .hba1c)?.value == 6.4)
        #expect(value(r, .glucose)?.unit == "mmol/L")
        #expect(value(r, .glucose)?.value == 6.0)       // 108 / 18.0182
        #expect(value(r, .vitaminB12)?.value == 310)
        // The two analytes outside the allow-list are reported, not guessed.
        #expect(r.unread.contains { $0.text.contains("Magnesium") })
        #expect(r.unread.contains { $0.text.contains("Free T4") })
        // The collection date wins over the report date and the date of birth.
        let cal = Calendar(identifier: .gregorian)
        let d = try #require(r.documentDate)
        #expect(cal.component(.month, from: d) == 6)
        #expect(cal.component(.day, from: d) == 2)
    }
}
