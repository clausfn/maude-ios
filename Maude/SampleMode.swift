// SampleMode.swift — opt-in, unmistakably-labelled SAMPLE MODE (FR-SMP-01…05).
//
// THE DEFECT THIS FILE EXISTS TO CLOSE
// ────────────────────────────────────
// `AppState.isDemoData` used to be defined as `!usingRealData` — "we have no
// real readings yet". Every screen that draws a fabricated stand-in value asked
// that flag for permission. So a brand-new REAL citizen, whose watch simply had
// not synced yet, was indistinguishable from someone who had asked to look at a
// demo — and got invented numbers with no label on them (the class of defect in
// qms/CHANGELOG.md PR-111). Two different questions had one answer.
//
// They are now separate, and only one of them authorises a fabricated value:
//
//   `usingRealData == false`  → nothing of yours yet → honest empty / calibrating
//   `isSampleMode == true`    → YOU asked for a sample → sample values, labelled
//
// FIVE PROPERTIES THIS IMPLEMENTATION HOLDS (all tested — SampleModeTests):
//
//  1. OFF BY DEFAULT, NEVER AUTOMATIC. The flag starts false and is written by
//     exactly two deliberate acts (`SampleModePolicy.Entry`). No empty fetch,
//     failed read, missing permission or first launch can set it.
//  2. SYNTHETIC ONLY. The values come from `SampleDataset` — arithmetic from a
//     fixed seed, nobody's readings.
//  3. LABELLED WHILE ON. `SampleModePolicy.labelIsVisible` ignores every
//     preference; the banner is app chrome, not a dismissible chip.
//  4. NO CONTAMINATION. While sample mode is on, `refreshFromHealth` does not
//     fetch, does not persist and does not derive — the ingest path is not
//     entered at all, so no sample value can reach SwiftData, the journal, the
//     vault, a grant or the ledger. The overlay lives in memory only.
//  5. CLEAN EXIT. Entering snapshots the citizen's own surfaces; leaving puts
//     that snapshot back, field for field, and drops both the snapshot and the
//     synthetic bundle. Then a normal refresh brings real data up to date.
import Foundation

// MARK: - The flag on disk

/// Where the citizen's choice is remembered. A preference — never data.
enum SampleModeStore {
    static let key = "maude.sampleMode.on"

