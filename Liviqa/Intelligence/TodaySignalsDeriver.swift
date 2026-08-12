// TodaySignalsDeriver.swift — the four Home "signals vs your normal" chips,
// derived on device from local HealthSamples so the Home screen shows YOUR data
// (not the demo seeds) the moment Apple Health is connected. Pure Foundation
// (NFR-PORT-01). nil ⇒ not enough real data yet → Home falls back to seeds.
import Foundation

public nonisolated struct TodaySignals: Sendable, Equatable {
    public var sleep: String      // "6h52"
    public var inRange: String    // "61%"
    public var hrv: String        // "48"
    public var rhr: String        // "58"
    public var inRangeIsClay: Bool

    // Last-7-day micro-trends for the Home chip sparklines (oldest→today, one
    // value per day that HAS data — no fabricated zeros). Empty ⇒ no sparkline.
    //
    // A series is SHORTER than the week whenever a day is missing, so its index
    // is NOT a day number. Anything drawing these against a day axis must use
    // `slots(for:over:)` below, which places each value on its own date and
    // leaves a gap where nothing was recorded.
    public var sleepWeek: [Double]
    public var inRangeWeek: [Double]
    public var hrvWeek: [Double]
    public var rhrWeek: [Double]
    /// The day each entry of the matching series belongs to (parallel, same
    /// count, ascending). Empty on the labelled demo fixtures, which carry a
    /// full week by construction — `DaySeries.aligned` handles that case and
    /// refuses to guess for any short series.
    public var sleepWeekDates: [Date]
    public var inRangeWeekDates: [Date]
    public var hrvWeekDates: [Date]
    public var rhrWeekDates: [Date]
    /// Today's glucose readings (mmol/L, chronological) for the CGM-style day curve.
    public var glucoseToday: [Double]

    public init(sleep: String, inRange: String, hrv: String, rhr: String, inRangeIsClay: Bool,
                sleepWeek: [Double] = [], inRangeWeek: [Double] = [],
                hrvWeek: [Double] = [], rhrWeek: [Double] = [], glucoseToday: [Double] = [],
                sleepWeekDates: [Date] = [], inRangeWeekDates: [Date] = [],
                hrvWeekDates: [Date] = [], rhrWeekDates: [Date] = []) {
        self.sleep = sleep; self.inRange = inRange; self.hrv = hrv; self.rhr = rhr
        self.inRangeIsClay = inRangeIsClay
        self.sleepWeek = sleepWeek; self.inRangeWeek = inRangeWeek
        self.hrvWeek = hrvWeek; self.rhrWeek = rhrWeek
        self.sleepWeekDates = sleepWeekDates; self.inRangeWeekDates = inRangeWeekDates
        self.hrvWeekDates = hrvWeekDates; self.rhrWeekDates = rhrWeekDates
        self.glucoseToday = glucoseToday
    }

    /// The four week series, addressed as a pair so a caller can never reach for
    /// the values and forget the dates.
    public enum WeekSeries: Sendable, CaseIterable {
        case sleep, inRange, hrv, rhr
    }

    public func values(_ series: WeekSeries) -> [Double] {
        switch series {
        case .sleep:   return sleepWeek
        case .inRange: return inRangeWeek
        case .hrv:     return hrvWeek
        case .rhr:     return rhrWeek
        }
    }

    public func dates(_ series: WeekSeries) -> [Date] {
        switch series {
        case .sleep:   return sleepWeekDates
        case .inRange: return inRangeWeekDates
        case .hrv:     return hrvWeekDates
        case .rhr:     return rhrWeekDates
        }
    }

    /// One slot per day of `window`, or nil when the series carries no dates and
    /// is too short to place — in which case the caller must draw it WITHOUT day
    /// labels rather than label it wrongly.
    public func slots(for series: WeekSeries, over window: [Date]) -> [DaySlot]? {
        DaySeries.aligned(values: values(series), dates: dates(series), over: window)
    }
}

