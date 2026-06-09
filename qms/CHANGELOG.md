# QMS Change Log

_One entry per release/PR that touches a requirement or risk control. Maps to git tags. Conventional Commits. Version: 2026-06-03._

## [Unreleased] — develop

### PR-46 — Wellness-scope AI assistant (non-MDSW) + deterministic guard (2026-06-09)
- **feat(chat):** `Liviqa/Chat/LiviqaChat.swift` — wellness-scope assistant: fixed
  copy (intended purpose / static safety line / AI label / system prompt),
  **deterministic `ChatGuard`** (input refusal + output sanitise; blocks prediction/
  prognosis/diagnosis/symptom/triage/treatment → safety line; strips imperatives +
  sexual-function meds), `LocalDataResponder` (descriptive-only, on-device), `ChatEngine`
  (guard-first/guard-last). Compliance authority: counsel memo (06_Regulatory).
- **feat(ui):** `ChatView.swift` — standalone consent (3 toggles, defaults off,
  withdrawable; cloud + research wired-but-disabled), persistent AI label, descriptive
  chat. In-memory history only (no persistence); withdrawal purges + resets consent.
  Entry = one row in ProfileSheet (brand/chrome/nav unchanged).
- **test(chat):** `LiviqaTests/ChatGuardTests` — 10 acceptance tests green (red-team
  prompts → safety line; descriptive answered; drift blocked; meds stripped; copy clean).
- **build:** on-device default; cloud "Enhanced" mode NOT built. No real LLM yet
  (deterministic). Open decision (LLM/cloud) flagged to DfG Works. See
  docs/AIChat_BuildNote_v01.md.
- Verified: builds (iOS Sim); consent + chat screenshots on Midnight.


### PR-52 — TestFlight 1.0(10.11–10.12) — beta-feedback UI fixes + Midnight contrast sweep (2026-06-09)
- **fix(ui) [beta feedback]:** read the 4 TestFlight `betaFeedbackScreenshotSubmissions`
  via the ASC API and fixed each (tester on Midnight/dark theme):
  - **DfG Tokens (`TokenWalletView`):** the cost pills + In-app/Charity toggle used
    `LiviqaTheme.ink` (a TEXT colour, light in Midnight) as a *background* with white
    text → white-on-cream, unreadable. Swapped to `invertBG`/`invertFG`. Balance card
    now shows the **DfG logo** (`dfg-logo`/`dfg-logo-negative`), not the Liviqa mark.
  - **`ConsultView` secure shell:** `fill(ink)` + white text → fixed always-dark
    video stage (`#0C1520`); avatar tint to a light overlay.
  - **`AreaTrendChart` (TIR graphic):** gradient area fill boosted 0.45/0.06 → 0.55/0.10
    so it reads on dark (the "graphic does not work" report was an older build w/o fill).
- **fix(ui) [NFR-UI contrast]:** swept ALL views for the Midnight trap — `ink`/`paper`
  used as a surface, hardcoded white surfaces, flipped-text. Zero offenders remain;
  verified Midnight Home renders clean.
- **fix(settings):** theme-picker `@AppStorage` default was `.midnight` while the app
  defaults to `.paper` → picker showed the wrong selection on fresh install. Aligned to
  `.paper`. Stale "video off" comment in `MessagesView` corrected (video is on).
- **build(release):** 10.10 → **10.11** (feedback) → **10.12** (settings/contrast), via
  the new `scripts/archive_upload_isolated.sh` (headless build through an isolated
  keychain — sidesteps the locked login keychain that hung codesign; restores the
  search list on exit, no login-keychain changes, no lost passwords).

### PR-51 — Console GoTrue login + onboarding-reinstate + live Home data (2026-06-09)
- **feat(console) [sandbox.liviqa.app]:** real GoTrue login replacing the rejected
  `dev-*` bearer tokens — role buttons authenticate per seeded account (link-by-email),
  no `DEV_AUTH`, no dev token in the bundle. Reset the 4 role passwords via the GoTrue
  admin API. In-app persona switcher removed (role from the account); Sign out → /login.
- **feat(ios) [start flow]:** onboarding-version gate replays the consent/start flow once
  (it had stopped appearing because the `hasSeen*` flags persisted) + re-prompts HealthKit.
- **feat(ios) [own data]:** Home signal chips + insight hero now driven by live HealthKit
  (`TodaySignalsDeriver`); Data Sources gained Connect-Health-&-sync + Import-a-file.
- **infra:** self-hosted Jitsi white-labelled to "Liviqa" (watermark off, runtime patch).

### PR-50 — TestFlight build 1.0(10.9) — Design System v2 screen build-out (2026-06-09)
- **feat(ui) [NFR-UI-*]:** built the remaining v2 screens from the locked design
  explorations (`_liviqa_design_reference/.../explorations/`), reusing the v2 token
  layer — no brand/logo/palette changes (iterate-on-locked rule):
  - **Correlation moment** (`NudgeDetailView`) → Alternative C: plain declarative
    sentence → one confirm chart → always-on evidence metadata (N·baseline·r·p) →
    named lever → "see the data" depth tier. **Still-learning state** (refuse to
    assert below the gate r≥0.4/p≤0.05/N≥need) implemented — the trust mechanism.
  - **Evidence components** (`EvidenceComponents.swift`): `ConfidenceChip`
    (gated/emerging/learning), `EvidenceMetadataRow`, `LeverCallout`,
    `SingleConfirmBar`, `BaselineProgressBar`, `NavBackHeader`, `FlowRow`.
  - **Baseline** → the **Aperture-arc gauge** (`ApertureArcGauge` + `MetricBaselineView`):
    open ring, moss arc = your normal band, today's dot on it, **never a 0–100
    percentile**; reachable from the passport wellness rows. Clay when it drifts.
  - **Week** (`WeekInContextView`) → two-state heatmap (moss in-range / clay worth-
    noticing) with the lit **cluster column** highlighted + named.
  - **Journal** → tap-first **quick-capture** grid (mood/meal/symptom/voice/upload)
    + context suggestions + mood sheet; every entry marked "🔒 on device" (the v1
    emotional-load fix: lead with actions, not a blank prompt).
  - **Consent history** (`ConsentLedgerView`) → Alternative A plain-language
    timeline with pins + "✓ verified" + "Technical details ›".
  - **Privacy** (`InAppPrivacyView`) → "circle of trust": nothing shared by default,
    per-recipient grant cards, **one-tap pause with an immediate receipt** (shows
    its work, not a spinner). Legal/MDR prose moved below the fold.
- **feat(model):** additive `NudgeEvidence` on `Nudge` (confidence, N, baseline,
  r, p, lever, chart, still-learning) — populated on demo nudges to exercise all
  three confidence states. Non-breaking (defaults nil).
- **chore(reg) [FR-REG-03]:** genericised the nudge share copy (no condition /
  recipient hard-coding). Kept current tab IA (Today·Trends·Wallet·Care·Journal) —
  the 5-tab rename stays HELD for Claus (and Care is needed for video). No new
  insulin/AFib nudge copy (RQ-01 still open).
- **build(release):** `CURRENT_PROJECT_VERSION` 10.8 → **10.9**. Today screen
  verified on the simulator (Paper ground, Home-C hero); all screens compile clean
  (sim build SUCCEEDED). Ships video (PR-49) + this build-out together.

### PR-49 — TestFlight build 1.0(10.8) — sovereign video consult ON (2026-06-09)
- **feat(consult) [NFR-SEC-07 SATISFIED]:** live video for the Care/consult flow,
  on a **self-hosted EU Jitsi** (Scaleway fr-par; instance `liviqa-jitsi`, public
  `163.172.173.186` → `163-172-173-186.sslip.io`, docker-jitsi-meet stable-9646,
  Let's Encrypt/ZeroSSL TLS, `ENABLE_AUTH=0`/`ENABLE_GUESTS=1`, `JVB_ADVERTISE_IPS`
  set). Verified live: web 200 over valid TLS, prosody ws + BOSH 200, arbitrary
  rooms serve. This closes the NFR-SEC-07 control that barred a US-parented video
  provider on the PII path — no `meet.jit.si`, EU-sovereign self-host instead.
  (Sovereignty rule consciously waived for Jitsi-the-OSS this session; we still
  self-hosted in-EU rather than using a US public instance.)
- **feat(consult):** `Config.videoConsultEnabled = true`; `Config.jitsiDomain` →
  new `jitsiSovereignDomain`. `Info.plist` gained `NSCameraUsageDescription` +
  `NSMicrophoneUsageDescription`. `ConsultView` `WKWebView` grants getUserMedia
  (WKUIDelegate `requestMediaCapturePermissionFor` → `.grant`) and pins
  `#config.disableDeepLinking=true&prejoinPageEnabled=false` so the call stays
  in-app. Deterministic room `liviqa-consult-<id>` unchanged.
