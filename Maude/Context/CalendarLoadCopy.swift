// CalendarLoadCopy.swift — every sentence Maude says about calendar load.
//
// Three rules bind this file, and the tests enforce all three:
//
//  1. FR-NDG-06 (DESIGNATED CONTROL). Every string leaving this file is built
//     through `guarded(_:fallback:)`, so it has passed `NudgeGuard.check`
//     before any view can render it. `CalendarLoadPrivacyTests` sweeps a wide
//     input space and fails if any construction trips the guard.
//  2. Personal baseline only. "Busier than YOUR usual" — never a population
//     norm, never a recommended number of meetings, never a judgement about how
//     a person should spend their time.
//  3. No causal verdict. A full day is never said to have caused a reading. The
//     grid puts two facts next to each other; the citizen reads their own life.
//
// Pure Foundation. No content of any event can reach here: the inputs are
// `CalendarDayLoad` (numbers) and a day name.
import Foundation

/// What the calendar row can honestly say right now.
public nonisolated enum CalendarRowState: Sendable, Equatable {
    /// The citizen has not turned the calendar signal on (or iOS has not
    /// granted it). Nothing has been read.
    case notConnected
    /// Read, but the calendars on this phone hold no timed entry at all.
    case noEntriesAtAll
    /// Read, but not enough days yet to know what this person's usual is.
    case calibrating(daysSoFar: Int)
    /// Enough of the citizen's own history to compare a day to their usual.
    case ready
}

