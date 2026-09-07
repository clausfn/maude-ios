// TrendsDeriver.swift — everything the Trends surface (FR-TOD-06) shows, derived
// on device from local `HealthSamples`. Week / Month / Quarter windows, each with:
//
//   · the daily time-in-range series vs the user's OWN usual band (mean ± 1σ of
//     their own daily TIR — never a clinical range; the clinical bands belong
//     exclusively to the glucose detail),
//   · cross-signal correlation observations that render ONLY past a conservative
//     evidence gate (|r| ≥ 0.4 AND two-tailed p ≤ 0.05 at N ≥ 10 paired days —
//     the same refuse-to-assert stance as the nudge evidence gate, FR-NDG-06
//     adjacent). Below the gate the surface shows an honest still-learning state;
//     the old canned narratives are gone and can never render on a real account.
//   · aggregate tiles (sleep avg · resting HR · active min/day) with deltas
//     against the PREVIOUS window of equal length — honest "—" when either
//     window is too thin.
//
// Also derives the Today-feed period comparison (InsightCompare: this 30 days of
// sleep vs the 30 before) and the 30-day HRV series the evening month-trend card
// needs (FR-TOD-05's named deriver extension).
//
// Every daily series leaves here with its DATES attached (`tirDailyDates`,
// `hrvDailyDates`, plus `windowStart`/`windowEnd`). A series holds one entry per
// day that HAS data, so its length says nothing about which days it covers —
// charts must place it with `tirSlots` / `hrvSlots` (see DaySeries.swift) or
// they will label a gapped week against the wrong days.
//
// NUMBERS + FIXED TEMPLATES ONLY: body sentences are assembled from a small fixed
// set of descriptive templates filled with derived figures — nothing generated,
// nothing prescriptive, no diagnosis framing (guard-checked in tests).
// Pure Foundation — no SwiftData / SwiftUI / HealthKit (NFR-PORT-01).
// Glucose canonical mmol/L (OD-07).
import Foundation

/// One cross-signal observation that passed the evidence gate.
public nonisolated struct TrendCorrelation: Sendable, Equatable {
    public let pairTitle: String     // "Sleep ↔ glucose in range"
    public let strong: Bool          // STRONG (|r| ≥ 0.6) vs MODERATE
    public let r: Double             // Pearson r (signed)
    public let pText: String         // "≤0.05" / "≤0.01" (conservative table gate)
    public let n: Int                // paired days
    public let body: String          // fixed descriptive template, derived figures

    public init(pairTitle: String, strong: Bool, r: Double, pText: String,
                n: Int, body: String) {
        self.pairTitle = pairTitle; self.strong = strong; self.r = r
        self.pText = pText; self.n = n; self.body = body
    }
}

