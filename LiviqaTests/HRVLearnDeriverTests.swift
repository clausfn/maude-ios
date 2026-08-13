// HRVLearnDeriverTests.swift — A7.2 Area ⑨: the up-to-60-day HRV aggregation
// behind the two-tier knowledge screen and the assistant's explain template.
// Pins the honesty rails: real window labels (never a hardcoded "60"), the
// ≥5-day claim threshold, and guard-clean fixed templates.
import Testing
import Foundation
@testable import Liviqa

struct HRVLearnDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    // A fixed "now" so weekday names are deterministic in expectations computed
    // the same way the deriver computes them.
    private let now = Date(timeIntervalSince1970: 1_755_000_000)   // 2026-08-12-ish

    private func metric(daysAgo: Int, _ v: Double) -> DailyMetric {
        DailyMetric(date: cal.date(byAdding: .day, value: -daysAgo,
                                   to: cal.startOfDay(for: now))!,
                    kind: .hrvSDNN, value: v, source: "watch",
                    tier: .good, provenance: .simulated)
    }

    private func samples(_ metrics: [DailyMetric]) -> HealthSamples {
        HealthSamples(hrv: metrics)
    }

    private func dayName(daysAgo: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f.string(from: cal.date(byAdding: .day, value: -daysAgo,
                                       to: cal.startOfDay(for: now))!)
    }

    // ── Claim threshold: below 5 days, say nothing. ──

    @Test func nilBelowFiveDays() {
        let s = samples((0..<4).map { metric(daysAgo: $0, 50) })
        #expect(HRVLearnDeriver.derive(from: s, now: now) == nil)
    }

    @Test func nilWithNoHRV() {
        #expect(HRVLearnDeriver.derive(from: .empty, now: now) == nil)
    }

    // ── Real window labels: the day count is what the data covers. ──

    @Test func windowDaysReportsActualCoverage() {
        // 12 days of data → "12-day" figures, never a fabricated "60".
        let s = samples((0..<12).map { metric(daysAgo: $0, 48 + Double($0 % 5)) })
        let d = HRVLearnDeriver.derive(from: s, now: now)
        #expect(d?.windowDays == 12)
    }

    @Test func windowCapsAtSixtyDaysAndExcludesOlder() {
        // 70 days of steady 50s, with an extreme outlier BEYOND the horizon —
        // it must not leak into the range.
        var metrics = (0..<70).map { metric(daysAgo: $0, 50) }
        metrics.append(metric(daysAgo: 65, 200))
        let d = HRVLearnDeriver.derive(from: samples(metrics), now: now)
        #expect(d?.windowDays == 60)
        #expect((d?.rangeHiMs ?? 999) < 200)
    }

    // ── Median / range arithmetic. ──

    @Test func medianAndRangeAreOwnFigures() {
        let values: [Double] = [44, 46, 48, 50, 52, 54, 58]   // median 50
        let s = samples(values.enumerated().map { metric(daysAgo: $0.offset, $0.element) })
        let d = HRVLearnDeriver.derive(from: s, now: now)
        #expect(d?.medianMs == 50)
        #expect(d?.rangeLoMs == 44)
        #expect(d?.rangeHiMs == 58)
    }

    // ── Week shape: low day, dip + recovery flags, real weekday names. ──

    @Test func weekLowAndRecoveryDerived() {
        // 30 steady days (51 ms) then the canvas week: dip to 39, recover to 52.
        var metrics = (7..<37).map { metric(daysAgo: $0, 51) }
        let week: [Double] = [48, 45, 39, 41, 44, 50, 52]     // oldest → today
        for (i, v) in week.enumerated() {
            metrics.append(metric(daysAgo: 6 - i, v))
        }
        let d = HRVLearnDeriver.derive(from: samples(metrics), now: now)
        #expect(d != nil)
        #expect(d?.weekSeries == week)
        #expect(d?.weekLowMs == 39)
        #expect(d?.weekLowDayName == dayName(daysAgo: 4))     // the 39-ms day
        #expect(d?.dippedBelowUsual == true)
        #expect(d?.recoveredToUsual == true)
    }

    @Test func steadyWeekClaimsNoDip() {
        let metrics = (0..<30).map { metric(daysAgo: $0, 50 + Double($0 % 2)) }
        let d = HRVLearnDeriver.derive(from: samples(metrics), now: now)
        #expect(d?.dippedBelowUsual == false)
        #expect(d?.meaningHeadline.contains("held close") == true)
    }

    // ── ONE "this week", app-wide (NFR-VIZ-DAY-02). ──
    //
    // The 2026-08-13 design sweep caught the Recovery pillar and the Insights
    // week drawing Friday as the week's HIGH while this page named "20 ms — your
    // low, Friday". Both draw the last seven days; only their SOURCE differed.
    // These tests fail the moment the two can disagree again.

    /// The app's canonical HRV week, as every other surface plots it.
    private func signals(_ week: [Double], dates: [Date] = []) -> TodaySignals {
        TodaySignals(sleep: "7h10", inRange: "88%",
                     hrv: String(Int((week.last ?? 0).rounded())), rhr: "70",
                     inRangeIsClay: false, hrvWeek: week, hrvWeekDates: dates)
    }

    /// A 60-day stream whose OWN last-7-days low sits on `lowDaysAgo` — i.e. the
    /// raw stream deliberately disagrees with the canonical week handed in.
    private func streamWithLow(on lowDaysAgo: Int) -> HealthSamples {
        var metrics = (7..<37).map { metric(daysAgo: $0, 27) }
        for d in 0...6 { metrics.append(metric(daysAgo: d, d == lowDaysAgo ? 20 : 26)) }
        return samples(metrics)
    }

    /// The day the canonical week's minimum actually falls on, computed the way
    /// a reader computes it: find the lowest value, read its column's date.
    private func lowDayOfCanonicalWeek(_ week: [Double]) -> String {
        let slots = DaySeries.aligned(values: week, dates: [],
                                      over: DaySeries.days(endingOn: now, count: 7))!
        let placed = slots.compactMap { s in s.value.map { (s.date, $0) } }
        let lowIdx = placed.indices.min(by: { placed[$0].1 < placed[$1].1 })!
        return HRVLearnDeriver.dayName(placed[lowIdx].0)
    }

    @Test func namedExtremeMatchesTheCanonicalWeek() {
        // Every shape here puts the low on a different day of the week, and the
        // raw stream always disagrees (its own low is 6 days ago).
        let weeks: [[Double]] = [
            [31, 28, 27, 23, 23, 29, 27],   // the LV001 goldmine week
            [20, 26, 23, 26, 25, 21, 25],
            [44, 45, 46, 49, 50, 51, 39],   // low on the latest day
            [39, 44, 45, 46, 49, 50, 51],   // low on the oldest day
        ]
        for week in weeks {
            let d = HRVLearnDeriver.reconciled(
                HRVLearnDeriver.derive(from: streamWithLow(on: 6), now: now),
                with: signals(week), now: now)
            #expect(d != nil)
            // The page draws the canonical seven numbers, not its own.
            #expect(d?.weekSeries == week)
            // …and names the day that series' extreme actually falls on.
            #expect(d?.weekLowDayName == lowDayOfCanonicalWeek(week),
                    "learn page named \(d?.weekLowDayName ?? "nil") for \(week)")
            #expect(d?.weekLowMs == Int((week.min() ?? 0).rounded()))
            // The hero value is the last day of that same week — the figure the
            // Home chip and the Recovery hero print.
            #expect(d?.latestMs == Int((week.last ?? 0).rounded()))
        }
    }

    @Test func reconciliationActuallyMovesTheNamedDay() {
        // Guards the guard: without reconciliation these two DO disagree, which
        // is exactly the shipped bug. If this ever stops differing, the fixture
        // has gone stale and the test above proves nothing.
        let week: [Double] = [31, 28, 27, 23, 23, 29, 27]
        let raw = HRVLearnDeriver.derive(from: streamWithLow(on: 6), now: now)
        let fixed = HRVLearnDeriver.reconciled(raw, with: signals(week), now: now)
        #expect(raw?.weekLowDayName == dayName(daysAgo: 6))
        #expect(fixed?.weekLowDayName == dayName(daysAgo: 3))
        #expect(raw?.weekLowDayName != fixed?.weekLowDayName)
        // The plain tier's sentence names the reconciled day too.
        if fixed?.dippedBelowUsual == true {
            #expect(fixed?.meaningHeadline.contains(dayName(daysAgo: 3)) == true)
        }
    }

    @Test func datedCanonicalWeekPlacesEachValueOnItsOwnDay() {
        // A gapped week: Wednesday-equivalent missing. Values must stay on their
        // own dates, and the low must be named from the date it was recorded on.
        let days = [6, 5, 4, 2, 1, 0].map {
            cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: now))!
        }
        let values: [Double] = [30, 29, 21, 28, 30, 27]
        let d = HRVLearnDeriver.reconciled(
            HRVLearnDeriver.derive(from: streamWithLow(on: 0), now: now),
            with: signals(values, dates: days), now: now)
        #expect(d?.weekSeries == values)
        #expect(d?.weekLowMs == 21)
        #expect(d?.weekLowDayName == dayName(daysAgo: 4))
        #expect(d?.latestMs == 27)
    }

    @Test func noCanonicalWeekLeavesTheDerivedWeekAlone() {
        // Nothing to anchor to ⇒ the deriver's own week stands (never blanked).
        let raw = HRVLearnDeriver.derive(from: streamWithLow(on: 2), now: now)
        #expect(HRVLearnDeriver.reconciled(raw, with: nil, now: now) == raw)
        // A short, undated series cannot be placed on a day axis — same rule.
        #expect(HRVLearnDeriver.reconciled(raw, with: signals([27, 26, 25]), now: now) == raw)
    }

    // ── Fixed templates stay descriptive (guard-clean; FR-NDG-06 discipline). ──

    @Test func meaningTemplatesSurviveTheChatGuard() {
        var metrics = (7..<37).map { metric(daysAgo: $0, 51) }
        for (i, v) in [48.0, 45, 39, 41, 44, 50, 52].enumerated() {
            metrics.append(metric(daysAgo: 6 - i, v))
        }
        let d = HRVLearnDeriver.derive(from: samples(metrics), now: now)!
        for text in [d.meaningHeadline, d.meaningBody, d.weekHeadline] {
            #expect(ChatGuard.sanitizeOutput(text) == text,
                    "learn-tier template tripped the guard: \(text)")
        }
    }
}
