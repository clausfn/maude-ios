// LabReportParser.swift — FR-REC-03 · any-lab report → canonical observations.
//
// The DETERMINISTIC half of the any-lab import (Bevel absorb ④). It consumes
// flat text lines (from a PDF's embedded text layer, or from on-device Vision
// OCR — see LabReportOCR.swift) and returns coded, canonical-unit lab values
// plus an explicit list of the lines it could NOT read.
//
// IDIOM: this mirrors SundhedParsers (Path B) rather than inventing a second
// one — same "recognise a declaration, pair it with a number+unit, never invent
// a value" discipline, same Danish/English number handling, and the same reuse
// of the bundled crosswalk (catalog scopeKeys, HbA1c IFCC→NGSP). Where an
// analyte already has a catalog var, that SAME key is used, so an OCR'd HbA1c
// and a Sundhed.dk HbA1c land on one scopeKey and compare cleanly.
//
// CARDINAL RULES
//   • ALLOW-LIST ONLY. Fifteen analytes are recognised; anything else is
//     reported as unread. There is no fuzzy matching and no fallback guess.
//   • The analyte's unit must be one this file knows how to convert. A known
//     analyte in an unknown unit is unread — never stored "as printed".
//   • Canonical units (OD-07): glucose mmol/L; HbA1c the NGSP % headline
//     (IFCC mmol/mol is converted with the same master equation Path B uses).
//   • NO reference ranges, no verdicts. The parser reads values; framing
//     against the citizen's OWN prior value lives in LabPriorFraming.swift.
//
// Pure Foundation — no Vision, no PDFKit, no SwiftUI (NFR-PORT-01), so the
// whole recogniser unit-tests in isolation and ports to Android.
import Foundation

// MARK: - Input

/// One line of text read off a report, with the confidence of the read
/// (1.0 for a PDF's embedded text layer; the OCR confidence for a photo).
public nonisolated struct LabReportLine: Equatable, Sendable {
    public let text: String
    public let confidence: Double

    public init(text: String, confidence: Double = 1.0) {
        self.text = text
        self.confidence = min(max(confidence, 0), 1)
    }
}

// MARK: - The allow-list

