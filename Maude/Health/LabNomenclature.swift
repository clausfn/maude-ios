// LabNomenclature.swift — display-name mapping layer for lab analytes.
//
// WHY (PR "electric-ink" export fixes, defect C): raw NPU/Danish system suffixes
// (";P", ";Hb(B)", ";Pt(U)", "[ALAT]") were leaking into display names, one drug
// name carried an unescaped HTML entity ("&#32"), and the same analyte appeared
// under Danish and English names inconsistently. This layer fixes all three at
// the DISPLAY boundary:
//   • the RAW source name stays stored (data is never rewritten);
//   • HTML entities are decoded at parse time (pure Foundation decoder below);
//   • the NPU system suffix becomes a STRUCTURED specimen field rendered as a
//     small label ("plasma", "blood", "urine") — never appended punctuation;
//   • common Danish analyte names map to one English display name each,
//     extending the existing `HealthDisplay.scopeKeyToName` pattern.
//
// Also hosts the clinical PANEL classification the exported summary groups by
// (defect D): metabolic/glucose, lipids, liver, kidney & electrolytes, blood
// count, thyroid, inflammation, vitamins & iron, serology, other.
//
// Pure Foundation, framework-free → unit-testable. Display mapping only —
// nothing here changes what is stored or what leaves the device.
import Foundation

public enum LabNomenclature {

    // MARK: - HTML entity decoding (parse-time; pure Foundation)