- **feat(console):** B2B console `VITE_JITSI_DOMAIN` repointed meet.jit.si → the
  sovereign host; rebuilt + redeployed to `sandbox.liviqa.app` (rclone sync + Edge
  purge). Citizen + clinician now land in the same room on the same EU server.
- **build(release):** `CURRENT_PROJECT_VERSION` 10.7 → **10.8**; archived + uploaded
  headlessly (API key `656L9P8JY3`, issuer `830c96d2…`). Upload UUID
  `a76b4e78-7853-44d2-baf8-72dd4de4ec0e`. Compiles clean (sim build SUCCEEDED).
- **Hardening (open):** move behind `meet.liviqa.app` (A record), lock SG to
  80/443/4443/UDP-10000, decide recording storage/retention before prod recording.

### PR-48 — TestFlight build 1.0(10.5) — HealthKit-connect pilot (2026-06-09)
- **build(release):** `CURRENT_PROJECT_VERSION` 10.4 → **10.5**; archived + uploaded
  to TestFlight **headlessly** via `scripts/archive_upload.sh` + the App Store
  Connect API key (`656L9P8JY3`) — `xcodebuild -allowProvisioningUpdates` minted
  the Apple **Distribution** cert + App Store profile under the DfG account
  (PS258XSNL8), bundle `dev.liviqa.app`. `Config/ExportOptions.plist` team confirmed
  PS258XSNL8. Upload UUID `e7732e90-7101-422d-8a82-1ae01ae57fd1`.
- **Ships:** PR-46 full HealthKit capture + Connect→authorize wiring + PR-47 Paper/
  clay. Release config = `sovereignProd` (api.liviqa.app, health 200), `authEnabled
  = false` (demo sign-in), video gated off.
- **Tester scope:** connect HealthKit → real on-device data renders (the pilot
  goal). **Backend derived-share upload needs auth** (`authEnabled`/GoTrue JWT —
  ClickUp Sprint-0 P0); demo mode has no sovereign session, so the push is a no-op.
  A follow-up build flips auth once GoTrue is verified end-to-end.
- Verified: ARCHIVE/EXPORT/UPLOAD all succeeded; build processing in App Store Connect.

### PR-47 — Design System v2 foundation: Paper default + clay attention tone (2026-06-09)
- **feat(theme):** added the Design System v2 signal tokens to `Liviqa/Theme.swift` —
  `clay`/`clay2`/`clay3`/`clayText`/`clayRev` (the single patient "worth noticing"
  attention tone, `#BD7A33`), the confidence ramp (`confHigh`/`confEmerging`/
  `confLearning`), the semantic type scale (`liviqaH1/H2/Body/Caption`) and
  `LiviqaTheme.Tracking`. Base palette already matched the design's `colors.css`
  (same `Liviqa_Design_Tokens_v01` source); Lato + IBM Plex Mono already bundled.
- **feat(theme) [NFR-UI-CLAY-01 / FR-REG-02]:** swept the patient view layer from
  `LiviqaTheme.amber` → `LiviqaTheme.clay` (`amber2`→`clay2`) across
  `Liviqa/Views/*.swift`. Rationale: amber reads as a warning light; the app is
  pitched below the medical-device line with a never-diagnostic voice, so the
  attention tone must NOT be an alarm. Two-state patient logic: moss = in-range,
  clay = worth-noticing. (Amber token retained for engine/console use.) This is a
  regulatory-relevant choice — clay avoids threshold/alarm framing (FR-REG-02).
- **feat(theme) [NFR-UI-THEME-01]:** default theme flipped Midnight → **Paper**
  (`LiviqaApp.themeModeRaw`), the design ground. Midnight still selectable in
  Settings; dynamic tokens flip the whole app via the single root scheme.
- Source: `claude.ai/design` handoff bundle (`_liviqa_design_reference/`), chat
  intent + locked screen directions (Correlation C, Home C, Baseline arc, Week
  heatmap, Consent A, Privacy one-tap, Journal quick-capture, 5-tab IA).
- Verified: `xcodebuild` (iOS Sim) BUILD SUCCEEDED; LiviqaTests 78/78 green;
  Today screen screenshotted in Paper + Midnight — glucose arc now moss→clay.

### PR-46 — Full HealthKit capture (Step A) + auth wiring + ingestion fixes (2026-06-09)
- **feat(ingestion) [FR-ING-01]:** expanded the HealthKit read set from the 7-type
  MVP set to the full capture set — added insulin delivery, AFib burden, blood
  pressure (sys/dia correlation), body composition (mass/fat%/lean/BMI), and the
  extended heart/respiratory panel (heart rate, walking HR, HR-recovery,
  respiratory rate, SpO₂, VO₂max). New value types + readers in
  `HealthSamples.swift` / `HealthKitService.swift`; arbitration extended
  (`SourceArbiter`); persisted into the existing `@Model` entities + idempotent
  replace helpers (`IngestionCoordinator`). Still **read-only** — share/write set
  stays empty (FR-ARCH-04). Identifiers bound via `if let` so unsupported types
  are skipped, not compile errors.
- **fix(onboarding) [FR-ING-01/02]:** the HealthKit primer "Connect" now actually
  requests read authorization + switches off demo data (`AppState.dataProviderKind
  = .healthKit` + `refreshFromHealth()`); skip stays on demo (never an error state).
  Previously the button only set the seen-flag → live ingestion never triggered.
- **fix(ingestion) [FR-ING-09, T-MAP-02]:** re-sync idempotency — the window-replace
  delete now covers the union of the requested window and the inserted rows' span,
  so a daily/boundary sample whose timestamp falls just outside the window is no
  longer re-inserted on every sync (was: 48 glucose rows where 42 expected). Fixes
  a pre-existing `reSyncIsIdempotent` failure. No data dropped.
- **fix(test):** `NudgeEngineTests` fixture gave the baseline HRV zero variance
  (constant 55) — always in-band by design (see `baselineBands`), so the low day
  never fired the recovery nudge. Gave the baseline realistic variance. Pre-existing
  failure, now green.
- **test(healthkit):** `readSetIsMvpReadSet` → `readSetIsFullCaptureSet` — asserts
  the MVP types + the new capture types are present and the set is ≥20.
- Regulatory posture unchanged at the data layer: **insulin stays dose-blind**
  (`FR-REG-04`, InsulinDose data-source only, no surface), **AFib stays
  display-only** (`OD-11`/D9), new readings are `provenance = .real`, tier
  good/estimate (never clinical). Rendering/nudging of the new signals = Step B.
- Verified: `xcodebuild` (iOS Sim) BUILD SUCCEEDED; LiviqaTests **78/78 green**
  (2 pre-existing failures fixed); baseline-stash confirmed Step A added zero new
  regressions.

### PR-45 — Demo-first TestFlight build for UI testing (auth gated) + 1.0(10.4) (2026-06-04)
- **feat(config):** `Config.authEnabled` (default **false**). While false the auth
  screen hides the live Apple + email sign-in and shows a single **"Enter Liviqa"**
  (demo) entry — TestFlight UI testers never hit a broken sign-in (GoTrue secret
  not yet verified end-to-end; Apple provider disabled; GoTrue signup disabled).
- Rationale: UI testing must not depend on the backend/auth layer. Demo mode
  renders all 5 screens with deterministic synthetic data. Flip `authEnabled` true
  once `SUPABASE_JWT_SECRET == GOTRUE_JWT_SECRET` is confirmed + Apple enabled
  (see docs/Auth_Deploy_Handoff_v01.md).
- **build(release):** `CURRENT_PROJECT_VERSION` 10.3 → **10.4**.
- Verified: builds (iOS Sim); auth screen shows white aperture logo + lone
  "Enter Liviqa" on Midnight.

### PR-44 — TestFlight feedback fixes: secondary-screen Midnight contrast (2026-06-04)
- Source: 3 TestFlight beta-feedback items on build 1.0(10.2) (iPhone 16, iOS 26.6).
- **fix(ui) [fb3 "Check Color on buttons"]:** `NudgePrimaryButtonStyle` used
  `LiviqaTheme.ink` as a surface + white text → cream-on-cream (invisible) on
  Midnight. Now invert tokens. Affected "Open"/"Show pattern" nudge CTAs.
- **fix(ui) [fb2 "Same"]:** `NudgeDetailView` had a hardcoded `Color.white` card
  (pale text unreadable on Midnight) + a dark-green RGB body/stroke on the share
  card. Now `paper2`/`ink2`/`moss3` tokens; flat `ChartPlaceholder` replaced with
  the gradient `AreaTrendChart`.
- **fix(ui) [fb1 "Graphic for Time in range does not work"]:** `AreaTrendChart`
  fill was nearly invisible on Midnight (moss .30 over dark). Strengthened
  gradient (.45→.06) + added baseline gridlines so it reads as a chart.
- **fix(ui) sweep (same root cause, reachable secondary screens):**
  PrivacyDeclaration "Understood" + DfGOnboarding "Got it" buttons, ProfileSheet
  count badge, and the TokenWallet balance card — all `ink`-as-surface+white →
  invert tokens. TokenWallet's code-drawn `apertureMini` (brand-rule violation)
  replaced with the locked `LiviqaApertureMark` asset (theme-aware variant).
