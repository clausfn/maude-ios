// SundhedParsers.swift — Deterministic, on-device parsers for Sundhed.dk exports.
//
// PATH B (PDF/file upload → on-device parse). These parsers consume the flat text
// extracted from a Sundhed.dk PDF (or the page text of the portal) and turn the
// three STRUCTURED sections into coded, derived facts:
//   • parseLabs(_:)      → [SundhedLabMeasurement]  (Danish IUPAC → catalog var)
//   • parseMeds(_:)      → [SundhedMedItem]         (active substance → ATC)
//   • parseDiagnoses(_:) → [String]                 (ICD-10 / SKS codes)
//
// CARDINAL (matches DerivedShareBuilder): raw document text NEVER leaves the
// device. The caller feeds transient text in, gets codes/numbers out, and
// discards the text. Free-text journal narrative is the DEFERRED NLP path
// (see SundhedNarrativeExtractor in SundhedPayload.swift) — not parsed here.
//
// Pure Foundation, framework-free → unit-testable. No network, no persistence.
import Foundation

// MARK: - Parsed value types

/// One lab measurement (one analyte, one rekvisition/date). Aggregation into the
/// contract's `by_variable` summary (latest/mean/n/scaled) happens in
/// SundhedPayloadBuilder — this stays a flat, faithful reading.
public struct SundhedLabMeasurement: Equatable, Sendable {
    public let catalogVar: String     // e.g. "hba1c", "egfr" (bundled crosswalk)
    public let component: String      // Danish IUPAC component, e.g. "Hæmoglobin"
    public let specimen: String?      // "P" | "B" | "U" (from ";P" / ";B" / ";U")
    public let unit: String           // reported unit, e.g. "mmol/L" ("%" after HbA1c conv.)
    public let value: Double          // reported value (NGSP % for HbA1c)
    public let scaleFactor: Double    // canonical-unit scale (1.0 unless crosswalk overrides)
    public let scaledValue: Double    // value * scaleFactor
    public let date: Date?            // rekvisition date if present on the row
}

/// One "Aktuel medicin" row. `atc` is nil when the active substance isn't in the
/// bundled crosswalk yet (the row still counts toward the med total).
public struct SundhedMedItem: Equatable, Sendable {
    public let brand: String              // e.g. "Novorapid FlexPen"
    public let activeSubstance: String    // parenthesised substance, e.g. "Insulin aspart"
    public let atc: String?               // e.g. "A10AB01" (crosswalk); nil if unknown
    public let form: String?              // e.g. "Injektionsvæske, 100 e/ml"
    public let dosage: String?            // e.g. "Efter aftale"
    public let reason: String?            // e.g. "Mod diabetes"
}

// MARK: - Parser

public enum SundhedParsers {

    // MARK: Labs

