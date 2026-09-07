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

// MARK: — Sleep night rules (portable; sleep incident 2026-08)

/// The night a sleep segment belongs to: the day it ENDS on. Anything from
/// 18:00 onwards counts towards the next morning, which is how a person reads
/// "last night" — and how Apple's own Sleep app labels a night. Pure
/// Foundation (Android-portable); `HealthKitService.nightDay` delegates here.
public enum SleepNightRule {
    public static func nightDay(_ instant: Date,
                                calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        calendar.startOfDay(for: instant.addingTimeInterval(6 * 3600))
    }
}

/// FR-SLP-10 — per-night sleep source resolution (sleep incident 2026-08,
/// RK-SLP-07). Pure Foundation (Android-portable), no side effects.
///
/// THE DEFECT THIS KILLS (test-pinned in `SleepPathAuditTests`, red pre-fix):
/// every nightly total is the SUM of three per-stage-bucket unions (deep + REM
/// + core/unspecified) — correct for one source, whose stages partition the
/// night, but wrong across sources: an iPhone or third-party app writing one
/// undifferentiated span over a watch-staged night put the same wall-clock
/// minutes in two buckets, and a real 7.5h night derived as 11h 03m. Apple
/// Health does not union sleep across apps — it shows ONE source per night —
/// so Maude disagreed with the screen the citizen checks it against.
///
/// Rule, per night bucket:
///   1. ONE source: stage detail (deep/REM present) beats an undifferentiated
///      span (the watch over the phone, matching Health's default priority);
///      then the larger asleep total; then name, so ties are deterministic.
///   2. Main sleep episode only: an unrecorded gap longer than
///      `maxUnbridgedGapHours` splits the bucket into episodes (the ~8h gap
///      between a night and an afternoon nap) and the episode with the most
///      asleep time is the night. A recorded AWAKE segment bridges its gap, and
///      the threshold is far above a mid-night charger gap, so a real night is
///      never split. Untimed (aggregated) sources keep everything — episodes
///      cannot be told apart without wall-clock times, and dropping data on a
///      guess would be fabrication in reverse.
/// Everything excluded is REPORTED, not hidden: the diagnostics instrument
/// (FR-DIAG-01) prints each excluded segment with its reason.
public nonisolated enum SleepNightResolver {

    /// Unrecorded time between two segments of one source that splits a night
    /// bucket into separate sleep episodes. 4h: far above any tracker gap
    /// inside a real night, far below the day-time gap to a nap.
    public static let maxUnbridgedGapHours: Double = 4

    static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    /// One night bucket, resolved — with the exclusions kept for disclosure.
    public struct Resolution: Sendable {
        /// The segments the night's figures come from (asleep + awake, one
        /// source, main episode).
        public let night: [SleepReading]
        /// Same night, other sources — Apple Health shows one source per night.
        public let excludedOtherSources: [SleepReading]
        /// Chosen source, other episodes in the bucket (naps).
        public let excludedOtherEpisodes: [SleepReading]
        /// Stages that are not sleep and not the night's awake anatomy (inBed,
        /// normally already dropped at ingestion).
        public let excludedNonSleep: [SleepReading]
        public let chosenSource: String?
    }

    /// The derivers' nightly arithmetic: per-stage-bucket unions, summed.
    /// Correct for ONE source (stages partition the night; an untimed source's
    /// stage aggregates each carry their own hours).
    static func asleepHours(_ segs: [SleepReading]) -> Double {
        SleepReading.mergedAsleepHours(segs, asleep: [.deep])
            + SleepReading.mergedAsleepHours(segs, asleep: [.rem])
            + SleepReading.mergedAsleepHours(segs, asleep: [.core, .asleepUnspecified])
    }

    /// Resolve ONE night bucket's segments.
    public static func resolve(night segments: [SleepReading]) -> Resolution {
        let usable = segments.filter { asleepStages.contains($0.stage) || $0.stage == .awake }
        let nonSleep = segments.filter { !asleepStages.contains($0.stage) && $0.stage != .awake }
        guard !usable.isEmpty else {
            return Resolution(night: [], excludedOtherSources: [],
                              excludedOtherEpisodes: [], excludedNonSleep: nonSleep,
                              chosenSource: nil)
        }

        // 1 — one source per night.
        let ranked = Dictionary(grouping: usable, by: \.source)
            .map { (source: $0.key, segs: $0.value) }
            .sorted { l, r in
                let ld = l.segs.contains { ($0.stage == .deep || $0.stage == .rem) && $0.hours > 0 }
                let rd = r.segs.contains { ($0.stage == .deep || $0.stage == .rem) && $0.hours > 0 }
                if ld != rd { return ld }
                let lh = asleepHours(l.segs), rh = asleepHours(r.segs)
                if lh != rh { return lh > rh }
                return l.source < r.source
            }
        let chosen = ranked[0]
        let otherSources = ranked.dropFirst().flatMap(\.segs)

        // 2 — main sleep episode only (needs wall-clock times on every segment).
        let chosenSegs = chosen.segs.sorted { $0.intervalStart < $1.intervalStart }
        guard chosenSegs.allSatisfy({ $0.start != nil }),
              chosenSegs.contains(where: { asleepStages.contains($0.stage) && $0.hours > 0 })
        else {
            return Resolution(night: chosenSegs, excludedOtherSources: otherSources,
                              excludedOtherEpisodes: [], excludedNonSleep: nonSleep,
                              chosenSource: chosen.source)
        }
        var episodes: [[SleepReading]] = []
        var current: [SleepReading] = []
        var runEnd: Date?
        for seg in chosenSegs {
            if let end = runEnd,
               seg.intervalStart.timeIntervalSince(end) > maxUnbridgedGapHours * 3600 {
                episodes.append(current); current = []
            }
            current.append(seg)
            runEnd = max(runEnd ?? seg.intervalEnd, seg.intervalEnd)
        }
        if !current.isEmpty { episodes.append(current) }

        // The night = the episode with the most asleep time; the LATER episode
        // wins a tie (it is the one "last night" means).
        var night = episodes[0]
        var best = asleepHours(night)
        for e in episodes.dropFirst() {
            let h = asleepHours(e)
            if h >= best { night = e; best = h }
        }
        let nightStarts = Set(night.map(\.intervalStart))
        let otherEpisodes = chosenSegs.filter { !nightStarts.contains($0.intervalStart) }
        return Resolution(night: night, excludedOtherSources: otherSources,
                          excludedOtherEpisodes: otherEpisodes,
                          excludedNonSleep: nonSleep, chosenSource: chosen.source)
    }

    /// The whole stream: bucket by night, resolve each, flatten — what
    /// `arbitrated()` hands every consumer. Idempotent: resolving an already
    /// resolved stream changes nothing (one source, one episode is stable).
    public static func resolvePerNight(_ sleep: [SleepReading],
                                       calendar: Calendar) -> [SleepReading] {
        resolutions(sleep, calendar: calendar).flatMap(\.resolution.night)
    }

    /// One resolved night bucket WITH its bucket date — `resolvePerNight`
    /// keeping the resolution itself, so `arbitrated()` can carry the naps and
    /// the exclusion disclosure alongside the resolved stream instead of
    /// silently discarding them (sleep visualisation wave 2026-08).
    public struct NightResolution: Sendable {
        public let night: Date
        public let resolution: Resolution
    }

    /// Bucket by night, resolve each, keep everything. Ascending by night.
    public static func resolutions(_ sleep: [SleepReading],
                                   calendar: Calendar) -> [NightResolution] {
        guard !sleep.isEmpty else { return [] }
        let byNight = Dictionary(grouping: sleep) { calendar.startOfDay(for: $0.date) }
        return byNight.keys.sorted().map {
            NightResolution(night: $0, resolution: resolve(night: byNight[$0] ?? []))
        }
    }

    /// The distinct nap EPISODES inside a flat list of resolver-excluded
    /// same-source segments: grouped by the same unbridged-gap rule that split
    /// them from the night. Untimed segments cannot form episodes and are
    /// returned as one group only if timed grouping is impossible.
    public static func napEpisodes(_ segments: [SleepReading]) -> [[SleepReading]] {
        let timed = segments.filter { $0.start != nil }
        guard timed.count == segments.count, !segments.isEmpty else {
            return segments.isEmpty ? [] : [segments]
        }
        let sorted = segments.sorted { $0.intervalStart < $1.intervalStart }
        var episodes: [[SleepReading]] = []
        var current: [SleepReading] = []
        var runEnd: Date?
        for seg in sorted {
            if let end = runEnd,
               seg.intervalStart.timeIntervalSince(end) > maxUnbridgedGapHours * 3600 {
                episodes.append(current); current = []
            }
            current.append(seg)
            runEnd = max(runEnd ?? seg.intervalEnd, seg.intervalEnd)
        }
        if !current.isEmpty { episodes.append(current) }
        return episodes
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

        // Tier rule first (clinical > good > estimate per stage+night), then
        // ONE source per night + main-episode isolation (FR-SLP-10 — sleep
        // incident 2026-08: per-stage bucket sums double-counted overlapping
        // sources; naps joined the night). Every consumer that unions `sleep`
        // itself gets the resolved stream. The resolutions are kept so the
        // naps and the exclusion disclosure survive arbitration — carried in
        // their OWN streams (`sleepNaps`, `sleepExclusions`) that no
        // asleep-total consumer reads.
        let sleepResolutions = SleepNightResolver.resolutions(
            SourceArbiter.arbitrate(sleep) { "\($0.stage.rawValue)@\(day($0.date))" },
            calendar: calendar)
        let resolvedSleep = sleepResolutions.flatMap(\.resolution.night)
        // Naps: what the resolver split off THIS pass, plus what an earlier
        // pass already carried (idempotence) — deduplicated by identity.
        var napSeen = Set<String>()
        let mergedNaps = (sleepNaps + sleepResolutions.flatMap(\.resolution.excludedOtherEpisodes))
            .filter { napSeen.insert("\($0.source)|\($0.stage.rawValue)|\($0.intervalStart.timeIntervalSinceReferenceDate)|\($0.hours)").inserted }
        // Exclusions: union of carried + newly excluded source names per night.
        var exclusionsByNight: [Date: Set<String>] = [:]
        for e in sleepExclusions {
            exclusionsByNight[calendar.startOfDay(for: e.night), default: []].formUnion(e.excludedSources)
        }
        for r in sleepResolutions where !r.resolution.excludedOtherSources.isEmpty {
            exclusionsByNight[r.night, default: []].formUnion(r.resolution.excludedOtherSources.map(\.source))
        }
        let mergedExclusions = exclusionsByNight.keys.sorted().map {
            SleepNightExclusion(night: $0, excludedSources: exclusionsByNight[$0]!.sorted())
        }

        return HealthSamples(
            glucose:      SourceArbiter.arbitrate(glucose)      { $0.ts.timeIntervalSince1970 },
            hrv:          SourceArbiter.arbitrate(hrv,          key: dailyKey),
            restingHR:    SourceArbiter.arbitrate(restingHR,    key: dailyKey),
            steps:        SourceArbiter.arbitrate(steps,        key: dailyKey),
            activeEnergy: SourceArbiter.arbitrate(activeEnergy, key: dailyKey),
            sleep:        resolvedSleep,
            // In-bed: §2.3 tier rule per NIGHT (a clinical sleep-lab in-bed
            // beats a phone estimate for the same night; same-tier spans all
            // kept). Which SOURCE's spans make the night's time-in-bed is the
            // night model's per-night decision (the resolved source's union).
            sleepInBed:   SourceArbiter.arbitrate(sleepInBed) { day($0.date) },
            sleepNaps:    mergedNaps,
            sleepExclusions: mergedExclusions,
            // Dual-recording sessions (bike computer + watch) start seconds
            // apart, so exact-start keying misses them — FR-PROV-02 clusters by
            // time overlap instead: counted once, enriched from both.
            workouts:     WorkoutDeduplicator.dedupe(workouts).workouts,
            // Full-HealthKit streams: same §2.3 rule per logical slot.
            heartExtras:     SourceArbiter.arbitrate(heartExtras, key: dailyKey),
            // Beats inside a workout: one logical slot per instant (T-FIT-01).
            // Must be carried explicitly — a dropped stream here would silently
            // re-open the avg-HR / zones gap after arbitration.
            workoutHeartRate: SourceArbiter.arbitrate(workoutHeartRate) { $0.ts.timeIntervalSince1970 },
            insulin:         SourceArbiter.arbitrate(insulin)        { "\($0.kind.rawValue)@\($0.ts.timeIntervalSince1970)" },
            bloodPressure:   SourceArbiter.arbitrate(bloodPressure)  { $0.ts.timeIntervalSince1970 },
            afib:            SourceArbiter.arbitrate(afib)           { $0.ts.timeIntervalSince1970 },
            bodyComposition: SourceArbiter.arbitrate(bodyComposition) { day($0.ts) },
            // One logical slot per NIGHT (the reading's date IS the night
            // bucket) — a watch + a ring recording the same night arbitrate by
            // tier, never average across tiers (FR-ING-16).
            wristTemperature: SourceArbiter.arbitrate(wristTemperature) { $0.date.timeIntervalSince1970 }
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
