# Risk Register (ISO 14971-aligned)

_Hazard → cause → mitigation → residual risk → linked requirement. Cardiac/glucose/medication lanes carry the top entries. Safety-path code changes require a row here (or an explicit "no new hazard" PR note). Version: 2026-06-03._

## PR-102 — Pre-launch audit fixes, wave 1: two hazards REMOVED, none added (2026-07-03)

Both safety-path changes in PR-102 remove existing hazards; neither introduces a
new clinical hazard. Nudges, units (glucose mmol/L, OD-07), provenance handling,
the AFib lane, and the `FR-NDG-06` guard are untouched.

- **Fabricated data presented as the user's own (demo-login leak) — REMOVED.**
  Cause: `Config.dfgWalletLoginEnabled`/`nationalIDLoginEnabled` shipped `true` in
  Release, routing simulated wallet/eID sign-ins through `signInDemo()` → the
  fabricated LV001 9.5-year record rendered as the user's own data on
  HealthKit-empty devices. Mitigation: both flags are now `#if DEBUG`-gated
  (compile-time `false` in Release) AND `applyLV001DatasetIfNeeded()` is a no-op
  in non-DEBUG builds — defence in depth: no Release path can inject LV001.
  Residual risk: low (Debug/demo builds still show LV001 by design, for the
  pitch; never distributed to users).
- **False deletion assurance ("All local data deleted." while nothing was
  deleted) — REMOVED.** Cause: the Settings delete flow advanced to a success
  state with `AppState.deleteAllData()` unimplemented (GDPR Art. 17 exposure; a
  user could believe sensitive health data was erased when it persisted).
  Mitigation: `deleteAllData()` implemented (SwiftData entities + journal file +
  encrypted sync anchors + Keychain session + UserDefaults + in-memory reset)
  and the confirmation is shown only after the erase completes (T-DEL-01).
  Residual risk: low; verify with `T-DEL-01_deleteAllData_purgesEverything`.
- **Mistral key in the binary (security, not clinical):** key now DEBUG-only;
  Release uses the backend `/ai/chat` proxy. No clinical path affected — the
  ChatGuard before/after every call is unchanged. Key rotation = owner action.
- **Wave 2 (2026-07-03) — designated control T-PROV-01 was inert
  (audit-integrity, not a new clinical hazard).** The provenance-never-renders
  shell guard (`scripts/guard_provenance.sh`) was wired to no build/CI step and
  was exiting 1 on wallet-receipt word collisions ("provenance receipt",
  UC-24b/UC-21), while VnV/RTM/this file recorded it green and blocking.
  Fixed: pattern scoped to the provenance DATA FIELD (`.provenance` access,
  `provenance:` label, `Provenance` type/case — not the bare word), guard wired
  as a blocking `build-ios.sh` step before xcodebuild, and the false records
  corrected in place (kept, not erased). The substantive rule held throughout:
  no view renders the field (audit-verified). RK-PROV-01 mitigation is now
  actually enforced as recorded. Also wave 2: 8 missing RTM rows added
  (FR-RSCH-03, FR-WAL-08, FR-PROV-02, FR-PAT-01/02, FR-PAS-03, FR-ING-08,
  NFR-RSCH-04) — traceability only, no code-path change, no new hazard.
- **Wave 3 (2026-07-05) — dead CTAs + consult-availability overclaim
  (honesty fixes, no new clinical hazard).** Six reachable dead controls
  (empty `Button { }`) were either wired — `NudgeDetailView` "Share via
  wallet" now opens the EXISTING `ShareWithClinicianView` consent-share flow
  (no new share path; same flow already reachable from Settings, full
  scope/range/recipient consent steps unchanged) — or converted to disabled
  honest stubs (SOON chip), so no control silently does nothing. And
  `PlanConsultView` no longer asserts "availability mirrors <clinician>'s
  calendar" over a simulated free/busy grid; the copy is now "Suggested
  times — your clinician will confirm." — removes a false trust claim in
  the care-scheduling flow (the consult request itself is real). A blocking
  dead-CTA grep in `build-ios.sh` keeps empty CTAs from returning. Nudges,
  units (mmol/L), provenance handling, the AFib lane, and the FR-NDG-06
  guard are untouched; no new FR, no RTM change needed.

## PR-96 — A6 "Daylight" re-skin; RK-ALARM-01 re-assessed — Amber Flame accepted (2026-06-16)

