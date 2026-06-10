# Liviqa iOS — Human Go-Live Checklist (Claus's manual Apple steps)

Everything code-side for a TestFlight build is done and verified (Debug + Release build green,
114 tests green, 5 tabs smoke-clean). The steps below are the ones I cannot do for
you — they need your Apple ID, signing identity, and App Store Connect. Do them in order.

App: **Liviqa** · bundle **dev.liviqa.app** · version **1.0** · build **10.20**.

---

## A. One-time, before archiving (verify, ~3 min)

1. **Open the project:** in Finder open `~/Developer/DataForGood/liviqa-ios/Liviqa.xcodeproj`
   (double-click). Wait for "Indexing" to finish.
2. **Select the target:** in the left Project navigator click the blue **Liviqa** project icon
   (top), then under TARGETS select **Liviqa**.
3. **Signing & Capabilities tab** → set **Team = Data for Good** (the account with access to
   App ID `dev.liviqa.app`). Leave **Automatically manage signing** ON. Xcode will mint the
   Apple Distribution cert + App Store profile.
   - If you see a red "Failed to register bundle identifier" or App Group error: that's the
     `com.apple.security.application-groups` entitlement. It is optional for the app to run —
     if provisioning fights you, you can remove the App Groups row here and re-try (no code
     change needed). HealthKit + Sign in with Apple must stay.
4. **Confirm capabilities present** in that same tab: **HealthKit** and **Sign in with Apple**
   are listed. (Both are already in the entitlements file; Xcode just needs to register them.)

## B. Confirm the privacy/usage strings (already in code — just eyeball)

These are already in `Liviqa/Info.plist`; you do **not** need to edit them. They are what Apple
review and the Health permission dialog show:
- `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` (read-only wording),
  `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSCalendarsWriteOnlyAccessUsageDescription`.

## C. Archive (the build itself)

1. **THE THING MOST LIKELY TO GO WRONG — set the run destination FIRST.** Top toolbar, the
   device dropdown next to the scheme: change it from any Simulator to **"Any iOS Device
   (arm64)"**. You CANNOT archive while a Simulator is selected — the Archive menu item is
   greyed out until you do this.
2. Menu bar → **Product → Archive**. (If "Archive" is greyed out, step C1 isn't done.)
3. Wait for the build (~2–4 min). The **Organizer** window opens with the new archive at top.
   Confirm it reads **Liviqa · 1.0 (10.20)**.

## D. Upload to App Store Connect → TestFlight

1. In the Organizer, with the new archive selected, click **Distribute App**.
2. Choose **TestFlight & App Store** → **Next**.
3. **Automatically manage signing** → **Next**. Let it upload (~3–5 min).
4. Go to **appstoreconnect.apple.com → Apps → Liviqa → TestFlight**. The build shows as
   "Processing" for ~5–15 min, then becomes available.
   - **Internal testers** (your own group) get it within minutes once processing completes —
     no review needed. Add testers under TestFlight → Internal Testing if not already there.
   - **External testers / App Store** require Apple's Beta App Review (a day or so) — not needed
     for your own pilot.
5. **If TestFlight doesn't notify testers** (this bit us on 10.17): open the build row, confirm
   it's in a group with **automatic distribution** ON, and that the build state is
   "Ready to Test". Testers may need to pull-to-refresh the TestFlight app.

## E. What this build contains
- Real on-device **HealthKit** read-only ingestion by default on a real device (Simulator and
  devices with no Health history fall back to clearly-labelled demo data). On a real device with
  Health not yet connected, Home shows a dismissible "Showing sample data → Connect Apple Health
  in Settings" hint so testers know how to see their own data.
- On-device nudge engine behind the **FR-NDG-06** guardrail (no dosing/diagnosis/normality claims).
- Encrypted local store; consent wallet + one-tap pause + Share-Receipt; calm v2 design system;
  care messaging with the message-visibility fix.
- **Real data on every surface** (Home chips, Insights, all pillar details) once Health is connected,
  with honest "Demo data" fallback; fabricated change indicators are hidden next to real values.
- **Upgraded data visualisation**: smoothed trend charts with a y-axis and a personal "your normal"
  band, Home 7-day sparklines, a CGM-style daily glucose curve in your target band, real sleep-stage
  breakdown (Deep/Light/REM) + nightly trend.
- **Journal entries persist** across relaunch (device-local, file-protected).

## F. Known limitations (not blockers; logged for the next pass)
- **Dynamic Type**: supported — body content scales with the system text size; the fixed bottom
  tab bar and Home signal chips are clamped so they stay on one line at accessibility sizes.
  Verified at accessibility-extra-large. VoiceOver labels present on the primary controls.
- The **video-consult flow** rework (clinician moderator / planned + instant / calendar) is owned
  by the parallel Care session.
- Watch app source is ready but its watchOS/Widget **targets must be created in Xcode**
  (`LiviqaWatch/README_SETUP.md`) before it ships.

## G. Paste-ready TestFlight "What to Test" (App Store Connect → TestFlight → Test Details)

> **Liviqa 1.0 (10.20) — what's new to try**
>
> This build turns on real Apple Health and a calmer home screen.
>
> 1. **Connect Apple Health.** On first launch, allow Health access when asked. If you skip it,
>    you'll see "Showing sample data" on Home with a link to connect later in Settings.
> 2. **Home.** Check it opens calm — a "steady week" summary, your four signals (Sleep, Glucose,
>    Recovery, Heart), and at most one "worth a look" item. Tap any signal for its detail + trend.
> 3. **Insights.** Look at the time-in-range and Recovery/Stress (HRV) trends and the 7-day grid.
> 4. **Assistant.** Tap ✨ (top-right) and ask about your data. Tell us if anything feels off or unclear.
> 5. **Privacy.** Review your active grants; try "pause" and "Add receipt to My DfG wallet".
> 6. **Care messages.** Open a conversation — confirm you can read and send messages clearly.
> 7. **Accessibility.** If you use larger text, check nothing is cut off.
>
> Please flag: anything confusing, any data that looks wrong, or anywhere it feels "too medical."
