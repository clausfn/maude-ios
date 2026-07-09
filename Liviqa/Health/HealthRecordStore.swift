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
    case paperScan          // future — paper print / OCR
    case healthKit          // future — Apple Health labs
    case manual             // entered by the citizen
    case other              // any future integration (name it via sourceDetail)

    /// Friendly chip/label copy (safe to render — this is NOT the hidden Provenance field).
    public var displayLabel: String {
        switch self {
        case .sundhedLive: return "Sundhed.dk"
        case .sundhedPdf:  return "Sundhed.dk file"
        case .paperScan:   return "Scanned"
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

    init(scopeKey: String, value: Double, unit: String, effectiveDate: Date,
         source: String, sourceDetail: String? = nil, importedAt: Date = Date(),
         mpcScaled: Int? = nil) {
        self.scopeKey = scopeKey; self.value = value; self.unit = unit
        self.effectiveDate = effectiveDate
        self.source = source; self.sourceDetail = sourceDetail
        self.importedAt = importedAt; self.mpcScaled = mpcScaled
    }
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
                source: HealthDataSource) {
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

        try? context.save()
    }

    // MARK: Read (for display — multi-source aware)

    /// Newest observation per scopeKey ACROSS sources (for a single-value display).
    /// Ties broken by importedAt. Sorted by display name.
    func latestObservations() -> [HealthObservation] {
        let all = (try? context.fetch(FetchDescriptor<HealthObservation>())) ?? []
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
    /// scopeKey = catalog var; value/unit from the LabRow; mpcScaled = round(value ×
    /// catalog scale_factor); conditions from the ICD-10 code (uppercased); meds from
    /// brand ?? substance + ATC. REUSES the existing crosswalk — no second standard.
    static func canonicalize(_ summary: SundhedDerivedSummary,
                             source: HealthDataSource,
                             at date: Date = Date())
        -> (obs: [HealthObservation], cond: [HealthCondition], med: [HealthMedication]) {
        let src = source.rawValue
        let obs: [HealthObservation] = summary.labs.map { row in
            let scale = SundhedParsers.scaleFactor(for: row.catalogVar)
            let scaled = (row.latest * scale).rounded()
            return HealthObservation(
                scopeKey: row.catalogVar,
                value: row.latest,
                unit: row.unit,
                effectiveDate: date,
                source: src,
                mpcScaled: Int(scaled)
            )
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
        let labs: [SundhedLabMeasurement] = latestObservations().map { o in
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

    // MARK: - Consumer (a): human-readable one-page summary (for the share sheet)

    /// A clean, dated, plain-text report of the whole record — Lab results / Diagnoses
    /// / Medicine — with a per-row source tag. Handed to the iOS share sheet by an
    /// explicit user action. No codes-as-jargon; readable by a citizen or clinician.
    func summaryReport(now: Date = Date()) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        var lines: [String] = []
        lines.append("Liviqa health summary")
        lines.append("Generated \(df.string(from: now))")
        lines.append("")

        let labs = latestObservations()
        lines.append("LAB RESULTS")
        if labs.isEmpty {
            lines.append("  (none imported yet)")
        } else {
            for o in labs {
                let name = HealthDisplay.labName(for: o.scopeKey)
                let val = HealthDisplay.number(o.value)
                let tag = HealthDataSource(rawValue: o.source)?.displayLabel ?? o.source
                lines.append("  \(name): \(val) \(o.unit)  ·  \(df.string(from: o.effectiveDate))  ·  \(tag)")
            }
        }
        lines.append("")

        let conds = conditions()
        lines.append("DIAGNOSES")
        if conds.isEmpty {
            lines.append("  (none imported yet)")
        } else {
            for c in conds {
                let tag = HealthDataSource(rawValue: c.source)?.displayLabel ?? c.source
                let label = c.label.map { " — \($0)" } ?? ""
                lines.append("  \(c.icd10)\(label)  ·  \(tag)")
            }
        }
        lines.append("")

        let meds = medications()
        lines.append("MEDICINE")
        if meds.isEmpty {
            lines.append("  (none imported yet)")
        } else {
            for m in meds {
                let atc = m.atc.map { " (\($0))" } ?? ""
                let tag = HealthDataSource(rawValue: m.source)?.displayLabel ?? m.source
                lines.append("  \(m.name)\(atc)  ·  \(tag)")
            }
        }
        lines.append("")
        lines.append("Exported from Liviqa · your data, shared by you")
        return lines.joined(separator: "\n")
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
    ]

    static func labName(for scopeKey: String) -> String {
        if let n = scopeKeyToName[scopeKey] { return n }
        // Prettify an unknown key: "some_key" → "Some key".
        let spaced = scopeKey.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    static func number(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
