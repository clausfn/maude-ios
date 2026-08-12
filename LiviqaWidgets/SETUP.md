# Liviqa Widgets + Complication — Xcode setup (one-time)

**FR-WID-01 · Bevel absorb ① · 2026-08-13**

All the Swift is written and type-checked. What is missing is two **targets**, which
must be created in Xcode: `Liviqa.xcodeproj/project.pbxproj` is deliberately never
hand-edited in this repo (`qms/CHANGELOG.md`, `LiviqaWatch/README_SETUP.md §6`), and
a WidgetKit `@main` cannot live in the app target.

Everything below is a literal click-path. Roughly 15 minutes for both targets.

> **Blocking prerequisite — read §1 before you start.** Under the current PPCN beta
> signing profile the App Group is *not* provisioned, and without it the widgets
> render their honest empty state and nothing else. That is a signing decision, not
> a code bug.

---

## 0. What already exists

| Path | What it is | Goes into |
|---|---|---|
| `LiviqaWidgets/Shared/LiviqaWidgetSnapshot.swift` | the snapshot type + App-Group store | app · iOS widget · watch complication |
| `LiviqaWidgets/Shared/WidgetCopy.swift` | every static user-facing string | app · iOS widget · watch complication |
| `LiviqaWidgets/App/WidgetSnapshotPublisher.swift` | app-side writer + FR-NDG-06 gate | **app only** |
| `LiviqaWidgets/Widget/LiviqaWidgetBundle.swift` | the `@main` widget bundle | **iOS widget only** |
| `LiviqaWidgets/Widget/EditionWidget.swift` | entry + `TimelineProvider` + `Widget` | **iOS widget only** |
| `LiviqaWidgets/Widget/EditionWidgetViews.swift` | small + medium layouts | **iOS widget only** |
| `LiviqaWidgets/Tests/LiviqaWidgetSnapshotTests.swift` | T-WID-01…06 | **LiviqaTests only** |
| `LiviqaWatch/Complication/LiviqaComplication.swift` | the `@main` watch complication | **watch complication only** |
| `Liviqa/Theme.swift` | A7.2 tokens (already in the app) | app **+ iOS widget** (§4.3) |

`LiviqaWidgets/` sits at the repo root and is **not** part of any
`PBXFileSystemSynchronizedRootGroup`, so nothing in it compiles until you tick target
membership below. (Verified 2026-08-13: a `#error` canary placed in
`LiviqaWidgets/` did not fire and the app build stayed green.)

---

## 1. Prerequisite — the App Group must actually be provisioned

The whole feature rests on one shared container. Check this first or you will build
two targets that show nothing.

1. `Config/Signing.xcconfig` already defines `APP_GROUP = group.dev.liviqa.app`.
   Do not hard-code that string anywhere — every reference below is `$(APP_GROUP)`.
2. `Liviqa/Liviqa.entitlements` (the canonical DfG entitlements) already declares
   `com.apple.security.application-groups = $(APP_GROUP)`. Good.
3. **`Config/Liviqa.ppcn.entitlements` deliberately does NOT.** Its comment says App
   Groups was dropped for the PPCN beta because headless ASC-key signing could not
   register it. If you build with `LIVIQA_ENTITLEMENTS` pointing at that file, the
   store fails **closed**: `LiviqaWidgetSnapshotStore` returns `nil`, the widget
   shows "Nothing to show yet", and the complication shows "—". Nothing crashes and
   nothing lies — but nothing appears either.
   → Either register the App Group on the App ID and add it to the PPCN
   entitlements, or accept that widgets only work on the DfG (`PS258XSNL8`) profile.
   **Decide this before promising widgets in a release note.**

---

## 2. Create the iOS widget target

1. Open `Liviqa.xcodeproj`.
2. **File ▸ New ▸ Target…**
3. **iOS** tab → **Widget Extension** → **Next**.
4. Product Name: **`Liviqa Widgets`** — with the space.
   *(Not `LiviqaWidgets`: Xcode names the new source folder after the product, and
   `LiviqaWidgets/` already exists at the repo root. The space avoids the collision.)*
5. **Uncheck "Include Live Activity"** and **"Include Configuration App Intent"**.
   Team: the same team as the app. → **Finish**.
6. When asked "Activate 'Liviqa Widgets' scheme?" → **Cancel**. Keep the `Liviqa`
   scheme active; the extension builds as part of the app.

Xcode creates a `Liviqa Widgets/` folder and adds an *Embed Foundation Extensions*
phase to the `Liviqa` app target. Leave that phase alone.

---

## 3. Delete the template files

