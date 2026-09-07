// MealMarkDeriverTests.swift — T-MEAL-01: the honest food surface
// (CN directive 2026-08-19). Meals exist ONLY as journal entries; the deriver
// turns the day's real MEAL entries into wall-clock marks for the glucose day
// curve — and nothing else. No nutrition model, no fabricated annotation.
//
// Pinned here:
//  · Only entries tagged `MealMarkDeriver.mealTag` on the requested day become
//    marks; everything else — other tags, other days — is left alone.
//  · The mark's hour sits on the same 0…24 axis as GlucoseWeekDetail.TodayPoint,
//    and its time text matches the entry's own clock time.
//  · The citizen's words are carried verbatim (first line), never rewritten.
//  · The one fixed label template passes NudgeGuard (FR-NDG-06) and states a
//    journal fact ("logged"), not a claim about a reading.
//  · No entries ⇒ no marks — the curve renders exactly as before.
import Testing
import Foundation
@testable import Maude

struct MealMarkDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func entry(_ body: String, tags: [String], at: Date) -> JournalEntry {
        JournalEntry(id: UUID(), body: body, tags: tags,
                     createdAt: at, updatedAt: at)
    }

    @Test func onlyMealEntriesOnTheDayBecomeMarksInClockOrder() {
        let day = date(2026, 8, 19, 0, 0)
        let entries = [
            entry("Late dinner", tags: [MealMarkDeriver.mealTag], at: date(2026, 8, 19, 19, 30)),
            entry("Rough night", tags: ["Sleep"], at: date(2026, 8, 19, 7, 0)),
            entry("Porridge with berries", tags: [MealMarkDeriver.mealTag], at: date(2026, 8, 19, 7, 45)),
            entry("Yesterday's lunch", tags: [MealMarkDeriver.mealTag], at: date(2026, 8, 18, 12, 15)),
            entry("Untagged note", tags: [], at: date(2026, 8, 19, 12, 0)),
        ]
        let marks = MealMarkDeriver.marks(in: entries, on: day, calendar: cal)
        #expect(marks.count == 2)
        #expect(marks.map(\.timeText) == ["07:45", "19:30"])
        #expect(marks.map(\.words) == ["Porridge with berries", "Late dinner"])
    }

    @Test func hourSitsOnTheGlucoseCurvesWallClockAxis() {
        let e = entry("Lunch", tags: [MealMarkDeriver.mealTag], at: date(2026, 8, 19, 12, 40))
        let marks = MealMarkDeriver.marks(in: [e], on: date(2026, 8, 19, 0, 0), calendar: cal)
        #expect(marks.count == 1)
        // 12:40 → 12.666… on the 0…24 axis (same convention as TodayPoint.hour).
        #expect(abs(marks[0].hour - (12 + 40.0 / 60)) < 0.001)
    }

    @Test func theTagMatchIsCaseInsensitiveButNeverFuzzy() {
        let day = date(2026, 8, 19, 0, 0)
        let entries = [
            entry("lowercase tag", tags: ["meal"], at: date(2026, 8, 19, 9, 0)),
            entry("looks similar, is not a meal", tags: ["Meals"], at: date(2026, 8, 19, 10, 0)),
            entry("substring, not a meal", tags: ["Oatmeal"], at: date(2026, 8, 19, 11, 0)),
        ]
        let marks = MealMarkDeriver.marks(in: entries, on: day, calendar: cal)
        #expect(marks.map(\.words) == ["lowercase tag"])
    }

    @Test func wordsAreTheFirstLineVerbatim() {
        let e = entry("Pasta with the family\nFelt full afterwards",
                      tags: [MealMarkDeriver.mealTag], at: date(2026, 8, 19, 18, 0))
        let marks = MealMarkDeriver.marks(in: [e], on: date(2026, 8, 19, 0, 0), calendar: cal)
        #expect(marks[0].words == "Pasta with the family")
    }

    @Test func noEntriesMeansNoMarksNeverAPlaceholder() {
        #expect(MealMarkDeriver.marks(in: [], on: Date()).isEmpty)
        let offDay = entry("Meal on another day", tags: [MealMarkDeriver.mealTag],
                           at: date(2026, 8, 12, 12, 0))
        #expect(MealMarkDeriver.marks(in: [offDay], on: date(2026, 8, 19, 0, 0),
                                      calendar: cal).isEmpty)
    }

    // FR-NDG-06 (designated control): the one generated template.
    @Test func theFixedLabelTemplatePassesTheGuardAndClaimsOnlyTheLogging() {
        let e = entry("Lunch", tags: [MealMarkDeriver.mealTag], at: date(2026, 8, 19, 12, 40))
        let mark = MealMarkDeriver.marks(in: [e], on: date(2026, 8, 19, 0, 0), calendar: cal)[0]
        let label = MealMarkDeriver.label(for: mark)
        #expect(NudgeGuard.check(label) == nil)
        #expect(label.contains("12:40"))
        // A journal fact, not a causal claim about the curve next to it.
        #expect(label.lowercased().contains("logged"))
    }

    // The capture button and the deriver read the ONE constant — the JournalView
    // source references MealMarkDeriver.mealTag, so the tag cannot drift.
    @Test func theCaptureButtonWritesTheSameTagTheDeriverReads() throws {
        let src = try SourceLint.text("Maude/Views/JournalView.swift")
        #expect(SourceLint.matches(#"expandComposer\(tag: MealMarkDeriver\.mealTag"#,
                                   in: src).count == 1)
    }
}
