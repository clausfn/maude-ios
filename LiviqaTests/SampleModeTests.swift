import Testing
import Foundation
import SwiftData
@testable import Liviqa

// FR-SMP-01…05 — opt-in, unmistakably-labelled SAMPLE MODE.
//
// The 2026-08-13 incident (qms/CHANGELOG.md PR-111) was fabricated content
// rendering as a citizen's own. Its enabling condition was a single flag,
// `isDemoData == !usingRealData`: "we have no real readings yet" was the same
// bit as "show the demo values". These tests hold the two apart and pin the
// four promises that follow from separating them — off by default, synthetic
// only, always labelled, and gone without trace when the citizen leaves.
//
// @MainActor to match the project's default isolation.
@MainActor
struct SampleModeTests {

    // MARK: - Fixtures

    /// Every state under test is fully ISOLATED, because the suite runs in
    /// parallel with the rest of LiviqaTests in one host process:
    ///   • its own UserDefaults suite — the sample-mode flag cannot race
    ///     another test through `.standard` (the BackupPostureTests flake
    ///     class);
    ///   • its own in-memory ModelContainer — a store-count assertion is
    ///     judged only against what THIS AppState wrote, never against another
    ///     test's ingest into (or erase of) the shared on-disk file;
    ///   • the `.mock` provider seam — no unit test may await a real
    ///     HealthKit path: on a headless host the authorisation request never
    ///     returns and hangs the whole suite.
    private func makeIsolated() -> (s: AppState, defaults: UserDefaults) {
        let defaults = makeDefaults()
        let s = AppState(supabase: MockSupabaseService(),
                         sampleModeDefaults: defaults,
                         store: try? LiviqaStore.makeContainer(inMemory: true))
        s.dataProviderKind = .mock
        return (s, defaults)
    }

