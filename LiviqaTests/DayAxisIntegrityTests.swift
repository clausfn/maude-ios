import Testing
import Foundation
@testable import Liviqa

// RK-CHART-01 — the day axis must not lie.
//
// A value sits on its REAL date. A day with nothing recorded renders as
// absence: never a zero, never interpolated, and never by shrinking the axis
// so the remaining values slide together and read as consecutive days.
//
// Three live instances of the shrink were fixed on 2026-08-19, all found by
// the same question ("what does this chart do with a day that has no data?"):
//
//   1. Sleep W — the duration fallback drew only nights that HAD data, so a
//      Mon/Wed/Fri week rendered as three adjacent bars.
//   2. Activity — `series()` compactMap-ped absent days out of the week, so
//      steps and active energy did the same.
//   3. Fitness — a week with no workouts was dropped from the 4-week load
//      buckets, which hid a REST WEEK entirely: the one thing a training-load
//      chart most needs to show.
//
// The fitness case carries the distinction the other two do not: inside the
// recorded span, "no workouts" is a real measured ZERO and must keep its slot;
// only weeks BEFORE the first recorded workout are genuinely absent.
struct DayAxisIntegrityTests {

    private let cal = Calendar(identifier: .gregorian)
    private var now: Date { cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())! }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }

    // MARK: - 1. Sleep W duration fallback

    /// Untimed nights (an importer that recorded totals but no clocks) take the
    /// duration fallback, because no night can produce a clock column. Those
    /// bars must still stand on the real 7-day axis.
    @Test func sleepWeekFallbackKeepsTheSevenDayAxis() throws {
        var s = HealthSamples()
        for off in [0, -2, -4] {                       // three non-consecutive nights
            s.sleep.append(SleepReading(date: day(off), stage: .core, hours: 4.0,
                                        source: "Import", tier: .estimate, provenance: .real))
            s.sleep.append(SleepReading(date: day(off), stage: .deep, hours: 1.5,
                                        source: "Import", tier: .estimate, provenance: .real))
        }
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        let m = SleepDetailView.Model(derived: d)

        // No night carries clock times, so this really is the fallback path.
        #expect(m.weekClock == nil)
        #expect(m.nights.count == 3)                   // the recorded nights (statistics)

        // …and the DRAWN axis is still the whole week.
        #expect(m.weekBars.count == 7)
        #expect(m.weekBars.compactMap(\.hours).count == 3)
        // Nights sit at −4, −2 and 0 ⇒ axis indices 2, 4 and 6.
        for (i, bar) in m.weekBars.enumerated() {
            let shouldHaveData = [2, 4, 6].contains(i)
            #expect((bar.hours != nil) == shouldHaveData,
                    "axis slot \(i) (\(bar.label)) should \(shouldHaveData ? "carry" : "not carry") a night")
        }
        // A gap is nil — never a zero that would draw a floor-height bar.
        #expect(m.weekBars.allSatisfy { $0.hours == nil || $0.hours! > 0 })
        // Each slot carries its OWN day's weekday letter, in order — the last
        // slot is today. (Letters repeat: S M T W T F S. Position, not the
        // letter, is what carries the date.)
        let symbols = cal.veryShortWeekdaySymbols
        let expected = (-6...0).map { off in
            symbols[(cal.component(.weekday, from: day(off)) - 1) % symbols.count]
        }
        #expect(m.weekBars.map(\.label) == expected)
    }

    // MARK: - 2. Activity steps + energy

    @Test func activityWeekSeriesSitsOnTheRealDayAxis() throws {
        func steps(_ v: Double, day off: Int) -> DailyMetric {
            DailyMetric(date: day(off), kind: .steps, value: v,
                        source: "iPhone", tier: .good, provenance: .real)
        }
        var s = HealthSamples()
        s.steps = [steps(9000, day: 0), steps(7000, day: -3), steps(8000, day: -6)]
        let d = try #require(ActivityDeriver.derive(from: s, now: now))

        #expect(d.stepsWeek == [8000, nil, nil, 7000, nil, nil, 9000])
        #expect(d.stepsLabels.count == 7)
        // The statistics still count only the days that were recorded.
        #expect(d.weekStepsTotal == 24000)
        #expect(d.longestDaySteps == 9000)
    }

    /// Active energy is absent entirely when nothing was recorded — an empty
    /// series, not seven nils, so the card can tell "no data" from "gaps".
    @Test func activityEnergyStaysEmptyWhenNothingWasRecorded() throws {
        func steps(_ v: Double, day off: Int) -> DailyMetric {
            DailyMetric(date: day(off), kind: .steps, value: v,
                        source: "iPhone", tier: .good, provenance: .real)
        }
        var s = HealthSamples()
        s.steps = [steps(9000, day: 0), steps(7000, day: -1)]
        let d = try #require(ActivityDeriver.derive(from: s, now: now))
        #expect(d.kcalWeek.isEmpty)
        #expect(d.kcalLabels.isEmpty)
        #expect(d.weekKcalTotal == nil)
    }

    // MARK: - 3. Fitness training load — a rest week is a measurement

    @Test func fitnessRestWeekKeepsItsSlotAndPreRecordWeeksStayAbsent() throws {
        func ride(day off: Int) -> WorkoutReading {
            let start = cal.date(bySettingHour: 17, minute: 0, second: 0, of: day(off))!
            return WorkoutReading(start: start, end: start.addingTimeInterval(3600),
                                  type: "Cycling", durMin: 60, kcal: 480, distKm: 20,
                                  source: "Watch", tier: .estimate, provenance: .real)
        }
        var s = HealthSamples()
        s.workouts = [ride(day: -25), ride(day: -1)]   // oldest bucket + this week
        let d = try #require(FitnessDeriver.derive(from: s, now: now))

        #expect(d.loadWeeks.count == 4)
        #expect(d.loadWeeks.map(\.label) == ["W1", "W2", "W3", "now"])
        // W2 and W3 sit INSIDE the recorded span with no workouts — real rest
        // weeks, which must stay visible at zero rather than vanish.
        #expect(d.loadWeeks[1].points == 0)
        #expect(d.loadWeeks[2].points == 0)
        #expect(d.loadWeeks[0].points ?? 0 > 0)
        #expect(d.loadWeeks[3].points ?? 0 > 0)
    }

    @Test func fitnessWeeksBeforeTheFirstWorkoutAreAbsentNotZero() throws {
        func ride(day off: Int) -> WorkoutReading {
            let start = cal.date(bySettingHour: 17, minute: 0, second: 0, of: day(off))!
            return WorkoutReading(start: start, end: start.addingTimeInterval(3600),
                                  type: "Cycling", durMin: 60, kcal: 480, distKm: 20,
                                  source: "Watch", tier: .estimate, provenance: .real)
        }
        var s = HealthSamples()
        s.workouts = [ride(day: -2)]                   // the record starts this week
        let d = try #require(FitnessDeriver.derive(from: s, now: now))

        #expect(d.loadWeeks.count == 4)
        // Nothing was recorded then — claiming a zero would invent a rest week
        // the citizen never had.
        #expect(d.loadWeeks[0].points == nil)
        #expect(d.loadWeeks[1].points == nil)
        #expect(d.loadWeeks[2].points == nil)
        #expect(d.loadWeeks[3].points ?? 0 > 0)
    }

    // MARK: - 4. The copy may not overclaim

    /// The bedtime card compares against the citizen's own usual — but the same
    /// SCREEN carries a sleep score whose Rest and Depth legs divide by fixed
    /// references (8 hours, a 35% deep-and-REM share), and the See-why panel
    /// says so out loud. A footnote claiming the PAGE holds no recommended hour
    /// was therefore false on its own screen.
    @Test func bedtimeFootnoteDoesNotOverclaimForTheWholePage() throws {
        let src = try String(contentsOfFile: Self.sleepViewPath, encoding: .utf8)
        #expect(!src.contains("no recommended hour on this page"),
                "the sleep score's Rest leg divides by 8 hours — the page-wide claim is false")
    }

    private static let sleepViewPath: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()               // LiviqaTests/
            .deletingLastPathComponent()               // repo root
            .appendingPathComponent("Liviqa/Views/SleepDetailView.swift").path
    }()
}

