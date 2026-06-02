# Risk Register (ISO 14971-aligned)

_Hazard → cause → mitigation → residual risk → linked requirement. Cardiac/glucose/medication lanes carry the top entries. Safety-path code changes require a row here (or an explicit "no new hazard" PR note). Version: 2026-06-03._

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
| RK-PROV-01 | Synthetic/estimate data mistaken for clinical truth | `provenance`/tier shown or clinical field accepts SIMULATED | `provenance` never renders (CI/unit guard, blocking); clinical-tier entities reject SIMULATED at schema level | NFR-PRIV-05, DataModel v1 | **mitigated** (PR-2/PR-3; T-PROV-01, T-DM-01) |
