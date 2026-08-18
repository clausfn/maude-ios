import Testing
import Foundation
@testable import Liviqa

// SleepNightResolver — the FR-SLP-10 unit (sleep incident 2026-08, RK-SLP-07):
// per night, ONE source and the MAIN sleep episode only, everything excluded
// kept for disclosure. The end-to-end failure shapes live in
// SleepPathAuditTests; this suite pins the resolver's own rules.
struct SleepNightResolverTests {

    private let cal = Calendar(identifier: .gregorian)
    private let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    private var bucket: Date { cal.startOfDay(for: Date()) }
    private func seg(_ stage: SleepStage, from startH: Double, to endH: Double,
                     source: String = "Apple Watch", timed: Bool = true,
                     dayOffset: Int = 0) -> SleepReading {
        let b = cal.date(byAdding: .day, value: dayOffset, to: bucket)!
        return SleepReading(date: b, stage: stage, hours: endH - startH,
                            start: timed ? b.addingTimeInterval(startH * 3600) : nil,
                            source: source, tier: .estimate, provenance: .real)
    }

    private func hours(_ segs: [SleepReading]) -> Double {
        SleepReading.mergedAsleepHours(segs, asleep: [.deep])
            + SleepReading.mergedAsleepHours(segs, asleep: [.rem])
            + SleepReading.mergedAsleepHours(segs, asleep: [.core, .asleepUnspecified])
    }

    // MARK: — one source per night

    @Test func stageDetailBeatsAnUndifferentiatedSpanEvenALongerOne() {
        // The phone's 9h unspecified span vs the watch's 7h staged night: the
        // staged source wins (Apple Health's default priority: the watch).
        let night = [seg(.deep, from: 0, to: 1.5), seg(.core, from: 1.5, to: 7),
                     seg(.asleepUnspecified, from: -1, to: 8, source: "iPhone")]
        let r = SleepNightResolver.resolve(night: night)
        #expect(r.chosenSource == "Apple Watch")
        #expect(abs(hours(r.night) - 7) < 0.001)
        #expect(r.excludedOtherSources.count == 1)
        #expect(r.excludedOtherSources.first?.source == "iPhone")
    }

    @Test func amongUndifferentiatedSourcesTheLargerNightWins() {
        let night = [seg(.asleepUnspecified, from: 0, to: 6, source: "AppA"),
                     seg(.asleepUnspecified, from: -1, to: 7, source: "AppB")]
        let r = SleepNightResolver.resolve(night: night)
        #expect(r.chosenSource == "AppB")
        #expect(abs(hours(r.night) - 8) < 0.001)
    }

    @Test func exactTieBreaksByNameDeterministically() {
        let night = [seg(.asleepUnspecified, from: 0, to: 7, source: "Beta"),
                     seg(.asleepUnspecified, from: 0, to: 7, source: "Alpha")]
        // Same detail, same hours → lexicographic name, stable across runs.
        #expect(SleepNightResolver.resolve(night: night).chosenSource == "Alpha")
        #expect(SleepNightResolver.resolve(night: night.reversed()).chosenSource == "Alpha")
    }

    @Test func aSourceOnlyFillsNightsTheChosenOneDoesNotCover() {
        // Watch has last night; the phone alone covers the night before (watch
        // not worn). Per-night selection keeps BOTH nights, each from its own
        // source — gap-fill across nights, never blending within one.
        let sleep = [seg(.deep, from: 0, to: 1), seg(.core, from: 1, to: 7),
                     seg(.asleepUnspecified, from: -1, to: 7.5, source: "iPhone"),
                     seg(.asleepUnspecified, from: 0, to: 6.5, source: "iPhone", dayOffset: -1)]
        let resolved = SleepNightResolver.resolvePerNight(sleep, calendar: cal)
        let byDay = Dictionary(grouping: resolved) { cal.startOfDay(for: $0.date) }
        #expect(byDay.count == 2)
        #expect(Set(byDay[bucket]!.map(\.source)) == ["Apple Watch"])
        #expect(Set(byDay[cal.date(byAdding: .day, value: -1, to: bucket)!]!.map(\.source)) == ["iPhone"])
    }

    // MARK: — main episode only

