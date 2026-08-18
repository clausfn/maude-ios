// AppState.swift — Single source of truth. Injected via .environment(appState).
// v02 · 2026-05-22 — added healthContext (declared baseline, HealthContext)
import Foundation
import Observation
import SwiftData
import UIKit
import UserNotifications

@Observable
final class AppState {

    // Service (swap MockSupabaseService → SupabaseService when credentials are ready)
    let supabase: any SupabaseServiceProtocol

    // L1 source selection. `.mock` = synthetic demo user; `.healthKit` = real
    // on-device data. Resolved at launch: real HealthKit when the platform has it
    // (a real device), demo otherwise (Simulator without Health, or when forced
    // by `-uiTestAutoDemo` / `LIVIQA_DATA=mock` for screenshots & tests).
    var dataProviderKind: DataProviderKind = AppState.resolveProviderKind()
    /// True only once a real HealthKit fetch has returned at least one reading.
    /// Drives the FR-ARCH-05 "Demo data" indicator accurately — so on a device
    /// with no Health data yet we still show (and label) the demo seeds.
    private(set) var usingRealData = false

    // MARK: - Sample mode (FR-SMP-01) — see SampleMode.swift for the whole story
    //
    // `isDemoData` used to be `!usingRealData` — "we have no real readings yet"
    // — and every screen that draws a fabricated stand-in value asked it for
    // permission. That conflated two different questions and is why invented
    // numbers could render, unlabelled, for a brand-new REAL citizen. The two
    // questions are now separate and only ONE of them authorises a fabricated
    // value (SampleModePolicy, and the tests that pin it):
    //
    //   hasNoRealReadings  → nothing of yours yet → honest empty / calibrating
    //   isSampleMode       → YOU asked for a sample → sample values, labelled
    //
    /// Where the sample-mode flag is remembered. `.standard` in the app; a
    /// TEST seam only — unit tests inject an isolated suite so parallel test
    /// instances can never race one another through the shared standard
    /// defaults (the BackupPostureTests/SampleModeTests flake class).
    let sampleModeDefaults: UserDefaults
    /// The citizen deliberately turned sample mode on. Written ONLY by
    /// `enterSampleMode(_:)` / `exitSampleMode()`; false on every fresh install.
    var sampleModeStorage: Bool
    /// The citizen's own surfaces, held aside while the sample is on screen.
    var sampleSnapshotStorage: SampleModeSnapshot? = nil
    /// The synthetic bundle for this session (built once, off the main actor).
    var sampleDerivationStorage: SampleDerivation? = nil
    /// True while the synthetic surfaces are the ones on screen — so the
    /// snapshot is taken on the transition IN and never over itself.
    var sampleOverlayApplied = false

    /// Sample mode is on: every value on screen is synthetic and labelled.
    var isSampleMode: Bool { sampleModeStorage }

    /// No real reading has arrived yet. This is an EMPTY-STATE condition and
    /// never, on its own, a licence to render an invented value.
    var hasNoRealReadings: Bool { !usingRealData }

    /// Legacy name, kept because a screen owned elsewhere still reads it. It now
    /// means what every one of its call sites actually wanted: "the values on
    /// screen are the sample, and must be labelled as such". It does NOT mean
    /// "no real data" any more — use `hasNoRealReadings` for that.
    var isDemoData: Bool { isSampleMode }
    /// Set once `refreshFromHealth` has run, so UI hints don't flash before the
    /// first fetch resolves.
    private(set) var didAttemptHealthFetch = false
    /// True only on a real device that tried HealthKit but has no readings yet —
    /// the cue to show the "connect Apple Health" hint. Never true in demo /
    /// screenshot mode (provider is `.mock` there).
    var showConnectHealthHint: Bool {
        didAttemptHealthFetch && dataProviderKind == .healthKit && !usingRealData
    }

    /// What the last REAL Health read actually returned.
    ///
    /// WORDING RULE (deliberate): HealthKit does not report read authorisation —
    /// `authorizationStatus(for:)` answers for WRITING only, and a denied read
    /// is specified to look exactly like an empty one. So a denied read and a
    /// brand-new watch with nothing recorded yet are indistinguishable from
    /// here, and this app never claims access was denied. `.noReadings` means
    /// precisely what it says: the request completed and every requested type
    /// came back empty.
    enum HealthReadOutcome: Sendable, Equatable {
        case notAttempted
        case readings                 // real samples arrived
        case noReadings               // completed; every requested type empty
        case failed(String)           // the request itself threw
    }
    private(set) var healthReadOutcome: HealthReadOutcome = .notAttempted

    /// The pure truth table behind `healthReadOutcome`, so the cue can be
    /// proved without a device: only a REAL Health read can produce a verdict —
    /// a demo/mock session never says anything about Apple Health at all.
    static func readOutcome(kind: DataProviderKind,
                            samplesEmpty: Bool) -> HealthReadOutcome {
        guard kind == .healthKit else { return .notAttempted }
        return samplesEmpty ? .noReadings : .readings
    }

    /// The inferred-denial cue: a real Health read completed and brought back
    /// nothing at all. Surfaces the honest "no readings came through" screen
    /// instead of leaving the citizen in a silently empty app. NOT an assertion
    /// that permission was refused — see `HealthReadOutcome`.
    var healthReadReturnedNothing: Bool {
        dataProviderKind == .healthKit && healthReadOutcome == .noReadings
    }

    static func resolveProviderKind() -> DataProviderKind {
        let pi = ProcessInfo.processInfo
        return resolveProviderKind(arguments: pi.arguments,
                                   env: pi.environment,
                                   realAvailable: HealthProviderFactory.isRealHealthDataAvailable)
    }

    /// Pure, testable resolution. Forced demo for UI-test/screenshot runs and
    /// `LIVIQA_DATA=mock`; forced real for `LIVIQA_DATA=healthKit`; otherwise real
    /// when the platform has Health, demo when it doesn't.
    ///
    /// The forcing branches are DEBUG-only: a Release binary must never be
    /// steerable onto the mock provider, even via launch arguments (posture —
    /// launch args aren't settable on TestFlight installs, but the seam stays
    /// closed regardless; lint: ReleasePostureTests.providerForcingIsDebugGated).
    static func resolveProviderKind(arguments: [String],
                                    env: [String: String],
                                    realAvailable: Bool) -> DataProviderKind {
        #if DEBUG
        if arguments.contains("-uiTestAutoDemo") || env["LIVIQA_DATA"] == "mock" { return .mock }
        if env["LIVIQA_DATA"] == "healthKit" { return .healthKit }
        #endif
        return realAvailable ? .healthKit : .mock
    }

    // On-device SwiftData store (samples never leave the device). Optional so a
    // schema/store failure can never crash launch — the feed still works.
    //
    // NEVER a bare `try?`: a nil container silently turns every ingest into a no-op
    // (guard-let → return), which reads as "data came in, then disappeared." If the
    // on-disk store can't open (e.g. a schema migration between builds), we log it
    // loudly and fall back to an in-memory container so the app keeps functioning this
    // session — a visible, understood failure instead of silent data loss.
    private let storeOpen: (container: ModelContainer?, diskFailed: Bool)
    private var modelContainer: ModelContainer? { storeOpen.container }

    /// True when the on-disk store failed to open and this session runs on the
    /// in-memory fallback (or no store at all). Surfaced as a Home banner —
    /// degraded persistence must never be silent: on a TestFlight device a broken
    /// schema migration would otherwise read as "all my data vanished".
    var storeDegraded: Bool { storeOpen.diskFailed }

    private static func openStore() -> (container: ModelContainer?, diskFailed: Bool) {
        do {
            return (try LiviqaStore.makeContainer(), false)
        } catch {
            print("‼️ LiviqaStore: on-disk container failed to open (\(error)). Falling back to in-memory for this session.")
            return (try? LiviqaStore.makeContainer(inMemory: true), true)
        }
    }

