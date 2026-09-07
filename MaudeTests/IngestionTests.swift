import Testing
import Foundation
@testable import Maude

// L1 ingestion seam — RTM: FR-ING-01, FR-ING-07, NFR-PORT-01.
struct IngestionTests {

    private func week() -> (Date, Date) {
        let end = Date(timeIntervalSince1970: 1_750_000_000)
        return (end.addingTimeInterval(-6 * 86_400), end)
    }

    // T-ING-01 — mock provider yields the full read set, all SIMULATED.
    @Test func mockProducesSimulatedReadSet() async throws {
        let (from, to) = week()
        let s = try await MockDataProvider().fetchSamples(from: from, to: to)

        #expect(!s.isEmpty)
        #expect(!s.glucose.isEmpty)
        #expect(!s.restingHR.isEmpty)
        #expect(!s.hrv.isEmpty)
        #expect(!s.steps.isEmpty)
        #expect(!s.activeEnergy.isEmpty)
        #expect(!s.sleep.isEmpty)

        // Every reading must be SIMULATED (clinical gate stays satisfiable).
        let allSimulated =
            s.glucose.allSatisfy { $0.provenance == .simulated } &&
            s.allDaily.allSatisfy { $0.provenance == .simulated } &&
            s.sleep.allSatisfy { $0.provenance == .simulated } &&
            s.workouts.allSatisfy { $0.provenance == .simulated }
        #expect(allSimulated)
    }

    // T-ING-02 — glucose is canonical mmol/L in a plausible band (OD-07).
    // Band 3.0–15.0: a TIR 50–75% LADA persona legitimately produces readings in
    // the ATTD 'very high' band (>13.9) — capping at 12 made the seeds clinically false.
    @Test func mockGlucoseIsCanonicalMmol() async throws {
        let (from, to) = week()
        let s = try await MockDataProvider().fetchSamples(from: from, to: to)
        #expect(s.glucose.allSatisfy { $0.mmol >= 3.0 && $0.mmol <= 15.0 })
    }

    // T-ING-03 — deterministic: same seed ⇒ identical first glucose value.
    @Test func mockIsDeterministic() async throws {
        let (from, to) = week()
        let a = try await MockDataProvider(seed: 42).fetchSamples(from: from, to: to)
        let b = try await MockDataProvider(seed: 42).fetchSamples(from: from, to: to)
        #expect(a.glucose.first?.mmol == b.glucose.first?.mmol)
    }

    // T-ING-04 — LV001 is inert unless the demo flag is set (no synthetic leak).
    @Test func lv001NotConfiguredByDefault() async {
        await #expect(throws: HealthProviderError.notConfigured) {
            _ = try await LV001Provider().fetchSamples(from: .now, to: .now)
        }
    }

    // T-ING-05 — factory default + demo-data flag wiring (FR-ARCH-05).
    @Test func factoryAndDemoFlag() {
        #expect(HealthProviderFactory.make(.mock).kind == .mock)
        #expect(DataProviderKind.mock.isDemoData)
        #expect(!DataProviderKind.healthKit.isDemoData)
    }
}