// MARK: - The day replay stands on the clock, not on the reading count

/// `DayReplay.Point` carries the real hour of every reading, and the replay
/// chart used to ignore it — spacing points evenly by index while labelling the
/// scrub handle "00:00 → now". A morning of six readings and an afternoon of
/// one therefore drew as an evenly paced day, and the handle's position
/// asserted a clock time the reading did not have.
struct DayReplayAxisTests {

    private func pt(_ hour: Double, _ mmol: Double = 6.0) -> DayReplay.Point {
        DayReplay.Point(hour: hour, mmol: mmol,
                        timeText: String(format: "%02d:00", Int(hour)))
    }

    /// Readings clustered in the morning must sit in the LEFT part of the axis,
    /// not spread evenly across it.
    @Test func pointsSitAtTheirOwnClockPosition() {
        // 07:00, 08:00, 09:00 … then one at 20:00.
        let pts = [pt(7), pt(8), pt(9), pt(20)]

        #expect(DayReplayChart.fraction(in: pts, of: 0) == 0)       // first ⇒ left edge
        #expect(DayReplayChart.fraction(in: pts, of: 3) == 1)       // last  ⇒ right edge

        // The 08:00 reading is 1 hour into a 13-hour span — near the left,
        // NOT a third of the way across as index spacing would place it.
        let f1 = DayReplayChart.fraction(in: pts, of: 1)
        #expect(abs(f1 - 1.0 / 13.0) < 0.0001)
        #expect(f1 < 0.2)
    }

    /// Dragging to the middle of the axis lands on the middle of the DAY.
    @Test func scrubbingResolvesByClockNotByReadingCount() {
        let pts = [pt(7), pt(8), pt(9), pt(20)]
        // Midpoint of 07:00–20:00 is 13:30; the nearest reading is 09:00 (idx 2),
        // not the middle reading of four.
        #expect(DayReplayChart.nearestIndex(in: pts, toFraction: 0.5) == 2)
        #expect(DayReplayChart.nearestIndex(in: pts, toFraction: 0) == 0)
        #expect(DayReplayChart.nearestIndex(in: pts, toFraction: 1) == 3)
    }

    /// Readings sharing a timestamp must not produce a zero-width axis.
    @Test func anInstantaneousSpanNeverDividesByZero() {
        let pts = [pt(9), pt(9)]
        let span = DayReplayChart.hourSpan(pts)
        #expect(span.hi > span.lo)
        #expect(DayReplayChart.fraction(in: pts, of: 1).isFinite)
    }
}
