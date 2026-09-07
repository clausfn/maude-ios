// DaySeries.swift — the day axis, once, for every chart that draws days.
//
// THE BUG THIS EXISTS TO KILL. Daily series used to travel as bare `[Double]`
// with one entry per day THAT HAS DATA. A chart then drew those values at evenly
// spaced x-positions and labelled the axis from a SEPARATELY computed list of
// calendar days. The two only agree when the user has data on every single day
// of the window — the moment one day is missing (a watch left on the charger, a
// sensor warm-up), every remaining value slides one column left and the user
// reads Saturday's number under Sunday's letter. Nothing in the type system
// noticed, because both sides were just arrays.
//
// The fix is to carry the DATE with the value and let the axis derive from those
// dates. A day with no reading renders as a GAP — never a zero (that would
// fabricate a reading of 0), never a straight line drawn through it (that would
// imply an observation nobody made).
//
// Pure Foundation — no SwiftUI (NFR-PORT-01), so the alignment rule is unit
// testable without a view.
import Foundation

/// One calendar day of a charted series, with the value recorded that day —
/// or `nil` when nothing was recorded. `nil` is the honest state; it is not 0.
public nonisolated struct DaySlot: Sendable, Equatable, Identifiable {
    public let date: Date          // start of day
    public let value: Double?      // nil ⇒ nothing recorded that day

    public init(date: Date, value: Double?) {
        self.date = date
        self.value = value
    }

    public var id: Date { date }
    public var hasValue: Bool { value != nil }
}

public nonisolated enum DaySeries {

    /// One shared calendar so day boundaries match wherever a series is placed
    /// on an axis (deriver, chart, tests) — the same rule ContextWindow uses.
    public static let calendar = Calendar(identifier: .gregorian)

    /// Calendar days from `start` through `end`, inclusive, ascending.
    /// Empty when `end` precedes `start`.
    public static func days(from start: Date, through end: Date,
                            calendar: Calendar = DaySeries.calendar) -> [Date] {
        let s = calendar.startOfDay(for: start), e = calendar.startOfDay(for: end)
        guard s <= e else { return [] }
        var out: [Date] = [], cur = s
        while cur <= e {
            out.append(cur)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return out
    }

    /// The window's last `count` days, ending on `end` (inclusive), ascending.
    public static func days(endingOn end: Date, count: Int,
                            calendar: Calendar = DaySeries.calendar) -> [Date] {
        guard count > 0 else { return [] }
        let e = calendar.startOfDay(for: end)
        return (0..<count).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: e)
        }
    }

    /// Place a dated series onto a day axis: one slot per day of `window`,
    /// carrying that day's value or `nil`. `values` and `dates` are parallel;
    /// a count mismatch is treated as "no dates known" and yields an all-nil
    /// axis rather than a guess.
    public static func slots(values: [Double], dates: [Date], over window: [Date],
                             calendar: Calendar = DaySeries.calendar) -> [DaySlot] {
        guard values.count == dates.count else {
            return window.map { DaySlot(date: $0, value: nil) }
        }
        var byDay: [Date: Double] = [:]
        for (v, d) in zip(values, dates) { byDay[calendar.startOfDay(for: d)] = v }
        return window.map { DaySlot(date: $0, value: byDay[calendar.startOfDay(for: $0)]) }
    }

    /// Place a series on a day axis, refusing to guess.
    ///
    ///  · dates carried  → exact placement, by date.
    ///  · no dates, but the series has exactly one value per day of the window
    ///    → the 1:1 mapping is unambiguous, so it is used (this is the shape of
    ///    the labelled demo fixtures, which are full weeks by construction).
    ///  · no dates and a SHORT series → `nil`. There is no honest way to say
    ///    which day each value belongs to, so the caller must drop the day
    ///    labels instead of mislabelling them.
    public static func aligned(values: [Double], dates: [Date], over window: [Date],
                               calendar: Calendar = DaySeries.calendar) -> [DaySlot]? {
        guard !window.isEmpty, !values.isEmpty else { return nil }
        if values.count == dates.count {
            return slots(values: values, dates: dates, over: window, calendar: calendar)
        }
        guard values.count == window.count else { return nil }
        return zip(window, values).map { DaySlot(date: $0, value: $1) }
    }

    /// Contiguous runs of recorded days. Charts stroke one path per run, so a
    /// missing day breaks the line instead of being drawn through.
    /// Each run is `(startIndex, values)` against the slot array.
    public static func runs(_ slots: [DaySlot]) -> [(start: Int, values: [Double])] {
        var out: [(start: Int, values: [Double])] = []
        var cur: (start: Int, values: [Double])? = nil
        for (i, s) in slots.enumerated() {
            if let v = s.value {
                if cur == nil { cur = (i, []) }
                cur?.values.append(v)
            } else if let c = cur {
                out.append(c); cur = nil
            }
        }
        if let c = cur { out.append(c) }
        return out
    }

    /// Number of days between the first and last recorded day of a set of
    /// dates, inclusive — the true span a chart of that series covers.
    public static func spanDays(_ dates: [Date], calendar: Calendar = DaySeries.calendar) -> Int {
        guard let lo = dates.min(), let hi = dates.max() else { return 0 }
        let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: lo),
                                        to: calendar.startOfDay(for: hi)).day ?? 0
        return d + 1
    }
}