- ConsultView shell left as-is (behind disabled `videoConsultEnabled` flag, v1).
- Verified: builds (iOS Sim); Trends TIR chart screenshot shows visible fill+grid.

### PR-43 — TestFlight build 1.0(10.2) + ASC attach helper (2026-06-04)
- **build(release):** `CURRENT_PROJECT_VERSION` 2 → **10.2** (MARKETING_VERSION
  unchanged at 1.0) — updates the existing **1.0 internal test train**
  (TestFlight shows `1.0 (10.2)`). Archived → exported → uploaded (altool:
  *UPLOAD SUCCEEDED*, Delivery UUID `f6667962-…`).
- **chore(ci):** `scripts/asc_attach_build.py` — stdlib-only App Store Connect
  client (ES256 JWT signed via openssl, DER→raw conversion) that polls a build's
  `processingState` until VALID and reports group assignment.
- **verified:** build reached **VALID**; export compliance pre-answered
  (`ITSAppUsesNonExemptEncryption=false` → API `usesNonExemptEncryption:false`);
  not expired. Internal **Internal DfG** group auto-distributes processed builds
  (API confirms internal groups can't be manually assigned: 422
  `ENTITY_UNPROCESSABLE`), so 1.0(10.2) is live for internal testers.
- No requirement/risk-control change; release-engineering only.

### PR-42 — Oura redesign #8: theme-aware aperture logo (white ring on Midnight) (2026-06-04)
- **fix(brand):** `LiviqaApertureMark` now auto-selects the asset variant from
  `colorScheme` — **reversed** (white `#F7F5F1` ring, the locked dark-bg brand
  mark) on Midnight, **primary** (ink ring) on Paper. `reversed:` is now an
  optional override, kept only for the Wallet watermark on an invert surface.
- **fix(ui):** app bar / AuthView / PrivacyDeclaration / Care empty-state marks
  switched from forced `reversed: false`/`true` to auto → the logo was invisible
  (dark mark on dark) and read like a faint spinner on Midnight; now visible.
- Locked aperture **asset unchanged** (no code redraw, brand cardinal rule); no
  rotation on the mark (the only `rotationEffect`s are chart ring trims).
- Verified: builds (iOS Sim); Today app-bar logo renders the white ring on Midnight.

### PR-41 — Oura redesign #7: runtime Display options + demo-chip default-off (2026-06-04)
- **feat(ui):** SettingsView **DISPLAY** zone — Theme segmented (Midnight/Paper →
  `liviqaThemeMode`, drives root tokens), Reduce-motion toggle (`liviqaReduceMotion`,
  read by `LiviqaMotion`), Demo-data-chip toggle (`liviqaShowDemoChip`). All three
  are real (no dead toggles); each writes `@AppStorage` consumed by live code.
- **fix(brand):** `liviqaShowDemoChip` **defaults OFF** — the "Demo data" chip is a
  forbidden `demo` label on customer-facing UI (CLAUDE.md cardinal rule); hidden by
  default, toggle retained for the real-vs-cohort integrity marker (FR-ARCH-05).
- **fix(ui):** profile avatar (Settings) + tab-bar avatar use invert tokens (were
  `ink`+white → invisible on Midnight).
- Verified: builds (iOS Sim); Paper/Midnight switch confirmed end-to-end; Today
  renders with no provenance label by default.

### PR-40 — Oura redesign #6: Journal Midnight contrast (2026-06-04)
- **fix(ui):** JournalView selected calendar-day pill, active filter chip, and FAB
  used `LiviqaTheme.ink` as a *surface* + white text → invisible on Midnight.
  Switched to invert-surface tokens. No copy/data-model change.
- Verified: builds (iOS Sim); calendar/filter/FAB all legible on Midnight + Paper.

### PR-39 — Oura redesign #5: Care surface + demo threads (2026-06-04)
- **feat(ui):** demo care-team threads (`MockData.demoCareThreads` — Nurse/Coach/GP)
  seeded into demo sign-in so the Care tab shows content; `MessageThreadView` demo
  message fallback + local send when no live backend.
- **fix(ui):** thread-row avatar invert tokens (was invisible on Midnight); richer
  empty-state card (aperture + headline) when genuinely unconnected.
- Verified: builds (iOS Sim); Care list + avatars legible on Midnight.

### PR-38 — Oura redesign #4: Wallet invert summary + CE toast (2026-06-04)
- **feat(ui):** Wallet summary card now an **invert surface** (was `ink`+white →
  invisible on Midnight); watermark aperture mark theme-aware; replaced bespoke CE
  toast with shared `LiviqaToastData` + `.liviqaToast` (withdraw → rust dot).
- Verified: builds (iOS Sim); summary card + watermark + "LV" avatar legible.

### PR-37 — Oura redesign #3: Trends (gradient trend + interactive grid) (2026-06-04)
- **feat(ui):** `AreaTrendChart` (generic gradient-area line + draw-in) in
  OuraComponents. WeekInContextView: TIR trend hero; 7-day grid cells now tappable
  → **day-readout** with StatusPill; theme-aware level fills (model `.color` was
  light-only hex); row/col highlight + selection ring.
- **feat(dev):** `LIVIQA_TAB` env (DEBUG) to deep-link the initial tab for snapshots.
- **fix(ui):** tab-bar/Today avatar contrast on Midnight (invert tokens).
- Verified: builds (iOS Sim); Trends renders gradient chart + interactive grid.

### PR-36 — Oura redesign #2b: Today screen wired (2026-06-04)
- **feat(ui):** TodayView radial **glucose hero** (RingView 68% TIR + glow + mono
  6.2 mmol/L + In-range StatusPill + GlucoseCurveView + stat row) and **mini-ring
  vitals** (Sleep/HRV/Steps), replacing the old flat rings row. Copy/data unchanged.
- **chore:** demo profile name → `LV001` (no real names, per task); DEBUG
  `-uiTestAutoDemo` launch hook for headless snapshotting.
- Verified: builds (iOS Sim); Today renders the Oura hero on Midnight + Paper.

### PR-35 — Oura redesign #2: shared ring/curve/toast components (2026-06-04)
- **feat(ui):** `OuraComponents.swift` — `RingView` (gradient moss→amber arc +
  glow + draw-in, resting state = full arc, Reduce-Motion-gated via system flag
  OR in-app `liviqaReduceMotion`), `MiniRing` (vitals + delta), `GlucoseCurveView`
  (target band + amber gradient area fill + NOW dot + x-ticks), `Toast`
  (invert-surface pill, status dot, mono timestamp, slide-up, ~2.8s auto-dismiss),
  `Delta`/`StatusPill`/`SourceChip`. VoiceOver labels on rings + curve.
- Self-contained (no screen wired yet) → no visual regression. Builds (iOS Sim).
- Next: wire into Today (radial hero + mini-ring vitals), then Trends grid,
  Wallet invert summary, Care, Journal, + debug menu.

### PR-34 — Oura redesign #1: Midnight theme foundation (NFR-UI-THEME-01) (2026-06-04)
- **feat(theme):** `Theme.swift` v02 — every `LiviqaTheme.*` colour is now a
  **dynamic token** (`Color.dyn(light,dark)`): light = Paper, dark = **Midnight**
  (tokens locked from the design brief; no invented hues). One root
  `.preferredColorScheme` flip (LiviqaApp, `@AppStorage("liviqaThemeMode")`,
  **default Midnight**) recolours all ~200 existing call sites — zero per-view
  churn, status bar + tab icons invert automatically.
- **feat(theme):** new hooks — `gridEmpty`, `heroGlow`, `homeIndicator`,
  `cardShadow` (per-mode), invert-surface set (`invertBG/FG/Sub/Line`), and
  `Radius.{card,hero,vitals}`. `Mode` enum (midnight/paper) for the runtime switch.
- **fix(ui):** AuthView's Apple + email-sign-in buttons used `ink` as a *surface*
  + white text (broke on Midnight when ink→cream) → switched to invert-surface
  tokens (correct on both themes). Launch background made theme-aware.
- Verified: builds for the iOS Simulator; Midnight renders the whole sign-in
  screen dark with the cream Lato wordmark + moss accent.
- Next: shared Oura components (RingView/MiniRing/GlucoseCurve/Toast), then
  Today → Trends → Wallet → Care → Journal. Brand/logo/copy unchanged; no
  provenance rendered; cardiac stays display-only.

### PR-33 — Full app-wide Lato rollout + TestFlight build 1.0(2) (2026-06-03)
- **feat(brand):** converted **all ~199** non-mono `.font(.system(size:…))` calls
  across every view to `.font(.lato(…))` — the whole app now renders in Lato
  (headlines/body), matching liviqa.app. Monospaced/rounded faces preserved
  (kickers/numbers stay IBM Plex Mono; one calendar day-number stays monospaced).