/// One derivation window (7 / 30 / 90 days back from today, inclusive).
public nonisolated struct TrendsRange: Sendable, Equatable {
    public let windowDays: Int
    /// Distinct days inside the window with ANY sample — the honesty figure
    /// ("based on N days"), important when the store holds less than a quarter.
    public let daysCovered: Int

    /// The window's own calendar bounds (start of day, inclusive). Every chart
    /// axis on this surface derives from these two dates rather than from the
    /// LENGTH of a series — a series only covers the days that carry data.
    public let windowStart: Date
    public let windowEnd: Date

    // Daily TIR trend vs the user's own usual band.
    public let tirDaily: [Double]           // one per day WITH glucose, oldest→today
    /// The day each `tirDaily` entry belongs to — parallel, same count, ascending.
    /// Without this a gapped week silently re-labels every value (see DaySeries).
    public let tirDailyDates: [Date]
    /// "14 JUL" — the first charted day, for prose that names the span. The
    /// CHART does not read this: it labels its axis from `tirSlots`' own dates,
    /// so there is exactly one source of truth for where the bars start.
    public let tirStartLabel: String
    public let tirPeriodPct: Int            // aggregate TIR over the window
    public let tirTodayPct: Int?            // today's own TIR, when today has glucose
    public let tirBandLo: Double?           // "your usual" band (mean ± 1σ of daily TIR)
    public let tirBandHi: Double?

    /// Observations past the gate ONLY — may well be empty (honest state).
    public let correlations: [TrendCorrelation]

    // Aggregate tiles, current window vs the previous window of equal length.
    public let sleepAvgHours: Double?
    public let sleepDeltaMin: Int?
    public let rhrAvg: Int?
    public let rhrDeltaBpm: Int?
    public let activeMinPerDay: Int?
    public let activeDeltaMin: Int?

    /// Daily HRV series over the window (evening month-trend card, FR-TOD-05).
    public let hrvDaily: [Double]
    /// The day each `hrvDaily` entry belongs to — parallel, same count, ascending.
    public let hrvDailyDates: [Date]

    public init(windowDays: Int, daysCovered: Int,
                windowStart: Date, windowEnd: Date,
                tirDaily: [Double], tirDailyDates: [Date],
                tirStartLabel: String, tirPeriodPct: Int, tirTodayPct: Int?,
                tirBandLo: Double?, tirBandHi: Double?,
                correlations: [TrendCorrelation],
                sleepAvgHours: Double?, sleepDeltaMin: Int?,
                rhrAvg: Int?, rhrDeltaBpm: Int?,
                activeMinPerDay: Int?, activeDeltaMin: Int?,
                hrvDaily: [Double], hrvDailyDates: [Date]) {
        self.windowDays = windowDays; self.daysCovered = daysCovered
        self.windowStart = windowStart; self.windowEnd = windowEnd
        self.tirDaily = tirDaily; self.tirDailyDates = tirDailyDates
        self.tirStartLabel = tirStartLabel
        self.tirPeriodPct = tirPeriodPct; self.tirTodayPct = tirTodayPct
        self.tirBandLo = tirBandLo; self.tirBandHi = tirBandHi
        self.correlations = correlations
        self.sleepAvgHours = sleepAvgHours; self.sleepDeltaMin = sleepDeltaMin
        self.rhrAvg = rhrAvg; self.rhrDeltaBpm = rhrDeltaBpm
        self.activeMinPerDay = activeMinPerDay; self.activeDeltaMin = activeDeltaMin
        self.hrvDaily = hrvDaily; self.hrvDailyDates = hrvDailyDates
    }

    // MARK: - Day-axis projections (the only thing a chart should draw)

    /// The TIR bars, one slot per calendar day from the FIRST charted day
    /// through the end of the window. Days with no glucose come back `nil` and
    /// are drawn as a gap — the axis stays honest ("14 JUL → TODAY") because the
    /// span is calendar days, not "number of values I happen to have".
    public var tirSlots: [DaySlot] {
        guard let first = tirDailyDates.min() else { return [] }
        let window = DaySeries.days(from: first, through: windowEnd)
        return DaySeries.slots(values: tirDaily, dates: tirDailyDates, over: window)
    }

    /// The HRV series across the WHOLE window — the evening month-trend card
    /// labels its axis "29 days ago → today", so it must draw 30 slots even
    /// when only some of them carry a reading.
    public var hrvSlots: [DaySlot] {
        let window = DaySeries.days(from: windowStart, through: windowEnd)
        return DaySeries.slots(values: hrvDaily, dates: hrvDailyDates, over: window)
    }
}

/// The Today-feed InsightCompare figures: sleep this 30 days vs the 30 before.
public nonisolated struct TrendsPeriodCompare: Sendable, Equatable {
    public let sentence: String        // fixed template, e.g. "You're sleeping 22 minutes more than you did in June."
    public let currentLabel: String    // "JULY" (midpoint month of the window)
    public let currentText: String     // "7h 10m"
    public let currentHours: Double
    public let previousLabel: String
    public let previousText: String
    public let previousHours: Double

    public init(sentence: String, currentLabel: String, currentText: String,
                currentHours: Double, previousLabel: String, previousText: String,
                previousHours: Double) {
        self.sentence = sentence
        self.currentLabel = currentLabel; self.currentText = currentText
        self.currentHours = currentHours
        self.previousLabel = previousLabel; self.previousText = previousText
        self.previousHours = previousHours
    }
}

