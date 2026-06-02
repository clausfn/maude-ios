# Design History File — Index (DHF)

_Append-only dated log of design decisions, linked to the Architecture Decision Register (D1–D10, D-*). Ports to ISO 13485 §7.3. Version: 2026-06-03._

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
