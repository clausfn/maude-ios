// HRVLearnDeriver.swift — A7.2 Area ⑨: the aggregation behind the two-tier HRV
// knowledge screen (Learn tier) and the assistant's explain-a-drop template.
// Derived on device from the same daily HealthKit SDNN stream that feeds
// TodaySignals.hrvWeek. Pure Foundation (NFR-PORT-01).
//
// HONESTY RAILS (T1):
//  · The window is UP TO 60 days of the user's OWN daily values — `windowDays`
//    reports the days actually used, and every rendered label must carry that
//    real figure (never a hardcoded "60-day" claim over thinner data).
//  · ≥5 distinct days are required before anything is claimed (same threshold
//    as BaselineDeriver) — below that the deriver returns nil and the surfaces
//    keep their honest still-learning framing.
//  · Apple's HRV samples are spot readings aggregated to a DAILY AVERAGE at
//    ingestion (HealthKitService.readDaily). No night-window ("measured
//    00:30–05:00") is derivable from that stream, so none is ever claimed.
//  · No life context ("a busy day", "high-load Wednesday") — the deriver only
//    knows the numbers; the fixed templates only describe them.
import Foundation

public nonisolated struct HRVLearnDetail: Sendable, Equatable {

    /// Most recent daily HRV (ms, rounded).
    public let latestMs: Int
    /// Distinct days of the user's own data the figures below are computed from (≤60).
    public let windowDays: Int
    public let rangeLoMs: Int
    public let rangeHiMs: Int
    /// Median of the daily values over the window — the "your usual" figure.
    public let medianMs: Int
    /// Mean ±1σ "your usual" band over the window (nil when variance is ~0).
    public let usualBand: ClosedRange<Double>?

    /// Last-7-days daily values (days WITH data only), oldest → latest.
    public let weekSeries: [Double]
    /// Weekday initials aligned with `weekSeries` ("M","T",…).
    public let weekTicks: [String]
    public let weekLowMs: Int?
    /// Full weekday name of the week's lowest day ("Wednesday").
    public let weekLowDayName: String?
    /// The week's low sat below the usual band (below the median when no band).
    public let dippedBelowUsual: Bool
    /// The latest value is back at/above the lower edge of usual.
    public let recoveredToUsual: Bool

    public init(latestMs: Int, windowDays: Int, rangeLoMs: Int, rangeHiMs: Int,
                medianMs: Int, usualBand: ClosedRange<Double>?,
                weekSeries: [Double], weekTicks: [String],
                weekLowMs: Int?, weekLowDayName: String?,
                dippedBelowUsual: Bool, recoveredToUsual: Bool) {
        self.latestMs = latestMs; self.windowDays = windowDays
        self.rangeLoMs = rangeLoMs; self.rangeHiMs = rangeHiMs
        self.medianMs = medianMs; self.usualBand = usualBand
        self.weekSeries = weekSeries; self.weekTicks = weekTicks
        self.weekLowMs = weekLowMs; self.weekLowDayName = weekLowDayName
        self.dippedBelowUsual = dippedBelowUsual
        self.recoveredToUsual = recoveredToUsual
    }

    // MARK: Fixed descriptive templates (guard-checked in tests — never advice)

    /// "What it means for you" headline for the plain knowledge tier.
    public var meaningHeadline: String {
        guard let day = weekLowDayName, dippedBelowUsual else {
            return String(localized: "Yours has held close to your own usual this week.")
        }
        return recoveredToUsual
            ? String(localized: "Yours dipped on \(day), then came back up.")
            : String(localized: "Yours dipped on \(day) and hasn't come back up yet.")
    }

    /// "What it means for you" body for the plain knowledge tier.
    public var meaningBody: String {
        String(localized: "Dips and rebounds like this are part of your own normal spread. Maude watches the trend against your own usual — not a chart of what's \u{201C}good\u{201D} for everyone else.")
    }

    /// Clinical-tier week-card headline.
    public var weekHeadline: String {
        guard let day = weekLowDayName, weekLowMs != nil else {
            return String(localized: "A steady week against your own range.")
        }
        return recoveredToUsual
            ? String(localized: "Back toward the top of your range after \(day).")
            : String(localized: "Lowest on \(day); not back to your usual yet.")
    }

    /// Annotation label for the week chart's low point ("39 ms — your low, Wednesday").
    public var weekLowAnnotation: String? {
        guard let low = weekLowMs, let day = weekLowDayName else { return nil }
        return "\(low) ms — your low, \(day)"
    }
}