    @Test func theAwakeAnatomyOfTheNightIsKeptTheNapIsNot() {
        let night = [seg(.core, from: -1, to: 2), seg(.awake, from: 2, to: 2.3),
                     seg(.core, from: 2.3, to: 6.5),
                     seg(.asleepUnspecified, from: 14.5, to: 15.2)]   // nap
        let r = SleepNightResolver.resolve(night: night)
        #expect(r.night.contains { $0.stage == .awake })              // anatomy kept
        #expect(r.excludedOtherEpisodes.count == 1)                   // the nap
        #expect(abs(hours(r.night) - 7.2) < 0.001)
    }

    @Test func aLongDaySleepBeatsAShortNightFragment() {
        // A shift-flip day: 1.5h in the small hours, 6h in the afternoon. The
        // larger sleep IS the day's main sleep — the fragment is the extra.
        let night = [seg(.core, from: 0, to: 1.5),
                     seg(.core, from: 9, to: 15)]
        let r = SleepNightResolver.resolve(night: night)
        #expect(abs(hours(r.night) - 6) < 0.001)
        #expect(r.excludedOtherEpisodes.count == 1)
    }

    @Test func untimedSourcesAreNeverEpisodeSplit() {
        // An aggregated import carries (stage, hours) with no wall-clock times:
        // episodes cannot be told apart, so nothing is dropped on a guess.
        let night = [seg(.deep, from: 0, to: 1.5, source: "Import", timed: false),
                     seg(.core, from: 0, to: 4, source: "Import", timed: false),
                     seg(.rem, from: 0, to: 1.5, source: "Import", timed: false)]
        let r = SleepNightResolver.resolve(night: night)
        #expect(r.night.count == 3)
        #expect(abs(hours(r.night) - 7) < 0.001)
        #expect(r.excludedOtherEpisodes.isEmpty)
    }

    @Test func inBedIsNeverPartOfTheNight() {
        let night = [seg(.core, from: 0, to: 7), seg(.inBed, from: -0.5, to: 7.5)]
        let r = SleepNightResolver.resolve(night: night)
        #expect(r.night.allSatisfy { $0.stage != .inBed })
        #expect(r.excludedNonSleep.count == 1)
    }

    @Test func awakeOnlyBucketResolvesToTheAwakeSegmentsAndNoTotal() {
        let r = SleepNightResolver.resolve(night: [seg(.awake, from: 3, to: 3.5)])
        #expect(hours(r.night) == 0)
    }

    @Test func emptyIsEmpty() {
        let r = SleepNightResolver.resolve(night: [])
        #expect(r.night.isEmpty && r.chosenSource == nil)
        #expect(SleepNightResolver.resolvePerNight([], calendar: cal).isEmpty)
    }

    // MARK: — idempotence (arbitrated() + the derivers both apply the rule)

    @Test func resolvingAResolvedStreamChangesNothing() {
        let pathological: [SleepReading] =
            [seg(.core, from: -1, to: 1), seg(.deep, from: 1, to: 2.2),
             seg(.core, from: 2.2, to: 4.9), seg(.rem, from: 4.9, to: 6.5),
             seg(.asleepUnspecified, from: -1.25, to: 7, source: "iPhone"),
             seg(.asleepUnspecified, from: 14.5, to: 15, source: "Apple Watch"),
             seg(.inBed, from: -2, to: 8, source: "iPhone"),
             seg(.asleepUnspecified, from: 0, to: 6.5, source: "iPhone", dayOffset: -1),
             seg(.deep, from: 0, to: 1.5, source: "Import", timed: false, dayOffset: -2),
             seg(.core, from: 0, to: 4, source: "Import", timed: false, dayOffset: -2)]
        let once = SleepNightResolver.resolvePerNight(pathological, calendar: cal)
        let twice = SleepNightResolver.resolvePerNight(once, calendar: cal)
        #expect(once.count == twice.count)
        #expect(abs(hours(once) - hours(twice)) < 0.0001)
        #expect(once.map(\.source) == twice.map(\.source))
        // And the aggregate path agrees with the direct path.
        var s = HealthSamples(); s.sleep = pathological
        #expect(s.arbitrated(calendar: cal).sleep.count == once.count)
    }
}
