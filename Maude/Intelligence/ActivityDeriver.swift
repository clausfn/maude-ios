// ActivityDeriver.swift — everything the A7.2 Activity metric-detail screen shows,
// derived on device from local `HealthSamples`. Pure Foundation (NFR-PORT-01).
//
// PERSONAL-BASELINE ONLY: the dashed "your usual" line is the mean of the user's
// OWN prior three weeks (falling back to this week's own mean when history is
// short). No population target, no 10k-steps folklore, ever (FR-NDG-06 rail).
//
// nil ⇒ no step days in the window → demo seeds (demo mode) or an honest empty
// state (real-data mode).
import Foundation

public nonisolated struct ActivityWeekDetail: Sendable, Equatable {

    /// Last-7-days series (days WITH data), oldest → today.
    /// The chart axis: one slot per day of the 7-day window, nil where nothing
    /// was recorded. Statistics below are computed over the RECORDED days only.
    public let stepsWeek: [Double?]
    public let stepsLabels: [String]
    public let kcalWeek: [Double?]
    public let kcalLabels: [String]

    /// Own usual daily steps: mean of the prior 21 days with data (≥5 needed);
    /// falls back to this week's own mean. Never a population figure.
    public let usualSteps: Double
    /// True when `usualSteps` comes from prior weeks (an honest "vs your usual"
    /// claim needs history that isn't the same week being described).
    public let usualFromHistory: Bool
    public let usualKcal: Double?

    public let weekStepsTotal: Int
    public let weekKcalTotal: Int?
    /// % difference of this week's daily mean vs `usualSteps` (only meaningful
    /// when `usualFromHistory`).
    public let pctVsUsual: Int?
    /// Days this week above the usual line.
    public let daysAboveUsual: Int
    public let longestDayName: String?     // "Sunday"
    public let longestDaySteps: Int?
    public let workoutsLogged: Int

    public init(stepsWeek: [Double?], stepsLabels: [String], kcalWeek: [Double?],
                kcalLabels: [String], usualSteps: Double, usualFromHistory: Bool,
                usualKcal: Double?, weekStepsTotal: Int, weekKcalTotal: Int?,
                pctVsUsual: Int?, daysAboveUsual: Int, longestDayName: String?,
                longestDaySteps: Int?, workoutsLogged: Int) {
        self.stepsWeek = stepsWeek; self.stepsLabels = stepsLabels
        self.kcalWeek = kcalWeek; self.kcalLabels = kcalLabels
        self.usualSteps = usualSteps; self.usualFromHistory = usualFromHistory
        self.usualKcal = usualKcal; self.weekStepsTotal = weekStepsTotal
        self.weekKcalTotal = weekKcalTotal; self.pctVsUsual = pctVsUsual
        self.daysAboveUsual = daysAboveUsual; self.longestDayName = longestDayName
        self.longestDaySteps = longestDaySteps; self.workoutsLogged = workoutsLogged
    }
}

public nonisolated enum ActivityDeriver {

    private static let cal = Calendar(identifier: .gregorian)

    public static func derive(from s: HealthSamples, now: Date = Date()) -> ActivityWeekDetail? {
        guard !s.steps.isEmpty else { return nil }
        let today = cal.startOfDay(for: now)
        let symbols = cal.veryShortWeekdaySymbols

        func series(_ metrics: [DailyMetric], daysBack from: Int, _ to: Int)
            -> [(day: Date, value: Double)] {
            var byDay: [Date: Double] = [:]
            for m in metrics { byDay[cal.startOfDay(for: m.date)] = m.value }
            return (from...to).compactMap { off in
                guard let d = cal.date(byAdding: .day, value: off, to: today),
                      let v = byDay[d] else { return nil }
                return (d, v)
            }
        }

        /// Every day of the window, in order — a day without a reading is a nil
        /// slot so the drawn axis keeps its true shape (DaySeries discipline).
        func axis(_ metrics: [DailyMetric], daysBack from: Int, _ to: Int)
            -> [(day: Date, value: Double?)] {
            var byDay: [Date: Double] = [:]
            for m in metrics { byDay[cal.startOfDay(for: m.date)] = m.value }
            return (from...to).compactMap { off in
                guard let d = cal.date(byAdding: .day, value: off, to: today) else { return nil }
                return (d, byDay[d])
            }
        }

        let stepsWeek = series(s.steps, daysBack: -6, 0)
        guard stepsWeek.count >= 2 else { return nil }
        let kcalWeek = series(s.activeEnergy, daysBack: -6, 0)
        let stepsAxis = axis(s.steps, daysBack: -6, 0)
        let kcalAxis = axis(s.activeEnergy, daysBack: -6, 0)

        // Own usual from the PRIOR three weeks (days −27…−7).
        let prior = series(s.steps, daysBack: -27, -7)
        let weekMean = stepsWeek.map(\.value).reduce(0, +) / Double(stepsWeek.count)
        let usualFromHistory = prior.count >= 5
        let usual = usualFromHistory
            ? prior.map(\.value).reduce(0, +) / Double(prior.count)
            : weekMean
        let priorKcal = series(s.activeEnergy, daysBack: -27, -7)
        // Written as statements rather than a nested ternary. The original had to
        // unify Double and Double? through two ternary levels with keypath maps on
        // both branches, and the type-checker exceeded its budget on it. Same
        // preference order: three prior weeks if there are at least 5 days, else
        // this week if there are at least 2, else nothing.
        let usualKcal: Double?
        if priorKcal.count >= 5 {
            usualKcal = priorKcal.map(\.value).reduce(0, +) / Double(priorKcal.count)
        } else if kcalWeek.count >= 2 {
            usualKcal = kcalWeek.map(\.value).reduce(0, +) / Double(kcalWeek.count)
        } else {
            usualKcal = nil
        }

        let pct: Int? = usualFromHistory && usual > 0
            ? Int(((weekMean - usual) / usual * 100).rounded()) : nil
        let longest = stepsWeek.max { $0.value < $1.value }

        func label(_ d: Date) -> String {
            symbols[(cal.component(.weekday, from: d) - 1) % symbols.count]
        }

        return ActivityWeekDetail(
            stepsWeek: stepsAxis.map(\.value),
            stepsLabels: stepsAxis.map { label($0.day) },
            kcalWeek: kcalWeek.isEmpty ? [] : kcalAxis.map(\.value),
            kcalLabels: kcalWeek.isEmpty ? [] : kcalAxis.map { label($0.day) },
            usualSteps: usual.rounded(),
            usualFromHistory: usualFromHistory,
            usualKcal: usualKcal.map { $0.rounded() },
            weekStepsTotal: Int(stepsWeek.map(\.value).reduce(0, +).rounded()),
            weekKcalTotal: kcalWeek.isEmpty ? nil
                : Int(kcalWeek.map(\.value).reduce(0, +).rounded()),
            pctVsUsual: pct,
            daysAboveUsual: stepsWeek.filter { $0.value > usual }.count,
            longestDayName: longest.map { FitnessDeriver.weekdayName($0.day) },
            longestDaySteps: longest.map { Int($0.value.rounded()) },
            workoutsLogged: s.workouts.filter {
                abs(cal.dateComponents([.day], from: cal.startOfDay(for: $0.start),
                                       to: today).day ?? 99) <= 6
            }.count)
    }
}