/// The analytes this importer will read. Deliberately small: each one has a
/// stable printed name, a unit set with an exact conversion, and a canonical
/// unit the app already stores. Extend ONLY when parsing is genuinely reliable.
public nonisolated enum LabAnalyte: String, CaseIterable, Sendable {
    case hba1c, glucose
    case cholesterolTotal, ldl, hdl, triglycerides
    case creatinine, egfr, alat
    case tsh, hemoglobin, ferritin, crp
    case vitaminD, vitaminB12

    /// Canonical store key — the EXISTING catalog var wherever one exists
    /// (SundhedParsers crosswalk), so sources meet on one key.
    public var scopeKey: String {
        switch self {
        case .hba1c:            return "hba1c"
        case .glucose:          return "glucose"
        case .cholesterolTotal: return "cholesterol_total"
        case .ldl:              return "ldl_cholesterol"
        case .hdl:              return "hdl_cholesterol"
        case .triglycerides:    return "triglycerides"
        case .creatinine:       return "creatinine"
        case .egfr:             return "egfr"
        case .alat:             return "alat"
        case .tsh:              return "tsh"
        case .hemoglobin:       return "hemoglobin"
        case .ferritin:         return "ferritin"
        case .crp:              return "crp"
        case .vitaminD:         return "vitamin_d"
        case .vitaminB12:       return "vitamin_b12"
        }
    }

    /// Name shown on the review row (matches HealthDisplay where a key exists).
    public var displayName: String {
        switch self {
        case .hba1c:            return "HbA1c"
        case .glucose:          return "Glucose"
        case .cholesterolTotal: return "Total cholesterol"
        case .ldl:              return "LDL cholesterol"
        case .hdl:              return "HDL cholesterol"
        case .triglycerides:    return "Triglycerides"
        case .creatinine:       return "Creatinine"
        case .egfr:             return "eGFR"
        case .alat:             return "ALAT"
        case .tsh:              return "TSH"
        case .hemoglobin:       return "Hemoglobin"
        case .ferritin:         return "Ferritin"
        case .crp:              return "CRP"
        case .vitaminD:         return "Vitamin D"
        case .vitaminB12:       return "Vitamin B12"
        }
    }

    /// The unit the value is STORED in. OD-07: glucose mmol/L; HbA1c is the
    /// NGSP % headline (same convention as the Sundhed Path B parser).
    public var canonicalUnit: String {
        switch self {
        case .hba1c:            return "%"
        case .glucose, .cholesterolTotal, .ldl, .hdl,
             .triglycerides, .hemoglobin:       return "mmol/L"
        case .creatinine:       return "µmol/L"
        case .egfr:             return "mL/min"
        case .alat:             return "U/L"
        case .tsh:              return "mIU/L"
        case .ferritin:         return "µg/L"
        case .crp:              return "mg/L"
        case .vitaminD:         return "nmol/L"
        case .vitaminB12:       return "pmol/L"
        }
    }

    /// Decimals kept after conversion — never more precision than the analyte
    /// is reported with (a converted value must not invent digits).
    public var decimals: Int {
        switch self {
        case .tsh:                                   return 2
        case .hba1c, .glucose, .cholesterolTotal, .ldl,
             .hdl, .triglycerides, .hemoglobin, .crp: return 1
        case .creatinine, .egfr, .alat, .ferritin,
             .vitaminD, .vitaminB12:                 return 0
        }
    }

    /// Printed names accepted for this analyte (EN + DA), matched whole-word
    /// and longest-first. No fuzzy matching: a name not in this list is unread.
    var synonyms: [String] {
        switch self {
        case .hba1c:
            return ["hba1c", "hba1c(ifcc)", "hemoglobin a1c", "haemoglobin a1c",
                    "hæmoglobin a1c", "glycated hemoglobin", "glycated haemoglobin",
                    "a1c"]
        case .glucose:
            return ["glucose", "glukose", "blood glucose", "plasma glucose",
                    "fasting glucose", "fastende glukose", "blodsukker"]
        case .cholesterolTotal:
            return ["total cholesterol", "cholesterol total", "cholesterol, total",
                    "total kolesterol", "kolesterol total", "cholesterol", "kolesterol"]
        case .ldl:
            return ["ldl cholesterol", "ldl-cholesterol", "ldl kolesterol",
                    "ldl-kolesterol", "ldl"]
        case .hdl:
            return ["hdl cholesterol", "hdl-cholesterol", "hdl kolesterol",
                    "hdl-kolesterol", "hdl"]
        case .triglycerides:
            return ["triglycerides", "triglyceride", "triglycerider", "triglycerid"]
        case .creatinine:
            return ["creatinine", "kreatinin"]
        case .egfr:
            return ["egfr", "e-gfr", "estimated gfr"]
        case .alat:
            return ["alanine aminotransferase", "alanine transaminase",
                    "alanintransaminase", "alat", "alt"]
        case .tsh:
            return ["tsh", "thyrotropin", "thyroid stimulating hormone"]
        case .hemoglobin:
            return ["hemoglobin", "haemoglobin", "hæmoglobin", "hgb", "hb"]
        case .ferritin:
            return ["ferritin"]
        case .crp:
            return ["c-reactive protein", "c-reaktivt protein", "hs-crp", "crp"]
        case .vitaminD:
            return ["25-hydroxyvitamin d", "25-oh vitamin d", "25-oh-d",
                    "vitamin d3", "vitamin d", "d-vitamin"]
        case .vitaminB12:
            return ["vitamin b12", "cobalamin", "kobalamin", "b12"]
        }
    }

    /// Accepted printed units → the exact conversion into `canonicalUnit`.
    /// Tokens are compared after `LabReportParser.normalizeUnit`.
    var unitRules: [String: LabUnitConversion] {
        switch self {
        case .hba1c:
            // DK/EU report IFCC mmol/mol; the app's headline is NGSP % (OD-07),
            // converted with the SAME master equation Path B uses.
            return ["%": .identity, "mmol/mol": .hba1cIFCCtoNGSP]
        case .glucose:
            // mg/dL → mmol/L: ÷ 18.0182.
            return ["mmol/l": .identity, "mg/dl": .factor(1.0 / 18.0182)]
        case .cholesterolTotal, .ldl, .hdl:
            // mg/dL → mmol/L: ÷ 38.67 (cholesterol molar mass).
            return ["mmol/l": .identity, "mg/dl": .factor(1.0 / 38.67)]
        case .triglycerides:
            // mg/dL → mmol/L: ÷ 88.57.
            return ["mmol/l": .identity, "mg/dl": .factor(1.0 / 88.57)]
        case .creatinine:
            // mg/dL → µmol/L: × 88.4.
            return ["umol/l": .identity, "mg/dl": .factor(88.4)]
        case .egfr:
            return ["ml/min": .identity, "ml/min/1.73m2": .identity,
                    "ml/min/1.73": .identity, "ml/min/1.73m^2": .identity]
        case .alat:
            return ["u/l": .identity, "iu/l": .identity]
        case .tsh:
            return ["miu/l": .identity, "mu/l": .identity,
                    "uiu/ml": .identity, "mie/l": .identity]
        case .hemoglobin:
            // DK reports mmol/L. g/dL → mmol/L: × 0.6206; g/L → mmol/L: × 0.06206.
            return ["mmol/l": .identity, "g/dl": .factor(0.6206), "g/l": .factor(0.06206)]
        case .ferritin:
            return ["ug/l": .identity, "ng/ml": .identity]
        case .crp:
            return ["mg/l": .identity, "mg/dl": .factor(10.0), "nmol/l": .factor(0.105)]
        case .vitaminD:
            // ng/mL → nmol/L: × 2.496.
            return ["nmol/l": .identity, "ng/ml": .factor(2.496)]
        case .vitaminB12:
            // pg/mL → pmol/L: × 0.7378.
            return ["pmol/l": .identity, "pg/ml": .factor(0.7378), "ng/l": .factor(0.7378)]
        }
    }

    /// OCR SANITY BOUND — deliberately far wider than anything physiological.
    /// This is NOT a clinical reference range and is never shown or judged: it
    /// exists so a misread digit ("64" read as "640") is refused instead of
    /// silently stored. A value outside it becomes an unread line.
    var readableBound: ClosedRange<Double> {
        switch self {
        case .hba1c:            return 2.0...25.0
        case .glucose:          return 0.5...60.0
        case .cholesterolTotal: return 0.5...25.0
        case .ldl:              return 0.1...20.0
        case .hdl:              return 0.1...10.0
        case .triglycerides:    return 0.1...40.0
        case .creatinine:       return 5.0...2000.0
        case .egfr:             return 1.0...200.0
        case .alat:             return 1.0...5000.0
        case .tsh:              return 0.001...200.0
        case .hemoglobin:       return 1.0...15.0
        case .ferritin:         return 1.0...20000.0
        case .crp:              return 0.1...600.0
        case .vitaminD:         return 1.0...500.0
        case .vitaminB12:       return 20.0...3000.0
        }
    }
}

