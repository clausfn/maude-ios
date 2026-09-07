# Maude — App Privacy answers (App Store Connect "Data Privacy" questionnaire)

Draft answers for the App Privacy "nutrition label". The app is **on-device by default**:
HealthKit is read-only, samples are stored encrypted locally and are **never uploaded** by the
core loop. Two paths do leave the device and must be disclosed honestly — both **user-initiated**:
(1) **Sign in with Apple** auth, and (2) the **opt-in DfG consent share**, which sends only
DERIVED / aggregated, scoped data after explicit per-recipient consent (never raw samples).

> ⚠️ Claus / counsel to CONFIRM the two starred items below before submitting — the privacy-label
> classification of the consent share and of the auth identifier has legal weight (GDPR Art. 9 /
> the freely-given-consent question already tracked in the project).

## Recommended answers

**"Do you or your third-party partners collect data from this app?"**
- **Yes** — because Sign in with Apple and the optional consent share transmit data off device.
  (If a future build truly ships with zero off-device transmission, this becomes "No".)

### Data types

| Apple data type | Collected? | Linked to identity? | Used for tracking? | Purpose | Notes |
|---|---|---|---|---|---|
| Health & Fitness | **Only via the opt-in share*** | No (de-identified/aggregated) | No | App Functionality (research contribution) | Core loop keeps Health on-device; the DfG share sends DERIVED, scoped, de-identified data only after explicit consent. |
| Contact Info — Email* | Yes (Sign in with Apple) | Yes | No | App Functionality / Account | Apple private-relay email if the user hides it. Used only to authenticate the account. |
| Identifiers — User ID | Yes (account id) | Yes | No | App Functionality | Backend account identifier; not an advertising id. |
| Usage Data / Diagnostics | **No** | — | — | — | No analytics SDK; no crash/usage telemetry collected. |
| Location, Financial, Browsing, Contacts, Photos | **No** | — | — | — | Not collected. |

- **Tracking (ATT):** **No.** Maude does not track users across apps/sites; no IDFA; no ad networks.
- **Data used to track you:** none.
- **Data linked to you:** Email + User ID (auth only).
- **Data not linked to you:** the consented Health contribution is de-identified/aggregated.*

### If you want the simplest defensible label
If the consent-share feature is **not enabled for the first TestFlight build** (verify
`Config.dfgReceiptEnabled` / the share path is gated), then Health & Fitness can be declared
**Not Collected**, and the only collected items are the Sign-in-with-Apple email + user id for
account functionality. This is the cleanest position for an initial pilot.

## Permission strings shown to users (already in Info.plist — no action)
- Health (read): "Maude reads your Health data on-device to show your trends and personal,
  plain-language nudges. Your health data stays on this device and is never uploaded."
- Health (update): read-only — never writes to Apple Health.
- Camera / Microphone: only during a user-started video consultation (EU-sovereign).
- Calendar (write-only): adds a consultation you plan; never reads existing events.
