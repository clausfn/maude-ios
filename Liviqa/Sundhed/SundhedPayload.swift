// SundhedPayload.swift — Builds the POST /ingest/sundhed request body from the
// on-device parse results. CODES AND DERIVED NUMBERS ONLY.
//
// CARDINAL (rule 3): this body carries catalog var keys, ATC codes, ICD-10/SKS
// codes and aggregate numbers — never raw document text or free-text narrative.
// It mirrors the existing DerivedShareBuilder discipline (transform locally,
// send only the derived, scoped package).
//
// Contract (POST /ingest/sundhed): the DerivedShare lands only under a covering
// active consent grant whose scope expands to the ingested vars; `conditions`
// additionally needs a grant scoped to include "conditions".
//
// Pure Foundation + Encodable → unit-testable. No network here (see
// SundhedImport.swift for the client).
import Foundation

// MARK: - Wire body (matches POST /ingest/sundhed exactly; snake_case)

public struct SundhedIngestBody: Encodable, Equatable, Sendable {
    public let citizenID: String
    public let provenance: String        // always "EXTERNAL"
    public let source: String            // always "sundhed_fhir"
    public let catalogVersion: String    // "0.4.0"
    public let asOf: String              // ISO-8601
    public let metrics: Metrics
    public let counts: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case citizenID = "citizen_id"
        case provenance
        case source
        case catalogVersion = "catalog_version"
        case asOf = "as_of"
        case metrics
        case counts
    }

    public struct Metrics: Encodable, Equatable, Sendable {
        public var labs: LabsBlock?
        public var meds: MedsBlock?
        public var conditions: ConditionsBlock?
    }

    // MARK: Labs

    public struct LabsBlock: Encodable, Equatable, Sendable {
        public let provenance: String    // "EXTERNAL"
        public let source: String        // "sundhed_fhir"
        public let summary: LabsSummary
    }

    public struct LabsSummary: Encodable, Equatable, Sendable {
        public let mean: Double?
        public let latest: Double?
        public let unit: String?
        public let n: Int?
        public let representative: String?          // the representative catalog var
        public let byVariable: [String: LabVar]

        enum CodingKeys: String, CodingKey {
            case mean, latest, unit, n, representative
            case byVariable = "by_variable"
        }
    }

    public struct LabVar: Encodable, Equatable, Sendable {
        public let latest: Double
        public let mean: Double
        public let n: Int
        public let unit: String
        public let scaleFactor: Double
        public let scaledLatest: Double
        public let scaledMean: Double

        enum CodingKeys: String, CodingKey {
            case latest, mean, n, unit
            case scaleFactor = "scale_factor"
            case scaledLatest = "scaled_latest"
            case scaledMean = "scaled_mean"
        }
    }

    // MARK: Meds

    public struct MedsBlock: Encodable, Equatable, Sendable {
        public let provenance: String
        public let source: String
        public let summary: MedsSummary
    }

    public struct MedsSummary: Encodable, Equatable, Sendable {
        public let count: Int
        public let codedDist: [String: Int]        // ATC code → count

        enum CodingKeys: String, CodingKey {
            case count
            case codedDist = "coded_dist"
        }
    }

    // MARK: Conditions

    public struct ConditionsBlock: Encodable, Equatable, Sendable {
        public let provenance: String
        public let source: String
        public let summary: ConditionsSummary
    }

    public struct ConditionsSummary: Encodable, Equatable, Sendable {
        public let count: Int
        public let codedDist: [String: Int]        // ICD-10/SKS code → presence(1)
        public let bySource: BySource?

        enum CodingKeys: String, CodingKey {
            case count
            case codedDist = "coded_dist"
            case bySource = "by_source"
        }
    }

    /// Structured vs. NLP-derived split. `structured` is the deterministic parse;
    /// `nlpDerived` stays empty until the DEFERRED journal-NLP path ships.
    public struct BySource: Encodable, Equatable, Sendable {
        public let structured: [String: Int]
        public let nlpDerived: [String: Int]

        enum CodingKeys: String, CodingKey {
            case structured
            case nlpDerived = "nlp_derived"
        }
    }
}

// MARK: - Human-review model (codes only; drives the Approve & save sheet)

