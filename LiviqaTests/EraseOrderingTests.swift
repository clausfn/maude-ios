import Testing
import Foundation
@testable import Liviqa

// T1 TestProd wave — GDPR Art. 17 ordering. The Settings delete flow erases
// SERVER-side first (`POST /me/erase`) and wipes the device only after the
// server confirmed: a network failure can then never strand server data behind
// a success message the user already saw. Also covers the Art. 20 export path.
@MainActor
struct EraseOrderingTests {

    /// Fake sovereign service: records call order for erase vs sign-out (the
    /// first step of the local wipe that touches the service).
    final class FakeRightsService: SupabaseServiceProtocol, DataRights, @unchecked Sendable {
        var eraseCalls = 0
        var failErase = false
        var signOutCalls = 0
        /// Captured at the moment of sign-out: had the server erase already run?
        var eraseRanBeforeSignOut: Bool?

        func eraseMyData() async throws {
            eraseCalls += 1
            if failErase { throw SupabaseError.serverError("The connection appears to be offline.") }
        }
        func exportMyData() async throws -> Data { Data(#"{"exportedAt":"fake"}"#.utf8) }

        func signOut() async throws {
            if eraseRanBeforeSignOut == nil { eraseRanBeforeSignOut = eraseCalls > 0 }
            signOutCalls += 1
        }

        // Protocol boilerplate (unused in these tests).
        func signInWithEmail(email: String, password: String) async throws -> UserSession {
            UserSession(userId: UUID(), email: email)
        }
        func signInWithApple(idToken: String, nonce: String) async throws -> UserSession {
            UserSession(userId: UUID(), email: nil)
        }
        func currentSession() async -> UserSession? { nil }
        func fetchProfile() async throws -> UserProfile {
            UserProfile(id: UUID(), displayName: nil, avatarURL: nil, createdAt: nil, alias: nil)
        }
        func fetchGrants() async throws -> [WalletGrant] { [] }
        func upsertGrant(_ grant: WalletGrant) async throws -> WalletGrant { grant }
        func fetchEvents(limit: Int) async throws -> [WalletEvent] { [] }
        func fetchJournalEntries(limit: Int) async throws -> [JournalEntry] { [] }
        func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry { entry }
        func deleteJournalEntry(id: UUID) async throws {}
    }

    @Test func serverFailureAbortsBeforeAnyLocalWipe() async {
        let svc = FakeRightsService()
        svc.failErase = true
        let state = AppState(supabase: svc)
        state.session = UserSession(userId: UUID(), email: "t@example.com")

        let ok = await state.eraseEverythingServerFirst()

        #expect(!ok)
        #expect(svc.eraseCalls == 1)
        #expect(svc.signOutCalls == 0)              // local wipe did NOT start
        #expect(state.session != nil)               // still signed in — retryable
        #expect(state.eraseServerError != nil)      // surfaced honestly
    }

    @Test func successRunsServerEraseBeforeLocalWipe() async {
        let svc = FakeRightsService()
        let state = AppState(supabase: svc)
        state.session = UserSession(userId: UUID(), email: "t@example.com")

        let ok = await state.eraseEverythingServerFirst()

        #expect(ok)
        #expect(svc.eraseCalls == 1)
        #expect(svc.signOutCalls == 1)
        #expect(svc.eraseRanBeforeSignOut == true)  // ORDER: server first, then local
        #expect(state.session == nil)               // signed out by the local wipe
        #expect(state.eraseServerError == nil)
    }

    @Test func mockBackendSkipsServerAndWipesLocally() async {
        // No DataRights capability (demo/mock) → device-local erase only.
        let state = AppState(supabase: MockSupabaseService())
        state.session = UserSession(userId: UUID(), email: nil)

        let ok = await state.eraseEverythingServerFirst()

        #expect(ok)
        #expect(state.session == nil)
        #expect(state.eraseServerError == nil)
    }

    @Test func exportWritesServerBlobToShareableFile() async throws {
        let svc = FakeRightsService()
        let state = AppState(supabase: svc)
        state.session = UserSession(userId: UUID(), email: "t@example.com")

        let url = try #require(await state.exportMyData())
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        #expect(data == Data(#"{"exportedAt":"fake"}"#.utf8))   // server blob, verbatim
        #expect(url.pathExtension == "json")
    }
}
