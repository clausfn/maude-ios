# Getting Maude onto your phone

**Decided 7 Sep 2026 (CN): Maude is signed by PPCN's Apple Developer account.**
Not Data for Good's, not a personal one. The app's identity is `xyz.ppcn.maude`,
which matches.

Everything on the code side is built and green. What is left is four things only
you can do, because they happen inside your Apple account in a browser and nobody
else can sign in as you. About twenty minutes, once.

When they are done, pressing one button in GitHub archives the app, signs it, and
uploads it to TestFlight on its own, every time.

---

## Before you open anything

One check, because it decides whether the next twenty minutes work at all.

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

## 1. Register the app identity (5 minutes)

Apple has to know the app exists before it will accept a build.

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
2. Click the blue **+** next to *Identifiers*.
3. Choose **App IDs** → **Continue** → **App** → **Continue**.
4. Description: `Maude`. Bundle ID: select **Explicit** and type `xyz.ppcn.maude`
5. Scroll the capability list and tick these three. The app does not build without them:
   - **HealthKit** — reading your Apple Health data, which is the point
   - **App Groups** — so the watch app and the phone app share one store
   - **Sign in with Apple**
6. **Continue** → **Register**.

Then the app group, on the same Identifiers page:

7. **+** again → scroll to **App Groups** → **Continue**.
8. Description: `Maude`. Identifier: `group.xyz.ppcn.maude` → **Continue** → **Register**.

Then click back into your App ID, **Edit** next to App Groups, tick the group you
just made, **Save**.

*If Apple says `xyz.ppcn.maude` is already taken:* it is registered on another team.
Tell me the exact wording — the fix is either to release it from that team or to
change one line of the app's identity, and which one depends on where it sits.

## 2. Create the App Store Connect record (3 minutes)

1. Go to [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
2. Blue **+** → **New App**.
3. Platform: **iOS**. Name: `Maude`. Primary language: **English (U.K.)**.
   Bundle ID: pick `xyz.ppcn.maude` from the dropdown — if it is not listed, step 1
   did not save. SKU: `maude-ppcn` (internal only, nobody sees it).
4. **Create**.

You never submit this for review. TestFlight builds go to you and anyone you invite
on the team, with no Apple review, as long as they are internal testers.

## 3. Make an API key so the robot can upload (4 minutes)

This is what lets GitHub upload without your password.

1. Go to [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
2. Make sure you are on the **Team Keys** tab, not Individual Keys.
3. Blue **+**. Name: `Maude CI`. Access: **App Manager**.
   It must be App Manager. A lesser role cannot create the signing certificate, and
   the build fails at the last step with an unhelpful message.
4. **Generate**.
5. The page now shows three things, and the file downloads **once only**:
   - **Issuer ID** — a long UUID at the top of the page. Copy it.
   - **Key ID** — 10 characters, in the row for the key you just made. Copy it.
   - **Download** the `.p8` file. Apple will not give it to you again.

## 4. Put the four values into GitHub (3 minutes)

1. Go to [github.com/clausfn/maude-ios/settings/secrets/actions](https://github.com/clausfn/maude-ios/settings/secrets/actions)
2. **New repository secret**, four times:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | the 10 characters from Membership details |
| `ASC_ISSUER_ID` | the UUID from step 3 |
| `ASC_KEY_ID` | the 10 characters from step 3 |
| `ASC_KEY_P8_BASE64` | the `.p8` file, converted — see below |

The last one has to be turned into a single line of text first. On your Mac, open
Terminal and run this with the real filename:

```
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
```

That puts the converted text on your clipboard. Paste it straight into the secret.
Nothing is printed on screen, and the workflow never prints it either.

---

## Then press the button

1. Go to [github.com/clausfn/maude-ios/actions/workflows/release.yml](https://github.com/clausfn/maude-ios/actions/workflows/release.yml)
2. **Run workflow** → pick the branch → **Run workflow**.
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
