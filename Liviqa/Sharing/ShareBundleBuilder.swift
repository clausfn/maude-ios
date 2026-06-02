// ShareBundleBuilder.swift — reduce on-device samples to a scoped, derived bundle.
//
// Every metric is collapsed to ONE value per day (mean for rates, sum for
// counts/minutes). Raw timestamps, meal context, source, tier, and provenance
// are dropped here — they never reach the bundle. Output is filtered to the
// consent grant's scopes (deny-by-default via ShareScope).
import Foundation

public enum ShareBundleBuilder {

    /// Build a scoped daily-aggregate bundle for `grant` over [start, end].
    /// Internal (not public): `WalletGrant` is an app-module type.
    static func build(from samples: HealthSamples,
                      grant: WalletGrant,
                      rangeStart: Date,
                      rangeEnd: Date,
                      calendar: Calendar = .current,
                      now: Date = Date()) -> ShareBundle {
        let allowed = ShareScope.metrics(for: grant.scopeKeys)
        var out: [DailySummary] = []

        if allowed.contains("hrv") {
            out += meanDaily(samples.hrv, metric: "hrv", unit: "ms", calendar: calendar)
        }
        if allowed.contains("restingHR") {
            out += meanDaily(samples.restingHR, metric: "restingHR", unit: "bpm", calendar: calendar)
        }
        if allowed.contains("steps") {
            out += sumDaily(samples.steps, metric: "steps", unit: "count", calendar: calendar)
        }
        if allowed.contains("activeEnergy") {
            out += sumDaily(samples.activeEnergy, metric: "activeEnergy", unit: "kcal", calendar: calendar)
        }
        if allowed.contains("glucose") {
            out += glucoseDaily(samples.glucose, calendar: calendar)
        }
        if allowed.contains("sleep") {
            out += sleepDaily(samples.sleep, calendar: calendar)
        }
        if allowed.contains("workouts") {
            out += workoutDaily(samples.workouts, calendar: calendar)
        }

        out.sort { $0.date != $1.date ? $0.date < $1.date : $0.metric < $1.metric }

        return ShareBundle(createdAt: now,
                           scopeKeys: grant.scopeKeys.sorted(),
                           rangeStart: rangeStart,
                           rangeEnd: rangeEnd,
                           summaries: out)
    }

    // MARK: - Aggregators (one row per metric per day)

    private static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    private static func meanDaily(_ metrics: [DailyMetric], metric: String,
                                  unit: String, calendar: Calendar) -> [DailySummary] {
        Dictionary(grouping: metrics) { calendar.startOfDay(for: $0.date) }
            .map { day, items in
                let mean = items.map(\.value).reduce(0, +) / Double(items.count)
                return DailySummary(date: day, metric: metric, value: round1(mean), unit: unit)
            }
    }

    private static func sumDaily(_ metrics: [DailyMetric], metric: String,
                                 unit: String, calendar: Calendar) -> [DailySummary] {
        Dictionary(grouping: metrics) { calendar.startOfDay(for: $0.date) }
            .map { day, items in
                DailySummary(date: day, metric: metric,
                             value: round1(items.map(\.value).reduce(0, +)), unit: unit)
            }
    }

    private static func glucoseDaily(_ readings: [GlucoseReading],
                                     calendar: Calendar) -> [DailySummary] {
        Dictionary(grouping: readings) { calendar.startOfDay(for: $0.ts) }
            .map { day, items in
                let mean = items.map(\.mmol).reduce(0, +) / Double(items.count)
                return DailySummary(date: day, metric: "glucose", value: round1(mean), unit: "mmol/L")
            }
    }

    private static func sleepDaily(_ readings: [SleepReading],
                                   calendar: Calendar) -> [DailySummary] {
        // Asleep time only — exclude awake / in-bed (not actual sleep).
        let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
        return Dictionary(grouping: readings) { calendar.startOfDay(for: $0.date) }
            .map { day, items in
                let hours = items.filter { asleep.contains($0.stage) }.map(\.hours).reduce(0, +)
                return DailySummary(date: day, metric: "sleep", value: round1(hours), unit: "hours")
            }
    }

    private static func workoutDaily(_ workouts: [WorkoutReading],
                                     calendar: Calendar) -> [DailySummary] {
        Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.start) }
            .map { day, items in
                DailySummary(date: day, metric: "workouts",
                             value: round1(items.map(\.durMin).reduce(0, +)), unit: "min")
            }
    }
}
