// CalendarLoadIngestor.swift — the ONLY place Maude reads the citizen's
// calendar (FR-CTX-CAL-01). It exists to turn events into two instants and two
// flags, and to do nothing else.
//
// WHAT THIS FILE MAY TOUCH ON AN EVENT
//   startDate · endDate · isAllDay · availability · status
// and nothing else. Not `title`, not `attendees`, not `location`, not
// `structuredLocation`, not `notes`, not `organizer`, not `url`, not
// `calendar` (a calendar's NAME is content too — which is why Maude cannot
// offer a "choose which calendars" picker: it would have to read their names).
// `CalendarLoadPrivacyTests.readPathNeverTouchesEventContent` reads this file
// and fails the build if any of those appear, so the promise in the permission
// prompt is checkable against the code rather than asserted in a comment.
//
// Nothing is logged. There is no `print`, no `os_log`, no debug dump anywhere
// on this path — an event's content must not exist in a console either.
//
// The derivation itself is pure and lives in `CalendarLoad.swift`; persistence
// is `CalendarLoadStore`. This file is the thin platform edge (NFR-PORT-01: an
// Android port replaces this file alone).
import Foundation
#if canImport(EventKit)
import EventKit
#endif

/// What iOS currently allows, said in Maude's own words. `writeOnly` is a real
/// and separate state: the app can add a planned consultation with it, and can
/// read nothing at all.
enum CalendarAccessState: Equatable {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case fullAccess
    case unavailable      // no EventKit on this platform
}

enum CalendarLoadIngestor {

    // MARK: - The test seam
    //
    // Unit tests must NEVER reach a live `EKEventStore`: on a headless
    // simulator the calendar TCC dialog can block the test host forever (the
    // same class of hang as the camera prompt on `care_previsit`). So the
    // refresh takes its two platform facts — the access state and the read —
    // through an injected `Environment`. Production uses `.live`; the unit
    // suite injects fakes and exercises everything else for real.

    struct Environment {
        var accessState: () -> CalendarAccessState
        var intervals: (_ from: Date, _ to: Date) -> [ScheduledInterval]

        /// The real platform edge. Constructs an `EKEventStore` only inside
        /// the read closure, and only after the access guard has passed.
        static let live = Environment(
            accessState: { CalendarLoadIngestor.accessState() },
            intervals: { from, to in
                #if canImport(EventKit)
                CalendarLoadIngestor.intervals(from: from, to: to)
                #else
                []
                #endif
            })
    }

    // MARK: - Authorisation

