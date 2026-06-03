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

    /// Ory Network project (auth provider for the sovereign backend). The app runs
    /// the native login flow here to get a session token, presented to the backend
    /// as `Authorization: Bearer`.
    static let oryURL = URL(string: "https://keen-khayyam-st5ek6x27a.projects.oryapis.com")!

    /// EU-sovereign video provider domain (self-hosted Jitsi / Whereby). The
    /// citizen joins `https://<jitsiDomain>/liviqa-consult-<sessionId>` — the same
    /// deterministic room the console uses. `nil` ⇒ no live media (secure shell).
    /// NFR-SEC-07: must never point at a US-parented provider on the PII path.
    ///
    /// TODO(NFR-SEC-07): set this to the real EU-sovereign Jitsi/Whereby domain
    /// (self-hosted) before any production/TestFlight build with live consults.
    /// Locked default is `nil` (secure shell). LOCAL QA only may opt into the demo
    /// domain by launching with env `LIVIQA_JITSI_DEMO=1` — never a prod default.
    static var jitsiDomain: String? {
        if ProcessInfo.processInfo.environment["LIVIQA_JITSI_DEMO"] == "1" { return jitsiDemoDomain }
        return nil
    }

    /// LOCAL-PARITY ONLY. `meet.jit.si` is US-operated — it must NEVER be used as a
    /// production default (NFR-SEC-07). Use it only for local dev to exercise the
    /// same Jitsi room the console joins (set `Config.jitsiDomain = jitsiDemoDomain`
    /// in a throwaway local build); never commit that wired to a real-PII path.
    static let jitsiDemoDomain = "meet.jit.si"

    enum Backend {
        case mock                                   // synthetic demo (default)
        case supabaseSandbox                        // US-parented; sandbox only
        // EU-sovereign (real PII). `devToken` = local seed bearer; `oryURL` = real
        // Ory auth (when set, sign-in uses Ory and the bearer is the Ory session token).
        case sovereign(baseURL: URL, devToken: String?, oryURL: URL?)
    }

    /// Active backend. Locked default is `.mock` (FR-ARCH-05 demo). LOCAL QA may
    /// override at launch via env `LIVIQA_BACKEND=sovereignLocal|sovereignStaging|
    /// supabaseSandbox` without changing the shipped default.
    static var backend: Backend {
        switch ProcessInfo.processInfo.environment["LIVIQA_BACKEND"] {
        case "sovereignLocal":   return sovereignLocal
        case "sovereignStaging": return sovereignStaging
        case "supabaseSandbox":  return .supabaseSandbox
        default:                 return .mock     // locked default
        }
    }

    /// Local sovereign backend for development (embedded Postgres; seed bearer
    /// token; no Ory). Backend: `http://localhost:3001`, citizen seed `dev-citizen-claus`.
    static let sovereignLocal: Backend = .sovereign(
        baseURL: URL(string: "http://localhost:3001")!,
        devToken: "dev-citizen-claus",
        oryURL: nil
    )

    /// Sovereign backend with real Ory login (email/password). Point `baseURL` at
    /// the staging/prod API; auth runs against `oryURL`.
    static let sovereignStaging: Backend = .sovereign(
        baseURL: URL(string: "https://api.dfgworks.dk")!,
        devToken: nil,
        oryURL: oryURL
    )

    /// Build the service for a backend. Defaults to the active `backend`.
    static func makeService(_ b: Backend = backend) -> any SupabaseServiceProtocol {
        switch b {
        case .mock:
            return MockSupabaseService()
        case .supabaseSandbox:
            return SupabaseService()
        case .sovereign(let url, let token, let oryURL):
            let ory = oryURL.map { OryAuthClient(baseURL: $0) }
            return LiviqaBackendService(baseURL: url, devToken: token, ory: ory)
        }
    }
}
