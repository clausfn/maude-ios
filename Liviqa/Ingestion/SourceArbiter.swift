// SourceArbiter.swift — DataModel v1 §2.3 source arbitration (portable).
//
// Rule: for any logical slot (a given metric at a given time/day), the HIGHEST
// trust tier present wins; lower tiers only FILL GAPS the higher tiers don't
// cover; tiers are NEVER silently blended within a slot. So a clinical glucose
// reading is never averaged with a consumer estimate for the same moment — the
// clinical value stands alone and the estimate is dropped for that slot, while
// an estimate on a day with no clinical/good reading is kept (gap fill).
//
// Pure Foundation (Android-portable). Tier order: clinical > good > estimate.
import Foundation

public enum SourceArbiter {

    /// Lower rank = higher trust. clinical(0) > good(1) > estimate(2).
    @inline(__always)
    static func rank(_ tier: DataTier) -> Int {
        switch tier {
        case .clinical: return 0
        case .good:     return 1
        case .estimate: return 2
        }
    }

    /// Keep, per `key`, only the readings of the highest tier present for that
    /// key. Different keys are arbitrated independently (so lower tiers fill the
    /// gaps the higher tiers leave). Order within a key is preserved.
    public static func arbitrate<T: Provenanced, K: Hashable>(
        _ readings: [T], key: (T) -> K
    ) -> [T] {
        guard !readings.isEmpty else { return [] }
        // Best (lowest) rank seen per key.
        var bestRank: [K: Int] = [:]
        for r in readings {
            let k = key(r)
            let rk = rank(r.tier)
            if let cur = bestRank[k] { if rk < cur { bestRank[k] = rk } }
            else { bestRank[k] = rk }
        }
        return readings.filter { rank($0.tier) == bestRank[key($0)] }
    }
}

public extension HealthSamples {
    /// Apply §2.3 arbitration to every stream. Daily metrics are keyed by
    /// (kind, day); glucose by timestamp; sleep by (stage, day); workouts by
    /// start. With a single source this is a no-op; it matters once clinical
    /// import connectors coexist with consumer estimates.
    func arbitrated(calendar: Calendar = .current) -> HealthSamples {
        func day(_ d: Date) -> TimeInterval { calendar.startOfDay(for: d).timeIntervalSince1970 }
        func dailyKey(_ m: DailyMetric) -> String { "\(m.kind.rawValue)@\(day(m.date))" }

        return HealthSamples(
            glucose:      SourceArbiter.arbitrate(glucose)      { $0.ts.timeIntervalSince1970 },
            hrv:          SourceArbiter.arbitrate(hrv,          key: dailyKey),
            restingHR:    SourceArbiter.arbitrate(restingHR,    key: dailyKey),
            steps:        SourceArbiter.arbitrate(steps,        key: dailyKey),
            activeEnergy: SourceArbiter.arbitrate(activeEnergy, key: dailyKey),
            sleep:        SourceArbiter.arbitrate(sleep)        { "\($0.stage.rawValue)@\(day($0.date))" },
            // Dual-recording sessions (bike computer + watch) start seconds
            // apart, so exact-start keying misses them — FR-PROV-02 clusters by
            // time overlap instead: counted once, enriched from both.
            workouts:     WorkoutDeduplicator.dedupe(workouts).workouts,
            // Full-HealthKit streams: same §2.3 rule per logical slot.
            heartExtras:     SourceArbiter.arbitrate(heartExtras, key: dailyKey),
            insulin:         SourceArbiter.arbitrate(insulin)        { "\($0.kind.rawValue)@\($0.ts.timeIntervalSince1970)" },
            bloodPressure:   SourceArbiter.arbitrate(bloodPressure)  { $0.ts.timeIntervalSince1970 },
            afib:            SourceArbiter.arbitrate(afib)           { $0.ts.timeIntervalSince1970 },
            bodyComposition: SourceArbiter.arbitrate(bodyComposition) { day($0.ts) }
        )
    }
}

public extension HealthSamples {
    /// The merge report behind `arbitrated()`'s workout stream — what got
    /// recorded twice and folded into one (FR-PROV-02). Recomputed on demand;
    /// the UI uses this to TELL the citizen rather than silently fixing.
    func workoutMergeReport() -> [WorkoutMerge] {
        WorkoutDeduplicator.dedupe(workouts).merges
    }
}
