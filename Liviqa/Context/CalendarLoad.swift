// CalendarLoad.swift — calendar DENSITY as a health signal (FR-CTX-CAL-01).
//
// THE ONE RULE, stated once so it can be checked by reading:
//
//     Liviqa reads how FULL a day was. It never reads, keeps, logs, sends or
//     shows WHAT was in it.
//
// Titles, attendees, locations, notes, organisers, URLs and calendar names are
// other people's personal data as much as the citizen's. They have no
// representation anywhere in this layer BY CONSTRUCTION: the only value that
// ever crosses out of EventKit is `ScheduledInterval`, which holds two
// instants and two flags and has no field that could carry a word of content.
// `CalendarLoadPrivacyTests` lints the whole read path for the accessors that
// would carry them, so a future edit cannot quietly start keeping them.
//
// Everything here is pure Foundation — no EventKit, no SwiftUI, no SwiftData
// (NFR-PORT-01, Android-portable). EventKit lives in
// `Liviqa/Ingestion/CalendarLoadIngestor.swift` and does nothing but produce
// `[ScheduledInterval]`.
import Foundation

// MARK: - The only thing that crosses out of EventKit

/// One occupied stretch of a day. Two instants and two flags — there is no
/// field here that can hold a title, a person, a place or a note, and that is
/// the point: the content cannot be carried even by accident.
public nonisolated struct ScheduledInterval: Sendable, Equatable {
    public let start: Date
    public let end: Date
    /// All-day entries carry no time-of-day load (a holiday is not sixteen
    /// hours of meetings), so they are excluded from every number below —
    /// including the event count. Kept as a flag rather than filtered at the
    /// source so the rule is visible and testable here, in pure code.
    public let isAllDay: Bool
    /// False for entries the citizen's own calendar marks as free/available or
    /// cancelled. A held-open slot is not a full day.
    public let isBusy: Bool

    public init(start: Date, end: Date, isAllDay: Bool = false, isBusy: Bool = true) {
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.isBusy = isBusy
    }
}

// MARK: - The numbers we keep (and the only ones)

/// One day of calendar DENSITY. Every field is a number or a day boundary.
/// Adding a `String` here would fail `CalendarLoadPrivacyTests.storedShapeIsNumbersOnly`.
public nonisolated struct CalendarDayLoad: Codable, Sendable, Equatable {
    /// Local start-of-day this row describes.
    public let dayStart: Date
    /// How many timed entries the day held.
    public let eventCount: Int
    /// Hours covered by at least one entry — a UNION, so two meetings booked
    /// over each other count once (the same discipline as the sleep merge).
    public let scheduledHours: Double
    /// The longest stretch with no real gap in it (gaps up to
    /// `WakingWindow.backToBackToleranceMinutes` are treated as continuous).
    public let longestRunHours: Double
    /// Hours inside the counting window that nothing was booked over.
    public let freeWakingHours: Double
    /// Minutes after local midnight of the day's first entry (nil when empty).
    public let earliestStartMinute: Int?
    /// Minutes after local midnight of the day's last entry end (nil when empty).
    public let latestEndMinute: Int?

    public init(dayStart: Date, eventCount: Int, scheduledHours: Double,
                longestRunHours: Double, freeWakingHours: Double,
                earliestStartMinute: Int?, latestEndMinute: Int?) {
        self.dayStart = dayStart
        self.eventCount = eventCount
        self.scheduledHours = scheduledHours
        self.longestRunHours = longestRunHours
        self.freeWakingHours = freeWakingHours
        self.earliestStartMinute = earliestStartMinute
        self.latestEndMinute = latestEndMinute
    }

    /// True when the day was read and held nothing. A read empty day is DATA
    /// (the citizen had a clear day); an unread day is absence and is simply
    /// not in the array at all.
    public var isEmptyDay: Bool { eventCount == 0 }
}

// MARK: - The counting window

/// The stretch of the day the "meeting-free hours" count is taken over.
///
/// It is an ARITHMETIC WINDOW, not advice. Liviqa does not recommend an hour to
/// get up or go to bed, and no copy built from these numbers may imply one.
public nonisolated struct WakingWindow: Sendable, Equatable {
    public let startMinute: Int     // minutes after local midnight
    public let endMinute: Int

    /// Gaps at or below this are not gaps — two meetings five minutes apart are
    /// one back-to-back run.
    public static let backToBackToleranceMinutes = 15

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = min(startMinute, endMinute)
        self.endMinute = max(startMinute, endMinute)
    }

    /// 07:00–23:00. A neutral counting frame, chosen so the number means the
    /// same thing on every day of the week.
    public static let standard = WakingWindow(startMinute: 7 * 60, endMinute: 23 * 60)

    public var lengthHours: Double { Double(endMinute - startMinute) / 60 }
}

// MARK: - Deriver (pure)

