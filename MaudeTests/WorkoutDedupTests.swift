import Testing
import Foundation
@testable import Maude

// FR-PROV-02 — dual-recording workout dedup (counted once, insights from both).
// Shapes mirror the founder's real record: bike computer + watch logging the
// same ride with starts ~40 s apart and 1–2% disagreement. T-DED-01..05.
struct WorkoutDedupTests {

    private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    private func ride(start: TimeInterval, dur: Double, kcal: Double? = nil,
                      dist: Double? = nil, src: String, tier: DataTier = .estimate) -> WorkoutReading {
        WorkoutReading(start: t0.addingTimeInterval(start),
                       end: t0.addingTimeInterval(start + dur * 60),
                       type: "Cycling", durMin: dur, kcal: kcal, distKm: dist,
                       source: src, tier: tier, provenance: .simulated)
    }

    // T-DED-01 — the founder case: same ride, starts 40 s apart → one session.
    @Test func dualRecordingCountsOnce() {
        let d = WorkoutDeduplicator.dedupe([
            ride(start: 0, dur: 52, kcal: 730, src: "Apple Watch"),
            ride(start: 40, dur: 52, dist: 23.5, src: "Bike computer · Strava"),
        ])
        #expect(d.workouts.count == 1)
        #expect(d.merges.count == 1)
        #expect(d.merges[0].merged.count == 1)
    }

    // T-DED-02 — enrichment: the kept record gains the field it lacked.
    @Test func primaryEnrichedFromDuplicate() {
        let d = WorkoutDeduplicator.dedupe([
            ride(start: 0, dur: 52, kcal: 730, src: "Apple Watch"),
            ride(start: 40, dur: 53, kcal: 745, dist: 23.5, src: "Bike computer · Strava"),
        ])
        // Strava record is richer (kcal + dist) → primary; nothing to gain.
        #expect(d.workouts[0].source == "Bike computer · Strava")
        #expect(d.workouts[0].kcal != nil && d.workouts[0].distKm != nil)
        // Reverse richness: watch-only payload gains distance from duplicate.
        let d2 = WorkoutDeduplicator.dedupe([
            ride(start: 0, dur: 52, kcal: 730, src: "Apple Watch"),
            ride(start: 40, dur: 52, dist: 23.5, src: "Phone app"),
        ])
        #expect(d2.workouts[0].distKm == 23.5)
        #expect(d2.merges[0].enrichedFields.isEmpty == false)
    }

    // T-DED-03 — distinct sessions (no overlap) are never merged.
    @Test func separateSessionsKept() {
        let d = WorkoutDeduplicator.dedupe([
            ride(start: 0, dur: 45, src: "Apple Watch"),
            ride(start: 4 * 3600, dur: 45, src: "Apple Watch"),
        ])
        #expect(d.workouts.count == 2)
        #expect(d.merges.isEmpty)
    }

    // T-DED-04 — different activity types never merge even when overlapping.
    @Test func typesNeverCrossMerge() {
        var row = ride(start: 0, dur: 30, src: "Apple Watch")
        let walk = WorkoutReading(start: row.start, end: row.end, type: "Walking",
                                  durMin: 30, kcal: nil, distKm: nil,
                                  source: "Phone", tier: .estimate, provenance: .simulated)
        let d = WorkoutDeduplicator.dedupe([row, walk])
        #expect(d.workouts.count == 2)
        _ = row
    }

    // T-DED-05 — higher trust tier wins the primary election regardless of payload.
    @Test func tierBeatsPayload() {
        let d = WorkoutDeduplicator.dedupe([
            ride(start: 0, dur: 52, kcal: 730, dist: 23.5, src: "Consumer app", tier: .estimate),
            ride(start: 30, dur: 52, src: "Clinic ergometer", tier: .clinical),
        ])
        #expect(d.workouts[0].source == "Clinic ergometer")
        // ...but still gains the consumer record's payload (merged, not blended).
        #expect(d.workouts[0].kcal == 730)
    }
}
