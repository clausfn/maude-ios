// GlucoseDetailDeriver.swift — everything the Glucose metric-detail screen (A7.2
// Area ③, the app's ONLY clinical-red surface) shows, derived on device from local
// `HealthSamples`. Canonical unit is mmol/L throughout (OD-07); GMI is the HbA1c
// headline. Pure Foundation — no SwiftData / SwiftUI / HealthKit (NFR-PORT-01) —
// so it is unit-testable in isolation and portable to Android.
//
// NUMBERS ONLY: this type carries no sentences. The view maps these figures onto
// fixed descriptive templates ("In range N% of the week…") — nothing generated,
// nothing prescriptive, no dosing/insulin output path (FR-REG-04).
//
// nil ⇒ no glucose readings in the last 7 days → the screen falls back to its
// clearly-demo seeds (demo mode) or an honest empty state (real-data mode).
import Foundation

public nonisolated struct GlucoseWeekDetail: Sendable, Equatable {

    /// One day of the week bars: the day's reading span + its own time in range.
    public struct DayRange: Sendable, Equatable {
        public let label: String        // narrow weekday letter ("M")
        public let lo: Double           // day's lowest reading (mmol/L)
        public let hi: Double           // day's highest reading (mmol/L)
        public let tirPct: Int          // % of the day's readings inside target
        public let isToday: Bool
        public init(label: String, lo: Double, hi: Double, tirPct: Int, isToday: Bool) {
            self.label = label; self.lo = lo; self.hi = hi
            self.tirPct = tirPct; self.isToday = isToday
        }
    }

    /// One of today's readings, positioned by wall-clock time.
    public struct TodayPoint: Sendable, Equatable {
        public let hour: Double         // 0…24, fraction of the day
        public let mmol: Double
        public init(hour: Double, mmol: Double) { self.hour = hour; self.mmol = mmol }
    }

    /// Today's highest reading, only reported when it sits ABOVE target.
    public struct Peak: Sendable, Equatable {
        public let mmol: Double
        public let timeText: String     // "13:40" (24h)
        public init(mmol: Double, timeText: String) { self.mmol = mmol; self.timeText = timeText }
    }

    /// % of the last-7-days readings inside the target band.
    public let inRangePct: Int
    /// Same figure for the 7 days before that; nil when that window has no readings.
    public let prevWeekInRangePct: Int?
    /// Mean of the week's readings (mmol/L).
    public let avgMmol: Double
    /// Glucose Management Indicator — the HbA1c-equivalent headline
    /// (GMI% = 3.31 + 0.02392 × mean mg/dL), computed over the FULL sample window.
    /// nil below 14 distinct days of readings (the CGM consensus minimum) — the
    /// GMI chip simply does not render then; never an estimated stand-in.
    public let gmiPct: Double?
    /// Week reading distribution across the 5 clinical bands, in % (sums ≈ 100):
    /// [very low <3.0 · low 3.0–<target · in range · high >target–13.9 · very high >13.9].
    public let bandPcts: [Double]
    /// Per-day spans, oldest → today, only days that HAVE readings.
    public let days: [DayRange]
    /// Today's readings in time order ([] when fewer than 2 — no curve then).
    public let today: [TodayPoint]
    /// Today's peak, only when above target (drives the red annotation).
    public let todayPeak: Peak?
    /// Number of separate above-target runs in today's readings.
    public let aboveTargetRuns: Int
    /// "Back in range by HH:MM" — the first in-range reading after today's LAST
    /// above-target run. nil when there was no run, or it hasn't come back yet.
    public let backInRangeText: String?
    /// Days this week whose highest reading crossed above target.
    public let daysAboveTarget: Int
    /// The dominant source name among the week's readings (e.g. the CGM app).
    public let source: String?

    public init(inRangePct: Int, prevWeekInRangePct: Int?, avgMmol: Double,
                gmiPct: Double?, bandPcts: [Double], days: [DayRange],
                today: [TodayPoint], todayPeak: Peak?, aboveTargetRuns: Int,
                backInRangeText: String?, daysAboveTarget: Int, source: String?) {
        self.inRangePct = inRangePct; self.prevWeekInRangePct = prevWeekInRangePct
        self.avgMmol = avgMmol; self.gmiPct = gmiPct; self.bandPcts = bandPcts
        self.days = days; self.today = today; self.todayPeak = todayPeak
        self.aboveTargetRuns = aboveTargetRuns; self.backInRangeText = backInRangeText
        self.daysAboveTarget = daysAboveTarget; self.source = source
    }
}

