// PassportStats+Derived.swift — compose the presentation-layer `PassportStats`
// from the on-device derived half (FR-PAS-05 / DM-05) and the count half held
// in app state. Keeps the derivation logic pure (see `PassportStatsDeriver`).
import Foundation

extension PassportStats {
    /// Compose the full passport figure: sensor-derived fields from
    /// `DerivedPassportStats`, declared/count fields from app state.
    static func compose(derived: DerivedPassportStats,
                        nudgesGenerated: Int,
                        sourcesConnected: Int,
                        journalEntries: Int,
                        consentDecisions: Int) -> PassportStats {
        PassportStats(
            totalReadings:      derived.totalReadings,
            nudgesGenerated:    nudgesGenerated,
            sourcesConnected:   sourcesConnected,
            daysTracked:        derived.daysTracked,
            glucoseTimeInRange: derived.glucoseTimeInRange,
            avgSleepHours:      derived.avgSleepHours,
            journalEntries:     journalEntries,
            consentDecisions:   consentDecisions)
    }
}
