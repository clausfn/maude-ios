// CorrelationDeriver.swift — the 7-day × signal correlation grid (DM-06,
// FR-PAS-05), computed entirely on device from local `HealthSamples`.
//
// The grid is a deviation-from-usual heat map: each cell encodes how far a
// signal sat from the user's OWN baseline that day (matching the model's
// `outlier = notable deviation from personal baseline`). It is personal-
// baseline-relative only — never a population norm, never a clinical band.
// Pure Foundation — no SwiftData / SwiftUI / HealthKit (NFR-PORT-01).
//
// Columns mirror the presentation model order:
//   glucose · sleep · hrv · exercise · spending · calendar · weather
// The first four derive from the MVP HealthKit read set. `derive(from:)` sees
// only `HealthSamples`, so it still emits `noData` for the last three — never a
// fabricated value. CALENDAR is now a real signal, but it comes from a separate
// consented source (`CalendarLoadStore`), so it is derived by
// `calendarCells(history:over:connected:)` at the bottom of this file and laid
// over column 5 by the caller. SPENDING and WEATHER remain honestly absent.
import Foundation

public nonisolated enum CorrelationCell: Int, Sendable, Equatable {
    case noData = 0, low = 1, medium = 2, high = 3, outlier = 4
}

public nonisolated struct CorrelationGrid: Sendable, Equatable {
    public nonisolated struct Row: Sendable, Equatable {
        public let dayLabel: String     // "M" … "S"
        public let dateOffset: Int      // days before today (0 = today)
        public let cells: [CorrelationCell]   // one per signal column
        public init(dayLabel: String, dateOffset: Int, cells: [CorrelationCell]) {
            self.dayLabel = dayLabel; self.dateOffset = dateOffset; self.cells = cells
        }
    }
    public let signals: [String]
    public let rows: [Row]              // 7 days, oldest first
    public let patternNote: String
    public let patternSources: [String]
    public let patternStrength: String  // "Strong" / "Moderate" / "Mild" / "Steady"

    public init(signals: [String], rows: [Row], patternNote: String,
                patternSources: [String], patternStrength: String) {
        self.signals = signals; self.rows = rows; self.patternNote = patternNote
        self.patternSources = patternSources; self.patternStrength = patternStrength
    }
}