/// What the review sheet shows the citizen before upload. Deliberately holds only
/// derived facts (catalog vars, ATC, ICD-10) — never the source text — so the
/// on-screen preview can't leak narrative either.
public struct SundhedDerivedSummary: Equatable {
    public struct LabRow: Equatable, Identifiable {
        public var id: String { catalogVar }
        public let catalogVar: String
        public let component: String
        public let latest: Double
        public let mean: Double
        public let unit: String
        public let n: Int
    }
    public struct MedRow: Equatable, Identifiable {
        public var id: String { atc + brand }
        public let atc: String
        public let brand: String
        public let substance: String
    }
    public struct ConditionRow: Equatable, Identifiable {
        public var id: String { code }
        public let code: String
    }

    public let labs: [LabRow]
    public let meds: [MedRow]
    public let unmappedMeds: [String]        // substances not yet in the ATC crosswalk
    public let conditions: [ConditionRow]

    public var isEmpty: Bool { labs.isEmpty && meds.isEmpty && conditions.isEmpty }

    /// Catalog vars + "conditions" (when present) the covering grant must include.
    public var requiredScope: [String] {
        var scope = Set(labs.map(\.catalogVar))
        if !conditions.isEmpty { scope.insert("conditions") }
        // Meds ride the "medications" scope key by convention.
        if !meds.isEmpty { scope.insert("medications") }
        return scope.sorted()
    }
}

// MARK: - Builder

public enum SundhedPayloadBuilder {

    /// Aggregate the flat parse results into the derived review summary.
    public static func summarise(labs: [SundhedLabMeasurement],
                                 meds: [SundhedMedItem],
                                 diagnoses: [String]) -> SundhedDerivedSummary {
        // Labs: group by catalog var, order by date (latest last).
        let grouped = Dictionary(grouping: labs, by: \.catalogVar)
        let labRows: [SundhedDerivedSummary.LabRow] = grouped.map { (varKey, ms) in
            let ordered = ms.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            let values = ordered.map(\.value)
            let mean = values.reduce(0, +) / Double(values.count)
            return SundhedDerivedSummary.LabRow(
                catalogVar: varKey,
                component: ordered.last?.component ?? varKey,
                latest: ordered.last?.value ?? mean,
                mean: mean.roundedTo(2),
                unit: ordered.last?.unit ?? "",
                n: values.count
            )
        }
        .sorted { $0.catalogVar < $1.catalogVar }

        let medRows = meds.compactMap { m -> SundhedDerivedSummary.MedRow? in
            guard let atc = m.atc else { return nil }
            return SundhedDerivedSummary.MedRow(atc: atc, brand: m.brand, substance: m.activeSubstance)
        }
        let unmapped = meds.filter { $0.atc == nil }.map(\.activeSubstance)
        let condRows = diagnoses.map { SundhedDerivedSummary.ConditionRow(code: $0) }

        return SundhedDerivedSummary(labs: labRows, meds: medRows, unmappedMeds: unmapped, conditions: condRows)
    }