In the new **`Liviqa Widgets`** group, select and **Move to Trash**:

- `Liviqa_Widgets.swift` (name varies — the file with `struct Provider: TimelineProvider`)
- `Liviqa_WidgetsBundle.swift` (the template `@main`)
- `AppIntent.swift` / `Liviqa_WidgetsLiveActivity.swift` — only if they exist

**Keep** `Assets.xcassets` and `Info.plist`.

If you leave the template `@main` in place the extension will not link
("'main' attribute can only apply to one type").

---

## 4. Add our source files

### 4.1 Into the widget target

Drag from Finder into the **`Liviqa Widgets`** group. In the dialog:
**Copy items if needed = OFF** · **Create groups** · **Add to targets = `Liviqa Widgets` ONLY**.

- `LiviqaWidgets/Shared/LiviqaWidgetSnapshot.swift`
- `LiviqaWidgets/Shared/WidgetCopy.swift`
- `LiviqaWidgets/Widget/LiviqaWidgetBundle.swift`
- `LiviqaWidgets/Widget/EditionWidget.swift`
- `LiviqaWidgets/Widget/EditionWidgetViews.swift`

### 4.2 Into the app target

Same drag, **Add to targets = `Liviqa` ONLY**:

- `LiviqaWidgets/Shared/LiviqaWidgetSnapshot.swift`  ← the *same* file, second membership
- `LiviqaWidgets/Shared/WidgetCopy.swift`            ← same
- `LiviqaWidgets/App/WidgetSnapshotPublisher.swift`

