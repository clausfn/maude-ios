// MealMarkDeriver.swift — the honest food answer (CN directive 2026-08-19).
//
// Maude has no nutrition tracker, and this file does not invent one. What the
// app HAS is journal MEAL entries (JournalView's "Add meal" capture, tag
// `mealTag`). This deriver surfaces those real, logged meals as time marks on
// the same 0…24 wall-clock axis the glucose day curve uses
// (`GlucoseWeekDetail.TodayPoint.hour`) — so the design's fabricated "after
// lunch" annotations become the honest version: a mark where the citizen
// actually logged a meal, saying only WHEN it was logged, never that it moved
// a reading.
//
// Rails held:
//  · No fabricated data — a mark exists only for a real entry the signed-in
//    account wrote (the caller passes `AppState.journalEntries`, which is
//    account-scoped per FR-JRNL-SCOPE-01). No entries ⇒ no marks ⇒ the curve
//    renders exactly as before.
//  · The fixed label template ("Meal logged · HH:MM") passes NudgeGuard
//    (FR-NDG-06). The citizen's own words are carried verbatim for the detail
//    readout — their words are theirs, not generated copy.
//  · `hour` is when the entry was CREATED. That is what the app truly knows —
//    the label says "logged", not "eaten".
//
// Pure Foundation (NFR-PORT-01). Internal because `JournalEntry` is internal.
import Foundation

/// One logged meal, positioned on the day's wall-clock axis.
nonisolated struct MealMark: Equatable, Identifiable, Sendable {
    let id: UUID
    /// 0…24 fraction of the day — the same axis as `GlucoseWeekDetail.TodayPoint`.
    let hour: Double
    /// "12:40" (24 h).
    let timeText: String
    /// The citizen's own first line, verbatim (may be empty).
    let words: String
}

nonisolated enum MealMarkDeriver {

    /// The one tag that means "meal" — JournalView's capture button writes it,
    /// this deriver reads it. Single constant so the two can never drift.
    static let mealTag = "Meal"

    /// The meals the account logged on `day`, chronological. Empty when none —
    /// never a placeholder.
    static func marks(in entries: [JournalEntry], on day: Date,
                      calendar: Calendar = Calendar(identifier: .gregorian)) -> [MealMark] {
        entries
            .filter { entry in
                entry.tags.contains { $0.caseInsensitiveCompare(mealTag) == .orderedSame }
                    && calendar.isDate(entry.createdAt, inSameDayAs: day)
            }
            .sorted { $0.createdAt < $1.createdAt }
            .map { entry in
                let c = calendar.dateComponents([.hour, .minute], from: entry.createdAt)
                let h = c.hour ?? 0, m = c.minute ?? 0
                return MealMark(
                    id: entry.id,
                    hour: Double(h) + Double(m) / 60,
                    timeText: String(format: "%02d:%02d", h, m),
                    words: firstLine(of: entry.body))
            }
    }

    /// The fixed on-curve label for a mark — a fact about the journal, never a
    /// claim about the reading next to it (FR-NDG-06-tested).
    static func label(for mark: MealMark) -> String {
        String(localized: "Meal logged · \(mark.timeText)")
    }

    private static func firstLine(of body: String) -> String {
        body.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }
}
