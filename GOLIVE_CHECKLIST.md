# Maude iOS — Human Go-Live Checklist (Claus's manual Apple steps + release gates)

_Rewritten 2026-07-05 (PR-102 wave 5) against the 2026-07-03 launch audit. The previous
version of this file failed the audit's cross-check: it claimed build 10.20 / 114 tests
(actual: 10.70 / 126), said the Watch target "must be created in Xcode" (it is built AND
embedded), and asserted "Release build green" without evidence. This version states only
what is verified and lists what is not._

**Verified code-side (2026-07-03 audit, @ 0558bdd):** Debug simulator build green via
`./build-ios.sh` (iPhone 17 / iOS 26.5) — including the Watch app, which is **compiled and
embedded** (`ValidateEmbeddedBinary …/Watch/Maude Watch.app`); **126 unit tests in 28
suites green**, 0 failures, 0 skipped — the FR-NDG-06 designated control ran and passed.

**NOT yet verified (do not claim them):** the Release-configuration build, MaudeUITests,
the device archive, and Watch runtime on a paired simulator. Commands are in audit §7;
run them before any external distribution.

App: **Maude** · bundle **xyz.ppcn.maude** (Watch: **xyz.ppcn.maude.watchkitapp**) ·
version **1.0** · build **10.70**.

---

## 0. Release gates — ALL green before any public / externally-tested build

Policy, not busywork — each gate traces to a 2026-07-03 audit finding.

1. **Demo-login flags OFF outside DEBUG.** `Config.dfgWalletLoginEnabled` and
   `Config.nationalIDLoginEnabled` now compile to `false` in Release (`#if DEBUG`,
   `Maude/Config.swift`), and `applyLV001DatasetIfNeeded()` is a Release no-op — enforced
   in code since PR-102 wave 1. **Check:** build Release and confirm the sign-in screen
   shows no DfG Wallet / national-eID tiles. _State: enforced; Release spot-check pending._
2. **Mistral key rotated + backend proxy live before any public build.** The old key
   compiled into every build up to 10.70 — treat it as burned and rotate it. Release
   builds now call `POST {apiBase}/ai/chat` (no key on device); the proxy route is
   prepared in maude-backend and must be deployed first. **Check:** rotate the key,
   deploy, then verify assistant chat works in a Release build. _State: OPEN — owner.
   Hard gate for App Store; wider TestFlight acceptable only post-rotation._
3. **Post-deploy route-parity check green.** api.maude.app currently 404s on 8
   client-called routes (wallet-auth, role-credential, issuance, appointments,
   push-token). **Check:** after deploying maude-backend HEAD, run
   `maude-backend/scripts/route-parity.sh https://api.maude.app` → exit 0
   (runbook: `maude-backend/DEPLOY_PARITY.md`). _State: OPEN — owner._
4. **guard_provenance green in CI.** T-PROV-01 (`scripts/guard_provenance.sh`) is a
   blocking step in `./build-ios.sh` since 2026-07-03 — it was inert before that date.
   Any CI that builds this repo must go through `./build-ios.sh` (or run the guard as its
   own required step). **Check:** `bash scripts/guard_provenance.sh Maude` → exit 0.
   _State: green locally; standing up real CI (no `.github/workflows/` exists) is an open
   owner action._
5. **Localization review of the `needs_review` keys.** 83 keys × 5 languages
   (da/nb/sv/es/pt) were machine-drafted 2026-07-05 and sit at state `needs_review` in
   `Maude/Localizable.xcstrings`. **Check:** review in Xcode's String Catalog editor
   (filter: Needs Review) and mark reviewed — they do not count as translated until then.
   _State: OPEN — owner review._

## A. One-time, before archiving (verify, ~3 min)

1. **Open the project:** in Finder open `~/Developer/DataForGood/maude-ios/Maude.xcodeproj`
   (double-click). Wait for "Indexing" to finish.
2. **Select the target:** in the left Project navigator click the blue **Maude** project icon
   (top), then under TARGETS select **Maude**.
3. **Signing & Capabilities tab** → set **Team = Data for Good** (the account with access to
   App ID `xyz.ppcn.maude`). Leave **Automatically manage signing** ON. Xcode will mint the
   Apple Distribution cert + App Store profile. Repeat for the **Maude Watch** target
   (`xyz.ppcn.maude.watchkitapp`) — it archives with the app.
   - If you see a red "Failed to register bundle identifier" or App Group error: that's the
     `com.apple.security.application-groups` entitlement. It is optional for the app to run —
     if provisioning fights you, you can remove the App Groups row here and re-try (no code
     change needed). HealthKit + Sign in with Apple must stay.
4. **Confirm capabilities present** in that same tab: **HealthKit** and **Sign in with Apple**
   are listed. (Both are already in the entitlements file; Xcode just needs to register them.)

## B. Confirm the privacy/usage strings (already in code — just eyeball)

These are already in `Maude/Info.plist`; you do **not** need to edit them. They are what Apple
review and the Health permission dialog show:
- `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` (read-only wording),
  `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` (both used by the video-consult
  device test), `NSCalendarsWriteOnlyAccessUsageDescription`.

## C. Archive (the build itself)

