// HealthSamples.swift — L1 ingestion value types (portable, framework-free).
//
// FR-ING-07: a single `HealthSamples` aggregate is the only thing a provider
// returns; there is **no network-upload method** anywhere on these types. They
// are plain values (no SwiftData / HealthKit), so the L1 layer is unit-testable
// and portable to Android (NFR-PORT-01). L2 maps these readings into the
// persisted SwiftData entities.
//
// `provenance` is carried for arbitration/storage only and MUST NEVER render.
import Foundation

/// HealthKit daily-metric kinds. The original MVP set (FR-ING-01: HRV-SDNN,
/// resting HR, steps, active energy) plus the extended heart/respiratory panel
/// captured in the full-HealthKit pass. Labs and the medication list are NOT in
/// HealthKit — they arrive via file import (sundhed.dk / LibreView / InBody).
public enum DailyMetricKind: String, Sendable, CaseIterable {
    case hrvSDNN        // ms
    case restingHR      // bpm
    case steps          // count
    case activeEnergy   // kcal
    // Extended heart / respiratory panel (full HealthKit capture).
    case heartRate        // bpm (daily mean)
    case walkingHR        // bpm (walking average)
    case hrRecovery       // bpm (one-minute recovery)
    case respiratoryRate  // breaths/min
    case spo2             // %, 0–100
    case vo2max           // mL/(kg·min)
}

