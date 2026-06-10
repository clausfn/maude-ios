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
        for offset in 0...days {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDay) else { continue }

            samples.restingHR.append(daily(day, .restingHR, jitter(&rng, base: 58, spread: 6), tier: .good))
            samples.hrv.append(daily(day, .hrvSDNN, jitter(&rng, base: 55, spread: 18), tier: .good))
            samples.steps.append(daily(day, .steps, jitter(&rng, base: 8200, spread: 3500).rounded(), tier: .estimate))
            samples.activeEnergy.append(daily(day, .activeEnergy, jitter(&rng, base: 430, spread: 160), tier: .estimate))

            // A handful of CGM-style glucose points across the day (mmol/L).
            for hour in stride(from: 7, through: 22, by: 3) {
                let ts = cal.date(byAdding: .hour, value: hour, to: day) ?? day
                let mmol = max(3.6, jitter(&rng, base: 6.2, spread: 1.8))
                samples.glucose.append(GlucoseReading(
                    ts: ts, mmol: round(mmol * 10) / 10,
                    mealContext: hour == 7 ? "fasting" : nil,
                    source: source, tier: .good, provenance: .simulated))
            }

            // Staged sleep (deep / core / rem) summing to the night's total, so the
            // sleep-stages visualisation has real structure to render.
            let sleepHours = max(4.5, jitter(&rng, base: 7.2, spread: 1.1))
            let deep = sleepHours * (0.16 + jitter(&rng, base: 0.02, spread: 0.04))
            let rem  = sleepHours * (0.21 + jitter(&rng, base: 0.02, spread: 0.04))
            let core = max(0.1, sleepHours - deep - rem)
            for (stage, hrs) in [(SleepStage.deep, deep), (.core, core), (.rem, rem)] {
                samples.sleep.append(SleepReading(
                    date: day, stage: stage, hours: round(hrs * 10) / 10,
                    source: source, tier: .estimate, provenance: .simulated))
            }

            // ~Every third day, a workout.
            if offset % 3 == 0 {
                let s = cal.date(byAdding: .hour, value: 18, to: day) ?? day
                let dur = jitter(&rng, base: 45, spread: 20)
                samples.workouts.append(WorkoutReading(
                    start: s, end: s.addingTimeInterval(dur * 60), type: "Cycling",
                    durMin: round(dur), kcal: round(dur * 9), distKm: round(dur / 3 * 10) / 10,
                    source: source, tier: .estimate, provenance: .simulated))
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