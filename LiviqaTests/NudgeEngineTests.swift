import Testing
import Foundation
@testable import Liviqa

// Shared fixtures for nudge tests.
enum NudgeFixtures {
    struct Scenario { let samples: HealthSamples; let signals: ClinicalSignals }

    /// 7 days with the last day low-HRV, low-steps, short-sleep, high-glucose.
    static func triggering(afib: Bool = false) -> [Scenario] {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        var s = HealthSamples.empty
        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: start)!
            s.hrv.append(.init(date: day, kind: .hrvSDNN, value: i == 6 ? 30 : 55, source: "Mock", tier: .good, provenance: .simulated))
            s.restingHR.append(.init(date: day, kind: .restingHR, value: 58, source: "Mock", tier: .good, provenance: .simulated))
            s.steps.append(.init(date: day, kind: .steps, value: i == 6 ? 2000 : 8000, source: "Mock", tier: .estimate, provenance: .simulated))
            s.sleep.append(.init(date: day, stage: .asleepUnspecified, hours: i == 6 ? 5 : 7.5, source: "Mock", tier: .estimate, provenance: .simulated))
            for h in [7, 12, 18] {
                let ts = cal.date(byAdding: .hour, value: h, to: day)!
                s.glucose.append(.init(ts: ts, mmol: i == 6 ? 9.2 : 6.0, source: "Mock", tier: .good, provenance: .simulated))
            }
        }
        return [Scenario(samples: s, signals: .init(afibSignalPresent: afib))]
    }
}

struct NudgeEngineTests {

    // T-NDG-01 — output is capped ("4 nudges, not 48 charts").
    @Test func cappedAtFour() {
        let s = NudgeFixtures.triggering()[0]
        #expect(NudgeEngine().generate(samples: s.samples, signals: s.signals).count <= 4)
    }

    // T-NDG-02 — AFib is display-only: route-to-clinician, no interpretation,
    // top priority so it always survives the cap (D9 / RK-CARD-01).
    @Test func afibIsDisplayOnlyRoute() {
        let s = NudgeFixtures.triggering(afib: true)[0]
        let nudges = NudgeEngine().generate(samples: s.samples, signals: s.signals)
        let afib = nudges.first { $0.lane == .displayOnly }
        #expect(afib != nil)
        #expect(afib?.category == .routeToClinician)
        #expect(afib?.priority == 100)
    }

    // T-NDG-03 — no AFib signal ⇒ no cardiac nudge at all.
    @Test func noAfibNoCardiac() {
        let s = NudgeFixtures.triggering(afib: false)[0]
        let nudges = NudgeEngine().generate(samples: s.samples, signals: s.signals)
        #expect(!nudges.contains { $0.lane == .displayOnly })
    }

    // T-NDG-04 — only allow-listed categories are ever emitted.
    @Test func onlyAllowListedCategories() {
        let s = NudgeFixtures.triggering(afib: true)[0]
        let nudges = NudgeEngine().generate(samples: s.samples, signals: s.signals)
        let allowed = Set(NudgeCategory.allCases)
        #expect(nudges.allSatisfy { allowed.contains($0.category) })
    }

    // T-NDG-05 — baseline-relative: the low-HRV last day yields a recovery lever.
    @Test func baselineRelativeRecovery() {
        let s = NudgeFixtures.triggering()[0]
        let nudges = NudgeEngine().generate(samples: s.samples, signals: s.signals, cap: 10)
        #expect(nudges.contains { $0.title.contains("Recovery") && $0.category == .behaviouralLever })
    }

    // T-NDG-07 — flat/sparse history ⇒ no fabricated nudges.
    @Test func sparseHistoryProducesNothingUnsafe() {
        let nudges = NudgeEngine().generate(samples: .empty)
        #expect(nudges.isEmpty)
    }

    // T-BASE-01 — Baseline needs ≥3 points and bands at ±1σ.
    @Test func baselineBands() {
        #expect(Baseline.from([1, 2]) == nil)
        let b = Baseline.from([10, 10, 10, 10])
        #expect(b?.band(for: 99) == .inBand)   // zero sd ⇒ in-band
        let v = Baseline.from([2, 4, 6, 8])!
        #expect(v.band(for: 100) == .above)
        #expect(v.band(for: -100) == .below)
    }
}
