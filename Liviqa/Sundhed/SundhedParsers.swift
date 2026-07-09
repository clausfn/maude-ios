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

    /// Parse the LABS section. Labs are grouped by category; each analyte is
    /// declared as "Component;Specimen / unit" (Danish IUPAC), followed by one
    /// value per rekvisition date. We map the Danish component → catalog var via
    /// the bundled crosswalk and keep only recognised analytes.
    public static func parseLabs(_ text: String) -> [SundhedLabMeasurement] {
        var out: [SundhedLabMeasurement] = []
        var current: AnalyteHeader?

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // An analyte declaration resets the active variable. Lines that don't
            // map to a known catalog var set `current = nil`, so their value rows
            // are skipped (we never guess).
            if let header = parseAnalyteHeader(line) {
                current = header.catalogVar == nil ? nil : header
                continue
            }
            guard let cur = current, let catalogVar = cur.catalogVar else { continue }

            // A value row: pull the rekvisition date (if any), then the FIRST
            // number after it (reference ranges/extra columns are ignored).
            let date = firstDate(in: line)
            let stripped = date.date == nil ? line : line.replacingOccurrences(of: date.raw, with: " ")
            guard let reported = firstNumber(in: stripped) else { continue }

            var value = reported
            var unit = cur.unit
            let scale = scaleFactor(for: catalogVar)

            // HbA1c is reported IFCC (mmol/mol) in DK — convert to NGSP (%) so the
            // shared figure is comparable to app/clinic targets.
            if catalogVar == "hba1c", cur.unit.lowercased().contains("mmol/mol") {
                value = hba1cIFCCtoNGSP(reported)
                unit = "%"
            }

            out.append(SundhedLabMeasurement(
                catalogVar: catalogVar,
                component: cur.component,
                specimen: cur.specimen,
                unit: unit,
                value: value,
                scaleFactor: scale,
                scaledValue: (value * scale).roundedTo(3),
                date: date.date
            ))
        }
        return out
    }

    private struct AnalyteHeader {
        let catalogVar: String?   // nil ⇒ recognised-as-header but not in crosswalk
        let component: String
        let specimen: String?
        let unit: String
    }

    /// Recognise an analyte declaration line. Real layouts:
    ///   "Hæmoglobin;B / mmol/L"            → comp=Hæmoglobin  spec=B  unit=mmol/L
    ///   "Alanintransaminase [ALAT];P / U/L" → comp=Alanintransaminase spec=P unit=U/L
    ///   "eGFR / 1,73m²(CKD-EPI) / mL/min"   → comp=eGFR unit=mL/min (middle dropped)
    ///   "Leukocytter;B / 10^9/L"            → comp=Leukocytter spec=B unit=10^9/L
    /// The unit's own "/" (mmol/L, 10^9/L) is preserved because we split on " / "
    /// (space-slash-space), which those units don't contain.
    private static func parseAnalyteHeader(_ line: String) -> AnalyteHeader? {
        guard line.contains(" / ") || line.contains(" /") || line.hasSuffix("/L") else {
            // Fast reject: a header always carries a unit behind a spaced slash.
            return nil
        }
        let parts = line.components(separatedBy: " / ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, let unit = parts.last, !unit.isEmpty else { return nil }

        var left = parts[0]
        var specimen: String?
        if let semi = left.firstIndex(of: ";") {
            let spec = String(left[left.index(after: semi)...]).trimmingCharacters(in: .whitespaces)
            specimen = spec.isEmpty ? nil : String(spec.prefix(1)).uppercased()
            left = String(left[..<semi]).trimmingCharacters(in: .whitespaces)
        }

        // Bracketed abbreviation is a strong crosswalk key: "Alanintransaminase [ALAT]".
        var bracket: String?
        if let open = left.firstIndex(of: "["), let close = left.firstIndex(of: "]"), open < close {
            bracket = String(left[left.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            left = String(left[..<open]).trimmingCharacters(in: .whitespaces)
        }

        let component = left
        let catalogVar = SundhedParsers.catalogVar(forComponent: component)
            ?? bracket.flatMap { SundhedParsers.catalogVar(forComponent: $0) }
        // A line that has a unit but no known component is still a header (so its
        // values are skipped, not mis-attributed) — return it with a nil var.
        // A line that isn't a plausible component name at all → not a header.
        guard !component.isEmpty, component.rangeOfCharacter(from: .letters) != nil else { return nil }
        return AnalyteHeader(catalogVar: catalogVar, component: component, specimen: specimen, unit: unit)
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
