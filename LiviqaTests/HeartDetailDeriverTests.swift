import Testing
import Foundation
@testable import Liviqa

// A7.2 Area ④ — the Heart detail screen's on-device derivation. Safety
// invariants under test: every band is the user's OWN mean ±1σ (never emitted
// below 5 values); the AFib lane carries ONLY display fields (figure + count +
// date — no trend, no interpretation, OD-11); templates pass FR-NDG-06.
struct HeartDetailDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
    }
    private func at(day: Int, hour: Int = 8) -> Date {
        let d = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: now))!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d)!
    }
    private func rhr(_ v: Double, day: Int) -> DailyMetric {
        DailyMetric(date: at(day: day), kind: .restingHR, value: v,
                    source: "Watch", tier: .good, provenance: .real)
    }
    private func bp(_ sys: Int, _ dia: Int, day: Int, hour: Int = 8) -> BloodPressureReading {
        BloodPressureReading(ts: at(day: day, hour: hour), sys: sys, dia: dia,
                             source: "Home cuff", tier: .good, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(HeartDetailDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func rhrBandNeedsFiveDays() throws {
        var s = HealthSamples()
        s.restingHR = [rhr(58, day: 0), rhr(59, day: -1), rhr(57, day: -2),
                       rhr(60, day: -3)]
        let d4 = try #require(HeartDetailDeriver.derive(from: s, now: now))
        #expect(d4.rhrBand == nil)
        #expect(d4.rhrLatest == 58)

        s.restingHR.append(rhr(58, day: -4))
        let d5 = try #require(HeartDetailDeriver.derive(from: s, now: now))
        let band = try #require(d5.rhrBand)
        #expect(band.lowerBound < 58.4 && band.upperBound > 58.4)   // around the mean
        #expect(d5.rhrSeries.count == 5)
    }

    @Test func bpDayLatestCorridorsAndPeak() throws {
        var s = HealthSamples()
        // 6 readings across 6 days; day −2 has TWO readings — latest must win.
        s.bloodPressure = [
            bp(122, 79, day: -5), bp(119, 77, day: -4), bp(124, 80, day: -3),
            bp(110, 70, day: -2, hour: 7), bp(121, 78, day: -2, hour: 20),
            bp(140, 90, day: -1), bp(120, 78, day: 0),
        ]
        let d = try #require(HeartDetailDeriver.derive(from: s, now: now))
        #expect(d.bp.count == 6)                       // 6 distinct days
        #expect(d.bp[3].sys == 121)                    // day −2 evening reading won
        let sysBand = try #require(d.sysBand)
        // 140 sits above the own corridor ⇒ the single annotation lands on it.
        #expect(Double(140) > sysBand.upperBound)
        let peak = try #require(d.bpPeakIndex)
        #expect(d.bp[peak].sys == 140)
        #expect(d.bp.last?.isLatest == true)
        #expect(d.bpLatestText == "120/78")
        #expect(d.bpEdgeLabels.count == 2)
        #expect(d.bpSource == "Home cuff")
    }

    @Test func afibIsDisplayOnlyFields() throws {
        var s = HealthSamples()
        s.afib = [
            AFibReading(ts: at(day: -3), pct: 1.2, source: "Watch", tier: .good, provenance: .real),
            AFibReading(ts: at(day: 0), pct: 0.8, source: "Watch", tier: .good, provenance: .real),
        ]
        let d = try #require(HeartDetailDeriver.derive(from: s, now: now))
        #expect(d.afibLatestPct == 0.8)                // the recorded figure, as-is
        #expect(d.afibDaysObserved == 2)
        #expect(d.afibLatestDateText != nil)
        // Display-only lane: nothing else derived — no series, no band, no delta
        // fields exist on the type for AFib (compile-time guarantee).
    }

    @Test func fixedTemplatesPassNudgeGuard() throws {
        var s = HealthSamples()
        s.restingHR = (0..<8).map { rhr(58 + Double($0 % 3), day: -$0) }
        s.bloodPressure = (0..<6).map { bp(120 + $0, 78, day: -$0) }
        s.afib = [AFibReading(ts: at(day: 0), pct: 0.4, source: "Watch",
                              tier: .good, provenance: .real)]
        let d = try #require(HeartDetailDeriver.derive(from: s, now: now))
        let derived = HeartDetailView.Model(derived: d)
        let seed = HeartDetailView.Model.designSeed
        for m in [derived, seed] {
            #expect(NudgeGuard.check(m.verdict) == nil)
            #expect(NudgeGuard.check(m.bpHeadline) == nil)
            #expect(NudgeGuard.check(m.rhrHeadline) == nil)
            #expect(NudgeGuard.check(m.afibHeadline) == nil)
            if let line = m.afibLine { #expect(NudgeGuard.check(line) == nil) }
            // The designated AFib rail copy itself must stay guard-clean.
            #expect(NudgeGuard.check("Rhythm findings are display-only — no score, no trend, no advice.") == nil)
        }
    }
}
