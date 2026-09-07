// HealthSummaryDocument.swift — the citizen's exported health summary, as a
// DOCUMENT MODEL (PR "electric-ink": complete redesign of the export).
//
// Two readers: the citizen handing it over, and a clinician with 90 seconds.
// Page 1 = identity block · major diagnoses in plain language · current
// medicines · a "latest key values" band. Then the lab panels (metabolic/
// glucose, lipids, liver, kidney, blood count, thyroid, inflammation,
// vitamins/iron, serology, other) — within each analyte, readings NEWEST FIRST
// with their REAL specimen dates, and the personal PRIOR value where history
// exists. Appendix = past/minor/administrative diagnosis entries + excluded
// collection artifacts + the full source citation.
//
// RAILS:
//  • dates are the source's specimen dates; a missing date renders as
//    "date not recorded" — NEVER the import date (defect A);
//  • qualitative results render as WORDS ("Not detected"), never 0 + unit
//    (defect B); collection artifacts are excluded and listed in the appendix;
//  • names are mapped via LabNomenclature (no ";P" suffixes, no HTML entities,
//    one English name per analyte; the raw source name stays in the data);
//  • NO generated judgements — values, dates, names only (FR-NDG-06 posture:
//    the framing strings below are fixed copy, guard-checked in tests);
//  • no population reference ranges as judgements; when the SOURCE supplied an
//    interval and we captured it, it is shown labelled as the source's;
//  • the hidden Provenance{REAL,SIMULATED,EXTERNAL} field never renders — the
//    user-facing source labels here are `HealthDataSource.displayLabel`;
//  • the pull date belongs in the HEADER ("Sundhed.dk record as of <date>"),
//    not on every row.
//
// This model renders two ways from the SAME structure, same order:
//  • `plainText()` — the accessibility/secondary artifact (below);
//  • `HealthSummaryPDF.render(_:)` — the primary A4 print artifact.
//
// Pure Foundation (the PDF renderer lives separately) → unit/golden-testable.
import Foundation

struct HealthSummaryDocument {

    // MARK: - Structure

    struct SourceStamp: Equatable {
        let label: String       // "Sundhed.dk record as of 12 Aug 2026"
    }

    /// One line in the page-1 "Latest key values" band.
    struct KeyValueLine: Equatable {
        let name: String        // "HbA1c"
        let valueText: String   // "49 %" (value + unit; already formatted)
        let dateText: String    // "12 Mar 2026" | "date not recorded"
        let priorText: String?  // "previous 51 % — 3 Nov 2025"
    }

    /// One reading of one analyte (already display-formatted).
    struct LabEntry: Equatable {
        let valueText: String       // "6.1 mmol/L" or "Not detected"
        let dateText: String        // "12 Mar 2026" | "date not recorded"
        let isQualitative: Bool
        let sourceReference: String?    // the SOURCE's interval, when captured
    }

    /// One analyte inside a panel: entries newest first.
    struct LabLine: Equatable {
        let name: String            // English display name (mapped)
        let specimenLabel: String?  // "plasma" | "blood" | "urine" | …
        let entries: [LabEntry]     // newest first; [0] = latest, [1...] = priors
        let sourceLabel: String     // "Sundhed.dk" (user-facing source label)
    }

    struct PanelSection: Equatable {
        let title: String
        let lines: [LabLine]
    }

    struct MedicineLine: Equatable {
        let name: String        // entity-decoded, whitespace-cleaned
        let form: String?
        let atc: String?
        let sourceLabel: String
    }

    struct DiagnosisLine: Equatable {
        let name: String        // plain language
        let code: String        // ICD-10 / SKS
        let sinceText: String?  // "since 2019"
        let sourceLabel: String
    }

    // MARK: - Content (in document order)

    let personName: String?         // declared name — never an email; nil = no name line
    let generatedText: String       // "Generated 19 Aug 2026"
    let sources: [SourceStamp]      // pull dates live HERE, not on rows
    let includedText: String        // "Includes 42 lab results · 12 diagnoses · 6 medicines"
    let majorDiagnoses: [DiagnosisLine]
    let medicines: [MedicineLine]
    let keyValues: [KeyValueLine]
    let panels: [PanelSection]
    let appendixDiagnoses: [DiagnosisLine]
    let excludedArtifactLines: [String]
    let isEmpty: Bool

    // MARK: - Fixed copy (framing only — guard-checked in tests; no judgements)

