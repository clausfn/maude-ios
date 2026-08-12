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
        String(localized: "Dips and rebounds like this are part of your own normal spread. Liviqa watches the trend against your own usual — not a chart of what's \u{201C}good\u{201D} for everyone else.")
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

    // MARK: Weekday labels (EN copy rail — copy EN like the rest of A7.2)

    private static func dayName(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    private static func dayInitial(_ d: Date) -> String {
        String(dayName(d).prefix(1))
    }
}
