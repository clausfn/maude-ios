// HealthRecordStore.swift — the citizen's canonical, on-device health record.
//
// GOAL: a GENERAL, source-agnostic, STANDARDS-BASED store. Many sources
// (Sundhed.dk live extraction, Sundhed PDF, paper OCR later, HealthKit, manual…)
// all land the SAME way — one `ingest()` API — and every row carries PROVENANCE
// (which source + optional integration name). The store is on-device only
// (registered in the same LiviqaStore ModelContainer as the sample entities); it
// NEVER auto-uploads. Data leaves only by an explicit, consented user action
// (Task 4: share summary / contribute to research).
//
// STANDARDS BACKBONE (rule: no second standard): scopeKey = catalog var
// (hba1c, ldl_cholesterol…), LOINC-mapped labs / ATC meds / ICD-10 conditions,
// canonical units, and MPC scale_factors — all sourced from the EXISTING
// SundhedParsers crosswalk (scaleFactor(for:)) and the derived SundhedDerivedSummary
// shape. A new source needs only a mapper into SundhedDerivedSummary (or directly
// into these row types) + one `ingest()` call.
//
// NOTE: `source`/`sourceDetail` here are the record's PROVENANCE in the plain
// English sense (which app/integration filed it). They are deliberately NOT the
// DataModel `Provenance{REAL,SIMULATED,EXTERNAL}` enum (that stays a hidden
// arbitration field, T-PROV-01) — these are user-facing source labels a citizen
// SHOULD see ("came from Sundhed.dk").
import Foundation
import SwiftData

// MARK: - Source provenance (user-facing, source-agnostic)

/// Where a canonical health record came from. Extend by adding a case — the store,
/// mappers, display and export are all keyed off this uniformly.
public enum HealthDataSource: String, Codable, CaseIterable, Sendable {
    case sundhedLive        // Path A — in-app MitID extraction
    case sundhedPdf         // Path B — Sundhed.dk PDF / text import
    case paperScan          // any-lab PDF/photo import (FR-REC-03, on-device Vision OCR)
    case healthKit          // future — Apple Health labs
    case manual             // entered by the citizen
    case other              // any future integration (name it via sourceDetail)

    /// Friendly chip/label copy (safe to render — this is NOT the hidden Provenance field).
    public var displayLabel: String {
        switch self {
        case .sundhedLive: return "Sundhed.dk"
        case .sundhedPdf:  return "Sundhed.dk file"
        case .paperScan:   return "Lab report you imported"
        case .healthKit:   return "Apple Health"
        case .manual:      return "Entered by you"
        case .other:       return "Imported"
        }
    }
}

// MARK: - Canonical @Model rows (registered in LiviqaStore)

/// One lab / vital observation in canonical units, keyed on the catalog scopeKey.
/// `mpcScaled` = round(value × catalog scale_factor) — the MPC-ready integer for
/// research; nil when no scaling applies.
@Model
final class HealthObservation {
    var scopeKey: String        // catalog var, e.g. "hba1c", "ldl_cholesterol"
    var value: Double           // canonical unit
    var unit: String
    var effectiveDate: Date
    var source: String          // HealthDataSource.rawValue (provenance)
    var sourceDetail: String?   // specific integration name, when relevant
    var importedAt: Date
    var mpcScaled: Int?         // round(value × scale_factor), MPC-ready

    // Record-quality fields (PR "electric-ink" export fixes; all optional so the
    // SwiftData store migrates lightweight and legacy rows stay valid):
    /// The REAL specimen/result date the source carried. nil = the source
    /// genuinely didn't record one — display says "date not recorded", NEVER the
    /// import date dressed up as a result date (defect A; day-axis integrity).
    var specimenDate: Date?
    /// SundhedResultKind.rawValue — "quantitative" | "qualitative" | "artifact".
    /// nil = legacy row, treated as quantitative.
    var resultKind: String?
    /// The source's own wording for a qualitative result ("Negativ",
    /// "Ikke påvist"). Rendered as words — never as 0 + unit (defect B).
    var resultText: String?
    /// Full NPU system token ("P", "B", "U", "Pt(U)") — structured specimen,
    /// shown as a small label at display, never appended to the name (defect C).
    var specimen: String?
    /// The SOURCE's own reference interval, when it supplied one and we captured
    /// it. Shown labelled as the source's — never invented, never a judgement.
    var sourceRefInterval: String?

