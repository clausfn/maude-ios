# Getting Maude onto your phone

**Decided 7 Sep 2026 (CN): Maude is signed by PPCN's Apple Developer account.**
Not Data for Good's, not a personal one. The app's identity is `xyz.ppcn.maude`,
which matches.

Everything on the code side is built and green.

**What is actually left is small, and smaller than an earlier draft of this file
claimed.** The App ID, its capabilities, the app group, the signing certificate and
the provisioning profiles are all created automatically by the archive step —
`-allowProvisioningUpdates` with the API key is Xcode's create-what-is-missing mode.
None of that is yours to do.

Two things are:

  1. An App Store Connect API key — **reuse the one you already have** if there is
     one on this team. It is team-wide, not per-app.
  2. One App Store Connect app record. Two minutes, and the only step Apple offers
     no automated route for.

When they are done, pressing one button in GitHub archives the app, signs it, and
uploads it to TestFlight on its own, every time.

---

## Before you open anything

One check, because it decides whether any of the rest works at all.

Sign in at [developer.apple.com/account](https://developer.apple.com/account) with
the PPCN account and look at **Membership details**. You want to see an active
**Apple Developer Program** membership and a **Team ID** — ten characters.

- **You see a Team ID.** Good. Everything below works. Copy it; it is the first of
  the four values you will need.
- **It says you are not enrolled**, or only shows a free account: TestFlight is not
  available until PPCN enrols. That costs 99 USD a year, needs a D-U-N-S number
  (Apple looks one up or issues one free), and Apple verifies the company, which
  takes a few days. Tell me and I will hold; nothing below changes afterwards.

There is a decent chance PPCN's team already exists — Liviqa shipped a beta under
`xyz.ppcn.liviqa` at some point, which means somebody registered a PPCN identifier
on an Apple team before. If that was this account, you are already enrolled.

---

## 1. The API key — reuse the one you have (0–4 minutes)

**Check first whether this is already done.** The Team ID and the App Store Connect
API key are TEAM-WIDE at Apple, not per-app. A key made for any earlier upload on
the PPCN team — Liviqa's, for instance — uploads Maude unchanged. If you still have
the `.p8` file, skip to step 3 and paste what you already have.

If it is gone (Apple only lets you download it once), make a new one:

1. Go to [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
2. **Team Keys** tab, not Individual Keys.
3. **+** → name `Maude CI` → access **App Manager**.
   It must be App Manager. A lesser role cannot create the signing certificate, and
   the build dies at the last step with an unhelpful message.
4. **Generate**, then take all three: the **Issuer ID** (UUID at the top), the
   **Key ID** (10 characters), and the downloaded **`.p8`**.

Your **Team ID** is 10 characters, on [developer.apple.com/account](https://developer.apple.com/account)
under Membership details.

## 2. Create the App Store Connect record (2 minutes)

This is the ONE step that cannot be automated, and it is worth saying why rather
than leaving it looking like an oversight. Apple's official App Store Connect API
has no endpoint that creates an app record. The only programmatic route is
fastlane's `produce`, which does not use an API key at all — it logs in as you with
your Apple ID, password and a 2FA code over an unofficial cookie session. That is
not something to run from a cloud session, and not something to put a password into
a chat window for. So: two minutes in a browser, once, for the life of the app.

1. Go to [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
2. Blue **+** → **New App**.
3. Platform: **iOS**. Name: `Maude`. Primary language: **English (U.K.)**.
   Bundle ID: `xyz.ppcn.maude` — see the note below if it is not in the dropdown.
   SKU: `maude-ppcn` (internal only, nobody sees it).
4. **Create**.

**If `xyz.ppcn.maude` is not in the dropdown**, the App ID has not been registered
yet. You do not have to register it by hand: run the pipeline once in `upload` mode
and stop worrying about the failure — `xcodebuild -allowProvisioningUpdates` uses
the API key to create the App ID, tick HealthKit / App Groups / Sign in with Apple
from the entitlements file, create `group.xyz.ppcn.maude`, and issue the
distribution certificate and profiles. Then come back here and the bundle ID will be
in the list. *(Apple's behaviour, not something this repo can test — if the archive
instead fails with a provisioning error naming something it could not create, send
me the error and that one thing gets registered by hand.)*

You never submit this record for review. TestFlight builds go to you and anyone you
invite on the team, with no Apple review, as long as they are internal testers.

## 3. Put four values into GitHub (3 minutes)

1. Go to [github.com/clausfn/maude-ios/settings/secrets/actions](https://github.com/clausfn/maude-ios/settings/secrets/actions)
2. **New repository secret**, for each one you do not already have:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | the 10 characters from Membership details |
| `ASC_ISSUER_ID` | the UUID from step 1 |
| `ASC_KEY_ID` | the 10 characters from step 1 |
| `ASC_KEY_P8_BASE64` | the `.p8` file, converted — see below |

The last one has to become a single line of text first. In Terminal, with the real
filename:

```
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
```

That puts the converted text on your clipboard. Paste it straight in. Nothing is
printed on screen, and the workflow never prints it either.

**Not sure which are already set?** Run the pipeline in **check** mode (below). It
reports all four as SET or MISSING and stops — no build, no upload, nothing that
reaches a tester.

---

## Then press the button

1. Go to [github.com/clausfn/maude-ios/actions/workflows/release.yml](https://github.com/clausfn/maude-ios/actions/workflows/release.yml)

   **The button only appears once this workflow is on the `main` branch.** GitHub
   lists manual workflows from the default branch only, so until PR #1 is merged the
   page is empty. That is not a setup mistake; it is how `workflow_dispatch` works.

2. **Run workflow** → **mode: check** first. It reports which secrets are in place
   and stops. Then run it again with **mode: upload**.
3. About fifteen minutes to build and upload. Apple then processes it for another
   five to fifteen.
4. Install **TestFlight** from the App Store on your phone, sign in with the same
   Apple ID, and Maude is there.

If it fails, the run's log ends with the actual error rather than a wall of build
output — the workflow has a diagnostics step for exactly that.

---

## What you will actually see on the phone

Be ready for this, so it is not a surprise.

**It is the health app, wearing PPCN.** Maude today is Liviqa 10.106 with PPCN's
brand and PPCN's mark on it, and the glucose screen's legibility fixed. Everything
in the health domain works: Apple Health reading, the on-device intelligence,
glucose, sleep, heart, activity, the journal, the encrypted store.

**The money half does not exist yet.** Zones, the ClickUp mirror, deadline
countdowns, the Danica Select wrapper — none of it is built. `CLAUDE.md` lists them
as what Maude adds beyond Liviqa, and that is still a plan, not code. A build today
gives you eyes on the health navigator, not the health *and wealth* navigator.

**It starts empty, on purpose.** No fabricated readings. Grant Apple Health access
when it asks and the screens fill from your own data. Until then you get honest
empty states, which is correct behaviour and not a broken build.

**It runs entirely on your phone.** The shipped build talks to no server. Sign-in is
satisfied locally — any email of yours and any password of six characters or more.
This changed for this release: inherited from Liviqa, the release build pointed at
`api.maude.app` and `auth.maude.app`, which are Data for Good's live systems.
Shipping that would have signed a PPCN app into DfG's production. See
`Maude/Config.swift` and `Maude/ReleasePosture.swift`, which now crashes the app on
launch if anyone repoints it there.

**Sign in with Apple starts fresh.** Apple's user identifier is scoped to the team
that signs the app. Under PPCN's team it is a new identity, so nothing carries over
from any earlier build you may have installed.

**Data for Good is still visible in places.** The onboarding still has a governance
screen about DfG, and the consent wallet, donation export and research-participation
features are still in the app. Fifty-eight files, listed in `DFG_SEPARATION.md`.
None of them send anything anywhere now that the backend is local, but they are on
the screen, and what happens to them is your call.

---

## Notes

- Build numbers come from the GitHub run number, so they always increase. Apple
  rejects a repeat.
- The version string is `MARKETING_VERSION` in the Xcode project, currently `0.1`.
- Nothing here is submitted to the App Store. Internal TestFlight only.
- `Config/Signing.xcconfig` holds the Team ID and is git-ignored, so the team never
  reaches the repository. CI writes it from the secret at build time.
