// AppState.swift — Single source of truth. Injected via .environment(appState).
// v02 · 2026-05-22 — added healthContext (declared baseline, HealthContext)
import Foundation
import Observation

@Observable
final class AppState {

    // Service (swap MockSupabaseService → SupabaseService when credentials are ready)
    let supabase: any SupabaseServiceProtocol

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

    // DfG tokens
    var tokenBalance: Int                    = 47
    var tokenTransactions: [TokenTransaction] = MockData.tokenTransactions

    // Declared profile — things only the user knows
    var healthContext: HealthContext = .demo

    // Error surface
    var lastError: String? = nil

    init(supabase: any SupabaseServiceProtocol = MockSupabaseService()) {
        self.supabase = supabase
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
    func signInDemo() {
        session = UserSession(
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: nil
        )
        profile = UserProfile(id: session!.userId, displayName: "Claus", avatarURL: nil, createdAt: Date())
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
