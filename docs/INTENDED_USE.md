# Maude — Intended Use Statement (v01, 2026-06-03)

_FR-QMS-01. Version-controlled intended-use / boundary-of-use statement for the
Maude citizen iOS app. Read with `qms/RISK.md` and the SRS._

## What Maude is
A privacy-first **wellness and self-knowledge** app. It reads the user's own
health/activity data on device (Apple HealthKit), runs an on-device engine, and
surfaces short, plain-language, **personal-baseline-relative** observations
("nudges") plus trends and a private journal. The user may optionally share a
**derived, consented** summary with a care recipient.

## What Maude is NOT
- **Not a medical device.** It does not diagnose, treat, cure, or prevent disease,
  and does not provide clinical decision-making.
- **No diagnostic or normality verdicts.** Output is baseline-relative only; the
  `NudgeGuard` control (FR-NDG-06, blocking) forbids dose quantities, dosing
  verbs, treatment directives, diagnostic claims, and "normal/abnormal" verdicts.
- **No dosing / treatment guidance.** There is no insulin or medication dosing
  surface (FR-REG-04).
- **Cardiac is display-only.** Any AFib/heart-rhythm signal is shown without
  interpretation and routes the user to their clinician (D9 / FR-REG-03); Maude
  states it does not interpret heart rhythm.

## Intended users
Health-engaged adults tracking their own data (the founder chronic-condition
persona is the design anchor). Not intended for use by clinicians as a diagnostic
tool, nor for emergencies.

## Safety boundary
Observations are wellness-grade (±1σ around the user's own history), not clinical
thresholds. Users are told a pattern is "in your own data — not a medical finding"
and to discuss anything concerning with a qualified professional. In an emergency,
contact local emergency services — Maude is not for urgent or emergency care.

## Data & privacy posture
Processing is on-device by default; raw HealthKit samples never leave the device.
Any sharing is explicit, per-recipient, derived-only, and revocable. EU-sovereign
infrastructure on any real-PII path (NFR-SEC-07).

## Regulatory framing
Positioned as a wellness/lifestyle app outside the EU MDR medical-device
definition by virtue of the boundaries above. Any future feature that crosses
into a medical-device claim requires regulatory review before release (see the
AFib-nudge open decision, D9).

## TestFlight note
Beta builds carry the same boundaries. Beta App Review notes and onboarding must
not imply diagnosis or treatment. Synthetic cohort data only for external testers.
