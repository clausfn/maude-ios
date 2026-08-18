// ColdStartSeeds.swift — honest first-launch state (T1 TestProd wave, 2026-07-07).
//
// DEBUG (demo builds, FR-ARCH-05): the polished synthetic seeds, as before.
// RELEASE (TestProd/TestFlight): NO mock seeding — every surface starts EMPTY
// and fills only from the user's own HealthKit backfill / the live backend.
// Fabricated readings, tokens, conditions or grants must never render as the
// user's own on a shipped build (launch-audit PR-102 line, extended app-wide).
import Foundation

extension AppState {

    enum ColdStart {
        #if DEBUG
        static let rings            = MockData.rings
        static let nudges           = MockData.todayNudges
        static let connectedSources = MockData.connectedSources
        static let passportStats    = MockData.passportStats
        static let correlationWeek  = MockData.correlationWeek
        static let tokenBalance     = 47
        static let tokenTransactions = MockData.tokenTransactions
        static let healthContext    = HealthContext.demo
        #else
        static let rings: [MetricRing] = []
        static let nudges: [Nudge] = []
        /// Apple Health is the only real source at cold start — shown honestly
        /// as not-yet-connected until a HealthKit fetch returns readings.
        static let connectedSources: [DataSourceConnection] = [
            .init(
                name: "Apple Health",
                icon: "heart.fill",
                iconColorHex: 0xFF3B30,
                category: .health,
                isConnected: false,
                lastSync: nil,
                dataDescription: String(localized: "Heart rate, sleep, steps, glucose"),
                privacyNote: String(localized: "Read-only. Never written back to Apple Health.")
            ),
        ]
        static let passportStats = PassportStats(
            totalReadings: 0, nudgesGenerated: 0, sourcesConnected: 0,
            daysTracked: 0, glucoseTimeInRange: 0, avgSleepHours: 0,
            journalEntries: 0, consentDecisions: 0)
        static let correlationWeek = CorrelationWeek(
            days: [], patternNote: "", patternSources: [], patternStrength: "")
        static let tokenBalance = 0
        static let tokenTransactions: [TokenTransaction] = []
        static let healthContext = HealthContext()
        #endif
    }

    /// True while there is nothing real to show on Home: no HealthKit readings,
    /// no derived signals, no insights. Drives the honest cold-start empty state
    /// ("baseline building — first insights after ~3 days") instead of demo
    /// placeholder values. Always false in DEBUG demo mode (seeds present).
    ///
    /// This is the state a citizen with nothing recorded yet MUST land in — it
    /// is the honest half of the split described in SampleMode.swift. Sample
    /// mode is the other half and is never entered from here: an empty app is
    /// an empty app, and says so, until the citizen asks for a sample.
    var isColdStartEmpty: Bool {
        if isSampleMode { return false }   // the sample IS the content, labelled
        return !usingRealData && todaySignals == nil && nudges.isEmpty
    }
}
