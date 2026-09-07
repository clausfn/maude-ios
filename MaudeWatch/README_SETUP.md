# Maude Watch App — setup (one-time, in Xcode)

The SwiftUI source is ready in `MaudeWatch/`. The watchOS **target** must be created
in Xcode (hand-editing the project file risks corrupting the iOS app). ~3 minutes.

## 1. Add the watch target
1. Open `Maude.xcodeproj` in Xcode.
2. **File ▸ New ▸ Target…**
3. Select the **watchOS** tab → **App** → **Next**.
4. Product Name: **Maude Watch** · Interface: **SwiftUI** · Language: **Swift**.
   - "Watch App for iOS App" / companion: **Yes** (embed in the Maude iOS app).
   - Uncheck "Include Notification Scene" and tests for now.
5. **Finish**. If asked to activate the new scheme, click **Activate**.

Xcode creates a `Maude Watch App/` group with a starter `ContentView`/`App`.

## 2. Swap in our source
1. **Delete** the auto-generated `MaudeWatchApp.swift`/`ContentView.swift` Xcode made
   (Move to Trash) — so there's no duplicate `@main`.
2. Drag the five files from the Finder folder **`MaudeWatch/`** into the new watch
   group: `MaudeWatchApp.swift`, `WatchHomeView.swift`, `WatchPillarDetailView.swift`,
   `WatchModels.swift`, `WatchTheme.swift`. In the dialog: **Copy items if needed = off**,
   **Add to target = Maude Watch App** (only the watch target).
   - The glance pillars tap through to `WatchPillarDetailView` (big value + two-state
     observation + a last-7-day sparkline, fed by the phone's `trend` series).

## 3. Add the iris mark to the watch
1. Open the watch target's **Assets.xcassets** → drag in a new Image Set named
   **`WatchMark`** → drop the reversed iris mark
   `design-system/assets/brand/maude_mark_iris_reversed.svg` (white-on-navy; the same
   locked brand asset the phone uses — never redraw it in code).
   (Or skip — the header just won't show the mark.)

## 4. Run
- Destination dropdown → an **Apple Watch Simulator** (e.g. "Apple Watch Series 10 (46mm)") → **▶ Run**.
- You'll see the glance: aperture + "Maude", a calm "A steady day" line, and the
  Glucose · Sleep · Recovery · Heart pillars (two-state dots).

## Compliance + brand (already baked into the source)
- Descriptive only — numbers + an observational/affirming line. No scores, verdicts,
  prediction, or advice (non-MDSW, same line as the phone).
- Two-state colour: moss = in your range, clay = worth noticing. Midnight palette.

## 5. Live data — WatchConnectivity (mostly wired already)
1. Add **`MaudeWatch/Connectivity/WatchSessionReceiver.swift`** to the **Maude Watch
   App** target. (The watch `@main` already hosts it and feeds the glance.)
2. **iOS side — nothing to do.** The phone sender lives at
   `Maude/Connectivity/PhoneWatchSync.swift` (inside the iOS target's synchronized
   folder, so it compiles into the app automatically), and `AppState.syncWatchGlance()`
   already calls `PhoneWatchSync.shared.push(...)` on every health refresh — mirroring
   the same Home values (affirming line + Glucose/Sleep/Recovery/Heart) to the wrist.
   Until a watch is paired, this is a silent no-op and the watch shows its demo snapshot.
   - ⚠️ Do **not** also add a `PhoneWatchSync.swift` to the iOS target by hand — there
     is only one now, and it's already in. A second copy = duplicate-symbol build error.

## 6. Complication (optional) — Widget Extension (watchOS)
1. **File ▸ New ▸ Target… ▸ watchOS ▸ Widget Extension** → name **"Maude Complication"**
   (uncheck "Include Configuration App Intent" / Live Activity).
2. Delete the generated widget swift; add **`Complication/MaudeComplication.swift`** to
   that target (it already has the `@main`).
3. **App Group** (shared value): select the **Maude Watch App** target and the
   **Maude Complication** target → Signing & Capabilities → **+ Capability ▸ App Groups**
   → add **`group.xyz.ppcn.maude`** to both. (The iOS app already uses this group.)
4. Run the watch scheme → on the watch face, add the **Maude** complication
   (In range). It shows the last value the watch received; refreshes on update.

## Next steps (I can build these once targets exist)
- ~~Wire `PhoneWatchSync.push(...)` to real on-device signals in the iOS app.~~ ✅ Done
  — `AppState.syncWatchGlance()` pushes the live Home snapshot on every refresh.
- **Tap-through:** a second screen per pillar (descriptive detail).
- Optional **HealthKit-on-watch** query so the watch works standalone.
