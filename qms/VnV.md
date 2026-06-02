# Verification & Validation (V&V)

_Test plan + results. Each safety-relevant requirement has at least one automated test referenced by ID. The `FR-NDG-06` guardrail and the provenance-never-renders guard are **blocking** (cannot be skipped or marked allow-fail). Version: 2026-06-03._

## Test index

| Test ID | Verifies | Type | Blocking? | Status |
|---|---|---|---|---|
| T-SIGN-01 | Signing identity resolves from `Config/Signing.xcconfig`; no hardcoded Team ID/bundle in tracked files | Manual + grep (see below) | No | **pass** (2026-06-03) |
| T-DM-01 | Clinical-tier rejects SIMULATED (validator + construction) | Unit (Swift Testing) | No | authored — run in Xcode |
| T-DM-02 | Glucose mg/dL→mmol/L conversion + round-trip (OD-07) | Unit | No | authored — run in Xcode |
| T-DM-03 | SwiftData schema loads and round-trips; clinical constructor sets clinical tier | Unit (`@MainActor`) | No | authored — run in Xcode |
| T-HK-RO-01 | `HealthKitService` requests an **empty** write set (read-only, `FR-ARCH-04`) | Unit | No | planned (PR-4) |
| T-NDG-06 | Nudge bodies pass the forbidden-construction list (diagnosis/dose/normative claims) | Unit | **Yes** | planned (PR-5) |
| T-PROV-01 | `provenance` field never reaches a user-facing surface | Unit + CI grep guard | **Yes** | planned (PR-3) |

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

## CI note (later)
A GitHub Actions workflow (PR-3+) runs lint + build + test on every PR; `T-NDG-06`
and `T-PROV-01` are configured as required, non-skippable checks.
