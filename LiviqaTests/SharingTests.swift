import Testing
import Foundation
import CryptoKit
@testable import Liviqa

// Scoped, derived-only, encrypted share boundary.
// RTM: FR-ARCH-04, NFR-PRIV-01, NFR-SEC-02. T-SHARE-01..05.
struct SharingTests {

    private let cal = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        Calendar(identifier: .gregorian)
            .startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
            .addingTimeInterval(Double(offset) * 86_400)
    }

    /// Three days of every stream, all SIMULATED (proves provenance is dropped).
    private func samples() -> HealthSamples {
        var s = HealthSamples()
        for d in 0..<3 {
            s.glucose.append(GlucoseReading(ts: day(d).addingTimeInterval(3600), mmol: 5.5 + Double(d) * 0.1,
                                            source: "mock", tier: .estimate, provenance: .simulated))
            s.hrv.append(DailyMetric(date: day(d), kind: .hrvSDNN, value: 42 + Double(d),
                                     source: "mock", tier: .estimate, provenance: .simulated))
            s.restingHR.append(DailyMetric(date: day(d), kind: .restingHR, value: 58,
                                           source: "mock", tier: .estimate, provenance: .simulated))
            s.steps.append(DailyMetric(date: day(d), kind: .steps, value: 5000,
                                       source: "mock", tier: .estimate, provenance: .simulated))
            s.sleep.append(SleepReading(date: day(d), stage: .deep, hours: 6.5,
                                        source: "mock", tier: .estimate, provenance: .simulated))
        }
        return s
    }

    private func grant(_ scopes: [String]) -> WalletGrant {
        WalletGrant(id: UUID(), userId: nil, recipientName: "Test",
                    recipientType: .clinical, scopeKeys: scopes,
                    isActive: true, expiresAt: nil, createdAt: nil)
    }

    // T-SHARE-01 — only metrics unlocked by the grant's scopes appear.
    @Test func scopeFiltersMetrics() {
        let bundle = ShareBundleBuilder.build(from: samples(), grant: grant(["glucose", "hrv"]),
                                              rangeStart: day(0), rangeEnd: day(2), calendar: cal)
        #expect(bundle.metricsPresent == ["glucose", "hrv"])
        #expect(!bundle.metricsPresent.contains("steps"))
        #expect(!bundle.metricsPresent.contains("sleep"))
    }

    // T-SHARE-02 — the serialized bundle NEVER contains provenance/source/raw markers.
    @Test func exportNeverLeaksProvenanceOrSource() throws {
        let bundle = ShareBundleBuilder.build(from: samples(), grant: grant(["glucose", "hrv", "activity", "sleep"]),
                                              rangeStart: day(0), rangeEnd: day(2), calendar: cal)
        let json = String(data: try SecureShareExporter.encoder.encode(bundle), encoding: .utf8)!
        #expect(!json.lowercased().contains("provenance"))
        #expect(!json.contains("SIMULATED"))
        #expect(!json.lowercased().contains("\"source\""))
        #expect(!json.contains("mealContext"))
    }

    // T-SHARE-03 — empty scopes ⇒ empty bundle (deny by default).
    @Test func unknownScopesYieldNothing() {
        let bundle = ShareBundleBuilder.build(from: samples(), grant: grant(["calendar", "spending"]),
                                              rangeStart: day(0), rangeEnd: day(2), calendar: cal)
        #expect(bundle.summaries.isEmpty)
    }

    // T-SHARE-04 — encrypt → decrypt round-trips to the identical bundle.
    @Test func encryptRoundTrips() throws {
        let bundle = ShareBundleBuilder.build(from: samples(), grant: grant(["glucose", "sleep"]),
                                              rangeStart: day(0), rangeEnd: day(2), calendar: cal)
        let exporter = SecureShareExporter(box: CryptoBox(key: SymmetricKey(size: .bits256)))
        let sealed = try exporter.encrypt(bundle)
        #expect(sealed.ciphertext.count > 0)
        #expect(try exporter.decrypt(sealed) == bundle)
    }

    // T-SHARE-05 — one derived row per metric per day (no raw intraday rows).
    @Test func oneRowPerMetricPerDay() {
        let bundle = ShareBundleBuilder.build(from: samples(), grant: grant(["glucose"]),
                                              rangeStart: day(0), rangeEnd: day(2), calendar: cal)
        #expect(bundle.summaries.count == 3)              // 3 days, not N intraday readings
        #expect(bundle.summaries.allSatisfy { $0.metric == "glucose" && $0.unit == "mmol/L" })
    }
}
