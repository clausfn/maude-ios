// WidgetSnapshotPublisher.swift — APP-SIDE writer for FR-WID-01.
//
// TARGET MEMBERSHIP: the **Liviqa iOS app target ONLY**. It references
// `AppState`, `TodaySignals` and `NudgeGuard`, none of which exist in an
// extension. (`LiviqaWidgets/Shared/` is what the extensions get.)
//
// The app derives exactly as it always has; this file takes the finished Home
// state and mirrors it into the App Group container so a widget can render it
// without ever touching the protected store. Same discipline as
// `PhoneWatchSync` / `AppState.syncWatchGlance()` — deliberately modelled on it
// so the wrist, the widget and the screen cannot disagree.
//
// THE GATE. `NudgeGuard.check` runs on the verdict sentence before it is
// written. FR-NDG-06 is a designated control: if the sentence somehow carries a
// forbidden construction it is NOT published — the neutral allow-listed steady
// line goes out instead, and DEBUG builds trap so it is caught in development.
// A guarded surface never degrades to "publish anyway".
//
// HONESTY. Nothing here fabricates. If there are no derived signals the
// publisher CLEARS the snapshot, so the widget falls back to its empty state
// instead of showing a stale figure forever. Demo seeds are not synthesised
// here: what the widget shows is what Home shows, and Home's own seeds are
// already gated behind `isDemoData`.
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Pure composer (unit-testable without AppState / MainActor)