    /// Reads TCC state via the CLASS method — no store instance exists here,
    /// and `authorizationStatus` never prompts.
    static func accessState() -> CalendarAccessState {
        #if canImport(EventKit)
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:  return .notDetermined
        case .restricted:     return .restricted
        case .denied:         return .denied
        case .fullAccess:     return .fullAccess
        case .writeOnly:      return .writeOnly
        @unknown default:     return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    /// Ask iOS for read access. The system prompt shows
    /// `NSCalendarsFullAccessUsageDescription`, which states the same promise
    /// this file implements: how full the days are, never what is in them.
    static func requestFullAccess() async -> CalendarAccessState {
        #if canImport(EventKit)
        let store = EKEventStore()
        _ = try? await store.requestFullAccessToEvents()
        return accessState()
        #else
        return .unavailable
        #endif
    }

    // MARK: - Connect (request → opt-in → first read), every failure NAMED
    //
    // Field report 10.103 ("I can't connect calendar"): when iOS has calendar
    // access denied — e.g. "Don't Allow" on the consult write-only prompt in an
    // earlier build — `requestFullAccessToEvents` returns false INSTANTLY with
    // no prompt (verified on-simulator 2026-08-19: denied → returned=false,
    // no dialog). The old connect path swallowed that into a note at the very
    // bottom of the scroll view, below the fold: the tap read as a no-op.
    // This flow returns a named outcome for every way the tap can end, so the
    // view has no silent branch left to fall into.

    /// Every way a connect attempt can end. No case is allowed to be silent:
    /// each maps to a sentence the citizen sees at the point of the tap.
    enum ConnectOutcome: Equatable {
        /// No signed-in account to scope the numbers under. Nothing was asked.
        case noAccount
        /// iOS did not grant full access; the payload is what it said instead.
        /// The opt-in was NOT recorded (the stuck "on but unreadable" state
        /// cannot be created by this path).
        case accessNotGranted(CalendarAccessState)
        /// iOS granted access but the opt-in record could not be written, so
        /// nothing was read and nothing is connected.
        case optInFailed
        /// Connected. `daysRead` is how many day-numbers the first read kept.
        case connected(daysRead: Int)
    }

    /// The connect flow with its four platform effects injected, so the unit
    /// suite can drive every outcome with no live `EKEventStore` (same seam
    /// discipline as `Environment`). Ordering is load-bearing and pinned by
    /// tests: the opt-in is recorded only AFTER iOS grants full access, and
    /// the read runs only after the opt-in is recorded.
    static func connect(accountID: String?,
                        request: () async -> CalendarAccessState,
                        optIn: (String) -> Bool,
                        refresh: (String) async -> Void,
                        daysRead: (String) -> Int) async -> ConnectOutcome {
        guard let accountID else { return .noAccount }
        let state = await request()
        guard state == .fullAccess else { return .accessNotGranted(state) }
        guard optIn(accountID) else { return .optInFailed }
        await refresh(accountID)
        return .connected(daysRead: daysRead(accountID))
    }

    // MARK: - The one read

    #if canImport(EventKit)
    /// EventKit in, `ScheduledInterval` out. This is the whole seam: after this
    /// function returns, no `EKEvent` exists anywhere in the app, so no later
    /// edit can reach a title or an attendee even by mistake.
    ///
    /// Cancelled entries are skipped (a cancelled meeting did not fill the day);
    /// entries the citizen's own calendar marks `free` are carried as not-busy
    /// and drop out of the arithmetic in `CalendarLoadDeriver`.
    static func intervals(from start: Date, to end: Date,
                          store: EKEventStore = EKEventStore()) -> [ScheduledInterval] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard event.status != .canceled else { return nil }
            guard let s = event.startDate, let e = event.endDate, e > s else { return nil }
            return ScheduledInterval(start: s, end: e,
                                     isAllDay: event.isAllDay,
                                     isBusy: event.availability != .free)
        }
    }
    #endif

    // MARK: - Refresh (read → derive → store)

    /// Re-derive the rolling density window for `accountID` and persist the
    /// numbers. Returns false — writing nothing — whenever the citizen has not
    /// opted in, there is no account scope, or iOS has not granted read access.
    /// Collection can therefore never start as a side effect of a refresh.
    @discardableResult
    static func refresh(accountID: String?,
                        now: Date = Date(),
                        window: WakingWindow = .standard,
                        calendar: Calendar = Calendar(identifier: .gregorian),
                        environment: Environment = .live,
                        base: URL? = CalendarLoadStore.baseDirectory()) -> Bool {
        guard let accountID,
              CalendarLoadStore.isOptedIn(forAccount: accountID, base: base) else { return false }
        guard environment.accessState() == .fullAccess else { return false }
        let today = calendar.startOfDay(for: now)
        let days: [Date] = (0..<CalendarLoadDeriver.historyDays)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .sorted()
        guard let first = days.first,
              let last = calendar.date(byAdding: .day, value: 1, to: days[days.count - 1])
        else { return false }
        let read = environment.intervals(first, last)
        let loads = CalendarLoadDeriver.week(days, from: read, window: window, calendar: calendar)
        return CalendarLoadStore.replaceDays(loads, forAccount: accountID, base: base)
    }
}
