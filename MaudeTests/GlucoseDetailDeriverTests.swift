import Testing
import Foundation
@testable import Maude

// A7.2 Area ③ — the Glucose detail screen's on-device derivation (mmol/L, OD-07;
// GMI headline; 5-band clinical distribution). Data-honesty invariants: nil
// without readings, GMI absent below the 14-day consensus minimum, prev-week
// comparison absent without a previous week.
struct GlucoseDetailDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    /// A fixed "now" mid-afternoon so today-window logic is deterministic.
    private var now: Date {
        cal.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!
    }
    private func at(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now))!
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
    private func reading(_ mmol: Double, day: Int, hour: Int, minute: Int = 0,
                         source: String = "cgm") -> GlucoseReading {
        GlucoseReading(ts: at(dayOffset: day, hour: hour, minute: minute), mmol: mmol,
                       source: source, tier: .good, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(GlucoseDetailDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func glucoseOutsideTheWeekDerivesNil() throws {
        var s = HealthSamples()
        s.glucose = [reading(6.0, day: -20, hour: 9)]
        #expect(GlucoseDetailDeriver.derive(from: s, now: now) == nil)
    }

    @Test func weekTirBandsAndAverage() throws {
        var s = HealthSamples()
        // 10 readings this week: 1 very low, 1 low, 6 in range, 1 high, 1 very high.
        s.glucose = [
            reading(2.5, day: -3, hour: 9),    // very low
            reading(3.4, day: -3, hour: 12),   // low
            reading(5.0, day: -2, hour: 9), reading(6.0, day: -2, hour: 12),
            reading(7.0, day: -2, hour: 18), reading(8.0, day: -1, hour: 9),
            reading(9.0, day: -1, hour: 12), reading(4.0, day: -1, hour: 18),
            reading(11.0, day: -1, hour: 20),  // high
            reading(14.5, day: -2, hour: 21),  // very high
        ]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.inRangePct == 60)                       // 6/10
        #expect(d.bandPcts.map { Int($0.rounded()) } == [10, 10, 60, 10, 10])
        #expect(abs(d.avgMmol - 7.04) < 0.01)             // mean of the ten
        #expect(d.prevWeekInRangePct == nil)              // no previous-week data
        #expect(d.gmiPct == nil)                          // < 14 distinct days
        #expect(d.source == "cgm")
        #expect(d.days.count == 3)
        #expect(d.daysAboveTarget == 2)                   // 14.5-day and 11.0-day
    }

    @Test func perDaySpansAndTodayFlag() throws {
        var s = HealthSamples()
        s.glucose = [
            reading(4.0, day: 0, hour: 8), reading(11.2, day: 0, hour: 13, minute: 40),
            reading(6.0, day: 0, hour: 15, minute: 30),
            reading(5.0, day: -1, hour: 9), reading(9.0, day: -1, hour: 20),
        ]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.days.count == 2)
        let today = try #require(d.days.last)
        #expect(today.isToday)
        #expect(today.lo == 4.0 && today.hi == 11.2)
        #expect(today.tirPct == 67)                       // 2/3
        #expect(d.days.first?.isToday == false)
    }

    @Test func todayCurvePeakRunsAndBackInRange() throws {
        var s = HealthSamples()
        s.glucose = [
            reading(5.4, day: 0, hour: 7),
            reading(11.2, day: 0, hour: 13, minute: 40),   // the spike
            reading(8.4, day: 0, hour: 15, minute: 10),    // back in range
            reading(6.2, day: 0, hour: 15, minute: 40),
        ]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.today.count == 4)
        #expect(abs((d.today.first?.hour ?? 0) - 7.0) < 0.01)
        let peak = try #require(d.todayPeak)
        #expect(peak.mmol == 11.2)
        #expect(peak.timeText == "13:40")
        #expect(d.aboveTargetRuns == 1)
        #expect(d.backInRangeText == "15:10")
    }

    @Test func stillAboveTargetHasNoBackInRange() throws {
        var s = HealthSamples()
        s.glucose = [
            reading(6.0, day: 0, hour: 9),
            reading(11.0, day: 0, hour: 14),
        ]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.aboveTargetRuns == 1)
        #expect(d.backInRangeText == nil)
        #expect(d.todayPeak?.mmol == 11.0)
    }

    @Test func inRangePeakIsNotReported() throws {
        var s = HealthSamples()
        s.glucose = [reading(6.0, day: 0, hour: 9), reading(8.0, day: 0, hour: 12)]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.todayPeak == nil)                        // 8.0 is inside target
        #expect(d.aboveTargetRuns == 0)
    }

    @Test func singleTodayReadingDrawsNoCurve() throws {
        var s = HealthSamples()
        s.glucose = [reading(6.0, day: 0, hour: 9), reading(7.0, day: -1, hour: 9)]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.today.isEmpty)                           // <2 today ⇒ no curve
    }

    @Test func prevWeekComparisonWhenDataExists() throws {
        var s = HealthSamples()
        // This week: 4/4 in range. Previous week: 1/2 in range.
        s.glucose = [
            reading(5.0, day: 0, hour: 9), reading(6.0, day: -2, hour: 9),
            reading(7.0, day: -4, hour: 9), reading(8.0, day: -6, hour: 9),
            reading(6.0, day: -8, hour: 9), reading(12.0, day: -10, hour: 9),
        ]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.inRangePct == 100)
        #expect(d.prevWeekInRangePct == 50)
    }

    @Test func gmiNeedsFourteenDistinctDays() throws {
        var s = HealthSamples()
        // 14 distinct days at a steady 6.0 mmol/L (some inside the week window).
        for day in 0..<14 {
            s.glucose.append(reading(6.0, day: -day, hour: 9))
        }
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        // GMI = 3.31 + 0.02392 × (6.0 × 18.016) = 5.9 (1 dp)
        #expect(d.gmiPct == 5.9)

        var s13 = HealthSamples()
        for day in 0..<13 { s13.glucose.append(reading(6.0, day: -day, hour: 9)) }
        let d13 = try #require(GlucoseDetailDeriver.derive(from: s13, now: now))
        #expect(d13.gmiPct == nil)
    }

    @Test func customTargetBandIsRespected() throws {
        var s = HealthSamples()
        s.glucose = [
            reading(4.5, day: 0, hour: 8), reading(5.0, day: 0, hour: 12),
            reading(7.0, day: 0, hour: 14),
        ]
        let d = try #require(GlucoseDetailDeriver.derive(
            from: s, tirLowMmol: 4.0, tirHighMmol: 6.0, now: now))
        #expect(d.inRangePct == 67)                        // 7.0 above the 4–6 band
        #expect(d.daysAboveTarget == 1)
    }

    @Test func dominantSourceWins() throws {
        var s = HealthSamples()
        s.glucose = [
            reading(5.0, day: 0, hour: 8, source: "Dexcom"),
            reading(6.0, day: 0, hour: 12, source: "Dexcom"),
            reading(7.0, day: 0, hour: 15, source: "manual"),
        ]
        let d = try #require(GlucoseDetailDeriver.derive(from: s, now: now))
        #expect(d.source == "Dexcom")
    }
}
