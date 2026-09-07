import Testing
import Foundation
@testable import Maude

// Day-axis alignment — the correctness rail under every chart that draws days.
//
// The defect these exist to catch: a daily series holds one entry per day THAT
// HAS DATA, so its INDEX is not a day number. Anything that drew such a series
// at evenly spaced x-positions and labelled the axis from a separately computed
// list of calendar days silently shifted every value after a gap onto the wrong
// day — the user read Saturday's number under Sunday's letter.
//
// Each test below is written so that it PASSES under date alignment and FAILS
// under the old index alignment.
struct DayAxisAlignmentTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ o: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -o, to: Date())!)
    }

    // MARK: - DaySeries primitive

    @Test func slotsPlaceEachValueOnItsOwnDayAndLeaveGapsEmpty() {
        // Readings on the oldest two days of the week and on today only.
        let values = [30.0, 40.0, 90.0]
        let dates  = [day(6), day(5), day(0)]
        let window = DaySeries.days(from: day(6), through: day(0))

        let slots = DaySeries.slots(values: values, dates: dates, over: window)

        #expect(slots.count == 7)                 // seven CALENDAR days, not three values
        #expect(slots[0].value == 30)
        #expect(slots[1].value == 40)
        // Index alignment would put 90 here. It belongs on today.
        #expect(slots[2].value == nil)
        #expect(slots[3].value == nil)
        #expect(slots[4].value == nil)
        #expect(slots[5].value == nil)
        #expect(slots[6].value == 90)
        #expect(slots[6].date == day(0))
        // A missing day is absent, never 0 — a zero would be a reading nobody took.
        #expect(slots.allSatisfy { $0.value != 0 })
    }

    @Test func alignedRefusesToPlaceAShortDatelessSeries() {
        // Four values, seven days, no dates: there is no honest mapping.
        let window = DaySeries.days(from: day(6), through: day(0))
        #expect(DaySeries.aligned(values: [61, 64, 70, 72], dates: [], over: window) == nil)
    }

    @Test func alignedAcceptsAFullLengthDatelessSeries() throws {
        // One value per day of the window ⇒ the 1:1 mapping is unambiguous.
        let window = DaySeries.days(from: day(6), through: day(0))
        let slots = try #require(
            DaySeries.aligned(values: [1, 2, 3, 4, 5, 6, 7], dates: [], over: window))
        #expect(slots.count == 7)
        #expect(slots.first?.value == 1)
        #expect(slots.last?.value == 7)
        #expect(slots.last?.date == day(0))
    }

    @Test func alignedIgnoresDatesThatDoNotPairWithValues() {
        // A desynced pair must never be trusted: no value is placed at all.
        let window = DaySeries.days(from: day(6), through: day(0))
        let slots = DaySeries.slots(values: [1, 2, 3], dates: [day(6)], over: window)
        #expect(slots.count == 7)
        #expect(slots.allSatisfy { $0.value == nil })
    }

    @Test func runsBreakAtMissingDays() {
        let window = DaySeries.days(from: day(6), through: day(0))
        let slots = DaySeries.slots(values: [10, 11, 12],
                                    dates: [day(6), day(5), day(0)], over: window)
        let runs = DaySeries.runs(slots)
        // Two stretches, not one line drawn through four absent days.
        #expect(runs.count == 2)
        #expect(runs[0].start == 0 && runs[0].values == [10, 11])
        #expect(runs[1].start == 6 && runs[1].values == [12])
    }

    @Test func daysHelpersProduceInclusiveAscendingWindows() {
        let w = DaySeries.days(from: day(6), through: day(0))
        #expect(w.count == 7)
        #expect(w.first == day(6))
        #expect(w.last == day(0))
        #expect(w == w.sorted())
        #expect(DaySeries.days(endingOn: day(0), count: 7) == w)
        // A backwards range is empty, not a crash and not a reversed guess.
        #expect(DaySeries.days(from: day(0), through: day(6)).isEmpty)
    }

    // MARK: - TrendsDeriver carries the day of every value

    private func glucoseDay(_ s: inout HealthSamples, offset: Int, tirPct: Double) {
        let inCount = Int((tirPct / 100 * 10).rounded())
        for i in 0..<10 {
            s.glucose.append(GlucoseReading(
                ts: day(offset).addingTimeInterval(Double(i) * 3600 + 6 * 3600),
                mmol: i < inCount ? 6.0 : 12.5,
                source: "cgm", tier: .good, provenance: .real))
        }
    }

    @Test func gappedTirWeekKeepsEveryValueOnItsOwnDay() throws {
        var s = HealthSamples()
        glucoseDay(&s, offset: 6, tirPct: 30)
        glucoseDay(&s, offset: 5, tirPct: 40)
        glucoseDay(&s, offset: 0, tirPct: 90)      // today, after a four-day gap

        let week = try #require(TrendsDeriver.derive(from: s)?.week)

        // Values and their days travel together, same count, ascending.
        #expect(week.tirDaily.count == week.tirDailyDates.count)
        #expect(week.tirDailyDates == [day(6), day(5), day(0)])
        #expect(week.tirDailyDates == week.tirDailyDates.sorted())

        // The chart projection is a CALENDAR axis: seven columns for seven days.
        let slots = week.tirSlots
        #expect(slots.count == 7)
        #expect(slots.first?.date == day(6))
        #expect(slots.last?.date == day(0))
        #expect(Int(slots[0].value ?? -1) == 30)
        #expect(Int(slots[1].value ?? -1) == 40)
        #expect(slots[2].value == nil)             // index alignment would put 90 here
        #expect(slots[3].value == nil)
        #expect(slots[4].value == nil)
        #expect(slots[5].value == nil)
        #expect(Int(slots[6].value ?? -1) == 90)
        // Recorded days keep their count; the axis is longer than the series.
        #expect(slots.compactMap(\.value).count == week.tirDaily.count)
    }

    @Test func tirSlotsRunThroughTheWindowEndEvenWhenReadingsStopped() throws {
        var s = HealthSamples()
        for off in 4...6 { glucoseDay(&s, offset: off, tirPct: 70) }   // stale by 4 days

        let week = try #require(TrendsDeriver.derive(from: s)?.week)
        let slots = week.tirSlots
        #expect(slots.count == 7)
        #expect(slots.last?.date == week.windowEnd)
        // The last four days carry nothing — the axis says so instead of
        // stretching three readings across the whole week.
        #expect(slots.suffix(4).allSatisfy { $0.value == nil })
        #expect(week.tirTodayPct == nil)
    }

    @Test func hrvSlotsCoverTheWholeWindowSoTheMonthCardLabelsAreTrue() throws {
        var s = HealthSamples()
        // HRV on only the most recent 10 days of the 30-day window.
        for off in 0..<10 {
            s.hrv.append(DailyMetric(date: day(off), kind: .hrvSDNN, value: 40 + Double(off),
                                     source: "watch", tier: .good, provenance: .real))
        }
        let month = try #require(TrendsDeriver.derive(from: s)?.month)

        #expect(month.hrvDaily.count == month.hrvDailyDates.count)
        #expect(month.hrvDaily.count == 10)

        // The evening card labels its axis "29 days ago → today", so the line
        // must be drawn over 30 columns with the first 20 empty.
        let slots = month.hrvSlots
        #expect(slots.count == 30)
        #expect(slots.first?.date == month.windowStart)
        #expect(slots.last?.date == month.windowEnd)
        #expect(slots.prefix(20).allSatisfy { $0.value == nil })
        #expect(slots.suffix(10).allSatisfy { $0.value != nil })
        #expect(slots.last?.value == 40)           // today's own reading, on today
    }

    @Test func windowBoundsMatchTheDeclaredWindowLength() throws {
        var s = HealthSamples()
        glucoseDay(&s, offset: 0, tirPct: 80)
        let t = try #require(TrendsDeriver.derive(from: s))
        for r in [t.week, t.month, t.quarter] {
            #expect(DaySeries.days(from: r.windowStart, through: r.windowEnd).count == r.windowDays)
            #expect(cal.isDateInToday(r.windowEnd))
        }
    }

    // MARK: - TodaySignals carries the day of every week value

    @Test func gappedWeekSignalsKeepEveryValueOnItsOwnDay() throws {
        var s = HealthSamples()
        glucoseDay(&s, offset: 6, tirPct: 30)
        glucoseDay(&s, offset: 3, tirPct: 60)
        glucoseDay(&s, offset: 0, tirPct: 90)

        let sig = try #require(TodaySignalsDeriver.derive(from: s))
        #expect(sig.inRangeWeek.count == 3)
        #expect(sig.inRangeWeekDates == [day(6), day(3), day(0)])

        let window = DaySeries.days(endingOn: day(0), count: 7)
        let slots = try #require(sig.slots(for: .inRange, over: window))
        #expect(slots.count == 7)
        #expect(Int(slots[0].value ?? -1) == 30)
        #expect(slots[1].value == nil)
        #expect(slots[2].value == nil)
        #expect(Int(slots[3].value ?? -1) == 60)   // index alignment would put 90 here
        #expect(slots[4].value == nil)
        #expect(slots[5].value == nil)
        #expect(Int(slots[6].value ?? -1) == 90)
    }

    @Test func everyWeekSeriesShipsWithMatchingDates() throws {
        var s = HealthSamples()
        for off in [6, 4, 1] {
            glucoseDay(&s, offset: off, tirPct: 70)
            s.hrv.append(DailyMetric(date: day(off), kind: .hrvSDNN, value: 45,
                                     source: "watch", tier: .good, provenance: .real))
            s.restingHR.append(DailyMetric(date: day(off), kind: .restingHR, value: 58,
                                           source: "watch", tier: .good, provenance: .real))
            s.sleep.append(SleepReading(date: day(off), stage: .core, hours: 7,
                                        source: "watch", tier: .good, provenance: .real))
        }
        let sig = try #require(TodaySignalsDeriver.derive(from: s))
        for series in TodaySignals.WeekSeries.allCases {
            #expect(sig.values(series).count == sig.dates(series).count)
            #expect(sig.dates(series) == sig.dates(series).sorted())
        }
    }

    @Test func aDatelessShortSeriesCannotBePlacedOnTheWeekAxis() {
        // The shape a fixture (or any older caller) can still produce: values
        // with no dates, fewer than the week. It must yield nil so the view
        // drops the day letters rather than labelling four values as seven days.
        let sig = TodaySignals(sleep: "7h00", inRange: "70%", hrv: "45", rhr: "58",
                               inRangeIsClay: false, inRangeWeek: [61, 64, 70, 72])
        let window = DaySeries.days(endingOn: day(0), count: 7)
        #expect(sig.slots(for: .inRange, over: window) == nil)
    }

    @Test func aDatelessFullWeekFixtureStillPlacesOneValuePerDay() throws {
        let sig = TodaySignals(sleep: "7h10", inRange: "88%", hrv: "27", rhr: "70",
                               inRangeIsClay: false,
                               inRangeWeek: [86, 86, 86, 100, 100, 100, 100])
        let window = DaySeries.days(endingOn: day(0), count: 7)
        let slots = try #require(sig.slots(for: .inRange, over: window))
        #expect(slots.count == 7)
        #expect(slots.allSatisfy { $0.value != nil })
        #expect(slots.last?.value == 100)
        #expect(slots.last?.date == day(0))
    }
}