nonisolated enum WidgetSnapshotComposer {

    /// Kind string of the iOS home-screen widget — must match
    /// `LiviqaEditionWidget.kind` in the widget extension target.
    static let editionWidgetKind = "LiviqaEditionWidget"

    /// Build the snapshot from derived Home state.
    ///
    /// - Parameters:
    ///   - signals: the app's derived `TodaySignals`. nil ⇒ nothing to publish.
    ///   - verdict: the sentence Home shows (`AppState.watchStateLine(for:)`).
    ///   - sleepHeadline: Home's own last-night sleep string, when available, so
    ///     the widget cannot disagree with the front page.
    /// - Returns: nil when there is nothing honest to show — the caller clears.
    static func compose(signals: TodaySignals?,
                        verdict: String,
                        sleepHeadline: String?,
                        now: Date = Date()) -> LiviqaWidgetSnapshot? {
        guard let s = signals else { return nil }
        return LiviqaWidgetSnapshot(
            derivedAt: now,
            edition: WidgetEdition.current(at: now),
            verdict: guardedVerdict(verdict),
            chips: chips(for: s, sleepHeadline: sleepHeadline),
            timeInRange: timeInRange(for: s))
    }

    // MARK: FR-NDG-06 gate

    /// The fallback when a sentence fails the guard: the app's own neutral,
    /// allow-listed steady line. Never a blank, never the offending text.
    static var neutralVerdict: String { String(localized: "You're having a steady week.") }

    /// Run the designated control, and trap in DEBUG so a regression is caught
    /// in development rather than shipped.
    static func guardedVerdict(_ text: String) -> String {
        let clean = sanitizedVerdict(text)
        #if DEBUG
        if clean != text.trimmingCharacters(in: .whitespacesAndNewlines),
           let violation = NudgeGuard.check(text) {
            assertionFailure("FR-NDG-06: widget verdict carried \(violation.rawValue): \(text)")
        }
        #endif
        return clean
    }

    /// The same control WITHOUT the debug trap, so T-WID-02 can assert the
    /// fallback behaviour on deliberately-violating input.
    static func sanitizedVerdict(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return neutralVerdict }
        return NudgeGuard.check(trimmed) == nil ? trimmed : neutralVerdict
    }

    // MARK: Decomposed chips (the anti-score-opacity payload)

    /// Sleep · Recovery · Heart. Glucose is not a chip — it is the two-state TIR
    /// read, which gets its own row.
    ///
    /// The baseline-relative words and thresholds MIRROR `TodayView`
    /// (`sleepVerdict` / `recoveryVerdict` / `heartVerdict`, and the ≥0.4 h /
    /// ≥2 ms trend deltas). Change them together or the surfaces drift.
    static func chips(for s: TodaySignals, sleepHeadline: String?) -> [WidgetSignalChip] {
        var out: [WidgetSignalChip] = []
        let dash = WidgetCopy.placeholderDash

        let sleepValue = sleepHeadline ?? s.sleep
        if sleepValue != dash, !sleepValue.isEmpty {
            out.append(WidgetSignalChip(
                label: String(localized: "Sleep"),
                value: sleepValue,
                note: trendingUp(s.sleepWeek, by: 0.4)
                    ? String(localized: "A little longer")
                    : String(localized: "As usual")))
        }

        if s.hrv != dash, !s.hrv.isEmpty {
            out.append(WidgetSignalChip(
                label: String(localized: "Recovery"),
                // Unit carried inline, matching the wrist glance (Area ⑧ fix).
                value: "\(s.hrv) ms",
                note: trendingUp(s.hrvWeek, by: 2)
                    ? String(localized: "On the way up")
                    : String(localized: "Steady")))
        }

        if s.rhr != dash, !s.rhr.isEmpty {
            out.append(WidgetSignalChip(
                label: String(localized: "Heart"),
                value: s.rhr,
                note: String(localized: "Calm")))
        }

        return out
    }

    /// Second-half vs first-half average of the user's OWN 7-day series.
    /// Verbatim from `TodayView.trendingUp` / `PhoneWatchSync`.
    static func trendingUp(_ series: [Double], by delta: Double) -> Bool {
        guard series.count >= 4 else { return false }
        let half = series.count / 2
        let early = series.prefix(half), late = series.suffix(series.count - half)
        return late.reduce(0, +) / Double(late.count)
             - early.reduce(0, +) / Double(early.count) >= delta
    }

    // MARK: Two-state time in range

    /// nil ⇒ no glucose figure → the widget prints the honest "no readings yet"
    /// line instead of an empty bar that would read as 0%.
    static func timeInRange(for s: TodaySignals) -> WidgetTimeInRange? {
        guard let pct = percentValue(s.inRange) else { return nil }
        return WidgetTimeInRange(inRangePct: pct,
                                 daysWithReadings: s.inRangeWeek.count,
                                 coverageWindowDays: 7)
    }

    /// "61%" → 61 · "—" → nil. Deliberately strict: anything unparseable is
    /// treated as absent rather than coerced to a number.
    static func percentValue(_ text: String) -> Int? {
        guard text.hasSuffix("%") else { return nil }
        let digits = text.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count == text.count - 1, let v = Int(digits) else { return nil }
        return min(100, max(0, v))
    }
}

// MARK: - AppState hook

extension AppState {

    /// Mirror the current Home edition into the App Group for the widget and
    /// the complication. Safe to call often; cheap (one small JSON write) and a
    /// silent no-op when the App Group is not provisioned.
    ///
    /// INTEGRATION: called alongside `syncWatchGlance()` — see
    /// `LiviqaWidgets/SETUP.md` §7.
    @MainActor
    func publishWidgetSnapshot(now: Date = Date()) {
        let sleepHeadline = sleepSummary.map {
            "\($0.asleepMinutes / 60)h \(String(format: "%02d", $0.asleepMinutes % 60))"
        }
        let snapshot = WidgetSnapshotComposer.compose(
            signals: todaySignals,
            verdict: watchStateLine(for: todaySignals),
            sleepHeadline: sleepHeadline,
            now: now)

        if let snapshot {
            LiviqaWidgetSnapshotStore.save(snapshot)
        } else {
            LiviqaWidgetSnapshotStore.clear()
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotComposer.editionWidgetKind)
        #endif
    }
}
