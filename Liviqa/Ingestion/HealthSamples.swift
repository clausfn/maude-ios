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

/// MVP HealthKit read set (FR-ING-01): HRV-SDNN, steps, active energy,
/// resting HR, blood glucose, sleep, workouts. Richer sources (BP, AFib,
/// body-comp, labs, meds) arrive via import/connectors, not this read set.
public enum DailyMetricKind: String, Sendable, CaseIterable {
    case hrvSDNN        // ms
    case restingHR      // bpm
    case steps          // count
    case activeEnergy   // kcal
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

/// The single ingestion aggregate (FR-ING-07). Value type, no upload method.
public struct HealthSamples: Sendable {
    public var glucose: [GlucoseReading]
    public var hrv: [DailyMetric]
    public var restingHR: [DailyMetric]
    public var steps: [DailyMetric]
    public var activeEnergy: [DailyMetric]
    public var sleep: [SleepReading]
    public var workouts: [WorkoutReading]

    public init(glucose: [GlucoseReading] = [], hrv: [DailyMetric] = [],
                restingHR: [DailyMetric] = [], steps: [DailyMetric] = [],
                activeEnergy: [DailyMetric] = [], sleep: [SleepReading] = [],
                workouts: [WorkoutReading] = []) {
        self.glucose = glucose; self.hrv = hrv; self.restingHR = restingHR
        self.steps = steps; self.activeEnergy = activeEnergy
        self.sleep = sleep; self.workouts = workouts
    }

    public static let empty = HealthSamples()

    public var isEmpty: Bool {
        glucose.isEmpty && hrv.isEmpty && restingHR.isEmpty && steps.isEmpty
            && activeEnergy.isEmpty && sleep.isEmpty && workouts.isEmpty
    }

    /// All daily-metric streams flattened — handy for arbitration/derivation.
    public var allDaily: [DailyMetric] { hrv + restingHR + steps + activeEnergy }
}
