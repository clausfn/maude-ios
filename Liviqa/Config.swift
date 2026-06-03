// Config.swift — Backend selection + credentials.
// Default backend is `.mock` (FR-ARCH-05 demo). The sovereign backend is the real
// PII target (NFR-SEC-07); Supabase is sandbox-only and US-parented.
import Foundation

enum Config {

    // Supabase (SANDBOX ONLY — never real PII; see NFR-SEC-07). Retained so the
    // sandbox path keeps working; demoted from the default.
    static let supabaseURL = URL(string: "https://mdtnupskqvxvpjffzwnv.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kdG51cHNrcXZ4dnBqZmZ6d252Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzkwNjEsImV4cCI6MjA5NDk1NTA2MX0.pmBtgp8uekeqZpS6bv7KH72GZS6TAHJb1Zei4YV4zvs"

    // MARK: - Backend selection

    enum Backend {
        case mock                                   // synthetic demo (default)
        case supabaseSandbox                        // US-parented; sandbox only
        case sovereign(baseURL: URL, devToken: String?)   // EU-sovereign (real PII)
    }

    /// Active backend. Flip to `.sovereignLocal` to develop against the local
    /// EU-sovereign backend, or build a `.sovereign(api.dfgworks.dk)` for staging.
    static let backend: Backend = .mock

    /// Local sovereign backend for development (embedded Postgres; seed bearer
    /// token). Backend: `http://localhost:3001`, citizen seed `dev-citizen-claus`.
    static let sovereignLocal: Backend = .sovereign(
        baseURL: URL(string: "http://localhost:3001")!,
        devToken: "dev-citizen-claus"
    )

    /// Build the service for a backend. Defaults to the active `backend`.
    static func makeService(_ b: Backend = backend) -> any SupabaseServiceProtocol {
        switch b {
        case .mock:
            return MockSupabaseService()
        case .supabaseSandbox:
            return SupabaseService()
        case .sovereign(let url, let token):
            return LiviqaBackendService(baseURL: url, devToken: token)
        }
    }
}