The A6 "Daylight" re-skin is a presentation change (six-colour palette, SF Pro
type, iris app icon, Liquid Glass chrome). Most of it carries **no clinical
hazard** — palette/type/icon/glass change no data, nudge, unit, or the AFib lane.
**One change is safety-relevant: it supersedes the PR-47 attention-tone control.**

- **RK-ALARM-01 (attention colour read as a medical warning) — RE-ASSESSED; amber
  accepted.** A6 retires the desaturated **clay** (`#BD7A33`) attention tone and
  moves the patient "worth a look" signal **back to Amber Flame** (`#FFB703`) — the
  hue PR-47 had moved away from because saturated amber can read as a warning light.
  This was flagged to the owner and **accepted by CN on 2026-06-16** (founder /
  design owner): Amber Flame is the patient attention tone going forward. The PR-47
  "clay over amber" decision is **superseded**, on the basis of the controls below.
  - **Why amber ≠ alarm here (the controls that hold the meaning to "notice"):**
    amber is used as a **fill / dot / border / icon** with **navy text** on light
    grounds (never amber alarm *text* on light — the locked contrast rule), not as a
    full-bleed saturated alarm state; colour is **never the only signal** — the
    "Worth a look" kicker label + demoted position (below the calm affirming hero) +
    metadata carry the meaning, preserving the colour-blind-safe rule; the copy keeps
    the non-threshold, non-alarm voice (`FR-REG-02`); and the patient app stays a
    **two-state** model (cerulean = in-range · amber = notice) — the saturated
    green/amber/red triage ramp remains console-only, never shown to the patient.
  - **AFib / cardiac lane:** untouched — still **display-only, route-to-cardiologist,
    no interpretation/alarm/trend** (`D9`/`FR-REG-03`; `T-NDG-02/03` still pass). The
    amber tone is not used on the cardiac lane.
  - **Residual risk: ACCEPTED (low).** Owner-confirmed presentation control; the tone
    signals *state* ("worth a look"), never an alarm, via context + label + position,
    not hue alone. Re-confirm at the next human-factors / regulatory review that
    amber-as-fill reads as "notice", not "warning".
- **Liquid Glass legibility (positive):** the new glass surfaces (tab bar, sheets)
  fall back to an **opaque** `LiviqaTheme.paper/paper2` fill under Reduce Transparency
  / Increase Contrast, so text contrast is preserved for low-vision users — no
  legibility regression introduced.
- **provenance-never-renders (`T-PROV-01`):** A6 added no `provenance` rendering. The
  guard's pre-existing failure on `develop` (ePRO "provenance receipt" strings in
  `JournalView`/`WalletView`) is **unrelated to A6** and tracked separately.
- No new clinical claim; HealthKit read-only (`FR-ARCH-04`), glucose unit (`OD-07`),
  and the nudge allow-list/guard (`FR-NDG-06`) are untouched.

## PR-46/47 — full HealthKit capture + Design System v2; controls hold (2026-06-09)

Step A widens ingestion to capture insulin, AFib burden, blood pressure, body
composition, and the full heart/respiratory panel. This is a **data-layer**
change — the new signals are read, arbitrated, and persisted, but **not rendered,
interpreted, or turned into a nudge** here (rendering = Step B). The top hazards
are directly engaged and the existing controls hold:

- **RK-GLU-01 (acting on glucose/insulin for dosing):** insulin delivery is now
  read from HealthKit (`insulinDelivery` → `InsulinDose`), but stays a **data
  source only — no insulin/dosing surface** (`FR-REG-04`). No UI/output path,
  no dose printed, no dosing verb. The glucose×insulin *observation* nudge is held
  to Step B and remains gated by the `FR-NDG-06` guard (a designated control) and
  the RQ-01 "describe vs advise" decision (Claus/counsel). Control: **holds.**
- **RK-CARD-01 (AFib read as diagnosis):** AFib burden is now read
  (`atrialFibrillationBurden` → `AFibBurden`), but the cardiac lane is unchanged —
  **display-only, route-to-cardiologist, no interpretation/alarm/trend** (`D9`/
  `OD-11`/`FR-REG-03`; `T-NDG-02/03`). The new read adds no rendering. Control: **holds.**
- **RK-PROV-01:** every new reading is `provenance = .real`, tier `good`/`estimate`
  — never `clinical`; the schema gate is untouched, the provenance-never-renders
  guard is unchanged. Control: **holds.**
