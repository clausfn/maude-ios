# Provenance

| | |
|---|---|
| Fork source | `clausfn/liviqa-ios`, branch `develop` |
| Fork commit | `1116069` — *qms: log 4 new TestFlight feedback items (10.106) awaiting CN approval* |
| Fork date | 7 September 2026 |
| Source build | TestFlight 10.106 |
| Source owner | Data for Good Foundation |
| New owner | PPCN.xyz ApS |

Full upstream git history is preserved in this repository. Every commit before the fork commit
belongs to the Liviqa lineage and was authored under DfG ownership.

## What the fork commit changed

1. Every `Liviqa` / `liviqa` / `LIVIQA` identifier, path, type and string renamed to `Maude`
   across 339 files and 6 directories.
2. Bundle identifiers rewritten: `dev.liviqa.app` and `xyz.ppcn.liviqa` to `xyz.ppcn.maude`;
   app group to `group.xyz.ppcn.maude`.
3. `DEVELOPMENT_TEAM = PS258XSNL8` (Fonden Data For Good) removed from all targets and from
   `ExportOptions.plist`; the team now comes from `Config/Signing.xcconfig`.
4. Build lineage reset — `CURRENT_PROJECT_VERSION` 10.106 to 1, `MARKETING_VERSION` 1.0 to 0.1,
   because this is a new App ID with no TestFlight history.
5. Identity documents rewritten: `README.md`, `CLAUDE.md`, this file, `DFG_SEPARATION.md`.

No source logic was altered. The app that builds from this commit is functionally Liviqa 10.106
under a different name and signing identity.

## What was deliberately NOT done

DfG's product surfaces — the consent wallet, the donation programme, research participation,
MitID identity verification and the DfG onboarding flow — are still present and still carry DfG
naming. Removing them is a separate, reviewed change. See `DFG_SEPARATION.md`.
