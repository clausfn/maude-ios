# Design History File — Index (DHF)

_Append-only dated log of design decisions, linked to the Architecture Decision Register (D1–D10, D-*). Ports to ISO 13485 §7.3. Version: 2026-06-03._

## 2026-06-03 — Auth: revert Ory → Supabase Auth (self-hosted GoTrue, EU) (PR-28)

- **Decision (supersedes the Ory direction).** Ory Network dropped — custom
  domains cost $70/mo, unjustified for the sandbox. Auth = **Supabase Auth
  (GoTrue), self-hosted on Scaleway (EU)**. Rationale doc: `docs/Auth_Supabase_v01.md`
  / backend `docs/Supabase_Auth_Setup_v01.md`.
- **Sovereignty held (NFR-SEC-07).** The load-bearing control is *self-hosted EU
  GoTrue* — **not** Supabase Cloud (US). Self-hosting gives EU residency + $0
  license. Wiring this to Supabase Cloud would breach NFR-SEC-07; recorded in
  RISK as `RK-SEC-RESIDENCY-02`. Founder-approved override of the earlier
  "Supabase = sandbox-only" note, scoped strictly to *self-hosted* GoTrue.
- **Minimal blast radius.** The app was already built on `SupabaseServiceProtocol`;
  only the auth *source* changed. New `SupabaseAuthClient` (GoTrue: password grant,
  native Apple `id_token` grant, `/user`, logout) replaces `OryAuthClient`;
  `LiviqaBackendService` swaps the injected client; `Config` gains
  `supabaseAuthURL` + `.sovereign(authURL:)`. `AppleSignInCoordinator` is
  unchanged — its id_token + raw nonce now feed GoTrue. Access token is
  Keychain-only (`SessionTokenStore`, NFR-SEC-01).
- **Backend already aligned.** `AuthGuard` verifies the Supabase JWT (`jose`,
  HS256 via `SUPABASE_JWT_SECRET` or `SUPABASE_JWKS_URL`), link-by-email; no
  backend change in this PR.
- **Verification:** `SupabaseAuthParsingTests` (T-SBA-01..05) run green in the iOS
  Simulator; app compiles; local e2e uses the dev-token path. Standing up the
  `supabase/gotrue` container + `supabaseAuthURL`/`SUPABASE_JWT_SECRET` is a
  deploy step.

## 2026-06-03 — Open-Meteo weather/AQI context (PR-6)

- **Privacy by construction.** The provider coarsens the coordinate to ~0.1°
  before building any URL, so precise location never leaves the device. The URL
  builders are pure functions and a test asserts the requests contain only
  `latitude`/`longitude`/`current` — proving "no health egress" mechanically.
- **Per-session, not a profile.** Weather is fetched on demand; only the
  environmental values are persisted (`WeatherContext`, provenance EXTERNAL).
  The coarse coordinate itself is not stored.
- **Resilient.** Air quality is best-effort: an AQI failure leaves `aqi == nil`
  rather than failing the whole snapshot. Open-Meteo is keyless and EU-hosted.
- **Verification:** coarsening, URL privacy, and the mock provider were executed
  via `swiftc` this session; the SwiftData entity mapping runs in Xcode.

## 2026-06-03 — Nudge engine + FR-NDG-06 + AFib display-only (PR-5)

- **Allow-list output, not free text.** The engine can only construct one of five
  `NudgeCategory` values; there is no path to author arbitrary clinical claims.
