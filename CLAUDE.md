# liviqa-ios — agent instructions
- iOS first, Android-ready. No iOS-only abstractions in core logic.
- On-device only by default. HealthKit READ-ONLY (empty write set). Local store AES-256 + Secure Enclave.
- Nudge engine: on-device, personal-baseline-relative, output allow-list only. AFib lane = display-only, route-to-cardiologist (D9). Guardrail FR-NDG-06 is a designated control — never skip its tests.
- Glucose canonical unit mmol/L (OD-07). GMI = HbA1c headline.
- provenance{REAL,SIMULATED,EXTERNAL} is a DATA field — must NEVER render on any screen.
- Every new FR-/NFR- gets a /qms/RTM.md row before merge. Safety-path change → /qms/RISK.md touch.
- Brand locked: iris mark, SF Pro (+ IBM Plex Mono for numbers/kickers), A6 "Daylight" six-colour palette. Aperture mark + Lato retired 2026-06-17 (PR-96 re-skin). Extend the prototype; do not redesign.
