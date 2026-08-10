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
    var isDemoData: Bool { !usingRealData }
    /// Set once `refreshFromHealth` has run, so UI hints don't flash before the
    /// first fetch resolves.
    private(set) var didAttemptHealthFetch = false
    /// True only on a real device that tried HealthKit but has no readings yet —
    /// the cue to show the "connect Apple Health" hint. Never true in demo /
    /// screenshot mode (provider is `.mock` there).
    var showConnectHealthHint: Bool {
        didAttemptHealthFetch && dataProviderKind == .healthKit && !usingRealData
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
    static func resolveProviderKind(arguments: [String],
                                    env: [String: String],
                                    realAvailable: Bool) -> DataProviderKind {
        if arguments.contains("-uiTestAutoDemo") || env["LIVIQA_DATA"] == "mock" { return .mock }
        if env["LIVIQA_DATA"] == "healthKit" { return .healthKit }
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
    private let modelContainer: ModelContainer? = AppState.openStore()

    private static func openStore() -> ModelContainer? {
        do {
            return try LiviqaStore.makeContainer()
        } catch {
            print("‼️ LiviqaStore: on-disk container failed to open (\(error)). Falling back to in-memory for this session.")
            return try? LiviqaStore.makeContainer(inMemory: true)
        }
    }

    /// The canonical, source-agnostic health record repository (labs/diagnoses/meds
    /// from ANY source). On-device only. `nil` only if the store failed to open.
    var healthStore: HealthStore? {
        guard let modelContainer else { return nil }
        return HealthStore(context: modelContainer.mainContext)
    }

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
    /// Dual-recording merges from the last fetch (FR-PROV-02) — sessions that
    /// arrived from two trackers and were counted once. Shown in Data sources.
    var workoutMerges: [WorkoutMerge] = []

    /// Last-night sleep-stage breakdown + nightly trend, derived from samples.
    /// Drives the real sleep visualisation (falls back to demo when nil).
    var sleepSummary: SleepSummary? = nil

    // Wallet
    var grants:       [WalletGrant]  = []
    var walletEvents: [WalletEvent]  = []
    var isLoadingWallet: Bool        = false

    // Journal
    var journalEntries:  [JournalEntry] = []
    var journalSyncEnabled: Bool        = false

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

    init(supabase: any SupabaseServiceProtocol = Config.makeService()) {
        self.supabase = supabase
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
        journalEntries = []
        lastError = nil
    }

    /// Permanently erase everything Liviqa holds on this device (T-DEL-01,
    /// Settings → "Delete all my data" / GDPR Art. 17): every SwiftData sample
    /// entity, the journal file, the encrypted HealthKit sync anchors, the
    /// Keychain session token, and Liviqa's UserDefaults leftovers — then sign
    /// out and reset the in-memory surfaces to first-launch demo seeds. Each
    /// step is best-effort so one failing store can never block the others.
    @MainActor
    func deleteAllData() async {
        // 1. On-device SwiftData store — every sample/source entity (OD-09).
        if let container = modelContainer {
            let context = container.mainContext
            for model in LiviqaStore.models {
                try? context.delete(model: model)
            }
            try? context.save()
        }
        // 2. Journal file (Application Support/journal.v1.json).
        if let journalURL = JournalStore.defaultURL() {
            try? FileManager.default.removeItem(at: journalURL)
        }
        // 3. Encrypted HealthKit sync anchors for this local scope (FR-ING-03/04).
        (try? EncryptedAnchorStore(keyVault: .shared, userScope: LocalUserScope.current()))?.clear()
        // 4. Keychain session token (NFR-SEC-01) + server session + auth state.
        SessionTokenStore().clear()
        await signOut()
        // 5. Liviqa UserDefaults leftovers.
        citizenCredentialValidUntil = nil
        UserDefaults.standard.removeObject(forKey: Self.initialBackfillKey)
        // 6. Reset every health-derived in-memory surface to first-launch seeds
        //    (demo in DEBUG, EMPTY in Release — ColdStartSeeds.swift) so no trace
        //    of the erased data survives in the running session.
        usingRealData   = false
        rings           = ColdStart.rings
        nudges          = ColdStart.nudges
        todaySignals    = nil
        sleepSummary    = nil
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
        researchContributed = false
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
    @MainActor
    func eraseEverythingServerFirst() async -> Bool {
        eraseServerError = nil
        if session != nil, let rights = dataRights {
            do { try await rights.eraseMyData() }
            catch {
                eraseServerError = error.localizedDescription
                return false
            }
        }
        await deleteAllData()
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
                    journal: JournalStore.load() ?? journalEntries))
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
        store.ingest(observations: rows.obs, conditions: rows.cond,
                     medications: rows.med, source: source)
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
            let d = await Task.detached(priority: .userInitiated) { () -> DerivedHealth in
                DerivedHealth(
                    engineNudges: NudgeEngine().generate(samples: samples),
                    patternFindings: (real || !demoPatternsAllowed) ? [] : PatternEngine.run(.lv001),
                    passport: PassportStatsDeriver.derive(from: samples),
                    grid: CorrelationDeriver.derive(from: samples),
                    signals: TodaySignalsDeriver.derive(from: samples),
                    sleep: SleepDeriver.derive(from: samples))
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
            if !real, !d.patternFindings.isEmpty {   // DEBUG demo provider only
                nudges.append(contentsOf: d.patternFindings.map { Nudge(finding: $0) })
            }
            // FR-PAS-05 / DM-05: refresh the derived half of the Passport from
            // the same on-device samples (the count half comes from app state).
            passportStats = PassportStats.compose(
                derived: d.passport,
                nudgesGenerated: nudges.count,
                sourcesConnected: connectedSources.filter(\.isConnected).count,
                journalEntries: journalEntries.count,
                consentDecisions: walletEvents.count)
            // FR-PAS-05 / DM-06: derive the 7-day correlation grid on device.
            correlationWeek = CorrelationWeek.from(d.grid)
            // Home signal chips — show the user's OWN latest values (nil keeps seeds).
            todaySignals = d.signals
            // Sleep-stage breakdown for the real sleep visualisation.
            sleepSummary = d.sleep
        } catch {
            lastError = error.localizedDescription   // keep existing nudges
        }
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
                granularity: nil,
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
    let sleep: SleepSummary?
}
