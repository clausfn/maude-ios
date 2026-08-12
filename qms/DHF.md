# Design History File — Index (DHF)

_Append-only dated log of design decisions, linked to the Architecture Decision Register (D1–D10, D-*). Ports to ISO 13485 §7.3. Version: 2026-06-03._

## 2026-08-12 (evening) — A7.2 screen ANATOMY is in scope, starting with Home (PR-106)

- **Decision (CN, 2026-08-12, on seeing the reskinned build vs the design
  canvas):** the A7.2 package is not a token swap only — the designed screen
  anatomy is the deliverable ("This is the design and the screens I need to
  see"). `screen-home.jsx` and the SCREENS.md v2 canvases are the source of
  truth for screen structure, not just colour.
- **Home rebuilt to the canvas** (PR-106, see CHANGELOG): verdict hero +
  iris day-arc, momentum strip, verdict-first 2×2 signal cards, single
  attention card / quiet all-clear, share card on live grant state, colophon.
  Verdict WORDS lead and numbers follow — the anti-score-opacity stance
  (also the #1 Bevel complaint in the 2026-08-12 study) is now structural.
- **Guarded invariants restated for the anatomy work:** verdict vocabulary is
  a fixed allow-list, baseline-relative, non-diagnostic; ONE attention card
  max; red remains clinical glucose TIR only; provenance never renders.
- **Next screens from the same set:** evening edition (closing note + day
  score ring + 30-day trend + tomorrow hook), InsightCompare, Insights week
  header + grid.

## 2026-08-12 (later) — A7.2 "Electric Ink" adopted as the visual system of record (PR-105)

- **Decision.** A7.2 (round-4 palette of the Claude Design redesign, carrying
  Christel Friis Conrad's review rounds — 52/57 threads resolved by the
  package) supersedes the v03 "Morning Edition" plaster skin. CN approved the
  five gate decisions 2026-08-12: rose heart substitute, amber renewal, TIR
  colour-safety ramp, notifications v1 scope, Bevel absorb list.
- **Two documented deviations from the package** (both a11y/safety-driven):
  heart rose `0xD9486B` instead of red `0xE62E3D` (RK-ALARM-01); `ink4`
  darkened to `0x7E88B0` (package value failed the 3:1 floor).
- **Deferred:** app-icon cobalt GRADIENT ground (solid mid-cobalt shipped;
  gradient via Icon Composer GUI later); screenshot QA against the package
  canvases; the A7.2 canonical register row in 00_Canonical/REGISTER.md.

## 2026-08-12 — Sundhed.dk on-device record wave (PR-104, dated catch-up) + A7 skin record

_Catch-up entry: the decisions below were taken 2026-07-07→2026-08-10 without
contemporaneous DHF entries; recorded after the fact by the 2026-08-12 audit._

- **D-SUND-A (2026-07-09, in code): in-app WKWebView self-access connect,
  superseding the out-of-app posture.** The DataAccess analysis (2026-07-09)
  recommended out-of-app (desktop + extension); the shipped decision is Path A
  in-app — citizen signs in with MitID themselves, an injected interceptor
  captures the SPA's own responses, everything reduces on device. Rationale in
  code: sanctioned Trifork/sundhed.dk self-access test. **Regularisation open:**
  written sanction artifact + DPIA v02 (RK-SUND-01). Path B (PDF import) kept
  as the fallback path.
- **D-REC-01 (2026-07-10): one canonical on-device record store.** Labs,
  conditions and medications from ANY source land in a single source-agnostic
  SwiftData store (per-source dedup/supersession, file-protected, no CloudKit)
  instead of per-feature caches — sharing and research read from one place,
  and the store leaves the device only via the explicit contribution path
  (FR-RSCH-05).
- **D-REC-02 (2026-08-10): diagnoses shown in plain language, tiered.**
  Everyday names + start dates at month precision; major conditions lead,
  minor/admin collapse. Tiering is presentation-only (full list reachable);
  display-only of the citizen's own record — no interpretation (RK-REC-01).
- **D-STORE-P (2026-07-10, `d9f4df6`): file-protection posture.**
  `.completeUntilFirstUserAuthentication` across the store and its WAL/SHM
  siblings; container-open failure = loud + in-memory fallback, made
  user-visible 2026-08-12 (`storeDegraded` banner, PR-104 Phase 0).
- **A7 "Morning/Evening Edition" skin (2026-07-07, `a83e55a`) — recorded.**
  Theme.swift v03 deployed the Claude Design A7 handoff tokens app-wide as a
  SKIN (plaster/fjord palette, Charter serif verdicts, SF Pro body, IBM Plex
  Mono numbers; evening = deep marine) — IA/structure/copy unchanged; the
  structural A7 build-out (33 of 66 handoff screens) is a separate tracked
  effort. Supersedes A6 "Daylight" as the visual system of record; canonical
  A7 register row = open action in `00_Canonical/REGISTER.md`.

## 2026-06-16 — A6 "Daylight" re-skin: six-colour palette, SF Pro, iris .icon, Liquid Glass (PR-96)

- **Goal.** Land the locked A6 "Daylight" brand — a six-colour palette (Punch Red ·
  Honeydew · Frosted Blue · Cerulean · Oxford Navy · Amber Flame), SF Pro + Dynamic
  Type for headline/body (IBM Plex Mono kept for numbers), the brand iris as a
  layered Liquid-Glass app icon + in-app marks, and iOS 26 Liquid Glass on the
  consumer chrome. Successor to **Design System v2 (PR-47)**; extends the prototype,
  no redesign.
- **Theme.** `Theme.swift` recoloured by token value, so every `LiviqaTheme.*` call
  site recolours automatically. Retired fern-green `#31780E` / lime `#4EB818`,
  brown-clay `#BD7A33`, and near-black `#0B1B30`; dark mode = deep navy `#15243D`.
  No green hue in the UI — Cerulean carries consent/in-range.
- **Type.** Headlines/body → system SF Pro (Dynamic-Type friendly); IBM Plex Mono
  retained for numbers/kickers; removed Lato/Schibsted/Instrument/Spline `.ttf`.
- **Mark + icon.** In-app `LiviqaMark`/`Reversed` → Oxford-Navy arcs + brand green
  ring. App icon is now a hand-authored layered **`AppIcon.icon`** (Icon Composer
  format) — navy ground + honeydew halo + green iris ring/dot, lifted by the system
  on iOS 26, flattened on iOS 17–25. Mark geometry unchanged (never redrawn).
- **Liquid Glass.** Floating `.ultraThinMaterial` tab-bar capsule + glass sheets,
  each with an **opaque solid fallback** under Reduce Transparency / Increase
  Contrast (one shared a11y flag). Today glass *cards* were tried and reverted (no
  benefit over the flat canvas); Today's large-title-condense was deferred (would
  move the locked wordmark = redesign).
- **SAFETY — attention tone reverted to amber (RK-ALARM-01, accepted).** A6 moves
  the "worth a look" attention tone from clay **back to Amber Flame**, re-assessing
  RK-ALARM-01 (see `qms/RISK.md`, PR-96). Flagged to the owner; **CN accepted Amber
  Flame on 2026-06-16** as the patient attention tone — the PR-47 "clay over amber"
  decision is superseded, on the basis that amber is used as fill/dot + navy text
  (never alarm text) and colour is never the sole signal (label + position carry the
  "notice", not "alarm", meaning). Recorded so the decision is conscious, not silent.
- **Design-system source.** The brand kit (`design-system/` — tokens, templates,
  iris/icon art) is now tracked in-repo (`new design`, `33a167d`).
- **Verified.** Build green per commit; full suite **130 unit + 2 UI tests, 0
  failures** (incl. blocking `T-NDG-06*` / `T-PROV-01` guards); Paper + Midnight +
  Increase-Contrast checked on the Simulator. Merged to `develop` (GitHub PR #1 →
  merge `32f4b33`).

## 2026-06-09 — DfG wallet (My DfG) integration — scaffold (feature-flagged OFF)

- **Goal.** Prepare a live Liviqa → My DfG wallet consent demo (eIDAS 2.0 /
  verifiable credentials) for Folkemøde, pending Partisia sandbox credentials.
- **Scaffold (inert while `Config.dfgWalletEnabled == false`).** `Config` gains
  wallet placeholders (request base, return URL, client id — all TBC from Partisia).
  `Services/DfGWalletService.swift`: builds the presentation-request URL, opens
  My DfG (`UIApplication.open`), `isCallback`/`handleReturn` parse the wallet's
  return (vp_token), with `DfGWalletConsentButton` (hidden unless enabled). Protocol
  payload (OpenID4VP) and presentation verification are TODO(Partisia).
- **Website piece.** Staged AASA + README at
  `10_Website/liviqa-web/_dfg-wallet-wellknown/` — `apple-app-site-association` so
  iOS opens My DfG from a request link ("Apple connects to the right wallet"), to be
  finalised with Partisia's My DfG AppID and moved into `.well-known/`.
- **Prep runbook:** `~/Desktop/Liviqa_DfG_Wallet_Demo_Prep_v01_20260609.md`. Critical
  path = Partisia credentials (email to Kim). Shipped app unaffected until enabled.

## 2026-06-09 — TestFlight cleanup: 10.15 as the single canonical build

- **Goal.** Only the latest build (10.15) available to testers; retire the rest.
- **Action (via `scripts/asc_cleanup_builds.py`, ASC API).** Expired 11 legacy
  builds (v1, v2, 10.5–10.14). Attached 10.15 to the external "Liviqa beta tester"
  group and **submitted it for Beta App Review** so it can reach the public link
  (`testflight.apple.com/join/hdXVzcSF`).
- **TestFlight constraint recorded.** Internal groups always expose *every* non-
  expired build — a build can only be hidden from internal testers by expiring it.
  External/public-link builds require Beta App Review.
- **Completed same session.** 10.15 was already APPROVED for external (the app's
  prior external approval carried to the update), so `watch-finish` expired
  10.2/10.3/10.4 immediately. **End state: 10.15 is the only non-expired build,
  live on both Internal DfG and the public link; all 14 older builds expired.**
- **No hard force-update exists** beyond expiring old builds (+ the app's
  onboarding-version replay gate). Expired builds can't be launched; TestFlight
  steers testers to the newest available build.

## 2026-06-09 — In-app incoming instant call + consent-first join (10.15)

- **What.** A clinician can start an instant secure consultation from the console
  ("Call now" on a panel patient / Start consultation); the citizen's app now
  surfaces a full-screen **incoming-call** overlay (`Views/IncomingCallView.swift`)
  and, on Join, drops into the existing `ConsultView` (sovereign Jitsi room).
- **Decision — joining IS the consent (consent-first).** The overlay states, before
  any connection: data stays on device, the clinician sees only what was consented,
  and **recording stays off unless separately allowed in-call**. Declining dismisses;
  there is no auto-answer. This keeps the call inside the same granular-consent
  posture as every other share (`FR-CONSENT-*`), rather than treating a call as a
  privileged channel.
- **How (no push infra yet).** `AppState.pollIncomingCall()` polls active consults
  on an 8 s loop from `MainTabView.task`; the first *new* consult id raises
  `incomingConsult`. `dismissIncoming()` marks it seen so it cannot re-fire. A real
  APNs push replaces the poll later — logged as follow-up, not a blocker.
- **Surface.** Always-dark call chrome (`#0C1520`) regardless of theme; avatar pulse;
  Decline (rust) / Join (moss). Camera/mic usage strings already present in Info.plist.
- **Verification.** Xcode `BUILD SUCCEEDED`; archived + uploaded via the isolated-
  keychain path (`scripts/archive_upload_isolated.sh`), Delivery UUID
  `9afca9b8-c48b-43a2-a4f4-aed64bef96b7`. Pairs with the console instant-call /
  worklist / presence work (see `liviqa-b2b-console/CHANGELOG.md`).

## 2026-06-09 — Design System v2 foundation: Paper default + clay attention tone (PR-47)

- **Source.** A `claude.ai/design` handoff bundle (in `_liviqa_design_reference/`,
  outside the repo). Read the chat transcript for intent: the thesis is
  *comprehension → insight → behaviour change*, "not population averages — yours",
  with always-on evidence metadata (N · baseline · r · p + a "still learning" gate).
  Keeps the locked brand (aperture mark, Lato, ink/moss). Locked screen directions:
  Correlation C, Home C, Baseline Aperture-arc, Week heatmap, Consent A, Privacy
  one-tap pause, Journal quick-capture, 5-tab IA.
- **The foundation already matched.** `Theme.swift` is built from the same
  `Liviqa_Design_Tokens_v01` source as the design's `colors.css`; the palette,
  Lato, and IBM Plex Mono were already in place. So v2 is a small token *delta*,
  not a recolor.
- **Decision — clay over amber (the keystone, founder-confirmed in design chat).**
  The single patient "worth noticing" tone is **clay `#BD7A33`** (tuned candidate 4),
  *not* amber. Amber reads as a warning light — wrong for an app below the
  medical-device line whose voice is never diagnostic. Patient app = two calm
  states (moss = in-range, clay = notice); the saturated green/amber/red triage
  ramp is the *console's* logic, deliberately not shared. Recorded as a risk
  control (`RK-ALARM-01`, RISK.md) because it bears on `FR-REG-02`.
- **Decision — default to Paper.** The design is light/paper-first; the app default
  flips Midnight → Paper. Midnight stays user-selectable; the dynamic tokens flip
  the whole app via one root `preferredColorScheme`, so no per-view change.
- **Applied as a token sweep.** `amber → clay` across `Liviqa/Views/*.swift`
  (the amber token is retained for engine/console). Added the confidence ramp and
  the semantic type scale (with the design's exact tracking).
- **Verification.** I cannot have Claus build (Xcode signing/destination issues on
  his side), so I build + screenshot myself: `xcodebuild` (iOS Sim) BUILD
  SUCCEEDED, LiviqaTests 78/78 green, Today screen screenshotted in both Paper and
  Midnight — the glucose arc now reads moss → clay. Screens (Today hero,
  Correlation, Baseline arc, Week, sovereignty set) are the next, screenshot-
  reviewed phase. The 5-tab IA rename and any new insulin/AFib nudge copy are
  **held for Claus** (structural / RQ-01 counsel).

## 2026-06-09 — Full HealthKit capture (Step A) + auth wiring + ingestion fixes (PR-46)

- **Decision — capture everything HealthKit holds.** Founder direction ("I want
  all… everything"): the data model (`Entities.swift`) already had the entities, so
  ingestion was widened to populate them — insulin, AFib burden, blood pressure,
  body composition, and the full heart/respiratory panel — alongside the original
  MVP set. Rationale: the founder's real CGM (via Zukka→HealthKit) and insulin (via
  mySugr→HealthKit) already live in Apple Health, so the demo/real data flows by
  *reading*, not by bundling PII or file import. Labs and the medication list are
  **not** in HealthKit and remain a separate file-import path (sundhed.dk/InBody).
- **Boundary held at the data layer.** Reading insulin/AFib does not cross the
  device line: insulin stays dose-blind (`FR-REG-04`), AFib display-only
  (`OD-11`/`D9`); see RISK.md PR-46/47. Rendering the new signals is Step B and
  gated by the `FR-NDG-06` guard + the RQ-01 decision.
- **Read-only preserved.** The wider read set is authorization-only; the share/
  write set stays empty (`FR-ARCH-04`).
- **Onboarding auth wired.** The HealthKit primer "Connect" now actually requests
  authorization and switches the provider to `.healthKit` (was a no-op that left
  the app on demo data).
- **Idempotency hardened.** `IngestionCoordinator`'s window-replace now deletes the
  union of the requested window and the inserted rows' span, so a boundary sample
  just outside the window is not re-inserted each sync. Fixes a pre-existing
  `reSyncIsIdempotent` failure with no data dropped.
- **Verification.** `xcodebuild` (iOS Sim) BUILD SUCCEEDED; LiviqaTests **78/78
  green**; a baseline git-stash run confirmed Step A introduced zero new
  regressions (the only two reds were pre-existing and are now fixed). Real-device
  sanity items flagged to Claus: SpO₂/body-fat %-scaling and the VO₂max unit
  string, which compile but want a glance against live values.

## 2026-06-03 — TestFlight prep: live-data Release + App Store gaps (PR-30)

- **Goal:** first TestFlight under the Data for Good team (`PS258XSNL8`), feeding
  live data through the sovereign backend + Supabase GoTrue. Gap analysis:
  `docs/TestFlight_Readiness_v01.md`.
- **Decisions (locked):** bundle `app.liviqa.ios` (the personal team holds
  `dev.liviqa.app`; bundle ids are globally unique); canonical hosts on
  `liviqa.app`; **video consult gated off** in v1 (no EU Jitsi yet → avoids
  camera/mic + NFR-SEC-07 exposure); external testers on **synthetic data only**.
- **Live by build config, not hardcoding.** `Config.backend` returns
  `sovereignProd` in Release/TestFlight and `.mock` in Debug, with an env override
  for QA. This makes the shipped build "just use live data" while keeping local
  dev synthetic — cleaner than literal hardcoding and reversible.
- **App Store gates closed headlessly:** privacy manifest (`PrivacyInfo.xcprivacy`),
  export-compliance (`ITSAppUsesNonExemptEncryption=false`), intended-use
  statement (FR-QMS-01), DfG team + bundle in the gitignored `Signing.xcconfig`.
- **Deliberately deferred to you (needs Apple login):** DfG Apple Distribution
  cert (this Mac's Keychain has only the personal identity), App ID + App Group
  registration, App Store Connect record + privacy nutrition labels, archive +
  upload. Signing identity is the one true blocker for the upload itself.
- **Verification:** simulator build succeeds; privacy manifest is bundled; bundle
  id resolves to `app.liviqa.ios`.

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
