# QMS Change Log

_One entry per release/PR that touches a requirement or risk control. Maps to git tags. Conventional Commits. Version: 2026-06-03._

## [Unreleased] — develop

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
