// CoreTypes.swift — L2 data-model cross-cutting types (DataModel v1 Reference).
//
// PORTABILITY (NFR-PORT-01): everything in this file is plain, framework-free
// Swift (no SwiftData / HealthKit / SwiftUI). The Android port maps these same
// enums and rules onto Kotlin. Only the @Model persistence in Entities.swift is
// iOS-specific.
import Foundation

// MARK: - Tier & provenance (on every sample row, DataModel v1 §2.1)

/// Trust tier of a sample's source. Drives source arbitration (DataModel v1 §2.3):
/// highest tier present wins; lower tiers only fill gaps; clinical is never
/// silently blended with a consumer estimate.
public enum DataTier: String, Codable, CaseIterable, Sendable {
    case clinical
    case good
    case estimate
}

/// Where a datum came from. **DATA FIELD ONLY.**
///
/// `provenance` MUST NEVER be rendered on any user-facing surface (no-AI-tell
/// cardinal rule / NFR-PRIV-05). There is intentionally **no** `displayName`,
/// `label`, or user-facing string here. A blocking guard test (T-PROV-01,
/// landing with ingestion) fails the build if a provenance value reaches the UI.
public enum Provenance: String, Codable, Sendable {
    case real = "REAL"
    case simulated = "SIMULATED"
    case external = "EXTERNAL"
}

/// Provenance values permitted for **clinical-tier** data. `.simulated` is
/// deliberately absent, so a clinical sample carrying simulated provenance is
/// *unrepresentable* on this path — the type-level expression of the DataModel
/// v1 rule "clinical fields reject SIMULATED." The same rule is enforced at the
/// schema gate for the variable-tier path (see `validateTierProvenance`).
public enum ClinicalProvenance: String, Codable, Sendable {
    case real = "REAL"
    case external = "EXTERNAL"

    public var provenance: Provenance {
        switch self {
        case .real: return .real
        case .external: return .external
        }
    }
}

// MARK: - Validation (the schema gate)

public enum DataModelError: Error, Equatable, Sendable {
    /// A clinical-tier row may not carry SIMULATED provenance (DataModel v1 §2.1).
    case clinicalRejectsSimulated
    /// A required physiological value was out of a sane physical range.
    case invalidValue(field: String)
}

/// The schema-level invariant enforced by every sample initializer:
/// clinical-tier data can never be SIMULATED.
@inline(__always)
public func validateTierProvenance(_ tier: DataTier, _ provenance: Provenance) throws {
    if tier == .clinical && provenance == .simulated {
        throw DataModelError.clinicalRejectsSimulated
    }
}

/// Common shape of every raw sample row (DataModel v1 §2.1).
public protocol Provenanced {
    var source: String { get }
    var tier: DataTier { get }
    var provenance: Provenance { get }
}

// MARK: - Glucose canonical unit (OD-07 / D10)

/// Glucose is stored in **mmol/L** everywhere on device (OD-07 resolved). This
/// is the only canonical unit; mg/dL exists solely as an import/conversion edge.
public enum GlucoseUnit {
    /// mg/dL per mmol/L for glucose (molar mass basis 18.0182).
    public static let mgdlPerMmol = 18.0182

    public static func mmol(fromMgdl mgdl: Double) -> Double { mgdl / mgdlPerMmol }
    public static func mgdl(fromMmol mmol: Double) -> Double { mmol * mgdlPerMmol }
}
