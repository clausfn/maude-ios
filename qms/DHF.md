# Design History File — Index (DHF)

_Append-only dated log of design decisions, linked to the Architecture Decision Register (D1–D10, D-*). Ports to ISO 13485 §7.3. Version: 2026-06-03._

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
