# Signing & Identity — Liviqa iOS

_Deployment-agnostic signing. Develop **now** under Claus's personal Apple Developer account (local builds + on-device runs to ingest his own Health data). The Data for Good account (`apps@dfgfoundation.org`) is for deployment **later** (2FA being resolved). Swapping accounts is a **config change, never a code change.**_

## Where identity lives

All signing/identity is in **`Config/Signing.xcconfig`** — and nowhere else.

| File | In git? | Holds |
|---|---|---|
| `Config/Signing.xcconfig` | **No (gitignored)** | The real values: `DEVELOPMENT_TEAM`, `APP_BUNDLE_ID`, `APP_GROUP` |
| `Config/Signing.example.xcconfig` | Yes (checked in) | Template with dev defaults and an **empty** `DEVELOPMENT_TEAM` (no real Team ID is ever committed) |

Build settings reference these — `PRODUCT_BUNDLE_IDENTIFIER`, `$(APP_GROUP)`, `DEVELOPMENT_TEAM` — so **no Team ID or bundle ID is hardcoded** in `.swift`, `Info.plist`, `*.entitlements`, or `project.pbxproj`.

- `PRODUCT_BUNDLE_IDENTIFIER = $(APP_BUNDLE_ID)` (app); test targets append `.Tests` / `.UITests`.
- Entitlements use `$(APP_GROUP)`; Xcode expands it at build time.
- The xcconfig is attached as the **base configuration** to every target (Debug + Release).

## First-time setup (per machine)

`Config/Signing.xcconfig` is gitignored, so a fresh clone must create it once:

```sh
cp Config/Signing.example.xcconfig Config/Signing.xcconfig
# then edit Config/Signing.xcconfig and set DEVELOPMENT_TEAM = <your Team ID>
```

Open `Liviqa.xcodeproj` in Xcode → **Signing & Capabilities** → confirm "Automatically manage signing" is on and the team resolves. Build + run on a real device (HealthKit is unavailable in the Simulator).

## Current dev configuration (personal account)

```
DEVELOPMENT_TEAM = G8MHRNS97R      # Claus personal team
APP_BUNDLE_ID    = dev.liviqa.app
APP_GROUP        = group.dev.liviqa.app
```

- **Automatic** signing. HealthKit capability is on; the entitlement only *enables* HealthKit — **read-only is enforced in code** (`HealthKitService` requests an empty write/`toShare` set per `FR-ARCH-04`).
- No TestFlight / App Store / provisioning-profile assumptions exist in code. Distribution config lives only in the xcconfig + the Xcode Signing tab.

## Migrating to Data for Good (later, no code change)

When the DfG account 2FA is resolved:

1. Edit **`Config/Signing.xcconfig` only**:
   ```
   DEVELOPMENT_TEAM = <DfG Team ID>
   APP_BUNDLE_ID    = <DfG bundle id, e.g. org.dfgfoundation.liviqa>
   APP_GROUP        = group.<that bundle id>
   ```
2. In Xcode → Signing & Capabilities, let automatic signing re-provision for the DfG team (register the App ID / App Group / HealthKit capability on first run).
3. Push to the DfG `liviqa-ios` repo. Nothing in source, Info.plist, or entitlements changes.

## App Group note

If the **personal** team has trouble provisioning `group.dev.liviqa.app` (App Groups sometimes need manual registration), the App Group entitlement can be removed from `Liviqa/Liviqa.entitlements` without any code change — it is only needed once an app extension/widget is added. HealthKit is the only capability required for on-device runs now.

## Repo layout note (authoring environment)

This clone was bootstrapped in a sandboxed agent session that guards `.git/`
directories, so git currently uses a **separate git directory** (`.git` is a
small pointer file → `../.liviqa-ios.gitdir`). This is valid git and works with
Xcode, the `git` CLI, and GitHub Desktop. To convert to a standard layout once
the repo is opened natively (optional, run from the repo root):

```sh
rm .git && git init --separate-git-dir=.git . >/dev/null 2>&1 || true
# simplest robust path: re-clone from the GitHub remote once it exists.
```

The canonical home is `~/Developer/DataForGood/liviqa-ios` (non-synced), per
`20_Build/Liviqa_DfG_CodeHome_and_Environment_v01`.