// MARK: - One "this week", app-wide (2026-08-13, NFR-VIZ-DAY-02)
//
// THE BUG THIS EXISTS TO KILL. `HRVLearnDetail` derives its week straight from
// the daily SDNN stream. Every OTHER HRV surface — the Home chip sparkline, the
// Insights week, the Recovery pillar — plots `TodaySignals.hrvWeek`. With real
// data those are the same seven numbers by construction (both are "one value per
// day WITH data, over the last 7 days", from the same samples), so nothing ever
// disagreed in a real session.
//
// But any path that REPLACES `todaySignals` AFTER derivation — the LV001
// goldmine fill in AppState, which swaps in composed aggregates — leaves the two
// reading DIFFERENT series over the SAME window under the SAME day letters. The
// 2026-08-13 design sweep caught exactly that: the Recovery pillar and the
// Insights week drew Friday as the week's HIGH while this page named "20 ms —
// your low, Friday" and the plain tier said "Yours dipped on Friday". Two
// screens, one signal, one week, opposite claims.
//
// The fix is to give the week ONE source. Whenever the app has a canonical week,
// every week-shaped figure the Learn page and the assistant read is re-anchored
// onto it. The up-to-60-day figures (range, median, own-usual band) keep coming
// from the long window, which no other surface draws — so nothing else moves.
public extension HRVLearnDetail {

    /// Re-anchor every WEEK-shaped figure onto the app's canonical HRV week.
    /// The long-window statistics (`windowDays`, range, median, band) are left
    /// exactly as derived — only the seven days, and the facts read off them,
    /// are replaced. Under 2 recorded days there is nothing to anchor to and the
    /// detail is returned untouched.
    func anchored(toWeek slots: [DaySlot]) -> HRVLearnDetail {
        let placed = slots.compactMap { s in s.value.map { (date: s.date, value: $0) } }
        guard placed.count >= 2 else { return self }

        let values = placed.map(\.value)
        // "Below your usual" is still measured against the LONG window's own
        // band — that is the only place a usual exists, and it is the same band
        // the copy already names.
        let usualLo = usualBand?.lowerBound ?? Double(medianMs)

        var lowMs: Int? = nil
        var lowDayName: String? = nil
        if let lowIdx = values.indices.min(by: { values[$0] < values[$1] }) {
            lowMs = Int(values[lowIdx].rounded())
            lowDayName = HRVLearnDeriver.dayName(placed[lowIdx].date)
        }

        return HRVLearnDetail(
            // The latest daily value is a week-shaped fact too: the Home chip and
            // the Recovery hero both print the last day of this same series.
            latestMs: Int((values.last ?? Double(latestMs)).rounded()),
            windowDays: windowDays,
            rangeLoMs: rangeLoMs, rangeHiMs: rangeHiMs,
            medianMs: medianMs, usualBand: usualBand,
            weekSeries: values,
            weekTicks: placed.map { HRVLearnDeriver.dayInitial($0.date) },
            weekLowMs: lowMs,
            weekLowDayName: lowDayName,
            dippedBelowUsual: (values.min() ?? .infinity) < usualLo,
            recoveredToUsual: (values.last ?? 0) >= usualLo)
    }
}

