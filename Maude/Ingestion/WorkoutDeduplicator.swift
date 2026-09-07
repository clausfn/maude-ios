// WorkoutDeduplicator.swift — dual-recording merge (FR-PROV-02 · v01 2026-06-11)
//
// The problem, straight from the founder's own record: a single ride is logged
// by TWO devices (cycling computer → Strava and Apple Watch → HealthKit), with
// start times seconds-to-minutes apart and 1–2% disagreement on distance.
// Counting both doubles training minutes, energy, and load — the fastest way
// to lose a clinician's trust in citizen data.
//
// Rule: one physical session counts ONCE, but insights keep BOTH recordings —
// the richer device often carries physiology the other lacks (power/cadence on
// the bike computer, heart rate on the watch). So we:
//   1. CLUSTER workouts of the same type whose times overlap ≥ 60% of the
//      shorter recording (same session, two witnesses).
//   2. Pick a PRIMARY for counting: higher trust tier first, then the record
//      with more physiological payload (kcal + distance present), then the
//      longer recording.
//   3. ENRICH the primary with fields it lacks from its duplicates (e.g. the
//      watch's kcal onto the bike computer's distance) — merged, not blended:
//      each field keeps a single source of truth.
//   4. REPORT every merge so the UI can tell the citizen plainly what
//      happened ("recorded twice, counted once — insights use both").
//
// Pure Foundation (Android-portable), same contract style as SourceArbiter.
import Foundation

/// One merge event: a session that arrived as multiple recordings.
public struct WorkoutMerge: Sendable, Equatable {
    public let start: Date
    public let type: String
    /// Source kept for counting (e.g. "Strava · bike computer").
    public let kept: String
    /// Sources whose recordings were folded into the primary.
    public let merged: [String]
    /// Fields the primary gained from a duplicate ("kcal", "distance").
    public let enrichedFields: [String]
}

public struct DedupedWorkouts: Sendable {
    /// One entry per physical session — safe for counting and load math.
    public let workouts: [WorkoutReading]
    /// What was merged, for the citizen-facing disclosure.
    public let merges: [WorkoutMerge]
}

public enum WorkoutDeduplicator {

    /// Overlap of the two intervals as a share of the SHORTER one.
    static func overlapShare(_ a: WorkoutReading, _ b: WorkoutReading) -> Double {
        let lo = max(a.start.timeIntervalSince1970, b.start.timeIntervalSince1970)
        let hi = min(a.end.timeIntervalSince1970, b.end.timeIntervalSince1970)
        guard hi > lo else { return 0 }
        let shorter = min(a.end.timeIntervalSince(a.start), b.end.timeIntervalSince(b.start))
        guard shorter > 0 else { return 0 }
        return (hi - lo) / shorter
    }

    /// Richness for primary election: payload fields present.
    private static func payload(_ w: WorkoutReading) -> Int {
        (w.kcal != nil ? 1 : 0) + (w.distKm != nil ? 1 : 0)
    }

    private static func better(_ a: WorkoutReading, _ b: WorkoutReading) -> Bool {
        let ra = SourceArbiter.rank(a.tier), rb = SourceArbiter.rank(b.tier)
        if ra != rb { return ra < rb }                       // higher trust tier
        if payload(a) != payload(b) { return payload(a) > payload(b) }  // richer record
        return a.durMin > b.durMin                            // longer recording
    }

    /// Cluster same-type, time-overlapping recordings; keep one per session,
    /// enriched from its duplicates; report every merge.
    public static func dedupe(_ workouts: [WorkoutReading],
                              minOverlap: Double = 0.6) -> DedupedWorkouts {
        guard workouts.count > 1 else { return DedupedWorkouts(workouts: workouts, merges: []) }
        let sorted = workouts.sorted { $0.start < $1.start }
        var used = Array(repeating: false, count: sorted.count)
        var out: [WorkoutReading] = []
        var merges: [WorkoutMerge] = []

        for i in sorted.indices where !used[i] {
            used[i] = true
            var cluster = [sorted[i]]
            for j in sorted.indices where !used[j] && j > i {
                // Same normalized type + real time overlap with ANY member.
                guard sorted[j].type.lowercased() == sorted[i].type.lowercased() else { continue }
                if cluster.contains(where: { overlapShare($0, sorted[j]) >= minOverlap }) {
                    used[j] = true
                    cluster.append(sorted[j])
                }
            }
            guard cluster.count > 1 else { out.append(cluster[0]); continue }

            // Elect the primary, then enrich it from the duplicates.
            let primary = cluster.sorted(by: better).first!
            let duplicates = cluster.filter { $0.source != primary.source || $0.start != primary.start }
            var kcal = primary.kcal, dist = primary.distKm
            var gained: [String] = []
            for d in duplicates {
                if kcal == nil, let v = d.kcal { kcal = v; gained.append("energy · \(d.source)") }
                if dist == nil, let v = d.distKm { dist = v; gained.append("distance · \(d.source)") }
            }
            out.append(WorkoutReading(
                start: primary.start, end: primary.end, type: primary.type,
                durMin: primary.durMin, kcal: kcal, distKm: dist,
                source: primary.source, tier: primary.tier, provenance: primary.provenance))
            merges.append(WorkoutMerge(
                start: primary.start, type: primary.type, kept: primary.source,
                merged: duplicates.map(\.source), enrichedFields: gained))
        }
        return DedupedWorkouts(workouts: out.sorted { $0.start < $1.start }, merges: merges)
    }
}