- **release:** bumped to build **1.0 (2)**, re-archived + uploaded to TestFlight —
  "UPLOAD SUCCEEDED" (Delivery UUID 3698bb2f-7ebe-49f4-a9cd-cfeb8b820493). This is
  the first fully brand-aligned build (icon + embedded mark + Lato/Plex fonts +
  paper launch). (Build 1.0(1) predated the brand work.)
- Verified: builds for the iOS Simulator; sign-in screen confirmed in Lato.
  Inner screens not screenshot-QA'd here (no tap-automation bridge) — eyeball in
  TestFlight for any Lato metric/wrap shifts; layouts mostly use
  minimumScaleFactor/flexible frames so risk is low.

### PR-32 — Brand alignment to liviqa.app (mark asset, Lato + IBM Plex Mono, launch) (2026-06-03)
- **feat(brand):** embed the **locked aperture mark** as an image asset
  (`LiviqaMark`/`LiviqaMarkReversed`, the same SVGs as the website) and rewrite
  `LiviqaApertureMark` to render it — no more code-drawn mark (brand kit §1:
  "embed the asset, never redraw"; code redraws caused prior drift). Same API, so
  all call sites are unchanged.
- **feat(brand):** bundle the site's real OFL fonts — **Lato** (Regular/Bold/
  Black) + **IBM Plex Mono** (Regular/Medium) — via `UIAppFonts`. `Theme` now uses
  IBM Plex Mono for kickers/numbers and adds `Font.lato(_:_:)`; the sign-in
  wordmark renders in Lato Black. (Full headline/body Lato rollout across all
  views is a follow-up — needs per-screen visual QA for metric shifts.)
- **feat(brand):** branded **launch screen** — paper `#F7F5F1` (`LaunchBackground`)
  instead of the default black.
- Palette already matched the kit (Theme tokens = design tokens). App icon = PR-29.
- Verified: builds for the iOS Simulator; fonts in the bundle, mark + launch color
  in `Assets.car`, PostScript names confirmed (no system fallback); sign-in screen
  matches liviqa.app (paper, aperture mark, Lato wordmark).

### PR-31 — First TestFlight upload (2026-06-03)
- **release:** Liviqa **1.0 (1)** archived (Release/live-data), signed with a
  freshly-minted Apple Distribution cert + App Store profile (all created headless
  via the App Store Connect API key), exported, and **uploaded to TestFlight** —
  "UPLOAD SUCCEEDED" (Delivery UUID 097e69a0-49fd-4e88-88d7-a66740b78b83). Bundle
  `dev.liviqa.app`, team PS258XSNL8.
- **fix(appstore):** added `NSHealthUpdateUsageDescription` — Apple rejects upload
  (90683) without the HealthKit *write* purpose string even though Liviqa is
  read-only.
- Found via the existing DfG App Store Connect record (Liviqa / `dev.liviqa.app`)
  + App ID `486FL49R3M` — so the earlier `app.liviqa.ios` plan was dropped; reused
  the existing identifier (no new App ID / app record).
- **State:** `api.liviqa.app` LIVE (TLS, `/me`→401 auth-gated). `auth.liviqa.app`
  (GoTrue) NOT yet deployed → sign-in won't work for testers until it's up
  (see `liviqa-backend/docs/Deploy_Prod_Hosts_Prompt_v01.md`). Hold external
  testers until auth is live.

### PR-30 — TestFlight prep: live-data Release config + App Store gaps (2026-06-03)
- **Decisions (locked):** DfG team `PS258XSNL8`; bundle `app.liviqa.ios`; canonical
  hosts on `liviqa.app`; video consult **gated off** in v1; external testers,
  synthetic data only. Gap list: `docs/TestFlight_Readiness_v01.md`.
- **feat(config):** `Config.backend` now ships **live in Release/TestFlight** —
  Release → `sovereignProd` (`api.liviqa.app` + Supabase GoTrue `auth.liviqa.app`);
  Debug → `.mock`; `LIVIQA_BACKEND` env still overrides. New `sovereignProd`
  preset; `sovereignStaging` repointed to `api.liviqa.app`.
- **feat(config):** `videoConsultEnabled = false` — `MessagesView` hides the
  consult-join section (no EU Jitsi / camera-mic in v1; messaging stays).
- **chore(signing):** `Config/Signing.xcconfig` (local, gitignored) → team
  `PS258XSNL8`, bundle `app.liviqa.ios`, group `group.app.liviqa.ios`.
- **fix(entitlements):** add `com.apple.developer.applesignin` (the SIWA button
  was wired without its entitlement) so the App ID gets the capability under
  automatic signing.
- **chore(appstore):** `Info.plist` `ITSAppUsesNonExemptEncryption=false`;
  added **`PrivacyInfo.xcprivacy`** (health/email/userID/message content, no
  tracking; UserDefaults reason CA92.1) — bundled, build verified.
- **docs:** `docs/INTENDED_USE.md` (FR-QMS-01); `docs/TestFlight_Readiness_v01.md`.
- Verified: `xcodebuild build` (iPhone 17 Pro sim) succeeds; privacy manifest in
  the .app; bundle id `app.liviqa.ios`.
- **Still blocked (needs your Apple login):** no DfG signing identity in this
  Mac's Keychain → add the DfG Apple ID in Xcode (automatic signing mints the
  Apple Distribution cert); register App ID `app.liviqa.ios` + App Group + the
  App Store Connect record; privacy nutrition labels; archive + upload.