*(Easier alternative for the two Shared files: add them once, then tick the second
target in the File Inspector's **Target Membership** panel.)*

### 4.3 Share `Liviqa/Theme.swift` with the widget

Select `Liviqa/Theme.swift` in the navigator → **File Inspector (⌥⌘1)** →
**Target Membership** → tick **`Liviqa Widgets`** as well as `Liviqa`.

The widget views use `LiviqaTheme` tokens and the `.lato` / `.liviqaSerif` /
`.liviqaKicker` / `.liviqaMono` faces — no hex literals — so the widget recolours
with the app. `Theme.swift` is self-contained (`SwiftUI` + `UIKit` only) and Charter
ships with iOS, so nothing else needs to come along.

### 4.4 Into LiviqaTests

Drag `LiviqaWidgets/Tests/LiviqaWidgetSnapshotTests.swift`,
**Add to targets = `LiviqaTests` ONLY**.

---

## 5. App Group + the `LiviqaAppGroup` Info.plist key

The App Group id is read at runtime from each target's Info.plist key
`LiviqaAppGroup`, set to `$(APP_GROUP)`. Nothing hard-codes it.

### 5.1 Capability

For **`Liviqa Widgets`** → **Signing & Capabilities** → **+ Capability ▸ App Groups**
→ add a group (any value; you fix it next).

Xcode generates `Liviqa Widgets/Liviqa Widgets.entitlements` with a **literal**
group string. Open that file and replace the literal with the variable, so it
matches `Liviqa/Liviqa.entitlements`:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>$(APP_GROUP)</string>
</array>
```

The app target already has this capability — do not touch it.

### 5.2 The Info.plist key

- **`Liviqa Widgets`** target → **Build Settings** → search `INFOPLIST_KEY` →
  add a User-Defined setting:
  `INFOPLIST_KEY_LiviqaAppGroup = $(APP_GROUP)`
  *(this target uses `GENERATE_INFOPLIST_FILE = YES`, so the key lands in the built
  Info.plist automatically)*
- **`Liviqa`** app target uses a real file, `Liviqa/Info.plist`. Open it and add:

```xml
<key>LiviqaAppGroup</key>
<string>$(APP_GROUP)</string>
```

If the key is missing or still shows `$(...)` unexpanded, the store logs once in
DEBUG and stays inert. It never guesses a group name.

---

## 6. Identity and version settings (`Liviqa Widgets` target)

Build Settings → set these three. The App Store rejects an extension whose version
does not match its host app.

| Setting | Value |
|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `$(APP_BUNDLE_ID).widgets` |
| `CURRENT_PROJECT_VERSION` | same as the app (`10.98` in-project today; the release script drives the real number) |
| `MARKETING_VERSION` | `1.0` |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` |

The target's **Base Configuration** should already be `Config/Signing.xcconfig`
(inherited from the project). Confirm it is — that is where `$(APP_BUNDLE_ID)` and
`$(APP_GROUP)` come from. Per repo convention, identity never appears as a literal
in a `.swift`, `Info.plist` or `.entitlements`.

---

## 7. Wire the app (the one-liner)

`Liviqa/AppState.swift`, in `refreshHealth()`. Line 744 today reads:

```swift
        defer { syncWatchGlance() }
```

Add one line directly beneath it:

```swift
        defer { publishWidgetSnapshot() }
```

That is the whole app-side integration. `publishWidgetSnapshot()` mirrors the
finished Home state into the App Group and asks WidgetKit to reload — and clears
the snapshot when there is nothing honest to show, so a stale figure can never
outlive its data.

> `AppState.swift` is owned by another agent in this wave. Apply this line in the
> integrating session rather than in the widget PR if the file is contended.

---

## 8. Create the watchOS complication target

The complication source has existed since Area ⑧ and has now been finished
(all four families, honest staleness, snapshot-backed). It still needs its target.

1. **File ▸ New ▸ Target…** → **watchOS** tab → **Widget Extension** → **Next**.
2. Product Name: **`Liviqa Complication`**. Uncheck **"Include Live Activity"** and
   **"Include Configuration App Intent"**. → **Finish** → **Cancel** the scheme prompt.
3. Delete the generated template widget `.swift` files (same reason as §3) — keep
   `Assets.xcassets` and `Info.plist`.
4. Add, with **Add to targets = `Liviqa Complication` ONLY**:
   - `LiviqaWatch/Complication/LiviqaComplication.swift`
   - `LiviqaWidgets/Shared/LiviqaWidgetSnapshot.swift`  ← third membership
   - `LiviqaWidgets/Shared/WidgetCopy.swift`            ← third membership
5. **App Groups** on **BOTH** the **`Liviqa Watch`** app target **and** the
   **`Liviqa Complication`** target → Signing & Capabilities → **+ Capability ▸
   App Groups**, then edit each generated `.entitlements` to use `$(APP_GROUP)`
   exactly as in §5.1. *(The watch app currently has no App Group at all — this is
   the gap recorded in the FR-WID-01 RTM row.)*
6. Build Settings for **`Liviqa Complication`**:

   | Setting | Value |
   |---|---|
   | `PRODUCT_BUNDLE_IDENTIFIER` | `$(APP_BUNDLE_ID).watchkitapp.complication` |
   | `INFOPLIST_KEY_LiviqaAppGroup` | `$(APP_GROUP)` |
   | `WATCHOS_DEPLOYMENT_TARGET` | `10.0` |
   | `CURRENT_PROJECT_VERSION` / `MARKETING_VERSION` | same as the app |

   The watch app itself is `$(APP_BUNDLE_ID).watchkitapp`; a watch extension's id
   must be prefixed by the watch app's id, hence the value above.

7. Also add `INFOPLIST_KEY_LiviqaAppGroup = $(APP_GROUP)` to the **`Liviqa Watch`**
   target, so the watch app can publish into the same container later.

---

## 9. Verify

```bash
xcodebuild -scheme Liviqa -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
bash scripts/guard_provenance.sh Liviqa
bash scripts/guard_provenance.sh LiviqaWidgets     # extend T-PROV-01 to the new root
```

Then in Xcode: run the `Liviqa` scheme, long-press the Home screen, **+**, search
**Liviqa**, add **Today's edition** in both small and medium.

Expected on a device with no published snapshot yet: **"Nothing to show yet /
Open Liviqa to build today's edition."** That is correct, not a bug — open the app,
let a health refresh complete, and the widget fills in with an "as of HH:MM" line.

Unit tests (`T-WID-01…06`) run with the normal test action once §4.4 is done.

> **Known, pre-existing:** `build-for-testing` currently fails on
> `Liviqa/Health/LabReportOCR.swift:146` — `VNRecognizeTextRequest` has no member
> `requiresOnDeviceRecognition` under the Xcode 26.5 SDK. Reproduced on a clean tree
> with none of these files present, so it is unrelated to FR-WID-01, but it does
> block running the new tests until someone fixes that call.

---

## 10. What this setup deliberately does NOT do

- **No lock-screen accessory widgets on iOS.** Scope is `systemSmall` +
  `systemMedium`. `.accessoryRectangular`/`.accessoryCircular` on iOS are a separate
  decision.
- **No interactive widgets, no App Intents, no deep links.** Tapping opens the app
  at its normal launch surface.
- **No Danish.** Copy is EN; the strings catalogue is not a member of the extension
  targets. The Danish pass is its own gate — when it happens, add
  `Liviqa/Localizable.xcstrings` to both extension targets.
- **No composite score anywhere.** The widget shows the edition sentence, the
  decomposed signals behind it, and a two-state time-in-range read. If a future
  change adds a single blended number to this surface, it has undone the point of
  the absorb.
