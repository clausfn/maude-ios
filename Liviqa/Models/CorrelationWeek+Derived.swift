// CorrelationWeek+Derived.swift — adapt the pure `CorrelationGrid`
// (FR-PAS-05 / DM-06) into the presentation-layer `CorrelationWeek`. Keeps the
// derivation logic itself framework-free (see `CorrelationDeriver`).
import Foundation

extension CorrelationWeek {
    static func from(_ grid: CorrelationGrid) -> CorrelationWeek {
        CorrelationWeek(
            days: grid.rows.map { row in
                CorrelationDay(
                    dayLabel: row.dayLabel,
                    dateOffset: row.dateOffset,
                    values: row.cells.map { CorrelationLevel(rawValue: $0.rawValue) ?? .noData })
            },
            patternNote: grid.patternNote,
            patternSources: grid.patternSources,
            patternStrength: grid.patternStrength)
    }
}
