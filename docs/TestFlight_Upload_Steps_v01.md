# TestFlight upload — exact steps (v01, 2026-06-03)

Your values: project `~/Developer/DataForGood/liviqa-ios` → open `Liviqa.xcodeproj`.
Team **Fonden Data For Good = PS258XSNL8** · bundle **app.liviqa.ios** · App Group
**group.app.liviqa.ios** · app name **Liviqa**. Signing = **Automatic** (Xcode
creates the App ID, Distribution cert, and profile for you). Capabilities:
HealthKit, App Groups, Sign in with Apple.

## 0. Make sure your Apple ID can act for the DfG team
You need an Apple ID that is a **member of the PS258XSNL8 team** (role: App Manager
or Admin + Developer). If your Apple ID isn't on it, the team holder adds you:
appstoreconnect.apple.com → **Users and Access** → invite your Apple ID. (Or use
the DfG account's own Apple ID.) Without this, Xcode won't show the team.

## 1. Add the account in Xcode (one-time)
Xcode → **Settings** (⌘,) → **Accounts** → **+** → Apple ID → sign in (+2FA).
After it loads you should see **Fonden Data For Good (PS258XSNL8)** in that
account's team list. If it's not there → you're not on the team yet (step 0).

## 2. Point the app at the DfG team
Open `Liviqa.xcodeproj`. Blue **Liviqa** project (top of left panel) → **TARGETS →
Liviqa** → **Signing & Capabilities** tab.
- "Automatically manage signing" = checked.
- **Team** → choose **Fonden Data For Good (PS258XSNL8)**.
- Bundle Identifier shows **app.liviqa.ios**.
- Capability tiles: **HealthKit**, **App Groups** (`group.app.liviqa.ios`),
  **Sign in with Apple**. If App Groups shows a ⟳/warning, click it to register.
  Xcode then registers the App ID + capabilities on the team ("Registering…").
- Red "Failed to register bundle identifier" = it's taken → tell me, pick another.

## 3. Create the app record (browser)
appstoreconnect.apple.com → **Apps** → **+** → **New App**:
- Platform **iOS** · Name **Liviqa** (must be App-Store-unique; if taken use
  "Liviqa Health") · Primary language · **Bundle ID = app.liviqa.ios** (appears in
  the dropdown after step 2) · SKU `liviqa-ios` · Full Access → **Create**.

## 4. Archive (Xcode)
- Top toolbar device selector → **Any iOS Device (arm64)** (NOT a simulator, or
  Archive is greyed out).
- **Product → Archive**. Wait; the **Organizer** opens with the archive.

## 5. Upload to TestFlight (Organizer)
Select the archive → **Distribute App** → **App Store Connect** → **Upload** →
keep **Automatically manage signing** (Xcode mints the Apple Distribution cert +
App Store profile) → **Upload** → "Upload Successful". (No encryption prompt — we
set `ITSAppUsesNonExemptEncryption=false`.)

## 6. TestFlight + privacy (browser)
appstoreconnect.apple.com → your app:
- **App Privacy** → declare data matching `PrivacyInfo.xcprivacy`: Health, Email
  Address, User ID, Other User Content — all *App Functionality*, linked, **not**
  tracking → Publish.
- **TestFlight** tab: build shows **Processing** (~5–15 min). Fill **Test
  Information** (what to test, feedback email).
- **Internal testers** (your team, ≤100, no review) → instant.
- **External testers** (your choice): create a group, add emails → the build goes
  to **Beta App Review** (~1 day). Beta App Review info: a **demo login** (a
  Supabase test account on synthetic data) + "wellness app, synthetic data, not a
  medical device; reads HealthKit on device."

## Gotchas (Apple isn't intuitive)
- Archive greyed out → you're on a Simulator destination; pick "Any iOS Device".
- "No accounts with PS258XSNL8" → your Apple ID isn't on the DfG team (step 0).
- "capability not enabled / can't create profile" → toggle automatic signing
  off/on, or remove+re-add the capability; Xcode re-registers it.
- Testers see **no data** → the backend `api.liviqa.app` + `auth.liviqa.app`
  aren't live yet (deploy step). The app still installs and runs.
- HealthKit on a Simulator has no data — real device or a simulator with Health
  sample data to see live nudges.