    /// Parse the LABS section (sundhed.dk Laboratoriesvar). Labs are grouped by
    /// category headers (Hæmatologi, Væske- og elektrolytbalance, Organmarkører,
    /// …); each analyte is declared as "Component;Specimen" (Danish IUPAC, e.g.
    /// "Hæmoglobin;B", "Alanintransaminase [ALAT];P", "eGFR / 1,73m²(CKD-EPI)",
    /// "Leukocytter;B") and its unit ("mmol/L", "U/L", "10^9/L", "mL/min") plus one
    /// numeric value+date per rekvisition follow — sometimes on the SAME line,
    /// sometimes on the ADJACENT line(s). We map the Danish component → catalog var
    /// via the bundled crosswalk and keep only recognised analytes, pairing each
    /// with the nearest numeric value+unit. We never invent values: an analyte with
    /// no numeric reading is skipped.
    public static func parseLabs(_ text: String) -> [SundhedLabMeasurement] {
        var out: [SundhedLabMeasurement] = []
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Active analyte: a recognised, in-crosswalk component whose unit is known.
        // Subsequent value rows attach to it until the next declaration.
        var current: ActiveAnalyte?

        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
            idx += 1
            if line.isEmpty { continue }

            // 1) An analyte declaration resets the active analyte (mapped or not),
            //    so a following value never leaks onto the previous analyte.
            if let decl = parseAnalyteHeader(line) {
                // Resolve the unit: inline if present, else the next non-empty line
                // when it is a bare unit token (Layout B: unit prints below).
                var unit = decl.unit
                if unit == nil, let (u, next) = peekUnit(lines, from: idx) {
                    unit = u
                    idx = next   // consume the standalone unit line
                }
                if let catalogVar = decl.catalogVar, let unit, !unit.isEmpty {
                    let active = ActiveAnalyte(catalogVar: catalogVar, component: decl.component,
                                               specimen: decl.specimen, unit: unit)
                    current = active
                    // Flat single-line row ("Comp;Spec unit  8,5  21.03.2024")? Trust
                    // an inline value ONLY when a rekvisition DATE is also present —
                    // a bare declaration ("eGFR / 1,73m²(CKD-EPI)") has none, so its
                    // qualifier digits (1,73) are never misread as a result.
                    let d = firstDate(in: line)
                    if d.date != nil, let v = numericResult(in: line, unit: unit, excludingDate: d.raw) {
                        out.append(makeMeasurement(active, value: v, date: d.date))
                    }
                } else {
                    current = nil   // unmapped analyte or unknown unit → skip its values
                }
                continue
            }

            // 2) A value row for the active analyte. Pull the rekvisition date (if
            //    any), drop it and the (digit-bearing) unit, then read the FIRST
            //    number that remains (reference ranges/extra columns are ignored).
            guard let cur = current else { continue }
            let d = firstDate(in: line)
            guard let v = numericResult(in: line, unit: cur.unit, excludingDate: d.raw) else { continue }
            out.append(makeMeasurement(cur, value: v, date: d.date))
        }
        return out
    }

    /// A recognised analyte ready to accept value rows (component IS in the
    /// crosswalk and its unit is known — no optionals to unwrap at the value site).
    private struct ActiveAnalyte {
        let catalogVar: String
        let component: String
        let specimen: String?
        let unit: String
    }

    /// Build a measurement, applying the HbA1c IFCC→NGSP conversion and any
    /// canonical-unit scale factor. Never invents a value — the caller has one.
    private static func makeMeasurement(_ cur: ActiveAnalyte, value reported: Double, date: Date?) -> SundhedLabMeasurement {
        var value = reported
        var unit = cur.unit
        let scale = scaleFactor(for: cur.catalogVar)

        // HbA1c is reported IFCC (mmol/mol) in DK — convert to NGSP (%) so the
        // shared figure is comparable to app/clinic targets.
        if cur.catalogVar == "hba1c", cur.unit.lowercased().contains("mmol/mol") {
            value = hba1cIFCCtoNGSP(reported)
            unit = "%"
        }
        return SundhedLabMeasurement(
            catalogVar: cur.catalogVar,
            component: cur.component,
            specimen: cur.specimen,
            unit: unit,
            value: value,
            scaleFactor: scale,
            scaledValue: (value * scale).roundedTo(3),
            date: date
        )
    }

    /// The raw result of recognising an analyte declaration line. `catalogVar` is
    /// nil when the line is structurally an analyte header but the component isn't
    /// in the crosswalk (so its value rows are skipped, not mis-attributed). `unit`
    /// is nil when no inline unit was present — the caller looks to the next line.
    private struct AnalyteHeader {
        let catalogVar: String?
        let component: String
        let specimen: String?
        let unit: String?
    }

    /// Recognise an analyte declaration line, tolerant of both layouts. Real forms:
    ///   "Hæmoglobin;B / mmol/L"             → comp=Hæmoglobin spec=B unit=mmol/L
    ///   "Alanintransaminase [ALAT];P / U/L"  → comp=Alanintransaminase spec=P unit=U/L
    ///   "Leukocytter;B / 10^9/L"             → comp=Leukocytter spec=B unit=10^9/L
    ///   "eGFR / 1,73m²(CKD-EPI)"  ⏎ "mL/min" → comp=eGFR unit=(from next line)
    /// A spaced-slash tail is treated as the unit ONLY if it LOOKS like a unit; the
    /// eGFR "1,73m²(CKD-EPI)" qualifier does not, so it stays part of the component
    /// and the real unit ("mL/min") is picked up from the adjacent line by the caller.
    private static func parseAnalyteHeader(_ line: String) -> AnalyteHeader? {
        var left = line
        var inlineUnit: String?

        // A spaced-slash tail is EITHER the unit ("… / mmol/L"), a unit followed by
        // an inline value+date ("… / mmol/L 4,1 21.03.2024", the same-line layout),
        // or a component qualifier ("eGFR / 1,73m²(CKD-EPI)"). Adopt a unit only
        // when the whole tail — or its first token — looks like one; the eGFR
        // qualifier does neither, so it stays part of the component name.
        if let slash = line.range(of: " / ") {
            let tail = String(line[slash.upperBound...]).trimmingCharacters(in: .whitespaces)
            if looksLikeUnit(tail) {
                inlineUnit = tail
            } else if let head = tail.split(separator: " ").first.map(String.init), looksLikeUnit(head) {
                inlineUnit = head
            }
            left = String(line[..<slash.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // Specimen after ';' (B/P/U). Presence marks this as an analyte label.
        var specimen: String?
        let hasSpecimen = left.range(of: ";[A-Za-z]", options: .regularExpression) != nil
        if let semi = left.firstIndex(of: ";") {
            let spec = String(left[left.index(after: semi)...]).trimmingCharacters(in: .whitespaces)
            specimen = spec.isEmpty ? nil : String(spec.prefix(1)).uppercased()
            left = String(left[..<semi]).trimmingCharacters(in: .whitespaces)
        }

        // Bracketed abbreviation is a strong crosswalk key: "Alanintransaminase [ALAT]".
        var bracket: String?
        let hasBracket = left.contains("[") && left.contains("]")
        if let open = left.firstIndex(of: "["), let close = left.firstIndex(of: "]"), open < close {
            bracket = String(left[left.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            left = String(left[..<open]).trimmingCharacters(in: .whitespaces)
        }

        let component = left.trimmingCharacters(in: .whitespaces)
        guard !component.isEmpty, component.rangeOfCharacter(from: .letters) != nil else { return nil }

        let catalogVar = SundhedParsers.catalogVar(forComponent: component)
            ?? bracket.flatMap { SundhedParsers.catalogVar(forComponent: $0) }

        // Only treat the line as an analyte declaration when it carries a structural
        // marker (specimen, bracket, inline unit) or a known component — this keeps
        // category headers ("Hæmatologi") and prose from resetting the active analyte.
        guard hasSpecimen || hasBracket || inlineUnit != nil || catalogVar != nil else { return nil }
        return AnalyteHeader(catalogVar: catalogVar, component: component, specimen: specimen, unit: inlineUnit)
    }

    /// If the next non-empty line is a bare unit token, return it and the index just
    /// past it (Layout B: the unit prints on the line BELOW the component). Returns
    /// nil when the next real line isn't a unit, so nothing is consumed by mistake.
    private static func peekUnit(_ lines: [String], from start: Int) -> (unit: String, nextIndex: Int)? {
        var j = start
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty { j += 1; continue }
            return looksLikeUnit(l) ? (l, j + 1) : nil
        }
        return nil
    }

    /// Does a token look like a lab unit ("mmol/L", "U/L", "10^9/L", "mL/min", "%",
    /// "mmol/mol", "fL")? Compact, no spaces/parens/commas/brackets (those mark a
    /// component qualifier), and either carries a slash/percent/caret or is a short
    /// alpha token — never a bare number ("2019") or a decimal ("1,73").
    static func looksLikeUnit(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.count <= 12 else { return false }
        if t == "%" { return true }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/^%·µ.-")
        guard t.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard t.rangeOfCharacter(from: .letters) != nil else { return false }  // reject "10", "1.73"
        if t.contains("/") || t.contains("%") || t.contains("^") { return true }
        return t.count <= 6   // short alpha(+digit) token: "U", "mg", "fL", "pmol"
    }

    /// First genuine numeric result on a line for a known analyte, ignoring its
    /// (digit-bearing) unit and any date so "10^9/L" or "21.03.2024" aren't misread.
    private static func numericResult(in line: String, unit: String, excludingDate raw: String) -> Double? {
        var s = line
        if !raw.isEmpty { s = s.replacingOccurrences(of: raw, with: " ") }
        if !unit.isEmpty { s = s.replacingOccurrences(of: unit, with: " ") }
        return firstNumber(in: s)
    }

    // MARK: Meds

    /// Parse the "Aktuel medicin (N)" card. Rows:
    ///   [Startdato] / Brand (Active substance) / Form, styrke / Dosering / Årsag
    /// The card shows NO ATC — we extract the parenthesised ACTIVE SUBSTANCE and
    /// map it to ATC via the bundled crosswalk.
    public static func parseMeds(_ text: String) -> [SundhedMedItem] {
        var out: [SundhedMedItem] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // A med row has a parenthesised substance and the " / " column layout.
            guard line.contains("("), line.contains(")"), line.contains(" / ") else { continue }
            guard let substance = firstParenthesised(line) else { continue }

            var cols = line.components(separatedBy: " / ").map { $0.trimmingCharacters(in: .whitespaces) }
            // Drop an optional leading Startdato column.
            if let first = cols.first, firstDate(in: first).date != nil, !first.contains("(") {
                cols.removeFirst()
            }
            guard let head = cols.first, head.contains("(") else { continue }

            let brand = String(head[..<(head.firstIndex(of: "(") ?? head.endIndex)])
                .trimmingCharacters(in: .whitespaces)
            let form = cols.count > 1 ? cols[1] : nil
            let dosage = cols.count > 2 ? cols[2] : nil
            // Årsag is conventionally the "Mod …" tail; fall back to the last column.
            let reason = cols.dropFirst(3).first(where: { $0.lowercased().hasPrefix("mod ") }) ?? (cols.count > 3 ? cols.last : nil)

            out.append(SundhedMedItem(
                brand: brand.isEmpty ? substance : brand,
                activeSubstance: substance,
                atc: atc(forSubstance: substance),
                form: form,
                dosage: dosage,
                reason: reason
            ))
        }
        return out
    }

    // MARK: Diagnoses

    /// Parse "Aktuelle diagnoser". Each expanded entry reveals
    /// "ICD 10: <sks code>" (D-prefixed SKS, e.g. "dm420"). We take the ICD-10
    /// code directly, validate it, upper-case and de-duplicate (presence = 1).
    public static func parseDiagnoses(_ text: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        // Tolerate "ICD 10", "ICD-10", "ICD10", any spacing around the colon.
        let pattern = "ICD[\\s\\-]?10\\s*:\\s*([A-Za-z][0-9A-Za-z.]+)"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard m.numberOfRanges > 1 else { continue }
            let code = ns.substring(with: m.range(at: 1))
                .replacingOccurrences(of: ".", with: "")
                .uppercased()
            guard isWellFormedICD10(code), !seen.contains(code) else { continue }
            seen.insert(code)
            out.append(code)
        }
        return out
    }

    // MARK: Journal (journal fra sygehus / forløb)

    /// Parse a "Journal fra sygehus" export (the per-contact forløb detail). Each
    /// clinical contact carries a "Diagnoser" block that spells out the diagnosis
    /// as an EXPLICIT ICD-10 (SKS) code — printed inline as "(DE104)", behind a
    /// "Diagnosekode:" label, or on its own line. We harvest those codes only; a
    /// single scan for D-prefixed SKS tokens covers all three printed layouts
    /// because each code is a standalone word.
    ///
    /// The forløb OVERVIEW table lists diagnoses only as free-text descriptions
    /// ("Paroksysmatisk atrieflimren", "Kræft i ileum") with no code attached —
    /// those are deliberately NOT harvested here (no guessing). Returns deduped,
    /// upper-cased ICD-10/SKS codes.
    public static func parseJournal(_ text: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        // D-prefixed SKS administrative codes: leading 'D', an ICD letter, two
        // digits, then optional subdivisions — DE104, DM420, DI489B. `\b` keeps
        // "(DE104)" and "Diagnosekode: DE104" from over-capturing neighbours.
        let pattern = "\\bD[A-Za-z][0-9]{2}[0-9A-Za-z]*\\b"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let code = ns.substring(with: m.range).uppercased()
            guard isWellFormedICD10(code), !seen.contains(code) else { continue }
            seen.insert(code)
            out.append(code)
        }
        // TODO(journal-nlp): map the overview's free-text "Diagnose" descriptions
        // (e.g. "Kræft i ileum") → ICD-10. That is the deferred server/NLP layer
        // (SundhedNarrativeExtractor); we harvest only explicit codes here.
        return out
    }

    /// Validate an ICD-10 code in either the Danish SKS administrative form
    /// (leading 'D' prefix + ICD letter + 2 digits + optional subdivisions, e.g.
    /// "DM420") or the canonical ICD-10 form (letter + 2 digits + optional
    /// subdivisions, e.g. "E11" / "E119").
    public static func isWellFormedICD10(_ code: String) -> Bool {
        let c = code.uppercased()
        func matches(_ pattern: String) -> Bool {
            c.range(of: pattern, options: .regularExpression) != nil
        }
        let sks = "^D[A-Z][0-9]{2}[0-9A-Z]*$"        // DM420, DE119, DI48
        let icd = "^[A-Z][0-9]{2}[0-9A-Z]*$"          // M42, E119
        return matches(sks) || matches(icd)
    }

    // MARK: - HbA1c IFCC → NGSP

    /// Convert HbA1c from IFCC (mmol/mol, DK standard) to NGSP (%): the master
    /// equation NGSP% = (0.09148 × IFCC) + 2.152. Rounded to 1 decimal.
    public static func hba1cIFCCtoNGSP(_ ifcc: Double) -> Double {
        ((0.09148 * ifcc) + 2.152).roundedTo(1)
    }

    // MARK: - Crosswalks (STARTER sets — extensible)

    /// Danish IUPAC component (lower-cased) → catalog variable key.
    /// EXTENSIBLE: add rows as new analytes appear; keys are the catalog v0.4.0
    /// variable names the backend expands scope against.
    static let componentToCatalogVar: [String: String] = [
        // Hæmatologi
        "hæmoglobin": "hemoglobin",
        "hgb": "hemoglobin",
        "leukocytter": "leukocytes",
        "trombocytter": "thrombocytes",
        // Glykæmisk
        "hba1c": "hba1c",
        "hæmoglobin a1c": "hba1c",
        "hba1c(ifcc)": "hba1c",
        "glukose": "glucose",
        // Nyre / organmarkører
        "kreatinin": "creatinine",
        "egfr": "egfr",
        "alanintransaminase": "alat",
        "alat": "alat",
        // Lipider
        "ldl-kolesterol": "ldl_cholesterol",
        "ldl": "ldl_cholesterol",
        "hdl-kolesterol": "hdl_cholesterol",
        "hdl": "hdl_cholesterol",
        "kolesterol": "cholesterol_total",
        // Væske- og elektrolytbalance
        "kalium": "potassium",
        "natrium": "sodium",
        // Inflammation
        "c-reaktivt protein": "crp",
        "crp": "crp",
        // Endokrin
        "tsh": "tsh",
    ]

    /// Active substance (lower-cased) → ATC code. EXTENSIBLE.
    /// Seeded with the substances in the reference exports plus common DK meds.
    static let substanceToATC: [String: String] = [
        "insulin aspart": "A10AB01",
        "insulin degludec": "A10AE06",
        "cyanocobalamin": "B03BA01",
        "pramipexol": "N04BC05",
        "metformin": "A10BA02",
        "apixaban": "B01AF02",
        "metoprolol": "C07AB02",
        "atorvastatin": "C10AA05",
        "simvastatin": "C10AA01",
        "acetylsalicylsyre": "B01AC06",
    ]

    /// Canonical-unit scale factors per catalog var (default 1.0). EXTENSIBLE —
    /// populate when a catalog var's canonical unit differs from the DK report unit.
    static let scaleFactors: [String: Double] = [:]

    static func catalogVar(forComponent component: String) -> String? {
        componentToCatalogVar[normalizeKey(component)]
    }
    static func atc(forSubstance substance: String) -> String? {
        substanceToATC[normalizeKey(substance)]
    }
    static func scaleFactor(for catalogVar: String) -> Double {
        scaleFactors[catalogVar] ?? 1.0
    }

    static func normalizeKey(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    // MARK: - Number / date scanning (Danish locale)

    /// Parse a Danish-formatted decimal ("1,73", "10,5", "1.234,5") to a Double.
    static func daNumber(_ token: String) -> Double? {
        var t = token.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        t = t.replacingOccurrences(of: " ", with: "")
        if t.contains(".") && t.contains(",") {
            // "." thousands, "," decimal.
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if t.contains(",") {
            t = t.replacingOccurrences(of: ",", with: ".")
        }
        return Double(t)
    }

    /// First numeric token on a line (Danish decimals), skipping standalone
    /// integers that are obviously not results is left to the caller's context.
    static func firstNumber(in line: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: "[-+]?[0-9][0-9\\.\\s]*,?[0-9]*") else { return nil }
        let ns = line as NSString
        for m in re.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            let raw = ns.substring(with: m.range).trimmingCharacters(in: .whitespaces)
            if let v = daNumber(raw) { return v }
        }
        return nil
    }

    /// First date on a line (dd-MM-yyyy, dd.MM.yyyy, or yyyy-MM-dd) with its raw
    /// substring (so the caller can strip it before reading the value).
    static func firstDate(in line: String) -> (date: Date?, raw: String) {
        let patterns = [
            ("dd-MM-yyyy", "\\b[0-9]{2}-[0-9]{2}-[0-9]{4}\\b"),
            ("dd.MM.yyyy", "\\b[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}\\b"),
            ("yyyy-MM-dd", "\\b[0-9]{4}-[0-9]{2}-[0-9]{2}\\b"),
        ]
        for (fmt, pat) in patterns {
            guard let re = try? NSRegularExpression(pattern: pat) else { continue }
            let ns = line as NSString
            if let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: m.range)
                let df = DateFormatter()
                df.calendar = Calendar(identifier: .iso8601)
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = fmt
                return (df.date(from: raw), raw)
            }
        }
        return (nil, "")
    }

    /// First `(...)` group's contents, e.g. brand "(Insulin aspart)" → "Insulin aspart".
    static func firstParenthesised(_ line: String) -> String? {
        guard let open = line.firstIndex(of: "("),
              let close = line[line.index(after: open)...].firstIndex(of: ")") else { return nil }
        let inner = String(line[line.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        return inner.isEmpty ? nil : inner
    }
}

private extension Double {
    func roundedTo(_ places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