    /// Build the wire body. Only sections with content are attached (all-optional
    /// so the backend re-checks scope/guardrails regardless).
    public static func build(citizenID: String,
                             labs: [SundhedLabMeasurement],
                             meds: [SundhedMedItem],
                             diagnoses: [String],
                             asOf: Date = Date()) -> SundhedIngestBody {
        var metrics = SundhedIngestBody.Metrics()

        // Labs by_variable
        let grouped = Dictionary(grouping: labs, by: \.catalogVar)
        if !grouped.isEmpty {
            var byVar: [String: SundhedIngestBody.LabVar] = [:]
            for (varKey, ms) in grouped {
                let ordered = ms.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                let vals = ordered.map(\.value)
                let scaled = ordered.map(\.scaledValue)
                let scale = ordered.last?.scaleFactor ?? 1.0
                byVar[varKey] = SundhedIngestBody.LabVar(
                    latest: ordered.last?.value ?? 0,
                    mean: (vals.reduce(0, +) / Double(vals.count)).roundedTo(3),
                    n: vals.count,
                    unit: ordered.last?.unit ?? "",
                    scaleFactor: scale,
                    scaledLatest: ordered.last?.scaledValue ?? 0,
                    scaledMean: (scaled.reduce(0, +) / Double(scaled.count)).roundedTo(3)
                )
            }
            // Representative = the var with the most readings (stable tiebreak).
            let rep = byVar.max { a, b in
                a.value.n != b.value.n ? a.value.n < b.value.n : a.key > b.key
            }
            let summary = SundhedIngestBody.LabsSummary(
                mean: rep?.value.mean,
                latest: rep?.value.latest,
                unit: rep?.value.unit,
                n: rep?.value.n,
                representative: rep?.key,
                byVariable: byVar
            )
            metrics.labs = SundhedIngestBody.LabsBlock(provenance: "EXTERNAL", source: "sundhed_fhir", summary: summary)
        }

        // Meds coded_dist by ATC
        if !meds.isEmpty {
            var dist: [String: Int] = [:]
            for m in meds { if let atc = m.atc { dist[atc, default: 0] += 1 } }
            let summary = SundhedIngestBody.MedsSummary(count: meds.count, codedDist: dist)
            metrics.meds = SundhedIngestBody.MedsBlock(provenance: "EXTERNAL", source: "sundhed_fhir", summary: summary)
        }

        // Conditions coded_dist by ICD-10 (presence = 1), structured source only.
        if !diagnoses.isEmpty {
            var dist: [String: Int] = [:]
            for code in diagnoses { dist[code] = 1 }
            let summary = SundhedIngestBody.ConditionsSummary(
                count: dist.count,
                codedDist: dist,
                bySource: SundhedIngestBody.BySource(structured: dist, nlpDerived: [:])
            )
            metrics.conditions = SundhedIngestBody.ConditionsBlock(provenance: "EXTERNAL", source: "sundhed_fhir", summary: summary)
        }

        let counts: [String: Int] = [
            "labs": labs.count,
            "lab_variables": grouped.count,
            "meds": meds.count,
            "conditions": diagnoses.count,
        ]

        return SundhedIngestBody(
            citizenID: citizenID,
            provenance: "EXTERNAL",
            source: "sundhed_fhir",
            catalogVersion: "0.4.0",
            asOf: ISO8601DateFormatter().string(from: asOf),
            metrics: metrics,
            counts: counts
        )
    }
}

// MARK: - Ingest seam (the ONE canonical definition; both paths call this)

/// The single capability the feature needs from the backend: POST the derived,
/// coded summary to /ingest/sundhed. Actor = the citizen (Bearer = their GoTrue
/// access token). Both acquisition paths converge here:
///   • Path B (file/PDF upload) — `SundhedImportView` builds the body from the
///     on-device parse and calls this.
///   • Path A (in-app MitID WebView) — `SundhedWebSessionView` reduces its in-page
///     harvest to a `SundhedIngestBody` via `SundhedPayloadBuilder` and calls this.
/// `AppState`'s service can adopt it (see INTEGRATION.md) to reuse the shared
/// session + silent token refresh; until then `LiviqaSundhedIngestClient`
/// (SundhedImport.swift) provides a self-contained conformer.
public protocol SundhedIngesting: Sendable {
    /// POST the derived, coded body to /ingest/sundhed. Throws on transport
    /// failure or when no covering consent grant exists (surface the backend copy).
    func ingestSundhed(_ body: SundhedIngestBody) async throws
}

// MARK: - Deferred journal-NLP seam

/// Extracts CODED findings (ICD-10 codes) from free-text journal narrative
/// ("journal-fra-sygehus"). This is the DEFERRED NLP path — structured labs/meds/
/// diagnoses do NOT use it.
///
/// TODO(sundhed-nlp): implement one of two designs, both codes-only on the wire:
///   1. On-device model — a bundled/downloaded NER model maps narrative → ICD-10
///      entirely on-device; results feed `ConditionsSummary.by_source.nlp_derived`.
///   2. Codes-only server round-trip — send the narrative to a Danish clinical
///      NER service that returns ONLY codes (never echoes text back / stores it),
///      under an explicit, separate consent step.
/// Until then, the stub returns [] so the pipeline compiles and the conditions
/// block stays structured-only.
public protocol SundhedNarrativeExtractor {
    /// Returns ICD-10/SKS codes inferred from narrative text. Codes only.
    func extractCodes(from narrative: String) -> [String]
}

/// Deferred-build stub: no NLP, no codes. Present so callers can wire the seam now.
public struct NoopSundhedNarrativeExtractor: SundhedNarrativeExtractor {
    public init() {}
    public func extractCodes(from narrative: String) -> [String] { [] }
}

private extension Double {
    func roundedTo(_ places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
