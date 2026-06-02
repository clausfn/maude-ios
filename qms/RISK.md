# Risk Register (ISO 14971-aligned)

_Hazard → cause → mitigation → residual risk → linked requirement. Cardiac/glucose/medication lanes carry the top entries. Safety-path code changes require a row here (or an explicit "no new hazard" PR note). Version: 2026-06-03._

## PR-1 — no new hazard

PR-1 is signing/identity configuration and repo relocation only. It introduces
**no analytical, clinical, or data-path code** and therefore **no new hazard**.
Logged per the QMS-lite "no safety-relevant change without a risk touch" rule.

## Pre-seeded top hazards (structure in place; mitigations land with their PRs)

| ID | Hazard | Cause | Planned mitigation | Linked req | Status |
|---|---|---|---|---|---|
| RK-CARD-01 | User reads an AFib signal as a diagnosis or acts on it without a clinician | Cardiac data rendered with interpretation/alarm/trend framing | **Display-only lane (D9):** render the signal, route to cardiologist, no interpretation; `FR-NDG-06` forbidden-construction guard (designated control, blocking tests) | D9, FR-REG-03, FR-NDG-06 | planned (PR-5) |
| RK-GLU-01 | User changes insulin/treatment based on a glucose nudge | Dosing/treatment language in nudge output | No insulin/dosing surface in MVP (`FR-REG-04`); allow-list output only; `FR-NDG-06` guard | FR-REG-04, FR-NDG-06 | planned (PR-5) |
| RK-PROV-01 | Synthetic/estimate data mistaken for clinical truth | `provenance`/tier shown or clinical field accepts SIMULATED | `provenance` never renders (CI/unit guard, blocking); clinical-tier entities reject SIMULATED at schema level | NFR-PRIV-05, DataModel v1 | planned (PR-2/PR-3) |