- **Read-only structural (FR-ARCH-04):** the share/write set is still **empty** —
  the wider read set adds no write capability (`T-HK-RO-01`; updated
  `readSetIsFullCaptureSet`). The app still cannot mutate the user's health record.
- **New wellness/watch data (BP, body-comp, SpO₂, VO₂max):** no clinical
  interpretation rendered; these land in the wellness/watch lanes when surfaced
  (Step B). No new clinical hazard at the data layer.
- **RK-DATA-DUP-01 (NEW, low — duplicate/inflated metrics mislead the user):**
  a re-sync could re-insert boundary samples outside the delete window, inflating
  a metric (e.g. glucose 48 rows where 42). **Mitigated:** the window-replace now
  deletes the union of the requested window and the inserted rows' span, so re-sync
  converges. Verified by `reSyncIsIdempotent` (`T-MAP-02`, now green). Note: real
  HealthKit reads are already window-clipped by the query predicate; this hardened
  the mock/edge path and the contract.

**Design System v2 — clay as an anti-alarm control (PR-47):**
- **RK-ALARM-01 (attention colour read as a medical warning):** the patient app's
  attention tone moved from saturated **amber** (a warning-light reflex, trained by
  dashboards/traffic) to a desaturated **clay** (`#BD7A33`) that says "worth a
  look", not "something's wrong". This is a deliberate de-risking choice that
  supports the never-diagnostic voice and `FR-REG-02` (no threshold/alarm framing):
  colour must signal *state* (moss = in-range, clay = notice), never an alarm.
  Colour is never the only signal (label + position + metadata), preserving the
  colour-blind-safe rule. No new clinical claim; this is a presentation control.

## PR-28 — auth provider change (Ory → self-hosted Supabase GoTrue); sovereignty held (2026-06-03)

- **RK-SEC-RESIDENCY-02 (auth on US-parented infra, NFR-SEC-07):** NOT regressed.
  Ory Network is replaced by **Supabase Auth (GoTrue) self-hosted in the EU**
  (Scaleway), not Supabase Cloud. Real-PII auth stays on EU-sovereign infra;
  tokens are Keychain-only (NFR-SEC-01). The backend verifies the Supabase JWT
  locally (jose) and never calls a US service per request. Had this been wired to
  Supabase *Cloud*, it would breach NFR-SEC-07 — the control is "self-hosted EU
  GoTrue", recorded here and in `docs/Auth_Supabase_v01.md`.
- No new clinical hazard. The app-level consent gate + backend authz are unchanged.

## PR-20/21/24 — consent-direction, message gate, encrypted sync-cursors (2026-06-03)

This batch wires citizen↔care-team messaging + Sign in with Apple and hardens
incremental ingestion. No new clinical interpretation; the entries are
consent/confidentiality controls.

- **RK-CONSENT-DIR-01 (recipient records a consult without the citizen's
  consent):** mitigated. Recording consent is one-directional — the recipient may
  only set `recordingRequested`; `recordingConsent` is writable ONLY on the
  citizen route (`CitizenService.recordingConsent`). The recipient route was
  corrected (liviqa-backend `73453ae`) and is now locked by a regression test
  (`workspace.service.spec.ts`) asserting it writes `{ recordingRequested }` only
  and never `recordingConsent`. The console shows "requested → awaiting citizen
  consent" until the citizen grants, and only then "Recording — consented by the
  citizen". Verified live (request: requested=true/consent=false; citizen grant:
  consent=true). Linked: NFR-PRIV-01, Video_and_OAuth_Contract_v01 §recording.
- **RK-MSG-SCOPE-01 (messaging used to move health content / reach a citizen
  without consent):** mitigated. Citizen `POST /threads/:recipientId/messages`
  requires an active grant (`SharedService.requireActiveGrant` → 403 otherwise),
  caps the body at 4000 chars, and is audited (`message.send`). Messaging is not
  a health-content channel (D-BACKEND-SCOPE); raw health discussion stays in the
  consult. Verified: 403 on no active grant.
- **RK-PRIV-ATREST-02 (HealthKit sync cursors readable / cross-user leakage):**
  mitigated. `HKQueryAnchor`s are sealed with the device DEK (AES-256-GCM via
  KeyVault, the PR-8 control) and written to files namespaced per device-local
  user — never UserDefaults, never keyed to a server/account id (FR-ING-04). A
  wrong device key fails GCM authentication rather than returning garbage
  (`EncryptedAnchorStoreTests`). No raw samples are stored — only the opaque
  cursor. Linked: NFR-SEC-02, FR-ING-03/04.

