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
    public let date: Date
    public let stage: SleepStage
    public let hours: Double
    public let source: String
    public let tier: DataTier
    public let provenance: Provenance
    public init(date: Date, stage: SleepStage, hours: Double,
                source: String, tier: DataTier, provenance: Provenance) {
        self.date = date; self.stage = stage; self.hours = hours
        self.source = source; self.tier = tier; self.provenance = provenance
    }
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
    static func mergedAsleepHours(_ segments: [SleepReading],
                                  asleep: Set<SleepStage>) -> Double {
        // Intervals in seconds; drop non-asleep stages and empty/negative spans.
        let intervals = segments
            .filter { asleep.contains($0.stage) && $0.hours > 0 }
            .map { seg -> (start: TimeInterval, end: TimeInterval) in
                let start = seg.date.timeIntervalSinceReferenceDate
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
    public var insulin: [InsulinReading]
    public var bloodPressure: [BloodPressureReading]
    public var afib: [AFibReading]
    public var bodyComposition: [BodyCompositionReading]

    public init(glucose: [GlucoseReading] = [], hrv: [DailyMetric] = [],
                restingHR: [DailyMetric] = [], steps: [DailyMetric] = [],
                activeEnergy: [DailyMetric] = [], sleep: [SleepReading] = [],
                workouts: [WorkoutReading] = [],
                heartExtras: [DailyMetric] = [], insulin: [InsulinReading] = [],
                bloodPressure: [BloodPressureReading] = [], afib: [AFibReading] = [],
                bodyComposition: [BodyCompositionReading] = []) {
        self.glucose = glucose; self.hrv = hrv; self.restingHR = restingHR
        self.steps = steps; self.activeEnergy = activeEnergy
        self.sleep = sleep; self.workouts = workouts
        self.heartExtras = heartExtras; self.insulin = insulin
        self.bloodPressure = bloodPressure; self.afib = afib
        self.bodyComposition = bodyComposition
    }

    public static let empty = HealthSamples()

    public nonisolated var isEmpty: Bool {
        glucose.isEmpty && hrv.isEmpty && restingHR.isEmpty && steps.isEmpty
            && activeEnergy.isEmpty && sleep.isEmpty && workouts.isEmpty
            && heartExtras.isEmpty && insulin.isEmpty && bloodPressure.isEmpty
            && afib.isEmpty && bodyComposition.isEmpty
    }

    /// All daily-metric streams flattened — handy for arbitration/derivation.
    public nonisolated var allDaily: [DailyMetric] { hrv + restingHR + steps + activeEnergy + heartExtras }
}
