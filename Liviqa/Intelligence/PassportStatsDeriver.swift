// PassportStatsDeriver.swift — derived half of the Health Passport (FR-PAS-05,
// DM-05), computed entirely on device from local `HealthSamples`.
//
// Pure Foundation — no SwiftData / SwiftUI / HealthKit (NFR-PORT-01), so it is
// unit-testable in isolation and portable to Android. The DECLARED/count half
// of the passport (nudges generated, sources connected, journal entries,
// consent decisions) is supplied by the caller from app state; this type only
// owns what sensors can derive.
import Foundation

/// The sensor-derived passport figures. Mirrors the numeric fields of the
/// presentation-layer `PassportStats` that a sensor/API could compute.
public nonisolated struct DerivedPassportStats: Sendable, Equatable {
    public let totalReadings: Int
    public let daysTracked: Int
    public let glucoseTimeInRange: Int   // 0–100 %
    public let avgSleepHours: Double

    public init(totalReadings: Int, daysTracked: Int,
                glucoseTimeInRange: Int, avgSleepHours: Double) {
        self.totalReadings = totalReadings
        self.daysTracked = daysTracked
        self.glucoseTimeInRange = glucoseTimeInRange
        self.avgSleepHours = avgSleepHours
    }
}

public nonisolated enum PassportStatsDeriver {

    /// Stages that count as actual sleep (excludes `awake` and `inBed`, which
    /// would otherwise inflate the nightly total).
    private static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    /// Derive the sensor-based stats from local samples.
    ///
    /// - `tirLowMmol`/`tirHighMmol`: the glucose time-in-range band. Defaults to
    ///   the standard CGM 3.9–10.0 mmol/L band; pass the user's `ClinicalTargets`
    ///   range to calibrate to their care plan (FR-PAS-03).
    public static func derive(from s: HealthSamples,
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0,
                              calendar: Calendar = Calendar(identifier: .gregorian)) -> DerivedPassportStats {

        let totalReadings = s.glucose.count + s.hrv.count + s.restingHR.count
            + s.steps.count + s.activeEnergy.count + s.sleep.count + s.workouts.count

        var days = Set<Date>()
        for g in s.glucose  { days.insert(calendar.startOfDay(for: g.ts)) }
        for d in s.allDaily { days.insert(calendar.startOfDay(for: d.date)) }
        for sl in s.sleep   { days.insert(calendar.startOfDay(for: sl.date)) }
        for w in s.workouts { days.insert(calendar.startOfDay(for: w.start)) }

        let tir: Int
        if s.glucose.isEmpty {
            tir = 0
        } else {
            let lo = min(tirLowMmol, tirHighMmol)
            let hi = max(tirLowMmol, tirHighMmol)
            let inRange = s.glucose.filter { $0.mmol >= lo && $0.mmol <= hi }.count
            tir = Int((Double(inRange) / Double(s.glucose.count) * 100).rounded())
        }

        let nightly = Dictionary(grouping: s.sleep.filter { asleepStages.contains($0.stage) }) {
            calendar.startOfDay(for: $0.date)
        }.mapValues { $0.reduce(0.0) { $0 + $1.hours } }
        let avgSleep = nightly.isEmpty ? 0 : nightly.values.reduce(0, +) / Double(nightly.count)

        return DerivedPassportStats(
            totalReadings: totalReadings,
            daysTracked: days.count,
            glucoseTimeInRange: tir,
            avgSleepHours: (avgSleep * 100).rounded() / 100)
    }
}
