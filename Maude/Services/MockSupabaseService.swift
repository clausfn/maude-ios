// MockSupabaseService.swift — In-memory implementation. No credentials needed.
// Used by AppState by default; also the demo mode backend.
import Foundation

final class MockSupabaseService: SupabaseServiceProtocol, @unchecked Sendable {

    // In-memory state
    private var _session: UserSession? = nil
    // Release seeds NOTHING. `.mock` is Maude's on-device service, not a demo, so
    // fabricated grants and ledger events must not render as the user's own — the
    // same rule ColdStartSeeds already holds for every other surface (PR-102).
    #if DEBUG
    private var _grants: [WalletGrant] = MockData.walletGrants
    private var _events: [WalletEvent] = MockData.walletEvents
    #else
    private var _grants: [WalletGrant] = []
    private var _events: [WalletEvent] = []
    #endif
    private var _entries: [JournalEntry] = []

    // Simulated network latency
    private func delay() async {
        let ms = UInt64.random(in: 150_000_000...400_000_000)
        try? await Task.sleep(nanoseconds: ms)
    }

    // MARK: Auth

    func signInWithEmail(email: String, password: String) async throws -> UserSession {
        await delay()
        guard !email.isEmpty, password.count >= 6 else {
            throw SupabaseError.invalidCredentials
        }
        let session = UserSession(
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: email
        )
        _session = session
        return session
    }

    func signUpWithEmail(email: String, password: String) async throws -> UserSession {
        await delay()
        guard !email.isEmpty else { throw SupabaseError.invalidCredentials }
        guard password.count >= 6 else { throw SupabaseError.weakPassword("") }
        if email.lowercased() == "taken@maude.app" { throw SupabaseError.emailTaken }  // dev: exercise the state
        let session = UserSession(
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            email: email
        )
        _session = session
        return session
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> UserSession {
        await delay()
        let session = UserSession(
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: nil
        )
        _session = session
        return session
    }

    func signOut() async throws {
        await delay()
        _session = nil
    }

    func currentSession() async -> UserSession? {
        _session
    }

    // MARK: Profile

    func fetchProfile() async throws -> UserProfile {
        await delay()
        guard let session = _session else { throw SupabaseError.notSignedIn }
        return UserProfile(
            id: session.userId,
            displayName: "Claus",
            avatarURL: nil,
            createdAt: Date()
        )
    }

    // MARK: Wallet

    func fetchGrants() async throws -> [WalletGrant] {
        await delay()
        return _grants
    }

    func upsertGrant(_ grant: WalletGrant) async throws -> WalletGrant {
        await delay()
        if let idx = _grants.firstIndex(where: { $0.id == grant.id }) {
            _grants[idx] = grant
        } else {
            _grants.append(grant)
        }
        return grant
    }

    func fetchEvents(limit: Int) async throws -> [WalletEvent] {
        await delay()
        return Array(_events.prefix(limit))
    }

    // MARK: Journal

    func fetchJournalEntries(limit: Int) async throws -> [JournalEntry] {
        await delay()
        return Array(_entries.prefix(limit))
    }

    func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry {
        await delay()
        if let idx = _entries.firstIndex(where: { $0.id == entry.id }) {
            _entries[idx] = entry
        } else {
            _entries.insert(entry, at: 0)
        }
        return entry
    }

    func deleteJournalEntry(id: UUID) async throws {
        await delay()
        _entries.removeAll { $0.id == id }
    }
}