public nonisolated struct TrendsSummary: Sendable, Equatable {
    public let week: TrendsRange
    public let month: TrendsRange
    public let quarter: TrendsRange
    public let compare: TrendsPeriodCompare?

    public init(week: TrendsRange, month: TrendsRange, quarter: TrendsRange,
                compare: TrendsPeriodCompare?) {
        self.week = week; self.month = month; self.quarter = quarter
        self.compare = compare
    }
}

public nonisolated enum TrendsDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    private static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    /// nil ⇒ no samples at all → the Trends screen shows its honest empty state.
    public static func derive(from s: HealthSamples,
                              now: Date = Date(),
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0) -> TrendsSummary? {
        guard !s.isEmpty else { return nil }
        let week    = range(s, days: 7,  now: now, lo: tirLowMmol, hi: tirHighMmol)
        let month   = range(s, days: 30, now: now, lo: tirLowMmol, hi: tirHighMmol)
        let quarter = range(s, days: 90, now: now, lo: tirLowMmol, hi: tirHighMmol)
        return TrendsSummary(week: week, month: month, quarter: quarter,
                             compare: periodCompare(s, now: now))
    }

    // MARK: - One window

    private static func range(_ s: HealthSamples, days: Int, now: Date,
                              lo: Double, hi: Double) -> TrendsRange {
        let today = cal.startOfDay(for: now)
        let windowDays = (0..<days).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
        let prevDays = (days..<2 * days).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }

        // Daily series inside the window.
        let tirByDay   = dailyTIR(s, lo: lo, hi: hi)
        let sleepByDay = dailySleep(s)
        let hrvByDay   = dailyMean(s.hrv)
        let rhrByDay   = dailyMean(s.restingHR)
        let kcalByDay  = dailyMean(s.activeEnergy)
        let workoutMinByDay = dailyWorkoutMinutes(s)

        let tirSeries = windowDays.compactMap { d in tirByDay[d].map { (d, $0) } }
        let tirDaily = tirSeries.map(\.1)
        let tirDates = tirSeries.map(\.0)
        // Same treatment for HRV: value and day travel together, so the evening
        // month-trend card can put each reading on its own date.
        let hrvSeries = windowDays.compactMap { d in hrvByDay[d].map { (d, $0) } }

        // Aggregate TIR over the window (reading-weighted, matching the chips).
        let (inCount, totalCount) = tirCounts(s, days: windowDays, lo: lo, hi: hi)
        let periodPct = totalCount > 0
            ? Int((Double(inCount) / Double(totalCount) * 100).rounded()) : 0

        // "Your usual" — mean ± 1σ of the user's OWN daily TIR (≥5 days, non-flat).
        var bandLo: Double? = nil, bandHi: Double? = nil
        if tirDaily.count >= 5 {
            let mean = tirDaily.reduce(0, +) / Double(tirDaily.count)
            let sd = (tirDaily.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
                      / Double(tirDaily.count)).squareRoot()
            if sd > 0 {
                bandLo = max(0, mean - sd)
                bandHi = min(100, mean + sd)
            }
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_DK")
        fmt.dateFormat = "d MMM"
        let startLabel = tirSeries.first.map { fmt.string(from: $0.0).uppercased() } ?? ""
        let todayPct = tirSeries.last.flatMap { $0.0 == today ? Int($0.1.rounded()) : nil }

        // Days covered (any stream) — the honesty figure.
        var covered = Set<Date>()
        for d in windowDays {
            if tirByDay[d] != nil || sleepByDay[d] != nil || hrvByDay[d] != nil
                || rhrByDay[d] != nil || kcalByDay[d] != nil || workoutMinByDay[d] != nil {
                covered.insert(d)
            }
        }

        // Aggregates + deltas vs the previous equal-length window.
        func avg(_ byDay: [Date: Double], over days: [Date], minDays: Int) -> Double? {
            let v = days.compactMap { byDay[$0] }
            return v.count >= minDays ? v.reduce(0, +) / Double(v.count) : nil
        }
        let sleepAvg  = avg(sleepByDay, over: windowDays, minDays: 3)
        let sleepPrev = avg(sleepByDay, over: prevDays, minDays: 3)
        let rhrAvg    = avg(rhrByDay, over: windowDays, minDays: 3)
        let rhrPrev   = avg(rhrByDay, over: prevDays, minDays: 3)
        // Active minutes: total workout minutes spread over the window's days.
        // Only claimed when the window actually holds tracked workouts.
        func activeMin(over days: [Date]) -> Double? {
            let mins = days.compactMap { workoutMinByDay[$0] }
            guard !mins.isEmpty else { return nil }
            return mins.reduce(0, +) / Double(days.count)
        }
        let act     = activeMin(over: windowDays)
        let actPrev = activeMin(over: prevDays)

        let correlations = gatedCorrelations(
            days: windowDays, sleep: sleepByDay, tir: tirByDay,
            hrv: hrvByDay, kcal: kcalByDay)

        return TrendsRange(
            windowDays: days,
            daysCovered: covered.count,
            windowStart: windowDays.first ?? today,
            windowEnd: windowDays.last ?? today,
            tirDaily: tirDaily,
            tirDailyDates: tirDates,
            tirStartLabel: startLabel,
            tirPeriodPct: periodPct,
            tirTodayPct: todayPct,
            tirBandLo: bandLo, tirBandHi: bandHi,
            correlations: correlations,
            sleepAvgHours: sleepAvg,
            sleepDeltaMin: zip2(sleepAvg, sleepPrev).map { Int(($0 * 60).rounded()) },
            rhrAvg: rhrAvg.map { Int($0.rounded()) },
            rhrDeltaBpm: zip2(rhrAvg, rhrPrev).map { Int($0.rounded()) },
            activeMinPerDay: act.map { Int($0.rounded()) },
            activeDeltaMin: zip2(act, actPrev).map { Int($0.rounded()) },
            hrvDaily: hrvSeries.map(\.1), hrvDailyDates: hrvSeries.map(\.0))
    }

    private static func zip2(_ a: Double?, _ b: Double?) -> Double? {
        guard let a, let b else { return nil }
        return a - b
    }

    // MARK: - Correlation observations (gate-first)

    /// Candidate pairs, computed over daily-aligned values from the user's own
    /// window. Assertion requires |r| ≥ 0.4 AND the conservative p ≤ 0.05 gate
    /// at N ≥ 10 paired days. Sentences are fixed templates + derived figures.
    private static func gatedCorrelations(days: [Date],
                                          sleep: [Date: Double],
                                          tir: [Date: Double],
                                          hrv: [Date: Double],
                                          kcal: [Date: Double]) -> [TrendCorrelation] {
        var out: [TrendCorrelation] = []

        // 1. Sleep ↔ same-day glucose in range.
        if let c = assess(days: days, x: sleep, y: tir, yNextDay: false,
                          title: String(localized: "Sleep ↔ glucose in range"),
                          template: { deltaPts, moreX in
            let d = Int(abs(deltaPts).rounded())
            let dir = (deltaPts >= 0) == moreX
            return dir
                ? String(localized: "On days you slept more than your usual, glucose stayed in range about \(d) points more of the day — in your own data.")
                : String(localized: "On days you slept more than your usual, glucose spent about \(d) points less of the day in range — in your own data.")
        }) { out.append(c) }

        // 2. Activity ↔ same-day glucose in range.
        if let c = assess(days: days, x: kcal, y: tir, yNextDay: false,
                          title: String(localized: "Activity ↔ glucose in range"),
                          template: { deltaPts, moreX in
            let d = Int(abs(deltaPts).rounded())
            let dir = (deltaPts >= 0) == moreX
            return dir
                ? String(localized: "On your more active days, glucose stayed in range about \(d) points more of the day — in your own data.")
                : String(localized: "On your more active days, glucose spent about \(d) points less of the day in range — in your own data.")
        }) { out.append(c) }

        // 3. Sleep ↔ next-morning recovery (HRV).
        if let c = assess(days: days, x: sleep, y: hrv, yNextDay: true,
                          title: String(localized: "Sleep ↔ next-morning recovery"),
                          template: { deltaMs, moreX in
            let d = Int(abs(deltaMs).rounded())
            let dir = (deltaMs >= 0) == moreX
            return dir
                ? String(localized: "Nights with more sleep than your usual lined up with higher recovery the next morning — about \(d) ms in your data.")
                : String(localized: "Nights with more sleep than your usual lined up with lower recovery the next morning — about \(d) ms in your data.")
        }) { out.append(c) }

        return out
    }

    /// Pair one daily series with another (optionally shifted to the NEXT day),
    /// gate it, and describe the observed split. nil below the gate.
    private static func assess(days: [Date], x: [Date: Double], y: [Date: Double],
                               yNextDay: Bool, title: String,
                               template: (Double, Bool) -> String) -> TrendCorrelation? {
        var xs: [Double] = [], ys: [Double] = []
        for d in days {
            let yKey = yNextDay ? cal.date(byAdding: .day, value: 1, to: d) ?? d : d
            if let xv = x[d], let yv = y[yKey] { xs.append(xv); ys.append(yv) }
        }
        let n = xs.count
        guard n >= 10, let r = pearson(xs, ys), abs(r) >= 0.4,
              let pText = pGateText(r: r, n: n) else { return nil }

        // Observed split: outcome mean on days above the predictor's median vs
        // below. Midpoint median (mean of the two central order statistics) so a
        // two-valued series still splits into both sides.
        let sortedX = xs.sorted()
        let median = (sortedX[(sortedX.count - 1) / 2] + sortedX[sortedX.count / 2]) / 2
        var above: [Double] = [], below: [Double] = []
        for (xv, yv) in zip(xs, ys) {
            if xv > median { above.append(yv) } else { below.append(yv) }
        }
        guard !above.isEmpty, !below.isEmpty else { return nil }
        let delta = above.reduce(0, +) / Double(above.count)
                  - below.reduce(0, +) / Double(below.count)

        return TrendCorrelation(pairTitle: title, strong: abs(r) >= 0.6, r: r,
                                pText: pText, n: n,
                                body: template(delta, true))
    }

    /// Pearson r; nil when either series is flat (undefined).
    static func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        let n = Double(xs.count)
        guard xs.count == ys.count, xs.count >= 3 else { return nil }
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for (x, y) in zip(xs, ys) {
            sxy += (x - mx) * (y - my)
            sxx += (x - mx) * (x - mx)
            syy += (y - my) * (y - my)
        }
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }

    /// Conservative two-tailed significance gate via a critical-t table
    /// (next-LOWER df row is used, which over-requires — never under). Returns
    /// "≤0.01" / "≤0.05", or nil below the gate. Requires N ≥ 10 (df ≥ 8).
    static func pGateText(r: Double, n: Int) -> String? {
        guard n >= 10 else { return nil }
        let df = n - 2
        let t05: [(df: Int, t: Double)] = [(8, 2.306), (10, 2.228), (12, 2.179),
                                           (15, 2.131), (20, 2.086), (30, 2.042),
                                           (60, 2.000), (120, 1.980)]
        let t01: [(df: Int, t: Double)] = [(8, 3.355), (10, 3.169), (12, 3.055),
                                           (15, 2.947), (20, 2.845), (30, 2.750),
                                           (60, 2.660), (120, 2.617)]
        func rCrit(_ table: [(df: Int, t: Double)]) -> Double {
            let t = table.last(where: { $0.df <= df })?.t ?? table[0].t
            return t / (Double(df) + t * t).squareRoot()
        }
        if abs(r) >= rCrit(t01) { return "≤0.01" }
        if abs(r) >= rCrit(t05) { return "≤0.05" }
        return nil
    }

    // MARK: - Period comparison (InsightCompare — Today feed)

    /// Sleep, trailing 30 days vs the 30 before. Only reported when both windows
    /// hold ≥5 sleep days AND the change is ≥10 minutes (otherwise the card
    /// simply doesn't render — quiet, not fabricated).
    private static func periodCompare(_ s: HealthSamples, now: Date) -> TrendsPeriodCompare? {
        let today = cal.startOfDay(for: now)
        let sleepByDay = dailySleep(s)
        func window(_ range: Range<Int>) -> (days: [Date], mid: Date) {
            let ds = range.reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
            let mid = cal.date(byAdding: .day, value: -(range.lowerBound + range.count / 2), to: today) ?? today
            return (ds, mid)
        }
        let cur = window(0..<30), prev = window(30..<60)
        let curV = cur.days.compactMap { sleepByDay[$0] }
        let prevV = prev.days.compactMap { sleepByDay[$0] }
        guard curV.count >= 5, prevV.count >= 5 else { return nil }
        let curAvg = curV.reduce(0, +) / Double(curV.count)
        let prevAvg = prevV.reduce(0, +) / Double(prevV.count)
        let deltaMin = Int(((curAvg - prevAvg) * 60).rounded())
        guard abs(deltaMin) >= 10 else { return nil }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_DK")
        fmt.dateFormat = "MMMM"
        let curLabel = fmt.string(from: cur.mid).uppercased()
        let prevLabel = fmt.string(from: prev.mid).uppercased()
        let prevName = fmt.string(from: prev.mid)

        let sentence = deltaMin > 0
            ? String(localized: "You're sleeping \(deltaMin) minutes more than you did in \(prevName).")
            : String(localized: "You're sleeping \(abs(deltaMin)) minutes less than you did in \(prevName).")

        return TrendsPeriodCompare(
            sentence: sentence,
            currentLabel: curLabel, currentText: hoursText(curAvg), currentHours: curAvg,
            previousLabel: prevLabel, previousText: hoursText(prevAvg), previousHours: prevAvg)
    }

    static func hoursText(_ hours: Double) -> String {
        var h = Int(hours)
        var m = Int(((hours - Double(h)) * 60).rounded())
        if m == 60 { h += 1; m = 0 }
        return "\(h)h \(String(format: "%02d", m))m"
    }

    // MARK: - Daily series helpers

    private static func dailyTIR(_ s: HealthSamples, lo: Double, hi: Double) -> [Date: Double] {
        guard !s.glucose.isEmpty else { return [:] }
        let low = min(lo, hi), high = max(lo, hi)
        var total: [Date: Int] = [:], inR: [Date: Int] = [:]
        for g in s.glucose {
            let d = cal.startOfDay(for: g.ts)
            total[d, default: 0] += 1
            if g.mmol >= low && g.mmol <= high { inR[d, default: 0] += 1 }
        }
        var out: [Date: Double] = [:]
        for (d, t) in total where t > 0 {
            out[d] = Double(inR[d] ?? 0) / Double(t) * 100
        }
        return out
    }

    private static func tirCounts(_ s: HealthSamples, days: [Date],
                                  lo: Double, hi: Double) -> (inRange: Int, total: Int) {
        guard let first = days.first else { return (0, 0) }
        let low = min(lo, hi), high = max(lo, hi)
        var inR = 0, total = 0
        for g in s.glucose where g.ts >= first {
            total += 1
            if g.mmol >= low && g.mmol <= high { inR += 1 }
        }
        return (inR, total)
    }

    private static func dailySleep(_ s: HealthSamples) -> [Date: Double] {
        guard !s.sleep.isEmpty else { return [:] }
        var byDay: [Date: [SleepReading]] = [:]
        for seg in s.sleep where asleepStages.contains(seg.stage) {
            byDay[cal.startOfDay(for: seg.date), default: []].append(seg)
        }
        var out: [Date: Double] = [:]
        for (d, segs) in byDay {
            out[d] = SleepReading.mergedAsleepHours(segs, asleep: asleepStages)
        }
        return out
    }

    private static func dailyMean(_ metrics: [DailyMetric]) -> [Date: Double] {
        var sums: [Date: (Double, Int)] = [:]
        for m in metrics {
            let d = cal.startOfDay(for: m.date)
            let cur = sums[d] ?? (0, 0)
            sums[d] = (cur.0 + m.value, cur.1 + 1)
        }
        return sums.mapValues { $0.0 / Double($0.1) }
    }

    private static func dailyWorkoutMinutes(_ s: HealthSamples) -> [Date: Double] {
        var out: [Date: Double] = [:]
        for w in s.workouts {
            out[cal.startOfDay(for: w.start), default: 0] += w.durMin
        }
        return out
    }
}