    /// The canonical, source-agnostic health record repository (labs/diagnoses/meds
    /// from ANY source). On-device only. `nil` only if the store failed to open.
    var healthStore: HealthStore? {
        guard let modelContainer else { return nil }
        return HealthStore(context: modelContainer.mainContext)
    }

    // MARK: - Donor programme (DON-2026-01) — donor builds only
    //
    // Storage for `AppState+Donation.swift`. In every shipped build
    // `DonationProgramme.isDonorBuild` is a compile-time `false`, so nothing
    // ever loads into these and `hasActiveDonationGrant` is always false — the
    // consent copy every citizen reads is unchanged.

    /// Sealed device record of the donation grant, its consent events and the
    /// log of every export. Empty except in a donor build with a recorded grant.
    var donationRecordStorage: DonationRecord = .empty

    /// True when a donor record exists on disk that this device's key cannot
    /// open. Surfaced honestly rather than reported as "no donation".
    var donationConsentUnreadable = false

    /// The on-device container, for the donation extension's read-only pass over
    /// the four donatable streams. Same store, no second copy.
    var donationModelContainer: ModelContainer? { modelContainer }

    // Display projections of the canonical record, refreshed from the store after any
    // ingest and on view appear. Newest-per-scopeKey labs (multi-source aware); all
    // conditions/meds (each tagged with its source).
    private(set) var healthObservations: [HealthObservation] = []
    private(set) var healthConditions:   [HealthCondition]   = []
    private(set) var healthMedications:  [HealthMedication]  = []
    /// Set true after an explicit, consented "contribute to research" upload succeeds.
    var researchContributed = false

    // Auth
    var session: UserSession?  = nil
    var profile: UserProfile?  = nil
    var isSigningIn: Bool      = false
    /// True while the launch-time session restore is in flight. Starts true so
    /// the root view shows calm launch progress instead of flashing AuthView
    /// before the Keychain check resolves (cleared by `restoreSession`).
    private(set) var isRestoringSession = true

    // Today. Seeds are demo data in DEBUG, EMPTY in Release (honest cold start,
    // T1 TestProd wave — see ColdStartSeeds.swift).
    var rings:  [MetricRing]   = ColdStart.rings
    var nudges: [Nudge]        = ColdStart.nudges
    /// Live Home "signals vs your normal" chips, derived from real HealthKit
    /// samples. nil ⇒ no real data yet → Home shows the demo seeds.
    var todaySignals: TodaySignals? = nil
    /// Glucose metric-detail derivation (week TIR bands, GMI, per-day spans,
    /// today's timed curve points). nil ⇒ no glucose in the last week → the
    /// detail screen shows its clearly-demo seeds (demo mode) or an honest
    /// empty state (real-data mode).
    var glucoseDetail: GlucoseWeekDetail? = nil
    /// Dual-recording merges from the last fetch (FR-PROV-02) — sessions that
    /// arrived from two trackers and were counted once. Shown in Data sources.
    var workoutMerges: [WorkoutMerge] = []

    /// Last-night sleep-stage breakdown + nightly trend, derived from samples.
    /// Drives the real sleep visualisation (falls back to demo when nil).
    var sleepSummary: SleepSummary? = nil

    // A7.2 Area ④ — metric-detail derivations (same honesty rule as
    // `glucoseDetail`: nil ⇒ the screen shows clearly-demo seeds in demo mode,
    // or an honest empty state on a real-data session).
    var sleepDetail: SleepWeekDetail? = nil
    var heartDetail: HeartWeekDetail? = nil
    var fitnessDetail: FitnessDetail? = nil
    var activityDetail: ActivityWeekDetail? = nil
    var bodyDetail: BodyTrendDetail? = nil
    var vitalsDetail: VitalsDetail? = nil
    /// Per-domain learned "your usual" baselines (UC-08) for the baseline sheet.
    var baselines: BaselineBook? = nil
    /// A7.2 Area ⑨ — up-to-60-day HRV aggregation for the two-tier knowledge
    /// screen + the assistant's explain-a-drop template (same honesty rule:
    /// nil ⇒ still-learning framing, never fabricated figures).
    var hrvLearn: HRVLearnDetail? = nil

    /// Trends surface derivation (FR-TOD-06, Area ②): week/month/quarter TIR
    /// trend vs the user's own usual band, gate-passed correlations, aggregate
    /// tiles, and the Today-feed period comparison. nil ⇒ honest empty state.
    var trends: TrendsSummary? = nil
    /// "Replay your day" derivation (Area ②): today's timestamped glucose curve
    /// + the figures the moment card narrates. nil ⇒ honest empty state.
    var dayReplay: DayReplay? = nil

    // Wallet
    var grants:       [WalletGrant]  = []
    var walletEvents: [WalletEvent]  = []
    var isLoadingWallet: Bool        = false

    // Journal
    var journalEntries:  [JournalEntry] = []
    var journalSyncEnabled: Bool        = false

    /// FR-JRNL-SCOPE-01 — the scope key the on-device journal is namespaced by:
    /// the SIGNED-IN account. nil ⇒ no account ⇒ no journal may be read or
    /// written (a signed-out device exposes nobody's entries, and nothing is
    /// deleted to achieve that — see `JournalStore`).
    var journalAccountID: String? { session?.userId.uuidString }

    // Context flags (FR-CTX-04) — the user's own "life explains this" markers.
    // Device-local (ContextFlagStore), restored at launch, wiped by deleteAllData.
    // Their ONLY effect on the engine is suppression (see NudgeEngine).
    var contextFlags: [ContextFlag] = ContextFlagStore.load() ?? []

    // Data sources & backup
    var backupPreference: BackupPreference    = .onDevice
    var connectedSources: [DataSourceConnection] = ColdStart.connectedSources

    // Health Passport
    var passportStats: PassportStats = ColdStart.passportStats
    var correlationWeek: CorrelationWeek = ColdStart.correlationWeek

    // DfG tokens
    var tokenBalance: Int                    = ColdStart.tokenBalance
    var tokenTransactions: [TokenTransaction] = ColdStart.tokenTransactions

    // Declared profile — things only the user knows
    var healthContext: HealthContext = ColdStart.healthContext

    // Error surface
    var lastError: String? = nil

    // Navigation UI state (shared so the custom app bar / tab bar stay consistent
    // across the redesigned screens, which hide the system nav bar).
    /// Set by the avatar button in `LiviqaAppBar`; MainTabView presents ProfileSheet.
    var showProfileSheet = false
    /// Set by the ✨ Ask button in the app bar; MainTabView presents the assistant.
    var showAssistant = false
    /// Set from Home + the Sundhed import success; MainTabView presents the Health
    /// Passport (where imported labs / diagnoses / medicine live) as a sheet, so the
    /// citizen can always reach — and screenshot — their record.
    var showHealthRecord = false
    /// >0 while a full-screen detail (chat, consult, a pushed screen) is on top —
    /// MainTabView hides the floating tab bar so it can't overlap the content.
    var detailDepth = 0

    // Research participation (UC-RSCH) — a pending study invitation + its consent flow.
    var researchOpportunity: ResearchStudy? = nil   // surfaced on Home + Care when matched
    var showStudyConsent = false                    // MainTabView presents StudyConsentView
    var researchNotificationUnread = false          // bell badge: a research invite arrived
    var joinedStudy: ResearchStudy? = nil           // set on Approve & join

