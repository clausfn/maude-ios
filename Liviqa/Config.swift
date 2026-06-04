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

    /// Supabase Auth (self-hosted GoTrue, EU/Scaleway) — the auth provider for the
    /// sovereign backend (NFR-SEC-07: EU-sovereign, not Ory, not Supabase Cloud).
    /// The app signs in here and presents the Supabase access token (JWT) to the
    /// backend as `Authorization: Bearer`. See docs/Auth_Supabase_v01.md.
    static let supabaseAuthURL = URL(string: "https://auth.liviqa.app")!

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
        // EU-sovereign (real PII). `devToken` = local seed bearer; `authURL` =
        // self-hosted Supabase Auth (when set, sign-in uses GoTrue and the bearer
        // is the Supabase access-token JWT).
        case sovereign(baseURL: URL, devToken: String?, authURL: URL?)
    }

    /// Active backend.
    /// - **Release / TestFlight → live sovereign prod** (`api.liviqa.app` + Supabase
    ///   GoTrue), so the shipped build feeds real/live data with no extra config.
    /// - **Debug → `.mock`** (synthetic demo, FR-ARCH-05).
    /// - `LIVIQA_BACKEND` env always wins (local QA / e2e), e.g.
    ///   `sovereignLocal|sovereignStaging|sovereignProd|supabaseSandbox|mock`.
    static var backend: Backend {
        switch ProcessInfo.processInfo.environment["LIVIQA_BACKEND"] {
        case "sovereignLocal":   return sovereignLocal
        case "sovereignStaging": return sovereignStaging
        case "sovereignProd":    return sovereignProd
        case "supabaseSandbox":  return .supabaseSandbox
        case "mock":             return .mock
        default:
            #if DEBUG
            return .mock              // dev default = synthetic
            #else
            return sovereignProd      // TestFlight/App Store = live data
            #endif
        }
    }

    /// Gates the live sign-in options (Apple + email) on the auth screen. While
    /// `false`, the auth screen shows ONLY "Continue without account" (demo) so
    /// TestFlight UI testers never hit a broken sign-in. Flip to `true` once the
    /// GoTrue ↔ backend secret is verified (and Apple provider enabled).
    /// See docs/Auth_Deploy_Handoff_v01.md.
    static let authEnabled = false

    /// v1 TestFlight ships WITHOUT the live video consult — no EU-sovereign Jitsi
    /// yet (NFR-SEC-07; `meet.jit.si` is demo-only) and no camera/mic entitlements.
    /// Secure messaging stays available. Flip on once a sovereign Jitsi is wired.
    static let videoConsultEnabled = false

    /// Local sovereign backend for development (embedded Postgres; seed bearer
    /// token; no Supabase). Backend: `http://localhost:3001`, citizen seed `dev-citizen-claus`.
    static let sovereignLocal: Backend = .sovereign(
        baseURL: URL(string: "http://localhost:3001")!,
        devToken: "dev-citizen-claus",
        authURL: nil
    )

    /// Sovereign backend with real Supabase Auth (GoTrue) login. Point `baseURL` at
    /// the staging/prod API; auth runs against the self-hosted `supabaseAuthURL`.
    static let sovereignStaging: Backend = .sovereign(
        baseURL: URL(string: "https://api.liviqa.app")!,
        devToken: nil,
        authURL: supabaseAuthURL
    )

    /// Production sovereign backend (TestFlight/App Store default). Canonical hosts
    /// are on `liviqa.app`: API `api.liviqa.app`, auth `auth.liviqa.app`.
    static let sovereignProd: Backend = .sovereign(
        baseURL: URL(string: "https://api.liviqa.app")!,
        devToken: nil,
        authURL: supabaseAuthURL
    )

    /// Build the service for a backend. Defaults to the active `backend`.
    static func makeService(_ b: Backend = backend) -> any SupabaseServiceProtocol {
        switch b {
        case .mock:
            return MockSupabaseService()
        case .supabaseSandbox:
            return SupabaseService()
        case .sovereign(let url, let token, let authURL):
            // Self-hosted GoTrue needs no apikey; pass one here only if fronted by Kong.
            let auth = authURL.map { SupabaseAuthClient(baseURL: $0, apiKey: nil) }
            return LiviqaBackendService(baseURL: url, devToken: token, auth: auth)
        }
    }
}
