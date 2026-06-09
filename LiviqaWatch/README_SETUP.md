# Liviqa Watch App — setup (one-time, in Xcode)

The SwiftUI source is ready in `LiviqaWatch/`. The watchOS **target** must be created
in Xcode (hand-editing the project file risks corrupting the iOS app). ~3 minutes.

## 1. Add the watch target
1. Open `Liviqa.xcodeproj` in Xcode.
2. **File ▸ New ▸ Target…**
3. Select the **watchOS** tab → **App** → **Next**.
4. Product Name: **Liviqa Watch** · Interface: **SwiftUI** · Language: **Swift**.
   - "Watch App for iOS App" / companion: **Yes** (embed in the Liviqa iOS app).
   - Uncheck "Include Notification Scene" and tests for now.
5. **Finish**. If asked to activate the new scheme, click **Activate**.

Xcode creates a `Liviqa Watch App/` group with a starter `ContentView`/`App`.

## 2. Swap in our source
1. **Delete** the auto-generated `LiviqaWatchApp.swift`/`ContentView.swift` Xcode made
   (Move to Trash) — so there's no duplicate `@main`.
2. Drag the four files from the Finder folder **`LiviqaWatch/`** into the new watch
   group: `LiviqaWatchApp.swift`, `WatchHomeView.swift`, `WatchModels.swift`,
   `WatchTheme.swift`. In the dialog: **Copy items if needed = off**, **Add to target =
   Liviqa Watch App** (only the watch target).

## 3. Add the aperture mark to the watch
1. Open the watch target's **Assets.xcassets** → drag in a new Image Set named
   **`WatchMark`** → drop `Brand_Assets/liviqa_mark_aperture_reversed_v01.svg` (white-on-dark).
   (Or skip — the header just won't show the mark.)

## 4. Run
- Destination dropdown → an **Apple Watch Simulator** (e.g. "Apple Watch Series 10 (46mm)") → **▶ Run**.
- You'll see the glance: aperture + "Liviqa", a calm "A steady day" line, and the
  Glucose · Sleep · Recovery · Heart pillars (two-state dots).

## Compliance + brand (already baked into the source)
- Descriptive only — numbers + an observational/affirming line. No scores, verdicts,
  prediction, or advice (non-MDSW, same line as the phone).
- Two-state colour: moss = in your range, clay = worth noticing. Midnight palette.

## Next steps (after the target exists — I can build these)
- **Real data:** WatchConnectivity to receive the descriptive snapshot from the phone
  (or a HealthKit-on-watch query). Keep the snapshot descriptive at the source.
- **Complication** (WidgetKit watchOS): a glanceable in-range % / calm dot on the face.
- **Tap-through:** a second screen per pillar (descriptive detail).
