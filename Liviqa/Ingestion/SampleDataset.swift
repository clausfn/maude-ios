// SampleDataset.swift — the opt-in SAMPLE dataset (FR-SMP-02). Pure Foundation.
//
// WHAT THIS IS, AND WHAT IT IS NOT
// ────────────────────────────────
// Every reading below is **SYNTHETIC**: generated here, by arithmetic, from a
// fixed seed. Not one number is any person's measurement. That is deliberate
// and it is the whole point of the file:
//
//   • The dataset is *modelled on* the shape of a real 60-day record we have
//     looked at — someone who wears a watch, runs a CGM, weighs themselves
//     now and then, sleeps badly on a Tuesday. It reproduces that SHAPE:
//     overnight glucose in the 5–7 mmol/L band, three meal excursions a day,
//     a dawn rise, HRV that falls the morning after a short night, resting HR
//     that lifts after a hard session, weekend step counts that beat weekdays.
//   • It reproduces none of that person's VALUES. Shipping one identified
//     human's health record to every tester — as a demo, "just to show the
//     app" — is precisely the thing this application exists to refuse. A
//     synthetic record cannot leak anybody, cannot be re-identified, and can
//     be regenerated, inspected and argued with in review.
//
// DETERMINISM: seeded (SplitMix64) with a per-day sub-seed keyed on the day's
// offset from today, so the dataset is byte-identical on every launch on a
// given day, and today's curve does not jump around while a tester is looking
// at it. Nothing here reads the clock except through the injected `now`.
//
// STORAGE: this type returns a value. It holds no store, takes no ModelContext,
// and there is no path from here into SwiftData, the journal, the vault or the
// consent ledger — sample readings must never be written anywhere that a real
// reading lives (FR-SMP-04, proven by SampleModeTests + SampleModePostureTests).
//
// SOURCE NAMING: every stream is sourced "Sample", which `MetricSourceLabel`
// classifies as a fixture, so no screen can print a fabricated device name
// ("· Dexcom G7") next to a fabricated number (T-DED-06).
//
// DELIBERATE OMISSIONS: no AFib burden, no blood pressure, no insulin doses,
// no labs, no diagnoses, no medicines, no journal entries. Those are the
// surfaces where an invented value would look most like a clinical fact about
// the person holding the phone; the sample simply does not speak there.
import Foundation