1. **THE THING MOST LIKELY TO GO WRONG — set the run destination FIRST.** Top toolbar, the
   device dropdown next to the scheme: change it from any Simulator to **"Any iOS Device
   (arm64)"**. You CANNOT archive while a Simulator is selected — the Archive menu item is
   greyed out until you do this.
2. Menu bar → **Product → Archive**. (If "Archive" is greyed out, step C1 isn't done.)
3. Wait for the build (~2–4 min). The **Organizer** window opens with the new archive at top.
   Confirm it reads **Maude · 1.0 (10.70)** — and that the archive contains the Watch app.

## D. Upload to App Store Connect → TestFlight

1. In the Organizer, with the new archive selected, click **Distribute App**.
2. Choose **TestFlight & App Store** → **Next**.
3. **Automatically manage signing** → **Next**. Let it upload (~3–5 min).
4. Go to **appstoreconnect.apple.com → Apps → Maude → TestFlight**. The build shows as
   "Processing" for ~5–15 min, then becomes available.
   - **Internal testers** (your own group) get it within minutes once processing completes —
     no review needed. Add testers under TestFlight → Internal Testing if not already there.
   - **External testers / App Store** require Apple's Beta App Review (a day or so) — and
     gates 2–5 in §0 above **must be green first**.
5. **If TestFlight doesn't notify testers** (this bit us on 10.17): open the build row, confirm
   it's in a group with **automatic distribution** ON, and that the build state is
   "Ready to Test". Testers may need to pull-to-refresh the TestFlight app.

## E. What build 10.70 contains
- Real on-device **HealthKit** read-only ingestion by default on a real device (Simulator and
  devices with no Health history fall back to clearly-labelled demo data), with real data on
  every surface once Health is connected.
- On-device nudge engine behind the **FR-NDG-06** guardrail (no dosing/diagnosis/normality
  claims); encrypted local store; consent wallet + one-tap pause + Share-Receipt.
- **A6 "Daylight" design system** (PR-96: six-colour palette, SF Pro + IBM Plex Mono, iris
  mark) with **Liquid Glass** surfaces (PR-98/101, iOS 17 floor kept) — including the
  magnifier tab bar shipped in 10.66–10.70.
- **Video consult** (PR-91–95): request → pre-visit check-in + device test → calendar invite
  + reminder ladder → virtual waiting room → auto-join; self-hosted EU Jitsi.
- **Research participation flow + consent reactivation** (PR-99); upgraded data
  visualisation incl. clinical TIR zones (PR-100); journal persistence; Dynamic Type
  genuinely scaling (PR-97).
- **Watch app built and embedded** (descriptive glance + pillar detail + complication).
- PR-102 audit fixes (see `qms/CHANGELOG.md`): real "Delete permanently", DEBUG-only demo
  logins, no Mistral key in Release, honest CTAs and consult-availability copy, provenance
  guard live and blocking.

## F. Known limitations (logged, not hidden)
- **Release build, MaudeUITests, device archive, Watch runtime: NOT yet run** on the
  audited tree — audit §7 has the exact commands. Run before external distribution.
- **Jitsi domain** is the TLS-valid sslip.io stand-in (`163-172-173-186.sslip.io`); moving
  behind `meet.maude.app` + hardening is a tracked follow-up.
- **Wallet rails on prod route to the sandbox container** (`Config.walletRailBaseURL`
  detour) until api.maude.app carries the routes — retire the detour or promote the
  container with change control (audit action 7).
- **Tests still to author** (recorded honestly in qms/): `T-DEL-01` (delete-all),
  `T-RSCH-01`, `T-CONSENT-REACT-01`, and the `noDeadPrimaryCTAs` XCUITest sweep.
- **Dynamic Type**: body content scales; the fixed bottom tab bar and Home signal chips are
  clamped so they stay on one line at accessibility sizes. Verified at
  accessibility-extra-large. VoiceOver labels present on the primary controls.

## G. Paste-ready TestFlight "What to Test" (App Store Connect → TestFlight → Test Details)

> **Maude 1.0 (10.70) — what's new to try**
>
> 1. **Connect Apple Health.** On first launch, allow Health access when asked. If you skip it,
>    you'll see "Showing sample data" on Home with a link to connect later in Settings.
> 2. **Home.** Check it opens calm — a "steady week" summary, your four signals (Sleep, Glucose,
>    Recovery, Heart), and at most one "worth a look" item. Tap any signal for its detail + trend.
> 3. **The new tab bar.** Press and drag along the bottom bar — the glass lens should magnify
>    the icons and select on release.
> 4. **Insights.** Look at the time-in-range (with clinical zones), Recovery/Stress (HRV)
>    trends and the 7-day grid.
> 5. **Assistant.** Tap ✨ (top-right) and ask about your data. Tell us if anything feels off or unclear.
> 6. **Privacy.** Review your active grants; try "pause" and "Add receipt to My DfG wallet".
> 7. **Care.** Open a conversation; try requesting a video consult and the camera/mic test.
> 8. **Watch.** If you wear an Apple Watch, install the companion app and check the glance.
> 9. **Accessibility.** If you use larger text, check nothing is cut off.
>
> Please flag: anything confusing, any data that looks wrong, or anywhere it feels "too medical."
