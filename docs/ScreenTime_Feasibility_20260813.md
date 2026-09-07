# Screen Time on iOS — what is actually obtainable, and what it would cost us

**Status:** feasibility assessment. **Nothing was built.**
**Written:** 2026-08-18. The filename carries the directive's batch date (2026-08-13).
**Author:** iOS engineering, on CN's directive *"Allow to access screentime, read calendar
load and other data sets on the device to determine health."*
**Sources:** Apple Developer documentation, fetched and quoted 2026-08-18 (URLs at the end).
Every claim about Apple's APIs below was checked against the documentation on that date,
not against memory or against the framing of the directive.

---

## 0. Where the brief was right, and the one place it needs correcting

The directive I was given said, in summary: *DeviceActivity/FamilyControls needs Apple's
Family Controls entitlement, and the report extension is designed so the app CANNOT read
the values into memory or persist them.* I was asked to verify that rather than trust it.

**Both halves are correct.** Apple's own words:

> "You must add the Family Controls capability to your app before you call the
> `requestAuthorization(for:)` … method. This capability adds the
> `com.apple.developer.family-controls` entitlement to your app. Before submitting your app
> to the App Store, you must [request permission] to use the entitlement."
> — *Family Controls* framework overview

> "To protect the user's privacy, your extension runs in a sandbox. This sandbox prevents
> your extension from making network requests or moving sensitive content outside the
> extension's address space."
> — *DeviceActivityReport*

**The correction — and it matters for what we could build.** "The app cannot read the
values" is true of the **report** path, which is the one everybody means by "read Screen
Time". It is **not** the whole picture. There is a second, narrower path Apple does allow
data to come back through:

- `DeviceActivityCenter.startMonitoring(_:during:events:)` registers **thresholds you
  declare in advance** ("30 minutes of this selection, during this schedule").
- When one is crossed, the system calls `DeviceActivityMonitor.eventDidReachThreshold(_:activity:)`
  in a **monitor** extension (a different extension from the sandboxed report one).
- That callback carries the **event name and the activity name** — no numbers, no app
  identities — but the callback *happening* is itself a fact, and the monitor extension can
  write it into a shared App Group container that the app then reads.

So the honest statement is: **we cannot read anyone's screen time. We could, with the
entitlement, learn that a threshold we ourselves defined was crossed** — a one-bit-per-day
signal per threshold, whose meaning we chose up front. That is a real difference from
"nothing at all", and it is the only version of this worth proposing, because it also
happens to be the version that respects the person: we would never learn what they use,
only that a line they agreed to was crossed.

I am flagging this explicitly, per the instruction to say so if my reading contradicts the
brief. It does not contradict it in substance — it refines it.

---

## 1. What is actually obtainable

### 1a. Available to any app, no entitlement
**Nothing.** There is no public API for total screen time, unlocks, pickups, notification
counts, or per-app usage outside the Family Controls family. An app can measure **its own**
foreground time and nothing else.

### 1b. Available with the `com.apple.developer.family-controls` entitlement

| Capability | API | What we would actually get |
|---|---|---|
| Show the person a usage report | `DeviceActivityReport` + a report extension | A **SwiftUI view** rendered inside a sandboxed extension. The app can display it. The app **cannot read the numbers**, cannot persist them, cannot send them anywhere. |
| Learn a threshold was crossed | `DeviceActivityCenter.startMonitoring` + `DeviceActivityMonitor` extension | A **callback** naming the event and activity we defined. No values. Writable to an App Group, so it can reach the app. |
| Let the person pick what to monitor | `FamilyActivityPicker` → `FamilyActivitySelection` | **Opaque tokens**. Apple: `FamilyActivitySelection` "holds opaque values that represent categories, applications, and web domains". The app never learns which apps were chosen — only `Label(token)` can render them, and tokens are voided if authorization is revoked. |
| Shield or restrict apps | `ManagedSettings` | Out of scope for Maude and out of character for it. We do not restrict people. |

What "device activity" means, in Apple's definition: *"the amount of time an application,
category, or web domain is frontmost on the screen"*, accumulated in the time zone of the
schedule's start date. Web activity includes third-party browsers only when they contribute
via `STWebpageController`.

### 1c. Authorization, for an adult using it on themselves
`AuthorizationCenter.requestAuthorization(for:)` accepts `.individual` as well as `.child` —
Apple: *"A parent or guardian must authenticate a child's account, while individuals can
authenticate their own account."* The individual is authenticated with Face ID / Touch ID.
So the parental-controls framing does **not** block an adult-self-monitoring use, which is
the only use Maude would ever have. It is revocable (`revokeAuthorization`), and revocation
voids every token previously issued.

---

## 2. What the entitlement requires, and how it is requested

1. **Add the Family Controls capability** in Xcode, which writes
   `com.apple.developer.family-controls` into the app entitlements. Development and
   TestFlight work on the development form of the entitlement.
2. **Before App Store submission**, request the **distribution** form through Apple's
   request form: <https://developer.apple.com/contact/request/family-controls-distribution>.
   This is a human review by Apple, not a toggle.
3. **Expect to justify the use case.** The entitlement exists for parental-controls and
   screen-wellbeing apps. Maude is neither of those things by category, and the request
   would have to make the adult-self-monitoring case explicitly. **We should assume it can
   be refused, and design so that a refusal costs us nothing.**
