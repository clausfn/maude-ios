// MockDataProvider.swift — synthetic `timeseries_daily` demo user (default).
//
// Deterministic, seeded generator producing physiologically plausible daily
// series. Every reading is provenance = .simulated (DataModel v1 §4) at
// good/estimate tier — so it can NEVER be mistaken for clinical truth and the
// clinical-rejects-SIMULATED gate stays satisfied. Pure value output; the
// `provenance` tag is for the data layer only and is never rendered.
import Foundation

/// Tiny deterministic RNG so the demo user is identical across runs/tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed != 0 ? seed : 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public struct MockDataProvider: HealthDataProvider {
    public let kind: DataProviderKind = .mock
    private let seed: UInt64
    private let source = "Mock"

    // Default seed = "LIVIQA" ASCII bytes ⇒ a stable, deterministic demo user.
    public init(seed: UInt64 = 0x4C_49_56_49_51_41) { self.seed = seed }

    public func requestReadAuthorization() async throws { /* always available */ }

    public func fetchSamples(from start: Date, to end: Date) async throws -> HealthSamples {
        var rng = SeededGenerator(seed: seed)
        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.startOfDay(for: min(start, end))
        let endDay = cal.startOfDay(for: max(start, end))
        let days = max(0, (cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0))

        var samples = HealthSamples.empty
        // Cross-metric coherence (the same stories the nudges tell): a poor-sleep
        // night worsens the NEXT day's glucose control; a workout day raises the
        // NEXT morning's resting HR slightly. Carried across loop iterations.
        var prevNightPoor = false
        var prevDayWorkout = false
        for offset in 0...days {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let weekday = cal.component(.weekday, from: day)
            let weekend = weekday == 1 || weekday == 7

            // RHR 52–68 for the founder persona; +3–5 bpm the morning after a
            // hard session (normal training response), small weekly drift.
            let rhrBase = 72.0 + (prevDayWorkout ? 4.0 : 0.0)
            samples.restingHR.append(daily(day, .restingHR, min(82, max(64, jitter(&rng, base: rhrBase, spread: 4))), tier: .good))
            // HRV 25–55 ms (persona range) — lower after a poor night.
            let hrvBase = prevNightPoor ? 22.0 : 28.0
            samples.hrv.append(daily(day, .hrvSDNN, min(38, max(17, jitter(&rng, base: hrvBase, spread: 6))), tier: .good))
            // Steps 4–12k with a weekday/weekend rhythm (longer weekend walks).
            let stepBase = weekend ? 9800.0 : 7400.0
            samples.steps.append(daily(day, .steps, min(12_000, max(4000, jitter(&rng, base: stepBase, spread: 2200))).rounded(), tier: .estimate))
            samples.activeEnergy.append(daily(day, .activeEnergy, jitter(&rng, base: weekend ? 520 : 410, spread: 130), tier: .estimate))

            // CGM day curve (mmol/L), LADA persona: overnight 5–7, MEAL EXCURSIONS
            // at 07–09 / 12–13 / 18–20 peaking 9–13, slow decay between — never
            // white noise. A poor-sleep night raises the whole day ~+1 mmol/L and
            // amplifies excursions (insulin resistance after short sleep). Lands
            // TIR ≈ 50–75% with mean ≈ 8–10 — consistent, per ATTD consensus bands.
            let dayShift = prevNightPoor ? 1.1 : 0.0
            let excursionGain = prevNightPoor ? 1.25 : 1.0
            for halfHour in stride(from: 0, through: 47, by: 2) {   // hourly points 00–23
                let hour = Double(halfHour) / 2.0
                var mmol = 6.3 + dayShift + jitter(&rng, base: 0, spread: 0.6)
                // Meal excursions: breakfast 07:30, lunch 12:30, dinner 19:00.
                for (peak, height, width) in [(8.3, 4.9, 1.9), (13.0, 4.1, 2.0), (19.5, 5.3, 2.3)] {
                    let d = (hour - peak) / width
                    mmol += height * excursionGain * exp(-d * d)
                }
                mmol = max(3.4, min(14.5, mmol))
                let ts = cal.date(byAdding: .minute, value: Int(hour * 60), to: day) ?? day
                samples.glucose.append(GlucoseReading(
                    ts: ts, mmol: round(mmol * 10) / 10,
                    mealContext: hour == 7 ? "fasting" : nil,
                    source: source, tier: .good, provenance: .simulated))
            }

            // Staged sleep (deep / core / rem) summing to the night's total, so the
            // sleep-stages visualisation has real structure to render. Two-ish
            // genuinely short nights a week (the founder's reality, and the setup
            // for the next-day glucose story above).
            let poorNight = jitter(&rng, base: 0, spread: 1) > 0.62
            let sleepHours = poorNight ? max(5.0, jitter(&rng, base: 5.9, spread: 0.6))
                                       : max(6.5, jitter(&rng, base: 7.4, spread: 0.7))
            prevNightPoor = poorNight
            // Realistic stage ratios: Deep 10–20%, REM ~18–25%.
            let deep = sleepHours * (0.12 + jitter(&rng, base: 0.01, spread: 0.02))
            let rem  = sleepHours * (0.20 + jitter(&rng, base: 0.01, spread: 0.03))
            let core = max(0.1, sleepHours - deep - rem)
            for (stage, hrs) in [(SleepStage.deep, deep), (.core, core), (.rem, rem)] {
                samples.sleep.append(SleepReading(
                    date: day, stage: stage, hours: round(hrs * 10) / 10,
                    source: source, tier: .estimate, provenance: .simulated))
            }

            // ~Every third day, a workout (drives next-morning RHR bump above).
            prevDayWorkout = offset % 3 == 0
            if offset % 3 == 0 {
                let s = cal.date(byAdding: .hour, value: 18, to: day) ?? day
                let dur = jitter(&rng, base: 45, spread: 20)
                samples.workouts.append(WorkoutReading(
                    start: s, end: s.addingTimeInterval(dur * 60), type: "Cycling",
                    durMin: round(dur), kcal: round(dur * 9), distKm: round(dur / 3 * 10) / 10,
                    source: source, tier: .estimate, provenance: .simulated))
                // FR-PROV-02 demo: the most recent ride is ALSO logged by the
                // bike computer (starts 40 s later, distance but no kcal) — the
                // dedup folds it in and Data sources discloses the merge.
                if offset == 0 {
                    samples.workouts.append(WorkoutReading(
                        start: s.addingTimeInterval(40), end: s.addingTimeInterval(dur * 60 + 25),
                        type: "Cycling", durMin: round(dur), kcal: nil,
                        distKm: round(dur / 3 * 10) / 10,
                        source: "Bike computer · Strava", tier: .estimate, provenance: .simulated))
                }
            }
        }
        return samples
    }

    // MARK: helpers

    private func daily(_ date: Date, _ kind: DailyMetricKind, _ value: Double, tier: DataTier) -> DailyMetric {
        DailyMetric(date: date, kind: kind, value: value,
                    source: source, tier: tier, provenance: .simulated)
    }

    /// Uniform jitter around `base` within ±`spread`.
    private func jitter(_ rng: inout SeededGenerator, base: Double, spread: Double) -> Double {
        let u = Double(rng.next() % 10_000) / 10_000.0   // 0..<1
        return base + (u * 2 - 1) * spread
    }
}