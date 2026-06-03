// AppState.swift — Single source of truth. Injected via .environment(appState).
// v02 · 2026-05-22 — added healthContext (declared baseline, HealthContext)
import Foundation
import Observation
import SwiftData

@Observable
final class AppState {

    // Service (swap MockSupabaseService → SupabaseService when credentials are ready)
    let supabase: any SupabaseServiceProtocol

    // L1 source selection. `.mock` = synthetic demo user (FR-ARCH-05 badge);
    // `.healthKit` = real on-device data. Swap with no code change elsewhere.
    var dataProviderKind: DataProviderKind = .mock
    var isDemoData: Bool { dataProviderKind.isDemoData }

    // On-device SwiftData store (samples never leave the device). Optional so a
    // schema/store failure can never crash launch — the feed still works.
    private let modelContainer: ModelContainer? = try? LiviqaStore.makeContainer()

    // Auth
    var session: UserSession?  = nil
    var profile: UserProfile?  = nil
    var isSigningIn: Bool      = false

    // Today
    var rings:  [MetricRing]   = MockData.rings
    var nudges: [Nudge]        = MockData.todayNudges

    // Wallet
    var grants:       [WalletGrant]  = []
    var walletEvents: [WalletEvent]  = []
    var isLoadingWallet: Bool        = false

    // Journal
    var journalEntries:  [JournalEntry] = []
    var journalSyncEnabled: Bool        = false

    // Data sources & backup
    var backupPreference: BackupPreference    = .onDevice
    var connectedSources: [DataSourceConnection] = MockData.connectedSources

    // Health Passport
    var passportStats: PassportStats = MockData.passportStats
    var correlationWeek: CorrelationWeek = MockData.correlationWeek

    // DfG tokens
    var tokenBalance: Int                    = 47
    var tokenTransactions: [TokenTransaction] = MockData.tokenTransactions

    // Declared profile — things only the user knows
    var healthContext: HealthContext = .demo

    // Error surface
    var lastError: String? = nil

    init(supabase: any SupabaseServiceProtocol = Config.makeService()) {
        self.supabase = supabase
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

    // MARK: - Care-team actions (FR-WAL adjacent; consult + messaging)

    @MainActor
    func refreshCareInbox() async {
        guard let care = careConnect else { return }
        async let t = try? await care.fetchThreads()
        async let c = try? await care.fetchActiveConsults()
        async let n = try? await care.fetchNotifications()
        careThreads = await t ?? careThreads
        activeConsults = await c ?? activeConsults
        careNotifications = await n ?? careNotifications
    }

    // MARK: - Auth actions

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
        profile = UserProfile(id: session!.userId, displayName: "LV001", avatarURL: nil, createdAt: Date())
        grants = MockData.walletGrants
        walletEvents = MockData.walletEvents
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

    // MARK: - Data loading

    @MainActor
    func postSignIn() async {
        await loadProfile()
        await loadWallet()
    }

    @MainActor
    func loadProfile() async {
        do { profile = try await supabase.fetchProfile() } catch { /* non-fatal */ }
    }

    // MARK: - On-device health pipeline (L1 → L2 → L3)

    /// Ingest the last 30 days from the active provider, persist on-device, and
    /// regenerate the capped, FR-NDG-06-clean nudge feed. Falls back to the
    /// existing nudges if nothing fires, so the feed is never empty.
    @MainActor
    func refreshFromHealth() async {
        let provider = HealthProviderFactory.make(dataProviderKind)
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        do {
            try await provider.requestReadAuthorization()
            // §2.3: arbitrate sources (highest tier wins, lower fills gaps) before
            // anything persists or feeds the engine.
            let samples = try await provider.fetchSamples(from: start, to: end).arbitrated()
            if let container = modelContainer {
                let coordinator = IngestionCoordinator(context: container.mainContext, provider: provider)
                try? coordinator.persist(samples, from: start, to: end)
            }
            let engineNudges = NudgeEngine().generate(samples: samples)
            if !engineNudges.isEmpty {
                nudges = engineNudges.map { Nudge(engine: $0) }
            }
            // FR-PAS-05 / DM-05: refresh the derived half of the Passport from
            // the same on-device samples (the count half comes from app state).
            passportStats = PassportStats.compose(
                derived: PassportStatsDeriver.derive(from: samples),
                nudgesGenerated: nudges.count,
                sourcesConnected: connectedSources.filter(\.isConnected).count,
                journalEntries: journalEntries.count,
                consentDecisions: walletEvents.count)
            // FR-PAS-05 / DM-06: derive the 7-day correlation grid on device.
            correlationWeek = CorrelationWeek.from(CorrelationDeriver.derive(from: samples))
        } catch {
            lastError = error.localizedDescription   // keep existing nudges
        }
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
            // Fall back to mock data so the UI is never empty
            grants       = MockData.walletGrants
            walletEvents = MockData.walletEvents
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
}
