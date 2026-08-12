// LV001Dataset.swift — Claus's REAL mined dataset (LV001 persona), composed
// for the prototype's graphs. Generated from the consented goldmine export
// (glucose/HRV/RHR/steps/exercise daily aggregates + de-duplicated sleep).
// Values are provenance .real; locations/timestamps are NOT embedded. Mirrors
// the PatternSeed.lv001 idiom. Loaded by AppState when the profile alias is LV001.
import Foundation

// INTERNAL CONSISTENCY (2026-08-13): a demo must never show two numbers for the
// same thing. Two contradictions were carried here and are fixed:
//   • the TIR ring said "GMI 6.8%" while the glucose detail this session opens
//     (GlucoseDetailView.designSeed — LV001 ships aggregates, not raw readings,
//     so `glucoseDetail` is deliberately nil) says 6.1%. The detail is the
//     anchor: TIR 88%, average 6.2 mmol/L, GMI 6.1%.
//   • every week sparkline ends on TODAY (see TodaySignalsDeriver.weekSeries),
//     so the last point of each series must be the same number as its chip.
enum LV001Dataset {
    static let passportStats = PassportStats(
        totalReadings:      9971,
        nudgesGenerated:    312,
        sourcesConnected:   20,
        daysTracked:        3499,
        glucoseTimeInRange: 88,
        avgSleepHours:      7.17,
        journalEntries:     0,
        consentDecisions:   0
    )

    static let rings: [MetricRing] = [
        .init(label: String(localized: "Sleep"), value: "7h 10", progress: 0.9, warn: false, subvalue: nil),
        .init(label: "TIR", value: "88%", progress: 0.88, warn: false, subvalue: "GMI 6.1%"),
        .init(label: "HRV", value: "27 ms", progress: 0.34, warn: true, subvalue: nil),
        .init(label: String(localized: "Steps"), value: "5.5k", progress: 0.55, warn: false),
    ]

    // Home chips + "Your Week" headlines & sparklines (WeekInContextView reads these).
    static let todaySignals = TodaySignals(
        sleep: "7h10", inRange: "88%", hrv: "27", rhr: "70",
        inRangeIsClay: false,
        // Each series ends on TODAY, so each last value IS its chip above.
        sleepWeek: [7.9, 7.4, 9.4, 8.7, 8.7, 8.1, 7.17],
        inRangeWeek: [86, 86, 86, 100, 100, 100, 88],
        hrvWeek: [31, 28, 27, 23, 23, 29, 27],
        rhrWeek: [70, 73, 69, 72, 70, 71, 70],
        glucoseToday: []
    )

    static let correlationWeek = CorrelationWeek(
        days: [
            CorrelationDay(dayLabel: "M", dateOffset: 6, values: [.medium, .medium, .medium, .high, .noData, .noData, .noData]),
            CorrelationDay(dayLabel: "T", dateOffset: 5, values: [.medium, .medium, .medium, .medium, .noData, .noData, .noData]),
            CorrelationDay(dayLabel: "W", dateOffset: 4, values: [.medium, .noData, .medium, .medium, .noData, .noData, .noData]),
            CorrelationDay(dayLabel: "T", dateOffset: 3, values: [.medium, .low, .medium, .medium, .noData, .noData, .noData]),
            CorrelationDay(dayLabel: "F", dateOffset: 2, values: [.medium, .noData, .medium, .medium, .noData, .noData, .noData]),
            CorrelationDay(dayLabel: "S", dateOffset: 1, values: [.medium, .outlier, .medium, .medium, .noData, .noData, .noData]),
            CorrelationDay(dayLabel: "S", dateOffset: 0, values: [.medium, .medium, .medium, .medium, .noData, .noData, .noData]),
        ],
        patternNote: String(localized: "Across your own record — 3499 days tracked — your glucose stays in range 88% of the time, with HRV and exercise moving together through the week."),
        patternSources: ["Glucose", "HRV", String(localized: "Exercise")],
        patternStrength: String(localized: "Strong")
    )
}
