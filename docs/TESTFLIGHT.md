# Getting Maude onto your phone

Everything on the code side is built. What is left is four things only you can do,
because they happen inside your Apple account in a browser and nobody else can sign
in as you. Roughly twenty minutes, once.

When they are done, `.github/workflows/release.yml` archives the app, signs it and
uploads it to TestFlight on its own, every time you press the button.

---

## Before you start: one decision

**Which Apple Developer account signs Maude?**

Maude's app identity is `xyz.ppcn.maude` — PPCN's. It is not Data for Good's, and
the whole point of the fork is that the two never merge. So the team that signs it
should be PPCN's own.

- **If PPCN already has an Apple Developer Program membership**, use it. Skip ahead.
- **If it does not**, you have two honest options:
  - **Enrol PPCN.xyz APS.** Costs 99 USD a year. An organisation enrolment needs a
    D-U-N-S number, which Apple will look up or issue for free, and Apple verifies
    the company. Allow a few days. This is the right long-term answer.
  - **Use your personal Apple Developer account** to get eyes on it this week, and
    move to the PPCN team later. Moving means changing one line in
    `Config/Signing.xcconfig` and re-uploading — no code change. The cost is that
    the build lives under your personal name until then.

**Do not sign it with the Data for Good team.** It would put a PPCN app under DfG's
legal entity, and the App Store record is public.

Everything below assumes you have picked one and can sign in to
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) with it.

---

## 1. Register the app identity (5 minutes)

Apple needs to know the app exists before it will accept a build.

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
2. Click the blue **+** next to *Identifiers*.
3. Choose **App IDs** → **Continue** → **App** → **Continue**.
4. Description: `Maude`. Bundle ID: select **Explicit** and type `xyz.ppcn.maude`
5. Scroll the capability list and tick these three. Maude will not build without them:
   - **HealthKit** — reading your Apple Health data, which is the whole point
   - **App Groups** — so the watch app and the phone app share one store
   - **Sign in with Apple**
6. **Continue** → **Register**.

Then the app group, on the same Identifiers page:

7. **+** again → scroll to **App Groups** → **Continue**.
8. Description: `Maude`. Identifier: `group.xyz.ppcn.maude` → **Continue** → **Register**.

Then go back to your App ID, click it, click **Edit** next to App Groups, and tick
the group you just made. **Save**.

## 2. Create the App Store Connect record (3 minutes)

1. Go to [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
2. Blue **+** → **New App**.
3. Platform: **iOS**. Name: `Maude`. Primary language: **English (U.K.)**.
   Bundle ID: pick `xyz.ppcn.maude` from the dropdown — if it is not there, step 1
   did not save. SKU: `maude-ppcn` (internal only, nobody sees it).
4. **Create**.

You never have to submit this for review. TestFlight builds go to you and anyone
you invite, without Apple reviewing anything, as long as the testers are on your
team ("internal testing").

## 3. Make an API key so the robot can upload (4 minutes)

This is what lets GitHub upload without your password.

1. Go to [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
2. Make sure you are on the **Team Keys** tab, not Individual Keys.
3. Blue **+**. Name: `Maude CI`. Access: **App Manager**.
   It must be App Manager — a lesser role cannot create the signing certificate,
   and the build will fail at the last step with an unhelpful message.
4. **Generate**.
5. The page now shows three things. You need all three, and the file can only be
   downloaded **once**:
   - **Issuer ID** — a long UUID at the top of the page. Copy it.
   - **Key ID** — 10 characters, in the row for the key you just made. Copy it.
   - **Download** the `.p8` file. Keep it somewhere safe; Apple will not give it
     to you again.

## 4. Put the four values into GitHub (3 minutes)

1. Go to [github.com/clausfn/maude-ios/settings/secrets/actions](https://github.com/clausfn/maude-ios/settings/secrets/actions)
2. **New repository secret**, four times:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | 10 characters. Top right of [developer.apple.com/account](https://developer.apple.com/account) under your name, or in Membership details. |
| `ASC_ISSUER_ID` | the UUID from step 3 |
| `ASC_KEY_ID` | the 10 characters from step 3 |
| `ASC_KEY_P8_BASE64` | the `.p8` file, converted — see below |

For the last one, the file has to be turned into a single line of text first. On
your Mac, open Terminal and run this, with the real filename:

```
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
```

That puts the converted text on your clipboard. Paste it straight into the secret.
Nothing is printed to the screen, and the workflow never prints it either.

---

## Then press the button

1. Go to [github.com/clausfn/maude-ios/actions/workflows/release.yml](https://github.com/clausfn/maude-ios/actions/workflows/release.yml)
2. **Run workflow** → pick the branch → **Run workflow**.
3. About fifteen minutes to build and upload. Apple then processes it for another
   five to fifteen.
4. Install **TestFlight** from the App Store on your phone, sign in with the same
   Apple ID, and Maude will be there.

If it fails, the run's log ends with the actual error rather than a wall of build
output — the workflow has a diagnostics step for exactly that.

---

## What you will actually see on the phone

Be prepared for this, so it is not a surprise.

**It is the health app, wearing PPCN.** Maude today is Liviqa 10.106 with PPCN's
brand on it and the glucose screen's legibility fixed. Everything in the health
domain works: HealthKit reading, the on-device intelligence, glucose, sleep, heart,
activity, the journal, the encrypted store.

**The money half does not exist yet.** Zones, the ClickUp mirror, deadline
countdowns, the Danica Select wrapper — none of it is built. `CLAUDE.md` lists them
as what Maude adds beyond Liviqa, and that is still a plan, not code. A build today
gives you eyes on the health navigator, not the health *and wealth* navigator.

**It starts empty, on purpose.** No fabricated readings. Grant Apple Health access
when it asks and the screens fill from your own data. Until then you get honest
empty states, which is the correct behaviour and not a broken build.

**It runs entirely on your phone.** As of 7 September 2026 the shipped build talks
to no server at all. Sign-in is satisfied locally — any email of yours and any
password of six characters or more. This changed specifically for this release:
inherited from Liviqa, the Release build pointed at `api.maude.app` and
`auth.maude.app`, which are Data for Good's live systems. Shipping that would have
signed a PPCN app into DfG's production. See `Maude/Config.swift` and
`Maude/ReleasePosture.swift`, which now crashes the app on launch if anyone ever
repoints it there.

**Data for Good is still visible in places.** The onboarding still has a governance
screen about DfG, and the consent wallet, donation export and research-participation
features are still in the app. Fifty-eight files, listed in `DFG_SEPARATION.md`.
None of them send anything anywhere now that the backend is local, but they are
still on the screen, and what happens to them is your call — particularly whether
the consent wallet becomes your own audit ledger or goes.

**The app icon is still Liviqa's iris**, renamed but not redrawn.

---

## Notes

- Build numbers come from the GitHub run number, so they always increase. Apple
  rejects a repeat.
- The version string is `MARKETING_VERSION` in the Xcode project, currently `0.1`.
- Nothing here is submitted to the App Store. Internal TestFlight only.
- `Config/Signing.xcconfig` holds the Team ID and is gitignored, so the team never
  reaches the repository. CI writes it from the secret at build time.