public struct GlucoseReading: Provenanced, Sendable {
    public let ts: Date
    public let mmol: Double          // canonical mmol/L (OD-07)
    public let mealContext: String?
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(ts: Date, mmol: Double, mealContext: String? = nil,
                source: String, tier: DataTier, provenance: Provenance) {
        self.ts = ts; self.mmol = mmol; self.mealContext = mealContext
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

public struct DailyMetric: Provenanced, Sendable {
    public let date: Date
    public let kind: DailyMetricKind
    public let value: Double
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(date: Date, kind: DailyMetricKind, value: Double,
                source: String, tier: DataTier, provenance: Provenance) {
        self.date = date; self.kind = kind; self.value = value
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

public struct SleepReading: Provenanced, Sendable {
    /// The NIGHT this segment belongs to (a start-of-day bucket). A night is
    /// labelled by the day it ends on, so a 23:04→06:14 night is one bucket
    /// rather than two half-nights split at midnight (`HealthKitService.nightDay`).
    public let date: Date
    public let stage: SleepStage
    public let hours: Double
    /// The segment's wall-clock START, when the source retained it. Optional
    /// because older/aggregated sources only carry (night, stage, hours) — the
    /// intra-night surfaces (depth chart, wake-up moment, bedtime) render only
    /// when this is present, and stay honestly absent when it is not.
    public let start: Date?
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(date: Date, stage: SleepStage, hours: Double, start: Date? = nil,
                source: String, tier: DataTier, provenance: Provenance) {
        self.date = date; self.stage = stage; self.hours = hours; self.start = start
        self.source = source; self.tier = tier; self.provenance = provenance
    }

    /// Wall-clock start of the segment's interval. Falls back to the night
    /// bucket for sources that carry no intra-night times.
    public nonisolated var intervalStart: Date { start ?? date }
    /// Wall-clock end of the segment's interval.
    public nonisolated var intervalEnd: Date { intervalStart.addingTimeInterval(hours * 3600) }
}

public extension SleepReading {

    /// Total asleep hours for a set of segments, counting each wall-clock minute
    /// **once** — the UNION of the intervals, never their sum.
    ///
    /// When two sources record the same night (iPhone + Apple Watch), their
    /// asleep segments overlap; naively summing `hours` double-counts the overlap
    /// (a real ~8h night reads as ~16h). This filters to `asleep` stages, treats
    /// each reading as the half-open interval `[date, date + hours]`, sorts by
    /// start, merges overlapping/adjacent intervals, and returns the merged span
    /// in hours. Overlapping segments from different sources count exactly once.
    ///
    /// Pure Foundation, no side effects (unit-testable, Android-portable).
    /// `nonisolated`: every caller is a pure deriver that runs OFF the main
    /// actor (AppState's detached deriver chain, the background nudge loop).
    nonisolated static func mergedAsleepHours(_ segments: [SleepReading],
                                              asleep: Set<SleepStage>) -> Double {
        // Intervals in seconds; drop non-asleep stages and empty/negative spans.
        let intervals = segments
            .filter { asleep.contains($0.stage) && $0.hours > 0 }
            .map { seg -> (start: TimeInterval, end: TimeInterval) in
                let start = seg.intervalStart.timeIntervalSinceReferenceDate
                return (start, start + seg.hours * 3600)
            }
            .sorted { $0.start < $1.start }
        guard let first = intervals.first else { return 0 }

        var total: TimeInterval = 0
        var runStart = first.start
        var runEnd = first.end
        for iv in intervals.dropFirst() {
            if iv.start <= runEnd {              // overlaps or touches → extend run
                runEnd = max(runEnd, iv.end)
            } else {                             // gap → bank the run, start a new one
                total += runEnd - runStart
                runStart = iv.start
                runEnd = iv.end
            }
        }
        total += runEnd - runStart
        return total / 3600
    }
}

public struct WorkoutReading: Provenanced, Sendable {
    public let start: Date
    public let end: Date
    public let type: String
    public let durMin: Double
    public let kcal: Double?
    public let distKm: Double?
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(start: Date, end: Date, type: String, durMin: Double,
                kcal: Double? = nil, distKm: Double? = nil,
                source: String, tier: DataTier, provenance: Provenance) {
        self.start = start; self.end = end; self.type = type; self.durMin = durMin
        self.kcal = kcal; self.distKm = distKm
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// One timestamped heart-rate reading taken INSIDE a workout interval (bpm).
///
/// T-FIT-01: the daily `heartRate` DailyMetric is a per-day mean and can say
/// nothing about a single session, so the Fitness screen's per-workout average
/// and its time-in-zone need the raw beats. These are read only for the recent
/// workout window (`HealthKitService.hrWindowDays`) — enough for the four-week
/// load buckets and this week's zone card, and bounded so a 90-day backfill
/// can't pull tens of thousands of samples into memory.
///
/// Zones derived from these are always fractions of the citizen's OWN observed
/// maximum in the window — never an age formula, never a population scale, and
/// never a target.
public struct HeartRateSample: Provenanced, Sendable {
    public let ts: Date
    public let bpm: Double
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(ts: Date, bpm: Double,
                source: String, tier: DataTier, provenance: Provenance) {
        self.ts = ts; self.bpm = bpm
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// One insulin-delivery event (HealthKit `insulinDelivery`, via mySugr etc.).
/// **FR-REG-04: data-layer only.** Never rendered as a dose and never used to
/// suggest one — it exists solely as an input to the glucose×insulin observation.
public struct InsulinReading: Provenanced, Sendable {
    public let ts: Date
    public let kind: InsulinKind
    public let units: Double
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(ts: Date, kind: InsulinKind, units: Double,
                source: String, tier: DataTier, provenance: Provenance) {
        self.ts = ts; self.kind = kind; self.units = units
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

public struct BloodPressureReading: Provenanced, Sendable {
    public let ts: Date
    public let sys: Int   // mmHg
    public let dia: Int   // mmHg
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(ts: Date, sys: Int, dia: Int,
                source: String, tier: DataTier, provenance: Provenance) {
        self.ts = ts; self.sys = sys; self.dia = dia
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// AFib burden % (HealthKit `atrialFibrillationBurden`). **OD-11: display-only.**
/// Re-presented as the watch's own number with a route-to-cardiologist prompt;
/// never interpreted, never alarmed on, never used to assert a rhythm finding.
public struct AFibReading: Provenanced, Sendable {
    public let ts: Date
    public let pct: Double
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(ts: Date, pct: Double,
                source: String, tier: DataTier, provenance: Provenance) {
        self.ts = ts; self.pct = pct
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// One night's sleeping wrist temperature in °C (HealthKit
/// `appleSleepingWristTemperature`, iOS 16+ / Apple Watch Series 8+; written
/// once per night by the watch).
///
/// `date` is the NIGHT bucket — the day the night ends on, the same rule sleep
/// uses (`HealthKitService.nightDay`) — so the reading lands on the morning it
/// describes and the day axis (DaySeries) holds without a midnight split.
///
/// PURPOSE (coverage audit 2026-08-18, FR-ING-16): sleep-context signal —
/// deviation from the citizen's OWN rolling baseline (illness / cycle /
/// recovery context next to that night's sleep). Absolute skin temperature is
/// never framed against a population range and never rendered as a fever claim.
public struct WristTemperatureReading: Provenanced, Sendable {
    public let date: Date       // night bucket (start of the morning's day)
    public let celsius: Double
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(date: Date, celsius: Double,
                source: String, tier: DataTier, provenance: Provenance) {
        self.date = date; self.celsius = celsius
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// Pure per-day roll-up of raw quantity samples — the ONE place the "how does a
/// pile of samples become a daily figure" rule lives (framework-free, so the
/// rule is unit-testable and Android-portable).
///
/// THE BUG THIS EXISTS TO KILL (coverage audit 2026-08-18, same class as the
/// sleep union-not-sum rule): a raw `HKSampleQuery` returns EVERY source's
/// samples — an iPhone in the pocket and a watch on the wrist both write step
/// samples for the same walk. Summing them across sources double-counts the
/// day (a real ~8k-step day reads as ~15k). Apple's own Health app never shows
/// that sum; a naive sample-level sum did.
///
/// Rule for CUMULATIVE kinds (steps, active energy): sum per (day, source),
/// then the day's figure is the single best-covering source's total — the
/// device that witnessed the most. Sources are NEVER summed together, echoing
/// §2.3's never-blend rule. A day only one device recorded keeps that device's
/// full total (gap fill).
///
/// Rule for MEAN kinds: the day's mean over all samples (unchanged behaviour —
/// several estimates of the same quantity average; they do not accumulate).
public enum DailyRollup {

    public struct Row: Sendable, Equatable {
        public let day: Date        // start-of-day bucket (caller buckets)
        public let value: Double
        public let source: String
        public init(day: Date, value: Double, source: String) {
            self.day = day; self.value = value; self.source = source
        }
    }

    public static func rollUp(_ rows: [Row], cumulative: Bool) -> [Row] {
        guard !rows.isEmpty else { return [] }
        if cumulative {
            // Per (day, source) totals → per day, the best-covering source wins.
            var perDaySource: [Date: [String: Double]] = [:]
            for r in rows {
                perDaySource[r.day, default: [:]][r.source, default: 0] += r.value
            }
            return perDaySource.map { day, bySource in
                // max by total; ties broken by source name for determinism.
                let winner = bySource.max {
                    ($0.value, $1.key) < ($1.value, $0.key)
                }!
                return Row(day: day, value: winner.value, source: winner.key)
            }.sorted { $0.day < $1.day }
        } else {
            var byDay: [Date: (sum: Double, n: Int, source: String)] = [:]
            for r in rows {
                let cur = byDay[r.day] ?? (0, 0, r.source)
                byDay[r.day] = (cur.sum + r.value, cur.n + 1, cur.source)
            }
            return byDay.map { day, a in
                Row(day: day, value: a.n > 0 ? a.sum / Double(a.n) : 0, source: a.source)
            }.sorted { $0.day < $1.day }
        }
    }
}

/// Body-composition snapshot. HealthKit yields weight / fat% / lean / BMI;
/// visceral and trunk-fat are InBody-only (file import), left nil here.
public struct BodyCompositionReading: Provenanced, Sendable {
    public let ts: Date
    public let weightKg: Double?
    public let fatPct: Double?
    public let leanKg: Double?
    public let bmi: Double?
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(ts: Date, weightKg: Double? = nil, fatPct: Double? = nil,
                leanKg: Double? = nil, bmi: Double? = nil,
                source: String, tier: DataTier, provenance: Provenance) {
        self.ts = ts; self.weightKg = weightKg; self.fatPct = fatPct
        self.leanKg = leanKg; self.bmi = bmi
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// The single ingestion aggregate (FR-ING-07). Value type, no upload method.
public struct HealthSamples: Sendable {
    public var glucose: [GlucoseReading]
    public var hrv: [DailyMetric]
    public var restingHR: [DailyMetric]
    public var steps: [DailyMetric]
    public var activeEnergy: [DailyMetric]
    public var sleep: [SleepReading]
    public var workouts: [WorkoutReading]
    // Full-HealthKit capture (additive; defaulted so existing callers/tests are
    // unaffected). `heartExtras` carries the extended heart/respiratory kinds.
    public var heartExtras: [DailyMetric]
    /// Raw beats inside the recent workout intervals (T-FIT-01) — per-workout
    /// average HR and time-in-zone come from here, nothing else does.
    public var workoutHeartRate: [HeartRateSample]
    public var insulin: [InsulinReading]
    public var bloodPressure: [BloodPressureReading]
    public var afib: [AFibReading]
    public var bodyComposition: [BodyCompositionReading]
    /// Nightly sleeping wrist temperature (FR-ING-16, coverage audit 2026-08-18).
    public var wristTemperature: [WristTemperatureReading]

    public init(glucose: [GlucoseReading] = [], hrv: [DailyMetric] = [],
                restingHR: [DailyMetric] = [], steps: [DailyMetric] = [],
                activeEnergy: [DailyMetric] = [], sleep: [SleepReading] = [],
                workouts: [WorkoutReading] = [],
                heartExtras: [DailyMetric] = [],
                workoutHeartRate: [HeartRateSample] = [],
                insulin: [InsulinReading] = [],
                bloodPressure: [BloodPressureReading] = [], afib: [AFibReading] = [],
                bodyComposition: [BodyCompositionReading] = [],
                wristTemperature: [WristTemperatureReading] = []) {
        self.glucose = glucose; self.hrv = hrv; self.restingHR = restingHR
        self.steps = steps; self.activeEnergy = activeEnergy
        self.sleep = sleep; self.workouts = workouts
        self.heartExtras = heartExtras; self.workoutHeartRate = workoutHeartRate
        self.insulin = insulin
        self.bloodPressure = bloodPressure; self.afib = afib
        self.bodyComposition = bodyComposition
        self.wristTemperature = wristTemperature
    }

    public static let empty = HealthSamples()

    public nonisolated var isEmpty: Bool {
        glucose.isEmpty && hrv.isEmpty && restingHR.isEmpty && steps.isEmpty
            && activeEnergy.isEmpty && sleep.isEmpty && workouts.isEmpty
            && heartExtras.isEmpty && workoutHeartRate.isEmpty && insulin.isEmpty
            && bloodPressure.isEmpty && afib.isEmpty && bodyComposition.isEmpty
            && wristTemperature.isEmpty
    }

    /// All daily-metric streams flattened — handy for arbitration/derivation.
    public nonisolated var allDaily: [DailyMetric] { hrv + restingHR + steps + activeEnergy + heartExtras }
}