    private func makeState() -> AppState { makeIsolated().s }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "sample-mode-\(UUID().uuidString)")!
    }

    /// Everything the overlay touches, as one comparable value — so "leaving
    /// restored exactly what was there" is an assertion, not an impression.
    private struct Fingerprint: Equatable {
        var nudges: [Nudge]
        var signals: TodaySignals?
        var glucoseIsNil: Bool
        var sleepIsNil: Bool
        var trendsIsNil: Bool
        var baselinesIsNil: Bool
        var hrvLearnIsNil: Bool
        var passport: [Int]
        var avgSleep: Double
        var patternNote: String
        var merges: Int

        @MainActor init(_ s: AppState) {
            nudges = s.nudges
            signals = s.todaySignals
            glucoseIsNil = s.glucoseDetail == nil
            sleepIsNil = s.sleepSummary == nil
            trendsIsNil = s.trends == nil
            baselinesIsNil = s.baselines == nil
            hrvLearnIsNil = s.hrvLearn == nil
            passport = [s.passportStats.totalReadings, s.passportStats.nudgesGenerated,
                        s.passportStats.sourcesConnected, s.passportStats.daysTracked,
                        s.passportStats.glucoseTimeInRange, s.passportStats.journalEntries,
                        s.passportStats.consentDecisions]
            avgSleep = s.passportStats.avgSleepHours
            patternNote = s.correlationWeek.patternNote
            merges = s.workoutMerges.count
        }
    }

    // MARK: - (a) The rule that was missing

    /// The incident invariant, stated directly: having no real readings is NOT
    /// a licence to render an invented value. Only the citizen's own request is.
    @Test func noRealDataIsNeverALicenceToInvent() {
        #expect(SampleModePolicy.mayRenderSampleValues(sampleModeOn: false,
                                                       hasRealReadings: false) == false)
        #expect(SampleModePolicy.mayRenderSampleValues(sampleModeOn: false,
                                                       hasRealReadings: true) == false)
        #expect(SampleModePolicy.mayRenderSampleValues(sampleModeOn: true,
                                                       hasRealReadings: false) == true)
    }

    /// The labelling is not a preference. `liviqaShowDemoChip` defaulted to
    /// FALSE and that is how unlabelled seeds reached testers; the replacement
    /// takes a preference argument and ignores it, in both positions.
    @Test func theLabelCannotBeSwitchedOffWhileSampleModeIsOn() {
        #expect(SampleModePolicy.labelIsVisible(sampleModeOn: true, userPreference: false))
        #expect(SampleModePolicy.labelIsVisible(sampleModeOn: true, userPreference: true))
        #expect(SampleModePolicy.labelIsVisible(sampleModeOn: false, userPreference: true) == false)
    }

    /// Every way in is a deliberate act of the citizen. The count is asserted so
    /// that adding an automatic entry ("the app looked empty, so…") cannot pass
    /// review silently — it fails here first.
    @Test func everyEntryIsDeliberate() {
        #expect(SampleModePolicy.Entry.allCases.count == 2)
        #expect(Set(SampleModePolicy.Entry.allCases.map(\.rawValue))
                == ["onboardingChoice", "settingsChoice"])
        for entry in SampleModePolicy.Entry.allCases {
            #expect(SampleModePolicy.mayEnter(entry))
        }
    }

    // MARK: - (b) Off by default

    @Test func sampleModeIsOffOnAFreshInstall() {
        let defaults = makeDefaults()
        #expect(SampleModeStore.isOn(defaults) == false)
        SampleModeStore.set(true, defaults)
        #expect(SampleModeStore.isOn(defaults))
        SampleModeStore.set(false, defaults)
        #expect(SampleModeStore.isOn(defaults) == false)
        // Off is stored as ABSENT, not as `false` — nothing to misread later.
        #expect(defaults.object(forKey: SampleModeStore.key) == nil)
    }

    /// A brand-new session — no readings, nothing derived — is NOT a sample
    /// session, and does not describe itself as one. This is the exact state
    /// the incident rendered fabricated content in.
    @Test func aFreshAccountWithNoReadingsIsNotASampleSession() {
        let s = makeState()
        #expect(s.isSampleMode == false)
        #expect(s.hasNoRealReadings)          // true, and it changes nothing
        #expect(s.isDemoData == false)        // the old alias no longer flips here
        #expect(SampleModePolicy.mayRenderSampleValues(
            sampleModeOn: s.isSampleMode, hasRealReadings: !s.hasNoRealReadings) == false)
    }

    /// …and with nothing derived it lands in the honest empty state, which is
    /// what the Home screen renders instead of stand-in figures.
    @Test func aFreshAccountWithNoReadingsShowsTheHonestEmptyState() {
        let s = makeState()
        s.nudges = []
        s.todaySignals = nil
        #expect(s.isColdStartEmpty)
        #expect(s.isSampleMode == false)
    }

    /// A refresh — the one thing that runs by itself at launch — cannot turn
    /// sample mode on, whatever the fetch returns. Proven against the injected
    /// `.mock` provider (the fixture's seam): the refresh runs the FULL ingest
    /// and deriver chain on a fetch that returns readings, and the flag stays
    /// off. Deliberately NOT a live `HealthKit` read — `requestAuthorization`
    /// never returns on a headless host and this test once hung the suite.
    @Test func refreshNeverEntersSampleMode() async {
        let (s, defaults) = makeIsolated()
        await s.refreshFromHealth()
        #expect(s.didAttemptHealthFetch)     // the ingest path genuinely ran
        #expect(s.isSampleMode == false)
        #expect(SampleModeStore.isOn(defaults) == false)
        // And the pure policy agrees: readings arriving (or not) is never an
        // entry — only the two deliberate acts are (`everyEntryIsDeliberate`).
        #expect(SampleModePolicy.mayRenderSampleValues(
            sampleModeOn: false, hasRealReadings: !s.hasNoRealReadings) == false)
    }

    // MARK: - (c) Entering, leaving, and leaving nothing behind

    @Test func enteringShowsTheSampleAndLeavingRestoresExactlyWhatWasThere() async {
        let s = makeState()
        defer { s.clearSampleModeForErase() }

        // A "real" session state to protect: whatever this citizen had.
        s.nudges = []
        s.todaySignals = TodaySignals(sleep: "7h 41", inRange: "82%", hrv: "63", rhr: "51",
                                      inRangeIsClay: false,
                                      sleepWeek: [7.1, 7.4], inRangeWeek: [80, 82],
                                      hrvWeek: [61, 63], rhrWeek: [52, 51])
        s.passportStats = PassportStats(totalReadings: 12, nudgesGenerated: 1, sourcesConnected: 1,
                                        daysTracked: 4, glucoseTimeInRange: 82, avgSleepHours: 7.4,
                                        journalEntries: 3, consentDecisions: 2)
        let before = Fingerprint(s)

        await s.enterSampleMode(.settingsChoice)
        #expect(s.isSampleMode)
        let during = Fingerprint(s)
        #expect(during != before, "sample mode changed nothing on screen")
        #expect(s.todaySignals != before.signals)

        s.exitSampleMode()
        #expect(s.isSampleMode == false)
        #expect(Fingerprint(s) == before, "leaving sample mode left residue")
        // And no bookkeeping is left holding a synthetic week in memory.
        #expect(s.sampleSnapshotStorage == nil)
        #expect(s.sampleDerivationStorage == nil)
        #expect(s.sampleOverlayApplied == false)
    }

    /// Entering twice must not snapshot the SAMPLE over the citizen's own data —
    /// that would be residue disguised as a restore.
    @Test func applyingTheOverlayTwiceStillRestoresTheRealSurfaces() async {
        let s = makeState()
        defer { s.clearSampleModeForErase() }
        s.nudges = []
        s.todaySignals = TodaySignals(sleep: "6h 02", inRange: "58%", hrv: "39", rhr: "60",
                                      inRangeIsClay: true,
                                      sleepWeek: [6.0], inRangeWeek: [58],
                                      hrvWeek: [39], rhrWeek: [60])
        let before = Fingerprint(s)

        await s.enterSampleMode(.onboardingChoice)
        s.applySampleOverlay()          // a second apply (relaunch/refresh path)
        s.applySampleOverlay()
        await s.resumeSampleModeIfOn()
        s.exitSampleMode()

        #expect(Fingerprint(s) == before)
    }

    @Test func aSecondEntryIsANoOpAndCannotReSnapshot() async {
        let s = makeState()
        defer { s.clearSampleModeForErase() }
        s.todaySignals = TodaySignals(sleep: "8h 00", inRange: "90%", hrv: "70", rhr: "48",
                                      inRangeIsClay: false, sleepWeek: [8], inRangeWeek: [90],
                                      hrvWeek: [70], rhrWeek: [48])
        let before = Fingerprint(s)
        await s.enterSampleMode(.settingsChoice)
        await s.enterSampleMode(.settingsChoice)   // guarded
        s.exitSampleMode()
        #expect(Fingerprint(s) == before)
    }

    /// Leaving with no snapshot (sample mode was entered in an earlier launch)
    /// must still leave nothing synthetic on screen.
    @Test func leavingWithoutASnapshotFallsBackToTheFirstLaunchSurfaces() async {
        let s = makeState()
        defer { s.clearSampleModeForErase() }
        await s.enterSampleMode(.settingsChoice)
        s.sampleSnapshotStorage = nil          // as if the process had restarted
        s.exitSampleMode()
        #expect(s.isSampleMode == false)
        #expect(s.todaySignals == nil)
        #expect(s.glucoseDetail == nil)
        #expect(s.trends == nil)
        #expect(s.baselines == nil)
    }

    @Test func eraseTakesSampleModeWithIt() async {
        let (s, defaults) = makeIsolated()
        await s.enterSampleMode(.settingsChoice)
        #expect(s.isSampleMode)
        #expect(SampleModeStore.isOn(defaults))
        s.clearSampleModeForErase()
        #expect(s.isSampleMode == false)
        #expect(SampleModeStore.isOn(defaults) == false)
        #expect(s.sampleSnapshotStorage == nil)
        #expect(s.sampleDerivationStorage == nil)
    }

    // MARK: - (d) No contamination

    /// The on-device store is the place a real reading lives. Entering sample
    /// mode, and refreshing while it is on, must add exactly nothing to it.
    ///
    /// The store here is THIS test's own injected in-memory container. In the
    /// combined suite the shared on-disk file is concurrently written by other
    /// tests' real mock ingests (HealthReadOutcomeTests) and wiped by the erase
    /// tests (EraseOrderingTests) — noise that once failed this test although
    /// no sample value was ever written. A real regression — the sample path
    /// gaining a write, or the refresh guard falling (the fixture's `.mock`
    /// provider would then persist a full synthetic week) — still lands in this
    /// container and fails here deterministically.
    @Test func sampleValuesNeverReachTheOnDeviceStore() async throws {
        let s = makeState()
        defer { s.clearSampleModeForErase() }
        let container = try #require(s.donationModelContainer)
        let ctx = container.mainContext

        func counts() throws -> [Int] {
            [try ctx.fetchCount(FetchDescriptor<GlucoseSample>()),
             try ctx.fetchCount(FetchDescriptor<HeartDaily>()),
             try ctx.fetchCount(FetchDescriptor<SleepSegment>()),
             try ctx.fetchCount(FetchDescriptor<Workout>()),
             try ctx.fetchCount(FetchDescriptor<BodyComposition>()),
             try ctx.fetchCount(FetchDescriptor<InsulinDose>()),
             try ctx.fetchCount(FetchDescriptor<BPReading>()),
             try ctx.fetchCount(FetchDescriptor<AFibBurden>()),
             try ctx.fetchCount(FetchDescriptor<HealthObservation>()),
             try ctx.fetchCount(FetchDescriptor<HealthCondition>()),
             try ctx.fetchCount(FetchDescriptor<HealthMedication>())]
        }

        let before = try counts()
        await s.enterSampleMode(.settingsChoice)
        #expect(try counts() == before, "entering sample mode wrote to the on-device store")
        await s.refreshFromHealth()          // the ingest path, while the sample is on
        #expect(try counts() == before, "a refresh in sample mode wrote to the on-device store")
        s.exitSampleMode()
        #expect(try counts() == before, "leaving sample mode wrote to the on-device store")
    }

    /// The structural half of the same promise: while sample mode is on, the
    /// ingest path is not entered at all — no fetch is even attempted, so there
    /// is no read, no persist and no deriver run to leak from.
    @Test func theIngestPathIsNotEnteredWhileSampleModeIsOn() async {
        let s = makeState()
        defer { s.clearSampleModeForErase() }
        #expect(s.didAttemptHealthFetch == false)
        await s.enterSampleMode(.settingsChoice)
        await s.refreshFromHealth()
        #expect(s.didAttemptHealthFetch == false,
                "refreshFromHealth ran the real fetch while sample mode was on")
        #expect(s.healthReadOutcome == .notAttempted)
        #expect(s.usingRealData == false)
    }

    /// Sample mode consents to nothing and connects to nothing, and its passport
    /// says so rather than borrowing the real session's counts.
    @Test func sampleModeClaimsNoSourcesNoJournalAndNoConsents() async {
        let s = makeState()
        defer { s.clearSampleModeForErase() }
        s.passportStats = PassportStats(totalReadings: 9, nudgesGenerated: 2, sourcesConnected: 3,
                                        daysTracked: 5, glucoseTimeInRange: 70, avgSleepHours: 7,
                                        journalEntries: 6, consentDecisions: 4)
        s.grants = []
        s.walletEvents = []
        await s.enterSampleMode(.settingsChoice)
        #expect(s.passportStats.sourcesConnected == 0)
        #expect(s.passportStats.journalEntries == 0)
        #expect(s.passportStats.consentDecisions == 0)
        #expect(s.grants.isEmpty)
        #expect(s.walletEvents.isEmpty)
        #expect(s.workoutMerges.isEmpty)
    }
}