    init(scopeKey: String, value: Double, unit: String, effectiveDate: Date,
         source: String, sourceDetail: String? = nil, importedAt: Date = Date(),
         mpcScaled: Int? = nil, specimenDate: Date? = nil, resultKind: String? = nil,
         resultText: String? = nil, specimen: String? = nil, sourceRefInterval: String? = nil) {
        self.scopeKey = scopeKey; self.value = value; self.unit = unit
        self.effectiveDate = effectiveDate
        self.source = source; self.sourceDetail = sourceDetail
        self.importedAt = importedAt; self.mpcScaled = mpcScaled
        self.specimenDate = specimenDate; self.resultKind = resultKind
        self.resultText = resultText; self.specimen = specimen
        self.sourceRefInterval = sourceRefInterval
    }

    /// Typed view over `resultKind` (legacy nil ⇒ quantitative).
    var kind: SundhedResultKind { resultKind.flatMap(SundhedResultKind.init(rawValue:)) ?? .quantitative }
}

/// One coded diagnosis (ICD-10 / SKS). `label` optional — codes are the standard.
@Model
final class HealthCondition {
    var icd10: String
    var label: String?
    var onsetDate: Date?
    var source: String
    var sourceDetail: String?
    var importedAt: Date

    init(icd10: String, label: String? = nil, onsetDate: Date? = nil,
         source: String, sourceDetail: String? = nil, importedAt: Date = Date()) {
        self.icd10 = icd10; self.label = label; self.onsetDate = onsetDate
        self.source = source; self.sourceDetail = sourceDetail; self.importedAt = importedAt
    }
}

/// One medication (ATC-coded when known).
@Model
final class HealthMedication {
    var atc: String?
    var name: String
    var form: String?
    var source: String
    var sourceDetail: String?
    var importedAt: Date

    init(atc: String? = nil, name: String, form: String? = nil,
         source: String, sourceDetail: String? = nil, importedAt: Date = Date()) {
        self.atc = atc; self.name = name; self.form = form
        self.source = source; self.sourceDetail = sourceDetail; self.importedAt = importedAt
    }
}

// (A HealthProcedure etc. would follow the same pattern: a @Model row + a dedup
//  key in ingest() + a mapper — nothing else in the pipeline changes.)

// MARK: - The repository

/// Repository over the on-device ModelContext. Source-agnostic: every source funnels
/// through the single `ingest(...)`. Dedup keeps ONE row per logical reading per
/// source, but keeps multi-source rows side by side (each tagged) so provenance is
/// never lost. Lightweight struct wrapping the (reference-type) context.
struct HealthStore {
    let context: ModelContext

    init(context: ModelContext) { self.context = context }

    // MARK: Ingest (the one API all sources share)

