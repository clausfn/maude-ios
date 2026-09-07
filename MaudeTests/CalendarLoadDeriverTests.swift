import Testing
import Foundation
@testable import Maude

// FR-CTX-CAL-01 — calendar DENSITY as a signal. T-CAL-01.
//
// Two things are being proved here: the arithmetic is right (a night that
// crosses midnight, two meetings booked over each other, a run with a five
// minute gap), and the honesty rules hold — an absent day is absent, an empty
// calendar is not a week of quiet days, and no comparison is made before there
// is a personal usual to compare against.
struct CalendarLoadDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    private var day0: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_760_000_000)) }
    private func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: day0)! }

    /// An interval on `d` from hh:mm for `minutes`.
    private func slot(_ d: Date, _ h: Int, _ m: Int, minutes: Int,
                      allDay: Bool = false, busy: Bool = true) -> ScheduledInterval {
        let start = cal.date(byAdding: .minute, value: h * 60 + m, to: d)!
        return ScheduledInterval(start: start, end: start.addingTimeInterval(Double(minutes) * 60),
                                 isAllDay: allDay, isBusy: busy)
    }

    // MARK: - The six numbers

    @Test func countsHoursAsAUnionNotASum() {
        // 09:00–11:00 and 10:00–12:00 overlap: three hours occupied, not four.
        let load = CalendarLoadDeriver.day(day0, from: [
            slot(day0, 9, 0, minutes: 120),
            slot(day0, 10, 0, minutes: 120),
        ], calendar: cal)
        #expect(load.eventCount == 2)
        #expect(load.scheduledHours == 3)
        #expect(load.longestRunHours == 3)
    }

    @Test func backToBackRunJoinsShortGapsAndBreaksOnRealOnes() {
        // 09:00–10:00, 10:05–11:00 (5-min gap → one run), then 14:00–15:00.
        let load = CalendarLoadDeriver.day(day0, from: [
            slot(day0, 9, 0, minutes: 60),
            slot(day0, 10, 5, minutes: 55),
            slot(day0, 14, 0, minutes: 60),
        ], calendar: cal)
        // 60 + 55 + 60 = 175 minutes. The five-minute gap is a gap for the
        // hours count and NOT a gap for the run count — that is the whole point.
        #expect(load.scheduledHours == 2.92)
        #expect(load.longestRunHours == 2)         // 09:00 → 11:00 counts as one run
    }

    @Test func freeWakingHoursCountsOnlyInsideTheWindow() {
        // One 06:00–08:00 meeting: only 07:00–08:00 lands inside 07:00–23:00.
        let load = CalendarLoadDeriver.day(day0, from: [slot(day0, 6, 0, minutes: 120)], calendar: cal)
        #expect(load.scheduledHours == 2)
        #expect(load.freeWakingHours == 15)        // 16 hours of window minus 1
    }

    @Test func earliestAndLatestAreMinutesAfterLocalMidnight() {
        let load = CalendarLoadDeriver.day(day0, from: [
            slot(day0, 8, 30, minutes: 30),
            slot(day0, 17, 0, minutes: 45),
        ], calendar: cal)
        #expect(load.earliestStartMinute == 8 * 60 + 30)
        #expect(load.latestEndMinute == 17 * 60 + 45)
    }

    @Test func anEventCrossingMidnightIsClippedToEachDayItOccupies() {
        // 23:00 → 01:00 next day.
        let interval = slot(day0, 23, 0, minutes: 120)
        let first = CalendarLoadDeriver.day(day0, from: [interval], calendar: cal)
        let second = CalendarLoadDeriver.day(day(1), from: [interval], calendar: cal)
        #expect(first.scheduledHours == 1)
        #expect(second.scheduledHours == 1)
        #expect(second.earliestStartMinute == 0)
        // ...and never lands on a day it does not touch.
        #expect(CalendarLoadDeriver.day(day(2), from: [interval], calendar: cal).eventCount == 0)
    }

    @Test func allDayAndFreeEntriesCarryNoLoad() {
        let load = CalendarLoadDeriver.day(day0, from: [
            slot(day0, 0, 0, minutes: 1440, allDay: true),      // a holiday
            slot(day0, 9, 0, minutes: 60, busy: false),         // marked available
        ], calendar: cal)
        #expect(load.eventCount == 0)
        #expect(load.scheduledHours == 0)
        #expect(load.freeWakingHours == 16)
    }

    @Test func anEmptyDayIsZeroesNotAbsence() {
        let load = CalendarLoadDeriver.day(day0, from: [], calendar: cal)
        #expect(load.isEmptyDay)
        #expect(load.earliestStartMinute == nil)
        #expect(load.latestEndMinute == nil)
        #expect(load.freeWakingHours == 16)
    }

    // MARK: - Honest absence

    @Test func anEntirelyEmptyCalendarIsNoDataNotAQuietWeek() {
        let history = (0..<7).map { CalendarLoadDeriver.day(day(-$0), from: [], calendar: cal) }
        #expect(CalendarLoadDeriver.isEntirelyEmpty(history))
        #expect(!CalendarLoadDeriver.hasUsableBaseline(history))
        let state = CorrelationDeriver.calendarRowState(connected: true, history: history)
        #expect(state == .noEntriesAtAll)
        let cells = CorrelationDeriver.calendarCells(history: history,
                                                     over: (0..<7).map { day(-$0) },
                                                     connected: true, calendar: cal)
        #expect(cells.allSatisfy { $0 == .noData })
    }

    @Test func twoDaysOfHistoryMakeNoClaimAboutAUsual() {
        let history = [
            CalendarLoadDeriver.day(day(-1), from: [slot(day(-1), 9, 0, minutes: 120)], calendar: cal),
            CalendarLoadDeriver.day(day0, from: [slot(day0, 9, 0, minutes: 60)], calendar: cal),
        ]
        #expect(CorrelationDeriver.calendarRowState(connected: true, history: history)
                == .calibrating(daysSoFar: 2))
        #expect(CorrelationDeriver.calendarUsual(history) == nil)
        let cells = CorrelationDeriver.calendarCells(history: history, over: [day(-1), day0],
                                                     connected: true, calendar: cal)
        #expect(cells.allSatisfy { $0 == .noData })
    }

    @Test func notConnectedIsAlwaysAnEmptyRow() {
        let history = busyWeek()
        #expect(CorrelationDeriver.calendarRowState(connected: false, history: history) == .notConnected)
        let cells = CorrelationDeriver.calendarCells(history: history, over: (0..<7).map { day(-$0) },
                                                     connected: false, calendar: cal)
        #expect(cells.allSatisfy { $0 == .noData })
    }

    @Test func aDayNeverReadIsNoDataAndNeverAZero() {
        // Three days of history, seven columns on screen.
        let history = (0..<3).map {
            CalendarLoadDeriver.day(day(-$0), from: [slot(day(-$0), 9, 0, minutes: 60 * ($0 + 1))],
                                    calendar: cal)
        }
        let dates = (0..<7).map { day(-$0) }.sorted()
        let cells = CorrelationDeriver.calendarCells(history: history, over: dates,
                                                     connected: true, calendar: cal)
        #expect(cells.count == 7)
        // The four oldest columns were never read.
        #expect(cells.prefix(4).allSatisfy { $0 == .noData })
        #expect(cells.suffix(3).allSatisfy { $0 != .noData })
    }

    // MARK: - Personal-baseline deviation

    /// Six ordinary ~2-hour days and one 9-hour day.
    private func busyWeek() -> [CalendarDayLoad] {
        (0..<7).map { off -> CalendarDayLoad in
            let d = day(-off)
            let minutes = (off == 2) ? 540 : 120
            return CalendarLoadDeriver.day(d, from: [slot(d, 9, 0, minutes: minutes)], calendar: cal)
        }
    }

    @Test func theFullestDayIsTheOneThatStandsOut() {
        let history = busyWeek()
        let dates = (0..<7).map { day(-$0) }.sorted()
        let cells = CorrelationDeriver.calendarCells(history: history, over: dates,
                                                     connected: true, calendar: cal)
        let standout = dates.firstIndex(of: day(-2))!
        #expect(cells[standout] == .outlier)
        #expect(cells.enumerated().allSatisfy { i, c in i == standout || c == .low || c == .medium })
    }

    /// A week that actually varies: 1, 2, 3, 4, 5, 9 and 0 booked hours. The
    /// clear day sits INSIDE the used stretch, not in front of it — a leading
    /// empty day means "not kept here yet" and is excluded from the baseline
    /// (see `daysBeforeTheFirstEntryAreAbsenceNotQuietDays`).
    private func variedWeek() -> [CalendarDayLoad] {
        let hours = [1, 2, 3, 4, 5, 9, 0]
        return (0..<7).map { i -> CalendarDayLoad in
            let d = day(i - 6)                       // oldest first, today last
            let mins = hours[i] * 60
            return CalendarLoadDeriver.day(
                d, from: mins == 0 ? [] : [slot(d, 9, 0, minutes: mins)], calendar: cal)
        }
    }

    @Test func directionIsAgainstThisPersonsOwnUsual() {
        let history = variedWeek()
        let usual = CorrelationDeriver.calendarUsual(history)
        #expect(usual != nil)
        let full = CorrelationDeriver.calendarLoad(for: day(-1), in: history, calendar: cal)!    // 9 h
        let clear = CorrelationDeriver.calendarLoad(for: day(0), in: history, calendar: cal)!     // 0 h
        let ordinary = CorrelationDeriver.calendarLoad(for: day(-4), in: history, calendar: cal)! // 3 h
        #expect(CorrelationDeriver.calendarDirection(full, usual: usual) == .busier)
        #expect(CorrelationDeriver.calendarDirection(clear, usual: usual) == .quieter)
        // A day near this person's own mean is neither — no drama is invented
        // out of an ordinary Tuesday.
        #expect(CorrelationDeriver.calendarDirection(ordinary, usual: usual) == .likeUsual)
        // No usual ⇒ no direction. A comparison is never invented.
        #expect(CorrelationDeriver.calendarDirection(full, usual: nil) == nil)
    }

    @Test func daysBeforeTheFirstEntryAreAbsenceNotQuietDays() {
        // A refresh reads the whole 28-day window at once. Someone who started
        // keeping this calendar four days ago gets a run of empty days in front
        // of the real ones — averaging those in would make an ordinary week
        // read as "fuller than your usual" for a month.
        var history: [CalendarDayLoad] = (0..<10).map {
            CalendarLoadDeriver.day(day(-13 + $0), from: [], calendar: cal)   // -13 … -4, never kept
        }
        history += (0..<4).map { i -> CalendarDayLoad in
            let d = day(i - 3)
            return CalendarLoadDeriver.day(d, from: [slot(d, 9, 0, minutes: 120)], calendar: cal)
        }
        let window = CalendarLoadDeriver.baselineWindow(history)
        #expect(window.count == 4)
        #expect(cal.isDate(window.first!.dayStart, inSameDayAs: day(-3)))
        // The usual is 2 h — the real days — not 0.57 h with ten blanks folded in.
        #expect(CorrelationDeriver.calendarUsual(history)!.mean == 2)
        // …and a day before the first entry is never drawn, in either surface.
        #expect(CorrelationDeriver.calendarLoad(for: day(-9), in: history, calendar: cal) == nil)
        let dates = (0..<7).map { day(-$0) }.sorted()
        let cells = CorrelationDeriver.calendarCells(history: history, over: dates,
                                                     connected: true, calendar: cal)
        #expect(cells.prefix(3).allSatisfy { $0 == .noData })   // -6, -5, -4
        #expect(cells.suffix(4).allSatisfy { $0 != .noData })   // -3 … 0
    }

    @Test func anEmptyDayInsideTheUsedStretchIsStillRealData() {
        // A genuinely clear Sunday between busy days IS data about the person.
        let hours = [2, 3, 0, 2, 3]
        let history = (0..<5).map { i -> CalendarDayLoad in
            let d = day(i - 4)
            return CalendarLoadDeriver.day(
                d, from: hours[i] == 0 ? [] : [slot(d, 9, 0, minutes: hours[i] * 60)], calendar: cal)
        }
        #expect(CalendarLoadDeriver.baselineWindow(history).count == 5)
        #expect(CorrelationDeriver.calendarLoad(for: day(-2), in: history, calendar: cal)?.eventCount == 0)
    }

    @Test func theCalendarColumnIsTheSixthOne() {
        #expect(CorrelationDeriver.calendarIndex == 5)
        #expect(CorrelationDeriver.signalLabels[CorrelationDeriver.calendarIndex] == "calendar")
    }

    @Test func theHealthSampleGridStillNeverFabricatesTheCalendarColumn() {
        // `derive(from:)` sees HealthSamples only — it must keep emitting noData
        // for calendar, because the real signal comes from a separate consent.
        var s = HealthSamples()
        for off in 0...6 {
            s.hrv.append(DailyMetric(date: day(-off), kind: .hrvSDNN, value: 55,
                                     source: "watch", tier: .good, provenance: .real))
        }
        let grid = CorrelationDeriver.derive(from: s)
        #expect(grid.rows.allSatisfy { $0.cells[CorrelationDeriver.calendarIndex] == .noData })
    }

    // MARK: - Store (account-scoped, opt-in, revocable)

    private func tempBase() -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("cal-load-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    @Test func nothingIsStoredUntilTheCitizenOptsIn() {
        let base = tempBase()
        #expect(CalendarLoadStore.isOptedIn(forAccount: "acct-a", base: base) == false)
        // A write cannot start collection.
        #expect(CalendarLoadStore.replaceDays(busyWeek(), forAccount: "acct-a", base: base) == false)
        #expect(CalendarLoadStore.load(forAccount: "acct-a", base: base) == nil)
        // No account scope ⇒ no path ⇒ nothing written.
        #expect(CalendarLoadStore.optIn(forAccount: nil, base: base) == false)
    }

    @Test func oneAccountNeverOpensAnothersCalendarNumbers() {
        let base = tempBase()
        CalendarLoadStore.optIn(forAccount: "acct-a", base: base)
        CalendarLoadStore.replaceDays(busyWeek(), forAccount: "acct-a", base: base)
        #expect(CalendarLoadStore.load(forAccount: "acct-a", base: base)?.days.count == 7)
        // A different account on the same device starts empty.
        #expect(CalendarLoadStore.load(forAccount: "acct-b", base: base) == nil)
        #expect(CalendarLoadStore.isOptedIn(forAccount: "acct-b", base: base) == false)
        // The id never lands on disk in the clear.
        #expect(CalendarLoadStore.url(forAccount: "acct-a", base: base)!.path.contains("acct-a") == false)
    }

    @Test func disconnectStopsCollectionAndDeletesWhatWasCollected() {
        let base = tempBase()
        CalendarLoadStore.optIn(forAccount: "acct-a", base: base)
        CalendarLoadStore.replaceDays(busyWeek(), forAccount: "acct-a", base: base)
        CalendarLoadStore.disconnect(forAccount: "acct-a", base: base)
        #expect(CalendarLoadStore.load(forAccount: "acct-a", base: base) == nil)
        #expect(CalendarLoadStore.isOptedIn(forAccount: "acct-a", base: base) == false)
        // And a later write cannot resurrect collection on its own.
        #expect(CalendarLoadStore.replaceDays(busyWeek(), forAccount: "acct-a", base: base) == false)
    }

    @Test func eraseRemovesEveryAccountsCalendarScope() {
        let base = tempBase()
        for id in ["acct-a", "acct-b"] {
            CalendarLoadStore.optIn(forAccount: id, base: base)
            CalendarLoadStore.replaceDays(busyWeek(), forAccount: id, base: base)
        }
        CalendarLoadStore.eraseAll(base: base)
        #expect(CalendarLoadStore.load(forAccount: "acct-a", base: base) == nil)
        #expect(CalendarLoadStore.load(forAccount: "acct-b", base: base) == nil)
    }

    @Test func historyIsCappedToTheRollingWindow() {
        let base = tempBase()
        CalendarLoadStore.optIn(forAccount: "acct-a", base: base)
        let many = (0..<60).map { CalendarLoadDeriver.day(day(-$0), from: [], calendar: cal) }
        CalendarLoadStore.replaceDays(many, forAccount: "acct-a", base: base)
        let stored = CalendarLoadStore.load(forAccount: "acct-a", base: base)!.days
        #expect(stored.count == CalendarLoadDeriver.historyDays)
        // Kept the most recent ones, oldest first.
        #expect(stored.first!.dayStart < stored.last!.dayStart)
        #expect(cal.isDate(stored.last!.dayStart, inSameDayAs: day0))
    }

    // MARK: - Refresh, against fakes only
    //
    // No test in this target may construct a live `EKEventStore`: the calendar
    // TCC dialog blocks a headless test host forever. Everything platform-shaped
    // goes through the injected `Environment`, and `T-CAL-02` proves the live
    // read seam exists in exactly one production file.

    /// A fake environment: the given access state, the given intervals, and a
    /// flag proving whether the read was ever attempted.
    private final class ReadWitness { var didRead = false }
    private func fakeEnv(_ state: CalendarAccessState,
                         intervals: [ScheduledInterval] = [],
                         witness: ReadWitness? = nil) -> CalendarLoadIngestor.Environment {
        .init(accessState: { state },
              intervals: { _, _ in witness?.didRead = true; return intervals })
    }

    @Test func refreshRefusesToCollectWithoutAnOptIn() {
        let base = tempBase()
        let witness = ReadWitness()
        // No account scope ⇒ false, and the calendar is never even read.
        #expect(CalendarLoadIngestor.refresh(accountID: nil,
                                             environment: fakeEnv(.fullAccess, witness: witness),
                                             base: base) == false)
        // An account that never opted in ⇒ same.
        #expect(CalendarLoadIngestor.refresh(accountID: "acct-a",
                                             environment: fakeEnv(.fullAccess, witness: witness),
                                             base: base) == false)
        #expect(witness.didRead == false)
        #expect(CalendarLoadStore.load(forAccount: "acct-a", base: base) == nil)
    }

    @Test func refreshRefusesWithoutFullAccessEvenWhenOptedIn() {
        let base = tempBase()
        CalendarLoadStore.optIn(forAccount: "acct-a", base: base)
        for state in [CalendarAccessState.notDetermined, .denied, .restricted, .writeOnly] {
            let witness = ReadWitness()
            #expect(CalendarLoadIngestor.refresh(accountID: "acct-a",
                                                 environment: fakeEnv(state, witness: witness),
                                                 base: base) == false)
            // Refusal means the read is not attempted at all — not "read and
            // discarded". Nothing may touch events iOS has not granted.
            #expect(witness.didRead == false)
        }
        #expect(CalendarLoadStore.load(forAccount: "acct-a", base: base)?.days.isEmpty == true)
    }

    @Test func refreshDerivesAndStoresTheRollingWindow() {
        let base = tempBase()
        CalendarLoadStore.optIn(forAccount: "acct-a", base: base)
        // Two meetings yesterday, one today.
        let intervals = [
            slot(day(-1), 9, 0, minutes: 60),
            slot(day(-1), 10, 5, minutes: 55),
            slot(day0, 14, 0, minutes: 30),
        ]
        let ok = CalendarLoadIngestor.refresh(accountID: "acct-a",
                                              now: day0.addingTimeInterval(15 * 3600),
                                              calendar: cal,
                                              environment: fakeEnv(.fullAccess, intervals: intervals),
                                              base: base)
        #expect(ok)
        let stored = CalendarLoadStore.load(forAccount: "acct-a", base: base)!.days
        #expect(stored.count == CalendarLoadDeriver.historyDays)
        let yesterday = stored.first { cal.isDate($0.dayStart, inSameDayAs: day(-1)) }!
        #expect(yesterday.eventCount == 2)
        #expect(yesterday.longestRunHours == 2)
        let today = stored.first { cal.isDate($0.dayStart, inSameDayAs: day0) }!
        #expect(today.eventCount == 1)
        #expect(today.scheduledHours == 0.5)
    }
}

