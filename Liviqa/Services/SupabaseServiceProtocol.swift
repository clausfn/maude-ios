// SupabaseServiceProtocol.swift — Contract shared by MockSupabaseService and SupabaseService.
import Foundation

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notSignedIn
    case invalidCredentials
    case notAvailable           // package not added yet / Apple Sign In stub
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:            return "You are not signed in."
        case .invalidCredentials:     return "Invalid email or password."
        case .notAvailable:           return "This sign-in method is not available right now."
        case .serverError(let msg):   return msg
        }
    }
}

// MARK: - Protocol

protocol SupabaseServiceProtocol: Sendable {

    // Auth
    func signInWithEmail(email: String, password: String) async throws -> UserSession
    func signInWithApple(idToken: String, nonce: String) async throws -> UserSession
    func signOut() async throws
    func currentSession() async -> UserSession?

    // Profile
    func fetchProfile() async throws -> UserProfile

    // Wallet
    func fetchGrants() async throws -> [WalletGrant]
    func upsertGrant(_ grant: WalletGrant) async throws -> WalletGrant
    func fetchEvents(limit: Int) async throws -> [WalletEvent]

    // Journal (opt-in sync only — HealthKit data never goes here)
    func fetchJournalEntries(limit: Int) async throws -> [JournalEntry]
    func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry
    func deleteJournalEntry(id: UUID) async throws
}