    /// Absent key ⇒ false. Sample mode is off on every fresh install.
    static func isOn(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func set(_ on: Bool, _ defaults: UserDefaults = .standard) {
        if on { defaults.set(true, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}

// MARK: - The two bundles

extension AppState {

    /// The citizen's OWN derived surfaces, held aside while the sample is on
    /// screen and put back verbatim when it leaves. Value type: restoring it
    /// cannot half-succeed.
    struct SampleModeSnapshot {
        var nudges: [Nudge]
        var todaySignals: TodaySignals?
        var glucoseDetail: GlucoseWeekDetail?
        var sleepSummary: SleepSummary?
        var trends: TrendsSummary?
        var dayReplay: DayReplay?
        var sleepDetail: SleepWeekDetail?
        var heartDetail: HeartWeekDetail?
        var fitnessDetail: FitnessDetail?
        var activityDetail: ActivityWeekDetail?
        var bodyDetail: BodyTrendDetail?
        var vitalsDetail: VitalsDetail?
        var baselines: BaselineBook?
        var hrvLearn: HRVLearnDetail?
        var passportStats: PassportStats
        var correlationWeek: CorrelationWeek
        var workoutMerges: [WorkoutMerge]

        @MainActor init(capturing s: AppState) {
            nudges = s.nudges
            todaySignals = s.todaySignals
            glucoseDetail = s.glucoseDetail
            sleepSummary = s.sleepSummary
            trends = s.trends
            dayReplay = s.dayReplay
            sleepDetail = s.sleepDetail
            heartDetail = s.heartDetail
            fitnessDetail = s.fitnessDetail
            activityDetail = s.activityDetail
            bodyDetail = s.bodyDetail
            vitalsDetail = s.vitalsDetail
            baselines = s.baselines
            hrvLearn = s.hrvLearn
            passportStats = s.passportStats
            correlationWeek = s.correlationWeek
            workoutMerges = s.workoutMerges
        }

        @MainActor func restore(into s: AppState) {
            s.nudges = nudges
            s.todaySignals = todaySignals
            s.glucoseDetail = glucoseDetail
            s.sleepSummary = sleepSummary
            s.trends = trends
            s.dayReplay = dayReplay
            s.sleepDetail = sleepDetail
            s.heartDetail = heartDetail
            s.fitnessDetail = fitnessDetail
            s.activityDetail = activityDetail
            s.bodyDetail = bodyDetail
            s.vitalsDetail = vitalsDetail
            s.baselines = baselines
            s.hrvLearn = hrvLearn
            s.passportStats = passportStats
            s.correlationWeek = correlationWeek
            s.workoutMerges = workoutMerges
        }
    }

    /// The synthetic bundle. Sendable value types only, so it can be built off
    /// the main actor exactly like the real deriver chain (FB-AJR9AqEk).
    struct SampleDerivation: Sendable {
        let engineNudges: [EngineNudge]
        let passport: DerivedPassportStats
        let grid: CorrelationGrid
        let signals: TodaySignals?
        let glucose: GlucoseWeekDetail?
        let sleep: SleepSummary?
        let trends: TrendsSummary?
        let dayReplay: DayReplay?
        let sleepDetail: SleepWeekDetail?
        let heart: HeartWeekDetail?
        let fitness: FitnessDetail?
        let activity: ActivityWeekDetail?
        let body: BodyTrendDetail?
        let vitals: VitalsDetail?
        let baselines: BaselineBook?
        let hrvLearn: HRVLearnDetail?
    }

    /// Build every surface from the synthetic record — through the SAME
    /// derivers and the SAME nudge engine the real pipeline uses. Nothing here
    /// is hand-written copy: the sentences a tester reads in sample mode are
    /// authored by the engine, so they pass `NudgeGuard` (FR-NDG-06) by
    /// construction, exactly as a real citizen's would.
    ///
    /// `nonisolated` + pure: no store, no context, no file, no network.
    nonisolated static func deriveSample(now: Date = Date()) -> SampleDerivation {
        let samples = SampleDataset.samples(now: now)
        return SampleDerivation(
            engineNudges: NudgeRun.nudges(from: samples, context: [], now: now),
            passport: PassportStatsDeriver.derive(from: samples),
            // `now` is threaded through every deriver that takes one, so the
            // synthetic record and the windows the derivers look at are anchored
            // to the SAME instant. Letting a deriver default to `Date()` while
            // the dataset was built around an injected `now` silently produced
            // empty screens (caught by SampleDatasetTests, which derives at a
            // fixed date) — and would have done the same on any device whose
            // clock disagreed with the build's assumptions.
            grid: CorrelationDeriver.derive(from: samples, now: now),
            signals: TodaySignalsDeriver.derive(from: samples),
            glucose: GlucoseDetailDeriver.derive(from: samples, now: now),
            sleep: SleepDeriver.derive(from: samples),
            trends: TrendsDeriver.derive(from: samples, now: now),
            dayReplay: DayReplayDeriver.derive(from: samples, now: now),
            sleepDetail: SleepDetailDeriver.derive(from: samples, now: now),
            heart: HeartDetailDeriver.derive(from: samples, now: now),
            fitness: FitnessDeriver.derive(from: samples, now: now),
            activity: ActivityDeriver.derive(from: samples, now: now),
            body: BodyTrendDeriver.derive(from: samples, now: now),
            vitals: VitalsDeriver.derive(from: samples, now: now),
            baselines: BaselineDeriver.derive(from: samples, now: now),
            hrvLearn: HRVLearnDeriver.derive(from: samples, now: now))
    }

    // MARK: - Enter / leave

    /// Turn sample mode ON. The ONLY way in — and it takes a
    /// `SampleModePolicy.Entry`, so a call site has to name which deliberate
    /// act it is answering. There is no overload without one.
    @MainActor
    func enterSampleMode(_ entry: SampleModePolicy.Entry, now: Date = Date()) async {
        guard SampleModePolicy.mayEnter(entry), !isSampleMode else { return }
        let derived = await Task.detached(priority: .userInitiated) {
            AppState.deriveSample(now: now)
        }.value
        sampleDerivationStorage = derived
        sampleModeStorage = true
        SampleModeStore.set(true, sampleModeDefaults)
        applySampleOverlay()
    }

    /// Turn sample mode OFF and put the citizen's own surfaces back, field for
    /// field. Synchronous and total: nothing synthetic survives this call.
    @MainActor
    func exitSampleMode() {
        guard isSampleMode else { return }
        sampleModeStorage = false
        SampleModeStore.set(false, sampleModeDefaults)
        if let snapshot = sampleSnapshotStorage {
            snapshot.restore(into: self)
        } else {
            // No snapshot (sample mode was entered in an earlier launch, so the
            // surfaces it replaced were the first-launch ones). Restore those —
            // never leave a synthetic value on screen because we lost the note.
            resetSurfacesToColdStart()
        }
        sampleSnapshotStorage = nil
        sampleDerivationStorage = nil
        sampleOverlayApplied = false
    }

    /// Leave, then bring the citizen's real data up to date. What the exit
    /// control on the banner and in Settings actually calls.
    @MainActor
    func leaveSampleMode() async {
        exitSampleMode()
        await refreshFromHealth()
    }

    /// Erase (GDPR Art. 17) drops the sample too — the flag is a preference and
    /// the surfaces are reset by the caller straight after.
    @MainActor
    func clearSampleModeForErase() {
        sampleModeStorage = false
        SampleModeStore.set(false, sampleModeDefaults)
        sampleSnapshotStorage = nil
        sampleDerivationStorage = nil
        sampleOverlayApplied = false
    }

    // MARK: - Applying the overlay

    /// Put the synthetic surfaces on screen, snapshotting the citizen's own
    /// first. Idempotent: the snapshot is taken only on the transition INTO the
    /// overlay, so calling this twice can never snapshot sample values over the
    /// real ones (which would be exactly the residue we promise not to leave).
    @MainActor
    func applySampleOverlay() {
        guard isSampleMode, let d = sampleDerivationStorage else { return }
        if !sampleOverlayApplied {
            sampleSnapshotStorage = SampleModeSnapshot(capturing: self)
            sampleOverlayApplied = true
        }
        nudges = d.engineNudges.map { Nudge(engine: $0) }
        todaySignals = d.signals
        glucoseDetail = d.glucose
        sleepSummary = d.sleep
        trends = d.trends
        dayReplay = d.dayReplay
        sleepDetail = d.sleepDetail
        heartDetail = d.heart
        fitnessDetail = d.fitness
        activityDetail = d.activity
        bodyDetail = d.body
        vitalsDetail = d.vitals
        baselines = d.baselines
        hrvLearn = d.hrvLearn
        correlationWeek = CorrelationWeek.from(d.grid)
        // The sample person's passport. Sources, journal entries and consent
        // decisions are counted as ZERO rather than borrowed from the real
        // session: sample mode connects nothing, writes nothing and consents to
        // nothing, and the passport must not imply otherwise.
        passportStats = PassportStats.compose(derived: d.passport,
                                              nudgesGenerated: nudges.count,
                                              sourcesConnected: 0,
                                              journalEntries: 0,
                                              consentDecisions: 0)
        // The sample records no session twice, so there is no merge to disclose.
        workoutMerges = []
    }

    /// Cold launch with the flag already on (the citizen left it on last time).
    /// Builds the synthetic bundle if this session has not built it yet, then
    /// applies it. Never sets the flag — it only honours a choice already made.
    @MainActor
    func resumeSampleModeIfOn(now: Date = Date()) async {
        guard isSampleMode else { return }
        if sampleDerivationStorage == nil {
            sampleDerivationStorage = await Task.detached(priority: .userInitiated) {
                AppState.deriveSample(now: now)
            }.value
        }
        applySampleOverlay()
    }

    /// The first-launch surfaces (demo seeds in DEBUG, EMPTY in Release —
    /// ColdStartSeeds.swift). Used only when there is no snapshot to restore.
    @MainActor
    func resetSurfacesToColdStart() {
        nudges = ColdStart.nudges
        todaySignals = nil
        glucoseDetail = nil
        sleepSummary = nil
        trends = nil
        dayReplay = nil
        sleepDetail = nil
        heartDetail = nil
        fitnessDetail = nil
        activityDetail = nil
        bodyDetail = nil
        vitalsDetail = nil
        baselines = nil
        hrvLearn = nil
        passportStats = ColdStart.passportStats
        correlationWeek = ColdStart.correlationWeek
        workoutMerges = []
    }
}
