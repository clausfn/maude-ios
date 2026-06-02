# Requirements Trace Matrix (RTM)

_QMS-lite spine. One row per requirement: SRS FR-/NFR- ID → design element → test ID → status. Kept at IEC 62304 Class B rigour. Version: 2026-06-03._

Status legend: `planned` · `in-progress` · `implemented` · `verified`.

| Req ID | Title | Design element (file) | Test ID | Status | PR |
|---|---|---|---|---|---|
| D-STORE | Deployment-agnostic signing; account swap = config change | `Config/Signing.xcconfig`, `Config/Signing.example.xcconfig`, `Liviqa.xcodeproj/project.pbxproj`, `docs/SIGNING.md` | T-SIGN-01 | verified | PR-1 |
| FR-ARCH-04 | Read-only HealthKit (never write) | `Liviqa/Liviqa.entitlements` (HK enabled), `Info.plist` (NSHealthShareUsageDescription); read-only enforced in code | T-HK-RO-01 | in-progress (entitlement + usage string set; empty write set enforced in `HealthKitService`, PR-4) | PR-1 |
| FR-QMS-01 | Intended-use statement under version control | _pending_ `docs/INTENDED_USE.md` | — | planned | — |
| FR-QMS-02 | Living ISO 14971 risk file | `qms/RISK.md` | — | in-progress | PR-1 |
| FR-QMS-03 | Requirement ↔ test traceability for all FR/NFR/DM | `qms/RTM.md` (this file) | — | in-progress | PR-1 |
| FR-QMS-05 | Phase-2 docs + changelogs as DHF skeleton | `qms/DHF.md`, `qms/CHANGELOG.md`, `qms/VnV.md` | — | in-progress | PR-1 |
| DataModel v1 §2.1 | Typed sample sources (12 entities) carry source/tier/provenance | `Liviqa/Models/Domain/Entities.swift` | T-DM-03 | implemented (tests authored; run in Xcode) | PR-2 |
| DataModel v1 §2.1 | Clinical-tier rejects SIMULATED (schema gate + type-level `ClinicalProvenance`) | `Liviqa/Models/Domain/CoreTypes.swift` | T-DM-01 | implemented | PR-2 |
| OD-07 / FR-ING-06 | Glucose canonical mmol/L (GMI = HbA1c headline) | `CoreTypes.swift` (`GlucoseUnit`), `GlucoseSample.mmol` | T-DM-02 | implemented | PR-2 |
| OD-09 | On-device SwiftData store, file-protection complete | `Liviqa/Models/Domain/Persistence.swift` | T-DM-03 | implemented (store FP-complete; DEK key-wrap = `Security/`) | PR-2/PR-8 |
| NFR-PRIV-01 | Samples never sync to cloud (`cloudKitDatabase: .none`) | `Persistence.swift` | — | implemented | PR-2 |
| FR-ING-01 | MVP read set (HRV-SDNN, RHR, steps, active energy, glucose, sleep, workouts) modelled as value readings | `Liviqa/Ingestion/HealthSamples.swift` | T-ING-01, T-ING-02 | implemented | PR-3 |
| FR-ING-07 | Single `HealthSamples` aggregate; no network-upload method on provider/types | `HealthSamples.swift`, `HealthDataProvider.swift` | T-ING-01 | implemented | PR-3 |
| FR-ARCH-04 | Read-only: HealthKit share/write set is **empty**; no write method anywhere | `Liviqa/Ingestion/HealthKitService.swift` (`shareTypes = []`), `HealthDataProvider.swift` | T-HK-RO-01 | implemented (typechecks vs HK SDK; unit run in Xcode) | PR-4 |
| FR-ARCH-04 / NFR-PRIV-01 | Outbound data is derived daily aggregates only, scoped to consent, encrypted — never raw samples / provenance / source | `Liviqa/Sharing/ShareBundle.swift`, `ShareBundleBuilder.swift`, `SecureShareExporter.swift` | T-SHARE-01..05 | implemented (11/11 checks pass) | PR-9 |
| FR-ING-02..05 | Concrete HealthKit reads (glucose mmol/L, HRV/RHR, steps, energy, sleep, workouts) | `HealthKitService.swift` | T-HK-RO-02/03 | implemented | PR-4 |
| FR-ING-09 | L1→L2 normalization + idempotent persistence into SwiftData | `Liviqa/Ingestion/IngestionCoordinator.swift` (`SampleMapper`) | T-MAP-01, T-MAP-02 | implemented (run in Xcode) | PR-4 |
| FR-NDG-01..05 | On-device heuristic nudge engine; baseline-relative; capped allow-list output | `Liviqa/Intelligence/NudgeEngine.swift`, `NudgeModel.swift` | T-NDG-01/04/05/07 | implemented (compiled + executed via swiftc) | PR-5 |
| FR-NDG-06 | Forbidden-construction guard (no dose/diagnosis/normality), **BLOCKING** | `Liviqa/Intelligence/NudgeGuard.swift` | T-NDG-06/06b/06c | **implemented & passing** (executed this session) | PR-5 |
| D9 / FR-REG-03 | AFib/cardiac lane is display-only: route-to-clinician, no interpretation | `NudgeEngine.afibNudge`, `RegulatoryLane.displayOnly` | T-NDG-02, T-NDG-03 | implemented | PR-5 |
| L3 lane map | Each stream tagged with its regulatory lane | `RegulatoryLane` (wellness/watch/constrained/displayOnly) | T-NDG-04 | implemented | PR-5 |
| FR-CTX-01 | Open-Meteo weather + AQI; coarse (~0.1°) coordinate, per-session, no health egress | `Liviqa/Context/OpenMeteoWeatherProvider.swift`, `WeatherContext.swift` | T-CTX-01/02/03 | implemented (executed via swiftc) | PR-6 |
| FR-CTX-02 | Weather snapshot persists as `WeatherContext`, provenance EXTERNAL | `Liviqa/Context/WeatherContextMapper.swift` | T-CTX-04 | implemented (run in Xcode) | PR-6 |
| FR-ARCH-05 | "Demo data" indicator source flag (mock = demo) + UI badge | `HealthDataProvider.swift` (`DataProviderKind.isDemoData`); `AppState.isDemoData`; `TodayView` badge | T-ING-05 | implemented (data flag + UI badge) | PR-7 |
| INT-L1L3 | Live L1→L2→L3 feed wired to Today screen | `AppState.refreshFromHealth()`; `EngineNudge+Card.swift`; `MainTabView` | (UI; user-verified) | implemented | PR-7 |
| NFR-PORT-01 | L1 ingestion portable (framework-free value types, provider protocol) | `Liviqa/Ingestion/*` | T-ING-01..05 | implemented | PR-3 |
| NFR-PRIV-05 / build-rule | `provenance` never renders (file guard + type guard, **blocking**) | `scripts/guard_provenance.sh`, `ProvenanceGuardTests.swift` | T-PROV-01, T-PROV-02, T-PROV-03 | implemented (file guard green; type tests run in Xcode) | PR-3 |

## Upcoming (tracked, not yet implemented)

| Req ID | Title | Target PR |
|---|---|---|
| NFR-SEC-02 / OD-09 | Secure Enclave key-wrapping + AES-256 verification | `Liviqa/Security/CryptoCore.swift`, `Liviqa/Security/KeyVault.swift` | T-SEC-01..06 | implemented (10/10 checks pass; SE w/ software fallback) | PR-8 |
| OD-07 reconcile | Migrate locked `MetricSnapshot.glucoseMgdl` (journal sync + Supabase col) to mmol/L | later (touches sync schema) |