No new clinical hazard introduced.

## PR-12 — FR-SHARE-02 device→sovereign egress; residency + leak hazards mitigated

The derived-share PUSH is now wired to the EU-sovereign backend.
- **RK-SEC-RESIDENCY-01 (real PII to US-parented cloud, NFR-SEC-07):** mitigated —
  `LiviqaBackendService` targets the sovereign backend (Scaleway+Ory); Supabase is
  demoted to `.supabaseSandbox`; default backend is `.mock`. Real-user cutover sets
  `.sovereign`.
- **RK-PRIV-EGRESS-01 (raw/provenance leaving device):** mitigated by construction —
  the only health payload sent is `DerivedShareBuilder`'s scoped daily aggregates;
  the service never serializes `HealthSamples`/provenance. Backend re-checks
  guardrails server-side. Verified live (PUT /shares 200; revoke immediate).
- **Residual:** transport is plain HTTP for `localhost` dev only; production uses
  TLS to `api.dfgworks.dk` (NFR-SEC-06). Dev bearer tokens are non-production.

## CORRECTION (2026-06-03) — retired off-spec egress module

A prior entry here described a `ShareBundle`/`SecureShareExporter` egress module.
That module duplicated and diverged from the canonical `DerivedShareBuilder`
(FR-SHARE-01) and assumed a local AES envelope instead of the contract's TLS
push to the EU-sovereign backend. It has been **retired**. The egress hazard is
owned by `DerivedShareBuilder` + the sovereign backend integration (below).

- **RK-PRIV-EGRESS-01 (raw/provenance/identifiers leaving device):** mitigated by
  `DerivedShareBuilder` (derived GROUPS only, no provenance/source; backend also
  strips) delivered over TLS (NFR-SEC-06) to an EU-sovereign backend (NFR-SEC-07,
  not US-parented Supabase). Control verified by `DerivedShareBuilderTests`.

## PR-8 — device-bound key material; data-at-rest hazard mitigated

PR-8 adds the AES-256 + Secure-Enclave key-wrap primitive (NFR-SEC-02 / OD-09).
No clinical interpretation; this is a confidentiality/integrity control.
- **RK-PRIV-ATREST-01 (on-device data readable if storage is extracted):** the
  data-encryption key (AES-256) is wrapped (ECIES: ECDH → HKDF-SHA256 → AES-GCM)
  to a P-256 device key whose private half lives in the **Secure Enclave** and
  never leaves it. Keychain items are `…ThisDeviceOnly`. A copied Keychain/
  backup is therefore not unwrappable on another device. Verified: wrong-device-
  key cannot unwrap (T-SEC-04), each wrap is forward-secret/unique (T-SEC-05).
- **Integrity:** AES-GCM authenticates every box — a single flipped byte throws
  rather than returning corrupted plaintext (T-SEC-02). No silent corruption.
- **Residual:** simulators without an SE fall back to a software P-256 key
  (still AES-256, still device-only Keychain); `KeyVault.isHardwareBacked`
  records which path is live for audit. Production hardware is SE-backed.

No new clinical hazard introduced.

## PR-6 — external context; privacy control added, no new clinical hazard

PR-6 adds the Open-Meteo weather/AQI signal. No clinical interpretation, no
health data leaves the device. New control:
- **Coarse-location:** coordinates are rounded to ~0.1° (~11 km) before any
  request, and a test proves requests carry only lat/lon + env fields (no health,
  no identifiers, no key) — mitigates a location-privacy leak (RK-PRIV-LOC-01).

No new clinical hazard introduced.

## PR-5 — nudge engine + FR-NDG-06: top hazards now mitigated in code

PR-5 is the first PR that renders interpretation/advice, so it directly engages
the top hazards. Mitigations are now **implemented and verified** (executed this
session), not just planned:

- **RK-CARD-01 (AFib read as diagnosis):** the cardiac lane is `displayOnly`.
  The only output is a `routeToClinician` nudge that explicitly states Liviqa
  does not interpret heart rhythm and routes to the cardiologist — no verdict,
  band, or trend. No-signal ⇒ no cardiac nudge (T-NDG-02/03).
