# TestFlight Beta Feedback Register

_Source: App Store Connect betaFeedbackScreenshotSubmissions (fetched via ASC API). One row per
submission; FB ids are the ASC submission id prefixes. Status: fixed / superseded / proposed / open._

| FB id | Date | Feedback (verbatim gist) | Diagnosis | Status |
|---|---|---|---|---|
| FB-AOIWoD6l | 06-10 | "Not how public hospitals work — either side requests a planned video consultation; other side accepts or proposes another slot (30 min slots)" | Booking needs a REQUEST → ACCEPT/COUNTER workflow, not direct booking. Telecare North / GP video-system best practice incoming from CN | **PROPOSED** — design next; awaiting CN's Telecare North material. Foundation laid: real backend Appointment booking shipped 06-11 |
| FB-AIEzHyog | 06-09 | "Flow is wrong — inform/call user, then plan in calendar; clinician should be default moderator; multi-party for specialists; planned + instant flows" | Same workflow theme + moderator default | **PARTIAL** — instant flow now auto-notifies the citizen in-app (PR-68); planned flow = the request/accept workflow above; moderator default = console starts the room (is moderator) |
| FB-ACOOcPPf | 06-09 | "Use case vs ŌURA? A bit restrictive" | Positioning question, not a defect — Liviqa's difference is consent/sharing/care, not ring metrics | **OPEN (narrative)** — for the pitch deck/onboarding copy, not code |
| FB-AFf8FjC1 | 06-09 | "This view of consent is broken" | Privacy grant cards rendered raw metric keys through a stub FlexHStack (plain HStack) → chips crushed into vertical letter-shreds | **FIXED** (PR-69): real FlowLayout + grouped, deduped chips ("Glucose", "Activity"…) |
| FB-AEZv4wJ8 | 06-09 | "Not working with the calendar" | Old (pre-redesign) journal calendar strip overlap; PlanConsult was local-only | **SUPERSEDED** — verify on 10.29; scheduling is now backend-real |
| FB-ABpGIUrM | 06-09 | "Same" | Same area, same minute as above | **SUPERSEDED** (with AEZv4wJ8) |
| FB-AJ8M7416 | 06-09 | "This will not work ;)" | Same scheduling area | **SUPERSEDED** — replaced by real booking + (proposed) request flow |
| FB-AK0022Mv | 06-09 | "Can we hide the technical token?" | Consult pre-join showed the raw Jitsi room id ("Liviqa Consult Cmq 67 Ttke…") | **FIXED** (PR-68): call titled "Liviqa video call", room id never shown |
| FB-AOUGIncO | 06-09 | "Confusing start on the mobile screen on video" | Jitsi welcome/prejoin noise + full toolbar | **FIXED** (PR-68): prejoin off, toolbar = mic/camera/hangup |
| FB-AH-UhwJB | 06-09 | "My LV round icon is gone — how do I navigate here" | Old-build navigation (pre-v2 tabs) | **SUPERSEDED** — v2 app bar always shows the avatar; verify on 10.29 |