public nonisolated enum GlucoseDetailDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    /// GMI needs at least this many distinct days of readings (CGM consensus).
    private static let gmiMinDays = 14
    /// mmol/L → mg/dL conversion factor for the GMI formula.
    private static let mgdlPerMmol = 18.016

    public static func derive(from s: HealthSamples,
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0,
                              now: Date = Date()) -> GlucoseWeekDetail? {
        guard !s.glucose.isEmpty else { return nil }
        let lo = min(tirLowMmol, tirHighMmol)
        let hi = max(tirLowMmol, tirHighMmol)
        let today = cal.startOfDay(for: now)
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today),
              let prevStart = cal.date(byAdding: .day, value: -13, to: today)
        else { return nil }

        let week = s.glucose.filter { $0.ts >= weekStart && $0.ts <= now }.sorted { $0.ts < $1.ts }
        guard !week.isEmpty else { return nil }

        let inRange: (Double) -> Bool = { $0 >= lo && $0 <= hi }
        let pct: ([GlucoseReading]) -> Int = { r in
            r.isEmpty ? 0 : Int((Double(r.filter { inRange($0.mmol) }.count) / Double(r.count) * 100).rounded())
        }

        // Whole-week TIR + the 5-band clinical distribution.
        let inRangePct = pct(week)
        let n = Double(week.count)

        // Counted into named constants rather than one array literal of five
        // closures with a trailing `.map`. That form made the Swift type-checker
        // exceed its budget ("unable to type-check this expression in reasonable
        // time") — it has to solve the literal as [Int] from the map closure while
        // the outer annotation says [Double], across five closures at once.
        // Thresholds and ordering are unchanged: L2 hypo · L1 hypo · target ·
        // L1 hyper · L2 hyper, matching the TIR ramp in Theme.swift.
        let countVeryLow  = week.filter { $0.mmol < 3.0 }.count
        let countLow      = week.filter { $0.mmol >= 3.0 && $0.mmol < lo }.count
        let countTarget   = week.filter { inRange($0.mmol) }.count
        let countHigh     = week.filter { $0.mmol > hi && $0.mmol <= 13.9 }.count
        let countVeryHigh = week.filter { $0.mmol > 13.9 }.count
        let bandCounts: [Int] = [countVeryLow, countLow, countTarget, countHigh, countVeryHigh]
        let bandPcts: [Double] = bandCounts.map { Double($0) / n * 100 }

        // Previous week, for the honest "vs last week" comparison.
        let prev = s.glucose.filter { $0.ts >= prevStart && $0.ts < weekStart }
        let prevWeekInRangePct = prev.isEmpty ? nil : pct(prev)

        let avgMmol = week.map(\.mmol).reduce(0, +) / n

        // GMI over the full window — only with enough distinct days to be honest.
        let allDays = Set(s.glucose.map { cal.startOfDay(for: $0.ts) })
        var gmiPct: Double? = nil
        if allDays.count >= gmiMinDays {
            let meanAll = s.glucose.map(\.mmol).reduce(0, +) / Double(s.glucose.count)
            gmiPct = ((3.31 + 0.02392 * meanAll * mgdlPerMmol) * 10).rounded() / 10
        }

        // Per-day spans (only days with readings), oldest → today.
        let symbols = cal.veryShortWeekdaySymbols
        let byDay = Dictionary(grouping: week) { cal.startOfDay(for: $0.ts) }
        let days: [GlucoseWeekDetail.DayRange] = byDay.keys.sorted().compactMap { day in
            guard let readings = byDay[day], !readings.isEmpty else { return nil }
            let values = readings.map(\.mmol)
            let weekday = cal.component(.weekday, from: day)   // 1…7
            return GlucoseWeekDetail.DayRange(
                label: symbols[(weekday - 1) % symbols.count],
                lo: values.min() ?? 0, hi: values.max() ?? 0,
                tirPct: pct(readings),
                isToday: day == today)
        }
        let daysAboveTarget = days.filter { $0.hi > hi }.count

        // Today's curve points + the above-target story.
        let todays = week.filter { cal.isDate($0.ts, inSameDayAs: today) }
        let todayPoints: [GlucoseWeekDetail.TodayPoint] = todays.count >= 2 ? todays.map {
            let c = cal.dateComponents([.hour, .minute, .second], from: $0.ts)
            let hour = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
            return GlucoseWeekDetail.TodayPoint(hour: hour, mmol: $0.mmol)
        } : []

        var peak: GlucoseWeekDetail.Peak? = nil
        var runs = 0
        var backText: String? = nil
        if !todayPoints.isEmpty, let maxReading = todays.max(by: { $0.mmol < $1.mmol }) {
            if maxReading.mmol > hi {
                peak = GlucoseWeekDetail.Peak(mmol: maxReading.mmol,
                                              timeText: timeText(maxReading.ts))
            }
            var above = false
            for r in todays {
                if r.mmol > hi { if !above { runs += 1; above = true } }
                else { above = false }
            }
            // After the LAST above-target reading, the first back-in-range reading.
            if let lastAbove = todays.lastIndex(where: { $0.mmol > hi }),
               lastAbove < todays.count - 1,
               let back = todays[(lastAbove + 1)...].first(where: { inRange($0.mmol) }) {
                backText = timeText(back.ts)
            }
        }

        // Dominant source among the week's readings (for the honest source line).
        let source = Dictionary(grouping: week, by: \.source)
            .max { $0.value.count < $1.value.count }?.key

        return GlucoseWeekDetail(
            inRangePct: inRangePct,
            prevWeekInRangePct: prevWeekInRangePct,
            avgMmol: avgMmol,
            gmiPct: gmiPct,
            bandPcts: bandPcts,
            days: days,
            today: todayPoints,
            todayPeak: peak,
            aboveTargetRuns: runs,
            backInRangeText: backText,
            daysAboveTarget: daysAboveTarget,
            source: source)
    }

    /// "13:40" — fixed 24h, deterministic across locales (matches app copy).
    private static func timeText(_ d: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
