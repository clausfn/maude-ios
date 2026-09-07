import Testing
import Foundation
@testable import Maude

// SleepNight — the ONE-TRUTH night model (sleep visualisation wave 2026-08).
//
// THE PRIME RULE under test: every figure on any sleep surface renders from
// one resolved object per night, so the same-screen contradiction CN
// photographed (tiles "Core 7h21m" vs chart labels "16h20m") is structurally
// impossible. The suites below pin:
//   (a) type-level in-bed separation — an InBedSpan can never join an asleep
//       total; time-in-bed = the chosen source's in-bed union, or the honest
//       envelope fallback, or nil
//   (b) internal consistency + agreement — assertInternalConsistency() and
//       assertAgreement() are empty on every fixture; hero == sum of tiles
//   (c) raw ≡ arbitrated — the model is identical whether the deriver sees
//       raw samples or the arbitrated stream (naps + exclusions carried)
//   (d) the 22:00→14:00 clock axis — wall-clock positions, honest edges
//   (e) ranges — gaps are gaps; every mean states its true denominator;
//       weekly stage mix only where every contributing night is staged
//   (f) sleeping respiratory rate — descriptive per-night mean vs OWN baseline,
//       nil without data or without enough of the citizen's own days
struct SleepNightModelTests {

    private let cal = Calendar(identifier: .gregorian)