// MARK: - The connect flow (field report 10.103 — "I can't connect calendar")
//
// Root cause, established with an on-simulator truth table (2026-08-19): with
// calendar access already DENIED in iOS — for example "Don't Allow" on the
// consult write-only prompt of an earlier build — `requestFullAccessToEvents`
// returns false INSTANTLY and shows NO prompt, and the old connect path's only
// feedback was a note rendered below the fold of the Data-sources scroll. The
// tap read as a dead button. These tests pin the fixed flow: every outcome is
// named, no failure is silent, the opt-in is never recorded unless iOS granted
// full access (the stuck "on but unreadable" conjunction cannot be created by
// a failed connect), and every sentence passes the FR-NDG-06 guard.
//
// Same rule as the rest of this file: no live `EKEventStore` anywhere — the
// flow's four platform effects are injected.
struct CalendarConnectFlowTests {

    /// Which platform effects the flow actually touched.
    private final class Witness {
        var requested = false
        var optedIn: [String] = []
        var refreshed: [String] = []
    }

    private func run(_ account: String?,
                     grants state: CalendarAccessState,
                     optInSucceeds: Bool = true,
                     daysRead: Int = 0,
                     witness: Witness = Witness()) async -> CalendarLoadIngestor.ConnectOutcome {
        await CalendarLoadIngestor.connect(
            accountID: account,
            request: { witness.requested = true; return state },
            optIn: { witness.optedIn.append($0); return optInSucceeds },
            refresh: { witness.refreshed.append($0) },
            daysRead: { _ in daysRead })
    }

