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
| T-HK-RO-02 | Read set = MVP 7 types | Unit | No | authored — run in Xcode |
| T-HK-RO-03 | Sleep stage mapping (REM/Deep/inBed) | Unit | No | authored — run in Xcode |
| T-MAP-01 | Mock→entity mapping preserves provenance; HRV+RHR merge per day | Unit (`@MainActor`) | No | authored — run in Xcode |
| T-MAP-02 | Re-sync of a window is idempotent (replace, not duplicate) | Unit (`@MainActor`) | No | authored — run in Xcode |
| T-NDG-01 | Nudge output is capped (≤4) | Unit | No | authored — run in Xcode (also executed via harness) |
| T-NDG-02 | AFib lane is display-only: routeToClinician, top priority | Unit | **Yes** | authored — run in Xcode (executed via harness) |
| T-NDG-03 | No AFib signal ⇒ no cardiac nudge | Unit | **Yes** | authored — run in Xcode (executed via harness) |
| T-NDG-04 | Only allow-listed categories emitted | Unit | No | authored — run in Xcode |
| T-NDG-05 | Baseline-relative: low-HRV day ⇒ recovery lever | Unit | No | authored — run in Xcode |
| T-NDG-06 | Forbidden constructions (dose/treatment/dosing-verb/diagnosis/normality) all blocked | Unit (parameterized) | **Yes** | **pass** — executed this session |
| T-NDG-06b | Legitimate baseline-relative copy + disclaimers pass | Unit | **Yes** | **pass** — executed this session |
| T-NDG-06c | Every engine-authored nudge passes the guard | Unit | **Yes** | **pass** — executed this session |
| T-NDG-07 | Empty/sparse history fabricates nothing | Unit | No | authored — run in Xcode |
| T-BASE-01 | Baseline needs ≥3 points; bands at ±1σ | Unit | No | authored — run in Xcode |
| T-PROV-01 | `provenance` never appears in any SwiftUI (view-layer) file | Shell guard (`scripts/guard_provenance.sh`) | **Yes** | **pass** (2026-06-03) |
| T-PROV-02 | `Provenance` is not `CustomStringConvertible` (no interpolatable label) | Unit | **Yes** | authored — run in Xcode |
| T-PROV-03 | `provenance` raw values stay machine tokens (REAL/SIMULATED/EXTERNAL) | Unit | No | authored — run in Xcode |
| T-ING-01 | Mock provider yields full read set, all SIMULATED | Unit (async) | No | authored — run in Xcode |
| T-ING-02 | Mock glucose is canonical mmol/L in plausible band | Unit | No | authored — run in Xcode |
| T-ING-03 | Mock generator is deterministic for a fixed seed | Unit | No | authored — run in Xcode |
| T-ING-04 | `LV001Provider` is inert without the `LV001_DEMO` flag | Unit | No | authored — run in Xcode |
| T-ING-05 | Factory wiring + `isDemoData` flag (FR-ARCH-05) | Unit | No | authored — run in Xcode |

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