/// How a printed unit becomes the canonical one. Exact and table-driven —
/// there is no inferred or "probably" conversion.
public nonisolated enum LabUnitConversion: Equatable, Sendable {
    case identity
    case factor(Double)
    case hba1cIFCCtoNGSP

    func apply(_ v: Double) -> Double {
        switch self {
        case .identity:          return v
        case .factor(let f):     return v * f
        // Reuse of the ONE HbA1c equation in the codebase (SundhedParsers) —
        // no second standard.
        case .hba1cIFCCtoNGSP:   return SundhedParsers.hba1cIFCCtoNGSP(v)
        }
    }
}

// MARK: - Output

/// One recognised result, ready for review. Carries BOTH the canonical value
/// and what was actually printed, so the review screen can show its work.
public nonisolated struct ParsedLabValue: Equatable, Sendable, Identifiable {
    public let lineIndex: Int
    public let analyte: LabAnalyte
    public let value: Double          // canonical unit, rounded to analyte.decimals
    public let unit: String           // canonical unit
    public let reportedValue: Double  // exactly as printed
    public let reportedUnit: String   // exactly as printed
    public let date: Date?            // the row's own date, when the line carried one
    public let confidence: Double     // read confidence of the source line(s)
    public let sourceLine: String     // the line it came from (shown for checking)

    public var id: Int { lineIndex }

    /// True when the printed unit was not the canonical one, so the review row
    /// can show "read as 108 mg/dL".
    public var wasConverted: Bool {
        LabReportParser.normalizeUnit(reportedUnit) != LabReportParser.normalizeUnit(unit)
    }
}