public nonisolated enum CalendarLoadCopy {

    // MARK: - The guard seam

    /// The FR-NDG-06 seam. A sentence that trips the guard is never shown; the
    /// caller's neutral fallback is shown instead. In DEBUG this trips an
    /// assertion so it surfaces in a test run rather than in a citizen's hands.
    public static func guarded(_ text: String, fallback: String) -> String {
        if let violation = NudgeGuard.check(text) {
            assertionFailure("Calendar copy tripped NudgeGuard (\(violation.rawValue)): \(text)")
            return fallback
        }
        return text
    }

    /// The neutral sentence every fallback lands on. Says only that Maude has
    /// nothing to say — never a number, never a claim.
    public static var neutralFallback: String {
        String(localized: "Maude has nothing to say about this day's calendar.")
    }

    // MARK: - Numbers, said in English

    static func hours(_ v: Double) -> String {
        let rounded = (v * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            let whole = Int(rounded.rounded())
            return whole == 1 ? String(localized: "1 hour") : String(localized: "\(whole) hours")
        }
        return String(localized: "\(String(format: "%.1f", rounded)) hours")
    }

    static func clock(_ minuteOfDay: Int) -> String {
        let h = min(23, max(0, minuteOfDay / 60))
        let m = min(59, max(0, minuteOfDay % 60))
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - The row's own state line

    /// The one line the CALENDAR row shows when there is nothing per-day to
    /// read. Honest absence: never a zero presented as a fact about the person.
    public static func stateLine(_ state: CalendarRowState) -> String {
        let text: String
        switch state {
        case .notConnected:
            text = String(localized: "Your calendar isn't connected, so this row is empty. Maude would read only how full your days are — never what is in them.")
        case .noEntriesAtAll:
            text = String(localized: "The calendars on this phone hold nothing in this window, so there is nothing to read. That is a fact about the calendar, not about your week.")
        case .calibrating(let days):
            let d = days == 1 ? String(localized: "1 day") : String(localized: "\(days) days")
            text = String(localized: "Maude has \(d) of your calendar so far. It needs a few days before it can tell a full day from your usual one.")
        case .ready:
            text = String(localized: "Read down this row to see how full each day was, against your own usual.")
        }
        return guarded(text, fallback: neutralFallback)
    }

    // MARK: - The per-day readout

    /// How far a day sat from this person's own usual. `nil` band = we are not
    /// making a comparison at all.
    public nonisolated enum Direction: Sendable, Equatable { case busier, quieter, likeUsual }

    /// One day, said plainly. `load` nil ⇒ that day was never read.
    ///
    /// - `notable`: the day reached the "worth noticing" band, which adds the
    ///   same non-finding disclaimer every other signal carries — plus the
    ///   explicit statement that Maude is not calling it a cause.
    public static func dayReadout(day: String,
                                  state: CalendarRowState,
                                  load: CalendarDayLoad?,
                                  usualScheduledHours: Double?,
                                  direction: Direction?,
                                  notable: Bool) -> String {
        let fallback = guarded(String(localized: "Maude has no calendar reading for \(day)."),
                               fallback: neutralFallback)

        switch state {
        case .notConnected, .noEntriesAtAll:
            return stateLine(state)
        case .calibrating, .ready:
            break
        }

        guard let load else { return fallback }

        if load.eventCount == 0 {
            return guarded(String(localized: "Nothing was booked on \(day) in the calendars on this phone."),
                           fallback: fallback)
        }

        let entries = load.eventCount == 1
            ? String(localized: "1 entry")
            : String(localized: "\(load.eventCount) entries")
        let booked = hours(load.scheduledHours)

        var sentence: String
        switch (direction, usualScheduledHours) {
        case (.busier?, let usual?):
            sentence = String(localized: "\(day) was fuller than your usual — \(entries), \(booked) booked, against your usual \(hours(usual)).")
        case (.quieter?, let usual?):
            sentence = String(localized: "\(day) was emptier than your usual — \(entries), \(booked) booked, against your usual \(hours(usual)).")
        case (.likeUsual?, let usual?):
            sentence = String(localized: "\(day) was about as full as your usual — \(entries), \(booked) booked, against your usual \(hours(usual)).")
        default:
            // Calibrating, or no usual yet: state the day, compare to nothing.
            sentence = String(localized: "\(day): \(entries), \(booked) booked.")
        }

        // A second clause only when it says something the first does not.
        if load.longestRunHours >= 2, load.longestRunHours >= load.scheduledHours - 0.25 {
            sentence += " " + String(localized: "Its longest unbroken run was \(hours(load.longestRunHours)).")
        } else if load.longestRunHours >= 3 {
            sentence += " " + String(localized: "Its longest unbroken run was \(hours(load.longestRunHours)).")
        }
        if let earliest = load.earliestStartMinute, let latest = load.latestEndMinute, latest > earliest {
            sentence += " " + String(localized: "First entry \(clock(earliest)), last ended \(clock(latest)).")
        }

        if notable {
            sentence += " " + String(localized: "A pattern in your own data, not a medical finding — and not read as a cause of anything else on this screen.")
        }
        return guarded(sentence, fallback: fallback)
    }

    // MARK: - When the connect tap fails (nothing may fail silently)
    //
    // Field report 10.103: with calendar access already denied in iOS, the
    // system shows NO prompt and the request returns instantly — so the only
    // honest response is a sentence at the point of the tap that says what iOS
    // said and where it can be changed. Verified on-simulator 2026-08-19:
    // denied ⇒ no dialog, silent false; write-only ⇒ iOS offers an upgrade
    // prompt at least once ("Allow Full Access" / "Keep Add Only").

    /// The sentence shown when a connect attempt ends without full access.
    /// `state` is what `requestFullAccess` came back with.
    static func connectFailureLine(afterRequest state: CalendarAccessState) -> String {
        let fallback = String(localized: "iOS didn't grant calendar access, so nothing was read.")
        let text: String
        switch state {
        case .denied:
            text = String(localized: "iOS has calendar access switched off for Maude, so it will not ask again here and nothing was read. To connect, allow Full Access in iOS Settings, then come back and tap connect.")
        case .restricted:
            text = String(localized: "Calendar access is restricted on this device — for example by Screen Time — so iOS will not show Maude's request, and Maude cannot connect. Nothing was read.")
        case .writeOnly:
            text = String(localized: "iOS lets Maude add an event to your calendar, but not read one — so nothing was read. To connect, allow Full Access in iOS Settings.")
        case .notDetermined, .fullAccess, .unavailable:
            text = fallback + " " + String(localized: "You can try again, or allow Full Access in iOS Settings.")
        }
        return guarded(text, fallback: fallback)
    }

    /// Whether Maude's own page in iOS Settings is where the citizen can
    /// actually change the answer. True for denied and write-only — the two
    /// states whose switch really is on that page. NOT true for restricted:
    /// a Screen Time (or profile) restriction does not appear there, so a
    /// "fix it in Settings" button would point at a page that cannot fix it.
    static func settingsCanFix(_ state: CalendarAccessState) -> Bool {
        switch state {
        case .denied, .writeOnly: return true
        case .restricted, .notDetermined, .fullAccess, .unavailable: return false
        }
    }

    /// No signed-in account to scope the numbers under.
    static var connectNoAccountLine: String {
        guarded(String(localized: "Sign in first — your calendar numbers are kept under your own account on this phone."),
                fallback: String(localized: "Sign in first."))
    }

    /// iOS said yes but the opt-in record could not be written. Nothing is
    /// connected and the sentence must not pretend otherwise.
    static var connectOptInFailedLine: String {
        guarded(String(localized: "Maude couldn't record your choice on this phone, so nothing was connected and nothing was read. Please try again."),
                fallback: String(localized: "Nothing was connected. Please try again."))
    }

    // MARK: - What the citizen is told BEFORE the permission prompt

    /// The exact list of numbers Maude keeps. Shown on the data-source screen
    /// before anything is asked for, and the same six the store holds.
    public static let readsList: [String] = [
        String(localized: "How many entries each day held"),
        String(localized: "How many hours of the day were booked"),
        String(localized: "The longest unbroken run of them"),
        String(localized: "How many hours between 07:00 and 23:00 nothing was booked over"),
        String(localized: "When the first entry started and the last one ended"),
    ]

    /// The exact list of things Maude never reads. Every item here is a field
    /// `CalendarLoadPrivacyTests` proves the read path never touches.
    public static let neverList: [String] = [
        String(localized: "Titles — what any entry is called"),
        String(localized: "People — who is invited or organising"),
        String(localized: "Places — where anything is"),
        String(localized: "Notes, links and attachments"),
        String(localized: "The names of your calendars"),
    ]

    /// The one-sentence promise. This is the same claim the iOS permission
    /// prompt makes, and `CalendarLoadPrivacyTests` checks the two agree.
    public static var promise: String {
        String(localized: "Maude reads how full your days are, never what is in them.")
    }
}
