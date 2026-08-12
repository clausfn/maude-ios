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
    public var sleepWeek: [Double]
    public var inRangeWeek: [Double]
    public var hrvWeek: [Double]
    public var rhrWeek: [Double]
    /// Today's glucose readings (mmol/L, chronological) for the CGM-style day curve.
    public var glucoseToday: [Double]

    public init(sleep: String, inRange: String, hrv: String, rhr: String, inRangeIsClay: Bool,
                sleepWeek: [Double] = [], inRangeWeek: [Double] = [],
                hrvWeek: [Double] = [], rhrWeek: [Double] = [], glucoseToday: [Double] = []) {
        self.sleep = sleep; self.inRange = inRange; self.hrv = hrv; self.rhr = rhr
        self.inRangeIsClay = inRangeIsClay
        self.sleepWeek = sleepWeek; self.inRangeWeek = inRangeWeek
        self.hrvWeek = hrvWeek; self.rhrWeek = rhrWeek
        self.glucoseToday = glucoseToday
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

        return TodaySignals(
            sleep: sleep, inRange: inRange, hrv: hrv, rhr: rhr,
            inRangeIsClay: !s.glucose.isEmpty && tir < 70,
            sleepWeek: sleepWeekSeries(s),
            inRangeWeek: tirWeekSeries(s, lo: tirLowMmol, hi: tirHighMmol),
            hrvWeek: dailyWeekSeries(s.hrv),
            rhrWeek: dailyWeekSeries(s.restingHR),
            glucoseToday: glucoseTodaySeries(s))
    }

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

    /// Daily-mean metric (HRV, resting HR) → last-7-day series, days with data only.
    private static func dailyWeekSeries(_ metrics: [DailyMetric]) -> [Double] {
        guard !metrics.isEmpty else { return [] }
        var byDay: [Date: Double] = [:]
        for m in metrics { byDay[cal.startOfDay(for: m.date)] = m.value }   // already daily
        let series = recentDays().compactMap { byDay[$0] }
        return series.count >= 2 ? series : []
    }

    /// Per-day total asleep hours over the last 7 days, days with data only.
    private static func sleepWeekSeries(_ s: HealthSamples) -> [Double] {
        guard !s.sleep.isEmpty else { return [] }
        // Union per night (dedupes overlapping iPhone + Watch segments), asleep
        // stages only — mirrors the SLEEP chip's nightly total.
        var byDay: [Date: [SleepReading]] = [:]
        for seg in s.sleep where asleepStages.contains(seg.stage) {
            byDay[cal.startOfDay(for: seg.date), default: []].append(seg)
        }
        let series = recentDays().compactMap { day in
            byDay[day].map { SleepReading.mergedAsleepHours($0, asleep: asleepStages) }
        }
        return series.count >= 2 ? series : []
    }

    /// Per-day time-in-range % over the last 7 days, days with glucose only.
    private static func tirWeekSeries(_ s: HealthSamples, lo: Double, hi: Double) -> [Double] {
        guard !s.glucose.isEmpty else { return [] }
        let low = min(lo, hi), high = max(lo, hi)
        var total: [Date: Int] = [:], inR: [Date: Int] = [:]
        for g in s.glucose {
            let d = cal.startOfDay(for: g.ts)
            total[d, default: 0] += 1
            if g.mmol >= low && g.mmol <= high { inR[d, default: 0] += 1 }
        }
        let series = recentDays().compactMap { d -> Double? in
            guard let t = total[d], t > 0 else { return nil }
            return Double(inR[d] ?? 0) / Double(t) * 100
        }
        return series.count >= 2 ? series : []
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