    /// `sampleModeDefaults` and `store` are TEST seams, not behaviour: the app
    /// always constructs with `.standard` and the on-disk store. Unit tests
    /// inject an isolated defaults suite and an in-memory `ModelContainer` so a
    /// test's assertions are judged only against what ITS OWN AppState did —
    /// never against another parallel test's writes to the shared on-disk file
    /// or the shared standard defaults.
    init(supabase: any SupabaseServiceProtocol = Config.makeService(),
         sampleModeDefaults: UserDefaults = .standard,
         store: ModelContainer? = nil) {
        self.supabase = supabase
        self.sampleModeDefaults = sampleModeDefaults
        self.sampleModeStorage = SampleModeStore.isOn(sampleModeDefaults)
        self.storeOpen = store.map { ($0, false) } ?? AppState.openStore()
        NotificationCenter.default.addObserver(forName: .liviqaPushToken, object: nil, queue: .main) { note in
            guard let hex = note.object as? String else { return }
            // Capture `self` weakly INSIDE the @MainActor Task (not in the non-isolated
            // observer closure) so nothing crosses the isolation boundary — silences the
            // Swift-6 "captured var 'self' in concurrently-executing code" warning.
            Task { @MainActor [weak self] in self?.handlePushToken(hex) }
        }
        // A research-invitation push (demo bridge: DfG Professional "Contact Cohort"
        // → simctl push with userInfo type=research) → open the consent flow.
        NotificationCenter.default.addObserver(forName: .liviqaOpenResearch, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.handleResearchInvite() }
        }
        // A research invite DELIVERED in the foreground → badge the bell + Care card
        // (without forcing the consent sheet open; the tap path does that).
        NotificationCenter.default.addObserver(forName: .liviqaResearchReceived, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.handleResearchReceived() }
        }
        // FR-NOT-02: an earned-attention alert was tapped → open that nudge's
        // evidence view (the shown work), not just the app.
        NotificationCenter.default.addObserver(forName: .liviqaOpenAttention, object: nil, queue: .main) { note in
            let tag = note.object as? String
            Task { @MainActor [weak self] in self?.handleAttentionTap(tag: tag) }
        }
        // Declared health profile (About you) — restore the device-local store so
        // ProfileSheet edits survive relaunch (A7.2 Area ⑧; saved on Save there).
        if let stored = HealthContextStore.load() {
            healthContext = stored
        }
        // Donor programme (DON-2026-01): restore the sealed donor record so the
        // consent copy is correct from the first frame. Compile-time no-op in
        // every shipped build — `isDonorBuild` is false there.
        loadDonationConsent()
    }

    /// APNs device token for this install (sent to the backend once signed in).
    var pushDeviceToken: String?

    /// Ask for notification permission + register for remote notifications. Safe to
    /// call repeatedly (iOS prompts once). No effect until the Push capability +
    /// APNs are in place — registration just fails gracefully.
    @MainActor
    func requestPushAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// A research invitation was DELIVERED — surface it on Home + Care and badge the
    /// bell. Does NOT open the consent sheet (tapping the notification does that).
    /// DEBUG-ONLY payload (T1): the surfaced study is the fabricated demo study
    /// (DfG Professional demo bridge). A Release build must never present it as
    /// a real invitation — no-op until real study payloads ride the push.
    @MainActor
    func handleResearchReceived() {
        #if DEBUG
        researchOpportunity = MockData.demoStudy
        researchNotificationUnread = true
        #endif
    }

    /// A research invitation was TAPPED (demo bridge from DfG Professional) — surface
    /// it and open the consent flow (s09 → s10).
    @MainActor
    func handleResearchInvite() {
        handleResearchReceived()
        // Open the consent sheet only when a real invitation was surfaced. In Release
        // handleResearchReceived() is a no-op (demo payload is DEBUG-only), so this
        // stays closed and the fabricated demo study is never presented.
        if researchOpportunity != nil { showStudyConsent = true }
    }

    // MARK: - FR-NOT-02 earned-attention deep link

    /// Headline of the nudge an earned-attention alert was about, kept until a
    /// matching card exists in the feed. Set on tap; a cold launch from the
    /// notification arrives BEFORE `refreshFromHealth` has rebuilt the feed, so
    /// the link is resolved again once it has.
    private var pendingAttentionTag: String?

    /// The card an earned-attention tap should open (its evidence view — the
    /// shown work). MainTabView observes this and clears it.
    var attentionDeepLink: Nudge?

    /// An earned-attention alert was tapped. Nil tag ⇒ just open the edition.
    @MainActor
    func handleAttentionTap(tag: String?) {
        pendingAttentionTag = tag
        resolveAttentionDeepLink()
    }

    /// Match the pending headline against the live feed. No match ⇒ nothing is
    /// invented: the tap simply lands on the edition, and the link stays pending
    /// until the feed is rebuilt.
    @MainActor
    func resolveAttentionDeepLink() {
        guard let tag = pendingAttentionTag else { return }
        guard let match = nudges.first(where: { $0.tag == tag && !$0.dismissed }) else { return }
        pendingAttentionTag = nil
        attentionDeepLink = match
    }

    /// Store the APNs token and push it to the backend (when signed in).
    @MainActor
    func handlePushToken(_ hex: String) {
        pushDeviceToken = hex
        guard session != nil, let care = careConnect else { return }
        Task { try? await care.registerPushToken(hex) }
    }

    /// Sovereign-only capabilities (recipient directory + derived-share push),
    /// available when running against the EU-sovereign backend. `nil` on mock/
    /// sandbox so callers degrade gracefully.
    var sovereign: (any SovereignSharing)? { supabase as? SovereignSharing }

    /// Citizen care-team surface (secure messaging + video consult), available on
    /// the sovereign backend only. `nil` on mock/sandbox.
    var careConnect: (any CareConnect)? { supabase as? CareConnect }

    // Care-team UI state (loaded on demand from the sovereign backend).
    var careThreads: [CareThread] = []
    var activeConsults: [ConsultSummary] = []
    var careNotifications: [CitizenNotification] = []
    /// Upcoming scheduled consultations (citizen video surface).
    var scheduledConsults: [ScheduledConsult] = []

    // Incoming-call ring — a clinician started an instant consult; we surface it as
    // an in-app incoming call with a consent flow. Poll-based (no push infra yet).
    var incomingConsult: ConsultSummary? = nil
    private var knownConsultIDs: Set<String> = []
    private var incomingPrimed = false

    /// Poll active consults; ring on a NEW one (not the consults already present at
    /// app start, and not while a call is already on screen).
    @MainActor
    func pollIncomingCall() async {
        guard let care = careConnect else { return }
        guard let consults = try? await care.fetchActiveConsults() else { return }
        activeConsults = consults
        let ids = Set(consults.map(\.id))
        if !incomingPrimed {                 // first poll: adopt the baseline, don't ring
            knownConsultIDs = ids
            incomingPrimed = true
            return
        }
        if incomingConsult == nil, let fresh = consults.first(where: { !knownConsultIDs.contains($0.id) }) {
            incomingConsult = fresh           // ring
        }
        knownConsultIDs = ids
    }

    @MainActor
    func dismissIncoming() {
        if let c = incomingConsult { knownConsultIDs.insert(c.id) }
        incomingConsult = nil
    }

    // MARK: - Care-team actions (FR-WAL adjacent; consult + messaging)

    @MainActor
    func refreshCareInbox() async {
        guard let care = careConnect else { return }
        async let t = try? await care.fetchThreads()
        async let c = try? await care.fetchActiveConsults()
        async let n = try? await care.fetchNotifications()
        async let sc = try? await care.fetchScheduledConsults()
        careThreads = await t ?? careThreads
        activeConsults = await c ?? activeConsults
        careNotifications = await n ?? careNotifications
        scheduledConsults = await sc ?? scheduledConsults
    }

    // MARK: - Auth actions

    /// Restore a persisted session at launch: the service revalidates the
    /// Keychain bearer (`currentSession`) so a tester who signed in yesterday
    /// lands straight in the app, not on AuthView. On failure (no token,
    /// expired, offline validation) this clears the restoring flag and the
    /// root view falls through to AuthView exactly as before. Signed-out
    /// sessions can't resurrect: `signOut` clears the Keychain token, so the
    /// next launch's restore finds nothing.
    @MainActor
    func restoreSession() async {
        defer { isRestoringSession = false }
        guard session == nil else { return }
        guard let restored = await supabase.currentSession() else { return }
        session = restored
        await postSignIn()   // same wiring as the explicit sign-in paths
    }

    @MainActor
    func signInWithEmail(email: String, password: String) async {
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }
        do {
            session = try await supabase.signInWithEmail(email: email, password: password)
            await postSignIn()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Create a new account (email + password) and enter the app signed in.
    /// Typed failures (email taken, weak password) surface via `lastError` in
    /// the same plain-language voice as sign-in.
    @MainActor
    func signUpWithEmail(email: String, password: String) async {
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }
        do {
            session = try await supabase.signUpWithEmail(email: email, password: password)
            await postSignIn()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func signInWithApple(idToken: String, nonce: String) async {
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }
        do {
            session = try await supabase.signInWithApple(idToken: idToken, nonce: nonce)
            await postSignIn()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func signInDemo() {
        session = UserSession(
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: nil
        )
        profile = UserProfile(id: session!.userId, displayName: "LV001", avatarURL: nil, createdAt: Date(), alias: "LV001")
        // A name declared in onboarding beats the pseudonymous alias for
        // greetings (the alias stays LV001 for recipients/consult). Same single
        // resolver as the real sign-in paths — no second rule.
        applyResolvedDisplayName()
        // Mock wallet/care seeds are DEBUG-only (T1). All Release entry points to
        // signInDemo are already gated (AuthView demo button, wallet/eID flags),
        // this keeps the fabricated grants out even if a new caller slips in.
        #if DEBUG
        grants = MockData.walletGrants
        walletEvents = MockData.walletEvents
        careThreads = MockData.demoCareThreads
        applyLV001DatasetIfNeeded()   // show Claus's real goldmine data immediately
        #endif
    }

    /// True when the session was established via the DfG Wallet (eIDAS 2.0 identity
    /// presentation, verified by Partisia and anchored on the CE ledger).
    var walletVerified = false
    /// CE-ledger reference returned by the (simulated) Partisia verification.
    var walletVerificationRef: String? = nil

    /// Sign in via the DfG Wallet. Same demo session, but flagged wallet-verified so
    /// the app can surface the "Verified with Partisia" provenance.
    func signInWithDfGWallet(verificationRef: String) {
        signInDemo()
        walletVerified = true
        walletVerificationRef = verificationRef
    }

    /// The identity provider used to sign in (e.g. "MitID", "e-Boks ID"), for provenance.
    var loginProvider: String? = nil
    /// Sign in via a national eID / login provider (MitID, e-Boks ID) — simulated.
    func signInWithProvider(_ name: String) {
        signInDemo()
        loginProvider = name
    }

    @MainActor
    func signOut() async {
        try? await supabase.signOut()
        session = nil
        profile = nil
        grants = []
        walletEvents = []
        // The journal is dropped from memory here; on disk it stays sealed in
        // the departing account's own scope (FR-JRNL-SCOPE-01). The next account
        // cannot address that path, so nothing of this citizen's writing is
        // readable to them — and nothing of it is deleted either. `JournalView`
        // reloads on the account change and lands empty.
        journalEntries = []
        lastError = nil
    }

    /// Permanently erase everything Liviqa holds on this device (T-DEL-01,
    /// Settings → "Delete all my data" / GDPR Art. 17): every SwiftData sample
    /// entity, the journal file, the encrypted HealthKit sync anchors, the
    /// Keychain session token, and Liviqa's UserDefaults leftovers — then sign
    /// out and reset the in-memory surfaces to first-launch demo seeds. Each
    /// step is best-effort so one failing store can never block the others.
    ///
    /// `keepDocuments` (A7.2 Area ⑧, ScrDeleteData "Keep documents, erase the
    /// rest"): spares ONLY the encrypted document vault (step 2d) — the saved
    /// letters and results stay sealed on this phone; everything else erases
    /// exactly as the full path does.
    @MainActor
    func deleteAllData(keepDocuments: Bool = false) async {
        // 1. On-device SwiftData store — every sample/source entity (OD-09).
        if let container = modelContainer {
            let context = container.mainContext
            for model in LiviqaStore.models {
                try? context.delete(model: model)
            }
            try? context.save()
        }
        // 2. Journal — THIS account's scoped store, plus the pre-10.101
        //    device-scoped file if it is still on disk (unattributed data this
        //    erase is explicitly asked to remove). Other accounts' scopes are
        //    left alone: their entries are another person's writing, not "my
        //    data". Runs BEFORE signOut so the account id is still known.
        if let account = journalAccountID {
            JournalStore.eraseAccount(account)
        }
        if let legacyJournal = JournalStore.legacyURL() {
            try? FileManager.default.removeItem(at: legacyJournal)
        }
        // 2b. PMS report outbox (FR-PMS-01) — queued safety reports are personal
        //     data too; the erase must not leave them behind.
        if let pmsURL = PMSOutboxStore.defaultURL() {
            try? FileManager.default.removeItem(at: pmsURL)
        }
        // 2c. Declared health profile store + voice-note audio (A7.2 Area ⑧,
        //     FR-JRN-04) — both device-local, both personal data.
        HealthContextStore.delete()
        VoiceNoteAudioStore.deleteAll()
        // 2c-ii. Context flags (FR-CTX-04) — the user's own notes about their own
        //        life (travelling / unwell / off-routine) are personal data too.
        ContextFlagStore.delete()
        // 2c-ii-b. Calendar-density numbers (FR-CTX-CAL-01, RK-CAL-05) — every
        //          account's calendar-load scope on this device. A full erase
        //          must not leave the calendar numbers on disk; `disconnect`
        //          only covers the single-account revoke path.
        CalendarLoadStore.eraseAll()
        // 2c-iii. Donor-programme record (FR-DON-04) — the sealed grant, its
        //         consent events, the export log, and any sealed file still
        //         staged for the share sheet. Device-side only: erasing the
        //         donated corpus itself is the custodians' operation, and the
        //         donor screen says so rather than implying this button reaches it.
        DonationConsentStore.deleteAll()
        DonationExport.purgeStaged()
        donationRecordStorage = .empty
        donationConsentUnreadable = false
        // 2d. Encrypted document store ("Health data space", FR-ING-15) — the
        //     blobs and their metadata index are removed from disk. The
        //     "Keep documents, erase the rest" path (ScrDeleteData, Area ⑧)
        //     branches around exactly this line — and nothing else.
        if !keepDocuments {
            (try? HealthVaultStore(keyVault: .shared, userScope: LocalUserScope.current()))?.clear()
        }
        // 3. Encrypted HealthKit sync anchors for this local scope (FR-ING-03/04).
        (try? EncryptedAnchorStore(keyVault: .shared, userScope: LocalUserScope.current()))?.clear()
        // 4. Keychain session token (NFR-SEC-01) + server session + auth state.
        SessionTokenStore().clear()
        await signOut()
        // 5. Liviqa UserDefaults leftovers.
        citizenCredentialValidUntil = nil
        UserDefaults.standard.removeObject(forKey: Self.initialBackfillKey)
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)   // declared name (UC-01)
        // 6. Reset every health-derived in-memory surface to first-launch seeds
        //    (demo in DEBUG, EMPTY in Release — ColdStartSeeds.swift) so no trace
        //    of the erased data survives in the running session.
        usingRealData   = false
        healthReadOutcome = .notAttempted
        // Sample mode is a preference, and the erase takes it with everything
        // else — the citizen must never come back from "delete all my data" to
        // a screen still full of somebody's synthetic week.
        clearSampleModeForErase()
        rings           = ColdStart.rings
        nudges          = ColdStart.nudges
        todaySignals    = nil
        glucoseDetail   = nil
        sleepSummary    = nil
        trends          = nil
        dayReplay       = nil
        sleepDetail     = nil
        heartDetail     = nil
        fitnessDetail   = nil
        activityDetail  = nil
        bodyDetail      = nil
        vitalsDetail    = nil
        baselines       = nil
        hrvLearn        = nil
        workoutMerges   = []
        passportStats   = ColdStart.passportStats
        correlationWeek = ColdStart.correlationWeek
        healthContext   = ColdStart.healthContext
        tokenBalance    = ColdStart.tokenBalance
        tokenTransactions = ColdStart.tokenTransactions
        connectedSources  = ColdStart.connectedSources
        // Canonical health-record projections (the @Model rows were wiped in step 1).
        healthObservations = []
        healthConditions   = []
        healthMedications  = []
        contextFlags       = []
        researchContributed = false
    }

    // MARK: - Context flags (FR-CTX-04) — declared by the user, suppression-only

    /// The flag covering today, if the user has marked it. Drives the Today
    /// register and the neutral chart treatment; it never changes a number.
    var activeContextFlag: ContextFlag? {
        contextFlags
            .filter { $0.covers(Date()) }
            .max { $0.startedOn < $1.startedOn }
    }

    /// Flags whose stretch is still open (no end day recorded).
    var openContextFlags: [ContextFlag] {
        contextFlags.filter(\.isOpen).sorted { $0.startedOn > $1.startedOn }
    }

    /// The engine-facing projection — kind + dates only. The user's note has no
    /// representation here, by construction (see ContextFlag / ContextWindow).
    var contextWindows: [ContextWindow] { contextFlags.map(\.window) }

    /// Start marking from today. Any stretch that is still open is closed
    /// yesterday first, so two stretches can never claim the same day.
    @MainActor
    func markContext(_ kind: ContextFlagKind, note: String? = nil, now: Date = Date()) {
        let cal = ContextWindow.calendar
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        for i in contextFlags.indices where contextFlags[i].isOpen {
            contextFlags[i].endedOn = max(contextFlags[i].startedOn, yesterday)
        }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        contextFlags.append(ContextFlag(kind: kind, startedOn: today,
                                        note: (trimmed?.isEmpty == false) ? trimmed : nil))
        persistContextFlags()
    }

    /// End a stretch today (today stays marked — the user lived it).
    @MainActor
    func endContextFlag(_ id: UUID, now: Date = Date()) {
        guard let i = contextFlags.firstIndex(where: { $0.id == id }) else { return }
        let today = ContextWindow.calendar.startOfDay(for: now)
        contextFlags[i].endedOn = max(contextFlags[i].startedOn, today)
        persistContextFlags()
    }

    /// Remove a stretch entirely — the user's record of their own life, theirs
    /// to delete. Nothing derived is retained from it.
    @MainActor
    func removeContextFlag(_ id: UUID) {
        contextFlags.removeAll { $0.id == id }
        persistContextFlags()
    }

    private func persistContextFlags() {
        ContextFlagStore.save(contextFlags)
    }

    // MARK: - GDPR rights (Art. 20 export · Art. 17 erase) — T1 TestProd wave

    /// GDPR self-service on the sovereign backend. nil on mock/sandbox so the
    /// Settings surfaces degrade to device-local behaviour.
    var dataRights: (any DataRights)? { supabase as? DataRights }

    /// Server-erase failure surfaced to the Settings delete flow (retryable).
    var eraseServerError: String? = nil

    /// Full erasure, SERVER FIRST: the backend account is deleted before the
    /// local wipe, so a network failure can never strand server-side data
    /// behind a "deleted" confirmation the user already saw. Returns false
    /// (with `eraseServerError` set) when the server step fails — nothing
    /// local is touched then, and the flow offers retry.
    ///
    /// `keepDocuments` (Area ⑧, "Keep documents, erase the rest"): the SERVER
    /// erase is identical — the server never holds documents (no upload path,
    /// FR-ING-15) — only the local wipe spares the encrypted vault.
    @MainActor
    func eraseEverythingServerFirst(keepDocuments: Bool = false) async -> Bool {
        eraseServerError = nil
        if session != nil, let rights = dataRights {
            do { try await rights.eraseMyData() }
            catch {
                eraseServerError = error.localizedDescription
                return false
            }
        }
        await deleteAllData(keepDocuments: keepDocuments)
        return true
    }

    /// GDPR Art. 20 export → a shareable JSON file URL (temporary directory).
    /// Sovereign backend: the server's own `/me/export` blob. Mock/demo: an
    /// honest device-local export (grants, ledger, journal). nil with
    /// `lastError` set on failure.
    @MainActor
    func exportMyData() async -> URL? {
        do {
            let data: Data
            if session != nil, let rights = dataRights {
                data = try await rights.exportMyData()
            } else {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                data = try encoder.encode(LocalExport(
                    exportedAt: Date(),
                    note: "Data held on this device. Raw HealthKit samples never leave your device and are read directly from Apple Health.",
                    grants: grants,
                    consentLedger: walletEvents,
                    // The signed-in account's own journal only (FR-JRNL-SCOPE-01);
                    // signed out there is nothing of "mine" to export.
                    journal: journalAccountID.flatMap { JournalStore.load(forAccount: $0) } ?? []))
            }
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd-HHmm"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Liviqa-export-\(df.string(from: Date())).json")
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private struct LocalExport: Encodable {
        let exportedAt: Date
        let note: String
        let grants: [WalletGrant]
        let consentLedger: [WalletEvent]
        let journal: [JournalEntry]
    }

    // MARK: - Data loading

    @MainActor
    func postSignIn() async {
        await loadProfile()
        await loadWallet()
        reloadHealthRecord()   // surface the persisted canonical record on launch
    }

    // MARK: - Canonical health record (source-agnostic; on-device only)

    /// Map a source's derived summary into canonical rows and UPSERT them into the
    /// on-device store, then refresh the display projections. NOTHING is uploaded —
    /// this only writes to the local SwiftData store. Any source that can produce a
    /// `SundhedDerivedSummary` (Sundhed live/PDF today; OCR/HealthKit later) reuses
    /// this single entry point.
    @MainActor
    func ingestHealthRecord(_ summary: SundhedDerivedSummary, source: HealthDataSource,
                            conditionOnsets: [String: Date] = [:]) {
        guard let store = healthStore else { return }
        let rows = HealthStore.canonicalize(summary, source: source)
        // Attach diagnosis start dates (year precision) when the source read them —
        // display metadata only; the coded research body is unaffected.
        if !conditionOnsets.isEmpty {
            for cond in rows.cond {
                if let d = conditionOnsets[cond.icd10] { cond.onsetDate = d }
            }
        }
        do {
            try store.ingest(observations: rows.obs, conditions: rows.cond,
                             medications: rows.med, source: source)
        } catch {
            // The import did NOT persist — say so instead of letting the record
            // render this session and vanish on relaunch (silent-data-loss posture).
            lastError = String(localized: "Your imported record couldn't be saved to this device. Nothing was lost from the source — please try the import again.")
        }
        reloadHealthRecord()
    }

    /// Reload the display projections from the persisted store (survives relaunch).
    @MainActor
    func reloadHealthRecord() {
        guard let store = healthStore else { return }
        healthObservations = store.latestObservations()
        healthConditions   = store.conditions()
        healthMedications  = store.medications()
    }

    /// EXPLICIT, consented research contribution — the ONLY path that sends the
    /// canonical record off-device. Builds the coded, MPC-ready body from the store
    /// and hands it to the EXISTING ingest client. Never auto-called: only a user tap
    /// reaches here. Surfaces backend copy on failure.
    @MainActor
    func contributeHealthResearch() async {
        guard let store = healthStore, !store.isEmpty else {
            lastError = "There's nothing in your health record to contribute yet."
            return
        }
        let citizen = profile?.alias ?? session?.userId.uuidString ?? ""
        let body = store.researchPayload(citizenId: citizen)
        let client = (supabase as? SundhedIngesting) ?? LiviqaSundhedIngestClient()
        do {
            try await client.ingestSundhed(body)
            researchContributed = true
            lastError = nil
        } catch {
            lastError = (error as? SundhedIngestError)?.errorDescription
                ?? (error as? SupabaseError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    @MainActor
    func loadProfile() async {
        do { profile = try await supabase.fetchProfile() } catch { /* non-fatal */ }
        applyResolvedDisplayName()
    }

    /// UC-01 / FR-ACC-NAME-01 — settle what the app may call this person, once,
    /// for every surface that reads `profile?.displayName` (greeting, Settings,
    /// avatar). The declared name wins; a backend value that is merely the
    /// local-part of the account's own email is a placeholder and is dropped, so
    /// an address (or a fragment of one) can never render as a name. Nothing
    /// known ⇒ nil ⇒ the surfaces greet without a name.
    @MainActor
    func applyResolvedDisplayName(defaults: UserDefaults = .standard) {
        // Read, resolve, then write back the whole struct: `profile?.x =
        // f(profile?.x)` opens a write access to `profile` while reading it,
        // which traps on exclusivity (caught by DisplayNameResolutionTests).
        guard var resolvedProfile = profile else { return }
        resolvedProfile.displayName = DisplayNameResolution.resolve(
            declared: defaults.string(forKey: Self.displayNameKey),
            backend:  resolvedProfile.displayName,
            accountEmail: session?.email)
        profile = resolvedProfile
    }

    // MARK: - Declared display name (UC-01 name capture — device-local)

    /// UserDefaults key for the locally-declared first name. The name never
    /// leaves the device; it only feeds the greeting surfaces
    /// (`profile?.displayName` consumers: Today greeting, Settings, avatar).
    static let displayNameKey = "liviqa.profile.displayName"

    /// Persist the name typed in onboarding and reflect it on the in-memory
    /// profile immediately (creating a local profile when none is loaded yet).
    @MainActor
    func setDisplayName(_ name: String, defaults: UserDefaults = .standard) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // An address is not a name, wherever it came from (FR-ACC-NAME-01).
        guard !trimmed.isEmpty,
              DisplayNameResolution.resolve(declared: trimmed, backend: nil,
                                            accountEmail: session?.email) != nil else { return }
        defaults.set(trimmed, forKey: Self.displayNameKey)
        if profile != nil {
            profile?.displayName = trimmed
        } else if let session {
            profile = UserProfile(id: session.userId, displayName: trimmed,
                                  avatarURL: nil, createdAt: nil, alias: nil)
        }
    }

    // MARK: - On-device health pipeline (L1 → L2 → L3)

    /// Ingest the recent window from the active provider, persist on-device, and
    /// regenerate the capped, FR-NDG-06-clean nudge feed. Falls back to the
    /// existing nudges if nothing fires, so the feed is never empty.
    @MainActor private var isRefreshing = false

    /// One-time flag: the initial 90-day HealthKit backfill has completed (a
    /// real fetch returned readings). Cleared by deleteAllData.
    static let initialBackfillKey = "liviqa.backfill.initialDone"
    private static var initialBackfillDone: Bool {
        get { UserDefaults.standard.bool(forKey: initialBackfillKey) }
        set { UserDefaults.standard.set(newValue, forKey: initialBackfillKey) }
    }

    /// Reflect a successful real HealthKit fetch on the Data sources surface —
    /// the Release cold-start seed lists Apple Health as not-yet-connected.
    @MainActor
    private func markAppleHealthConnected() {
        guard let i = connectedSources.firstIndex(where: { $0.name == "Apple Health" }) else { return }
        connectedSources[i].isConnected = true
        connectedSources[i].lastSync = Date()
    }

    @MainActor
    func refreshFromHealth() async {
        // FR-SMP-04 — sample mode is a DISPLAY mode, and while it is on the app
        // does not read, derive from, or write the citizen's real data at all:
        // no fetch, no persist, no deriver chain. The ingest path is simply not
        // entered, which is what makes "a sample value can never reach a real
        // store" a structural fact rather than a promise. Leaving sample mode
        // runs this function properly (`leaveSampleMode`).
        //
        // Returning here also means `syncWatchGlance()` is NOT called, which is
        // deliberate: the watch face is a surface this app cannot put a
        // "sample data" label on. It keeps showing the citizen's own last real
        // glance rather than a synthetic number with nothing marking it.
        if isSampleMode {
            await resumeSampleModeIfOn()
            return
        }
        guard !isRefreshing else { return }   // don't overlap (root + Home both trigger on launch)
        isRefreshing = true
        // Declared first ⇒ runs LAST (after the applyLV001 defer settles todaySignals),
        // so the wrist mirrors the same Home values across real / LV001 / demo paths.
        defer { syncWatchGlance() }
        defer { isRefreshing = false; didAttemptHealthFetch = true }
        // Always re-apply the LV001 goldmine after any fetch outcome (success, empty,
        // or a HealthKit auth throw on the simulator) — runs last, after usingRealData
        // is final, so a real device with the user's own data still wins.
        defer { applyLV001DatasetIfNeeded() }
        let provider = HealthProviderFactory.make(dataProviderKind)
        let end = Date()
        // T1 cold-start honesty: the FIRST successful real fetch backfills 90
        // days of existing Health history so baselines/patterns fill from data
        // the user already has; steady state stays at 30 days.
        let windowDays = Self.initialBackfillDone ? 30 : 90
        let start = Calendar.current.date(byAdding: .day, value: -windowDays, to: end) ?? end
        do {
            try await provider.requestReadAuthorization()
            // §2.3: arbitrate sources (highest tier wins, lower fills gaps) before
            // anything persists or feeds the engine.
            let raw = try await provider.fetchSamples(from: start, to: end)
            let samples = raw.arbitrated()
            // FR-PROV-02: when two trackers recorded the same session, say so —
            // counted once, insights kept from both. Disclosure beats silence.
            workoutMerges = raw.workoutMergeReport()
            // Real data = a HealthKit fetch that actually returned readings. An
            // empty fetch (e.g. Simulator, or a device with no Health history)
            // keeps the demo seeds (DEBUG) / the honest empty state (Release).
            usingRealData = provider.kind == .healthKit && !samples.isEmpty
            // Every requested type came back empty ⇒ the inferred-denial cue
            // (which never accuses — see HealthReadOutcome).
            let outcome = Self.readOutcome(kind: provider.kind, samplesEmpty: samples.isEmpty)
            if outcome != .notAttempted { healthReadOutcome = outcome }
            if usingRealData {
                Self.initialBackfillDone = true
                markAppleHealthConnected()
            }
            if let container = modelContainer {
                let coordinator = IngestionCoordinator(context: container.mainContext, provider: provider)
                _ = try? coordinator.persist(samples, from: start, to: end)
            }
            let real = usingRealData
            // FB-AJR9AqEk — run the (pure, Sendable) deriver chain OFF the main
            // actor. Awaiting the detached task suspends the main actor, so a tab
            // tap during refresh is handled immediately instead of dropped ("had
            // to push many times"). Only the cheap @Observable assignments below
            // run back on main. All inputs/outputs are Sendable value types.
            // Demo pattern findings exist ONLY for the mock/demo provider in DEBUG
            // builds (launch-audit PR-102: a Release build must never fabricate).
            #if DEBUG
            let demoPatternsAllowed = provider.kind == .mock
            #else
            let demoPatternsAllowed = false
            #endif
            // FR-CTX-04: the days the user marked, projected to kind + dates.
            // Handed to the engine as a SUPPRESSION gate only — it can remove
            // baseline-deviation nudges for a marked day, never add or raise one.
            let contextWindows = self.contextWindows
            let d = await Task.detached(priority: .userInitiated) { () -> DerivedHealth in
                DerivedHealth(
                    // FR-NOT-02: the ONE seam to the engine. The background
                    // earned-attention wake calls NudgeRun too, so the off-session
                    // loop can never drift from what the app shows on screen.
                    engineNudges: NudgeRun.nudges(from: samples, context: contextWindows),
                    patternFindings: (real || !demoPatternsAllowed) ? [] : PatternEngine.run(.lv001),
                    passport: PassportStatsDeriver.derive(from: samples),
                    grid: CorrelationDeriver.derive(from: samples),
                    signals: TodaySignalsDeriver.derive(from: samples),
                    glucose: GlucoseDetailDeriver.derive(from: samples),
                    sleep: SleepDeriver.derive(from: samples),
                    trends: TrendsDeriver.derive(from: samples),
                    dayReplay: DayReplayDeriver.derive(from: samples),
                    sleepDetail: SleepDetailDeriver.derive(from: samples),
                    heart: HeartDetailDeriver.derive(from: samples),
                    fitness: FitnessDeriver.derive(from: samples),
                    activity: ActivityDeriver.derive(from: samples),
                    body: BodyTrendDeriver.derive(from: samples),
                    vitals: VitalsDeriver.derive(from: samples),
                    baselines: BaselineDeriver.derive(from: samples),
                    hrvLearn: HRVLearnDeriver.derive(from: samples))
            }.value
            // With REAL data, trust the engine even when it finds nothing — clear
            // any demo seeds so fabricated nudges are never shown as the user's own
            // (data-integrity / no-AI-tell). In demo mode, keep the seeds when the
            // engine is quiet so the feed is never empty.
            if real || !d.engineNudges.isEmpty {
                nudges = d.engineNudges.map { Nudge(engine: $0) }
            }
            // FR-PAT-01: long-horizon pattern findings (same detectors and
            // thresholds as the clinician console — one engine, any citizen).
            // Demo input until the summarisation pipeline computes PatternInput
            // from real device history (FR-PAT-02).
            //
            // FR-CTX-04: these are appended AFTER the engine, so they bypass the
            // engine's suppression gate. On a day the citizen has marked, the
            // feed must be quiet — a flag can only ever REMOVE cards, so the
            // append is skipped entirely rather than filtered card-by-card.
            let markedToday = ContextFlagDeriver.isMarked(Date(), in: contextWindows)
            if !real, !markedToday, !d.patternFindings.isEmpty {   // DEBUG demo provider only
                nudges.append(contentsOf: d.patternFindings.map { Nudge(finding: $0) })
            }
            // FR-NOT-02: a cold launch from an earned-attention alert lands here
            // before the feed exists — now that it does, open the card the alert
            // was about. No match ⇒ stays on the edition (nothing is invented).
            resolveAttentionDeepLink()
            // FR-PAS-05 / DM-05: refresh the derived half of the Passport from
            // the same on-device samples (the count half comes from app state).
            passportStats = PassportStats.compose(
                derived: d.passport,
                nudgesGenerated: nudges.count,
                sourcesConnected: connectedSources.filter(\.isConnected).count,
                journalEntries: journalEntries.count,
                consentDecisions: walletEvents.count)
            // FR-PAS-05 / DM-06: derive the 7-day correlation grid on device.
            // FR-CTX-CAL-01: CALENDAR comes from its own consented source, laid
            // over column 5 here — so a citizen with a connected calendar but no
            // HealthKit history still gets their calendar row. The overlay never
            // fabricates: unless this ACCOUNT opted in AND iOS granted access
            // AND a usable baseline exists, every overlaid cell is `.noData` —
            // exactly what the deriver already emitted for that column.
            correlationWeek = CorrelationWeek.from(overlayingCalendarColumn(on: d.grid))
            // Home signal chips — show the user's OWN latest values (nil keeps seeds).
            todaySignals = d.signals
            // Glucose detail screen — same samples, same honesty rule.
            glucoseDetail = d.glucose
            // Sleep-stage breakdown for the real sleep visualisation.
            sleepSummary = d.sleep
            // Trends + day-replay surfaces — same samples, same honesty rule.
            trends = d.trends
            dayReplay = d.dayReplay
            // A7.2 Area ④ metric details + learned baselines — same honesty rule.
            sleepDetail = d.sleepDetail
            heartDetail = d.heart
            fitnessDetail = d.fitness
            activityDetail = d.activity
            bodyDetail = d.body
            vitalsDetail = d.vitals
            baselines = d.baselines
            hrvLearn = d.hrvLearn
        } catch {
            if provider.kind == .healthKit {
                healthReadOutcome = .failed(error.localizedDescription)
            }
            lastError = error.localizedDescription   // keep existing nudges
        }
    }

    /// FR-CTX-CAL-01 — lay the consented calendar-density column over the
    /// derived grid. Account-scoped exactly like the journal (PR-111): no
    /// signed-in account ⇒ no history and not connected ⇒ every cell `.noData`.
    /// `connected` is the REAL conjunction (opt-in record AND iOS full access),
    /// never a literal; `accessState()` reads TCC without prompting, so this is
    /// safe on any path, including a headless test host.
    @MainActor
    private func overlayingCalendarColumn(on grid: CorrelationGrid) -> CorrelationGrid {
        let account = journalAccountID
        let history = CalendarLoadStore.load(forAccount: account)?.days ?? []
        let connected = CalendarLoadStore.isOptedIn(forAccount: account)
            && CalendarLoadIngestor.accessState() == .fullAccess
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let dates = grid.rows.map {
            calendar.date(byAdding: .day, value: -$0.dateOffset, to: today) ?? today
        }
        let overlay = CorrelationDeriver.calendarCells(history: history, over: dates,
                                                       connected: connected)
        let rows = zip(grid.rows, overlay).map { row, cell -> CorrelationGrid.Row in
            var cells = row.cells
            if cells.indices.contains(CorrelationDeriver.calendarIndex) {
                cells[CorrelationDeriver.calendarIndex] = cell
            }
            return CorrelationGrid.Row(dayLabel: row.dayLabel,
                                       dateOffset: row.dateOffset, cells: cells)
        }
        return CorrelationGrid(signals: grid.signals, rows: rows,
                               patternNote: grid.patternNote,
                               patternSources: grid.patternSources,
                               patternStrength: grid.patternStrength)
    }

    /// LV001 persona on the prototype (no live HealthKit): show Claus's consented
    /// goldmine dataset instead of demo seeds (FB-AN9QOlAh — "graphs not showing my
    /// real data when logged in as Claus"). A real device with the user's own
    /// HealthKit history (`usingRealData`) always wins — this only fills the demo.
    /// DEBUG-ONLY (PR-102, launch audit): a Release/TestFlight build must NEVER
    /// inject the fabricated LV001 record as the user's own data — in non-DEBUG
    /// builds this is a no-op, whatever path calls it.
    @MainActor
    func applyLV001DatasetIfNeeded() {
        #if DEBUG
        guard !usingRealData, profile?.alias == "LV001" else { return }
        passportStats   = LV001Dataset.passportStats
        correlationWeek = LV001Dataset.correlationWeek
        rings           = LV001Dataset.rings
        todaySignals    = LV001Dataset.todaySignals
        // LV001 ships composed aggregates, not raw glucose samples — a detail
        // derived from the MOCK provider's series would contradict the canned
        // 88% chips above. nil → the glucose screen shows its demo seeds.
        glucoseDetail   = nil
        #endif
    }

    @MainActor
    func loadWallet() async {
        isLoadingWallet = true
        defer { isLoadingWallet = false }
        do {
            async let g = supabase.fetchGrants()
            async let e = supabase.fetchEvents(limit: 20)
            grants       = try await g
            walletEvents = try await e
        } catch {
            #if DEBUG
            // Demo builds: fall back to mock data so the UI is never empty.
            grants       = MockData.walletGrants
            walletEvents = MockData.walletEvents
            #else
            // TestProd (T1): never present fabricated grants/events as the
            // user's own. Keep what we have and surface the failure honestly.
            lastError = error.localizedDescription
            #endif
        }
    }

    // MARK: - Derived-share push (FR-SHARE-02)

    /// Build and push the DERIVED, scoped share for a grant (PUT /shares/{grantId}).
    /// Fetches fresh samples on-device, arbitrates sources, derives only the
    /// metrics inside the consented GROUPS, and pushes that — never raw samples,
    /// never provenance. No-op with a friendly error if not on the sovereign backend.
    @MainActor
    func pushDerivedShare(grantId backendGrantId: String, scopeGroups: Set<String>, rangeDays: Int = 90) async {
        guard let sov = sovereign else {
            lastError = "Sharing requires the sovereign backend."
            return
        }
        do {
            let request = try await buildShare(scopeGroups: scopeGroups, rangeDays: rangeDays)
            try await sov.pushDerivedShare(grantId: backendGrantId, request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Full share flow used by the Share-with-clinician UI: create a consent grant
    /// for a real recipient (group scope), derive the scoped package on-device, and
    /// push it (PUT /shares/{grantId}). Returns the new backend grant id on success.
    /// `nil` (with `lastError` set) on failure or when not on the sovereign backend.
    @discardableResult
    @MainActor
    func createGrantAndShare(recipientId: String,
                             role: RecipientRole,
                             scopeGroups: Set<String>,
                             rangeDays: Int,
                             expiry: Date,
                             purpose: String? = nil) async -> String? {
        guard let sov = sovereign else {
            lastError = "Sharing requires the sovereign backend (set Config.backend = .sovereign…)."
            return nil
        }
        do {
            let grantId = try await sov.createGrant(
                recipientId: recipientId,
                role: role,
                scopeGroups: Array(scopeGroups),
                purpose: purpose,
                // Summaries-only is stated HERE, at the consent surface, rather
                // than left to the backend client's `?? "summary"` default two
                // layers down (T-PRO-01 finding, 2026-08-13): the wire body was
                // already correct, but a refactor of that default would silently
                // widen every share. The consent surface now says what it means.
                granularity: ShareGranularity.summariesOnly(for: scopeGroups),
                expiry: expiry,
                delivery: "live_view"
            )
            let request = try await buildShare(scopeGroups: scopeGroups, rangeDays: rangeDays)
            try await sov.pushDerivedShare(grantId: grantId, request)
            await loadWallet()   // reflect the new grant + ledger event
            return grantId
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Fetch → arbitrate → derive the scoped package. Raw samples never leave here.
    @MainActor
    private func buildShare(scopeGroups: Set<String>, rangeDays: Int) async throws -> DerivedShareRequest {
        let provider = HealthProviderFactory.make(dataProviderKind)
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -rangeDays, to: end) ?? end
        let samples = try await provider.fetchSamples(from: start, to: end).arbitrated()
        return DerivedShareBuilder.build(from: samples, scopeGroups: scopeGroups)
    }

    // MARK: - Per-consult share (FR-PRO-01: pre-visit gate → expiring grant + summary)

    /// Backend grant ids for consult shares armed THIS session (recipientId → id),
    /// so un-ticking the pre-visit box can revoke the exact grant it created.
    var consultShareGrantIds: [String: String] = [:]

    /// How long a per-consult grant lives. Generous enough to cover a same-day
    /// consult that runs late; short enough that the summary genuinely expires
    /// with the episode ("Shared for this consult · expires after the call").
    static let consultShareLifetime: TimeInterval = 24 * 3600

    /// Arm the pre-visit share: create a short-lived, summaries-only grant for
    /// this recipient and push the derived summary (glucose TIR/mean · sleep ·
    /// recovery) for the last 7 days. Rides the existing FR-SHARE-02 path, so
    /// raw samples and provenance never leave the device and the grant lands in
    /// the consent ledger like any other. Returns false (with `lastError`) on
    /// failure or off the sovereign backend.
    @MainActor
    @discardableResult
    func armConsultShare(recipientId: String) async -> Bool {
        guard let sov = sovereign else { return false }
        // The role tightens the server-side scope template; look it up from the
        // directory and fall back to the clinical template (never looser).
        var role: RecipientRole = .clinicalNurse
        if let match = (try? await sov.fetchRecipients())?.first(where: { $0.id == recipientId }) {
            role = match.role
        }
        let expiry = Date().addingTimeInterval(Self.consultShareLifetime)
        guard let id = await createGrantAndShare(recipientId: recipientId,
                                                role: role,
                                                scopeGroups: ["glucose", "sleep", "recovery"],
                                                rangeDays: 7,
                                                expiry: expiry,
                                                purpose: "consultation") else { return false }
        consultShareGrantIds[recipientId] = id
        return true
    }

    /// Withdraw the consult share armed this session (one-way revoke; the ledger
    /// keeps the grant + revocation events). No-op when we don't hold the id —
    /// the grant still expires on its own and stays manageable from Privacy.
    @MainActor
    func disarmConsultShare(recipientId: String) async {
        guard let sov = sovereign, let id = consultShareGrantIds[recipientId] else { return }
        do {
            try await sov.revokeGrant(backendGrantId: id)
            consultShareGrantIds[recipientId] = nil
            await loadWallet()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func toggleGrant(_ grant: WalletGrant) async {
        // Optimistic update
        guard let idx = grants.firstIndex(where: { $0.id == grant.id }) else { return }
        var updated = grant
        updated.isActive.toggle()
        grants[idx] = updated

        do {
            let saved = try await supabase.upsertGrant(updated)
            grants[idx] = saved
        } catch {
            // Revert on failure
            grants[idx] = grant
            lastError = error.localizedDescription
        }
    }

    /// UC-21 — issue a Liviqa Share Receipt for a grant into the My DfG wallet.
    /// Provenance only (never raw samples). Returns the wallet offer URL to render
    /// as a QR / open on-device, or `nil` with `lastError` set on failure.
    @MainActor
    func issueShareReceipt(for grant: WalletGrant, verified: String? = nil) async -> URL? {
        guard let sov = sovereign else {
            lastError = "Wallet receipts require the sovereign backend."
            return nil
        }
        do {
            return try await sov.issueShareReceipt(for: grant, verified: verified)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// UC-A — issue the citizen's own "Liviqa Citizen" sign-in credential into
    /// their My DfG wallet (pseudonymous: role + member id + issue date only).
    /// Returns the wallet offer URL, or nil with `lastError` set.
    /// Expiry of the last-issued Liviqa Citizen credential (short-validity
    /// policy — renewal is just re-issuing). Persisted so the Privacy row can
    /// show "valid until / renew" across launches.
    var citizenCredentialValidUntil: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: "liviqa.citizenCred.validUntil")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "liviqa.citizenCred.validUntil") }
    }

    @MainActor
    func issueCitizenCredential() async -> URL? {
        guard let sov = sovereign else {
            lastError = "Your Liviqa Citizen credential requires the sovereign backend."
            return nil
        }
        do {
            let offer = try await sov.issueCitizenCredential()
            citizenCredentialValidUntil = offer.validUntil
            return offer.url
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}

/// Results of the off-main deriver chain (FB-AJR9AqEk). All fields are Sendable
/// value types so the bundle can cross the actor boundary out of `Task.detached`.
private struct DerivedHealth: Sendable {
    let engineNudges: [EngineNudge]
    let patternFindings: [PatternFinding]
    let passport: DerivedPassportStats
    let grid: CorrelationGrid
    let signals: TodaySignals?
    let glucose: GlucoseWeekDetail?
    let sleep: SleepSummary?
    let trends: TrendsSummary?
    let dayReplay: DayReplay?
    // A7.2 Area ④ — the seven metric-detail surfaces.
    let sleepDetail: SleepWeekDetail?
    let heart: HeartWeekDetail?
    let fitness: FitnessDetail?
    let activity: ActivityWeekDetail?
    let body: BodyTrendDetail?
    let vitals: VitalsDetail?
    let baselines: BaselineBook?
    // A7.2 Area ⑨ — knowledge-tier / explain-template HRV aggregation.
    let hrvLearn: HRVLearnDetail?
}