    static let title = "Health summary"
    static let noDateText = "date not recorded"
    static let diagnosesNote = HealthDisplay.diagnosesExplainer
    static let keyValuesTitle = "Latest key values"
    static let majorDiagnosesTitle = "Diagnoses — major & ongoing"
    static let medicinesTitle = "Current medicines"
    static let labsTitle = "Lab results"
    static let appendixTitle = "Appendix — past, minor & administrative entries"
    static let artifactsTitle = "Rows excluded as collection artifacts"
    static let footer = "Exported from Maude · your data, shared by you"
    static let sourceReferencePrefix = "source reference interval"

    // MARK: - Build (store → document)

    /// Assemble the document from the on-device canonical store. Deterministic:
    /// every collection is explicitly sorted, dates formatted with a fixed
    /// POSIX formatter — so a fixture store renders byte-identical text.
    /// App-tracked wellness keys that are NOT lab results: blood pressure and
    /// weight surface in the key-values band; sleep stays an in-app metric and
    /// does not enter the clinician document at all.
    private static let nonLabScopeKeys: Set<String> = [
        "weight", "systolic_bp", "diastolic_bp", "sleep_hours",
    ]

    static func build(store: HealthStore, personName: String?, now: Date = Date()) -> HealthSummaryDocument {
        let fullHistory = store.observationHistory()       // artifacts excluded
        let history = fullHistory.filter { !nonLabScopeKeys.contains($0.key) }
        let artifacts = store.artifactObservations()
        let conds = store.conditions()
        let meds = store.medications()

        // --- Header --------------------------------------------------------
        let generatedText = "Generated \(Self.dateText(now))"
        let sources = sourceStamps(history: fullHistory, conditions: conds, medications: meds)
        let labCount = history.values.reduce(0) { $0 + $1.count }
        var included: [String] = []
        if labCount > 0 { included.append("\(labCount) lab result\(labCount == 1 ? "" : "s")") }
        if !conds.isEmpty { included.append("\(conds.count) diagnos\(conds.count == 1 ? "is" : "es")") }
        if !meds.isEmpty { included.append("\(meds.count) medicine\(meds.count == 1 ? "" : "s")") }
        let includedText = included.isEmpty ? "No records imported yet" : "Includes " + included.joined(separator: " · ")

        // --- Diagnoses (major → page 1; rest → appendix) -------------------
        func diagnosisLine(_ c: HealthCondition) -> DiagnosisLine {
            let name = (c.label?.isEmpty == false) ? c.label! : HealthDisplay.conditionName(for: c.icd10)
            return DiagnosisLine(
                name: name,
                code: c.icd10.uppercased(),
                sinceText: c.onsetDate.map { HealthDisplay.sinceText($0) },
                sourceLabel: sourceLabel(c.source)
            )
        }
        let major = conds.filter { HealthDisplay.conditionTier(for: $0.icd10) == .major }.map(diagnosisLine)
        let secondary = conds.filter { HealthDisplay.conditionTier(for: $0.icd10) != .major }.map(diagnosisLine)

        // --- Medicines -----------------------------------------------------
        let medicineLines: [MedicineLine] = meds.map { m in
            MedicineLine(
                name: cleanName(m.name),
                form: m.form.map(cleanName),
                atc: m.atc?.trimmingCharacters(in: .whitespaces),
                sourceLabel: sourceLabel(m.source)
            )
        }

        // --- Labs: panels + key-value band ---------------------------------
        var panelBuckets: [LabNomenclature.LabPanel: [LabLine]] = [:]
        for (scopeKey, rows) in history {
            guard let newest = rows.first else { continue }
            let entries: [LabEntry] = rows.prefix(3).map { entry(for: $0) }
            let line = LabLine(
                name: HealthDisplay.labName(for: scopeKey),
                specimenLabel: HealthDisplay.specimenLabel(for: newest),
                entries: entries,
                sourceLabel: sourceLabel(newest.source)
            )
            let panel = LabNomenclature.panel(scopeKey: scopeKey,
                                              isQualitative: newest.kind == .qualitative)
            panelBuckets[panel, default: []].append(line)
        }
        let panels: [PanelSection] = LabNomenclature.LabPanel.allCases.compactMap { panel in
            guard var lines = panelBuckets[panel], !lines.isEmpty else { return nil }
            lines.sort { $0.name.lowercased() < $1.name.lowercased() }
            return PanelSection(title: panel.title, lines: lines)
        }

        let keyValues = keyValueBand(history: fullHistory)

        // --- Appendix: excluded artifacts ----------------------------------
        let artifactLines: [String] = artifacts.map { a in
            let name = HealthDisplay.labName(for: a.scopeKey)
            let unit = a.unit.isEmpty ? "" : " \(a.unit)"
            return "\(name) — \(HealthDisplay.number(a.value))\(unit) — \(dateText(for: a))"
        }

        return HealthSummaryDocument(
            personName: personName?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? personName?.trimmingCharacters(in: .whitespaces) : nil,
            generatedText: generatedText,
            sources: sources,
            includedText: includedText,
            majorDiagnoses: major,
            medicines: medicineLines,
            keyValues: keyValues,
            panels: panels,
            appendixDiagnoses: secondary,
            excludedArtifactLines: artifactLines,
            isEmpty: labCount == 0 && conds.isEmpty && meds.isEmpty
        )
    }