    // MARK: Outcomes are named, ordering is load-bearing

    @Test func noAccountAsksIOSForNothing() async {
        let witness = Witness()
        let outcome = await run(nil, grants: .fullAccess, witness: witness)
        #expect(outcome == .noAccount)
        #expect(witness.requested == false)
        #expect(witness.optedIn.isEmpty)
        #expect(witness.refreshed.isEmpty)
    }

    @Test func refusedAccessIsNamedAndRecordsNoOptIn() async {
        // The 10.103 state: iOS answers without prompting. Whatever it says
        // short of full access, the outcome carries the state — and the opt-in
        // record is NOT written, so a failed connect can never manufacture the
        // stuck "you turned this on but nothing is being read" row.
        for state in [CalendarAccessState.denied, .restricted, .writeOnly, .notDetermined] {
            let witness = Witness()
            let outcome = await run("acct-a", grants: state, witness: witness)
            #expect(outcome == .accessNotGranted(state))
            #expect(witness.requested)
            #expect(witness.optedIn.isEmpty, "opt-in must never be recorded on \(state)")
            #expect(witness.refreshed.isEmpty, "nothing may be read on \(state)")
        }
    }

    @Test func fullAccessConnectsAndReportsTheDaysRead() async {
        let witness = Witness()
        let outcome = await run("acct-a", grants: .fullAccess, daysRead: 5, witness: witness)
        #expect(outcome == .connected(daysRead: 5))
        #expect(witness.optedIn == ["acct-a"])
        #expect(witness.refreshed == ["acct-a"])
    }