    /// Fixed anchor (Wednesday 2026-06-10, 09:00): keeps week groupings and
    /// day arithmetic deterministic whatever day or DST season the suite runs
    /// in — a −1 night is always the same calendar week as day 0 here.
    private var morning: Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))!
    }
    private func bucket(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: morning))!
    }
    /// A TIMED segment on night bucket `offset`, from `startH` to `endH` hours
    /// relative to that bucket's midnight (−1.0 ⇒ 23:00 the evening before).
    private func seg(_ stage: SleepStage, from startH: Double, to endH: Double,
                     night offset: Int = 0, source: String = "Apple Watch",
                     timed: Bool = true) -> SleepReading {
        let b = bucket(offset)
        return SleepReading(date: b, stage: stage, hours: endH - startH,
                            start: timed ? b.addingTimeInterval(startH * 3600) : nil,
                            source: source, tier: .estimate, provenance: .real)
    }
    private func inBed(from startH: Double, to endH: Double,
                       night offset: Int = 0, source: String = "Apple Watch") -> InBedSpan {
        let b = bucket(offset)
        return InBedSpan(date: b, start: b.addingTimeInterval(startH * 3600),
                         hours: endH - startH, source: source,
                         tier: .estimate, provenance: .real)
    }
    /// The reference night: 23:00 → 06:30, deep 1.2h · core 4.7h · REM 1.6h
    /// = 7.5h (450 min), one 12-min wake-up at 02:12 bridged inside core.
    private func watchNight(_ offset: Int = 0) -> [SleepReading] {
        [seg(.core, from: -1.0, to: 1.0, night: offset),
         seg(.deep, from: 1.0, to: 2.2, night: offset),
         seg(.awake, from: 2.2, to: 2.4, night: offset),
         seg(.core, from: 2.4, to: 5.1, night: offset),
         seg(.rem,  from: 5.1, to: 6.7, night: offset)]
    }
    private func lastNight(_ s: HealthSamples) throws -> SleepNight {
        try #require(SleepNightBuilder.nights(from: s, calendar: cal).last)
    }

    // MARK: (a) in-bed: separate stream, separate type, never in a total

    @Test func inBedSpansNeverEnterAsleepTotals() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        // A pathological 20h in-bed pile — if in-bed could leak into asleep
        // arithmetic anywhere, these would blow every figure up.
        s.sleepInBed = [inBed(from: -3, to: 9), inBed(from: -4, to: 8),
                        inBed(from: 9, to: 13)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 450)
        #expect(d.night.asleepMin == 450)
        #expect(SleepDeriver.derive(from: s)?.asleepMinutes == 450)
        // …and the same through the arbitrated path.
        let a = try #require(SleepDetailDeriver.derive(from: s.arbitrated(calendar: cal), now: morning))
        #expect(a.asleepMin == 450)
    }

    @Test func timeInBedIsTheChosenSourcesUnion() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        // Two spans with a 10-min break: union = 8h40m − 10m = 510 min.
        s.sleepInBed = [inBed(from: -1.2, to: 3.0), inBed(from: 3.1666666667, to: 7.4666666667)]
        let n = try lastNight(s)
        #expect(n.inBedIsFromSource)
        #expect(n.inBedMin == 510)
        let start = try #require(n.inBedStart), end = try #require(n.inBedEnd)
        #expect(abs(start.timeIntervalSince(bucket(0).addingTimeInterval(-1.2 * 3600))) < 1)
        #expect(abs(end.timeIntervalSince(bucket(0).addingTimeInterval(7.4666666667 * 3600))) < 1)
        // TIME IN BED and TIME ASLEEP are two separate figures.
        #expect(n.asleepMin == 450)
    }

    @Test func timeInBedFallsBackToTheAsleepEnvelope() throws {
        var s = HealthSamples()
        s.sleep = watchNight()          // 23:00 → 06:42 envelope incl. the wake-up
        let n = try lastNight(s)
        #expect(n.inBedIsFromSource == false)
        #expect(n.inBedMin == Int((7.7 * 60).rounded()))   // 23:00→06:42
        #expect(n.asleepMin == 450)
    }

    @Test func anotherSourcesInBedDoesNotDressTheChosenNight() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        // The phone's classic 9h in-bed span — NOT the chosen source's.
        s.sleepInBed = [inBed(from: -1.5, to: 7.5, source: "iPhone")]
        let n = try lastNight(s)
        #expect(n.inBedIsFromSource == false)       // envelope fallback instead
        #expect(n.inBedMin == Int((7.7 * 60).rounded()))
    }

    @Test func untimedNightWithoutInBedHasNoTimeInBed() throws {
        var s = HealthSamples()
        s.sleep = [seg(.deep, from: 0, to: 1.5, source: "Import", timed: false),
                   seg(.core, from: 0, to: 4, source: "Import", timed: false)]
        let n = try lastNight(s)
        #expect(n.inBedMin == nil)                  // unknowable, not defaulted
        #expect(n.asleepMin == 330)
    }

    @Test func arbitrationCarriesInBedInItsOwnStream() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        s.sleepInBed = [inBed(from: -1.2, to: 7.5)]
        let a = s.arbitrated(calendar: cal)
        #expect(a.sleepInBed.count == 1)
        #expect(a.sleep.allSatisfy { $0.stage != .inBed })
    }

    // MARK: (b) internal consistency + agreement

    @Test func theHeroEqualsTheSumOfTheTilesByConstruction() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        let n = try lastNight(s)
        #expect(n.asleepMin == n.deepMin + n.coreMin + n.remMin)
        #expect(n.deepMin == 72)
        #expect(n.remMin == 96)
        #expect(n.coreMin == 282)
        #expect(n.awakeMin == 12)
        #expect(n.assertInternalConsistency().isEmpty)
    }

    @Test func everyFixtureNightIsInternallyConsistentAndAgrees() throws {
        // The pathological bucket: second source, a nap, in-bed, an untimed
        // import night two days back.
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.asleepUnspecified, from: -1.25, to: 7.0, source: "iPhone"),
               seg(.asleepUnspecified, from: 14.5, to: 15.0),
               seg(.core, from: 0, to: 6.5, night: -1),
               seg(.deep, from: 0, to: 1.5, night: -2, source: "Import", timed: false),
               seg(.core, from: 0, to: 4.0, night: -2, source: "Import", timed: false)]
        s.sleepInBed = [inBed(from: -1.1, to: 6.8)]
        for path in [s, s.arbitrated(calendar: cal)] {
            let d = try #require(SleepDetailDeriver.derive(from: path, now: morning))
            #expect(d.assertAgreement().isEmpty)
            for n in SleepNightBuilder.nights(from: path, calendar: cal) {
                #expect(n.assertInternalConsistency().isEmpty)
            }
        }
    }

    @Test func chartLabelsAreTheTileFiguresVerbatim() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        let shape = try #require(d.shape)
        #expect(shape.soundings.first { $0.stage == 3 }?.minutes == d.deepMin)
        #expect(shape.soundings.first { $0.stage == 1 }?.minutes == d.remMin)
        #expect(shape.soundings.first { $0.stage == 2 }?.minutes == d.coreMin)
    }

    @Test func fellAsleepAndWokeUpAreTheAsleepEdges() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        let n = try lastNight(s)
        #expect(n.fellAsleepClock == "23:00")
        #expect(n.wokeUpClock == "06:42")
    }

    // MARK: (c) raw ≡ arbitrated (naps + exclusions survive arbitration)

    @Test func napsAreSeparatedAndNeverGrowTheNight() throws {
        var s = HealthSamples()
        s.sleep = watchNight() + [seg(.asleepUnspecified, from: 14.5, to: 15.0)]
        let n = try lastNight(s)
        #expect(n.asleepMin == 450)
        #expect(n.naps.count == 1)
        #expect(n.naps.first?.asleepMin == 30)
        #expect(n.naps.first?.start == bucket(0).addingTimeInterval(14.5 * 3600))
    }

    @Test func theModelIsIdenticalFromRawAndArbitratedSamples() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.asleepUnspecified, from: -1.25, to: 7.0, source: "iPhone"),
               seg(.asleepUnspecified, from: 14.5, to: 15.0)]
        s.sleepInBed = [inBed(from: -1.1, to: 6.8)]
        let raw = try lastNight(s)
        let arb = try lastNight(s.arbitrated(calendar: cal))
        #expect(raw == arb)
        #expect(raw.naps.count == 1 && arb.naps.count == 1)
        #expect(raw.excludedSources == ["iPhone"])
        #expect(arb.excludedSources == ["iPhone"])
        // Idempotence: a second arbitration changes nothing (no duplicates).
        let twice = try lastNight(s.arbitrated(calendar: cal).arbitrated(calendar: cal))
        #expect(twice == arb)
    }

    // MARK: (d) the 22:00 → 14:00 clock axis

    @Test func clockAxisPositionsAreWallClockFractions() {
        let night = bucket(0)
        func f(_ h: Double) -> Double {
            SleepClockAxis.fraction(night.addingTimeInterval(h * 3600), night: night, calendar: cal)
        }
        #expect(abs(f(-1.0) - 1.0 / 16) < 0.0001)      // 23:00 evening before
        #expect(abs(f(0) - 2.0 / 16) < 0.0001)         // midnight
        #expect(abs(f(6.0) - 8.0 / 16) < 0.0001)       // 06:00 = axis midpoint
        #expect(f(-2.5) < 0)                           // 21:30 → off the top
        #expect(f(17.0) > 1)                           // 17:00 → off the bottom
    }

    @Test func weekColumnSpansBedtimeToWakeWithHonestEdges() throws {
        var s = HealthSamples()
        s.sleep = watchNight()
        let n = try lastNight(s)
        let col = try #require(SleepClockColumn.column(for: n, calendar: cal))
        #expect(abs(col.bedFraction - 1.0 / 16) < 0.001)      // 23:00
        #expect(abs(col.wakeFraction - 8.7 / 16) < 0.001)     // 06:42
        #expect(!col.clippedTop && !col.clippedBottom)
        #expect(col.bands.count == 5)                          // awake included
        #expect(col.bands.allSatisfy { $0.y0 >= 0 && $0.y1 <= 1 && $0.y1 > $0.y0 })
    }

    @Test func shiftWorkerDaySleepIsClippedNotDragged() throws {
        // Sleeping 09:00–17:00: the wake lies beyond 14:00. The column must
        // SAY it was cut, not silently compress onto the axis.
        var s = HealthSamples()
        s.sleep = [seg(.core, from: 9, to: 13), seg(.rem, from: 13, to: 14),
                   seg(.core, from: 14, to: 17)]
        let n = try lastNight(s)
        let col = try #require(SleepClockColumn.column(for: n, calendar: cal))
        #expect(col.clippedBottom)
        #expect(col.wakeFraction > 1)
        #expect(!col.clippedTop)
        #expect(col.bands.allSatisfy { $0.y1 <= 1 })
    }

    @Test func earlyBedtimeIsClippedAtTheTop() throws {
        var s = HealthSamples()
        s.sleep = [seg(.core, from: -2.5, to: 5.0)]      // asleep from 21:30
        let n = try lastNight(s)
        let col = try #require(SleepClockColumn.column(for: n, calendar: cal))
        #expect(col.clippedTop)
        #expect(col.bedFraction < 0)
        #expect(col.bands.allSatisfy { $0.y0 >= 0 })
    }

    @Test func untimedNightsProduceNoColumn() throws {
        var s = HealthSamples()
        s.sleep = [seg(.core, from: 0, to: 7, source: "Import", timed: false)]
        let n = try lastNight(s)
        #expect(SleepClockColumn.column(for: n, calendar: cal) == nil)
    }

    /// DST fall-back (Europe/Copenhagen, 2026-10-25, clocks 03:00→02:00): a
    /// 23:00→07:00 wall-clock night is NINE real hours — the duration counts
    /// them all, but the 07:00 wake must sit at the 07:00 gridline.
    @Test func dstNightPositionsByWallClockAndCountsRealHours() throws {
        var cph = Calendar(identifier: .gregorian)
        cph.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        func date(_ d: Int, _ h: Int) -> Date {
            cph.date(from: DateComponents(timeZone: cph.timeZone, year: 2026, month: 10,
                                          day: d, hour: h))!
        }
        let start = date(24, 23), end = date(25, 7)
        var s = HealthSamples()
        s.sleep = [SleepReading(date: SleepNightRule.nightDay(start, calendar: cph),
                                stage: .asleepUnspecified,
                                hours: end.timeIntervalSince(start) / 3600, start: start,
                                source: "Apple Watch", tier: .estimate, provenance: .real)]
        let n = try #require(SleepNightBuilder.nights(from: s, calendar: cph).last)
        #expect(n.asleepMin == 540)                             // the real 9 h
        let wake = SleepClockAxis.fraction(end, night: n.date, calendar: cph)
        #expect(abs(wake - 9.0 / 16) < 0.0001)                  // wall-clock 07:00
    }

    // MARK: (e) ranges — gaps are gaps, denominators are stated

    @Test func weekRangeStatesItsTrueDenominator() throws {
        var s = HealthSamples()
        s.sleep = watchNight() + watchNight(-2) + watchNight(-5)   // 3 of 7 days
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.week.days.count == 7)
        #expect(d.week.nightsWithData == 3)
        #expect(d.week.nights.count == 3)
        #expect(d.week.columns.count == 3)
        #expect(d.week.meanAsleepMin == 450)
        #expect(d.week.meanInBedMin == Int((7.7 * 60).rounded()))
    }

    @Test func monthSlotsRenderGapsAsGaps() throws {
        var s = HealthSamples()
        s.sleep = watchNight() + watchNight(-3)
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.month.slots.count == 30)
        #expect(d.month.slots.filter(\.hasValue).count == 2)
        #expect(d.month.nightsWithData == 2)
        #expect(d.month.meanAsleepMin == 450)
        // The two recorded nights sit on their own dates; every other day is
        // nil — never zero, never interpolated.
        let recorded = Set([bucket(0), bucket(-3)])
        for slot in d.month.slots {
            #expect(slot.hasValue == recorded.contains(slot.date))
            if slot.hasValue { #expect(abs(slot.value! - 7.5) < 0.01) }
        }
        #expect(d.sixMonths.slots.count == 182)
        #expect(d.sixMonths.nightsWithData == 2)
    }

    @Test func weeklyStageMixOnlyWhereEveryNightIsStaged() throws {
        var s = HealthSamples()
        // This week: two staged nights → mix present. Two weeks back: one
        // staged + one undifferentiated → mix withheld, duration mean kept.
        s.sleep = watchNight() + watchNight(-1)
            + watchNight(-14)
            + [seg(.asleepUnspecified, from: -1, to: 6, night: -15)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        let weeks = d.month.weeks
        #expect(weeks.count >= 2)
        let staged = try #require(weeks.last)
        #expect(staged.nightCount == 2)
        #expect(staged.meanDeepMin == 72)
        #expect(staged.meanAsleepMin == 450)
        let mixed = try #require(weeks.first)
        #expect(mixed.meanDeepMin == nil)         // an honest refusal
        #expect(mixed.meanAsleepMin > 0)          // the duration story remains
    }

    // MARK: (f) sleeping respiratory rate — descriptive, own baseline only

    @Test func respiratoryRateNeedsDataAndEnoughOwnDays() throws {
        func metric(_ offset: Int, _ v: Double) -> DailyMetric {
            DailyMetric(date: bucket(offset), kind: .respiratoryRate, value: v,
                        source: "Apple Watch", tier: .good, provenance: .real)
        }
        var s = HealthSamples()
        s.sleep = watchNight()
        // No respiratory data at all → nil, never invented.
        let bare = try lastNight(s)
        #expect(bare.respiratoryRateMean == nil)

        // A value for the night but only 3 other days → mean yes, baseline no.
        s.heartExtras = [metric(0, 14.8), metric(-1, 13.9), metric(-2, 14.1), metric(-3, 14.0)]
        let thin = try lastNight(s)
        #expect(thin.respiratoryRateMean == 14.8)
        #expect(thin.respiratoryRateBaseline == nil)

        // Five other days → the OWN baseline appears (their mean, 14.0).
        s.heartExtras += [metric(-4, 13.9), metric(-5, 14.1)]
        let full = try lastNight(s)
        #expect(full.respiratoryRateMean == 14.8)
        #expect(abs((full.respiratoryRateBaseline ?? 0) - 14.0) < 0.0001)
    }

    // MARK: demo/sample streams exercise the new surfaces honestly

    @Test func mockProviderNightsCarryInBedAndStayConsistent() async throws {
        let end = Date(timeIntervalSince1970: 1_750_000_000)
        let s = try await MockDataProvider().fetchSamples(from: end.addingTimeInterval(-13 * 86_400), to: end)
        #expect(!s.sleepInBed.isEmpty)
        for n in SleepNightBuilder.nights(from: s.arbitrated(), calendar: cal) {
            #expect(n.assertInternalConsistency().isEmpty)
            #expect(n.inBedIsFromSource)
            #expect(n.inBedMin != nil)
        }
    }

    @Test func sampleDatasetSeparatesItsSaturdayNap() {
        let s = SampleDataset.samples(now: Date(timeIntervalSince1970: 1_750_000_000))
        #expect(!s.sleepInBed.isEmpty)
        #expect(!s.sleepNaps.isEmpty)                 // the Saturday naps
        let nights = SleepNightBuilder.nights(from: s, calendar: cal)
        #expect(nights.contains { !$0.naps.isEmpty })
        for n in nights { #expect(n.assertInternalConsistency().isEmpty) }
    }
}