    // MARK: - Assembly helpers

    /// The date shown for one observation: the REAL specimen date when the
    /// source carried one; the citizen's own entry date for manual rows and the
    /// sample date for HealthKit rows (both genuinely theirs); otherwise
    /// "date not recorded" — never the import date dressed as a result date.
    static func dateText(for o: HealthObservation) -> String {
        if let d = o.specimenDate { return dateText(d) }
        switch HealthDataSource(rawValue: o.source) {
        case .manual, .healthKit: return dateText(o.effectiveDate)
        default: return noDateText
        }
    }

    private static func entry(for o: HealthObservation) -> LabEntry {
        let valueText: String
        if o.kind == .qualitative {
            // WORDS, never 0 + unit. English display word; the source's own
            // wording stays stored on the row.
            valueText = SundhedParsers.qualitativeDisplayWord(o.resultText ?? "Result on file")
        } else {
            valueText = "\(HealthDisplay.number(o.value))\(o.unit.isEmpty ? "" : " \(o.unit)")"
        }
        return LabEntry(
            valueText: valueText,
            dateText: dateText(for: o),
            isQualitative: o.kind == .qualitative,
            sourceReference: o.sourceRefInterval
        )
    }

    /// The handful a clinician looks for first: HbA1c, glucose, lipid headline,
    /// kidney eGFR (falling back to creatinine), blood pressure when held.
    /// Value · unit · REAL date · personal prior where history exists.
    private static func keyValueBand(history: [String: [HealthObservation]]) -> [KeyValueLine] {
        func numericRows(_ key: String) -> [HealthObservation] {
            (history[key] ?? []).filter { $0.kind == .quantitative }
        }
        func line(_ key: String, as name: String? = nil) -> KeyValueLine? {
            let rows = numericRows(key)
            guard let latest = rows.first else { return nil }
            let prior = rows.dropFirst().first
            return KeyValueLine(
                name: name ?? HealthDisplay.labName(for: key),
                valueText: "\(HealthDisplay.number(latest.value))\(latest.unit.isEmpty ? "" : " \(latest.unit)")",
                dateText: dateText(for: latest),
                priorText: prior.map {
                    "previous \(HealthDisplay.number($0.value))\($0.unit.isEmpty ? "" : " \($0.unit)") — \(dateText(for: $0))"
                }
            )
        }
        var out: [KeyValueLine] = []
        if let l = line("hba1c") { out.append(l) }
        if let l = line("glucose") { out.append(l) }
        if let l = line("ldl_cholesterol") { out.append(l) }
        else if let l = line("cholesterol_total") { out.append(l) }
        if let l = line("egfr") { out.append(l) }
        else if let l = line("creatinine") { out.append(l) }
        // Blood pressure — one combined line when both halves are held.
        let sys = numericRows("systolic_bp")
        let dia = numericRows("diastolic_bp")
        if let s = sys.first, let d = dia.first {
            let priorText: String? = {
                guard let ps = sys.dropFirst().first, let pd = dia.dropFirst().first else { return nil }
                return "previous \(HealthDisplay.number(ps.value))/\(HealthDisplay.number(pd.value)) mmHg — \(dateText(for: ps))"
            }()
            out.append(KeyValueLine(
                name: "Blood pressure",
                valueText: "\(HealthDisplay.number(s.value))/\(HealthDisplay.number(d.value)) mmHg",
                dateText: dateText(for: s),
                priorText: priorText
            ))
        }
        if let l = line("weight") { out.append(l) }
        return out
    }