    @Test func optInWriteFailureIsNamedAndNothingIsRead() async {
        // iOS said yes but the record could not be written: the flow must say
        // so — never claim a connection — and must not read a single event.
        let witness = Witness()
        let outcome = await run("acct-a", grants: .fullAccess, optInSucceeds: false, witness: witness)
        #expect(outcome == .optInFailed)
        #expect(witness.refreshed.isEmpty)
    }

    // MARK: Every failure SPEAKS, honestly, through the guard

    @Test func everyFailureLineIsNonEmptyGuardCleanAndNeverClaimsSuccess() {
        var lines: [String] = [CalendarLoadCopy.connectNoAccountLine,
                               CalendarLoadCopy.connectOptInFailedLine]
        for state in [CalendarAccessState.denied, .restricted, .writeOnly, .notDetermined] {
            lines.append(CalendarLoadCopy.connectFailureLine(afterRequest: state))
        }
        for line in lines {
            #expect(!line.isEmpty)
            #expect(NudgeGuard.check(line) == nil, "guard tripped: \(line)")
            // The success phrase must be unmanufacturable by a failure path.
            #expect(!line.contains("Calendar connected"), "a failure line claims success: \(line)")
        }
    }

    @Test func statesIOSWillNotRepromptOnPointAtSettings() {
        // Verified on-simulator: denied shows no dialog at all, and write-only
        // may be declined once and then never re-prompts. For the states whose
        // switch really is on Maude's Settings page, the sentence must say
        // where the switch lives.
        for state in [CalendarAccessState.denied, .writeOnly] {
            #expect(CalendarLoadCopy.settingsCanFix(state))
            #expect(CalendarLoadCopy.connectFailureLine(afterRequest: state).contains("iOS Settings"))
        }
        // Restricted is a Screen Time / profile restriction: it does NOT
        // appear on Maude's Settings page, so no button may promise it does.
        // The sentence states the restriction instead.
        #expect(!CalendarLoadCopy.settingsCanFix(.restricted))
        #expect(CalendarLoadCopy.connectFailureLine(afterRequest: .restricted).contains("restricted"))
        #expect(!CalendarLoadCopy.settingsCanFix(.notDetermined))
        #expect(!CalendarLoadCopy.settingsCanFix(.fullAccess))
        #expect(!CalendarLoadCopy.settingsCanFix(.unavailable))
    }