    /// UPSERT with dedup. `source` is authoritative — every incoming row is stamped
    /// with it (and a fresh importedAt), so a mapper needn't set it.
    ///   • observations dedup by (scopeKey + same-day effectiveDate + source)
    ///   • conditions   dedup by (icd10 + source)
    ///   • medications  dedup by (atc ?? name + source)
    /// Existing same-key rows are updated in place; new ones inserted. Persisted.
    func ingest(observations: [HealthObservation],
                conditions: [HealthCondition],
                medications: [HealthMedication],
                source: HealthDataSource) throws {
        let src = source.rawValue
        let now = Date()
        let cal = Calendar.current

        // --- Observations -----------------------------------------------------
        var existingObs = (try? context.fetch(FetchDescriptor<HealthObservation>())) ?? []
        for incoming in observations {
            incoming.source = src
            incoming.importedAt = now
            if let match = existingObs.first(where: {
                $0.source == src && $0.scopeKey == incoming.scopeKey &&
                cal.isDate($0.effectiveDate, inSameDayAs: incoming.effectiveDate)
            }) {
                match.value = incoming.value
                match.unit = incoming.unit
                match.mpcScaled = incoming.mpcScaled
                match.sourceDetail = incoming.sourceDetail
                match.importedAt = now
                match.specimenDate = incoming.specimenDate
                match.resultKind = incoming.resultKind
                match.resultText = incoming.resultText
                match.specimen = incoming.specimen
                match.sourceRefInterval = incoming.sourceRefInterval
            } else {
                context.insert(incoming)
                existingObs.append(incoming)
            }
        }

        // --- Conditions -------------------------------------------------------
        var existingCond = (try? context.fetch(FetchDescriptor<HealthCondition>())) ?? []
        for incoming in conditions {
            incoming.source = src
            incoming.importedAt = now
            if let match = existingCond.first(where: {
                $0.source == src && $0.icd10 == incoming.icd10
            }) {
                if let l = incoming.label { match.label = l }
                if let d = incoming.onsetDate { match.onsetDate = d }   // a later pull may add the year
                match.sourceDetail = incoming.sourceDetail
                match.importedAt = now
            } else {
                context.insert(incoming)
                existingCond.append(incoming)
            }
        }

        // --- Medications ------------------------------------------------------
        var existingMed = (try? context.fetch(FetchDescriptor<HealthMedication>())) ?? []
        func medKey(_ m: HealthMedication) -> String { (m.atc ?? m.name).lowercased() }
        for incoming in medications {
            incoming.source = src
            incoming.importedAt = now
            let key = medKey(incoming)
            if let match = existingMed.first(where: { $0.source == src && medKey($0) == key }) {
                match.name = incoming.name
                match.form = incoming.form
                match.sourceDetail = incoming.sourceDetail
                match.importedAt = now
            } else {
                context.insert(incoming)
                existingMed.append(incoming)
            }
        }

        // NEVER `try?` here: a swallowed save is silent data loss — the imported
        // record renders this session (in-context objects) and vanishes on relaunch,
        // the exact failure mode the d9f4df6 store fix condemned. Propagate so the
        // caller can tell the user their import did NOT stick.
        do {
            try context.save()
        } catch {
            print("‼️ HealthStore.ingest: context.save() FAILED — imported record will not survive relaunch: \(error)")
            throw error
        }
    }

    // MARK: Read (for display — multi-source aware)

    /// Newest QUANTITATIVE observation per scopeKey ACROSS sources (for a
    /// single-value display). Ties broken by importedAt. Sorted by display name.
    /// Qualitative rows and collection artifacts are excluded here — a numeric
    /// surface would render their pinned 0 as "0 mmol/L" (defect B); they are
    /// read via `observationHistory()` which carries their words instead.
    func latestObservations() -> [HealthObservation] {
        let all = ((try? context.fetch(FetchDescriptor<HealthObservation>())) ?? [])
            .filter { $0.kind == .quantitative }
        var best: [String: HealthObservation] = [:]
        for o in all {
            if let cur = best[o.scopeKey] {
                if o.effectiveDate > cur.effectiveDate ||
                   (o.effectiveDate == cur.effectiveDate && o.importedAt > cur.importedAt) {
                    best[o.scopeKey] = o
                }
            } else {
                best[o.scopeKey] = o
            }
        }
        return best.values.sorted {
            HealthDisplay.labName(for: $0.scopeKey) < HealthDisplay.labName(for: $1.scopeKey)
        }
    }

    /// The full per-analyte history for the exported summary: every stored
    /// observation grouped by scopeKey, NEWEST FIRST within each group,
    /// qualitative rows included (their result is their WORDS), collection
    /// artifacts excluded by default (flagged rows, not results). Cross-source.
    func observationHistory(includeArtifacts: Bool = false) -> [String: [HealthObservation]] {
        let all = (try? context.fetch(FetchDescriptor<HealthObservation>())) ?? []
        let kept = includeArtifacts ? all : all.filter { $0.kind != .artifact }
        var grouped = Dictionary(grouping: kept, by: \.scopeKey)
        for (key, rows) in grouped {
            grouped[key] = rows.sorted { a, b in
                a.effectiveDate == b.effectiveDate
                    ? a.importedAt > b.importedAt
                    : a.effectiveDate > b.effectiveDate
            }
        }
        return grouped
    }

