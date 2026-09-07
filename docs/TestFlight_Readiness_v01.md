# TestFlight readiness — gap list (v01, 2026-06-03)

Goal: a **TestFlight build under the Data for Good team** (`PS258XSNL8` — "Fonden
Data For Good"), wired to **live data** (sovereign backend + Supabase GoTrue auth),
console live at `sandbox.maude.app`. Legend: ✅ done · ⚠️ gap (we fix) · 🔴 blocker
(needs your Apple login — I can't do headless) · ❓ decision needed.

## Decisions (locked 2026-06-03)
- **Bundle id:** `app.maude.ios` (App Group `group.app.maude.ios`).
- **Video consult in v1:** GATED OFF (`Config.videoConsultEnabled = false`) — no cam/mic, no Jitsi. Secure messaging stays.
- **Canonical hosts:** `maude.app` → API `api.maude.app`, auth `auth.maude.app`, console `sandbox.maude.app`.
- **Testers:** external testers, **synthetic data only** (backend serves the synthetic cohort).

## Done in this pass (headless)
- ✅ `Config.backend`: Release/TestFlight → `sovereignProd` (`api.maude.app` + GoTrue); Debug → `.mock`; env still overrides.
- ✅ Video consult gated off (`Config.videoConsultEnabled`; `MessagesView` hides the consult section) → no camera/mic strings needed for v1.
- ✅ `Config/Signing.xcconfig` (local): `DEVELOPMENT_TEAM = PS258XSNL8`, `APP_BUNDLE_ID = app.maude.ios`.
- ✅ `Info.plist`: `ITSAppUsesNonExemptEncryption = false` (export-compliance prompt skipped).
- ✅ `PrivacyInfo.xcprivacy` privacy manifest added (health/email/userID/message-content; UserDefaults reason CA92.1) — bundled, build verified.
- ✅ `docs/INTENDED_USE.md` (FR-QMS-01).
- ✅ App icon (PR-29).

## A. Signing & identity
- ✅ Team ID wired: `Config/Signing.xcconfig` → `DEVELOPMENT_TEAM = PS258XSNL8`.
- 🔴 **No DfG signing identity in this Mac's Keychain** — only `Apple Development … (G8MHRNS97R)` (personal). TestFlight needs an **Apple Distribution** cert under `PS258XSNL8`.
  → Xcode ▸ Settings ▸ Accounts ▸ add the DfG Apple ID (with access to `PS258XSNL8`) ▸ enable automatic signing → Xcode mints the Distribution cert + App Store profile. (Or import the cert+private-key `.p12` for `AJ98C58F5H`.)
- ❓ **Bundle id.** Template default `xyz.ppcn.maude` is likely already registered under the personal team; bundle ids are globally unique, so DfG probably needs a fresh one (e.g. `app.maude.ios`). Decision blocks the App ID + App Store Connect record.
- 🔴 Register the App ID under `PS258XSNL8` + matching **App Group**; create the app record in **App Store Connect**.

## B. Capabilities / entitlements
- ✅ HealthKit capability + read-only entitlement.
- ⚠️ **HealthKit background delivery** entitlement (anchored ingestion / observers, FR-ING-03/04) — confirm it's in the entitlements + provisioning.
- ✅ Sign in with Apple capability (AuthView wired).
- ✅ App Groups (`group.<bundle>`).
- ⚠️ Ensure entitlements match the DfG App ID's enabled capabilities exactly (HealthKit, SIWA, App Groups), or upload validation fails.

## C. Info.plist / privacy (App Store hard requirements)
- ✅ `NSHealthShareUsageDescription`.
- ⚠️ **`NSCameraUsageDescription` + `NSMicrophoneUsageDescription`** — required if the Care-tab video consult ships (Jitsi WebView). Missing today.
- ⚠️ **`ITSAppUsesNonExemptEncryption`** = NO (standard HTTPS only) — set it to skip export-compliance prompts each upload.
- 🔴/⚠️ **`PrivacyInfo.xcprivacy` privacy manifest** — now required by Apple. Declare data types (health = not collected off-device; the only egress is the derived, consented share) + required-reason APIs (UserDefaults, file timestamp, Keychain). We author it; you confirm.
- ⚠️ Remove the dev-only **`NSAllowsLocalNetworking`** from the Release/TestFlight build (it's a local-dev ATS concession; prod is TLS-only).
- 🔴 **App Store privacy "nutrition labels"** (App Store Connect) — declare health data handling honestly.

## D. Live-data wiring ("hardcoded live feed")
- ⚠️ `Config.backend` defaults to `.mock`. Make **Release/TestFlight default to the live sovereign backend + Supabase GoTrue** (Debug stays local) via build configuration — clean, not literal hardcoding. Add a `.sovereignProd` preset.
- ❓ **Production hosts**: API + auth + console. Today the code/runbook mix `api.dfgworks.dk`, `auth.maude.app`, `sandbox.maude.app`. Pick the canonical set; I'll standardize all repos + docs.
- ⚠️ `Config.supabaseAuthURL` currently `https://auth.maude.app` (placeholder) — point at the real GoTrue host once it's stood up.
- ✅ App icon present (PR-29).

## E. Backend / console prod-ready (mostly your deploy, code already aligned)
- 🔴 Scaleway backend container **healthy** (the deploy was erroring on a bad `DATABASE_URL`; confirm it's green) with `SUPABASE_JWT_SECRET`/`JWKS` set + `DEV_AUTH=false`.
- 🔴 Provision real identities (link-by-email) matching the accounts.
- ✅ Console live (`sandbox.maude.app`).
- ❓ Real vs synthetic data for testers — external testers + **real health data** has consent/Art.9 implications; first round likely **internal testers / own data**.

## F. Video consult scope (decision drives several gaps above)
- ❓ Ship the Care tab (video) in v1? If yes → need cam/mic usage strings **and** an **EU-sovereign Jitsi** (NFR-SEC-07; `meet.jit.si` is demo-only) + App Review justification. If no → gate it off; build is much closer.

## G. Regulatory / health
- ✅ FR-NDG-06 guard, AFib display-only, no diagnostic claims.
- ⚠️ Intended-use statement (FR-QMS-01, still pending) — add `docs/INTENDED_USE.md` before external testers.
- ⚠️ Beta App Review notes (what the app does, test account, health-data rationale).

## H. Build mechanics
- ⚠️ `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` (e.g. 0.1.0 / build 1).
- 🔴 Archive (`xcodebuild archive` / Xcode) signed with the DfG Distribution identity → upload to TestFlight (needs B + A).
- ⚠️ QMS: TestFlight is a release → RTM/CHANGELOG/DHF/RISK + this doc.

## Order of attack
1. **Decisions** (you): bundle id · production hosts · video-in-v1 · testers data. ← unblocks the rest.
2. **Apple-side** (you, needs login): add DfG Apple ID to Xcode + automatic signing; register App ID/App Group; create App Store Connect record; nutrition labels.
3. **Headless (me, now):** Release→live-data config preset; camera/mic + export-compliance Info.plist; `PrivacyInfo.xcprivacy`; remove ATS from Release; version/build; `INTENDED_USE.md`; QMS. Then a signed archive is just "press upload" once 1–2 are done.
