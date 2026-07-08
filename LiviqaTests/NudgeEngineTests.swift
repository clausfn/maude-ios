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
            // Baseline HRV must have natural variance: a zero-σ baseline is always
            // in-band by design (see baselineBands), so a flat 55 would never let
            // the low last day register as "below". Real HRV varies day to day.
            s.hrv.append(.init(date: day, kind: .hrvSDNN, value: i == 6 ? 30 : 55 + Double(i), source: "Mock", tier: .good, provenance: .simulated))
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

// T-NDG-08 — the sleep nudge must group multi-source segments into per-night
// totals before comparing "last night" to the baseline. Regression for the
// fragment-vs-night bug: with iPhone + Apple Watch both recording a night as
// many overlapping asleep segments, the old code mapped each raw segment to its
// own hours and compared one fragment against a baseline of fragments. Here
// every raw segment is a uniform 1.5h fragment (zero-σ per-segment series, which
// can never flag anything), so only correct per-night grouping can distinguish a
// short night from a normal one.
struct SleepNudgeGroupingTests {
    private let cal = Calendar(identifier: .gregorian)
    private let start = Calendar(identifier: .gregorian)
        .startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))

    /// One night as uniform 1.5h asleep fragments, each recorded twice (iPhone +
    /// Apple Watch overlap) so the union collapses the duplicates. `hours` must be
    /// a multiple of 1.5; fragments run back-to-back from the day's start, so the
    /// merged nightly total is exactly `hours`.
    private func night(_ dayOffset: Int, hours: Double) -> [SleepReading] {
        let day = cal.date(byAdding: .day, value: dayOffset, to: start)!
        let slots = Int((hours / 1.5).rounded())
        return (0..<slots).flatMap { slot -> [SleepReading] in
            let segStart = cal.date(byAdding: .minute, value: slot * 90, to: day)!
            return ["iPhone", "Apple Watch"].map { src in
                SleepReading(date: segStart, stage: .core, hours: 1.5,
                             source: src, tier: .estimate, provenance: .simulated)
            }
        }
    }

    /// Six baseline nights with natural variance (a zero-σ baseline is always
    /// in-band by design), then the night under test — all doubly-sourced.
    private func samples(lastNightHours: Double) -> HealthSamples {
        var s = HealthSamples.empty
        for (i, h) in [7.5, 6.0, 7.5, 6.0, 7.5, 6.0].enumerated() { s.sleep += night(i, hours: h) }
        s.sleep += night(6, hours: lastNightHours)
        return s
    }

    // A genuinely short last night (3h vs a ~6.75h baseline) fires the lever —
    // impossible under the old per-segment code, whose series was a flat 1.5.
    @Test func shortLastNightFromMergedFragmentsFires() {
        let nudges = NudgeEngine().generate(samples: samples(lastNightHours: 3.0), cap: 10)
        #expect(nudges.contains { $0.title.contains("Short night") && $0.category == .behaviouralLever })
    }

    // A normal (in-band) last night, equally fragmented across two sources, must
    // not fabricate a short-night nudge.
    @Test func normalLastNightFromMergedFragmentsIsQuiet() {
        let nudges = NudgeEngine().generate(samples: samples(lastNightHours: 7.5), cap: 10)
        #expect(!nudges.contains { $0.title.contains("Short night") })
    }
}