    /// Rows flagged as collection artifacts (e.g. a 0-min urine collection) —
    /// excluded from the summary by default, listed honestly in its appendix.
    func artifactObservations() -> [HealthObservation] {
        ((try? context.fetch(FetchDescriptor<HealthObservation>())) ?? [])
            .filter { $0.kind == .artifact }
            .sorted { $0.effectiveDate > $1.effectiveDate }
    }

    /// The newest stored reading for one scopeKey STRICTLY BEFORE `date`, across
    /// sources. Used by the any-lab import (FR-REC-03) to frame a freshly read
    /// result against the citizen's OWN previous value — never a population band.
    /// Returns nil when there is no earlier reading, and the caller says so
    /// plainly rather than inventing a comparison.
    func priorObservation(scopeKey: String, before date: Date) -> HealthObservation? {
        let all = (try? context.fetch(FetchDescriptor<HealthObservation>())) ?? []
        return all
            .filter { $0.scopeKey == scopeKey && $0.effectiveDate < date }
            .max { a, b in
                a.effectiveDate == b.effectiveDate
                    ? a.importedAt < b.importedAt
                    : a.effectiveDate < b.effectiveDate
            }
    }

    /// All conditions (multi-source rows coexist), sorted by code then source.
    func conditions() -> [HealthCondition] {
        let all = (try? context.fetch(FetchDescriptor<HealthCondition>())) ?? []
        return all.sorted { $0.icd10 == $1.icd10 ? $0.source < $1.source : $0.icd10 < $1.icd10 }
    }

    /// All medications, sorted by name then source.
    func medications() -> [HealthMedication] {
        let all = (try? context.fetch(FetchDescriptor<HealthMedication>())) ?? []
        return all.sorted { $0.name.lowercased() == $1.name.lowercased()
            ? $0.source < $1.source
            : $0.name.lowercased() < $1.name.lowercased() }
    }

    var isEmpty: Bool {
        (try? context.fetchCount(FetchDescriptor<HealthObservation>())) ?? 0 == 0 &&
        (try? context.fetchCount(FetchDescriptor<HealthCondition>())) ?? 0 == 0 &&
        (try? context.fetchCount(FetchDescriptor<HealthMedication>())) ?? 0 == 0
    }

    // MARK: - Mapper (Sundhed derived summary → canonical rows). Pure.

    /// Turn a derived summary (Path A/B produce this today) into canonical rows.
    /// scopeKey = catalog var; value/unit per READING; mpcScaled = round(value ×
    /// catalog scale_factor); conditions from the ICD-10 code (uppercased); meds from
    /// brand ?? substance + ATC. REUSES the existing crosswalk — no second standard.
    ///
    /// DATES (defect A): each reading lands with its REAL specimen date —
    /// `specimenDate` = the source's date, `effectiveDate` = that same date (so
    /// dedup/ordering follow the truth). Only when the source genuinely recorded
    /// no date does `effectiveDate` fall back to the import date for ordering,
    /// with `specimenDate` staying nil so display says "date not recorded" —
    /// the import date is never presented as a result date.
    static func canonicalize(_ summary: SundhedDerivedSummary,
                             source: HealthDataSource,
                             at date: Date = Date())
        -> (obs: [HealthObservation], cond: [HealthCondition], med: [HealthMedication]) {
        let src = source.rawValue
        var obs: [HealthObservation] = []
        for row in summary.labs {
            let scale = SundhedParsers.scaleFactor(for: row.catalogVar)
            // Legacy summaries (no readings) keep the old one-row-per-analyte shape.
            let readings = row.readings.isEmpty
                ? [SundhedDerivedSummary.Reading(value: row.latest, unit: row.unit, date: nil)]
                : row.readings
            for r in readings {
                let quantitative = r.kind == .quantitative
                obs.append(HealthObservation(
                    scopeKey: row.catalogVar,
                    value: quantitative ? r.value : 0,
                    unit: r.unit,
                    effectiveDate: r.date ?? date,
                    source: src,
                    mpcScaled: quantitative ? Int((r.value * scale).rounded()) : nil,
                    specimenDate: r.date,
                    resultKind: r.kind.rawValue,
                    resultText: r.text,
                    specimen: row.specimen,
                    sourceRefInterval: r.referenceInterval
                ))
            }
        }
        let cond: [HealthCondition] = summary.conditions.map { row in
            HealthCondition(icd10: row.code.uppercased(), source: src)
        }
        let med: [HealthMedication] = summary.meds.map { row in
            let name = row.brand.isEmpty ? row.substance : row.brand
            return HealthMedication(atc: row.atc.isEmpty ? nil : row.atc, name: name, source: src)
        }
        return (obs, cond, med)
    }

