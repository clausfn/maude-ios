import Testing
import Foundation
@testable import Liviqa

// Go-live Wave 1 made REAL (often sparse) HealthKit the default provider. These
// tests lock in that the on-device derivers never crash and return sane values
// on empty / single-point data — the inputs demo data never exercised.
struct DeriverRobustnessTests {

    // Empty samples → zeroed passport, no NaN, no crash. (Int(NaN) would trap.)
    @Test func passportFromEmptyIsZeroed() {
        let s = PassportStatsDeriver.derive(from: .empty)
        #expect(s.totalReadings == 0)
        #expect(s.daysTracked == 0)
        #expect(s.glucoseTimeInRange == 0)
        #expect(s.avgSleepHours == 0)
    }

    // A single glucose reading must not divide-by-zero into a TIR crash.
    @Test func passportFromSingleGlucoseIsSafe() {
        let g = GlucoseReading(ts: Date(), mmol: 6.0, source: "t", tier: .good, provenance: .real)
        let s = PassportStatsDeriver.derive(from: HealthSamples(glucose: [g]))
        #expect(s.glucoseTimeInRange == 100)   // one in-range reading = 100%
        #expect(s.totalReadings == 1)
    }

    // Today signals: no real data → nil (Home keeps demo seeds, honestly).
    @Test func todaySignalsNilOnEmpty() {
        #expect(TodaySignalsDeriver.derive(from: .empty) == nil)
    }

    // Today signals: a single HRV point is enough to surface real signals, and
    // missing streams render as "—" rather than crashing or faking a number.
    @Test func todaySignalsSparseIsSafe() {
        let hrv = DailyMetric(date: Date(), kind: .hrvSDNN, value: 45, source: "t", tier: .good, provenance: .real)
        let sig = TodaySignalsDeriver.derive(from: HealthSamples(hrv: [hrv]))
        #expect(sig != nil)
        #expect(sig?.inRange == "—")          // no glucose → em dash, not a fabricated %
        #expect(sig?.hrv == "45")
    }

    // Correlation grid derives from empty without crashing.
    @Test func correlationGridFromEmptyDoesNotCrash() {
        _ = CorrelationDeriver.derive(from: .empty)
        #expect(Bool(true))
    }

    // Sparkline week series: empty input → no series (no fabricated zeros).
    @Test func weekSeriesEmptyOnNoData() {
        let sig = TodaySignalsDeriver.derive(from: .empty)
        #expect(sig == nil)
    }

    // Glucose on 3 recent days → a 3-point TIR sparkline of valid percentages.
    @Test func tirWeekSeriesHasOnePointPerDayWithData() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        func g(_ daysAgo: Int, _ mmol: Double) -> GlucoseReading {
            GlucoseReading(ts: cal.date(byAdding: .day, value: -daysAgo, to: today)!.addingTimeInterval(3600),
                           mmol: mmol, source: "t", tier: .good, provenance: .real)
        }
        // day -2: in range, day -1: high (out), day 0: in range
        let s = HealthSamples(glucose: [g(2, 6.0), g(1, 12.0), g(0, 7.0)])
        let sig = TodaySignalsDeriver.derive(from: s)
        #expect(sig?.inRangeWeek.count == 3)
        #expect(sig?.inRangeWeek.allSatisfy { $0 >= 0 && $0 <= 100 } == true)
    }

    // A single day of HRV is not enough for a sparkline (≥2 points required).
    @Test func dailyWeekSeriesNeedsTwoPoints() {
        let hrv = DailyMetric(date: Date(), kind: .hrvSDNN, value: 45, source: "t", tier: .good, provenance: .real)
        let sig = TodaySignalsDeriver.derive(from: HealthSamples(hrv: [hrv]))
        #expect(sig?.hrvWeek.isEmpty == true)
    }
}