public nonisolated enum TodaySignalsDeriver {

    public static func derive(from s: HealthSamples,
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0) -> TodaySignals? {
        // Need at least one real signal, else stay on the demo seeds.
        guard !s.hrv.isEmpty || !s.sleep.isEmpty || !s.glucose.isEmpty || !s.restingHR.isEmpty
        else { return nil }

        let stats = PassportStatsDeriver.derive(from: s, tirLowMmol: tirLowMmol, tirHighMmol: tirHighMmol)

        // Sleep chip = LAST NIGHT's asleep total — the same figure the Sleep pillar
        // detail shows, and consistent with the "latest reading" semantic of the HRV/
        // RHR chips below. Previously this used the multi-night AVERAGE
        // (stats.avgSleepHours), which read ~54 min off from the detail's last-night
        // value (Home 4h12 vs detail 5h06) — the "front page doesn't match" bug. The
        // average still lives in PassportStats where an average is actually intended.
        let lastNightHours = SleepDeriver.derive(from: s).map { Double($0.asleepMinutes) / 60.0 } ?? 0
        let sleep = lastNightHours > 0 ? formatSleep(lastNightHours) : "—"
        let tir = stats.glucoseTimeInRange
        let inRange = s.glucose.isEmpty ? "—" : "\(tir)%"
        let hrv = latest(s.hrv).map { String(Int($0.rounded())) } ?? "—"
        let rhr = latest(s.restingHR).map { String(Int($0.rounded())) } ?? "—"

        let sleepW = sleepWeekSeries(s)
        let tirW   = tirWeekSeries(s, lo: tirLowMmol, hi: tirHighMmol)
        let hrvW   = dailyWeekSeries(s.hrv)
        let rhrW   = dailyWeekSeries(s.restingHR)

        return TodaySignals(
            sleep: sleep, inRange: inRange, hrv: hrv, rhr: rhr,
            inRangeIsClay: !s.glucose.isEmpty && tir < 70,
            sleepWeek: sleepW.values,
            inRangeWeek: tirW.values,
            hrvWeek: hrvW.values,
            rhrWeek: rhrW.values,
            glucoseToday: glucoseTodaySeries(s),
            sleepWeekDates: sleepW.dates,
            inRangeWeekDates: tirW.dates,
            hrvWeekDates: hrvW.dates,
            rhrWeekDates: rhrW.dates)
    }

    /// A week series and the days it actually covers, always built together.
    private typealias WeekSeries = (values: [Double], dates: [Date])
    private static let emptyWeek: WeekSeries = ([], [])

    /// Today's glucose readings (mmol/L) in chronological order; [] if <2 today.
    private static func glucoseTodaySeries(_ s: HealthSamples) -> [Double] {
        let today = cal.startOfDay(for: Date())
        let todays = s.glucose
            .filter { cal.isDate($0.ts, inSameDayAs: today) }
            .sorted { $0.ts < $1.ts }
            .map { $0.mmol }
        return todays.count >= 2 ? todays : []
    }

    // MARK: 7-day micro-trend series (oldest→today; one value per day WITH data).

    private static let cal = Calendar(identifier: .gregorian)
    private static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
    private static func recentDays(_ count: Int = 7) -> [Date] {
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    /// Pair the last-7-day values with the days they came from, dropping days
    /// with no reading. Under 2 days ⇒ empty (nothing to trend).
    private static func weekSeries(_ valueFor: (Date) -> Double?) -> WeekSeries {
        let pairs = recentDays().compactMap { d in valueFor(d).map { (d, $0) } }
        guard pairs.count >= 2 else { return emptyWeek }
        return (pairs.map(\.1), pairs.map(\.0))
    }

    /// Daily-mean metric (HRV, resting HR) → last-7-day series, days with data only.
    private static func dailyWeekSeries(_ metrics: [DailyMetric]) -> WeekSeries {
        guard !metrics.isEmpty else { return emptyWeek }
        var byDay: [Date: Double] = [:]
        for m in metrics { byDay[cal.startOfDay(for: m.date)] = m.value }   // already daily
        return weekSeries { byDay[$0] }
    }

    /// Per-day total asleep hours over the last 7 days, days with data only.
    private static func sleepWeekSeries(_ s: HealthSamples) -> WeekSeries {
        guard !s.sleep.isEmpty else { return emptyWeek }
        // Union per night (dedupes overlapping iPhone + Watch segments), asleep
        // stages only — mirrors the SLEEP chip's nightly total.
        var byDay: [Date: [SleepReading]] = [:]
        for seg in s.sleep where asleepStages.contains(seg.stage) {
            byDay[cal.startOfDay(for: seg.date), default: []].append(seg)
        }
        return weekSeries { day in
            byDay[day].map { SleepReading.mergedAsleepHours($0, asleep: asleepStages) }
        }
    }

    /// Per-day time-in-range % over the last 7 days, days with glucose only.
    private static func tirWeekSeries(_ s: HealthSamples, lo: Double, hi: Double) -> WeekSeries {
        guard !s.glucose.isEmpty else { return emptyWeek }
        let low = min(lo, hi), high = max(lo, hi)
        var total: [Date: Int] = [:], inR: [Date: Int] = [:]
        for g in s.glucose {
            let d = cal.startOfDay(for: g.ts)
            total[d, default: 0] += 1
            if g.mmol >= low && g.mmol <= high { inR[d, default: 0] += 1 }
        }
        return weekSeries { d in
            guard let t = total[d], t > 0 else { return nil }
            return Double(inR[d] ?? 0) / Double(t) * 100
        }
    }

    /// Most recent value in a daily series.
    private static func latest(_ m: [DailyMetric]) -> Double? {
        m.max(by: { $0.date < $1.date })?.value
    }

    private static func formatSleep(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int(((hours - Double(h)) * 60).rounded())
        return m == 60 ? "\(h + 1)h00" : "\(h)h\(String(format: "%02d", m))"
    }
}
