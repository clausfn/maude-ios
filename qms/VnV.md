# Verification & Validation (V&V)

_Test plan + results. Each safety-relevant requirement has at least one automated test referenced by ID. The `FR-NDG-06` guardrail and the provenance-never-renders guard are **blocking** (cannot be skipped or marked allow-fail). Version: 2026-06-03._

## Test index

| Test ID | Verifies | Type | Blocking? | Status |
|---|---|---|---|---|
| T-SIGN-01 | Signing identity resolves from `Config/Signing.xcconfig`; no hardcoded Team ID/bundle in tracked files | Manual + grep (see below) | No | **pass** (2026-06-03) |
| T-DM-01 | Clinical-tier rejects SIMULATED (validator + construction) | Unit (Swift Testing) | No | authored — run in Xcode |
| T-DM-02 | Glucose mg/dL→mmol/L conversion + round-trip (OD-07) | Unit | No | authored — run in Xcode |
| T-DM-03 | SwiftData schema loads and round-trips; clinical constructor sets clinical tier | Unit (`@MainActor`) | No | authored — run in Xcode |
| T-HK-RO-01 | `HealthKitService` share/write set is **empty** (read-only, `FR-ARCH-04`) | Unit | No | authored — run in Xcode (typechecks vs HK SDK) |
| T-HK-RO-02 | Full-capture read set present (MVP + insulin/AFib/BP/body-comp/heart panel), ≥20 types; write set stays empty | Unit | No | **pass** — iOS Sim (PR-46) |
| T-HK-RO-03 | Sleep stage mapping (REM/Deep/inBed) | Unit | No | authored — run in Xcode |
| T-MAP-01 | Mock→entity mapping preserves provenance; HRV+RHR merge per day | Unit (`@MainActor`) | No | authored — run in Xcode |
| T-MAP-02 | Re-sync of a window is idempotent (replace, not duplicate; union-bound delete) | Unit (`@MainActor`) | No | **pass** — iOS Sim (fixed PR-46) |
| T-NDG-01 | Nudge output is capped (≤4) | Unit | No | authored — run in Xcode (also executed via harness) |
| T-NDG-02 | AFib lane is display-only: routeToClinician, top priority | Unit | **Yes** | authored — run in Xcode (executed via harness) |
| T-NDG-03 | No AFib signal ⇒ no cardiac nudge | Unit | **Yes** | authored — run in Xcode (executed via harness) |
| T-NDG-04 | Only allow-listed categories emitted | Unit | No | authored — run in Xcode |
| T-NDG-05 | Baseline-relative: low-HRV day ⇒ recovery lever (fixture given realistic baseline variance) | Unit | No | **pass** — iOS Sim (fixed PR-46) |
| T-NDG-06 | Forbidden constructions (dose/treatment/dosing-verb/diagnosis/normality) all blocked | Unit (parameterized) | **Yes** | **pass** — executed this session |
| T-NDG-06b | Legitimate baseline-relative copy + disclaimers pass | Unit | **Yes** | **pass** — executed this session |
| T-NDG-06c | Every engine-authored nudge passes the guard | Unit | **Yes** | **pass** — executed this session |
| T-NDG-07 | Empty/sparse history fabricates nothing | Unit | No | authored — run in Xcode |
| T-BASE-01 | Baseline needs ≥3 points; bands at ±1σ | Unit | No | authored — run in Xcode |
| T-CTX-01 | Coordinate coarsened to ~0.1° before any request | Unit | No | **pass** — executed this session |
| T-CTX-02 | Request URLs carry only lat/lon + env fields (no health/identifiers) | Unit | No | **pass** — executed this session |
| T-CTX-03 | Mock weather provider returns a snapshot offline | Unit (async) | No | **pass** — executed this session |
| T-CTX-04 | Snapshot maps to `WeatherContext` with provenance EXTERNAL | Unit | No | authored — run in Xcode |
| T-PROV-01 | Provenance DATA FIELD (`.provenance` access, `provenance:` label, `Provenance` type/case) never referenced in any SwiftUI (view-layer) file | Shell guard (`scripts/guard_provenance.sh`), blocking step in `build-ios.sh` | **Yes** | **pass** (2026-07-03). CORRECTION (launch audit 2026-07-03): the 2026-06-03 "pass" was recorded while the guard was wired to no build/CI step (inert) and was in fact exiting 1 on wallet-receipt word collisions ("provenance receipt", UC-24b/UC-21 copy in JournalView/WalletView) — the record overstated the control. Fixed + wired 2026-07-03 (PR-102): pattern scoped to data-field usage, guard added to `build-ios.sh` before xcodebuild. The substantive never-renders rule held throughout (no view renders the field — audit-verified) |
| T-PROV-02 | `Provenance` is not `CustomStringConvertible` (no interpolatable label) | Unit | **Yes** | authored — run in Xcode |
| T-PROV-03 | `provenance` raw values stay machine tokens (REAL/SIMULATED/EXTERNAL) | Unit | No | authored — run in Xcode |
| T-ING-01 | Mock provider yields full read set, all SIMULATED | Unit (async) | No | authored — run in Xcode |
| T-ING-02 | Mock glucose is canonical mmol/L in plausible band | Unit | No | authored — run in Xcode |
| T-ING-03 | Mock generator is deterministic for a fixed seed | Unit | No | authored — run in Xcode |
| T-ING-04 | `LV001Provider` is inert without the `LV001_DEMO` flag | Unit | No | authored — run in Xcode |
| T-ING-05 | Factory wiring + `isDemoData` flag (FR-ARCH-05) | Unit | No | authored — run in Xcode |
| T-SBA-01 | Supabase password-grant body (`email`/`password`) | Unit (Swift Testing) | No | **pass** — iOS Simulator (2026-06-03) |
| T-SBA-02 | Apple `id_token`-grant body (`provider:apple`/`id_token`/`nonce`; nonce omitted when empty) | Unit | No | **pass** — iOS Simulator |
| T-SBA-03 | GoTrue token response parse (`access_token`+`user.id`/`email`+`refresh_token`; no token ⇒ nil) | Unit | No | **pass** — iOS Simulator |
| T-SBA-04 | GoTrue `/user` parse (`id`/`email`; empty ⇒ nil) | Unit | No | **pass** — iOS Simulator |
| T-SBA-05 | Apple nonce: SHA-256 deterministic + 64-hex; random nonce length + uniqueness | Unit | No | **pass** — iOS Simulator |
| T-ANCH-01..06 | EncryptedAnchorStore: round-trip, ciphertext-at-rest, per-key + per-user-scope isolation, wrong-DEK auth-fail, remove/clear | Unit | No | **pass** — iOS Simulator |
| T-ANCH-07 | `HKQueryAnchor ⇆ Data` secure-coding round-trip | Unit | No | **pass** — iOS Simulator |
| T-ANCH-08 | Fake-provider anchor-advances-on-sync (resume from prior cursor; no-new ⇒ unchanged) | Unit (async) | No | **pass** — iOS Simulator |

