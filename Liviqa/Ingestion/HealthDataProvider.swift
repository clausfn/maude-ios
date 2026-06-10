// HealthDataProvider.swift — L1 ingestion seam (portable, framework-free).
//
// The provider is READ-ONLY by contract: it exposes a read-authorization
// request and a fetch, and NOTHING that writes, saves, or uploads (FR-ARCH-04,
// FR-ING-07). HealthKit's empty write set is enforced in the concrete
// HealthKitService (PR-4); this protocol simply offers no write surface.
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public enum DataProviderKind: String, Sendable, CaseIterable {
    case healthKit   // real on-device Apple Health (PR-4)
    case mock        // synthetic timeseries_daily demo user (default)
    case lv001       // real founder demo (Liviqa surface only, build-flagged)

    /// Whether data from this provider is real (drives the FR-ARCH-05 "Demo
    /// data" indicator — surfaced in the UI layer, never as a provenance pill).
    public var isDemoData: Bool { self == .mock }
}

public enum HealthProviderError: Error, Equatable, Sendable {
    case notAuthorized
    case notConfigured
    case unavailableOnPlatform
}

/// Abstraction over every health-data source. Implementations: `HealthKitService`
/// (PR-4), `MockDataProvider`, `LV001Provider`.
public protocol HealthDataProvider: Sendable {
    /// Identifies the source for the FR-ARCH-05 demo indicator and arbitration.
    var kind: DataProviderKind { get }

    /// Request READ-ONLY authorization. No write/share scopes are ever requested.
    func requestReadAuthorization() async throws

    /// Fetch the MVP read set for a date range. Pure read; never uploads.
    func fetchSamples(from start: Date, to end: Date) async throws -> HealthSamples
}

/// Selects the active provider. `.healthKit` resolves to `HealthKitService`
/// where the SDK exists, falling back to the mock on platforms without it.
public enum HealthProviderFactory {
    /// True when this build can read real on-device health data (HealthKit SDK
    /// present AND the platform has Health available). False on platforms/
    /// toolchains without HealthKit, so callers fall back to the demo provider.
    public static var isRealHealthDataAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    public static func make(_ kind: DataProviderKind) -> any HealthDataProvider {
        switch kind {
        case .mock:  return MockDataProvider()
        case .lv001: return LV001Provider()
        case .healthKit:
            #if canImport(HealthKit)
            return HealthKitService()
            #else
            return MockDataProvider()
            #endif
        }
    }
}