public nonisolated enum CorrelationDeriver {

    public static let signalLabels = ["glucose", "sleep", "hrv", "exercise",
                                      "spending", "calendar", "weather"]
    /// Number of leading columns we can derive from local samples.
    private static let derivedCount = 4
    private static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    public static func derive(from s: HealthSamples,
                              now: Date = Date(),
                              calendar: Calendar = Calendar(identifier: .gregorian)) -> CorrelationGrid {
        let today = calendar.startOfDay(for: now)
        let offsets = Array((0...6).reversed())          // 6 (oldest) … 0 (today)
        let days = offsets.map { calendar.date(byAdding: .day, value: -$0, to: today)! }

        func dailyGlucose(_ d: Date) -> Double? {
            let v = s.glucose.filter { calendar.isDate($0.ts, inSameDayAs: d) }.map(\.mmol)
            return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        }
        func dailySleep(_ d: Date) -> Double? {
            let segs = s.sleep.filter { asleepStages.contains($0.stage) && calendar.isDate($0.date, inSameDayAs: d) }
            // Union, not sum, so overlapping two-source nights count once.
            return segs.isEmpty ? nil : SleepReading.mergedAsleepHours(segs, asleep: asleepStages)
        }
        func dailyHRV(_ d: Date) -> Double? {
            let v = s.hrv.filter { calendar.isDate($0.date, inSameDayAs: d) }.map(\.value)
            return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
        }
        // Exercise must be ONE unit across the 7-day series. Mixing workout
        // MINUTES (workout days) with active-energy KCAL (other days) z-scores a
        // ~45-min value against a ~500-kcal mean, so ordinary walk days read as
        // the week's biggest deviations. Active energy is present ~daily and
        // already includes the workout burn, so it is the single source of
        // truth. Only if the WHOLE week has no active energy do we fall back to
        // workout minutes — still one consistent unit across the series.
        let weekHasActiveEnergy = days.contains { d in
            s.activeEnergy.contains { calendar.isDate($0.date, inSameDayAs: d) }
        }
        func dailyExercise(_ d: Date) -> Double? {
            if weekHasActiveEnergy {
                let e = s.activeEnergy.filter { calendar.isDate($0.date, inSameDayAs: d) }.map(\.value)
                return e.isEmpty ? nil : e.reduce(0, +) / Double(e.count)
            }
            let mins = s.workouts.filter { calendar.isDate($0.start, inSameDayAs: d) }.map(\.durMin)
            return mins.isEmpty ? nil : mins.reduce(0, +)
        }
        let providers: [(Date) -> Double?] = [dailyGlucose, dailySleep, dailyHRV, dailyExercise]

        var series: [[Double?]] = []
        var baselines: [Baseline?] = []
        for p in providers {
            let row = days.map { p($0) }
            series.append(row)
            baselines.append(Baseline.from(row.compactMap { $0 }))
        }

        func z(_ value: Double?, _ base: Baseline?) -> Double? {
            guard let value, let base, base.sd > 0 else { return nil }
            return abs(value - base.mean) / base.sd
        }
        func cell(_ value: Double?, _ base: Baseline?) -> CorrelationCell {
            guard let zz = z(value, base) else { return value == nil ? .noData : .low }
            switch zz {
            case ..<0.5: return .low
            case ..<1.0: return .medium
            case ..<2.0: return .high
            default:     return .outlier
            }
        }

        let symbols = calendar.veryShortWeekdaySymbols   // ["S","M",...]
        var rows: [CorrelationGrid.Row] = []
        var topZ = -1.0, topDayIdx = -1, topSig = -1
        var sourcesHit = Set<Int>()

        for (i, off) in offsets.enumerated() {
            var cells: [CorrelationCell] = []
            for sig in 0..<derivedCount {
                let c = cell(series[sig][i], baselines[sig])
                cells.append(c)
                if c == .high || c == .outlier { sourcesHit.insert(sig) }
                if let zz = z(series[sig][i], baselines[sig]), zz > topZ {
                    topZ = zz; topDayIdx = i; topSig = sig
                }
            }
            cells += Array(repeating: CorrelationCell.noData, count: signalLabels.count - derivedCount)
            let wd = symbols[calendar.component(.weekday, from: days[i]) - 1]
            rows.append(.init(dayLabel: wd, dateOffset: off, cells: cells))
        }

        let (note, sources, strength) = pattern(
            topZ: topZ, topDayIdx: topDayIdx, topSig: topSig,
            days: days, sourcesHit: sourcesHit, calendar: calendar)

        return CorrelationGrid(signals: signalLabels, rows: rows,
                               patternNote: note, patternSources: sources,
                               patternStrength: strength)
    }

    /// Source-list label (matches the model's capitalised names, HRV upper-cased).
    private static func sourceLabel(_ l: String) -> String { l == "hrv" ? "HRV" : String(localized: String.LocalizationValue(l.capitalized)) }
    /// Mid-sentence label (lower-case except the HRV acronym).
    private static func noteLabel(_ l: String) -> String { l == "hrv" ? "HRV" : String(localized: String.LocalizationValue(l)) }

    private static func pattern(topZ: Double, topDayIdx: Int, topSig: Int,
                                days: [Date], sourcesHit: Set<Int>,
                                calendar: Calendar) -> (String, [String], String) {
        let titled = sourcesHit.sorted().map { sourceLabel(signalLabels[$0]) }
        // Nothing reached the "high"/"outlier" band → a steady week.
        guard topSig >= 0, topZ >= 1.0, topDayIdx >= 0 else {
            return (String(localized: "Your week looked steady — nothing strayed far from your usual pattern."),
                    [], String(localized: "Steady"))
        }
        let fmt = DateFormatter()
        fmt.calendar = calendar
        fmt.locale = Locale.autoupdatingCurrent
        fmt.dateFormat = "EEEE"
        let weekday = fmt.string(from: days[topDayIdx])
        let top = noteLabel(signalLabels[topSig])
        let strength = topZ >= 2.0 ? String(localized: "Strong") : String(localized: "Moderate")

        let note: String
        if titled.count >= 2 {
            let others = titled.filter { $0.caseInsensitiveCompare(top) != .orderedSame }
            let joined = others.joined(separator: " and ")
            note = String(localized: "Your \(top) on \(weekday) stood out most from your usual this week, alongside shifts in \(joined). Worth a look — it's your pattern to read.")
        } else {
            note = String(localized: "Your \(top) on \(weekday) stood out most from your usual this week. Worth a look — it's your pattern to read.")
        }
        return (note, titled, strength)
    }
}

