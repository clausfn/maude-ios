import Testing
import Foundation
@testable import Liviqa

// Derived share builder — RTM: FR-SHARE-01, D-BACKEND-SCOPE, NFR-PRIV-05.
struct DerivedShareBuilderTests {

    private func g(_ mmol: Double, _ dayOffset: Int = 0) -> GlucoseReading {
        GlucoseReading(ts: Date(timeIntervalSince1970: 1_750_000_000 + Double(dayOffset) * 86_400),
                       mmol: mmol, source: "test", tier: .good, provenance: .simulated)
    }
    private func dm(_ kind: DailyMetricKind, _ value: Double, _ dayOffset: Int = 0) -> DailyMetric {
        DailyMetric(date: Date(timeIntervalSince1970: 1_750_000_000 + Double(dayOffset) * 86_400),
                    kind: kind, value: value, source: "test", tier: .good, provenance: .simulated)
    }

    // T-SHARE-01 — TIR % is computed correctly and headline lands in summary.mean.
    @Test func computesTimeInRange() {
        // 3 in-range (3.9–10.0), 1 low, 1 high → 60%
        let samples = HealthSamples(glucose: [g(5.0), g(7.0), g(9.0), g(3.0), g(12.0)])
        let req = DerivedShareBuilder.build(from: samples, scopeGroups: ["glucose"])
        let tir = req.payload.metrics["tir"]
        #expect(tir?.summary?["mean"] == 60.0)
        #expect(tir?.unit == "%")
        let events = Dictionary(uniqueKeysWithValues: (tir?.events ?? []).map { ($0.label, $0.count) })
        #expect(events["Hypos (<3.9)"] == 1)
        #expect(events["Hypers (>10)"] == 1)
    }

    // T-SHARE-02 — only CONSENTED groups are emitted; nothing outside scope leaks.
    @Test func emitsOnlyConsentedGroups() {
        let samples = HealthSamples(glucose: [g(5.0)], hrv: [dm(.hrvSDNN, 30)], steps: [dm(.steps, 8000)])
        let req = DerivedShareBuilder.build(from: samples, scopeGroups: ["activity"])
        #expect(req.payload.metrics["steps"] != nil)   // activity granted
        #expect(req.payload.metrics["tir"] == nil)      // glucose NOT granted
        #expect(req.payload.metrics["hrv"] == nil)      // recovery NOT granted
    }

    // T-SHARE-03 — the encoded payload carries NO provenance/source (NFR-PRIV-05, D-BACKEND-SCOPE).
    @Test func payloadHasNoProvenanceOrRawSource() throws {
        let samples = HealthSamples(glucose: [g(5.0), g(11.0)], hrv: [dm(.hrvSDNN, 28)])
        let req = DerivedShareBuilder.build(from: samples, scopeGroups: ["glucose", "recovery"])
        let data = try JSONEncoder().encode(req)
        let json = String(decoding: data, as: UTF8.self).lowercased()
        #expect(!json.contains("provenance"))
        #expect(!json.contains("simulated"))
        #expect(!json.contains("\"source\""))
    }

    // T-SHARE-04 — mean glucose is a derived summary, not raw readings.
    @Test func meanGlucoseIsDerived() {
        let samples = HealthSamples(glucose: [g(8.0), g(10.0)])
        let req = DerivedShareBuilder.build(from: samples, scopeGroups: ["glucose"])
        #expect(req.payload.metrics["mean_g"]?.summary?["mean"] == 9.0)
        #expect(req.payload.metrics["mean_g"]?.unit == "mmol/L")
    }
}