public nonisolated enum HRVLearnDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    /// Same claim threshold as BaselineDeriver: below this, say nothing.
    private static let minDays = 5
    /// The design's aggregation horizon; the actual day count is always reported.
    private static let horizonDays = 60

    public static func derive(from s: HealthSamples, now: Date = Date()) -> HRVLearnDetail? {
        guard !s.hrv.isEmpty else { return nil }

        // One value per day (the stream is daily post-arbitration; keep the
        // newest per day defensively), inside the 60-day horizon.
        let today = cal.startOfDay(for: now)
        guard let horizonStart = cal.date(byAdding: .day, value: -(horizonDays - 1), to: today)
        else { return nil }
        var byDay: [Date: Double] = [:]
        for m in s.hrv.sorted(by: { $0.date < $1.date }) {
            let day = cal.startOfDay(for: m.date)
            if day >= horizonStart && day <= today { byDay[day] = m.value }
        }
        let days = byDay.keys.sorted()
        guard days.count >= minDays else { return nil }

        let values = days.map { byDay[$0]! }
        let sortedValues = values.sorted()
        let median = sortedValues.count % 2 == 1
            ? sortedValues[sortedValues.count / 2]
            : (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2
        let band = HeartDetailDeriver.band(values)

        // Last-7-days series (days with data), mirroring TodaySignals.hrvWeek.
        let weekDays = days.filter {
            (cal.dateComponents([.day], from: $0, to: today).day ?? 99) <= 6
        }
        let weekSeries = weekDays.map { byDay[$0]! }
        let weekTicks = weekDays.map { dayInitial($0) }

        var weekLowMs: Int? = nil
        var weekLowDayName: String? = nil
        if let lowIdx = weekSeries.indices.min(by: { weekSeries[$0] < weekSeries[$1] }) {
            weekLowMs = Int(weekSeries[lowIdx].rounded())
            weekLowDayName = dayName(weekDays[lowIdx])
        }

        let latest = values.last ?? median
        let usualLo = band?.lowerBound ?? median
        let dipped = weekSeries.min().map { $0 < usualLo } ?? false
        let recovered = (weekSeries.last ?? latest) >= usualLo

        return HRVLearnDetail(
            latestMs: Int(latest.rounded()),
            windowDays: days.count,
            rangeLoMs: Int((sortedValues.first ?? median).rounded()),
            rangeHiMs: Int((sortedValues.last ?? median).rounded()),
            medianMs: Int(median.rounded()),
            usualBand: band,
            weekSeries: weekSeries,
            weekTicks: weekTicks,
            weekLowMs: weekLowMs,
            weekLowDayName: weekLowDayName,
            dippedBelowUsual: dipped,
            recoveredToUsual: recovered)
    }

    // MARK: The canonical week (see the HRVLearnDetail.anchored note above)

    /// `TodaySignals.hrvWeek` placed on the last seven calendar days — the SAME
    /// `DaySeries.aligned` call the Recovery pillar makes, so the two screens can
    /// only ever draw the same seven days. nil ⇒ the app has no canonical week
    /// (no signals, or a short series carrying no dates, which cannot be placed
    /// honestly) and the deriver's own week stands.
    public static func canonicalWeek(_ signals: TodaySignals?,
                                     now: Date = Date()) -> [DaySlot]? {
        guard let signals else { return nil }
        let window = DaySeries.days(endingOn: now, count: 7)
        return DaySeries.aligned(values: signals.hrvWeek,
                                 dates: signals.hrvWeekDates,
                                 over: window)
    }

    /// The HRV detail as every surface must read it: the long window's own
    /// statistics, the week anchored to the app's canonical week. This is the
    /// only supported way to hand an `HRVLearnDetail` to a view.
    public static func reconciled(_ detail: HRVLearnDetail?,
                                  with signals: TodaySignals?,
                                  now: Date = Date()) -> HRVLearnDetail? {
        guard let detail else { return nil }
        guard let slots = canonicalWeek(signals, now: now) else { return detail }
        return detail.anchored(toWeek: slots)
    }

    // MARK: Weekday labels (EN copy rail — copy EN like the rest of A7.2)

    public static func dayName(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    public static func dayInitial(_ d: Date) -> String {
        String(dayName(d).prefix(1))
    }
}