4. **Two new app extensions** (report and/or monitor), each with its own bundle id, profile
   and review surface, plus an App Group if the monitor path is used.
5. **Consequences to note before asking.** Authorizing Family Controls changes device
   behaviour: Apple states the system *"removes any restrictions that prevent the user from
   bypassing parental controls so the user can delete an authorized app or sign out of
   iCloud as needed"*. It is a heavier grant than a normal privacy prompt, and the citizen
   deserves to be told that in our own words before they meet Apple's dialog.

**Estimate, if granted:** the entitlement request and its review dominate. The engineering
is roughly one week for the threshold path (extension, App Group hand-off, opt-in surface,
derivation, honest-absence states, tests) and about half that again if we also render the
read-only report view.

---

## 3. What we would build if it were granted

Deliberately the *smallest* thing that is a real signal, and nothing that reads content.

- **The person sets their own line.** In their words: "tell me when I've been on my phone
  past midnight" or "past two hours after 21:00". We turn that into one
  `DeviceActivityEvent` with a threshold and a schedule. **The line is theirs, not a
  population norm** — the same rule the whole app runs on.
- **We store one number per day: how many of their own thresholds were crossed.** Not
  minutes, not apps, not domains — we would not have those, and would not keep them if we
  did.
- **It reads exactly like the calendar row.** A column in the 7-day grid, deviation from
  their own usual, "more evenings than your usual" — never "you use your phone too much",
  never a claim that a late evening caused a poor night.
- **The report view, if we ship it at all, is shown and not read.** `DeviceActivityReport`
  renders inside its own sandbox; we would present it as *the citizen's own view of their
  own data*, and say plainly on the screen that Maude cannot see what is in it. That is a
  rare and rather good honesty story: a screen where the app truthfully says "I am showing
  you something I cannot read."
- **Refusal costs nothing.** If Apple declines the entitlement, the feature simply does not
  appear. No placeholder, no coming-soon row that looks like a connection.

---

## 4. Usable proxies for "digital load" that need no entitlement

This is the part worth acting on now.

1. **Calendar load — built, in this same batch.** How full each day was, from the citizen's
   own calendar, density only. This is the strongest honest proxy for "load" available on
   the device without any special approval, and it is now a real column in the week grid.
   See `Maude/Context/CalendarLoad.swift` and FR-CTX-CAL-01.
2. **The sleep record already tells us most of what "late-night phone use" was a proxy
   *for*.** We ingest bedtime, sleep onset, fragmentation and wake time. "You went to bed
   later than your usual" is the fact we actually care about; screen time was only ever a
   guess at its cause. We have the fact. We do not need to guess at the cause, and under
   FR-NDG-06 we would not be allowed to assert one anyway.
3. **Maude's own session times.** We can honestly measure how long the citizen spends in
   *this* app. Low value as a health signal, and I would not ship it: it measures our
   product, not their life, and dressing it up as "digital load" would be exactly the kind
   of overclaim this codebase keeps getting bitten by.
4. **Focus status** (`INFocusStatusCenter`, separate user authorization) yields a coarse
   "Focus is on/off". It is a statement about an intention, not about usage, and it is
   noisy. Recorded as considered and **not** recommended.
5. **What does NOT exist, so nobody re-proposes it:** unlock/pickup counts, notification
   counts, keyboard or typing activity, per-app usage outside Family Controls, and any
   "total screen time" number. None of these have a public API.

---

## 5. Recommendation

1. **Do not build Screen Time now.** The report path cannot give the app a value, and the
   threshold path costs two extensions and an Apple approval we may not get.
2. **Ship the calendar-load signal** (done in this batch) and judge from real use whether a
   digital-load signal adds anything the calendar and the sleep record do not already say.
3. **If we still want it, request the entitlement early** — the review is the long pole —
   and scope the request to adult self-monitoring with citizen-defined thresholds, because
   that is both the honest use and the easiest one to justify to Apple.
4. **Meanwhile, the app must not pretend.** The "Screen Time" row on the Data sources
   screen used to open a sheet with a "Connect Screen Time" button that reached a seed array
   absent from shipping builds: it read nothing, changed nothing, and looked like a
   connection. In this batch it became a plain, non-tappable row that says Screen Time is
   not available and why. **That is the one code change this document caused.**

---

## Sources (fetched 2026-08-18)

- Family Controls — <https://developer.apple.com/documentation/familycontrols>
- `AuthorizationCenter.requestAuthorization(for:)` — <https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)>
- `FamilyActivitySelection` — <https://developer.apple.com/documentation/familycontrols/familyactivityselection>
- Family Controls (Distribution) request form — <https://developer.apple.com/contact/request/family-controls-distribution>
- Device Activity — <https://developer.apple.com/documentation/deviceactivity>
- `DeviceActivityReport` — <https://developer.apple.com/documentation/deviceactivity/deviceactivityreport>
- `DeviceActivityReportExtension` — <https://developer.apple.com/documentation/deviceactivity/deviceactivityreportextension>
- `DeviceActivityMonitor` / `eventDidReachThreshold(_:activity:)` — <https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor>
- `DeviceActivityEvent` — <https://developer.apple.com/documentation/deviceactivity/deviceactivityevent>
- `DeviceActivityCenter.startMonitoring(_:during:events:)` — <https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:)>
- `ApplicationToken` — <https://developer.apple.com/documentation/managedsettings/applicationtoken>
