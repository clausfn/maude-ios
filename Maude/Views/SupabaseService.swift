// SupabaseService.swift — Stub only. App uses MockSupabaseService (demo mode).
// Live Supabase implementation: see SupabaseService+Live.swift (not compiled by default).
import Foundation

final class SupabaseService: SupabaseServiceProtocol, @unchecked Sendable {
    func signInWithEmail(email: String, password: String) async throws -> UserSession {
        throw SupabaseError.notAvailable
    }
    func signUpWithEmail(email: String, password: String) async throws -> UserSession {
        throw SupabaseError.notAvailable
    }
    func signInWithApple(idToken: String, nonce: String) async throws -> UserSession {
        throw SupabaseError.notAvailable
    }
    func signOut() async throws {}
    func currentSession() async -> UserSession? { nil }
    func fetchProfile() async throws -> UserProfile { throw SupabaseError.notAvailable }
    func fetchGrants() async throws -> [WalletGrant] { MockData.walletGrants }
    func upsertGrant(_ grant: WalletGrant) async throws -> WalletGrant { grant }
    func fetchEvents(limit: Int) async throws -> [WalletEvent] { MockData.walletEvents }
    func fetchJournalEntries(limit: Int) async throws -> [JournalEntry] { [] }
    func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry { entry }
    func deleteJournalEntry(id: UUID) async throws {}
}
