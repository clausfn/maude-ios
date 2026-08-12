import Testing
import Foundation
@testable import Liviqa

// FR-TOD-06 — the Trends surface derivation. T-TOD-06.
// The gate is the point: correlation claims render ONLY past |r| ≥ 0.4,
// p ≤ 0.05 (conservative critical-r table) and N ≥ 10 paired days; below it
// the deriver refuses to assert. All copy must be FR-NDG-06 guard-clean.
struct TrendsDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ o: Int) -> Date { cal.startOfDay(for: cal.date(byAdding: .day, value: -o, to: Date())!) }

    private func glucoseDay(_ s: inout HealthSamples, offset: Int, tirPct: Double) {
        // 10 readings per day; `tirPct` of them inside 3.9–10.0 mmol/L.
        let inCount = Int((tirPct / 100 * 10).rounded())
        for i in 0..<10 {
            let mmol = i < inCount ? 6.0 : 12.5
            s.glucose.append(GlucoseReading(
                ts: day(offset).addingTimeInterval(Double(i) * 3600 + 6 * 3600),
                mmol: mmol, source: "cgm", tier: .good, provenance: .real))
        }
    }

    private func sleepDay(_ s: inout HealthSamples, offset: Int, hours: Double) {
        s.sleep.append(SleepReading(date: day(offset), stage: .core, hours: hours,
                                    source: "watch", tier: .good, provenance: .real))
    }

    // MARK: - Empty / honest states

    @Test func emptySamplesDeriveNil() {
        #expect(TrendsDeriver.derive(from: HealthSamples()) == nil)
    }

    @Test func thinDataAssertsNoCorrelationsAndNoBand() {
        var s = HealthSamples()
        for off in 0...2 { glucoseDay(&s, offset: off, tirPct: 80) }
        let t = TrendsDeriver.derive(from: s)
        #expect(t != nil)
        // 3 days: below the 5-day band minimum and far below the N ≥ 10 gate.
        #expect(t?.month.tirBandLo == nil)
        #expect(t?.month.correlations.isEmpty == true)
    }

    // MARK: - TIR trend vs own band

    @Test func tirTrendComesFromOwnDailySeries() throws {
        var s = HealthSamples()
        for off in 0..<14 { glucoseDay(&s, offset: off, tirPct: off % 2 == 0 ? 80 : 70) }
        let t = TrendsDeriver.derive(from: s)!
        #expect(t.month.tirDaily.count == 14)
        // Aggregate sits between the alternating day values.
        #expect(t.month.tirPeriodPct >= 70 && t.month.tirPeriodPct <= 80)
        // Today (offset 0, even) has data → today annotation present.
        #expect(t.month.tirTodayPct == 80)
        // A personal band exists and brackets the mean.
        let lo = try #require(t.month.tirBandLo)
        let hi = try #require(t.month.tirBandHi)
        #expect(lo < hi && lo >= 60 && hi <= 90)
    }

    // MARK: - The evidence gate

    @Test func correlationGateRefusesSmallN() {
        var s = HealthSamples()
        // 8 perfectly-correlated days — still below N ≥ 10: must NOT assert.
        for off in 0..<8 {
            let good = off % 2 == 0
            sleepDay(&s, offset: off, hours: good ? 8.0 : 5.5)
            glucoseDay(&s, offset: off, tirPct: good ? 90 : 60)
        }
        let t = TrendsDeriver.derive(from: s)!
        #expect(t.month.correlations.isEmpty)
    }

    @Test func correlationPassesGateOnStrongPairedSeriesAndIsGuardClean() throws {
        var s = HealthSamples()
        // 20 strongly-coupled days (r ≈ 1): long sleep ↔ high TIR.
        for off in 0..<20 {
            let good = off % 2 == 0
            sleepDay(&s, offset: off, hours: good ? 8.0 : 5.5)
            glucoseDay(&s, offset: off, tirPct: good ? 90 : 60)
        }
        let t = TrendsDeriver.derive(from: s)!
        let sleepTIR = t.month.correlations.first { $0.pairTitle.lowercased().contains("sleep") && $0.pairTitle.lowercased().contains("glucose") }
        let c = try #require(sleepTIR)
        #expect(c.strong)                 // |r| ≥ 0.6
        #expect(c.n >= 10)
        #expect(c.pText == "≤0.01" || c.pText == "≤0.05")
        // Fixed templates must pass the forbidden-construction guard.
        #expect(NudgeGuard.check(c.body) == nil)
        #expect(NudgeGuard.check(c.pairTitle) == nil)
    }

    @Test func uncorrelatedSeriesAssertsNothing() {
        var s = HealthSamples()
        // Orthogonal patterns → r = 0 exactly: sleep alternates every day,
        // TIR alternates every TWO days.
        for off in 0..<20 {
            sleepDay(&s, offset: off, hours: off % 2 == 0 ? 8.0 : 6.0)
            glucoseDay(&s, offset: off, tirPct: (off / 2) % 2 == 0 ? 80 : 70)
        }
        let t = TrendsDeriver.derive(from: s)!
        let sleepTIR = t.month.correlations.first { $0.pairTitle.lowercased().contains("glucose") && $0.pairTitle.lowercased().contains("sleep") }
        #expect(sleepTIR == nil)
    }

    @Test func pGateTableIsConservative() {
        // Below N = 10 → never significant, whatever r.
        #expect(TrendsDeriver.pGateText(r: 0.99, n: 9) == nil)
        // Weak r at moderate N → not significant.
        #expect(TrendsDeriver.pGateText(r: 0.30, n: 20) == nil)
        // Strong r at good N → at least ≤0.05.
        #expect(TrendsDeriver.pGateText(r: 0.80, n: 20) != nil)
    }

    // MARK: - Aggregate tiles (delta vs the previous window)

    @Test func monthAggregatesDeltaAgainstPreviousWindow() {
        var s = HealthSamples()
        // Resting HR: 60 bpm in the previous 30 days, 57 bpm in the current 30.
        for off in 0..<30 {
            s.restingHR.append(DailyMetric(date: day(off), kind: .restingHR, value: 57,
                                           source: "watch", tier: .good, provenance: .real))
        }
        for off in 30..<60 {
            s.restingHR.append(DailyMetric(date: day(off), kind: .restingHR, value: 60,
                                           source: "watch", tier: .good, provenance: .real))
        }
        let t = TrendsDeriver.derive(from: s)!
        #expect(t.month.rhrAvg == 57)
        #expect(t.month.rhrDeltaBpm == -3)
        // No workouts tracked → active tile honestly empty.
        #expect(t.month.activeMinPerDay == nil)
    }

    // MARK: - Period comparison (InsightCompare)

    @Test func periodCompareReportsSleepShiftAndIsGuardClean() throws {
        var s = HealthSamples()
        for off in 0..<30 { sleepDay(&s, offset: off, hours: 7.2) }    // now
        for off in 30..<60 { sleepDay(&s, offset: off, hours: 6.8) }   // before
        let t = TrendsDeriver.derive(from: s)!
        let c = try #require(t.compare)
        #expect(c.sentence.contains("more"))
        #expect(c.currentHours > c.previousHours)
        #expect(NudgeGuard.check(c.sentence) == nil)
    }

    @Test func periodCompareStaysQuietOnNoise() {
        var s = HealthSamples()
        for off in 0..<60 { sleepDay(&s, offset: off, hours: 7.0) }    // flat
        let t = TrendsDeriver.derive(from: s)!
        #expect(t.compare == nil)   // < 10 min shift → no card, not a fabricated one
    }

    // MARK: - FR-TOD-05: the 30-day HRV series for the evening month trend

    @Test func monthRangeCarriesHRVDailySeries() {
        var s = HealthSamples()
        for off in 0..<30 {
            s.hrv.append(DailyMetric(date: day(off), kind: .hrvSDNN, value: 40 + Double(off % 5),
                                     source: "watch", tier: .good, provenance: .real))
        }
        let t = TrendsDeriver.derive(from: s)!
        #expect(t.month.hrvDaily.count == 30)
        #expect(t.week.hrvDaily.count == 7)
    }
}