### PR-29 — App icon (the AppIcon set had no image) (2026-06-03)
- **fix(brand):** the `AppIcon.appiconset` declared icon slots but contained **no
  image** → blank/default icon. Installed the locked aperture app-icon
  (`Brand_Assets/liviqa_appicon_aperture_1024.png`), flattened onto the brand
  off-white `#F7F5F1` (opaque, no alpha — iOS requires it; the alpha came from the
  source's rounded corners, which iOS masks itself). Single 1024 universal entry;
  actool generates all sizes. Cardinal rule honoured — locked mark, not redrawn.
- Note: delete the old app from the simulator/device once (iOS caches the blank
  icon) and re-run to see it.

### PR-28 — Auth: revert Ory → Supabase Auth (self-hosted GoTrue, EU) (FR-AUTH-01) (2026-06-03)
- **Decision:** Ory Network dropped (custom domains $70/mo, unjustified for the
  sandbox). Auth = **Supabase Auth (GoTrue) self-hosted on Scaleway (EU)** —
  sovereign + $0 license, so NFR-SEC-07 still holds (self-hosted EU GoTrue, NOT
  Supabase Cloud/US). See `docs/Auth_Supabase_v01.md`; backend `AuthGuard`
  already verifies the Supabase JWT (jose, HS256/JWKS, link-by-email).
- **feat(auth):** new `SupabaseAuthClient` (GoTrue) — `login` (password grant),
  `loginWithApple` (native `id_token` grant), `user` (session check), `logout`,
  with pure body builders + response parsers. `LiviqaBackendService` now takes a
  `SupabaseAuthClient` (was `OryAuthClient`): sign-in obtains the Supabase access
  token, persists it via `SessionTokenStore` (Keychain, NFR-SEC-01), and presents
  it as the backend bearer. `currentSession` validates the token via GoTrue.
- **feat(config):** `Config.supabaseAuthURL` (self-hosted GoTrue) + `.sovereign(…,
  authURL:)`; `sovereignStaging` points auth at it; `sovereignLocal` keeps the dev
  seed token (no Supabase needed locally). `LIVIQA_BACKEND` env override unchanged.
- **revert:** removed `OryAuthClient` + `OryAuthParsingTests` + `OryAppleParsingTests`.
  `AppleSignInCoordinator` is unchanged (its id_token + raw nonce now feed GoTrue).
- **test:** `SupabaseAuthParsingTests` (T-SBA-01..05) — password/Apple grant
  bodies, token + user parsing, nonce helpers. 8-suite simulator run green.

### PR-27 — Anchor cadence fix + re-entrancy guard + testable AnchorSync (FR-ING-03/04) (2026-06-03)
- **fix(ingestion):** correct per-type background-delivery cadence — step count
  `.hourly` (high churn), every other signal `.immediate`.
- **fix(ingestion):** re-entrancy guard in `ObserverRegistry` — an observer
  wake-up during an in-flight sync is coalesced (`beginSync`/`endSync`), so two
  `ingestDelta()` passes never overlap.
- **refactor(ingestion):** extract a portable `AnchorSync.advance(store:key:fetch:)`
  seam (no HealthKit) — loads the encrypted anchor, runs the source from it,
  persists the advanced anchor. The HK query is injected, so the
  anchor-advances-on-sync behaviour is testable with a fake.
- **test:** `EncryptedAnchorStoreTests.anchorAdvancesOnEachSync` (T-ANCH-08) —
  fake provider; each sync resumes from the prior cursor and moves it forward; a
  no-new-anchor sync leaves it put. 9-suite simulator run green.

### PR-26 — Sign in with Apple: ASAuthorizationController → Ory OIDC (FR-AUTH-01) (2026-06-03)
- **feat(auth):** `AppleSignInCoordinator` runs the native `ASAuthorizationController`
  flow with a SHA-256-hashed nonce, returning the Apple `id_token` + the RAW
  nonce. `AuthView`'s "Continue with Apple" now calls it →
  `AppState.signInWithApple` → `LiviqaBackendService.signInWithApple` (the PR-22
  Ory OIDC submit), persisting the Ory session token in the Keychain. No silent
  demo fallback; the Demo button stays the separate never-fail path. User cancel
  is swallowed; other errors surface.
- **test:** moved the Apple/OIDC parsing tests into their own `OryAppleParsingTests`
  (OIDC submit body, Apple success envelope) + a nonce test (deterministic
  SHA-256, correct length, run-to-run uniqueness).
- Note: the Apple sheet needs the "Sign in with Apple" entitlement to complete on
  device; the parsing/nonce logic is unit-tested headlessly.
- **chore(e2e):** local-QA hooks so the Care tab can be exercised against the
  local backend without changing shipped defaults — `Config.backend`/`jitsiDomain`
  read `LIVIQA_BACKEND` / `LIVIQA_JITSI_DEMO` env (defaults stay `.mock` / `nil`),
  and `NSAllowsLocalNetworking` lets the app reach `http://localhost`. Backend
  seed now provisions an **active consult session** (nurse↔LV001) so the consult
  is joinable out of the box (liviqa-backend `prisma/seed.ts`).

### PR-25 — Jitsi config decision: EU-sovereign default, demo domain quarantined (2026-06-03)
- **chore(config):** `Config.jitsiDomain` stays `nil` (secure-shell default — no
  live media until a real EU-sovereign Jitsi/Whereby domain is set), with a TODO
  to set it before any production/TestFlight build (NFR-SEC-07). Adds
  `Config.jitsiDemoDomain = "meet.jit.si"` clearly marked LOCAL-PARITY ONLY
  (US-operated — never a production default), for dev to join the same room the
  console uses.

### PR-24 — Anchored incremental HealthKit + encrypted on-device anchors (FR-ING-03/04) (2026-06-03)
- **feat(ingestion):** `HealthKitService+Anchored` — `HKAnchoredObjectQuery` per
  MVP type starting from a persisted `HKQueryAnchor`, plus `HKObserverQuery` +
  `enableBackgroundDelivery` at a per-type cadence (glucose `.immediate`, the
  rest `.hourly`). Exposed behind a framework-free capability protocol
  `IncrementalHealthSource` (`ingestDelta()` / `startBackgroundObservers` /
  `stopBackgroundObservers`) so the portable layer and demo providers stay
  HealthKit-free (NFR-PORT-01).
- **feat(security):** `EncryptedAnchorStore` — seals each anchor with the device
  DEK (KeyVault → AES-256-GCM/`CryptoBox`) and writes it to a file under
  Application Support, namespaced (SHA-256) per **device-local** user
  (`LocalUserScope`, a Keychain UUID — never UserDefaults, never a server/account
  id). `AnchorCodec` does the `HKQueryAnchor ⇆ Data` secure-coding archive.
- **test:** `EncryptedAnchorStoreTests` (T-ANCH-01..06) — encrypted round-trip,
  ciphertext-at-rest, per-key + per-user-scope isolation, wrong-DEK auth failure,
  remove/clear; `AnchorCodecTests` (T-ANCH-07) — HKQueryAnchor round-trip. All
  pass in the iOS Simulator.
- Verified: `xcodebuild build` (iPhone 17 Pro sim) succeeds; observer/background-
  delivery paths run on device (entitlement-gated).

### PR-23 — Correlation grid UI in Health Passport (FR-PAS-05 / DM-06 follow-up) (2026-06-03)
- **feat(ui):** `HealthPassportView.correlationCard` renders the 7×signal grid
  from the **live** `appState.correlationWeek` (built on-device by
  `CorrelationDeriver`, PR-17) — day headers, per-signal rows, deviation heat-map
  cells, legend, and the pattern note/sources/strength. Reuses the locked visual
  language from `WeekInContextView` (cardinal rule: iterate, don't rebuild — the
  locked mock view is untouched).
- **a11y (NFR-A11Y-01):** every cell carries `"<metric>, <day>: <level>"` using
  the existing `CorrelationLevel.accessibilityLabel`; decorative headers/legend
  are `accessibilityHidden`. No trust chips (NFR-PRIV-05).
- Verified: app builds for the iOS Simulator; deriver tests (T-COR-01) green.

### PR-22 — Sign in with Apple via Ory OIDC-native (2026-06-03)
- **feat(auth):** `OryAuthClient.loginWithApple(idToken:nonce:)` runs Ory's native
  social flow — GET login flow → POST the Apple `id_token` to the `oidc` method
  (`id_token_nonce` binds the token to the SIWA request) → reuse
  `parseLoginSuccess` (Ory returns the same `session_token` envelope as password).
  Pure `oidcSubmitBody` builder for testability.
- **feat(services):** `LiviqaBackendService.signInWithApple` (was a `notAvailable`
  stub) now performs the real Ory OIDC login when an `OryAuthClient` is present,
  sets the bearer, and persists the session token via `SessionTokenStore`
  (Keychain, NFR-SEC-01); local-dev (no Ory) keeps the seed-token fallback.
- **test:** `OryAuthParsingTests` gains T-ORY-04 (OIDC submit body: method/
  provider/id_token/nonce; nonce omitted when empty) and T-ORY-05 (Apple OIDC
  success parse). Run in the iOS Simulator.

### PR-21 — (backend) recording-consent direction regression test (2026-06-03)
- Backend change lives in **liviqa-backend** (commit `test(consult): …`). The
  recipient route already set `recordingRequested` (not `recordingConsent`, fixed
  in `73453ae`); this batch adds `workspace.service.spec.ts` asserting the
  recipient route writes `{ recordingRequested }` only and never touches
  `recordingConsent` (privacy-critical). Console already reflects the corrected
  direction (liviqa-b2b-console `dd7090d`): button "Request recording" → sets
  requested; "Recording — consented by the citizen" only when
  `recordingConsent === true`; `guard:ci` green.
- Verified: backend `npm test` green; live curl — nurse request →
  requested=true/consent=false, citizen consent → consent=true.

### PR-20 — (backend) citizen secure-messaging routes (2026-06-03)
- Backend change lives in **liviqa-backend** (commit `feat(citizen): secure-
  messaging threads routes`). Adds `@Roles('citizen')` `GET /threads`,
  `GET /threads/:recipientId/messages` (marks recipient→citizen read on open),
  `POST /threads/:recipientId/messages` (active-grant-gated, body cap 4000,
  audited `message.send`). JSON shapes match the iOS `ThreadDTO`/`MessageDTO`;
  `CareConnect`/`LiviqaBackendService` already consume them (PR-18). Backend
  `citizen.service.spec.ts` + live curl as `dev-citizen-claus` verify list/read/
  send and the 403 on no active grant.

### PR-19 — Care tab: secure messaging + video consult UI (2026-06-03)
- **feat(ui):** new **Care** tab (`MainTabView`) → `MessagesView`: lists active
  consults to join and secure message threads with the care team (loads via
  `AppState.refreshCareInbox`; pull-to-refresh). `MessageThreadView` is a chat
  (bubbles + composer) over `CareConnect.fetchMessages`/`sendMessage`.
- **feat(ui):** `ConsultView` joins the deterministic EU room
  (`https://<jitsiDomain>/liviqa-consult-<id>`) in a `WKWebView` (inline media);
  falls back to a secure shell when no EU domain is set (NFR-SEC-07). The
  citizen owns recording consent (Allow/Stop → `setRecordingConsent`), reflecting
  a recipient request; the consented-only framing is shown beside the call.
- Verified: SourceKit clean (no lints); full Xcode/simulator build pending
  (sandbox has no iOS runtime). Live data needs the deferred backend `/threads`
  routes; consult/notifications routes already exist.

### PR-18 — Citizen CareConnect client + Ory token Keychain persistence (2026-06-03)
- **docs:** `docs/Video_and_OAuth_Contract_v01.md` — cross-repo contract for the
  citizen side of the recipient workflow already in `liviqa-backend`/
  `liviqa-b2b-console` (Ory bearer model, deterministic Jitsi room
  `liviqa-consult-<id>`, recording-consent direction, citizen endpoint set).
- **feat(services):** `CareConnect` capability (sovereign-only, off the shared
  protocol) + `LiviqaBackendService` conformance — `GET /notifications`,
  `GET /consults/active`, `POST /consults/:id/join`,
  `POST /consults/:id/recording-consent` (citizen-authoritative), and the new
  messaging routes `GET /threads`, `GET/POST /threads/:recipientId/messages`.
  Portable value types (`ConsultSummary`, `CareThread`, `CareMessage`,
  `CitizenNotification`) + wire DTOs.
- **feat(security):** `SessionTokenStore` (Keychain, device-only) persists the
  Ory session token (NFR-SEC-01 / FR-AUTH-03). `LiviqaBackendService` restores it
  on init (stay-signed-in), saves on Ory login, clears on sign-out;
  `currentSession` revalidates via `whoami`.
- **feat(state):** `AppState.careConnect` + `refreshCareInbox()` (threads /
  active consults / notifications).
- Verified: service layer typechecks clean via swiftc. UI + live calls pending.
- Backend deferred (needs the backend repo): citizen `/threads*` routes and the
  recipient recording route writing `recordingRequested` (not `recordingConsent`).

### chore — backend contract cross-check + bug-hunt (2026-06-03)
- Verified `LiviqaBackendService` against the actual `liviqa-backend` repo
  controllers/services (not just openapi): routes `/me`, `/grants`, `/ledger?limit`,
  `/recipients`, `POST /grants`, `POST /grants/{id}/revoke`, `PUT /shares/{grantId}`
  all match. DTOs match: `CreateGrantDto` (recipientId/recipientRole/scopeKeys/
  granularity/expiry/delivery), `PushShareDto` `{ asOf, payload:{ metrics, insights } }`
  == `DerivedShareRequest`, grant/ledger reads (`expiresAt`/`createdAt`/`occurredAt`),
  and `/me` `AuthedAccount` (`id,kind,role,email,displayName,org`) == `AccountDTO`.
  `Gran` = summary|trend|events|detailed|off → our `"summary"` default is valid and
  the backend clamps to the role template regardless. No client change required.
- Bug-hunt over PR-15/16/17 + sharing/backend client: full pure layer typechecks
  clean together; no defects found.

### PR-17 — On-device 7-day correlation grid (FR-PAS-05 / DM-06) (2026-06-03)
- **feat(intelligence):** `CorrelationDeriver` (pure Foundation) builds the
  7-day × 7-signal grid as a deviation-from-usual heat map: each cell is the
  day's value vs the user's OWN window baseline (|z| → low/medium/high/outlier),
  personal-baseline-relative only. Derives glucose/sleep/HRV/exercise from local
  samples; spending/calendar/weather stay `noData` (connector-only — never
  fabricated). Emits a plain-language `patternNote`, named `patternSources`, and
  `patternStrength` (Steady/Moderate/Strong). New portable `CorrelationGrid`.
- **feat(models):** `CorrelationWeek.from(_:)` adapts the grid to the
  presentation model; `AppState.refreshFromHealth` populates `correlationWeek`
  from the same on-device samples (grid UI consumer remains a follow-up — no
  view renders the grid yet).
- **safety:** the pattern note is run through `NudgeGuard` in tests (no clinical
  /diagnostic/normative language).
- **test:** `CorrelationDeriverTests` (T-COR-01) + swiftc driver — 7×7 shape,
  oldest-first ordering, external columns `noData`, outlier-day detection and
  naming, steady-week path, guard-clean notes.

### PR-16 — On-device Health Passport stats derivation (FR-PAS-05 / DM-05) (2026-06-03)
- **feat(intelligence):** `PassportStatsDeriver` (pure Foundation) computes the
  sensor half of the Passport from local `HealthSamples`: `totalReadings`,
  `daysTracked` (distinct calendar days across all streams), `glucoseTimeInRange`
  (% in the 3.9–10.0 mmol/L band by default, or the user's `ClinicalTargets`
  band, FR-PAS-03), and `avgSleepHours` (asleep stages only — `awake`/`inBed`
  excluded). New `DerivedPassportStats` value type (NFR-PORT-01).
- **feat(models):** `PassportStats.compose(derived:…)` composes the sensor half
  with the count half (nudges, connected sources, journal, consent decisions).
- **feat(state):** `AppState.refreshFromHealth` now refreshes `passportStats`
  from the same arbitrated on-device samples, so the Passport reflects live data
  instead of the static `MockData` seed.
- **test:** `PassportStatsDeriverTests` (T-PAS-01) + swiftc driver — TIR 70%,
  avg-sleep excludes awake, daysTracked, totalReadings, empty-safe, custom band.

### PR-15 — Nudge engine: workout↔glucose coupling rule (§6.2 lead example) (2026-06-03)
- **feat(intelligence):** `NudgeEngine.workoutGlucoseNudge` — the prototype's
  lead example ("glucose dropped X% more than usual after yesterday's ride").
  Per workout it computes the glucose change (mean of the hour before start −
  mean of the two hours after end), groups by workout type, and fires only when
  the LATEST same-type session's drop is materially steeper (>1σ and ≥15%) than
  the user's OWN prior same-type sessions (Baseline needs ≥3). Within-user
  correlation only — no targets, no population norm, no advice.
- **safety:** output runs through `NudgeGuard` (FR-NDG-06) like every stream;
  copy stays clean (personal "more than usual", glucose accent, lane `.watch`).
- **test:** `WorkoutGlucoseNudgeTests` (T-NDG-08) + swiftc driver — fires on a
  steep latest ride, silent on typical drops, silent without ≥3 prior sessions;
  guard-clean. Pure Foundation (Android-portable, NFR-PORT-01 / NFR-MAINT-02).

### PR-14 — Ory Network auth (real session tokens) for the sovereign backend (2026-06-03)
- **feat(auth):** `OryAuthClient` runs the Ory Network NATIVE login flow
  (`GET /self-service/login/api` → `POST {ui.action}` password → `session_token`;
  `GET /sessions/whoami`; `POST /self-service/logout/api`). Pure response parsers
  are unit-tested (`OryAuthParsingTests`, verified via swiftc) without networking.
- **feat(services):** `LiviqaBackendService` takes an optional `OryAuthClient`.
  When present, `signInWithEmail` performs a real Ory login and the returned
  session token becomes the backend `Authorization: Bearer` (openapi: "prod: Ory
  session token"); `currentSession` validates via whoami; `signOut` revokes.
  When absent (local dev), the static seed token remains the identity.
- **feat(config):** `Config.oryURL` (Ory project) + `.sovereign(…, oryURL:)`;
  `sovereignLocal` (seed tokens, no Ory) and `sovereignStaging` (real Ory login)
  presets. Default backend stays `.mock`.
- Note: Apple/OIDC-native via Ory not wired yet (email/password is the path);
  session token is in-memory (Keychain persistence = follow-up).

### PR-13 — FR-SHARE-02 UI: live recipient picker + consented share send (2026-06-03)
- **feat(ui):** `ShareWithClinicianView` wired to the sovereign backend — step 3
  loads the real care directory (`GET /recipients`) and lets the citizen pick a
  recipient; step 1 toggles map to consent GROUP keys (glucose→glucose, sleep→
  sleep, HRV→recovery, activity→activity; nudges ride along as insights, not a
  scope group); "Send" creates the grant (group scope, 48h expiry) and pushes the
  derived package. Falls back to the simulated flow on `.mock`/demo.
- **feat(state):** `AppState.createGrantAndShare(recipientId:role:scopeGroups:
  rangeDays:expiry:)` — create grant → derive (fetch→arbitrate→DerivedShareBuilder)
  → `PUT /shares/{grantId}` → reload wallet. `pushDerivedShare` gains `rangeDays`.
  Raw samples/provenance never leave the device.
- **feat(ui):** `WalletView` "granted since" now uses the grant's real `createdAt`;
  grants + consent ledger already render from the live mapping (PR-12). Withdraw →
  `POST /grants/{id}/revoke` via `toggleGrant` (one-way, evidenced).
- Verified: sourcekit clean; full Xcode build pending on-device (sandbox has no
  simulator runtime). Backend write loop already proven live (PR-12).
- Completes FR-SHARE-02 / UC-07/11/12 on the citizen surface.

### PR-12 — FR-SHARE-02: EU-sovereign backend client + derived-share push (2026-06-03)
- **feat(services):** `LiviqaBackendService` implements `SupabaseServiceProtocol`
  against the EU-sovereign backend (NestJS/Scaleway+Ory) per `openapi.yaml` /
  `Liviqa_iOS_Backend_Contract_v01` — `GET /me`, `GET /recipients`, `GET /grants`,
  `POST /grants`(+`/revoke`), `GET /ledger`, and the new `pushDerivedShare →
  PUT /shares/{grantId}` (body from `DerivedShareBuilder`, FR-SHARE-01).
- **feat(services):** `SovereignSharing` protocol (recipient directory + grant
  create + derived-share push) reached via `AppState.sovereign`; `AppState`
  gains `pushDerivedShare(grantId:scopeGroups:)` (fetch→arbitrate→derive→push;
  raw/provenance never leave device).
- **feat(config):** `Config.Backend` (`.mock` default · `.supabaseSandbox` ·
  `.sovereign(baseURL:devToken:)`) + `makeService()`; `AppState.init` selects it.
  Supabase demoted to sandbox-only (NFR-SEC-07); default stays `.mock`.
- **feat(services):** `BackendMapping` — pure, testable wire↔domain transforms
  (stable UUIDv5 from opaque backend ids; ledger event/decision maps; tolerant
  ISO-8601 parse; role→display-type). `BackendMappingTests` (T-BMAP-01..06).
- **verify:** mapping driver green via swiftc; full write loop exercised live
  against `http://localhost:3001` (`dev-citizen-claus`): create grant (group
  scope) → 201, `PUT /shares` (DerivedShareBuilder body) → 200, revoke → ok.
- Maps to FR-WAL-* / UC-07/11/12/13. Closes the open device→backend seam.

### CORRECTION — re-anchor to SRS/UseCases v05 + sovereign backend (2026-06-03)
- **revert(sharing):** retired the off-spec `ShareBundle`/`ShareBundleBuilder`/
  `SecureShareExporter` + `SharingTests` introduced below. They duplicated the
  existing, on-contract `DerivedShareBuilder` (FR-SHARE-01) and diverged from it
  (individual scope keys vs consent GROUPS; a local AES envelope vs the contract's
  TLS `PUT /shares/{grantId}`). `DerivedShareBuilder` is the canonical builder.
- **docs(qms):** re-anchored RTM to actual SRS IDs — FR-SHARE-01 (DerivedShareBuilder),
  FR-SHARE-02 (sovereign wiring, planned), **NFR-SEC-07** (cloud holding real PII
  must be EU-sovereign — `liviqa-backend`/Scaleway+Ory, not US-parented Supabase),
  FR-PROV-01 (SourceArbiter). Root cause of the divergence: building from the
  derived RTM instead of `Liviqa_SRS_v05`/`Liviqa_UseCases_v05` and
  `docs/Sovereign_Backend_Integration_v01.md`.
- **feat(ingestion):** `SourceArbiter` (FR-PROV-01) retained — highest tier wins,
  lower fills gaps, never blends clinical with estimate; wired into
  `AppState.refreshFromHealth()` before persist/engine. Verified via swiftc.
- Retained as on-spec: PR-7 (FR-ARCH-05/UC-05), PR-8 KeyVault (NFR-SEC-01/02).

### PR-9 [RETIRED] — scoped, derived-only, encrypted share boundary (2026-06-03)
- **feat(sharing):** `ShareBundle` / `DailySummary` — the ONLY shape data may
  leave the device. Derived daily aggregates only: no raw intraday samples, no
  `source`, and NEVER `provenance` (internal arbitration stays on-device).
- **feat(sharing):** `ShareScope` maps consent scope keys → unlockable metrics
  (deny-by-default; `calendar`/unknown scopes unlock nothing).
- **feat(sharing):** `ShareBundleBuilder` reduces `HealthSamples` to one row per
  metric per day (mean for rates, sum for counts/minutes; sleep counts asleep
  time only) filtered to the grant's scopes.
- **feat(sharing):** `SecureShareExporter` JSON-encodes then AES-256-GCM-seals
  the bundle via `KeyVault.cryptoBox()` — the PR-8 primitive becomes an enforced
  egress control. Bundle dates are whole-second so the encrypted round-trip is
  byte-stable.
- **feat(security):** `KeyVault(requireUserPresence:)` opt-in — gates the Secure-
  Enclave device key on Face/Touch ID (passcode fallback) via `SecAccessControl`.
- **test:** `SharingTests` (T-SHARE-01..05): scope filtering, no-provenance/
  no-source/no-raw guard on serialized JSON, deny-by-default, encrypt round-trip,
  one-row-per-metric-per-day.

_Requirements touched:_ FR-ARCH-04, NFR-PRIV-01, NFR-SEC-02.
_Risk:_ mitigates RK-PRIV-EGRESS-01 (raw/identifying data leaving device); no new
clinical hazard. See `qms/RISK.md`.
_Verification note:_ all 11 sharing checks executed this session via a `swiftc`
driver. KeyVault biometric path runs on device.

### PR-8 — Secure Enclave key-wrap + AES-256 verification (2026-06-03)
- **feat(security):** `CryptoBox` — AES-256-GCM authenticated encryption
  (nonce‖ct‖tag combined box); `keyBitCount` exposed for strength assertions.
- **feat(security):** `KeyWrap` — ECIES wrap of the data-encryption key (DEK) to
  a P-256 device key (ECDH → HKDF-SHA256 → AES-GCM), versioned HKDF context,
  fresh ephemeral per wrap. `AgreementPrivateKey` abstraction unifies software
  and `SecureEnclave.P256` keys so unwrap is identical on both paths.
- **feat(security):** `KeyVault` — mints a 256-bit DEK on first use, wraps it to
  a Secure-Enclave device key (private half never leaves the SE; only its
  `.dataRepresentation` is stored), persists the wrapped DEK in the Keychain
  (`…AfterFirstUnlockThisDeviceOnly`). Software P-256 fallback for simulators;
  `isHardwareBacked` records the live path. `reset()` for wipe/sign-out.
- **test:** `CryptoTests` (T-SEC-01..06) — AES-256 round-trip, GCM tamper
  rejection, wrap/unwrap recovery, wrong-device-key failure, per-wrap
  uniqueness, serialization round-trip.

_Requirements touched:_ NFR-SEC-02, OD-09.
_Risk:_ mitigates RK-PRIV-ATREST-01 (data-at-rest) + adds integrity guarantee;
no new clinical hazard. See `qms/RISK.md`.
_Verification note:_ all 10 crypto checks executed this session via a `swiftc`
driver (software P-256). Secure-Enclave + Keychain paths run on device.

### PR-7 — UI wiring: live L1→L2→L3 feed + demo-data badge (2026-06-03)
- **feat(app):** `AppState.refreshFromHealth()` runs the on-device pipeline —
  active `HealthDataProvider` (mock or HealthKit) → `IngestionCoordinator.persist`
  (L2, on-device only) → `NudgeEngine` (L3) — and publishes the capped,
  FR-NDG-06-clean feed. Falls back to existing nudges if nothing fires, so the
  Today feed is never empty. SwiftData container is optional → a store failure
  can never crash launch.
- **feat(app):** provider is selectable via `AppState.dataProviderKind`
  (`.mock` default for the synthetic demo user; `.healthKit` for real data) with
  no code change at the call sites.
- **feat(intelligence):** `EngineNudge → Nudge` card adapter (`EngineNudge+Card.swift`)
  — the single seam between domain output and the locked prototype card. No
  clinical copy added; card text comes straight from the engine.
- **feat(ui):** `TodayView` shows a neutral "DEMO DATA" badge when the feed is
  synthetic (FR-ARCH-05). `MainTabView` triggers `refreshFromHealth()` on appear.
- **refactor(ingestion):** split `IngestionCoordinator.sync` into `sync` +
  `persist(_:from:to:)` so a caller can fetch once and reuse samples for L3.
- Prototype design untouched (cardinal rule): wiring is additive (one new param,
  one extension file, one additive badge).

_Requirements touched:_ FR-ARCH-05 (demo-data disclosure), L1→L2→L3 integration.
_Risk:_ no new clinical hazard. The display-only AFib lane stays display-only
(`EngineNudge` → `.cardiac` accent, no clinician routing implied by the card).
_Verification note:_ asset-less `xcodebuild` (device, signing off) shows **0 new
errors** in any wired file; remaining errors are the authoring-sandbox macro
plugins only. UI rendering verified by the user in Xcode.

### fix — resolve `Nudge` type collision with locked prototype (2026-06-03)
- The PR-5 engine type `Nudge` collided with the locked prototype's
  presentation-layer `Nudge` card view-model (`Liviqa/Models/MockData.swift`),
  producing "invalid redeclaration / ambiguous for type lookup" — the hard error
  that blocked the Xcode build. Renamed the engine output type to `EngineNudge`
  across `NudgeModel`/`NudgeGuard`/`NudgeEngine` (prototype left untouched, per
  the cardinal rule). A future UI PR maps `EngineNudge` → the `Nudge` card.
- Verified: full `xcodebuild` (device, signing off) shows the `Nudge` clash gone
  (0 errors); all remaining build errors are the authoring-sandbox's inability to
  run Swift macro plugins (`@Model`, `@Observable`, `#Preview`) + their cascades,
  which do not occur in a normal Xcode toolchain.

### PR-6 — Open-Meteo weather/AQI context (coarse, no health egress) (2026-06-03)
- **feat(context):** `OpenMeteoWeatherProvider` fetches current weather +
  European AQI (FR-CTX-01). Coordinate is coarsened to ~0.1° (~11 km) before any
  request (privacy control); air-quality is best-effort (non-fatal). Keyless,
  EU-hosted. `MockWeatherProvider` for offline/tests.
- **feat(context):** pure `OpenMeteo` URL builders — requests carry only
  lat/lon + named env fields, proven by test (no health data, no identifiers,
  no key). `Coordinate`/`WeatherSnapshot` value types, Foundation-only.
- **feat(context):** `WeatherContextMapper` → `WeatherContext` entity
  (provenance EXTERNAL); coarse coordinate is not persisted.
- **test:** `WeatherContextTests` (T-CTX-01..04).

_Requirements touched:_ FR-CTX-01, FR-CTX-02.
_Risk:_ no new clinical hazard; adds a privacy control (coarse location, no
health egress). See `qms/RISK.md`.
_Verification note:_ coarsening + URL-privacy + mock executed via `swiftc` this
session; entity mapping (SwiftData) runs in Xcode.

### PR-5 — On-device nudge engine + FR-NDG-06 guard + AFib display-only (2026-06-03)
- **feat(intelligence):** `NudgeEngine` — on-device, heuristic, personal-baseline
  -relative (±1σ). Emits the strict allow-list only (verdict / number / band-status
  / behavioural-lever / route-to-clinician), capped at 4 ("4 nudges, not 48 charts").
- **feat(safety):** `NudgeGuard` — **FR-NDG-06 designated control**. Blocks dose
  quantities, dosing verbs, treatment directives, affirmative diagnostic claims,
  and clinical-normality verdicts in any nudge string. Every engine output is
  validated before release; violators dropped + trapped in debug.
- **feat(cardiac):** AFib/cardiac is `displayOnly` (D9) — the only output is a
  route-to-clinician nudge (no verdict/band/interpretation), top priority so it
  always survives the cap. No signal ⇒ no cardiac nudge.
- **feat(model):** `RegulatoryLane` (wellness/watch/constrained/displayOnly),
  `Baseline`, `Nudge`, `NudgeCategory`, `ClinicalSignals` — pure Foundation,
  Android-portable, carries no `provenance`.
- **test:** `NudgeGuardTests` (T-NDG-06/06b/06c, blocking), `NudgeEngineTests`
  (T-NDG-01..07, T-BASE-01).

_Requirements touched:_ FR-NDG-01..06, D9/FR-REG-03, L3 lane map.
_Risk:_ RK-CARD-01, RK-GLU-01 now **mitigated** (was the top MDR exposure). See `qms/RISK.md`.
_Verification note:_ entire layer compiled **and executed** via `swiftc` harness
this session — guard blocks all bad strings, engine caps + routes correctly.
Swift Testing suites re-run in Xcode.

### PR-4 — HealthKitService (read-only) + L1→L2 persistence (2026-06-03)
- **feat(ingestion):** `HealthKitService` reads the MVP set on-device. Share/write
  set is **empty** — read-only by construction (FR-ARCH-04). Blood glucose read
  directly in canonical mmol/L (OD-07); all readings `provenance = .real`.
  Daily metrics aggregated per day (sum for steps/energy, mean for HRV/RHR).
- **feat(ingestion):** `HealthProviderFactory` resolves `.healthKit` →
  `HealthKitService` where the SDK exists, else Mock (`#if canImport(HealthKit)`).
- **feat(ingestion):** `IngestionCoordinator` + `SampleMapper` normalize
  `HealthSamples` into SwiftData entities (glucose, HeartDaily [HRV+RHR merged],
  sleep, workouts). Re-sync of a window is idempotent (replace-range, no dupes).
  Steps/active-energy stay on `HealthSamples` for L3 derivations (no raw entity).
- **test:** `HealthKitTests` (T-HK-RO-01/02/03), `MappingTests` (T-MAP-01/02).

_Requirements touched:_ FR-ARCH-04, FR-ING-02..05, FR-ING-09, OD-07, OD-09.
_Risk:_ glucose values now flow from device→store; still data-layer only, no
interpretation/rendering. AFib/insulin remain unsurfaced. See `qms/RISK.md`.
_Verification note:_ `HealthKitService` typechecks against the real HealthKit
SDK via `swiftc` this session; `IngestionCoordinator` (SwiftData macro) + Swift
Testing suites run in Xcode on the dev machine.

### PR-3 — L1 ingestion seam + provenance guard (2026-06-03)
- **feat(ingestion):** framework-free `HealthSamples` aggregate + value readings
  (`GlucoseReading`, `DailyMetric`, `SleepReading`, `WorkoutReading`) for the MVP
  read set (FR-ING-01). Single aggregate, no upload method anywhere (FR-ING-07).
- **feat(ingestion):** `HealthDataProvider` protocol — read-only by contract
  (auth + fetch only, no write surface, FR-ARCH-04) — with `DataProviderKind`
  (`isDemoData` drives the FR-ARCH-05 indicator) and `HealthProviderFactory`.
- **feat(ingestion):** `MockDataProvider` — deterministic, seeded synthetic
  demo user; every reading `provenance = .simulated` so the clinical gate stays
  satisfied. `LV001Provider` real-data stub, inert unless `LV001_DEMO` flag set
  (no synthetic fallback — would violate the clinical gate).
- **feat(guard):** `scripts/guard_provenance.sh` — **blocking** T-PROV-01: fails
  if `provenance` appears in any SwiftUI file. Plus type-level guards (T-PROV-02/03).
- **refactor(model):** move portable enums `SleepStage`/`InsulinKind` into
  framework-free `CoreTypes.swift` (shared by L1 and L2; NFR-PORT-01).
- **test:** `LiviqaTests/IngestionTests.swift` (T-ING-01..05),
  `LiviqaTests/ProvenanceGuardTests.swift` (T-PROV-02/03).

_Requirements touched:_ FR-ING-01, FR-ING-07, FR-ARCH-04 (partial), FR-ARCH-05
(data flag), NFR-PORT-01, NFR-PRIV-05 (provenance render guard).
_Risk:_ no new hazard; the provenance-never-renders control is now enforced.
_Verification note:_ pure L1 + core layer typechecks clean via `swiftc` in this
session; the file guard runs green here. Swift Testing suites + SwiftData run in Xcode.

### PR-2 — Typed L2 data model (2026-06-03)
- **feat(model):** 12 typed sample entities (`GlucoseSample`, `InsulinDose`,
  `HeartDaily`, `BPReading`, `AFibBurden`, `SleepSegment`, `Workout`,
  `BodyComposition`, `LabResult`, `MedicationRecord`/`MedicationInteraction`,
  `WeatherContext`, `CalendarLoad`) per DataModel v1 §2.1, each carrying
  `source` + `tier{clinical,good,estimate}` + `provenance{REAL,SIMULATED,EXTERNAL}`.
- **feat(model):** clinical-tier rejects SIMULATED — schema gate
  (`validateTierProvenance`, throwing on every init) plus a type-level
  `ClinicalProvenance` (no `.simulated` case) for clinical constructors.
- **feat(model):** glucose canonical mmol/L (`GlucoseUnit`, OD-07); `provenance`
  is data-only (no user-facing label exists on the enum).
- **feat(store):** on-device `SwiftData` container (`LiviqaStore`) with
  `cloudKitDatabase: .none` (samples never sync, NFR-PRIV-01) + file-protection
  complete. Not yet wired into app launch (ingestion is its first writer, PR-4).
- **test:** `LiviqaTests/DataModelTests.swift` — clinical/SIMULATED rejection,
  mmol/L conversion, type-level clinical constructor, SwiftData schema round-trip.

_Requirements touched:_ DataModel v1 §2.1, OD-07, OD-09 (partial), NFR-PRIV-01.
_Risk:_ glucose/AFib/insulin **data** entities introduced — data-layer only, no
rendering or interpretation; insulin has no MVP surface (FR-REG-04). See `qms/RISK.md`.
_Verification note:_ this authoring session cannot run the SwiftData macro plugin
or the iOS Simulator; tests are authored and run in Xcode on the dev machine.

### PR-1 — Deployment-agnostic signing + QMS scaffold (2026-06-03)
- **chore:** relocate locked Phase-1 prototype to non-synced canonical clone
  `~/Developer/DataForGood/liviqa-ios` (baseline, no code change).
- **feat(signing):** centralise all signing/identity in `Config/Signing.xcconfig`
  (gitignored) + `Config/Signing.example.xcconfig`; wire
  `DEVELOPMENT_TEAM` / `PRODUCT_BUNDLE_IDENTIFIER` / `APP_GROUP` via build
  settings; remove hardcoded Team ID and bundle IDs from the project, Info.plist,
  and entitlements. Account swap → DfG is now an xcconfig edit (D-STORE).
- **feat(healthkit):** enable HealthKit capability + `NSHealthShareUsageDescription`
  (read-only enforced in code, later PR — `FR-ARCH-04`).
- **docs:** add `docs/SIGNING.md` (setup + migration runbook).
- **chore(qms):** scaffold RTM, DHF, RISK, CHANGELOG, VnV.

_Requirements touched:_ D-STORE, FR-ARCH-04 (partial), FR-QMS-02/03/05.
_Risk:_ no new hazard (see `qms/RISK.md`).
