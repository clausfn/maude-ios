import Testing
import Foundation
@testable import Liviqa

// Regression: overlapping asleep segments from two sources (iPhone + Apple Watch)
// must be UNIONED, not summed — a real ~8h night must never read as ~16h.
// Guards SleepReading.mergedAsleepHours, the shared helper behind every nightly
// total (Home SLEEP chip, Passport, sleep breakdown, correlation grid).
struct SleepMergeTests {

    private let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    /// A segment starting `startH` hours after `base`, lasting `dur` hours.
    private func seg(_ startH: Double, dur: Double,
                     stage: SleepStage = .asleepUnspecified,
                     source: String = "watch") -> SleepReading {
        SleepReading(date: base.addingTimeInterval(startH * 3600), stage: stage,
                     hours: dur, source: source, tier: .good, provenance: .real)
    }

    @Test func fullOverlapFromTwoSourcesCountsOnce() {
        // The reported bug: iPhone and Watch both record the same 8h night.
        let segs = [seg(0, dur: 8, source: "iphone"), seg(0, dur: 8, source: "watch")]
        #expect(SleepReading.mergedAsleepHours(segs, asleep: asleep) == 8)   // not 16
    }

    @Test func adjacentSegmentsUnionToTheirSpan() {
        // [0h,4h] then [4h,8h] touch with no gap → 8h.
        let segs = [seg(0, dur: 4), seg(4, dur: 4)]
        #expect(SleepReading.mergedAsleepHours(segs, asleep: asleep) == 8)
    }

    @Test func partialOverlapIsUnionNotSum() {
        // [0h,6h] and [3h,9h] → union [0h,9h] = 9h, not 12h.
        let segs = [seg(0, dur: 6), seg(3, dur: 6)]
        #expect(SleepReading.mergedAsleepHours(segs, asleep: asleep) == 9)
    }

    @Test func disjointRunsPreserveTheGap() {
        // A genuine break between runs is kept: [0h,3h] + [5h,8h] = 6h.
        let segs = [seg(0, dur: 3), seg(5, dur: 3)]
        #expect(SleepReading.mergedAsleepHours(segs, asleep: asleep) == 6)
    }

    @Test func nonAsleepStagesAreExcluded() {
        // An overlapping awake / inBed block must not inflate the asleep union.
        let segs = [seg(0, dur: 8, stage: .asleepUnspecified),
                    seg(0, dur: 3, stage: .awake),
                    seg(0, dur: 3, stage: .inBed)]
        #expect(SleepReading.mergedAsleepHours(segs, asleep: asleep) == 8)
    }

    @Test func unorderedInputIsHandled() {
        // Helper sorts internally: later-starting segment supplied first.
        let segs = [seg(4, dur: 4), seg(0, dur: 4)]
        #expect(SleepReading.mergedAsleepHours(segs, asleep: asleep) == 8)
    }

    @Test func emptyIsZero() {
        #expect(SleepReading.mergedAsleepHours([], asleep: asleep) == 0)
    }
}