    // MARK: - Consumer (b): research payload (explicit, consented — never auto-sent)

    /// Build the EXISTING coded research body from the canonical store, honouring the
    /// standard: catalog scopeKeys, ATC / ICD-10 codes, and MPC scale_factors. Reuses
    /// `SundhedPayloadBuilder` (the one canonical builder) — no MPC crypto here, and
    /// nothing is sent. The caller (an explicit "contribute to research" action) hands
    /// this to the existing `SundhedIngesting` client. The backend re-checks k_floor /
    /// covering-grant guardrails on receipt.
    func researchPayload(citizenId: String, asOf: Date = Date()) -> SundhedIngestBody {
        // Only CODED observations (real catalog vars) go to research/MPC — display-only
        // passthrough rows (analytes kept under their readable name, no catalog code)
        // are shown to the citizen but never leave the device as research data.
        let labs: [SundhedLabMeasurement] = latestObservations()
            .filter { SundhedParsers.knownCatalogVars.contains($0.scopeKey) }
            .map { o in
            let scale = SundhedParsers.scaleFactor(for: o.scopeKey)
            return SundhedLabMeasurement(
                catalogVar: o.scopeKey,
                component: HealthDisplay.labName(for: o.scopeKey),
                specimen: nil,
                unit: o.unit,
                value: o.value,
                scaleFactor: scale,
                scaledValue: o.value * scale,
                date: o.effectiveDate
            )
        }
        let meds: [SundhedMedItem] = medications().map { m in
            SundhedMedItem(brand: m.name, activeSubstance: m.name, atc: m.atc,
                           form: m.form, dosage: nil, reason: nil)
        }
        // Dedup diagnoses across sources (presence semantics).
        var seen = Set<String>()
        let diagnoses: [String] = conditions().compactMap { c in
            let code = c.icd10.uppercased()
            guard !seen.contains(code) else { return nil }
            seen.insert(code); return code
        }
        return SundhedPayloadBuilder.build(
            citizenID: citizenId, labs: labs, meds: meds, diagnoses: diagnoses, asOf: asOf)
    }

    // MARK: - Consumer (a): the shareable health summary (for the share sheet)

    /// The plain-text rendering of the citizen's health summary — the SAME
    /// document, in the same order, as the primary PDF artifact
    /// (`HealthSummaryPDF`); kept as the accessibility/secondary format. Handed
    /// to the iOS share sheet by an explicit user action. `personName` is the
    /// citizen's DECLARED name (never an email) — nil renders no name line.
    func summaryReport(personName: String? = nil, now: Date = Date()) -> String {
        HealthSummaryDocument.build(store: self, personName: personName, now: now).plainText()
    }
}

// MARK: - Display crosswalk (scopeKey → readable name)

/// Readable labels for catalog scopeKeys, and small formatting helpers. Kept next to
/// the store (Foundation-only) so both the report and the SwiftUI display agree.
enum HealthDisplay {
    static let scopeKeyToName: [String: String] = [
        "hemoglobin":        "Hemoglobin",
        "leukocytes":        "Leukocytes",
        "thrombocytes":      "Thrombocytes",
        "hba1c":             "HbA1c",
        "glucose":           "Glucose",
        "creatinine":        "Creatinine",
        "egfr":              "eGFR",
        "alat":              "ALAT",
        "ldl_cholesterol":   "LDL cholesterol",
        "hdl_cholesterol":   "HDL cholesterol",
        "cholesterol_total": "Total cholesterol",
        "potassium":         "Potassium",
        "sodium":            "Sodium",
        "crp":               "CRP",
        "tsh":               "TSH",
        // Any-lab import keys (FR-REC-03) with no catalog var yet — shown to the
        // citizen, excluded from the coded research payload by knownCatalogVars.
        "triglycerides":     "Triglycerides",
        "ferritin":          "Ferritin",
        "vitamin_d":         "Vitamin D",
        "vitamin_b12":       "Vitamin B12",
        // Manual-entry keys (Data sources → "Type readings in yourself").
        "weight":            "Weight",
        "systolic_bp":       "Blood pressure (systolic)",
        "diastolic_bp":      "Blood pressure (diastolic)",
        "sleep_hours":       "Sleep",
    ]

