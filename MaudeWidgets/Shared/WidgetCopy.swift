// WidgetCopy.swift — every user-facing STATIC string the widgets and the
// complication can render, in one place.
//
// Why one place: FR-NDG-06 is a designated control. The dynamic `verdict`
// sentence is re-checked through `NudgeGuard` by the app-side publisher before
// it is written, but the widget's own chrome is written here, in the extension,
// where NudgeGuard does not live. Collecting it into a single table makes it
// sweepable: T-WID-02 runs `NudgeGuard.check` over `WidgetCopy.allStatic` and
// fails on any forbidden construction.
//
// Rails these strings respect:
//   • no dose, no treatment directive, no dosing verb (FR-NDG-06)
//   • no diagnostic claim, no clinical-normality word ("normal", "healthy range")
//   • personal-baseline-relative only — "your range", never a reference range
//   • no composite score vocabulary ("score", "grade", "rating") — the widget
//     shows decomposed parts, which is the whole point of this absorb
//   • honest absence: the empty-state copy says there is nothing yet, and
//     never stands in for a number
//
// Pure Foundation (NFR-PORT-01).
import Foundation

public nonisolated enum WidgetCopy {

    // MARK: Kickers (the only all-caps, per the A7.2 type scale)

    public static var morningKicker: String { String(localized: "Today") }
    public static var eveningKicker: String { String(localized: "Tonight") }
    public static var brandKicker: String { String(localized: "Maude") }

    // MARK: Time in range (two-state — inside your range / outside it)

    /// "68% in range"
    public static func inRangeHeadline(_ pct: Int) -> String {
        String(localized: "\(pct)% in range")
    }
    /// "32% outside" — the second of the two states, named explicitly.
    public static func outsideLabel(_ pct: Int) -> String {
        String(localized: "\(pct)% outside")
    }
    /// "6 of your last 7 days have readings" — the shown work: how much data is
    /// behind the picture. Singular kept so one day does not read as a bug.
    public static func coverageFooter(days: Int, of windowDays: Int) -> String {
        days == 1
            ? String(localized: "1 of your last \(windowDays) days has readings")
            : String(localized: "\(days) of your last \(windowDays) days have readings")
    }
    /// Range wording is always the user's OWN target band, never a clinical one.
    public static var yourRangeCaption: String { String(localized: "inside your range") }

    // MARK: Staleness

    /// Prefix used by `WidgetStaleness.asOfText`. Kept here for the sweep.
    public static var asOfExample: String { String(localized: "as of 07:12") }

    // MARK: Honest empty / absent states — never a placeholder figure

    public static var emptyTitle: String { String(localized: "Nothing to show yet") }
    public static var emptyBody: String {
        String(localized: "Open Maude to build today's edition.")
    }
    public static var noGlucoseLine: String {
        String(localized: "No glucose readings yet")
    }
    public static var calibratingNote: String {
        String(localized: "Still learning your usual")
    }
    /// Shown when a chip has a value but no baseline word yet.
    public static var placeholderDash: String { "—" }

    // MARK: Complication labels (watchOS)

    public static var complicationInRangeLabel: String { String(localized: "In range") }
    public static var complicationName: String { String(localized: "In range") }
    public static var complicationDescription: String {
        String(localized: "Your time in range, and when it was last updated.")
    }

    // MARK: Widget gallery entries

    public static var editionWidgetName: String { String(localized: "Today's edition") }
    public static var editionWidgetDescription: String {
        String(localized: "Your edition sentence, the signals behind it, and your time in range.")
    }

    // MARK: Accessibility

    public static func accessibilityTimeInRange(_ pct: Int) -> String {
        String(localized: "\(pct) percent inside your range, \(100 - pct) percent outside.")
    }
    public static var accessibilityDecomposed: String {
        String(localized: "The signals behind this sentence.")
    }

    // MARK: The sweep list (T-WID-02)

    /// Every static string above, with the formatted variants exercised at
    /// representative values. A new string that is NOT added here is not swept,
    /// so add it when you add copy.
    public static var allStatic: [String] {
        [
            morningKicker, eveningKicker, brandKicker,
            inRangeHeadline(68), outsideLabel(32),
            coverageFooter(days: 6, of: 7), coverageFooter(days: 1, of: 7),
            yourRangeCaption, asOfExample,
            emptyTitle, emptyBody, noGlucoseLine, calibratingNote, placeholderDash,
            complicationInRangeLabel, complicationName, complicationDescription,
            editionWidgetName, editionWidgetDescription,
            accessibilityTimeInRange(68),
            accessibilityDecomposed,
        ]
    }
}