- **FR-NDG-06 as a structural gate, not a lint.** `NudgeGuard` is applied inside
  `NudgeEngine.generate` — a nudge that fails is dropped before it can be returned,
  and `assertionFailure` traps it in debug (the engine must never author one). The
  guard targets affirmative *constructions* so disclaimers ("this is not a
  diagnosis") and canonical units ("6.4 mmol/L") stay clean — verified by running
  the suite, not just reading it.
- **AFib = D9 display-only.** The cardiac lane has exactly one output shape:
  route-to-clinician with an explicit "we don't interpret heart rhythm" line, at
  the highest priority so the cap never hides it. No band, trend, or verdict
  exists for cardiac. This is the top MDR exposure; treating it as display-only is
  the deliberate de-risking choice.
- **Baseline-relative, never clinical-reference.** Bands are ±1σ around the
  user's own history (≥3 points required) — wellness-grade by design. We never
  print "normal/abnormal" (guard rule `clinicalNormality`).
- **Verification:** the whole intelligence layer is pure Foundation, so it was
  compiled and **executed** here via a harness — all guard + engine assertions
  passed. Tests re-run in Xcode.

## 2026-06-03 — HealthKitService (read-only) + L1→L2 persistence (PR-4)

- **Read-only enforced structurally**, not just by policy: `HealthKitService`
  requests authorization with `toShare: []` and exposes no write method
  (FR-ARCH-04). The empty share set is a static property covered by T-HK-RO-01.
- **Glucose canonical at the edge:** HealthKit blood glucose is read directly in
  `mmol/L` (mole unit ÷ litre, OD-07) so no mg/dL ever enters the store.
- **Daily aggregation rule:** cumulative metrics (steps, active energy) are summed
  per day; discrete metrics (HRV-SDNN, resting HR) are averaged per day. HRV + RHR
  merge into a single `HeartDaily` row (the DataModel v1 daily-cardio shape).
- **Idempotent re-sync:** `IngestionCoordinator` replaces all rows in the synced
  window before insert, so repeated syncs converge instead of duplicating.
- **DataModel gap noted:** steps + active energy have no raw entity in v1; they are
  retained on the in-memory `HealthSamples` to feed L3 activity/recovery streams
  (PR-5) rather than inventing an entity outside the locked model.
- **Verification:** `HealthKitService` typechecks against the real HealthKit SDK
  here; the SwiftData-backed coordinator/tests run in Xcode.

## 2026-06-03 — L1 ingestion seam + provenance guard (PR-3)

- **L1 / L2 split formalised.** The provider returns a framework-free
  `HealthSamples` value aggregate (FR-ING-07); L2 maps those readings into the
  SwiftData entities (PR-4). Keeping L1 free of SwiftData/HealthKit makes it
  unit-testable here and portable to Android Health Connect (NFR-PORT-01).
- **Read-only by contract.** `HealthDataProvider` exposes only read-auth + fetch
  — there is deliberately no write/save/upload method to honour (FR-ARCH-04).
  HealthKit's empty write set is enforced in the concrete service (PR-4).
- **MockDataProvider** is the default demo user: deterministic (seeded SplitMix64),
  physiologically plausible, every reading `provenance = .simulated`. This keeps
  the clinical-rejects-SIMULATED gate satisfied end-to-end. `LV001Provider` is a
  real-data stub that stays inert unless `LV001_DEMO` is set — it must never fall
  back to synthetic data (that would mislabel simulated data as real).
- **provenance-never-renders** is now an enforced control, not just a convention:
  a blocking shell guard (`scripts/guard_provenance.sh`, T-PROV-01) fails if the
  word appears in any SwiftUI file, backed by a type-level guard ensuring
  `Provenance` is not `CustomStringConvertible` (T-PROV-02). Ran green this session.
- Verified the entire L1 + core layer by `swiftc -typecheck` in this session
  (no SwiftData macro needed); Swift Testing suites run in Xcode.

## 2026-06-03 — Typed L2 data model (PR-2)

- Implemented the DataModel v1 §2.1 sample sources as 12 SwiftData `@Model`
  entities, each carrying `source` + `tier` + `provenance`. Cross-cutting rules
  (tier, provenance, glucose unit, validation) kept framework-free in
  `CoreTypes.swift` for Android portability (NFR-PORT-01).
- **Clinical rejects SIMULATED** expressed two ways: a throwing schema gate on
  every initializer (the variable-tier path) and a type-level `ClinicalProvenance`
  with no `.simulated` case (the known-clinical path, e.g. `LabResult(clinicalAt:)`).
- **OD-07 applied:** glucose stored in mmol/L; `GlucoseUnit` is the only
  conversion edge. The locked `MetricSnapshot.glucoseMgdl` (journal sync /
  Supabase column) is intentionally left untouched — its migration touches the
  sync schema and is tracked as a later reconciliation.
- **OD-09:** on-device `SwiftData` store, `cloudKitDatabase: .none` (samples
  never sync), file-protection complete. Secure Enclave key-wrapping + AES-256
  verification deferred to PR-7.
- Environment note: this authoring session cannot run the SwiftData macro plugin
  or the iOS Simulator (sandbox blocks the plugin subprocess / CoreSimulator), so
  PR-2 is verified by typechecking the framework-free core and by review; the
  unit tests run in Xcode on the dev machine.

## 2026-06-03 — Repo bootstrap & deployment-agnostic signing (PR-1)

- **Relocated** the locked Phase-1 SwiftUI prototype from the synced
  `09_Liviqa_iOS_Prototype/Liviqa/Liviqa` into the non-synced canonical clone
  `~/Developer/DataForGood/liviqa-ios`, per the Code-Home golden rule
  (git inside synced folders corrupts). Baseline imported verbatim — **no code
  changes** (CARDINAL: iterate, never rebuild). Added DfG `CLAUDE.md` guardrails.
- **Decision D-STORE applied:** signing/identity centralised in
  `Config/Signing.xcconfig` (gitignored) + `Config/Signing.example.xcconfig`
  (checked-in template, empty Team ID). Build settings reference
  `DEVELOPMENT_TEAM` / `PRODUCT_BUNDLE_IDENTIFIER` / `APP_GROUP`; no identity is
  hardcoded in source, Info.plist, entitlements, or the project file. Migrating
  to the Data for Good account later is an xcconfig edit, not a code change.
  Dev posture: personal team `G8MHRNS97R`, bundle `dev.liviqa.app`, automatic
  signing, HealthKit capability enabled. See `docs/SIGNING.md`.
- **HealthKit** capability enabled in entitlements; `NSHealthShareUsageDescription`
  added. Read-only (empty write set) is enforced in code in a later PR
  (`FR-ARCH-04`). No TestFlight/App Store/provisioning assumptions in code.
- **QMS-lite scaffold** created: RTM, DHF, RISK, CHANGELOG, VnV.

Branch model established: `main` (baseline) → `develop` → `feature/*`.