    /// One header stamp per source present in the record, "as of" its newest
    /// import — the pull date belongs HERE, not on every row.
    private static func sourceStamps(history: [String: [HealthObservation]],
                                     conditions: [HealthCondition],
                                     medications: [HealthMedication]) -> [SourceStamp] {
        var newestImport: [String: Date] = [:]
        for rows in history.values {
            for o in rows { newestImport[o.source] = max(newestImport[o.source] ?? .distantPast, o.importedAt) }
        }
        for c in conditions { newestImport[c.source] = max(newestImport[c.source] ?? .distantPast, c.importedAt) }
        for m in medications { newestImport[m.source] = max(newestImport[m.source] ?? .distantPast, m.importedAt) }
        return newestImport
            .sorted { $0.key < $1.key }
            .map { source, date in
                switch HealthDataSource(rawValue: source) {
                case .sundhedLive: return SourceStamp(label: "Sundhed.dk record as of \(dateText(date))")
                case .sundhedPdf:  return SourceStamp(label: "Sundhed.dk file import as of \(dateText(date))")
                case .paperScan:   return SourceStamp(label: "Imported lab report, read \(dateText(date))")
                case .healthKit:   return SourceStamp(label: "Apple Health as of \(dateText(date))")
                case .manual:      return SourceStamp(label: "Entered by hand, last updated \(dateText(date))")
                default:           return SourceStamp(label: "Imported as of \(dateText(date))")
                }
            }
    }

    private static func sourceLabel(_ raw: String) -> String {
        HealthDataSource(rawValue: raw)?.displayLabel ?? raw
    }

    /// Medicine/analyte name cleanup: decode HTML entities (legacy stored rows
    /// may predate the parse-time fix), trim, collapse runs of whitespace.
    private static func cleanName(_ raw: String) -> String {
        var s = LabNomenclature.decodeHTMLEntities(raw)
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Fixed-format date ("12 Aug 2026"), POSIX locale — deterministic across
    /// devices and test runs; the document is EN copy throughout.
    static func dateText(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(identifier: "Europe/Copenhagen")
        df.dateFormat = "d MMM yyyy"
        return df.string(from: d)
    }

    // MARK: - Plain-text rendering (secondary/accessibility artifact)

    /// The text rendering — SAME content, SAME order as the PDF.
    func plainText() -> String {
        var lines: [String] = []
        lines.append("MAUDE \(Self.title.uppercased())")
        if let personName { lines.append(personName) }
        lines.append(generatedText)
        for s in sources { lines.append(s.label) }
        lines.append(includedText)
        lines.append("")

        if !majorDiagnoses.isEmpty {
            lines.append(Self.majorDiagnosesTitle.uppercased())
            for d in majorDiagnoses {
                let since = d.sinceText.map { " · \($0)" } ?? ""
                lines.append("  \(d.name) (\(d.code))\(since) · \(d.sourceLabel)")
            }
            lines.append("  Note: \(Self.diagnosesNote)")
            lines.append("")
        }

        if !medicines.isEmpty {
            lines.append(Self.medicinesTitle.uppercased())
            for m in medicines {
                var parts = [m.name]
                if let f = m.form, !f.isEmpty { parts.append(f) }
                if let atc = m.atc, !atc.isEmpty { parts.append("ATC \(atc)") }
                lines.append("  " + parts.joined(separator: " · ") + " · \(m.sourceLabel)")
            }
            lines.append("")
        }

        if !keyValues.isEmpty {
            lines.append(Self.keyValuesTitle.uppercased())
            for k in keyValues {
                var line = "  \(k.name): \(k.valueText) — \(k.dateText)"
                if let p = k.priorText { line += " · \(p)" }
                lines.append(line)
            }
            lines.append("")
        }

        if !panels.isEmpty {
            lines.append(Self.labsTitle.uppercased())
            for panel in panels {
                lines.append("  \(panel.title)")
                for lab in panel.lines {
                    let spec = lab.specimenLabel.map { " (\($0))" } ?? ""
                    lines.append("    \(lab.name)\(spec) · \(lab.sourceLabel)")
                    for (i, e) in lab.entries.enumerated() {
                        var line = i == 0
                            ? "      \(e.valueText) — \(e.dateText)"
                            : "      previous \(e.valueText) — \(e.dateText)"
                        if let ref = e.sourceReference, !ref.isEmpty {
                            line += " · \(Self.sourceReferencePrefix) \(ref)"
                        }
                        lines.append(line)
                    }
                }
            }
            lines.append("")
        }

        if !appendixDiagnoses.isEmpty || !excludedArtifactLines.isEmpty {
            lines.append(Self.appendixTitle.uppercased())
            for d in appendixDiagnoses {
                let since = d.sinceText.map { " · \($0)" } ?? ""
                lines.append("  \(d.name) (\(d.code))\(since) · \(d.sourceLabel)")
            }
            if !appendixDiagnoses.isEmpty {
                lines.append("  Note: \(Self.diagnosesNote)")
            }
            if !excludedArtifactLines.isEmpty {
                lines.append("  \(Self.artifactsTitle):")
                for a in excludedArtifactLines { lines.append("    \(a)") }
            }
            lines.append("")
        }

        lines.append(Self.footer)
        return lines.joined(separator: "\n")
    }
}
