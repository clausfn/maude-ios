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

## Upcoming (tracked, not yet implemented)

| Req ID | Title | Target PR |
|---|---|---|
| FR-ING-01..13 | HealthKit ingestion (read-only set) behind `HealthDataProvider` | PR-3/PR-4 |
| FR-NDG-06 | Forbidden-construction guardrail (designated control; **blocking** tests) | PR-5 |
| NFR-PRIV-05 / build-rule | `provenance` never renders (CI/unit guard, **blocking**) | PR-3 |
| OD-07 / FR-ING-06 | Glucose canonical mmol/L | PR-2 |
| NFR-SEC-02 / OD-09 | Local store encrypted (SwiftData + Secure Enclave, AES-256) | PR-2/PR-7 |
| D9 / FR-REG-03 | AFib lane display-only, route-to-cardiologist | PR-5 |
