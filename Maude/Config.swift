// Config.swift — Backend selection + credentials.
//
// MAUDE SHIPS ON-DEVICE: `.mock` in every configuration, meaning no network service.
// The sovereign hosts named below (api.maude.app, auth.maude.app) and the Supabase
// sandbox belong to DATA FOR GOOD and are Liviqa's, not Maude's. They are retained
// so the fork's history stays readable and are reachable only through the
// MAUDE_BACKEND env hook, which a shipped install cannot set. See `backend` below,
// ReleasePosture.swift, PROVENANCE.md and DFG_SEPARATION.md.
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
    static let supabaseAuthURL = URL(string: "https://auth.maude.app")!

    /// EU-sovereign video provider domain (self-hosted Jitsi / Whereby). The
    /// citizen joins `https://<jitsiDomain>/maude-consult-<sessionId>` — the same
    /// deterministic room the console uses. `nil` ⇒ no live media (secure shell).
    /// NFR-SEC-07: must never point at a US-parented provider on the PII path.
    ///
    /// Live value points at the self-hosted Jitsi on Scaleway (fr-par, EU). It is
    /// reachable over a valid public TLS cert and accepts guests (the citizen and
    /// their clinician join the same deterministic room — no account wall).
    /// LOCAL QA may override to the public demo domain with env `MAUDE_JITSI_DEMO=1`.
    static var jitsiDomain: String? {
        if ProcessInfo.processInfo.environment["MAUDE_JITSI_DEMO"] == "1" { return jitsiDemoDomain }
        return jitsiSovereignDomain
    }

    /// Self-hosted, EU-sovereign Jitsi (Scaleway fr-par). Hardening follow-up:
    /// move behind `meet.maude.app` (A record → this host) for a clean URL; the
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
    ///
    /// MAUDE IS ON-DEVICE. Both Debug and Release resolve to `.mock`, which in this
    /// app means "no network service at all": sign-in is satisfied locally and every
    /// surface starts EMPTY and fills only from the user's own HealthKit backfill.
    /// `ColdStartSeeds` already ships empty in Release, so nothing is fabricated.
    ///
    /// WHY THIS CHANGED (2026-09-07). Inherited from Liviqa, Release resolved to
    /// `sovereignProd` — `api.maude.app` and `auth.maude.app`, which are Data for
    /// Good's live sovereign stack carrying other people's health data. Maude is
    /// PPCN's, one user, forked from Liviqa; shipping it pointed there would have
    /// signed a PPCN-branded app into DfG production. That is the merge the fork
    /// exists to prevent (see PROVENANCE.md and DFG_SEPARATION.md), so the default
    /// had to move before any build could be distributed.
    ///
    /// The sovereign cases below are RETAINED, not deleted: they are how Liviqa
    /// works and the fork keeps its history readable. They are reachable only via
    /// the `MAUDE_BACKEND` env hook, which a TestFlight or App Store install cannot
    /// set — so they cannot be reached by a shipped build.
    /// - `MAUDE_BACKEND` env always wins (local QA / e2e), e.g.
    ///   `sovereignLocal|sovereignStaging|sovereignProd|supabaseSandbox|mock`.
    static var backend: Backend {
        switch ProcessInfo.processInfo.environment["MAUDE_BACKEND"] {
        case "sovereignLocal":   return sovereignLocal
        case "sovereignStaging": return sovereignStaging
        case "sovereignProd":    return sovereignProd
        case "supabaseSandbox":  return .supabaseSandbox
        case "mock":             return .mock
        default:
            // On-device in both configurations. Debug additionally seeds synthetic
            // demo data (ColdStartSeeds); Release seeds nothing and starts empty.
            return .mock
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
    /// `~/Desktop/Maude_DfG_Wallet_Demo_Prep_v01_20260609.md`). The shipped app is
    /// unaffected while this is `false`.
    static let dfgWalletEnabled = false

    /// Sign in with Apple needs three things bound to the running bundle: the SIWA
    /// entitlement, the backend/GoTrue token audience, and Apple's team-scoped user
    /// identifiers. Both shipping bundles now satisfy all three — the canonical DfG
    /// build (`xyz.ppcn.maude`) and the temporary PPCN beta (`xyz.ppcn.maude`,
    /// 2026-07-07: SIWA capability registered on the App ID, entitlement in
    /// `Maude.ppcn.entitlements`, and `xyz.ppcn.maude` added to GoTrue's Apple
    /// audience). Caveat on PPCN: Apple's user id is team-scoped, so a sign-in there
    /// links to an existing account only when Apple releases the real email; a
    /// "Hide My Email" relay makes a fresh account. Any *other* bundle → hide the
    /// button rather than show-and-break.
    static let appleSignInBundles: Set<String> = ["xyz.ppcn.maude", "xyz.ppcn.maude"]
    static var appleSignInAvailable: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return appleSignInBundles.contains(id)
    }

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

    /// Path A "Connect Sundhed.dk" — in-app MitID WebView that session-rides the
    /// citizen's OWN sundhed.dk login to pull labs/meds/diagnoses as CODES + summaries.
    /// ENABLED unconditionally (2026-07-09) for the SANCTIONED Trifork / sundhed.dk
    /// self-access test: the citizen signs in with MitID themselves and only coded
    /// summaries cross the JS→Swift boundary. The ReleasePosture precondition that
    /// forced this off in Release has been removed for the duration of the test.
    static let sundhedWebConnectEnabled = true

    /// Path B "Connect Sundhed.dk" — file/PDF import → on-device parse → coded ingest.
    /// Not a simulated/insecure path (real file, real derived codes only), so no
    /// ReleasePosture precondition. ENABLED in Release/TestFlight (2026-07-09): the
    /// POST /ingest/sundhed route is live + verified on api.maude.app. The endpoint
    /// stays flag-gated server-side (SUNDHED_TESTPROD_INGEST) and consent-gated.
    static let sundhedConnectEnabled = true

    /// Wallet credential rails (Maude Citizen issuance, receipts, OID4VP login).
    static let walletIssuanceEnabled = true

    /// Base URL override for the wallet/care rails. TESTPROD (T1, 2026-07-07):
    /// the sandbox-container detour is RETIRED — on Release every rail
    /// (grants, ledger, wallet issuance, care surface) rides the main backend
    /// (`api.maude.app`). nil ⇒ use the main backend. DEBUG-only env override
    /// (`MAUDE_WALLET_RAIL_URL`) kept for local dev against a split backend.
    /// Deploy gating (route parity on api.maude.app) is the owner's step —
    /// this constant just stops the app from hard-coding a sandbox host.
    static var walletRailBaseURL: URL? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["MAUDE_WALLET_RAIL_URL"],
           let url = URL(string: raw) {
            return url
        }
        #endif
        return nil
    }

    /// Show a small "Simulation · not yet integrated" label on the wallet login
    /// flows (AltID / e-Boks ID / iGrant.io / DfG) — they are presentation-only and
    /// do not yet talk to a real wallet/verifier. ON for honest testing; flip to
    /// false for a polished investor demo.
    static let showSimulationLabels = true

    /// Maude Share Receipt issuance (UC-21) — the citizen mints a provenance
    /// receipt of a share into their My DfG wallet. ON: the issuance rail is proven
    /// on the real Partisia sandbox. Flip to false to hide the action.
    static let dfgReceiptEnabled = true
    /// Universal link / scheme that opens the My DfG wallet with a request.
    /// e.g. "https://wallet.dataforgoodfoundation.org/present" (TBC by Partisia).
    static let dfgWalletRequestBase = "https://wallet.dataforgoodfoundation.org/present"
    /// Where the wallet returns control to Maude (must match an Associated Domain
    /// or registered URL scheme + the AASA we host). TBC by Partisia.
    static let dfgWalletReturnURL = "https://www.maude.app/wallet/callback"
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
        baseURL: URL(string: "https://sandbox.maude.app")!,   // staging API (NOT prod)
        devToken: nil,
        authURL: supabaseAuthURL                                // single shared GoTrue for now
    )

    /// Production sovereign backend (TestFlight/App Store default). Canonical hosts
    /// are on `maude.app`: API `api.maude.app`, auth `auth.maude.app`.
    static let sovereignProd: Backend = .sovereign(
        baseURL: URL(string: "https://api.maude.app")!,
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
            return MaudeBackendService(baseURL: url, devToken: token, auth: auth)
        }
    }
}
