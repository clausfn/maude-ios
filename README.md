# maude-ios

**Maude** — Claus F. Nielsen's private command centre. Native iOS (Swift/SwiftUI), Watch app,
widgets. Owner: **PPCN.xyz ApS**. One user. Never placed on the market.

Health, oversight and money in one app that keeps working when no Claude session is attached.

## Where this came from

Forked from `clausfn/liviqa-ios` at branch `develop`, build **10.106** (commit `1116069`,
29 Aug 2026) — the live TestFlight build. Liviqa is owned by the **Data for Good Foundation**
and remains DfG's product. Maude is a separate PPCN-owned application that starts from that
engineering base. See `PROVENANCE.md`.

The two must not converge again: DfG identity, branding and product surfaces are being removed
from this repo — see `DFG_SEPARATION.md` for what is still present.

## Identity

| | |
|---|---|
| Bundle id | `xyz.ppcn.maude` |
| App group | `group.xyz.ppcn.maude` |
| Watch | `xyz.ppcn.maude.watchkitapp` |
| Team | set `DEVELOPMENT_TEAM` in `Config/Signing.xcconfig` — the PPCN/personal team, **never** `PS258XSNL8` (Fonden Data For Good) |
| Version | 0.1 (1) — new App ID, new build lineage |

The predecessor App ID `xyz.ppcn.liviqa` already carried HealthKit and Sign in with Apple, and
was registered in the Supabase Apple audience. `xyz.ppcn.maude` needs those two steps once.

## Build

```bash
cp Config/Signing.example.xcconfig Config/Signing.xcconfig   # then fill DEVELOPMENT_TEAM
./build-ios.sh
```

`build-ios.sh` runs three blocking guards before compiling: the provenance-never-renders guard,
the donation-is-an-export guard, and the dead-CTA guard. Do not disable them.

## Rules that carry over unchanged

- iOS first, Android-ready. No iOS-only abstractions in core logic.
- On-device by default. HealthKit **read-only**, empty write set. Local store AES-256 + Secure Enclave.
- Nudge engine on-device, personal-baseline-relative, output allow-list only.
- AFib lane is display-only and routes to a cardiologist. Guardrail FR-NDG-06 is a designated
  control — never skip its tests.
- Glucose canonical unit mmol/L. GMI is the HbA1c headline.
- `provenance{REAL,SIMULATED,EXTERNAL}` is a data field and must never render on any screen.
- No insulin dose is ever computed. Not disabled — absent.

## Rules that change

- **Owner is PPCN, not DfG.** No DfG logo, name, wallet or donation programme in shipped UI.
- **One user.** No MDR, no QMS gate on release, no App Store. Distribution is Ad Hoc.
  The `/qms/` history is kept as engineering record, not as a regulatory obligation.
- **Stealth posture is ACTIVE.** Nothing about this app goes external.