public nonisolated enum SampleDataset {

    /// How many days of history the sample carries.
    public static let days = 60

    /// Every stream is attributed to this name. `MetricSourceLabel.isFixture`
    /// matches it exactly, so it is dropped from any prose slot that would
    /// otherwise read as "the device your numbers came from".
    public static let sourceName = "Sample"

    /// Base seed — "SAMPLE" in ASCII. Changing it changes the person.
    private static let baseSeed: UInt64 = 0x53_41_4D_50_4C_45

    private static let cal = Calendar(identifier: .gregorian)

    // MARK: - The three days worth looking at
    //
    // Offsets back from today. A demo with no texture teaches nothing, so the
    // sample carries a small number of legible stories — each one built from
    // the SAME arithmetic as every other day, just with the dials moved:
    //
    //   −2  a late dinner (21:40) → a tall evening excursion, then a short night
    //   −3  the morning after the late dinner → HRV down, glucose runs higher
    //   −9  a long weekend walk → steps and energy up, next-morning RHR up
    //
    // They are close enough to today that a tester meets them in the first week
    // view, and far enough apart that no two collide.
    private static let lateDinnerOffset = 2
    private static let longWalkOffset = 9

    // MARK: - Build

    /// The full synthetic record, ending at `now`.
    ///
    /// Returned already `arbitrated()` — the same §2.3 pass a real fetch runs —
    /// so what the derivers see in sample mode is shaped exactly like what they
    /// see on a real device, and no screen gets a code path of its own.
    public static func samples(now: Date = Date()) -> HealthSamples {
        var s = HealthSamples.empty
        let today = cal.startOfDay(for: now)

        // Day −(days-1) … day 0. Each day draws from its own generator, so a
        // change to one day's arithmetic cannot shift every later day.
        for back in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { continue }
            var rng = SeededGenerator(seed: baseSeed ^ UInt64(back &+ 1))
            let d = Day(offsetBack: back, day: day, rng: &rng)

            s.restingHR.append(daily(day, .restingHR, d.restingHR, tier: .good))
            s.hrv.append(daily(day, .hrvSDNN, d.hrv, tier: .good))
            s.steps.append(daily(day, .steps, d.steps, tier: .estimate))
            s.activeEnergy.append(daily(day, .activeEnergy, d.activeEnergy, tier: .estimate))
            s.heartExtras.append(daily(day, .heartRate, d.meanHR, tier: .good))
            s.heartExtras.append(daily(day, .walkingHR, d.walkingHR, tier: .estimate))
            s.heartExtras.append(daily(day, .respiratoryRate, d.respiratoryRate, tier: .good))
            s.heartExtras.append(daily(day, .spo2, d.spo2, tier: .estimate))
            // VO₂max is written by a watch every few days, not daily — the gaps
            // are part of the shape a real record has.
            if back % 5 == 0 {
                s.heartExtras.append(daily(day, .vo2max, d.vo2max, tier: .estimate))
            }

            s.glucose += glucoseDay(d)
            s.sleep += night(d)
            s.workouts += d.workout.map { [$0] } ?? []
            s.workoutHeartRate += d.workout.map { workoutHeartRate(for: $0, hard: d.hardSession) } ?? []

            // A scale that gets stood on a couple of times a week.
            if back % 3 == 0 {
                s.bodyComposition.append(BodyCompositionReading(
                    ts: cal.date(byAdding: .hour, value: 7, to: day) ?? day,
                    weightKg: d.weightKg, fatPct: d.fatPct,
                    leanKg: round(d.weightKg * (1 - d.fatPct / 100) * 10) / 10,
                    bmi: round(d.weightKg / (1.78 * 1.78) * 10) / 10,
                    source: sourceName, tier: .estimate, provenance: .simulated))
            }
        }
        return s.arbitrated(calendar: cal)
    }

    // MARK: - One day's dials

    /// Everything one day needs, drawn once so the streams stay coherent with
    /// each other (a short night lowers HRV *and* lifts the next day's curve —
    /// the same coupling a real record shows).
    private struct Day {
        let offsetBack: Int
        let day: Date
        let weekend: Bool
        /// This night was short (the sleep the day is named by).
        let shortNight: Bool
        /// The night BEFORE was short — the lever for today's glucose and HRV.
        let afterShortNight: Bool
        let lateDinner: Bool
        let longWalk: Bool
        let hardSession: Bool

        let sleepHours: Double
        let restingHR: Double
        let hrv: Double
        let steps: Double
        let activeEnergy: Double
        let meanHR: Double
        let walkingHR: Double
        let respiratoryRate: Double
        let spo2: Double
        let vo2max: Double
        let weightKg: Double
        let fatPct: Double
        let workout: WorkoutReading?
        /// Bedtime drift, in minutes before 23:00.
        let bedtimeShift: Double

        init(offsetBack: Int, day: Date, rng: inout SeededGenerator) {
            self.offsetBack = offsetBack
            self.day = day
            let weekday = SampleDataset.cal.component(.weekday, from: day)
            self.weekend = weekday == 1 || weekday == 7
            // A short night lands on a fixed weekday rhythm plus the story day,
            // so the pattern is learnable rather than random noise.
            self.shortNight = (weekday == 3) || offsetBack == SampleDataset.lateDinnerOffset
            self.afterShortNight = (weekday == 4) || offsetBack == SampleDataset.lateDinnerOffset - 1
            self.lateDinner = offsetBack == SampleDataset.lateDinnerOffset
            self.longWalk = offsetBack == SampleDataset.longWalkOffset
            self.hardSession = offsetBack % 9 == 0

            self.sleepHours = shortNight
                ? SampleDataset.clamp(SampleDataset.jitter(&rng, base: 5.7, spread: 0.4), 5.0, 6.3)
                : SampleDataset.clamp(SampleDataset.jitter(&rng, base: 7.3, spread: 0.6), 6.2, 8.4)
            self.bedtimeShift = SampleDataset.jitter(&rng, base: 20, spread: 22) + (lateDinner ? 55 : 0)

            // Resting HR: a personal band, lifted the morning after a hard
            // session or a short night. Never near a clinical threshold.
            var rhr = SampleDataset.jitter(&rng, base: 56, spread: 3)
            if afterShortNight { rhr += 3.2 }
            if longWalk { rhr += 2.4 }
            self.restingHR = round(SampleDataset.clamp(rhr, 49, 68))

            // HRV: the mirror image — down after a short night, up on a rest day.
            var hrvMs = SampleDataset.jitter(&rng, base: 46, spread: 6)
            if afterShortNight { hrvMs -= 9 }
            if weekend { hrvMs += 3 }
            self.hrv = round(SampleDataset.clamp(hrvMs, 22, 74))

            let stepBase = longWalk ? 18_400.0 : (weekend ? 10_600.0 : 7_900.0)
            self.steps = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: stepBase, spread: 2100), 2600, 22_000))
            self.activeEnergy = round(SampleDataset.clamp(
                SampleDataset.jitter(&rng, base: longWalk ? 940 : (weekend ? 560 : 430), spread: 120), 140, 1300))

            self.meanHR = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 68, spread: 4), 58, 84))
            self.walkingHR = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 104, spread: 7), 88, 126))
            self.respiratoryRate = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 14.2, spread: 1.4), 11, 18) * 10) / 10
            self.spo2 = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 97, spread: 1.2), 94, 100))
            self.vo2max = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 41.5, spread: 1.6), 36, 48) * 10) / 10

            // Weight: a slow, unremarkable drift with day-to-day scale noise.
            let drift = Double(offsetBack) * 0.012
            self.weightKg = round((SampleDataset.jitter(&rng, base: 74.6 + drift, spread: 0.35)) * 10) / 10
            self.fatPct = round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 21.4, spread: 0.9), 17, 27) * 10) / 10

            // Sessions: roughly four a week, types on a fixed rotation, plus the
            // long walk. Everything about them is a value, never a place.
            let doesSession = longWalk || [0, 2, 3, 5].contains(offsetBack % 7)
            if doesSession {
                let type = longWalk ? "Walking"
                    : ["Cycling", "Running", "Strength training", "Walking"][offsetBack % 4]
                let minutes = longWalk
                    ? round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: 128, spread: 18), 90, 160))
                    : round(SampleDataset.clamp(SampleDataset.jitter(&rng, base: hardSession ? 58 : 42, spread: 12), 22, 78))
                let startHour = weekend ? 10 : 17
                let start = SampleDataset.cal.date(byAdding: .hour, value: startHour, to: day) ?? day
                let kcal = round(minutes * (longWalk ? 5.4 : (hardSession ? 10.2 : 8.1)))
                let km: Double? = {
                    switch type {
                    case "Cycling":  return round(minutes / 2.1 * 10) / 10
                    case "Running":  return round(minutes / 5.6 * 10) / 10
                    case "Walking":  return round(minutes / 11.0 * 10) / 10
                    default:         return nil
                    }
                }()
                self.workout = WorkoutReading(
                    start: start, end: start.addingTimeInterval(minutes * 60),
                    type: type, durMin: minutes, kcal: kcal, distKm: km,
                    source: SampleDataset.sourceName, tier: .estimate, provenance: .simulated)
            } else {
                self.workout = nil
            }
        }
    }

    // MARK: - Streams

    /// One day of CGM at a 15-minute cadence: an overnight plateau, a dawn
    /// rise, three meal excursions with realistic rise/decay asymmetry, and a
    /// post-session dip on days with a workout. The late-dinner day pushes its
    /// evening peak two hours later and higher — the story the demo tells.
    private static func glucoseDay(_ d: Day) -> [GlucoseReading] {
        var rng = SeededGenerator(seed: baseSeed &+ 0x9E37 &+ UInt64(d.offsetBack &+ 1))
        var out: [GlucoseReading] = []

        let overnight = 5.6 + (d.afterShortNight ? 0.7 : 0)
        let gain = d.afterShortNight ? 1.22 : 1.0
        // (peak hour, height mmol/L, width hours)
        var meals: [(Double, Double, Double)] = [
            (7.9, 2.9, 1.5),     // breakfast
            (12.6, 3.4, 1.7),    // lunch
        ]
        meals.append(d.lateDinner ? (21.7, 4.6, 2.1) : (18.9, 3.1, 1.8))

        for step in 0..<96 {
            let hour = Double(step) * 0.25
            var mmol = overnight + jitter(&rng, base: 0, spread: 0.22)
            // Dawn phenomenon — a gentle lift from 04:00 peaking near 07:00.
            mmol += 0.55 * exp(-pow((hour - 6.6) / 2.0, 2))
            for (peak, height, width) in meals {
                // Asymmetric: a fast rise, a slower fall (a real curve is not a bell).
                let dt = hour - peak
                let w = dt < 0 ? width * 0.62 : width
                mmol += height * gain * exp(-pow(dt / w, 2))
            }
            // A session pulls glucose down for the hour that follows it.
            if let w = d.workout {
                let wh = Double(cal.component(.hour, from: w.start))
                    + Double(cal.component(.minute, from: w.start)) / 60
                let after = hour - (wh + w.durMin / 60)
                if after > 0, after < 2 { mmol -= 0.9 * exp(-pow(after / 0.9, 2)) }
            }
            mmol = clamp(mmol, 3.6, 13.8)
            let ts = d.day.addingTimeInterval(hour * 3600)
            out.append(GlucoseReading(
                ts: ts, mmol: round(mmol * 10) / 10,
                mealContext: step == 28 ? "fasting" : nil,   // 07:00
                source: sourceName, tier: .good, provenance: .simulated))
        }
        return out
    }

    /// One night, laid out in wall-clock time: four cycles, deep front-loaded,
    /// REM back-loaded, one or two brief wake-ups. The stage TOTALS are the
    /// figures the day drew; only their placement is invented here, by a plain
    /// published rule — the same discipline the mock provider's night follows.
    private static func night(_ d: Day) -> [SleepReading] {
        let hours = d.sleepHours
        let deep = hours * (d.shortNight ? 0.14 : 0.17)
        let rem = hours * (d.shortNight ? 0.17 : 0.22)
        let core = max(0.1, hours - deep - rem)
        // Bedtime the evening before: 23:00 minus the day's own drift.
        let bedtime = d.day.addingTimeInterval(-(60 + d.bedtimeShift) * 60)
        let deepShare = [0.42, 0.29, 0.19, 0.10]
        let remShare = [0.12, 0.21, 0.29, 0.38]

        var out: [SleepReading] = []
        var t = bedtime
        func add(_ stage: SleepStage, _ h: Double) {
            guard h > 0.001 else { return }
            out.append(SleepReading(date: d.day, stage: stage,
                                    hours: round(h * 100) / 100, start: t,
                                    source: sourceName, tier: .estimate,
                                    provenance: .simulated))
            t = t.addingTimeInterval(h * 3600)
        }
        for cycle in 0..<4 {
            let coreSlice = core / 4
            add(.core, coreSlice / 2)
            add(.deep, deep * deepShare[cycle])
            add(.core, coreSlice / 2)
            if cycle == 1 { add(.awake, 0.12) }
            if cycle == 3 && d.shortNight { add(.awake, 0.18) }
            add(.rem, rem * remShare[cycle])
        }
        return out
    }

    /// Beats inside one session, once a minute: warm-up, a steady block, one
    /// push on the hard days, cool-down. Deterministic (no RNG draws), and the
    /// values stay a long way below anything that could read as a clinical
    /// event — the sample never simulates an emergency.
    private static func workoutHeartRate(for w: WorkoutReading, hard: Bool) -> [HeartRateSample] {
        let minutes = max(1, Int(w.durMin.rounded()))
        let ceiling: Double = w.type == "Walking" ? 118 : (hard ? 168 : 152)
        let floor: Double = w.type == "Walking" ? 92 : 104
        return (0..<minutes).map { m in
            let f = Double(m) / Double(minutes)
            var bpm = floor + (ceiling - floor) * sin(Double.pi * min(1, f * 1.12))
            if hard, f > 0.55, f < 0.72 { bpm += 9 }
            bpm += Double((m % 7) - 3)
            return HeartRateSample(ts: w.start.addingTimeInterval(Double(m) * 60),
                                   bpm: round(bpm * 10) / 10,
                                   source: sourceName, tier: .good,
                                   provenance: .simulated)
        }
    }

    // MARK: - Helpers

    private static func daily(_ date: Date, _ kind: DailyMetricKind,
                              _ value: Double, tier: DataTier) -> DailyMetric {
        DailyMetric(date: date, kind: kind, value: value,
                    source: sourceName, tier: tier, provenance: .simulated)
    }

    private static func jitter(_ rng: inout SeededGenerator,
                               base: Double, spread: Double) -> Double {
        let u = Double(rng.next() % 10_000) / 10_000.0
        return base + (u * 2 - 1) * spread
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, v))
    }
}