    /// Decode the HTML entities that appear in Danish register exports —
    /// numeric ("&#32;", "&#x26;", tolerant of a missing semicolon as seen in
    /// the FMK medicine names) and the small named set (&amp; &aelig; &oslash;
    /// &aring; …). Unknown entities are left untouched (never guessed).
    public static func decodeHTMLEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = s
        // Numeric entities, decimal and hex, with or without the closing ';'.
        if let re = try? NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|[0-9]+);?") {
            let ns = out as NSString
            var replacements: [(NSRange, String)] = []
            for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)) {
                let token = ns.substring(with: m.range(at: 1))
                let value: UInt32?
                if token.lowercased().hasPrefix("x") {
                    value = UInt32(token.dropFirst(), radix: 16)
                } else {
                    value = UInt32(token)
                }
                if let v = value, let scalar = Unicode.Scalar(v) {
                    replacements.append((m.range, String(Character(scalar))))
                }
            }
            for (range, text) in replacements.reversed() {
                out = (out as NSString).replacingCharacters(in: range, with: text)
            }
        }
        // Named entities (longest first so "&aring;" wins over any prefix).
        let named: [(String, String)] = [
            ("&nbsp;", "\u{00A0}"), ("&quot;", "\""), ("&apos;", "'"),
            ("&aelig;", "æ"), ("&AElig;", "Æ"), ("&oslash;", "ø"), ("&Oslash;", "Ø"),
            ("&aring;", "å"), ("&Aring;", "Å"),
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
        ]
        for (entity, char) in named {
            out = out.replacingOccurrences(of: entity, with: char)
        }
        // Collapse doubled whitespace a decoded "&#32" often leaves behind.
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Specimen (NPU system suffix → structured label)

    /// Human label for an NPU/Danish system token (the part after ';' in
    /// "Hæmoglobin;B" or "Glukose;Pt(U)"). Rendered as a SMALL LABEL next to the
    /// analyte name — never appended to it. Unknown tokens fall back to the
    /// token itself lower-cased (still a label, never invented anatomy).
    public static func specimenLabel(forSystemToken raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let t = decodeHTMLEntities(raw).trimmingCharacters(in: .whitespaces)
        let key = t.lowercased()
        let known: [String: String] = [
            "p": "plasma",
            "b": "blood",
            "u": "urine",
            "s": "serum",
            "csv": "spinal fluid",
            "csf": "spinal fluid",
            "f": "stool",
            "pt": "timed collection",
            "pt(u)": "urine collection",
            "pt(u.)": "urine collection",
            "hb(b)": "blood",
            "hb": "blood",
            "erc(b)": "blood",
            "p(fpt)": "plasma, fasting",
            "fpt": "fasting",
        ]
        if let label = known[key] { return label }
        // Composite tokens like "Pt(U)"-variants: try the inner bracket.
        if let open = t.firstIndex(of: "("), let close = t.firstIndex(of: ")"), open < close {
            let inner = String(t[t.index(after: open)..<close]).lowercased()
            if let label = known[inner] { return label }
        }
        return key
    }

    /// Split a raw analyte name that still carries its NPU suffix
    /// ("Glukose;P", "Hæmoglobin A1c;Hb(B)") into (name, systemToken).
    public static func splitSystemSuffix(_ raw: String) -> (name: String, system: String?) {
        let decoded = decodeHTMLEntities(raw)
        guard let semi = decoded.firstIndex(of: ";") else { return (decoded, nil) }
        let name = String(decoded[..<semi]).trimmingCharacters(in: .whitespaces)
        let system = String(decoded[decoded.index(after: semi)...]).trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? decoded : name, system.isEmpty ? nil : system)
    }

    // MARK: - Analyte display names (Danish → one English name each)

    /// Danish (or already-English) analyte name, normalised → English display
    /// name. Extends the `HealthDisplay.scopeKeyToName` pattern to the analytes
    /// a Danish lab record commonly carries. The raw source name is STORED
    /// unchanged; this mapping is applied only at display/export time.
    static let danishToEnglish: [String: String] = [
        // Haematology
        "hæmoglobin": "Haemoglobin",
        "hgb": "Haemoglobin",
        "erytrocytter": "Erythrocytes (red cells)",
        "leukocytter": "Leukocytes (white cells)",
        "trombocytter": "Platelets",
        "hæmatokrit": "Haematocrit",
        "erytrocytvolumen": "Mean cell volume (MCV)",
        "mcv": "Mean cell volume (MCV)",
        "mch": "Mean cell haemoglobin (MCH)",
        "mchc": "Mean cell haemoglobin conc. (MCHC)",
        "retikulocytter": "Reticulocytes",
        "neutrofilocytter": "Neutrophils",
        "neutrofile granulocytter": "Neutrophils",
        "lymfocytter": "Lymphocytes",
        "monocytter": "Monocytes",
        "eosinofilocytter": "Eosinophils",
        "basofilocytter": "Basophils",
        // Glycaemic
        "hba1c": "HbA1c",
        "hæmoglobin a1c": "HbA1c",
        "hba1c(ifcc)": "HbA1c",
        "glukose": "Glucose",
        "glucose": "Glucose",
        // Kidney & electrolytes
        "kreatinin": "Creatinine",
        "kreatininium": "Creatinine",
        "egfr": "eGFR",
        "egfr / 1,73m²(ckd-epi)": "eGFR",
        "karbamid": "Urea",
        "urat": "Urate",
        "natrium": "Sodium",
        "natriumion": "Sodium",
        "kalium": "Potassium",
        "kaliumion": "Potassium",
        "calcium": "Calcium",
        "calciumion frit": "Calcium (ionised)",
        "magnesium": "Magnesium",
        "magnesiumion": "Magnesium",
        "fosfat": "Phosphate",
        "klorid": "Chloride",
        // Liver
        "alanintransaminase": "ALT (alanine transaminase)",
        "alat": "ALT (alanine transaminase)",
        "aspartattransaminase": "AST (aspartate transaminase)",
        "asat": "AST (aspartate transaminase)",
        "basisk fosfatase": "Alkaline phosphatase",
        "gamma-glutamyltransferase": "GGT (gamma-GT)",
        "ggt": "GGT (gamma-GT)",
        "bilirubin": "Bilirubin",
        "bilirubiner": "Bilirubin",
        "albumin": "Albumin",
        "amylase": "Amylase",
        "pankreas-amylase": "Pancreatic amylase",
        "laktatdehydrogenase": "LDH (lactate dehydrogenase)",
        "ldh": "LDH (lactate dehydrogenase)",
        // Lipids
        "kolesterol": "Total cholesterol",
        "cholesterol": "Total cholesterol",
        "ldl-kolesterol": "LDL cholesterol",
        "ldl": "LDL cholesterol",
        "hdl-kolesterol": "HDL cholesterol",
        "hdl": "HDL cholesterol",
        "triglycerid": "Triglycerides",
        "triglycerider": "Triglycerides",
        // Thyroid
        "tsh": "TSH",
        "thyrotropin": "TSH",
        "thyroxin frit": "Free T4",
        "t4 frit": "Free T4",
        "triiodthyronin frit": "Free T3",
        "t3 frit": "Free T3",
        // Inflammation
        "c-reaktivt protein": "CRP",
        "crp": "CRP",
        "sænkningsreaktion": "ESR (sedimentation rate)",
        // Vitamins & iron
        "ferritin": "Ferritin",
        "jern": "Iron",
        "transferrin": "Transferrin",
        "transferrinmætning": "Transferrin saturation",
        "cobalamin": "Vitamin B12",
        "cobalaminer": "Vitamin B12",
        "vitamin b12": "Vitamin B12",
        "folat": "Folate",
        "folater": "Folate",
        "25-hydroxy-vitamin d": "Vitamin D (25-OH)",
        "vitamin d": "Vitamin D (25-OH)",
        "d-vitamin": "Vitamin D (25-OH)",
        // Coagulation
        "koagulationsfaktor ii+vii+x": "INR (coagulation)",
        "inr": "INR (coagulation)",
        // Urine
        "urin opsamlingstid": "Urine collection time",
        "opsamlingstid": "Collection time",
        "urin volumen": "Urine volume",
        "albumin/kreatinin-ratio": "Albumin/creatinine ratio",
        "u-albumin": "Urine albumin",
    ]

    /// One English display name for a raw analyte name as the source wrote it —
    /// entity-decoded, suffix-stripped, bracket abbreviations honoured, Danish
    /// mapped to English. Falls back to the cleaned source name (capitalised),
    /// so a name NEVER renders with ";P"-style punctuation or entities.
    public static func displayName(forRawAnalyte raw: String) -> String {
        let (name, _) = splitSystemSuffix(raw)
        var clean = name
        // "[ALAT]"-style bracketed abbreviation: try it as a key, then strip it.
        var bracketKey: String?
        if let open = clean.firstIndex(of: "["), let close = clean.firstIndex(of: "]"), open < close {
            bracketKey = String(clean[clean.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            clean.removeSubrange(open...close)
            clean = clean.trimmingCharacters(in: .whitespaces)
        }
        let key = normalise(clean)
        if let mapped = danishToEnglish[key] { return mapped }
        if let bk = bracketKey, let mapped = danishToEnglish[normalise(bk)] { return mapped }
        // Qualifier tails like "eGFR / 1,73m²(CKD-EPI)" → try the head token.
        if let slash = clean.range(of: " / ") {
            let head = String(clean[..<slash.lowerBound]).trimmingCharacters(in: .whitespaces)
            if let mapped = danishToEnglish[normalise(head)] { return mapped }
        }
        guard !clean.isEmpty else { return raw }
        return clean.prefix(1).uppercased() + clean.dropFirst()
    }

    static func normalise(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    // MARK: - Clinical panels (export grouping)

    /// The clinical panel a lab analyte belongs to in the exported summary.
    /// A GROUPING for readability — carries no judgement and no ordering of
    /// importance beyond "what a clinician expects to find together".
    public enum LabPanel: Int, CaseIterable, Sendable {
        case metabolic, lipids, liver, kidney, bloodCount, thyroid
        case inflammation, vitaminsIron, serology, other

        public var title: String {
            switch self {
            case .metabolic:    return "Metabolic & glucose"
            case .lipids:       return "Lipids"
            case .liver:        return "Liver & pancreas"
            case .kidney:       return "Kidney & electrolytes"
            case .bloodCount:   return "Blood count"
            case .thyroid:      return "Thyroid"
            case .inflammation: return "Inflammation"
            case .vitaminsIron: return "Vitamins & iron"
            case .serology:     return "Serology & screens"
            case .other:        return "Other results"
            }
        }
    }

    /// Canonical catalog scopeKeys → panel (exact matches first).
    private static let scopeKeyPanels: [String: LabPanel] = [
        "hba1c": .metabolic, "glucose": .metabolic,
        "ldl_cholesterol": .lipids, "hdl_cholesterol": .lipids,
        "cholesterol_total": .lipids, "triglycerides": .lipids,
        "alat": .liver,
        "creatinine": .kidney, "egfr": .kidney, "potassium": .kidney, "sodium": .kidney,
        "hemoglobin": .bloodCount, "leukocytes": .bloodCount, "thrombocytes": .bloodCount,
        "tsh": .thyroid,
        "crp": .inflammation,
        "ferritin": .vitaminsIron, "vitamin_d": .vitaminsIron, "vitamin_b12": .vitaminsIron,
    ]

    /// Name-pattern fallbacks (Danish + English substrings, checked in order) for
    /// passthrough analytes with no catalog scopeKey yet.
    private static let namePatterns: [(pattern: String, panel: LabPanel)] = [
        // Serology / screens
        ("antistof", .serology), ("antigen", .serology), ("antibod", .serology),
        (" rna", .serology), (" dna", .serology), ("-rna", .serology), ("-dna", .serology),
        ("igg", .serology), ("igm", .serology), ("hiv", .serology),
        ("hepatitis", .serology), ("borrelia", .serology), ("virus", .serology),
        ("sars", .serology), ("screen", .serology), ("dyrkning", .serology),
        // Lipids
        ("kolesterol", .lipids), ("cholesterol", .lipids), ("triglycerid", .lipids),
        ("lipoprotein", .lipids),
        // Glycaemic
        ("hba1c", .metabolic), ("glukos", .metabolic), ("glucos", .metabolic),
        ("insulin", .metabolic), ("c-peptid", .metabolic),
        // Liver / pancreas
        ("transaminase", .liver), ("alat", .liver), ("asat", .liver),
        ("fosfatase", .liver), ("glutamyltransferase", .liver), ("ggt", .liver),
        ("bilirubin", .liver), ("albumin/krea", .kidney), ("albumin", .liver),
        ("amylase", .liver), ("laktatdehydrogenase", .liver),
        // Kidney & electrolytes
        ("kreatinin", .kidney), ("creatinin", .kidney), ("egfr", .kidney),
        ("karbamid", .kidney), ("urea", .kidney), ("urat", .kidney),
        ("natrium", .kidney), ("sodium", .kidney), ("kalium", .kidney),
        ("potassium", .kidney), ("calcium", .kidney), ("magnesium", .kidney),
        ("fosfat", .kidney), ("phosphat", .kidney), ("klorid", .kidney),
        ("urin", .kidney), ("urine", .kidney),
        // Blood count
        ("hæmoglobin", .bloodCount), ("hemoglobin", .bloodCount), ("haemoglobin", .bloodCount),
        ("erytrocyt", .bloodCount), ("erythrocyt", .bloodCount),
        ("leukocyt", .bloodCount), ("trombocyt", .bloodCount), ("platelet", .bloodCount),
        ("hæmatokrit", .bloodCount), ("mcv", .bloodCount), ("mchc", .bloodCount),
        ("retikulocyt", .bloodCount), ("neutrofil", .bloodCount), ("lymfocyt", .bloodCount),
        ("monocyt", .bloodCount), ("eosinofil", .bloodCount), ("basofil", .bloodCount),
        // Thyroid
        ("tsh", .thyroid), ("thyro", .thyroid), ("t4", .thyroid), ("t3", .thyroid),
        // Inflammation
        ("reaktivt protein", .inflammation), ("crp", .inflammation),
        ("sænkning", .inflammation),
        // Vitamins & iron
        ("ferritin", .vitaminsIron), ("transferrin", .vitaminsIron),
        ("jern", .vitaminsIron), ("cobalamin", .vitaminsIron), ("b12", .vitaminsIron),
        ("folat", .vitaminsIron), ("vitamin", .vitaminsIron),
        // Coagulation rides with blood count
        ("koagulation", .bloodCount), ("inr", .bloodCount),
    ]

    /// Panel for a stored observation: exact scopeKey first, then name patterns
    /// over the raw analyte name; qualitative rows with no other home default to
    /// serology (screens are the common qualitative case); everything else `other`.
    public static func panel(scopeKey: String, isQualitative: Bool = false) -> LabPanel {
        if let p = scopeKeyPanels[scopeKey] { return p }
        let (name, _) = splitSystemSuffix(scopeKey)
        let key = normalise(name)
        for (pattern, panel) in namePatterns where key.contains(pattern) {
            return panel
        }
        return isQualitative ? .serology : .other
    }
}