/// A line the parser refused to read, with the honest reason. Every such line
/// is surfaced to the citizen — nothing is silently dropped or guessed.
public nonisolated struct UnreadLabLine: Equatable, Sendable, Identifiable {
    public enum Reason: String, Sendable {
        case unknownAnalyte        // a value, but not one of the allow-listed analytes
        case unknownUnit           // known analyte, unit this parser can't convert
        case ambiguousNumber       // "1.234" — thousands or decimal? refuse to pick
        case censoredValue         // "<0.5" — a bound, not a measurement
        case outsideReadableBound  // digits almost certainly misread
    }
    public let id: Int             // source line index
    public let text: String
    public let reason: Reason
}

public nonisolated struct LabReportParseResult: Equatable, Sendable {
    public let values: [ParsedLabValue]
    public let unread: [UnreadLabLine]
    /// The report's own sample/collection date when one was printed; nil when
    /// no date was found (the review screen then says so and asks).
    public let documentDate: Date?

    public var isEmpty: Bool { values.isEmpty }
}

// MARK: - The parser

public nonisolated enum LabReportParser {

    /// Parse a whole report. Order of lines is the reading order of the page.
    public static func parse(lines: [LabReportLine]) -> LabReportParseResult {
        let docDate = documentDate(in: lines)

        var values: [ParsedLabValue] = []
        var unread: [UnreadLabLine] = []
        var seen = Set<String>()          // scopeKey + day → keep the first read
        var consumed = Set<Int>()         // lines already used as a value row

        for (i, line) in lines.enumerated() {
            guard !consumed.contains(i) else { continue }
            let raw = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }

            // A line's own date is stripped before number scanning so "12-03-2026"
            // can never be misread as a result (same discipline as Path B).
            let (lineDate, dateRaw) = SundhedParsers.firstDate(in: raw)
            let scanText = dateRaw.isEmpty ? raw : raw.replacingOccurrences(of: dateRaw, with: " ")

            let numbers = numberCandidates(in: scanText)
            // The label is everything before the first number that could BE a
            // result. Digits inside a name ("HbA1c", "Vitamin B12", "Free T4")
            // are part of the name and must not cut the label short.
            let labelRegion = prefix(of: scanText,
                                     upTo: numbers.first(where: { !$0.nameInternal })?.start)
            let analyte = matchAnalyte(in: labelRegion)

            // --- Case 1: label and value on the SAME line ---------------------
            if let first = numbers.first(where: { !$0.excluded }) {
                guard let analyte else {
                    // A value we can see but an analyte we don't know. Only
                    // report it when it really looks like a result row (a unit
                    // and a label), so page furniture stays quiet.
                    if first.unit != nil, hasLabelText(labelRegion) {
                        unread.append(.init(id: i, text: raw, reason: .unknownAnalyte))
                    }
                    continue
                }
                if let reason = first.refusal {
                    unread.append(.init(id: i, text: raw, reason: reason))
                    continue
                }
                let printedUnit = first.unit ?? unitHint(in: labelRegion) ?? ""
                switch build(analyte: analyte, number: first.value, printedUnit: printedUnit,
                             date: lineDate, confidence: line.confidence,
                             sourceLine: raw, lineIndex: i) {
                case .success(let v):
                    appendUnique(v, into: &values, seen: &seen, docDate: docDate)
                case .failure(let reason):
                    unread.append(.init(id: i, text: raw, reason: reason))
                }
                continue
            }

            // --- Case 2: label line, value on the NEXT line -------------------
            // (the two-column PDF layout Path B also has to handle)
            guard let analyte, let j = nextNonEmpty(after: i, in: lines) else { continue }
            let nextRaw = lines[j].text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Only when the next line is a bare value row — if it names an
            // analyte of its own, it belongs to that analyte, not this one.
            guard matchAnalyte(in: nextRaw) == nil else { continue }
            let (nextDate, nextDateRaw) = SundhedParsers.firstDate(in: nextRaw)
            let nextScan = nextDateRaw.isEmpty ? nextRaw : nextRaw.replacingOccurrences(of: nextDateRaw, with: " ")
            guard let cand = numberCandidates(in: nextScan).first(where: { !$0.excluded }) else { continue }
            if let reason = cand.refusal {
                unread.append(.init(id: i, text: raw, reason: reason))
                consumed.insert(j)
                continue
            }
            let printedUnit = cand.unit ?? unitHint(in: labelRegion) ?? ""
            switch build(analyte: analyte, number: cand.value, printedUnit: printedUnit,
                         date: nextDate ?? lineDate,
                         confidence: min(line.confidence, lines[j].confidence),
                         sourceLine: "\(raw) \(nextRaw)", lineIndex: i) {
            case .success(let v):
                appendUnique(v, into: &values, seen: &seen, docDate: docDate)
                consumed.insert(j)
            case .failure(let reason):
                unread.append(.init(id: i, text: raw, reason: reason))
                consumed.insert(j)
            }
        }

        return LabReportParseResult(values: values, unread: unread, documentDate: docDate)
    }

    // MARK: Row construction

    private enum BuildOutcome {
        case success(ParsedLabValue)
        case failure(UnreadLabLine.Reason)
    }

    private static func build(analyte: LabAnalyte, number: Double, printedUnit: String,
                              date: Date?, confidence: Double,
                              sourceLine: String, lineIndex: Int) -> BuildOutcome {
        let key = normalizeUnit(printedUnit)
        guard !key.isEmpty, let conversion = analyte.unitRules[key] else {
            // A known analyte in a unit we cannot convert exactly is NOT stored
            // "as printed" — that would silently corrupt the canonical record.
            return .failure(.unknownUnit)
        }
        let converted = round(conversion.apply(number), to: analyte.decimals)
        guard analyte.readableBound.contains(converted) else {
            return .failure(.outsideReadableBound)
        }
        return .success(ParsedLabValue(
            lineIndex: lineIndex,
            analyte: analyte,
            value: converted,
            unit: analyte.canonicalUnit,
            reportedValue: number,
            reportedUnit: printedUnit.trimmingCharacters(in: .whitespaces),
            date: date,
            confidence: confidence,
            sourceLine: sourceLine
        ))
    }

    /// One reading per analyte per day: the FIRST read wins (report summaries
    /// print the same analyte twice; a later repeat is not a new measurement).
    private static func appendUnique(_ v: ParsedLabValue, into values: inout [ParsedLabValue],
                                     seen: inout Set<String>, docDate: Date?) {
        let day = (v.date ?? docDate).map { ISO8601DateFormatter().string(from: $0).prefix(10) } ?? "—"
        let key = "\(v.analyte.scopeKey)@\(day)"
        guard !seen.contains(key) else { return }
        seen.insert(key)
        values.append(v)
    }

    // MARK: Analyte matching (allow-list, longest name wins)

    /// All (normalised synonym, analyte) pairs, longest first, so
    /// "LDL cholesterol" never resolves to total cholesterol.
    private static let synonymIndex: [(name: String, analyte: LabAnalyte)] = {
        var pairs: [(String, LabAnalyte)] = []
        for a in LabAnalyte.allCases {
            for s in a.synonyms { pairs.append((normalizeLabel(s), a)) }
        }
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    /// The analyte named in a label region, or nil. Whole-word match only.
    static func matchAnalyte(in labelRegion: String) -> LabAnalyte? {
        let hay = normalizeLabel(stripSpecimenPrefix(labelRegion))
        guard !hay.isEmpty else { return nil }
        for (name, analyte) in synonymIndex where containsWord(hay, name) {
            return analyte
        }
        return nil
    }

    /// Danish IUPAC / EN specimen prefixes ("P-Glukose", "S-Ferritin",
    /// "Plasma Glucose") are addressing, not part of the analyte name.
    private static func stripSpecimenPrefix(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        let wordPrefixes = ["plasma", "serum", "whole blood", "blood", "urine", "fasting"]
        var changed = true
        while changed {
            changed = false
            let lower = t.lowercased()
            for p in wordPrefixes where lower.hasPrefix(p + " ") {
                t = String(t.dropFirst(p.count + 1)); changed = true
            }
            // "P-", "B-", "S-", "U-", "fP-", "dU-" …
            if let m = t.range(of: #"^[A-Za-z]{1,2}\s*[-–]\s*"#, options: .regularExpression) {
                t = String(t[m.upperBound...]); changed = true
            }
        }
        return t
    }

    /// Lower-cased, punctuation-flattened label text for matching.
    static func normalizeLabel(_ s: String) -> String {
        var t = s.lowercased()
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "-")
        // Keep '-' (ldl-cholesterol) and '(' boundaries; flatten the rest.
        t = t.replacingOccurrences(of: #"[,:;\[\]\(\)\*\|]"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Whole-word containment where '-' and ' ' are both word separators, so
    /// "ldl-cholesterol" and "ldl cholesterol" match the same synonym and "hb"
    /// never matches inside "hba1c".
    private static func containsWord(_ haystack: String, _ needle: String) -> Bool {
        let h = haystack.replacingOccurrences(of: "-", with: " ")
        let n = needle.replacingOccurrences(of: "-", with: " ")
        guard !n.isEmpty else { return false }
        var search = h.startIndex..<h.endIndex
        while let r = h.range(of: n, range: search) {
            let beforeOK = r.lowerBound == h.startIndex
                || !isWordChar(h[h.index(before: r.lowerBound)])
            let afterOK = r.upperBound == h.endIndex
                || !isWordChar(h[r.upperBound])
            if beforeOK && afterOK { return true }
            guard r.upperBound < h.endIndex else { break }
            search = h.index(after: r.lowerBound)..<h.endIndex
        }
        return false
    }

    private static func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }

    /// Does the label region carry actual words (≥3 letters)? Keeps page
    /// furniture ("2 / 4", "Tel. 33 12 …") out of the unread list.
    private static func hasLabelText(_ s: String) -> Bool {
        s.filter { $0.isLetter }.count >= 3
    }

    // MARK: Numbers and units

    struct NumberCandidate {
        let value: Double
        let start: Int          // UTF-16 offset in the scanned string
        let unit: String?       // printed unit immediately after the number
        let excluded: Bool      // not a result: name-internal, unit-internal,
                                // bracketed, part of a range, or behind "ref"
        let nameInternal: Bool  // a digit inside a word — "A1c", "B12", "T4"
        let refusal: UnreadLabLine.Reason?   // ambiguous or censored
    }

    /// UTF-16-safe prefix (analyte names carry æ/µ; NSRange offsets are UTF-16).
    private static func prefix(of s: String, upTo offset: Int?) -> String {
        let ns = s as NSString
        guard let offset else { return s }
        return ns.substring(to: min(max(offset, 0), ns.length))
    }

    /// Every number on the line with its trailing unit and an exclusion verdict.
    static func numberCandidates(in line: String) -> [NumberCandidate] {
        let ns = line as NSString
        guard let re = try? NSRegularExpression(pattern: #"[0-9][0-9.,]*"#) else { return [] }
        let excludedRanges = exclusionRanges(in: line)

        var out: [NumberCandidate] = []
        for m in re.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            var token = ns.substring(with: m.range)
            // Trailing separators belong to the sentence, not the number.
            while let last = token.last, last == "." || last == "," { token.removeLast() }
            guard !token.isEmpty else { continue }

            let start = m.range.location
            let before = start > 0 ? ns.substring(with: NSRange(location: start - 1, length: 1)) : ""
            // A number reached through '/' is part of a unit, not a result
            // ("mL/min/1.73m²") — never a candidate.
            let insideUnit = before == "/"
            // A number glued to the end of a word is part of the NAME, not a
            // measurement: HbA1c, Vitamin B12, Free T4, Vitamin D3, 25-OH.
            let nameInternal = before.rangeOfCharacter(from: .letters) != nil
            let excluded = insideUnit || nameInternal
                || excludedRanges.contains { NSLocationInRange(start, $0) }

            // "<0.5" / ">1000" is a bound, not a measurement.
            var refusal: UnreadLabLine.Reason?
            if start > 0 {
                let prev = ns.substring(with: NSRange(location: start - 1, length: 1))
                if prev == "<" || prev == ">" { refusal = .censoredValue }
            }

            let parsed = LabNumber.parse(token)
            var value = 0.0
            switch parsed {
            case .value(let v):  value = v
            case .ambiguous:     refusal = refusal ?? .ambiguousNumber
            case .unreadable:    continue
            }

            let after = ns.substring(from: m.range.location + m.range.length)
            out.append(NumberCandidate(value: value, start: start,
                                       unit: leadingUnit(in: after),
                                       excluded: excluded, nameInternal: nameInternal,
                                       refusal: refusal))
        }
        return out
    }

    /// Character ranges whose numbers are NOT results: anything in brackets,
    /// anything after a reference-interval keyword, and both sides of an
    /// "a - b" span. Lab reports print their bands here; Maude never reads them.
    private static func exclusionRanges(in line: String) -> [NSRange] {
        let ns = line as NSString
        var ranges: [NSRange] = []
        for pattern in [#"\([^)]*\)"#, #"\[[^\]]*\]"#,
                        #"(?i)\b(ref|reference|referenceinterval|interval|område|range|expected)\b.*$"#,
                        #"[0-9][0-9.,]*\s*[-–—]\s*[0-9][0-9.,]*"#] {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            ranges += re.matches(in: line, range: NSRange(location: 0, length: ns.length)).map(\.range)
        }
        return ranges
    }

    /// The unit printed immediately after a number ("5.4 mmol/L (…)" → "mmol/L").
    /// Stops at whitespace-then-digit or any character outside the unit set.
    static func leadingUnit(in tail: String) -> String? {
        var s = Substring(tail)
        while let f = s.first, f == " " || f == "\u{00A0}" { s = s.dropFirst() }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/^%µμ².,")
        var unit = ""
        for ch in s {
            guard ch.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { break }
            unit.append(ch)
            if unit.count > 16 { break }
        }
        while let last = unit.last, last == "." || last == "," { unit.removeLast() }
        guard unit.rangeOfCharacter(from: .letters) != nil || unit == "%" else { return nil }
        return unit.isEmpty ? nil : unit
    }

    /// A unit printed with the NAME instead of the value — "HbA1c (%)",
    /// "Ferritin, µg/L". Used only when the number itself carries none.
    static func unitHint(in labelRegion: String) -> String? {
        if let m = labelRegion.range(of: #"\(([^)]{1,16})\)"#, options: .regularExpression) {
            let inner = labelRegion[m].dropFirst().dropLast()
            if let u = leadingUnit(in: String(inner)) { return u }
        }
        if let comma = labelRegion.lastIndex(of: ","),
           let u = leadingUnit(in: String(labelRegion[labelRegion.index(after: comma)...])) {
            return u
        }
        return nil
    }

    /// Normalise a printed unit for table lookup: lower-cased, spaces removed,
    /// micro signs folded to "u", superscripts flattened, decimal comma → dot.
    static func normalizeUnit(_ s: String) -> String {
        var t = s.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:()[]"))
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "µ", with: "u")
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: ",", with: ".")
        if t == "l/mmol" { t = "mmol/l" }        // a column-swapped OCR read
        return t
    }

    private static func round(_ v: Double, to places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (v * f).rounded() / f
    }

    private static func nextNonEmpty(after i: Int, in lines: [LabReportLine]) -> Int? {
        var j = i + 1
        while j < lines.count {
            if !lines[j].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return j }
            j += 1
        }
        return nil
    }

    // MARK: Document date

    /// The report's sample date: the first date on a line that names one
    /// ("Collected", "Sample date", "Prøvedato"…); otherwise the first date
    /// printed anywhere. nil when the file carries no parseable date at all —
    /// the review screen then says so instead of inventing one.
    static func documentDate(in lines: [LabReportLine]) -> Date? {
        let keywords = ["collected", "collection", "sample date", "sampled", "drawn",
                        "specimen", "taken", "prøvedato", "prøvetagning", "rekvisition",
                        "dato", "date", "report date", "rapportdato"]
        // A date of birth is NOT a sample date — a line that names one is skipped
        // outright rather than quietly becoming the report's date.
        let notADate = ["birth", "born", "født", "fødsel", "cpr", "dob", "d.o.b"]
        var firstAnywhere: Date?
        for line in lines {
            let (d, _) = SundhedParsers.firstDate(in: line.text)
            guard let d else { continue }
            let lower = line.text.lowercased()
            if notADate.contains(where: { lower.contains($0) }) { continue }
            if firstAnywhere == nil { firstAnywhere = d }
            if keywords.contains(where: { lower.contains($0) }) { return d }
        }
        return firstAnywhere
    }
}

