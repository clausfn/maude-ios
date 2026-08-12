// ContextFlagDeriver.swift — FR-CTX-04 suppression logic (portable).
//
// The ONE rule, stated once so it can be checked by reading:
//
//     A context flag can only ever REMOVE a nudge. It can never add one,
//     re-rank one, or change a number.
//
// That is the FR-NDG-06 interaction rule (**designated control**): the flag is
// a suppression gate, not an input. `NudgeEngine` implements it by not even
// calling its baseline-comparison streams on a marked day — there is no branch
// anywhere that emits a nudge BECAUSE a flag exists, and T-CTX-04 proves the
// output on a marked day is always a subset of the unmarked output.
//
// Two lanes are deliberately NOT suppressed:
//   • route-to-clinician / display-only (AFib, D9) — a safety route must never
//     be silenced by a self-declared travel note.
//   • the plain resting-HR number echo — it states the user's own reading and
//     makes no baseline claim, so suppressing it would hide data, not noise.
//
// `ContextWindow` carries kind + dates and NOTHING ELSE: the user's free-text
// note has no representation in this layer by construction.
//
// Pure Foundation — no SwiftData/HealthKit/SwiftUI. Android-portable.
import Foundation

/// The engine-facing projection of a context flag: a closed or open day range.
/// Both ends are INCLUSIVE; `end == nil` means the range is still open.
public nonisolated struct ContextWindow: Sendable, Equatable, Hashable {

    /// One shared calendar so day boundaries are computed identically wherever
    /// a window is evaluated (engine, views, store).
    public static let calendar = Calendar(identifier: .gregorian)

    public let kind: ContextFlagKind
    public let start: Date
    public let end: Date?

    public init(kind: ContextFlagKind, start: Date, end: Date? = nil) {
        self.kind = kind
        self.start = start
        self.end = end
    }

    /// True when the given instant's DAY falls inside this window.
    public func covers(_ instant: Date, calendar: Calendar = ContextWindow.calendar) -> Bool {
        let day = calendar.startOfDay(for: instant)
        guard day >= calendar.startOfDay(for: start) else { return false }
        guard let end else { return true }                      // still open
        return day <= calendar.startOfDay(for: end)
    }
}

public nonisolated enum ContextFlagDeriver {

    /// The window covering this day, if any (the most recently started one wins
    /// when stretches overlap — the user's latest word about their own life).
    public static func window(covering instant: Date,
                              in windows: [ContextWindow],
                              calendar: Calendar = ContextWindow.calendar) -> ContextWindow? {
        windows
            .filter { $0.covers(instant, calendar: calendar) }
            .max { $0.start < $1.start }
    }

    /// True when the user has marked this day.
    public static func isMarked(_ instant: Date,
                                in windows: [ContextWindow],
                                calendar: Calendar = ContextWindow.calendar) -> Bool {
        window(covering: instant, in: windows, calendar: calendar) != nil
    }

    /// How many of the given days are marked — used for honest chart/window
    /// annotations ("3 of these days are marked"). Counts real days only; it
    /// never invents a day that isn't in the passed set.
    public static func markedCount(among days: [Date],
                                   in windows: [ContextWindow],
                                   calendar: Calendar = ContextWindow.calendar) -> Int {
        days.reduce(0) { $0 + (isMarked($1, in: windows, calendar: calendar) ? 1 : 0) }
    }

    /// SUPPRESSION GATE (FR-NDG-06 interaction rule). Baseline-comparison
    /// streams are skipped for a marked day; safety routing and plain number
    /// echoes are not. Suppression-only: the return value can never widen the
    /// engine's output — `NudgeEngine.generate` only ever uses it to skip.
    public static func suppressesBaselineDeviations(
        on instant: Date,
        windows: [ContextWindow],
        calendar: Calendar = ContextWindow.calendar
    ) -> Bool {
        isMarked(instant, in: windows, calendar: calendar)
    }
}