    static func labName(for scopeKey: String) -> String {
        if let n = scopeKeyToName[scopeKey] { return n }
        // Passthrough keys carry the raw source analyte ("Glukose;P") — map via
        // the nomenclature layer: entities decoded, the NPU system suffix moved
        // to the structured specimen label (defect C), Danish → English name.
        if scopeKey.contains(";") || scopeKey.contains("[") || scopeKey.contains("&") {
            return LabNomenclature.displayName(forRawAnalyte: scopeKey)
        }
        if !scopeKey.contains("_"), scopeKey.rangeOfCharacter(from: .uppercaseLetters) != nil {
            return LabNomenclature.displayName(forRawAnalyte: scopeKey)
        }
        // Prettify an unknown catalog-style key: "some_key" → "Some key".
        let spaced = scopeKey.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    /// Small specimen label for an observation ("plasma", "blood", "urine
    /// collection") — from the structured specimen token when stored, else from
    /// a passthrough scopeKey's suffix. nil when the source named none.
    static func specimenLabel(for o: HealthObservation) -> String? {
        if let token = o.specimen, !token.isEmpty {
            return LabNomenclature.specimenLabel(forSystemToken: token)
        }
        let (_, system) = LabNomenclature.splitSystemSuffix(o.scopeKey)
        return LabNomenclature.specimenLabel(forSystemToken: system)
    }

    static func number(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        // One decimal when it is faithful; two when rounding to one would
        // erase the value (a 0.02 basophil count must not print as "0.0").
        let one = (v * 10).rounded() / 10
        return one == v ? String(format: "%.1f", v) : String(format: "%.2f", v)
    }

    // MARK: Condition names (ICD-10 → plain language, on-device)

    /// Citizen-friendly names for ICD-10 codes. A static classification lookup —
    /// bundled on device, no journal text involved, so codes-only discipline holds.
    /// Danish records use SKS codes (WHO ICD-10 prefixed with `D`, e.g. DE104 =
    /// E10.4); the lookup normalises that away. Longest-prefix match (4 chars, then
    /// 3) so subdivisions inherit their category name; anything unknown falls back
    /// to a readable chapter description — a code NEVER renders bare.
    private static let icd10Names: [String: String] = [
        // Endocrine / metabolic (E) — everyday name first, clinical in parentheses.
        "E10": "Type 1 diabetes",
        "E102": "Type 1 diabetes with kidney complications",
        "E103": "Type 1 diabetes with eye complications",
        "E104": "Type 1 diabetes with nerve complications",
        "E105": "Type 1 diabetes with circulation complications",
        "E107": "Type 1 diabetes with several complications",
        "E108": "Type 1 diabetes with other complications",
        "E109": "Type 1 diabetes without complications",
        "E11": "Type 2 diabetes",
        "E114": "Type 2 diabetes with nerve complications",
        "E119": "Type 2 diabetes without complications",
        "E03": "Low metabolism (underactive thyroid)",
        "E05": "High metabolism (overactive thyroid)",
        "E66": "Overweight (obesity)",
        "E78": "High cholesterol",
        // Blood (D5x–D8x, WHO)
        "D50": "Low iron (iron-deficiency anaemia)",
        "D51": "Vitamin B12 deficiency",
        // Cancer / tumours (C)
        "C18": "Bowel cancer",
        "C34": "Lung cancer",
        "C43": "Melanoma (skin cancer)",
        "C44": "Skin cancer (non-melanoma)",
        "C50": "Breast cancer",
        "C61": "Prostate cancer",
        "C759": "Tumour of a hormone gland (unspecified)",
        "C75": "Tumour of a hormone gland",
        // Mental health (F)
        "F17": "Smoking dependence",
        "F32": "Depression",
        "F41": "Anxiety",
        // Nervous system (G)
        "G40": "Epilepsy",
        "G43": "Migraine",
        "G45": "Mini-stroke (TIA)",
        "G47": "Sleep disorder",
        "G62": "Nerve damage in arms/legs (polyneuropathy)",
        "G632": "Diabetic nerve damage (polyneuropathy)",
        "G63": "Nerve damage in arms/legs (polyneuropathy)",
        // Eye / ear (H)
        "H25": "Cataract (clouded lens)",
        "H26": "Cataract (clouded lens)",
        "H360": "Diabetic eye damage (retinopathy)",
        "H36": "Retinal damage (eye complication)",
        "H90": "Hearing loss",
        "H91": "Hearing loss",
        // Heart / circulation (I)
        "I10": "High blood pressure",
        "I20": "Chest pain from the heart (angina)",
        "I21": "Heart attack",
        "I25": "Narrowed coronary arteries (chronic heart disease)",
        "I48": "Irregular heartbeat (atrial fibrillation)",
        "I489": "Irregular heartbeat (atrial fibrillation)",
        "I50": "Heart failure",
        "I63": "Stroke",
        "I83": "Varicose veins",
        // Lungs (J)
        "J18": "Pneumonia",
        "J30": "Hay fever (allergic rhinitis)",
        "J44": "COPD (smoker's lungs)",
        "J45": "Asthma",
        // Digestion (K)
        "K21": "Heartburn / acid reflux",
        "K25": "Stomach ulcer",
        "K29": "Inflamed stomach lining (gastritis)",
        "K42": "Hernia at the navel (umbilical hernia)",
        "K429": "Hernia at the navel (umbilical hernia)",
        "K57": "Pouches in the bowel wall (diverticular disease)",
        "K58": "Irritable bowel (IBS)",
        "K64": "Haemorrhoids",
        "K80": "Gallstones",
        // Muscles / bones / joints (M)
        "M06": "Rheumatoid arthritis",
        "M10": "Gout",
        "M16": "Worn hip joint (osteoarthritis)",
        "M17": "Worn knee joint (osteoarthritis)",
        "M42": "Scheuermann's / spinal wear (osteochondrosis)",
        "M420": "Scheuermann's disease (curved upper back)",
        "M54": "Back pain",
        "M79": "Muscle and soft-tissue pain",
        "M81": "Brittle bones (osteoporosis)",
        // Kidney / urinary (N)
        "N18": "Chronic kidney disease",
        "N20": "Kidney stones",
        "N390": "Urinary tract infection",
        "N39": "Bladder / urinary condition",
        // Skin (L)
        "L20": "Eczema (atopic)",
        "L40": "Psoriasis",
    ]

    /// Readable chapter fallback (first letter of the WHO code) so unknown codes
    /// still say SOMETHING a citizen understands.
    private static let icd10Chapters: [Character: String] = [
        "A": "Infectious disease", "B": "Infectious disease",
        "C": "Tumour / cancer-related condition",
        "D": "Blood or immune condition",
        "E": "Hormonal or metabolic condition",
        "F": "Mental-health condition",
        "G": "Nervous-system condition",
        "H": "Eye or ear condition",
        "I": "Heart or circulatory condition",
        "J": "Respiratory condition",
        "K": "Digestive condition",
        "L": "Skin condition",
        "M": "Muscle, bone or joint condition",
        "N": "Kidney or urinary condition",
        "O": "Pregnancy-related condition",
        "P": "Newborn-period condition",
        "Q": "Congenital condition",
        "R": "Symptom or clinical finding",
        "S": "Injury", "T": "Injury or external cause",
        "Z": "Contact / administrative code",
    ]

    /// "since Apr 2019" when the onset carries month detail, "since 2019" for a
    /// year-only onset (parsed as 1 Jan — treated as year precision).
    static func sinceText(_ d: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: d)
        if cal.component(.month, from: d) == 1 && cal.component(.day, from: d) == 1 {
            return "since \(String(y))"
        }
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return "since \(df.string(from: d))"
    }

