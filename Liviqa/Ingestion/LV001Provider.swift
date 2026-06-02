// LV001Provider.swift — real founder demo source (Liviqa surface only).
//
// Stub seam for the real-data demo build. It is NOT active by default; it only
// yields data when built with the `LV001_DEMO` compilation condition AND a
// local export is present (never committed). Readings are provenance = .real /
// .external — never .simulated — so they remain clinically eligible.
//
// PR-3 ships the seam only; the concrete real-export reader lands with the
// HealthKitService work (PR-4) since it shares the same parsing/normalization.
import Foundation

public struct LV001Provider: HealthDataProvider {
    public let kind: DataProviderKind = .lv001
    public init() {}

    public func requestReadAuthorization() async throws {
        #if !LV001_DEMO
        throw HealthProviderError.notConfigured
        #endif
    }

    public func fetchSamples(from start: Date, to end: Date) async throws -> HealthSamples {
        #if LV001_DEMO
        // TODO(PR-4): parse the local LV001 export into HealthSamples
        // (provenance .real / .external). Until then, no synthetic fallback —
        // returning simulated data here would violate the clinical gate.
        return .empty
        #else
        throw HealthProviderError.notConfigured
        #endif
    }
}