// MARK: - Number reading (EN + DA, and an explicit "won't guess")

/// Reads a printed number token. Where the separator is genuinely ambiguous
/// ("1.234" — one thousand two hundred and thirty four, or 1.234?) it returns
/// `.ambiguous` rather than picking one. Refusing is the honest answer.
public nonisolated enum LabNumber {
    public enum Reading: Equatable, Sendable {
        case value(Double)
        case ambiguous
        case unreadable
    }

    public static func parse(_ token: String) -> Reading {
        let t = token.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.rangeOfCharacter(from: .decimalDigits) != nil else { return .unreadable }

        let hasDot = t.contains("."), hasComma = t.contains(",")

        if hasDot && hasComma {
            // Both present: the LAST one is the decimal separator, the other groups.
            let dotIdx = t.lastIndex(of: ".")!, commaIdx = t.lastIndex(of: ",")!
            let decimal: Character = dotIdx > commaIdx ? "." : ","
            let grouping: Character = decimal == "." ? "," : "."
            let cleaned = t.replacingOccurrences(of: String(grouping), with: "")
                           .replacingOccurrences(of: String(decimal), with: ".")
            return Double(cleaned).map { .value($0) } ?? .unreadable
        }

        if hasDot || hasComma {
            let sep: Character = hasDot ? "." : ","
            let parts = t.split(separator: sep, omittingEmptySubsequences: false)
            // Exactly one separator, exactly three digits after it, and an
            // integer part that could BE a thousands group (1–3 digits, no
            // leading zero) → genuinely ambiguous. Refuse.
            if parts.count == 2, parts[1].count == 3,
               (1...3).contains(parts[0].count), parts[0].first != "0",
               parts[1].allSatisfy(\.isNumber), parts[0].allSatisfy(\.isNumber) {
                return .ambiguous
            }
            if parts.count > 2 {
                // "1.234.567" — grouping, unambiguous.
                let cleaned = t.replacingOccurrences(of: String(sep), with: "")
                return Double(cleaned).map { .value($0) } ?? .unreadable
            }
            let cleaned = t.replacingOccurrences(of: ",", with: ".")
            return Double(cleaned).map { .value($0) } ?? .unreadable
        }

        return Double(t).map { .value($0) } ?? .unreadable
    }
}