    // MARK: Condition tiers (major vs past/minor vs administrative)

    /// Display tier for a diagnosis code. Drives the passport grouping: ongoing /
    /// major conditions lead; injuries, one-off infections, symptom codes and
    /// administrative contact codes live in a collapsed secondary group so they
    /// don't crowd (or alarm) the main record.
    enum ConditionTier { case major, pastMinor, admin }

    static func conditionTier(for icd10: String) -> ConditionTier {
        let code = normalizedWHO(icd10)
        guard let first = code.first else { return .pastMinor }
        switch first {
        case "Z", "U":            return .admin      // contact / administrative
        case "S", "T":            return .pastMinor  // injuries, external causes
        case "R":                 return .pastMinor  // symptoms & findings, not diseases
        case "A", "B":            return .pastMinor  // acute infections
        default: break
        }
        // Acute respiratory infections (common cold → acute bronchitis) are episodic.
        if code.hasPrefix("J"), let n = Int(code.dropFirst().prefix(2)), n <= 22 { return .pastMinor }
        if code.hasPrefix("N39") { return .pastMinor }   // UTI / bladder episodes
        if code.hasPrefix("H6")  { return .pastMinor }   // ear infections
        if code.hasPrefix("K52") { return .pastMinor }   // gastroenteritis
        return .major
    }

