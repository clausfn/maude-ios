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
    /// Live value points at the self-hosted Jitsi on Scaleway (fr-par, EU). It is
    /// reachable over a valid public TLS cert and accepts guests (the citizen and
    /// their clinician join the same deterministic room — no account wall).
    /// LOCAL QA may override to the public demo domain with env `LIVIQA_JITSI_DEMO=1`.
    static var jitsiDomain: String? {
        if ProcessInfo.processInfo.environment["LIVIQA_JITSI_DEMO"] == "1" { return jitsiDemoDomain }
        return jitsiSovereignDomain
    }

    /// Self-hosted, EU-sovereign Jitsi (Scaleway fr-par). Hardening follow-up:
    /// move behind `meet.liviqa.app` (A record → this host) for a clean URL; the
    /// sslip.io host is a valid, TLS-terminated stand-in until then.
    static let jitsiSovereignDomain = "163-172-173-186.sslip.io"

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
    static let authEnabled = true

    /// Live video consult. Enabled now that a self-hosted EU-sovereign Jitsi is
    /// wired (`jitsiSovereignDomain`, Scaleway fr-par) and camera/mic usage strings
    /// are in Info.plist. Secure messaging stays available regardless.
    static let videoConsultEnabled = true

    // MARK: - DfG wallet (My DfG) integration — eIDAS 2.0 verifiable credentials
    /// OFF until Partisia provides the sandbox pack. When enabled, a consent moment
    /// can hand off to the My DfG wallet to present/sign a credential, then return.
    /// All values below are PLACEHOLDERS — fill from Partisia (see
    /// `~/Desktop/Liviqa_DfG_Wallet_Demo_Prep_v01_20260609.md`). The shipped app is
    /// unaffected while this is `false`.
    static let dfgWalletEnabled = false

    /// DfG Wallet *login* flow (eIDAS 2.0 + Partisia verification) on the sign-in
    /// screen. This is the in-app, high-fidelity simulation of the wallet use cases
    /// (identity presentation → MPC signature check → CE-ledger anchoring) for demos
    /// and pilots — it does not require the live Partisia backend.
    /// DEBUG-ONLY (PR-102, launch audit): simulated identity logins must never ship
    /// in a Release/TestFlight build — they route through `signInDemo()` and would
    /// present fabricated data as the user's own. ON for the pitch in Debug.
    #if DEBUG
    static let dfgWalletLoginEnabled = true
    #else
    static let dfgWalletLoginEnabled = false
    #endif

    /// National eID / login-provider sign-in (MitID, e-Boks ID) — simulated, in-app
    /// high-fidelity flows for demos and pilots. No live IDP integration.
    /// DEBUG-ONLY (PR-102): same rationale as `dfgWalletLoginEnabled`.
    #if DEBUG
    static let nationalIDLoginEnabled = true
    #else
    static let nationalIDLoginEnabled = false
    #endif

    /// Wallet credential rails (Liviqa Citizen issuance, receipts, OID4VP login).
    /// They live in the SANDBOX only (per Partisia/Kim, 2026-06-09: production
    /// credentials are parked). The sandbox backend shares prod's database and
    /// JWT secret, so on production builds the wallet rails are ROUTED to the
    /// sandbox container instead of being hidden — same accounts, same grants,
    /// same ledger; only the credential calls take the sandbox path.
    static let walletIssuanceEnabled = true

    /// Base URL for the wallet rails when the main backend doesn't carry them
    /// (prod). nil ⇒ use the main backend (local/staging already have the rails).
    static var walletRailBaseURL: URL? {
        if case .sovereign(let baseURL, _, _) = backend, baseURL.host == "api.liviqa.app" {
            return URL(string: "https://liviqa70f58a68-liviqa-backend-sandbox.functions.fnc.fr-par.scw.cloud")!
        }
        return nil
    }

    /// Show a small "Simulation · not yet integrated" label on the wallet login
    /// flows (AltID / e-Boks ID / iGrant.io / DfG) — they are presentation-only and
    /// do not yet talk to a real wallet/verifier. ON for honest testing; flip to
    /// false for a polished investor demo.
    static let showSimulationLabels = true

    /// Liviqa Share Receipt issuance (UC-21) — the citizen mints a provenance
    /// receipt of a share into their My DfG wallet. ON: the issuance rail is proven
    /// on the real Partisia sandbox. Flip to false to hide the action.
    static let dfgReceiptEnabled = true
    /// Universal link / scheme that opens the My DfG wallet with a request.
    /// e.g. "https://wallet.dataforgoodfoundation.org/present" (TBC by Partisia).
    static let dfgWalletRequestBase = "https://wallet.dataforgoodfoundation.org/present"
    /// Where the wallet returns control to Liviqa (must match an Associated Domain
    /// or registered URL scheme + the AASA we host). TBC by Partisia.
    static let dfgWalletReturnURL = "https://www.liviqa.app/wallet/callback"
    /// Our verifier / relying-party client id issued by Partisia (sandbox). TBC.
    static let dfgWalletClientID = "<<FILL_FROM_PARTISIA>>"

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
        baseURL: URL(string: "https://sandbox.liviqa.app")!,   // staging API (NOT prod)
        devToken: nil,
        authURL: supabaseAuthURL                                // single shared GoTrue for now
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
