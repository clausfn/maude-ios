# maude-ios — agent instructions

**Maude is PPCN's, one user, never sold.** Forked from Liviqa 10.106 (see `PROVENANCE.md`).
Liviqa belongs to Data for Good. Never merge the two, never carry DfG branding into shipped UI,
never push a Maude commit to `clausfn/liviqa-ios`.

## Engineering rules (carried over — do not relax)

- iOS first, Android-ready. No iOS-only abstractions in core logic.
- On-device only by default. HealthKit READ-ONLY (empty write set). Local store AES-256 + Secure Enclave.
- Nudge engine: on-device, personal-baseline-relative, output allow-list only. AFib lane =
  display-only, route-to-cardiologist (D9). Guardrail FR-NDG-06 is a designated control — never
  skip its tests.
- Glucose canonical unit mmol/L (OD-07). GMI = HbA1c headline.
- `provenance{REAL,SIMULATED,EXTERNAL}` is a DATA field — must NEVER render on any screen.
- Visual system A7 "Morning/Evening Edition" (`Theme.swift` v03): plaster/fjord palette, Charter
  serif verdicts, SF Pro body, IBM Plex Mono numbers; evening = deep marine. Extend, do not redesign.
- `build-ios.sh` runs three blocking guards. Never disable one to get a green build.

## Rules that changed with the fork

- `/qms/` is kept as engineering record and changelog. It is **not** a regulatory gate: one user,
  no market placement, no MDR. Do not add release-blocking QMS ceremony.
- Distribution is **TestFlight, internal testing only** (CN, 2026-09-07 — this reverses the
  earlier Ad Hoc rule). Never App Store review, never public. `.github/workflows/release.yml`
  is manual-dispatch only; `docs/TESTFLIGHT.md` is the setup.
- **Signed by PPCN's Apple Developer account** (CN, 2026-09-07), never Data for Good's and
  never a personal one. One bundle, `xyz.ppcn.maude`. The Team ID lives only in the
  `APPLE_TEAM_ID` repository secret and the git-ignored `Config/Signing.xcconfig`.
- **The shipped build talks to no server.** `Config.backend` is `.mock` in every configuration,
  and `ReleasePosture.verify()` crashes on launch if a Release build ever resolves to a
  sovereign backend — those hosts (`api.maude.app`, `auth.maude.app`) are Data for Good's.
- No insulin dose and no order placement may exist in this codebase at all — absent, not disabled.
- One unconditional safety rule survives, for the owner's sake rather than a regulator's: symptoms
  suggesting DKA, stroke on an AFib background, or NET red flags stop everything and say go now.

## What Maude adds beyond Liviqa

Oversight and money, on top of the health app that already works: zones (MGMT, DK, TH, PROJ:*,
LIVIQA, DFG-ORG, DFG-PRO, MIT, PERSONAL, HEALTH, FAMILY, KARCH, LEGACY), a park watchdog,
deadline countdowns, a ClickUp mirror, and a Danica Select wrapper model. Build these as new
modules; do not bend the health domain to fit them.

## Talking to Claus

He is not a programmer and does not read code, diffs or terminal output. Lead with what changed
for him and what he must do. Plain English. End with something he can click or see. Report every
phase in four blocks: Done, Skipped or failed, Needs you, Next.