## PR-46/47 — full HealthKit capture + Design System v2 (2026-06-09)

Full-suite run on the iOS Simulator (iPhone 17, Xcode 26.4.1). **Claus cannot build
in Xcode (signing/destination issues on his side), so verification is run here:**
`xcodebuild build` + `xcodebuild test` + `simctl io screenshot` per change.

```
✔ xcodebuild build — BUILD SUCCEEDED (iOS Simulator, CODE_SIGNING_ALLOWED=NO)
✔ LiviqaTests — 78 tests in 19 suites, 0 failures
   incl. readSetIsFullCaptureSet (PR-46), reSyncIsIdempotent + baselineRelativeRecovery
   (both pre-existing failures, now green)
```

- **Zero new regressions from Step A** — proven by a baseline `git stash` run: the
  only two reds (`reSyncIsIdempotent`, `NudgeEngineTests`) were red on the clean
  tree *before* the change; the read-set-count test was the only test my change
  legitimately touched, and it was updated to `readSetIsFullCaptureSet`.
- **Read-only preserved:** T-HK-RO-01 (empty write set) unchanged; the wider read
  set is authorization-only.
- **Idempotency (T-MAP-02):** fixed via union-bound window delete; re-sync converges
  (was 48 glucose rows where 42 expected → now stable). No data dropped.
- **Regulated controls re-verified at the data layer:** insulin dose-blind
  (FR-REG-04), AFib display-only (T-NDG-02/03) — the new HealthKit reads add no
  rendering. Surfacing them (Step B) stays gated by FR-NDG-06 + RQ-01.
- **Design v2:** build green in both Paper and Midnight; Today screen screenshotted
  in both — the glucose arc now reads moss → clay (the two-state attention logic).
