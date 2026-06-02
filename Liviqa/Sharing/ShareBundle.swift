// ShareBundle.swift — the ONLY shape of data that may leave the device.
//
// Privacy contract (NFR-PRIV-01 / FR-ARCH-04): a share bundle carries
// DERIVED DAILY AGGREGATES ONLY — never raw intraday samples, never a `source`,
// and NEVER `provenance` (REAL/SIMULATED/EXTERNAL is internal arbitration; the
// no-AI-tell rule forbids it from ever crossing the device boundary). It is
// scoped to exactly the metrics the user's consent grant allows, and it is
// always encrypted at the boundary (see SecureShareExporter).
//
// Pure Foundation (Android-portable). A blocking test (T-SHARE-02) fails the
// build if the serialized bundle ever contains a provenance/source field.
import Foundation

/// One derived daily value. Numeric + unit only — no provenance, no source.
public struct DailySummary: Codable, Sendable, Equatable {
    public let date: Date
    public let metric: String   // canonical: glucose|hrv|restingHR|steps|activeEnergy|sleep|workouts
    public let value: Double
    public let unit: String

    public init(date: Date, metric: String, value: Double, unit: String) {
        self.date = date; self.metric = metric; self.value = value; self.unit = unit
    }
}

/// The export envelope. Codable so it serializes to JSON before encryption.
public struct ShareBundle: Codable, Sendable, Equatable {
    public static let schemaID = "liviqa.share.v1"

    public let schema: String
    public let createdAt: Date
    public let scopeKeys: [String]      // the consent scopes this bundle honors
    public let rangeStart: Date
    public let rangeEnd: Date
    public let summaries: [DailySummary]

    public init(createdAt: Date, scopeKeys: [String], rangeStart: Date,
                rangeEnd: Date, summaries: [DailySummary]) {
        // Whole-second resolution → ISO-8601 (de)serialization is lossless and
        // the encrypted round-trip is byte-stable. Daily aggregates don't need
        // sub-second precision anyway.
        func floorSeconds(_ d: Date) -> Date {
            Date(timeIntervalSince1970: d.timeIntervalSince1970.rounded(.down))
        }
        self.schema = Self.schemaID
        self.createdAt = floorSeconds(createdAt)
        self.scopeKeys = scopeKeys
        self.rangeStart = floorSeconds(rangeStart)
        self.rangeEnd = floorSeconds(rangeEnd)
        self.summaries = summaries
    }

    /// Distinct metrics actually present — handy for scope assertions.
    public var metricsPresent: Set<String> { Set(summaries.map(\.metric)) }
}

/// Maps consent scope keys → the derived metrics they unlock. Anything not
/// listed (or external-only like `calendar`) yields nothing — deny by default.
public enum ShareScope {
    static let metricsByScopeKey: [String: [String]] = [
        "glucose":        ["glucose"],
        "hrv":            ["hrv"],
        "heart_rate":     ["restingHR"],
        "activity":       ["steps", "activeEnergy"],
        "sleep":          ["sleep"],
        "training_load":  ["workouts"],
    ]

    /// The set of derived metric keys permitted by the given consent scopes.
    public static func metrics(for scopeKeys: [String]) -> Set<String> {
        var allowed: Set<String> = []
        for key in scopeKeys { allowed.formUnion(metricsByScopeKey[key] ?? []) }
        return allowed
    }
}