// MARK: - CALENDAR column (FR-CTX-CAL-01)
//
// The sixth column stopped being an honest coming-soon placeholder when the
// calendar-load signal landed. It is derived here so it obeys exactly the same
// rule as the four HealthKit columns: a cell is |deviation| from THIS person's
// own usual, in the same z-bands, and nothing else.
//
// What is deliberately NOT here:
//   • no population norm and no "recommended" number of meetings — there is no
//     such thing to compare a person to;
//   • no causal claim — a full day is never said to have moved a reading. The
//     grid places two facts side by side; the citizen reads their own life;
//   • no judgement — "fuller than your usual" is an observation, and no copy
//     built on it may suggest how someone ought to spend their time.
//
// The input is `[CalendarDayLoad]` — numbers. No event content can reach this
// file because none exists after `CalendarLoadIngestor.intervals`.
extension CorrelationDeriver {

    /// Column index of CALENDAR in `signalLabels` (and in `CorrelationDay.values`).
    public static let calendarIndex = 5

    /// The person's own usual booked hours, or nil when there isn't enough of
    /// their history to have a usual yet.
    public static func calendarUsual(_ history: [CalendarDayLoad]) -> Baseline? {
        guard CalendarLoadDeriver.hasUsableBaseline(history) else { return nil }
        return Baseline.from(CalendarLoadDeriver.baselineWindow(history).map(\.scheduledHours))
    }

    /// What the calendar row can honestly say. `connected` must be the REAL
    /// state (opted in AND iOS granted read access) — never a literal.
    public static func calendarRowState(connected: Bool,
                                        history: [CalendarDayLoad]) -> CalendarRowState {
        guard connected else { return .notConnected }
        if history.isEmpty { return .calibrating(daysSoFar: 0) }
        if CalendarLoadDeriver.isEntirelyEmpty(history) { return .noEntriesAtAll }
        guard CalendarLoadDeriver.hasUsableBaseline(history) else {
            return .calibrating(daysSoFar: CalendarLoadDeriver.baselineWindow(history).count)
        }
        return .ready
    }

    /// One cell per display date. A date with no stored reading is `.noData` —
    /// never a zero, which would assert the citizen had an empty day.
    public static func calendarCells(history: [CalendarDayLoad],
                                     over dates: [Date],
                                     connected: Bool,
                                     calendar: Calendar = Calendar(identifier: .gregorian)) -> [CorrelationCell] {
        let empty = Array(repeating: CorrelationCell.noData, count: dates.count)
        guard case .ready = calendarRowState(connected: connected, history: history),
              let base = calendarUsual(history) else { return empty }

        return dates.map { d in
            guard let load = self.calendarLoad(for: d, in: history, calendar: calendar) else {
                return .noData
            }
            guard base.sd > 0 else { return .low }
            let z = abs(load.scheduledHours - base.mean) / base.sd
            switch z {
            case ..<0.5: return .low
            case ..<1.0: return .medium
            case ..<2.0: return .high
            default:     return .outlier
            }
        }
    }

    /// The stored day matching a display date, or nil when that day is not
    /// something Liviqa can honestly speak about: either it was never read, or
    /// it falls before the citizen's first recorded entry, where an empty day
    /// means "this calendar wasn't kept here yet" rather than "a clear day".
    /// Both the cells and the readout go through this, so they cannot disagree.
    public static func calendarLoad(for date: Date, in history: [CalendarDayLoad],
                                    calendar: Calendar = Calendar(identifier: .gregorian)) -> CalendarDayLoad? {
        CalendarLoadDeriver.baselineWindow(history)
            .first { calendar.isDate($0.dayStart, inSameDayAs: date) }
    }

    /// Which side of the person's own usual a day sat on. Never a verdict —
    /// the copy layer turns this into "fuller / emptier than your usual".
    public static func calendarDirection(_ load: CalendarDayLoad,
                                         usual: Baseline?) -> CalendarLoadCopy.Direction? {
        guard let usual, usual.sd > 0 else { return nil }
        let delta = load.scheduledHours - usual.mean
        if abs(delta) < 0.5 * usual.sd { return .likeUsual }
        return delta > 0 ? .busier : .quieter
    }
}
