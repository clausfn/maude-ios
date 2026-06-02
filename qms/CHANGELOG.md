# QMS Change Log

_One entry per release/PR that touches a requirement or risk control. Maps to git tags. Conventional Commits. Version: 2026-06-03._

## [Unreleased] — develop

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