    // MARK: The row itself is honest BEFORE the tap

    @Test func rowNoteSpeaksWhenIOSAlreadySaidNo() {
        // Not opted in + access already off: the row must say so up front —
        // the connect button cannot make iOS prompt in these states.
        let denied = DataSourcesView.calendarRowNote(optedIn: false, access: .denied, daysRead: 0)
        #expect(denied.contains("iOS Settings"), "row is mute about a dead switch")
        let writeOnly = DataSourcesView.calendarRowNote(optedIn: false, access: .writeOnly, daysRead: 0)
        #expect(writeOnly.contains("iOS Settings"))
        #expect(writeOnly.contains("add an event"))
        // Restricted is not fixable from Maude's Settings page, so the row
        // states the restriction and points nowhere it cannot deliver.
        let restricted = DataSourcesView.calendarRowNote(optedIn: false, access: .restricted, daysRead: 0)
        #expect(restricted.contains("restricted"))
        #expect(!restricted.contains("iOS Settings"))
    }

    @Test func rowNoteKeepsThePromiseLineWhenIOSWasNeverAsked() {
        let note = DataSourcesView.calendarRowNote(optedIn: false, access: .notDetermined, daysRead: 0)
        #expect(note.contains("how full your days are"))
        #expect(!note.contains("iOS Settings"), "no scare copy before iOS was ever asked")
    }

    @Test func rowNoteStatesTheStuckConjunctionAndTheConnectedCount() {
        let stuck = DataSourcesView.calendarRowNote(optedIn: true, access: .denied, daysRead: 0)
        #expect(stuck.contains("off in iOS Settings"))
        #expect(stuck.contains("nothing is being read"))

        let connected = DataSourcesView.calendarRowNote(optedIn: true, access: .fullAccess, daysRead: 3)
        #expect(connected.contains("3 days read"))
        let one = DataSourcesView.calendarRowNote(optedIn: true, access: .fullAccess, daysRead: 1)
        #expect(one.contains("1 day read"))
    }

    @Test func everyRowNotePassesTheGuard() {
        for optedIn in [true, false] {
            for access in [CalendarAccessState.notDetermined, .denied, .restricted,
                           .writeOnly, .fullAccess, .unavailable] {
                for days in [0, 1, 7] {
                    let note = DataSourcesView.calendarRowNote(optedIn: optedIn,
                                                               access: access, daysRead: days)
                    #expect(NudgeGuard.check(note) == nil, "guard tripped: \(note)")
                }
            }
        }
    }
}
