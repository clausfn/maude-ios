import Testing
import Foundation
@testable import Liviqa
#if canImport(HealthKit)
import HealthKit
#endif

// Sleep incident 2026-08 (field report: founder's own nights "brutally wrong"
// on device) — the failure-shape audit, fixture-driven, no live stores.
//
// Each test pins ONE shape against the REAL post-PR-109 derivation path:
//   (a)  multi-source double-counting (Watch + iPhone + a third app, one night)
//   (b)  an afternoon nap merged into "last night"
//   (c)  inBed vs asleep confusion
//   (d)  DST transition nights (25h / 23h days)
//   (e)  the t+6h night-bucket rule for a shift worker sleeping 09:00–17:00
//   (f)  unrecorded gaps read as sleep
//
// (a) and (b) were REAL defects (red on the pre-fix code, see RISK RK-SLP-07):
// per-stage bucket sums double-counted wall-clock minutes across sources, and
// the night bucket unioned naps into the night. Fixed by SleepNightResolver
// (one source per night, main sleep episode only — the same stance Apple
// Health takes: it picks a source per night, it does not union across apps).
struct SleepPathAuditTests {

    private let cal = Calendar(identifier: .gregorian)
    private let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    private var morning: Date { cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())! }
    private func bucket(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: morning))!
    }
    /// A TIMED segment on the night bucket `offset`, running from `startH` to
    /// `endH` hours relative to that bucket's midnight (−1.0 ⇒ 23:00 the
    /// evening before) — the exact shape `HealthKitService.readSleep` emits.
    private func seg(_ stage: SleepStage, from startH: Double, to endH: Double,
                     night offset: Int = 0, source: String = "Apple Watch") -> SleepReading {
        let b = bucket(offset)
        return SleepReading(date: b, stage: stage, hours: endH - startH,
                            start: b.addingTimeInterval(startH * 3600),
                            source: source, tier: .estimate, provenance: .real)
    }

    /// The reference night: Apple Watch, contiguous 23:00 → 06:30.
    /// deep 1.2h · REM 1.6h · core 4.7h = 7.5h asleep (450 min).
    private func watchNight(_ offset: Int = 0) -> [SleepReading] {
        [seg(.core, from: -1.0, to: 1.0, night: offset),
         seg(.deep, from: 1.0, to: 2.2, night: offset),
         seg(.core, from: 2.2, to: 4.9, night: offset),
         seg(.rem,  from: 4.9, to: 6.5, night: offset)]
    }

    // MARK: (a) multi-source double-counting

    @Test func watchPlusPhoneOverlapMustNotInflateTheNight() throws {
        // The iPhone (or a third-party app) writes ONE undifferentiated span
        // over the same night the watch staged. Before the fix, the deep and
        // REM buckets were summed ON TOP of the unspecified span that already
        // covers those minutes: 8.25 + 1.2 + 1.6 ≈ 11.05 h for a 7.5 h night.
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.asleepUnspecified, from: -1.25, to: 7.0, source: "iPhone")]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 450)          // the watch's night, once
        #expect(d.deepMin == 72)
        #expect(d.remMin == 96)
        #expect(d.coreMin == 282)
        #expect(d.source == "Apple Watch")   // the chosen source, honestly named
        let sum = try #require(SleepDeriver.derive(from: s))
        #expect(sum.asleepMinutes == 450)    // Home chip agrees with the detail screen
    }

    @Test func twoStageSourcesDisagreeingMustNotCrossCount() throws {
        // A third-party app writes its OWN stages for the same night, timed
        // differently. Per-stage unions across both sources double-count every
        // minute the two disagree on.
        var s = HealthSamples()
        s.sleep = watchNight() + [
            seg(.rem,  from: -1.0, to: 1.0, source: "SleepApp"),
            seg(.core, from: 1.0, to: 5.0, source: "SleepApp"),
            seg(.deep, from: 5.0, to: 6.5, source: "SleepApp"),
        ]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 450)          // one source's night, not a cross-sum
    }

    @Test func arbitratedSleepIsSingleSourcePerNightForEveryConsumer() {
        // TodaySignals / Trends / Correlation / NudgeEngine / Passport all
        // union s.sleep themselves — the arbitrated aggregate they consume must
        // already be one source per night, or their totals silently include the
        // phone's span (8.25h) instead of the watch's night (7.5h).
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.asleepUnspecified, from: -1.25, to: 7.0, source: "iPhone")]
        let resolved = s.arbitrated().sleep
        #expect(Set(resolved.map(\.source)) == ["Apple Watch"])
        #expect(abs(SleepReading.mergedAsleepHours(resolved, asleep: asleep) - 7.5) < 0.001)
    }

    // MARK: (b) naps merged into the night total

    @Test func afternoonNapMustNotJoinLastNight() throws {
        // A 14:30–15:00 nap lands in the SAME night bucket (t+6h rule) as the
        // night that ended 06:30 that morning. "Last night" must not grow by it.
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.asleepUnspecified, from: 14.5, to: 15.0)]      // same source
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 450)          // not 480
        let sum = try #require(SleepDeriver.derive(from: s))
        #expect(sum.asleepMinutes == 450)
    }

    @Test func napNeverStretchesTheNightShape() throws {
        // With the nap in the bucket, the drawn night must still end 06:30 —
        // not stretch its axis to 15:00.
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.asleepUnspecified, from: 14.5, to: 15.0)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        let shape = try #require(d.shape)
        #expect(shape.startClock == "23:00")
        #expect(shape.endClock == "06:30")
    }

    // MARK: (c) inBed vs asleep

    @Test func inBedNeverCountsAsSleep() throws {
        // A 9h in-bed span over a 7.5h night (the iPhone's classic contribution
        // before it is dropped at ingestion) must change nothing.
        var s = HealthSamples()
        s.sleep = watchNight()
            + [seg(.inBed, from: -1.5, to: 7.5)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 450)
        #expect(SleepDeriver.derive(from: s)?.asleepMinutes == 450)
    }

    // MARK: (d) DST transition nights (Europe/Copenhagen)

    private var cph: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return c
    }
    private func cphDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        cph.date(from: DateComponents(timeZone: cph.timeZone, year: y, month: mo,
                                      day: d, hour: h, minute: mi))!
    }
    /// Mirror of ingestion: hours from the ABSOLUTE interval, night from t+6h.
    private func hkSeg(start: Date, end: Date, stage: SleepStage = .asleepUnspecified,
                       source: String = "Apple Watch") -> SleepReading {
        SleepReading(date: SleepNightRule.nightDay(start, calendar: cph), stage: stage,
                     hours: end.timeIntervalSince(start) / 3600, start: start,
                     source: source, tier: .estimate, provenance: .real)
    }

    @Test func fallBackNightKeepsItsRealNineHours() throws {
        // 2026-10-25, clocks 03:00→02:00: a 23:00→07:00 wall-clock night is
        // NINE real hours. The derived total must be the real duration.
        let start = cphDate(2026, 10, 24, 23), end = cphDate(2026, 10, 25, 7)
        #expect(end.timeIntervalSince(start) == 9 * 3600)
        var s = HealthSamples(); s.sleep = [hkSeg(start: start, end: end)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: cphDate(2026, 10, 25, 9)))
        #expect(d.asleepMin == 540)
    }

    @Test func springForwardNightKeepsItsRealSevenHours() throws {
        // 2026-03-29, clocks 02:00→03:00: a 23:00→07:00 wall-clock night is
        // SEVEN real hours, and stays one night in one bucket.
        let start = cphDate(2026, 3, 28, 23), end = cphDate(2026, 3, 29, 7)
        #expect(end.timeIntervalSince(start) == 7 * 3600)
        var s = HealthSamples(); s.sleep = [hkSeg(start: start, end: end)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: cphDate(2026, 3, 29, 9)))
        #expect(d.asleepMin == 420)
    }

    @Test func nightBucketHoldsAcrossBothTransitions() {
        // The t+6h rule lands transition nights on the morning they end on —
        // fixed-seconds addition is safe because the jumps happen 02:00–03:00.
        #expect(SleepNightRule.nightDay(cphDate(2026, 10, 24, 23), calendar: cph)
                == cph.startOfDay(for: cphDate(2026, 10, 25, 12)))
        #expect(SleepNightRule.nightDay(cphDate(2026, 3, 28, 23, 30), calendar: cph)
                == cph.startOfDay(for: cphDate(2026, 3, 29, 12)))
        // Boundary: 17:59 belongs to the day itself, 18:00 to the next morning.
        #expect(SleepNightRule.nightDay(cphDate(2026, 8, 10, 17, 59), calendar: cph)
                == cph.startOfDay(for: cphDate(2026, 8, 10, 12)))
        #expect(SleepNightRule.nightDay(cphDate(2026, 8, 10, 18, 0), calendar: cph)
                == cph.startOfDay(for: cphDate(2026, 8, 11, 12)))
    }

    // MARK: (e) shift worker, 09:00–17:00

    @Test func shiftWorkerDaySleepsStayOneNightPerDay() throws {
        // Sleeping 09:00–17:00: t+6h buckets each sleep on its own day; three
        // consecutive day-sleeps must be three 8h nights, never merged.
        var s = HealthSamples()
        for off in [-2, -1, 0] {
            s.sleep += [seg(.core, from: 9, to: 13, night: off),
                        seg(.rem, from: 13, to: 14, night: off),
                        seg(.core, from: 14, to: 17, night: off)]
        }
        let d = try #require(SleepDetailDeriver.derive(from: s,
                                                       now: bucket(0).addingTimeInterval(18 * 3600)))
        #expect(d.nights.count == 3)
        #expect(d.nights.allSatisfy { $0.hours == 8.0 })
        #expect(d.asleepMin == 480)
    }

    // MARK: (f) gaps are never sleep

    @Test func unrecordedGapsAreNeverCountedAsSleep() throws {
        // 23:00–01:00 + 02:00–06:00: the unrecorded hour is not sleep. 6h, not 7.
        var s = HealthSamples()
        s.sleep = [seg(.core, from: -1, to: 1), seg(.core, from: 2, to: 6)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 360)
    }

    @Test func aMidNightTrackerGapDoesNotSplitTheNight() throws {
        // Watch off the wrist 00:00–02:30 (charging): both pieces are one night
        // (the gap is under the 4h episode split), the gap itself uncounted.
        var s = HealthSamples()
        s.sleep = [seg(.core, from: -2, to: 0), seg(.core, from: 2.5, to: 7.5)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: morning))
        #expect(d.asleepMin == 420)          // 2h + 5h
    }
}