- **Real-device sanity (flagged, not yet verified):** SpO₂/body-fat percent scaling
  (×100 from HealthKit's fraction) and the VO₂max unit string `"ml/kg*min"` compile
  but want a glance against live values on Claus's device.

## T-SBA — Supabase Auth (GoTrue) parsing & V&V (PR-28)

Auth is **Supabase Auth (self-hosted GoTrue, EU)** (reverted from Ory; NFR-SEC-07
held — self-hosted EU, not Supabase Cloud). The request-body builders + response
parsers in `SupabaseAuthClient` are pure and were run in the iOS Simulator
(`SupabaseAuthParsingTests`, T-SBA-01..05). The backend verifies the Supabase JWT
(`jose`, HS256/JWKS, link-by-email) — covered backend-side. End-to-end against the
local backend uses the dev-token path (`DEV_AUTH=true`); real GoTrue login is a
deploy step (stand up `supabase/gotrue`, set `SUPABASE_JWT_SECRET`).

```
✔ SupabaseAuthParsingTests — 5/5
✔ EncryptedAnchorStoreTests (incl. anchor-advances), AnchorCodecTests
✔ NudgeGuard / Crypto / BackendMapping / PassportStats / Correlation
Test run: 8 suites passed (iOS 17 Simulator, Xcode 26.4.1)
```

## T-SIGN-01 — procedure & result (PR-1)

```sh
# 1. No hardcoded identity in tracked source/config:
grep -rn "G8MHRNS97R\|me.clausfnielsen" \
  --include='*.pbxproj' --include='*.plist' --include='*.entitlements' --include='*.swift' .
#    → expected: no matches  ✓

# 2. Real Team ID lives ONLY in the gitignored local xcconfig:
git check-ignore Config/Signing.xcconfig   # → Config/Signing.xcconfig  ✓

# 3. Settings resolve through the xcconfig:
xcodebuild -showBuildSettings -project Liviqa.xcodeproj -scheme Liviqa -configuration Debug \
  | grep -E "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|APP_GROUP|CODE_SIGN_ENTITLEMENTS"
#    → PRODUCT_BUNDLE_IDENTIFIER = dev.liviqa.app
#      DEVELOPMENT_TEAM          = G8MHRNS97R
#      APP_GROUP                 = group.dev.liviqa.app
#      CODE_SIGN_ENTITLEMENTS    = Liviqa/Liviqa.entitlements   ✓
```

Result: **pass** on Xcode 26.4.1 (2026-06-03).

## T-PROV-01 — procedure & result (PR-3)

```sh
bash scripts/guard_provenance.sh Liviqa
#   → ✓ provenance-never-renders guard passed (T-PROV-01)
```

Result: **pass** (2026-06-03). Greps every file importing SwiftUI for the word
`provenance`; fails the build on any hit. Wired as a required CI check (below).

CORRECTION (launch audit 2026-07-03, PR-102): the record above is kept for
history but was wrong on both counts by audit time — the guard was wired to no
build/CI step (inert; "wired as a required CI check" was never true, see the
corrected CI note below) and the bare-word pattern was exiting 1 on
wallet-receipt product vocabulary ("provenance receipt", UC-24b/UC-21 copy in
`JournalView`/`WalletView`). Fixed 2026-07-03: pattern scoped to the provenance
DATA FIELD (`.provenance` access, `provenance:` label, `Provenance` type/case),
guard wired as a blocking `build-ios.sh` step before xcodebuild. Re-run
2026-07-03: **pass** (green on the tree; red on a data-field fixture; green on a
receipt-vocabulary fixture). The substantive never-renders rule held throughout.

## T-NDG-06 — procedure & result (PR-5)

The FR-NDG-06 guard + engine were compiled and **executed** this session via a
standalone harness (`swiftc` over `CoreTypes`, `HealthSamples`, `NudgeModel`,
`NudgeGuard`, `NudgeEngine`), since the intelligence layer is pure Foundation:

```
== NudgeGuard (FR-NDG-06) ==  all 7 forbidden strings blocked; all 7 legit pass
   (incl. "This is not a diagnosis." and "6.4 mmol/L" → clean)
== NudgeEngine ==  capped at 4; all outputs pass FR-NDG-06;
   AFib ⇒ displayOnly/routeToClinician @priority 100 (survives cap)
ALL HARNESS CHECKS PASSED
```

The Swift Testing suites (`NudgeGuardTests`, `NudgeEngineTests`) mirror these and
re-run in Xcode. T-NDG-06/06b/06c and T-NDG-02/03 are required, non-skippable.

## CI note (later)
A GitHub Actions workflow (PR-3+) runs lint + build + test on every PR; `T-NDG-06`
and `T-PROV-01` are configured as required, non-skippable checks.

CORRECTION (launch audit 2026-07-03, PR-102): the note above never became true —
no `.github/workflows/` exists in this repo (audit-verified: 0 workflows, 0
hooks, 0 `PBXShellScriptBuildPhase` entries). Actual enforcement as of
2026-07-03: `T-PROV-01` runs as a blocking step in `build-ios.sh` (before
xcodebuild; `set -e` aborts the build); `T-NDG-06*` suites run in Xcode.
Standing up real CI with both as required checks remains an open owner action.