public nonisolated enum CalendarLoadDeriver {

    /// How many days of history the store keeps and the baseline may use.
    public static let historyDays = 28

    /// Density for one local day. Intervals may cover any range — anything
    /// outside the day is clipped away, so a meeting that runs past midnight
    /// contributes to both days it actually occupies and to neither more.
    public static func day(_ dayStart: Date,
                           from intervals: [ScheduledInterval],
                           window: WakingWindow = .standard,
                           calendar: Calendar = Calendar(identifier: .gregorian)) -> CalendarDayLoad {
        let start = calendar.startOfDay(for: dayStart)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        // Minute-of-day ranges, clipped to this day. All-day and non-busy
        // entries never reach the arithmetic.
        var spans: [(lo: Int, hi: Int)] = []
        for i in intervals where !i.isAllDay && i.isBusy {
            let lo = max(i.start, start)
            let hi = min(i.end, end)
            guard hi > lo else { continue }
            let loM = Int((lo.timeIntervalSince(start) / 60).rounded(.down))
            let hiM = Int((hi.timeIntervalSince(start) / 60).rounded(.up))
            guard hiM > loM else { continue }
            spans.append((loM, min(hiM, 24 * 60)))
        }

        guard !spans.isEmpty else {
            return CalendarDayLoad(dayStart: start, eventCount: 0, scheduledHours: 0,
                                   longestRunHours: 0, freeWakingHours: window.lengthHours,
                                   earliestStartMinute: nil, latestEndMinute: nil)
        }

        let count = spans.count
        let earliest = spans.map(\.lo).min()
        let latest = spans.map(\.hi).max()

        let unioned = merge(spans, joiningGapsOf: 0)
        let scheduled = Double(unioned.reduce(0) { $0 + ($1.hi - $1.lo) }) / 60

        let runs = merge(spans, joiningGapsOf: WakingWindow.backToBackToleranceMinutes)
        let longest = Double(runs.map { $0.hi - $0.lo }.max() ?? 0) / 60

        // Free waking hours: the counting window minus whatever it overlaps.
        let busyInWindow = unioned.reduce(0) { acc, s in
            acc + max(0, min(s.hi, window.endMinute) - max(s.lo, window.startMinute))
        }
        let free = max(0, Double(window.endMinute - window.startMinute - busyInWindow)) / 60

        return CalendarDayLoad(dayStart: start,
                               eventCount: count,
                               scheduledHours: round2(scheduled),
                               longestRunHours: round2(longest),
                               freeWakingHours: round2(free),
                               earliestStartMinute: earliest,
                               latestEndMinute: latest)
    }

    /// Density for each of `days` (any order in, same order out).
    public static func week(_ days: [Date],
                            from intervals: [ScheduledInterval],
                            window: WakingWindow = .standard,
                            calendar: Calendar = Calendar(identifier: .gregorian)) -> [CalendarDayLoad] {
        days.map { day($0, from: intervals, window: window, calendar: calendar) }
    }

    /// Merge overlapping spans, optionally treating gaps up to `gap` minutes as
    /// continuous. Sorted, non-overlapping, ascending.
    private static func merge(_ spans: [(lo: Int, hi: Int)],
                              joiningGapsOf gap: Int) -> [(lo: Int, hi: Int)] {
        let sorted = spans.sorted { $0.lo < $1.lo }
        var out: [(lo: Int, hi: Int)] = []
        for s in sorted {
            if let last = out.last, s.lo - last.hi <= gap {
                out[out.count - 1].hi = max(last.hi, s.hi)
            } else {
                out.append(s)
            }
        }
        return out
    }

    private static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    // MARK: - Honest absence

    /// True when the stored history holds no timed entry at all. An entirely
    /// empty calendar almost always means the citizen does not keep their
    /// calendar on this phone — reading "your days were like usual" out of that
    /// would be a claim about a person from an absence of data, so every
    /// surface treats this as NO DATA rather than as a week of quiet days.
    public static func isEntirelyEmpty(_ history: [CalendarDayLoad]) -> Bool {
        history.allSatisfy { $0.eventCount == 0 }
    }

    /// Days needed before a "busier / quieter than your usual" claim is allowed
    /// — the same ≥3 rule `Baseline.from` applies to every other signal.
    public static let minimumDaysForBaseline = 3

    /// The stretch of history a baseline may be taken over: from the citizen's
    /// FIRST recorded entry onward, ascending.
    ///
    /// The days before it are the trap. A refresh reads the whole rolling
    /// window at once, so someone who started keeping this calendar eight days
    /// ago gets twenty empty days in front of eight real ones. Those empty days
    /// are not quiet days — they are days this calendar was not being kept
    /// here — and averaging them in would make an ordinary week read as
    /// "fuller than your usual" for a month. Empty days INSIDE the used stretch
    /// stay: a genuinely clear Sunday is data about the person.
    public static func baselineWindow(_ history: [CalendarDayLoad]) -> [CalendarDayLoad] {
        let sorted = history.sorted { $0.dayStart < $1.dayStart }
        guard let first = sorted.firstIndex(where: { $0.eventCount > 0 }) else { return [] }
        return Array(sorted[first...])
    }

    /// True when the history can support a personal-baseline comparison.
    public static func hasUsableBaseline(_ history: [CalendarDayLoad]) -> Bool {
        baselineWindow(history).count >= minimumDaysForBaseline
    }
}