    /// A short, calming context line for entries that can make a citizen wonder.
    /// Specific notes for known codes; otherwise a tier-generic explanation for the
    /// secondary group. Major, self-explanatory conditions return nil.
    static func conditionContext(for icd10: String) -> String? {
        let code = normalizedWHO(icd10)
        if code.count >= 4, let n = conditionNotes[String(code.prefix(4))] { return n }
        if code.count >= 3, let n = conditionNotes[String(code.prefix(3))] { return n }
        switch conditionTier(for: icd10) {
        case .admin:
            return "An administrative or contact code from the journal — not an illness."
        case .pastMinor:
            return "A record of a past, usually short-lived issue. Not necessarily active today."
        case .major:
            return nil
        }
    }

    /// Specific notes for codes that commonly cause "wait, what is this?" moments.
    private static let conditionNotes: [String: String] = [
        "M420": "A growth-related curvature of the upper back that typically starts in the teenage years — usually an old finding.",
        "M42":  "A wear-related spinal finding — often historical.",
        "C759": "A coded tumour record where the detail lives in the journal — often historical work-up. Ask your doctor what it refers to.",
        "K429": "A hernia at the navel — often repaired or harmless.",
        "K42":  "A hernia at the navel — often repaired or harmless.",
        "I489": "A heart-rhythm record — can reflect a single documented episode.",
        "E102": "A coded complication entry linked to your diabetes care.",
        "E103": "A coded complication entry linked to your diabetes care.",
        "E104": "A coded complication entry linked to your diabetes care.",
        "E105": "A coded complication entry linked to your diabetes care.",
        "E107": "A coded complication entry linked to your diabetes care.",
        "E108": "A coded complication entry linked to your diabetes care.",
        "G632": "A coded complication entry linked to your diabetes care.",
        "H360": "A coded complication entry linked to your diabetes care.",
    ]

    /// The one explainer every diagnoses list should carry — these are journal
    /// codes, not a statement of what's active today.
    static let diagnosesExplainer =
        "These entries are coded records from your hospital and GP journal, including past and closed episodes — a diagnosis listed here is not necessarily active today. The full story behind each entry is in your journal on sundhed.dk. Ask your doctor if something looks unfamiliar."

    /// Normalise to the WHO-style code: uppercase, dots stripped, SKS `D` prefix
    /// removed (DE104 → E104) while preserving WHO's own D-chapter codes.
    private static func normalizedWHO(_ icd10: String) -> String {
        var code = icd10.uppercased().replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespaces)
        if code.count >= 3, code.first == "D",
           let second = code.dropFirst().first, second.isLetter {
            code = String(code.dropFirst())
        }
        return code
    }

    /// Plain-language name for an ICD-10 (or Danish SKS) code.
    static func conditionName(for icd10: String) -> String {
        let code = normalizedWHO(icd10)
        // Longest-prefix match: 4 chars, then 3.
        if code.count >= 4, let n = icd10Names[String(code.prefix(4))] { return n }
        if code.count >= 3, let n = icd10Names[String(code.prefix(3))] { return n }
        if let first = code.first, let chapter = icd10Chapters[first] { return chapter }
        return "Diagnosis"
    }
}
