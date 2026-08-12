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