- **RK-GLU-01 (acting on a glucose nudge for dosing):** no insulin/dosing
  surface; glucose output is band-status relative to the personal baseline only.
  The **FR-NDG-06 guard** (designated control) blocks any dose quantity, dosing
  verb, treatment directive, diagnostic claim, or clinical-normality verdict in
  ANY nudge string. Every engine output is run through the guard before release;
  violators are dropped and trapped (`assertionFailure`) in debug.
- **RK-PROV-01:** the nudge layer carries no `provenance`/tier and renders no
  source label; provenance guard still green.

Residual risk: heuristic thresholds (±1σ baseline) are wellness-grade, not
clinical — acceptable for the wellness/watch lanes; the constrained/display-only
lanes carry no interpretation. FR-NDG-06 tests are **blocking** (qms/VnV.md).

## PR-4 — real glucose/cardiac data now ingested; controls hold

PR-4 lets real device data flow HealthKit → store. Still no rendering, nudging,
or interpretation. Controls reinforced:
- **Read-only** is now structural: HealthKit share/write set is empty
  (`HealthKitService.shareTypes = []`, T-HK-RO-01) — the app cannot mutate the
  user's health record (closes the "app writes bad data back" failure mode).
- Glucose canonicalized to mmol/L at the read edge (OD-07) — no unit-confusion
  hazard from mixed mg/dL in the store.
- Ingested HealthKit data is `provenance = .real`, tier `good`/`estimate` (never
  clinical) — keeps RK-PROV-01 mitigation intact; clinical gate untouched.
- RK-CARD-01 / RK-GLU-01 unchanged: no AFib/glucose **rendering or nudge** added
  (still land in PR-5).

No new hazard introduced.

## PR-2 — data entities only, no new clinical hazard

PR-2 introduces glucose, AFib-burden, and insulin-dose **data entities** plus the
on-device store. These are data-layer types: nothing is rendered, interpreted, or
turned into a nudge here. Controls preserved:
- Clinical-tier rows cannot be SIMULATED (schema gate + type-level
  `ClinicalProvenance`) — guards RK-PROV-01.
- `InsulinDose` is a data source only; **no insulin/dosing surface** (FR-REG-04) —
  no UI/output path added.
- Samples cannot leave the device: store uses `cloudKitDatabase: .none` (NFR-PRIV-01).

No new hazard introduced. AFib/glucose rendering + nudge constraints are still
the open mitigations tracked below (land in PR-5).

## PR-1 — no new hazard

PR-1 is signing/identity configuration and repo relocation only. It introduces
**no analytical, clinical, or data-path code** and therefore **no new hazard**.
Logged per the QMS-lite "no safety-relevant change without a risk touch" rule.

## Pre-seeded top hazards (structure in place; mitigations land with their PRs)

| ID | Hazard | Cause | Planned mitigation | Linked req | Status |
|---|---|---|---|---|---|
| RK-CARD-01 | User reads an AFib signal as a diagnosis or acts on it without a clinician | Cardiac data rendered with interpretation/alarm/trend framing | **Display-only lane (D9):** render the signal, route to cardiologist, no interpretation; `FR-NDG-06` forbidden-construction guard (designated control, blocking tests) | D9, FR-REG-03, FR-NDG-06 | **mitigated** (PR-5; T-NDG-02/03/06) |
| RK-GLU-01 | User changes insulin/treatment based on a glucose nudge | Dosing/treatment language in nudge output | No insulin/dosing surface in MVP (`FR-REG-04`); allow-list output only; `FR-NDG-06` guard | FR-REG-04, FR-NDG-06 | **mitigated** (PR-5; T-NDG-06) |
| RK-PROV-01 | Synthetic/estimate data mistaken for clinical truth | `provenance`/tier shown or clinical field accepts SIMULATED | `provenance` never renders (blocking file guard — CORRECTION 2026-07-03: recorded as "CI/unit guard, blocking" since PR-2/3, but the shell guard was wired to no CI/build step and was exiting 1 on wallet-receipt word collisions until 2026-07-03, when the pattern was scoped to the data field and the guard wired as a blocking `build-ios.sh` step, PR-102); clinical-tier entities reject SIMULATED at schema level | NFR-PRIV-05, DataModel v1 | **mitigated** (PR-2/PR-3; T-PROV-01 — designated control inert until 2026-07-03, corrected PR-102; T-DM-01). The substantive never-renders rule held throughout (audit-verified) |
