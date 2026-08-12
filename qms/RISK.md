# Risk Register (ISO 14971-aligned)

_Hazard → cause → mitigation → residual risk → linked requirement. Cardiac/glucose/medication lanes carry the top entries. Safety-path code changes require a row here (or an explicit "no new hazard" PR note). Version: 2026-06-03._

## A7.2 Area ⑨ — Knowledge base & AI behaviours (branch claude/a72-electric-ink, 2026-08-12)

Six census rows: the two-tier HRV knowledge screen (new) and the four designed
assistant example behaviours (explain / plain-language / calibration / safe
redirect) on the existing ChatGuard-protected chat. Safety posture:

- **ChatGuard input surface STRENGTHENED (additive only — RK-CHAT lane).**
  While building the designed redirect presentation, a gap was found in
  `blockedIntent`: dose-adjustment vocabulary without the words dose/insulin
  ("time to titrate my basal?", "how much bolus for pasta?") passed the input
  guard (outcome stayed safe — the deterministic responder cannot advise — but
  the question did not route to care as designed). New additive pattern
  `titrat…|basal|bolus|prescri…` in `Liviqa/Chat/LiviqaChat.swift`; pinned by
  new `ChatGuardTests` red-team arguments. No pattern was removed or narrowed;
  a companion test pins that the designed descriptive prompts are NOT refused.
  Residual risk: unlisted drug names still pass the input guard; the
  deterministic responder answers descriptively and `sanitizeOutput` strips
  advice, so the failure mode is a generic answer, never advice. Unchanged.
- **Designated control `safetyLine` UNCHANGED (open ruling, DHF 2026-08-12:
  counsel memo required before any copy change).** The canvas's warmer,
  dose-specific redirect copy (b-learn.jsx AIRedirect) was NOT adopted; only
  the PRESENTATION around the verbatim line shipped: two action chips opening
  the EXISTING consent-first flows (`ShareWithClinicianView` summaries-only,
  `PlanConsultView`) plus a proof footer. Chips generate no text and never
  re-enter the model. The canvas's named clinician ("Mette, your diabetes
  nurse") renders only from a real care-team record, generic otherwise.
  `ChatBehaviourTests.redirectIntentIsSafetyAndLineIsUnchanged` +
  `redirectFollowUpsAreConsentFirstActionsOnly` pin both. Divergence list for
  the counsel memo lives in the PR notes.
- **Honest answer-origin (T1) — "Answered on this iPhone" can no longer
  overclaim.** The canvas shows the proof line unconditionally; the consented
  Mistral cloud path would have made it false. `ChatReply.origin` tracks where
  the SHOWN text was generated (guard refusals on the cloud path stay
  `.onDevice` — the prompt never left the phone; cloud fallbacks likewise);
  the footer renders a truthful Mistral-EU variant for `.cloud`. Pinned by
  `ChatBehaviourTests.guardRefusalOnCloudPathNeverLeftThePhone`.
- **No fabricated calibration progress (T1).** The canvas's "day 1 of about
  14" + 8% bar conflicts with Home's deliberate no-fake-day-counter stance
  (TodayView.baselineBuildingCard). Chat adopts Home's story: a real
  days-of-data count when one exists (PassportStats.daysTracked), an
  indeterminate bar otherwise, and the same "about 3 days" first-insight
  expectation. Pinned by `ChatBehaviourTests.calibrationNeverFabricatesADayCounter`.
- **No invented life context / no invented derivations.** The explain template
  never asserts meetings/dinners (pinned test); the Learn clinical tier drops
  the non-derivable "measured 00:30–05:00"/"Nightly ≥3h" claims for the
  truthful daily-average method description; the plain-glucose "better than
  most weeks" clause is computed against the user's own month or CUT; the
  post-meal clause renders only from the real DayReplay curve. New
  `HRVLearnDeriver` claims nothing below 5 days and always labels its actual
  window. FR-NDG-06 untouched; chat keeps clinical red out ("comfortable
  middle band" phrasing); glucose stays mmol/L (OD-07); provenance never
  renders. No new hazard elsewhere.

## A7.2 Area ⑧ — Account & settings + Watch (branch claude/a72-electric-ink, 2026-08-12)

Twelve census rows: Account & security (new), dedicated Delete screen, the
edition-model Notification settings (FR-NOT-01/02), real voice-note capture
(FR-JRN-04), profile/declaration small deltas, and the watch glance honesty
fixes. Safety posture:

- **FR-REG-01 — MDR notice single-sourced (safety-copy move).** The two
  DIVERGENT wordings of the wellness-not-device notice (SettingsView
  regulatory card vs InAppPrivacyView) are replaced by ONE canonical constant
  (`Liviqa/Models/RegulatoryCopy.mdrNotice`, the long form); the Account
  screen's short DfG footer lives in the same file so the two sentences are
  reviewed together and can never drift into contradicting claims. A wording
  review now touches exactly one line.
- **RK-DEL-01 posture HELD; one claim downgraded, one option added.** The
  dedicated Delete screen (ScrDeleteData) PRESERVES the server-first erase
  ordering and its honest retryable failure state (T-DEL-01/T1 — the canvas
  omits it; `EraseOrderingTests` unchanged). The canvas' "consent receipts
  kept 30 days by law" is NOT shipped — nothing in the client or backend
  contract verifies a 30-day period; the row says "kept only as long as the
  law requires, then erased". **OPEN COMPLIANCE ITEM: confirm the actual
  statutory receipt-retention period with the backend before Release and
  restore the precise number.** "Keep documents, erase the rest" is REAL and
  minimal: `deleteAllData(keepDocuments:)` branches around exactly the
  Area ⑦ vault-clear step (2d) and nothing else — the server erase is
  identical because the server never holds documents (no upload path,
  FR-ING-15).
- **FR-JRN-04 — on-device-only claim gating (designated) now enforced in
  code.** The voice recorder's "Transcribed on this iPhone — the audio never
  leaves it." footer renders ONLY while an SFSpeech task with
  `requiresOnDeviceRecognition = true` is actually running; the flag is
  hard-set in the single request factory and asserted by `VoiceCaptureTests`
  (T-JRN-04, never skip). No server recognition path and no audio upload path
  exist in the capture code. When on-device recognition is unavailable the
  note degrades honestly to audio-only (no fake transcript). Audio lands in
  `journal-audio/` with `NSFileProtectionComplete` and is wiped by the GDPR
  erase. `Info.plist` mic string updated — the old "only during a video
  consultation" claim would have become false with voice notes.
- **FR-NOT-01/02 — notification content is allow-listed by construction
  (FR-NDG-06 designated).** The only strings that can reach a notification
  are the two static edition templates in `EditionNotifications` (morning /
  evening, silent, no health data, guard-checked in `NotificationPrefTests`).
  The earned-attention ALERT is deliberately NOT scheduled — no background
  picker exists, so the "at most one a day" cadence guarantee stays with the
  engine and nothing can outrun it. The default-OFF "Study & consent
  activity" pref gates only the foreground BANNER of study payloads; the
  in-app consent surfaces (bell badge, Care card) still update, so nothing
  consent-relevant is silently lost.
- **Watch — descriptive-only line strengthened, not weakened.** The glance
  `stateLine` now mirrors the phone's ACTUAL affirming line (the same three
  approved strings + thresholds as `TodayView.affirmHeadline`) instead of a
  hardcoded "steady week" — an honesty fix inside the existing non-MDSW
  vocabulary; no new strings, no verdicts, provenance still never travels in
  the payload. Recovery gains its " ms" unit.
- **Account & security — three canvas claims downgraded to what is true**
  ("Signed in" without a provider claim; backup "nothing has been backed up
  yet" — no engine exists; recovery contact = honest coming-soon). The
  NFR-SEC-08 app-lock control is wrapped (same `@AppStorage` pref +
  LAContext gate), not rebuilt.

No new hazard class introduced; two claims-vs-implementation gaps (delete
retention wording, watch state line) removed.

## A7.2 Area ⑦ — Integrations / data: real encrypted vault + honest source states (branch claude/a72-electric-ink, 2026-08-12)

Four census rows: DataSourcesView ScrDataSources rebuild (verdict band,
Connected/add split, manual entry, lawful-basis gate, disconnect),
HealthVaultView "Health data space" rebuild over a NEW encrypted document
store (FR-ING-15), and the two Connect-Sundhed.dk cosmetic deltas (Paths A/B).
Safety posture:

- **RK-VAULT-01 (NEW, claims-vs-implementation hazard REMOVED) — the vault's
  encryption claims are now literally true (FR-ING-15).** Hazard: the old
  HealthVaultView told the citizen "Your documents, on this device, encrypted"
  over a hardcoded demo seed (`VaultSeed`) — no document was ever stored, and
  the Data-sources "import" set only a toast string, so a citizen could
  believe a sensitive document was safely kept when it was silently discarded.
  Mitigation: `Liviqa/Security/HealthVaultStore.swift` — every document AND
  the metadata index (names are sensitive) sealed with AES-256-GCM
  (`CryptoBox` over the KeyVault DEK, ECIES-wrapped to the Secure-Enclave
  P-256 device key), written atomic + `NSFileProtectionComplete`, namespaced
  to `LocalUserScope` (never a backend id). Add (Files/Photos), preview,
  delete-with-confirm are real; delete removes the blob from disk immediately
  (no trash). The Secure-Enclave clause in the UI renders from
  `KeyVault.isHardwareBacked` — no enclave overclaim on SE-less simulators.
  GDPR erase wipes the store (`AppState.eraseEverything` 2d; a future "keep my
  documents" option must branch around exactly that line). Asserted by
  T-ING-15 (`HealthVaultStoreTests`: ciphertext-at-rest incl. index,
  delete-really-deletes on disk, metadata persistence across instances, GCM
  tamper → loud failure, scope isolation). No upload path exists in the store
  or either vault surface, and none may be added.
- **Consent rail — documents stay OUT of shares by default.** The space's
  consent strip states it ("money and insurance papers never enter a clinician
  share"); no code path feeds vault documents into `DerivedShareBuilder` or
  any grant — documents leave only as decrypted bytes under an explicit user
  action, and today no such share surface exists. Unchanged: FR-SHARE-02
  derived-only share payloads.
- **RK-SUND-01 posture HELD — no new extraction, no new egress.** Area ⑦
  touched Path A/B presentation only: first-import CTA aligned to the canvas
  ("Import from Sundhed.dk"), checklist row dress (the honest `.empty`/"none
  found" state kept — a row still never ticks green without a real capture),
  Path B review footer strengthened to the discard promise ("Only this coded
  summary is saved. The file itself … is discarded.") which matches the
  removed-upload reality; idle-stage OnDeviceChip added. Interception,
  reduction and the on-device-only sink are untouched; the MitID prompt
  (Area ① satellite) now fronts the session from Data sources too. The
  Sundhedsplatformen lawful-basis gate card renders ONLY when
  `Config.sundhedWebConnectEnabled` is false — the gate is the flag-off state,
  never a regression of the live path.
- **Manual entry (new surface, no new hazard class).** Hand-typed
  weight / blood pressure / glucose / sleep land through the SAME
  `HealthStore.ingest()` as every source, tagged `.manual` — the user-facing
  label "Entered by you" is the `HealthDataSource` provenance a citizen SHOULD
  see; the hidden `Provenance{REAL,SIMULATED,EXTERNAL}` field still never
  renders (T-PROV-01 unaffected). Glucose entry is mmol/L only (OD-07), with
  plausibility bounds (1–35 mmol/L) so a mistyped mg/dL value can't land.
  No nudge/deriver change: FR-NDG-06 untouched.
- **Honest connect/disconnect states.** The Connected card lists only sources
  genuinely connected in this build (real HealthKit deriver, persisted
  Sundhed.dk record, DEBUG demo seeds); Apple Health disconnect is NOT faked —
  the sheet says iOS holds that permission (Health app → Sharing); Sundhed.dk
  "disconnect" forgets the returning-user record while already-imported data
  stays until deleted, exactly as the copy promises.

## A7.2 Area ⑥ — Sharing & consent: the trust core (branch claude/a72-electric-ink, 2026-08-12)

Ten census rows: WalletView copy-register purge + UC-11/Research-hub entries,
ShareWithClinicianView single-scroll rebuild, CreateGrantView (new),
ConsentLedgerView claim gating, ShareReceiptSheet slip rebuild,
StudyConsentView defaults-off flip, ResearchHubView (new), TokenWalletView
donate-first rework, InAppPrivacyView proof surface. Safety posture:

- **RK-SHARE-03 (NEW) — the package's "Every reading" share mode is NOT built
  (OPEN QMS RULING, DHF 2026-08-12 night).** Hazard: ScrSharePattern's per-area
  "Summary only | Every reading" choice would ship raw measurement lists off
  the device, directly contradicting the repo's derived-only rail (FR-SHARE-02
  / `DerivedShareBuilder` — raw samples and provenance never enter a share
  payload) and the package's own ScrCreateGrant plate ("Raw readings can never
  be added to a grant · Locked on"). The canvas is internally inconsistent.
  Mitigation: the rebuilt share form is SUMMARIES-ONLY — area rows are on/off
  (no detail-level segmented pair), the verdict kicker reads "one area · one
  time period · summaries only", and the lock plate + CreateGrantView's
  non-interactive "Locked on" plate state the rail as UI. The mode stays
  unbuilt until the product/QMS ruling closes. No engine/deriver change; the
  existing `createGrantAndShare` path is untouched.
- **RK-WAL-09 — CE-stub receipts are NON-EVIDENTIARY: claim gating implemented
  (FR-WAL-09, safety-path copy).** Hazard: the ledger header "Nobody can edit
  this — not even us", the slip body "signed so nobody can change it
  afterwards", and a rendered proof number would overclaim while the backend
  runs CE_MODE=stub (no cryptographic receipt exists). Mitigation: evidentiary
  = `CEEvidence.isEvidentiary` (receipt id AND event hash — stub mode attaches
  neither). Proof number + "Signed at" + the signed-claim sentence render ONLY
  from evidentiary evidence (`ReceiptSlipModel.build`); otherwise the slip
  softens to "kept in your consent record" and "Recorded at". The consent
  record's header claim gates the same way
  (`ConsentLedgerView.headerClaim(hasEvidence:)` → "It is designed so nobody
  can edit it" without evidence), and the per-event "verified" chip + evidence
  block render only on evidentiary events. Asserted by T-WAL-09
  (`ConsentSurfaceTests`).
- **RK-RSCH-07 — study-consent defaults flipped to OFF (consent-safety
  default, FR-RSCH-07).** Hazard: `StudyConsentView` pre-selected ALL of a
  study's data categories, so a citizen could approve maximal scope with the
  pre-checked defaults doing the consenting. Mitigation: `initialSelection` is
  now empty for every study, the sheet says "Everything is off until you
  switch it on", and Approve & join stays disabled until ≥ 1 category is on
  (`canJoin`). Joined-state copy now names the categories actually selected,
  not the study's full request. Asserted by T-RSCH-07 (`ConsentSurfaceTests`).
- **k ≥ 5 stands; the wording is a translation.** "Grouped with at least 4
  other people — never shown alone" (research hub, study consent, wallet
  footer) equals k ≥ 5; `ResearchStudy.groupingPhrase` clamps to the k ≥ 5
  floor so a mis-seeded study can never lower the promise (NFR-RSCH-04
  unchanged, `cohortK ≥ 5`). Tested.
- **Token wallet (FR-DFG-07) — consent-record claim withheld.** Token events
  do not yet log as wallet events (local `TokenTransaction`s never reach the
  ledger), so the designed "earning and donating are written to your consent
  record" sentence is NOT shipped; the footer claims only what is true
  ("tokens carry no health data"). Donation descriptions carry the cause name
  only — no field can hold a reading (tested). Real ledger sums; Release keeps
  honest empty states (no fabricated catalogue/causes).
- **Revoke stays one-way; offline queue NOT built (conscious drop, honest
  failure instead).** The census manifest's queued-offline-withdraw has no
  backend/replay machinery; shipping copy that says "your stop is saved" over
  a reverted optimistic update would be false. Instead a failed stop reverts
  (existing `toggleGrant` behaviour) and the toast says honestly "Couldn't
  stop the share — you may be offline. Nothing changed; try again." Vocabulary
  converged on "stop" across WalletView/InAppPrivacyView/ledger (the old
  Pause/Resume demo control is deleted); reactivation remains an explicit
  fresh re-consent (FR-WAL-08 untouched).
- **Proof surface (NFR-PRIV-05) now proves with real state.** InAppPrivacyView
  drops its DEBUG-only fabricated grants (a Release proof sheet previously
  showed no sharing state at all) and mirrors `AppState.grants` read-only;
  empty state is the honest "No one." Airplane-mode proof is purely local
  framing (no network claim); "every look is logged" links the consent record
  and counts real `dataAccessed` events. Demo study never renders as a real
  open study (hub renders only `researchOpportunity`; honest empty state
  otherwise). Provenance renders nowhere on any Area-⑥ surface; no red/TIR;
  FR-NDG-06 untouched.

## A7.2 Area ⑤ — Care & Liviqa PRO citizen surface rebuilt to the A7 canvases (branch claude/a72-electric-ink, 2026-08-12)

- **RK-CONSULT-SHARE-01 (NEW) — the pre-visit share tick now creates a REAL
  consent grant (FR-PRO-01).** Hazards: (a) the citizen could believe more (or
  less) is shared than actually is; (b) a per-consult share could outlive the
  episode; (c) the derived payload could leak raw data or provenance.
  Mitigations: (a) the tick's copy is the verbatim summaries-only promise
  ("…never your raw data, which stays on this device") and the status line
  states the real posture — on the sovereign backend it reads "Shared for this
  consult · expires automatically in 24 hours · listed in your consent record"
  only AFTER the grant + summary push succeed; on failure the tick REVERTS
  (never a claimed share that didn't happen); off the sovereign backend no
  status line renders and nothing is transmitted. (b) the grant carries a 24 h
  expiry and summaries-only granularity; un-ticking revokes the exact grant the
  screen created (one-way, both events kept in the ledger); the grant stays
  manageable from Privacy like any other. (c) the payload rides the audited
  FR-SHARE-02 path (`DerivedShareBuilder`): derived summaries only, no raw
  samples, no provenance field, mmol/L (OD-07). Residual: LOW — a citizen who
  ticks in demo mode shares nothing (matching demo's empty network), and the
  console-side view-event ingestion (who saw what, when) is an OPEN contract
  item tracked on FR-PRO-01.
- **Consent-first join held (structural).** Joining IS the consent to the call
  on both surfaces that can start one (incoming ring, waiting-room auto-join);
  no pre-ticked boxes added, no join without the citizen's own tap/arm. The
  incoming-call consent line was MERGED, not replaced: canvas copy ("Joining is
  your consent to this call. X sees only the summary you've shared — never your
  raw data.") + the existing recording guarantee ("Recording stays off unless
  you allow it in the call.") — strictly stronger than either alone.
- **Recording consent (FR-WAL) — copy preserved, affordance repositioned.** The
  in-call consent moved from a card to the designed floating banner; the ask
  copy is byte-identical ("X asked to record this call. Only you can allow it —
  and you can stop any time."), the on-state keeps the logged-either-way
  disclosure, and Stop stays one tap. The unprompted "Allow recording" button
  (shown even when nobody asked) was REMOVED — a consent affordance now appears
  only against a real request: fewer accidental grants, no new hazard.
- **Waiting room stays honest.** The rebuilt (light) waiting room drops the old
  "Your clinician has been notified you're waiting" line — the app only polls;
  no notification is actually sent — and replaces it with the canvas body
  ("Your call opens automatically the moment they join."), which is literally
  what `waitLoop()` does. The 15-min grace state (reschedule offer) is kept.
  New footer promise "Secure EU video room · nothing is recorded without your
  say-so" is true by construction (NFR-SEC-07 EU Jitsi + citizen-owned
  recording consent).
- **No clinical red introduced.** Care surfaces stay fjord/moss; rust appears
  only on the standing boundary controls (decline/hang-up) it already owned.
  TIR/GMI render on NO iOS care surface — the red=TIR-only rail transfers to
  the console PRO build as a written obligation (FR-PRO-01). FR-NDG-06
  untouched (no nudge-engine code in this area).

- **RK-PMS-01 (NEW) — the wrong/harmful-nudge reporting channel (UC-19 /
  FR-PMS-01).** Hazards: (a) the PMS intake could leak health data off the
  device, and (b) the report flow could be mistaken for a care/triage channel.
  Mitigations: the payload is **summary-only by construction** — `PMSReport`
  carries only nudge id/tag/headline, shown-at, a fixed-choice reason and the
  user's optional note, and has no field that can hold a reading (key
  allow-list unit-tested, T-PMS-01). Transport is **queue-only**: the sovereign
  client exposes no PMS endpoint today, so reports persist in an on-device,
  file-protected outbox (wiped by GDPR erase) and the UI says so honestly
  ("will send when a reporting channel opens") — nothing transmits until a
  consented route exists. The sheet closes on a consent-ledger-style receipt
  listing exactly what is queued, and both the form and the receipt carry the
  urgent-care footer ("For anything urgent about your health, contact your care
  team. Liviqa doesn't diagnose or treat."). FR-NDG-06 is untouched — the
  channel feeds the guard's post-market loop, it never alters engine output
  (T-NDG-06* remain blocking).
- **Trends (FR-TOD-06) — correlation claims gated; red rail held.** The rebuilt
  Trends surface renders STRONG/MODERATE pills only past a conservative
  evidence gate (|r| ≥ 0.4 AND two-tailed p ≤ 0.05 via a critical-r table at
  N ≥ 10 paired days; STRONG at |r| ≥ 0.6); below the gate it shows an honest
  "still learning" refusal. The former hard-coded correlation/month narratives
  are deleted — every figure now derives on device from the user's own samples,
  so canned copy cannot render on any account. All sentences are fixed
  descriptive templates (guard-checked, T-TOD-06). The TIR chart stays
  personal-band framed ("Your usual · lo–hi%", moss/fjord); **no red anywhere
  on Trends** — clinical red remains exclusive to the glucose detail
  (RK-ALARM-01 lock re-affirmed). mmol/L canonical (OD-07). Same rail applied
  in passing to Insights' weekly metric cards (down-deltas were rust; now ink).
- **Day replay (scrub-your-day) — narration from derived figures only.** The
  "At HH:MM" moment card is generated from timestamped glucose plus a real
  tracked workout when one ended shortly before the peak; the canvas's canned
  at-timestamp steps/heart-rate sentences are NOT reproduced, because those
  streams exist only at daily granularity in the read model — **omitted rather
  than fabricated**. Time-of-day phrasing is generic ("Around lunchtime."),
  never a claim about meals or activities the app cannot see. Descriptive-only,
  mmol/L, no red. No new hazard beyond the honesty risks mitigated above.

## A7.2 Area ④ — non-glucose metric details rebuilt to the D-series anatomy (branch claude/a72-electric-ink, 2026-08-12)

Seven surfaces: Sleep, Heart, Fitness, Activity, Body, Vitals rebuilt/created
(`SleepDetailView` / `HeartDetailView` / `FitnessDetailView` /
`ActivityDetailView` / `BodyDetailView` / `VitalsDetailView` + derivers in
`Liviqa/Intelligence/`), plus the restyled baseline sheet
(`MetricBaselineView` + `BaselineDeriver`). Safety posture:

- **RK-ALARM-01 lock held — no clinical red on any Area-④ surface.** Heart uses
  the approved rose-punch `accentHeart 0xD9486B`; Body introduces the design's
  own indigo `accentBody 0x5B5FC7` (new token, extension in `MetricCharts.swift`);
  Sleep/Fitness/Activity/Vitals use their existing domain accents. `clinRed`
  appears nowhere in Area-④ code — the glucose detail remains the app's single
  red surface.
- **RK-CARD-01 / OD-11 / D9 — AFib lane stays display-only.** `HeartDetailDeriver`
  re-presents the recorded burden figure + observation-day count + date and
  nothing else: the type carries no series, band, trend or delta for AFib
  (structural mitigation), the card's foot prints the designated rail ("display-
  only — no score, no trend, no advice"), and the "Talk to your cardiologist"
  chip is a plain routing affordance into the existing share-with-clinician
  flow — not an alert. FR-NDG-06 (designated control) untouched; its tests
  remain blocking.
- **Sleep score — a DELIBERATE, transparent deviation from FR-SLEEP-01's "no
  score" clause.** The DSleep hero ring is the same anti-score-opacity stance
  as the accepted evening day score (FR-TOD-05): three visible fractions —
  rest = night/8 h × 50 (the accepted FR-TOD-05 divisor), depth = deep+REM
  share vs a stated 35% reference × 30, rhythm = last night vs the user's OWN
  week mean × 20 — printed under the hero, never an opaque composite. It
  refuses to render below 4 nights or without stage detail
  (`SleepDetailDeriverTests`). RTM FR-SLEEP-01 row annotated.
- **Personal-baseline framing everywhere.** Every band/corridor in Area ④
  (RHR band, BP corridors, activity "usual" line, body corridor, vitals bands,
  learned baselines) is the user's OWN mean ±1σ over the local window and
  refuses to render below 5 own readings — never a clinical reference range,
  never a population target (unit-tested per deriver). The Fitness screen
  carries the designated no-target line verbatim.
- **FR-NDG-06 exposure controlled.** All Area-④ sentences are fixed descriptive
  templates from derived numbers (no generated language); every template —
  including the design-package demo seeds — runs through `NudgeGuard.check`
  in the new deriver test files. The package's advice-adjacent fitness verdict
  ("your legs are asking for an easy day") is demo-seed-only; real verdicts
  are descriptive.
- **Data honesty.** Demo seeds render only behind `isDemoData` with no
  derivation (glucose-detail pattern); real sessions get honest empty states.
  Ingestion truths respected: no intra-night sleep times ⇒ the søkort depth
  chart, wake-up annotation and bedtime card are demo-only; no per-workout HR
  ingestion yet ⇒ avg-HR/zones honest-absent on real data (T-FIT-01).
  `provenance` never renders (unchanged).

No new hazard class introduced; existing mitigations extended to the new
surfaces as above.

## A7.2 Area ③ — Glucose detail rebuilt to the DGlucose anatomy (branch claude/a72-electric-ink, 2026-08-12)

- **RK-ALARM-01 — clinical red EXTENDED inside the glucose clinical charts,
  lock re-affirmed.** New token `clinRed 0xDA2F46` (package `clinRed`; dark
  lift `0xF0637A`, ≈4.8:1 on plate) renders in exactly three places, all
  inside the glucose clinical charts: (1) the out-of-range re-stroke of the
  day curve, (2) its above-target peak annotation, (3) the excursion caps on
  the week range bars. It appears nowhere as accent, border, chrome, or text
  outside those charts — the red-is-clinical-glucose-only lock holds, and the
  glucose detail remains the app's single red surface. Never colour-alone:
  the red marks coincide with position outside the labelled target band, the
  frozen PR-105 zone ramp keeps its hatch/dots/in-band labels, the TIR
  proportion bar names every band in a key with mmol/L ranges (extremes also
  patterned), and each week bar prints its own numeric TIR%. Both charts also
  carry VoiceOver values. The `clinicalTIRZones` flag reverts the day curve
  AND the red re-stroke AND the week-bar red caps to the personal-band idiom
  in one switch (no half-clinical state).
- **GMI derivation (HbA1c headline, OD glucose lane) — display-only.** New
  `GlucoseDetailDeriver` computes GMI = 3.31 + 0.02392 × mean mg/dL from the
  full on-device window, and refuses to emit it below 14 distinct days of
  readings (CGM consensus minimum) — the chip is absent, never an estimated
  stand-in. mmol/L canonical everywhere (OD-07). All screen sentences are
  fixed descriptive templates from derived numbers (no generated language,
  no diagnosis framing); week-over-week claims render only when the previous
  week actually has readings (unit-tested, `GlucoseDetailDeriverTests`).
- **FR-REG-04 — insulin stays data-layer only.** The design package's
  "insulin dots" row is deliberately NOT implemented: `InsulinReading` keeps
  no render path. Rendering dose events on the glucose curve would create the
  first insulin surface and re-open RK-GLU-01; recorded here as a conscious
  design deviation, not an omission.
- **Demo-honesty:** the design-package seed story renders only when no
  derivation exists AND the session is demo-tagged; a real device without
  glucose shows an honest empty state. Derived data always wins (no
  demo-over-real). `provenance` untouched — still never renders.

## PR-105 — A7.2 "Electric Ink" reskin: colour-semantic decisions (2026-08-12, CN sign-offs recorded)

- **RK-ALARM-01 — amber attention semantic RENEWED for A7.2.** The attention
  amber moves `0xFFB703 → 0xFFC533` in light mode (dark/watch keep `0xFFB703`).
  Hue family and all controls unchanged (one earned card/day, words stay ink,
  never amber small text). Residual risk accepted with eyes open: light amber
  now exactly aliases the TIR "high" band — an attention card could weakly read
  as glycaemic when it is sleep/recovery-derived; mitigation: attention cards
  always carry their domain icon + worded headline, TIR amber renders only
  inside the labelled glucose chart. CN sign-off 2026-08-12.
- **Heart accent: the package's saturated red REJECTED, rose adopted.** A7.2
  proposed `accentHeart = 0xE62E3D`; adopting a second saturated red would
  dilute red-means-clinical-glucose salience (colour-meaning collision, and
  inverse dulling of true alarm red). DECISION (CN 2026-08-12): substitute
  rose-punch `0xD9486B` (dark `0xF07E9B`, ≥3:1 on plate) — A7.2 saturation,
  unmistakably rose. No new hazard; the lock holds.
- **TIR ramp replacement — hazard REMOVED.** The old ramp's target-green vs
  low-red pair computed 1.05:1 luminance (deuteranopia trap, flagged in the A7
  direction review). The frozen A7.2 ramp + mandatory non-colour signals
  (hatch on very-low, dots on very-high, in-band labels, y-axis values) make
  the clinical bands legible without hue discrimination. Dark lifts verified
  ≥3:1 on plate (3.33/6.37/8.80/10.78/4.99). CN sign-off 2026-08-12.
- **No other clinical surface touched:** nudge engine, units (mmol/L, OD-07),
  AFib lane, provenance handling all unchanged; the reskin is presentation-only.

## PR-104 — Sundhed.dk on-device record wave + Phase 0 robustness (2026-08-12, dated catch-up — see CHANGELOG PR-104 notice)

- **RK-SUND-01 — in-app session-ride: terms/lawfulness grey zone + extraction
  fragility — OPEN (external-testing blocker).** Hazard: Path A captures
  sundhed.dk's own SPA responses inside an in-app WKWebView — the approach the
  governing DataAccess analysis (2026-07-09) assessed as likely against
  sundhed.dk's terms and recommended out-of-app; extraction depends on
  undocumented endpoints/DOM and can break silently on their side. Mitigations
  in place: SELF-ACCESS only (the citizen reads their own record, signed in
  themselves; credentials never visible to Liviqa); terminal sink is the
  on-device store ONLY (auto-upload removed — off-device requires the separate
  explicit FR-RSCH-05 act); honest empty/none-found states rather than
  fabricated results (hardened 10.94–10.98). NOT mitigated: the lawfulness
  posture itself — the in-code "sanctioned by Trifork/sundhed.dk" claim has no
  written artifact on file, and the DPIA (v01 draft) models a different
  architecture and excludes external testers. **Owner gates before external
  TestFlight: file the written sanction (or gate `sundhedWebConnectEnabled`
  off for external builds) + DPIA v02 signed.** Residual risk: open — accepted
  for the internal self-access cohort only.
- **RK-REC-01 — displaying national-record diagnoses (mis-reading /
  mis-tiering) — mitigated.** Hazard: a citizen misreads the plain-language
  diagnosis list, or the major/minor tiering demotes something they consider
  serious. Mitigations: display-only presentation of the citizen's OWN record
  (Liviqa adds no interpretation, no normality judgement, no advice); tiering
  is presentation-only with the full list reachable; entries attributed to the
  national record as source; the nudge engine is NOT coupled to conditions
  (FR-NDG-06 guard untouched — T-NDG-06/06b/06c green in the 2026-08-12 full
  run). Residual risk: low. Counsel addendum on diagnosis display + tiering
  vs the wellness boundary = open owner action (audit 2026-08-12).
- **RK-SLEEP-01 — fragment-vs-baseline sleep comparison — REMOVED by fix.**
  Hazard (pre-existing, found in the wave): `sleepNudge` compared a single
  sleep FRAGMENT against a baseline of fragments, risking false "below your
  usual" nudges on multi-source nights. Fix `574b971`: nightly totals are the
  union of asleep segments (same grouping as SleepDeriver); pinned by
  `SleepMergeTests`. Baseline-relative correctness improved; no new hazard.
- **RK-STORE-02 — silent persistence failure (data loss without signal) —
  ADDRESSED by construction (Phase 0, `530b32d`).** Hazards: (a) a failed
  ingest save rendered the imported record this session and lost it on
  relaunch with no signal (`try?`-swallowed save); (b) a failed store open
  fell back to in-memory with only a console print — on a TestFlight device a
  broken migration would read as "all my data vanished". Mitigations: ingest
  save now throws and surfaces honest user copy; `storeDegraded` renders a
  visible Home banner ("nothing new is being saved… existing data is safe");
  the Release provider-forcing seam is compiled out (posture lint added).
  Residual risk: low.
- **No new clinical hazard elsewhere in the wave:** no change to glucose units
  (OD-07 mmol/L), no AFib-lane change, no provenance rendering (field remains
  data-only; guard green), no new nudge categories.

## PR-103 — TestProd app wave (T1): erase-ordering hazard addressed by construction, no new clinical hazard (2026-07-07)

- **Stranded server data behind a "deleted" confirmation (GDPR Art. 17
  integrity) — ADDRESSED by ordering.** Hazard: with a server-side erase
  added to the Settings delete flow, a local-wipe-first sequence could wipe
  the device, show success, and then fail the network call — leaving the
  user's account data on the backend while they believe everything is gone
  (the PR-102 "false deletion assurance" hazard, moved to the server side).
  Mitigation (by construction): `AppState.eraseEverythingServerFirst()` calls
  `POST /me/erase` FIRST and runs the local wipe ONLY after the server
  confirmed `erased: true`; a server failure aborts before anything local is
  touched and surfaces a retryable, honest error ("nothing was removed yet —
  not from Liviqa's servers and not from this device"). Ordering pinned by
  `EraseOrderingTests` (failure aborts pre-wipe; success ordering
  server→local). The residual failure direction is the SAFE one: worst case
  the server is erased and the local wipe is interrupted (app killed
  mid-flow) — the device still holds the user's own data and the flow can be
  re-run; no state exists where the user was told "deleted" while server
  data persists. Residual risk: low.
- **No new clinical hazard.** Rails unification, GDPR surfaces, real journal
  sync, receipt display and cold-start honesty touch no nudge logic, no
  units (glucose mmol/L, OD-07), no provenance handling, no AFib lane, no
  FR-NDG-06 guard. The Release cold-start change only REMOVES fabricated
  data from shipped builds (extends the PR-102 demo-leak removal app-wide);
  the honest empty state cannot present synthetic values as the user's own.

## PR-102 — Pre-launch audit fixes, wave 1: two hazards REMOVED, none added (2026-07-03)

Both safety-path changes in PR-102 remove existing hazards; neither introduces a
new clinical hazard. Nudges, units (glucose mmol/L, OD-07), provenance handling,
the AFib lane, and the `FR-NDG-06` guard are untouched.

- **Fabricated data presented as the user's own (demo-login leak) — REMOVED.**
  Cause: `Config.dfgWalletLoginEnabled`/`nationalIDLoginEnabled` shipped `true` in
  Release, routing simulated wallet/eID sign-ins through `signInDemo()` → the
  fabricated LV001 9.5-year record rendered as the user's own data on
  HealthKit-empty devices. Mitigation: both flags are now `#if DEBUG`-gated
  (compile-time `false` in Release) AND `applyLV001DatasetIfNeeded()` is a no-op
  in non-DEBUG builds — defence in depth: no Release path can inject LV001.
  Residual risk: low (Debug/demo builds still show LV001 by design, for the
  pitch; never distributed to users).
- **False deletion assurance ("All local data deleted." while nothing was
  deleted) — REMOVED.** Cause: the Settings delete flow advanced to a success
  state with `AppState.deleteAllData()` unimplemented (GDPR Art. 17 exposure; a
  user could believe sensitive health data was erased when it persisted).
  Mitigation: `deleteAllData()` implemented (SwiftData entities + journal file +
  encrypted sync anchors + Keychain session + UserDefaults + in-memory reset)
  and the confirmation is shown only after the erase completes (T-DEL-01).
  Residual risk: low; verify with `T-DEL-01_deleteAllData_purgesEverything`.
- **Mistral key in the binary (security, not clinical):** key now DEBUG-only;
  Release uses the backend `/ai/chat` proxy. No clinical path affected — the
  ChatGuard before/after every call is unchanged. Key rotation = owner action.
- **Wave 2 (2026-07-03) — designated control T-PROV-01 was inert
  (audit-integrity, not a new clinical hazard).** The provenance-never-renders
  shell guard (`scripts/guard_provenance.sh`) was wired to no build/CI step and
  was exiting 1 on wallet-receipt word collisions ("provenance receipt",
  UC-24b/UC-21), while VnV/RTM/this file recorded it green and blocking.
  Fixed: pattern scoped to the provenance DATA FIELD (`.provenance` access,
  `provenance:` label, `Provenance` type/case — not the bare word), guard wired
  as a blocking `build-ios.sh` step before xcodebuild, and the false records
  corrected in place (kept, not erased). The substantive rule held throughout:
  no view renders the field (audit-verified). RK-PROV-01 mitigation is now
  actually enforced as recorded. Also wave 2: 8 missing RTM rows added
  (FR-RSCH-03, FR-WAL-08, FR-PROV-02, FR-PAT-01/02, FR-PAS-03, FR-ING-08,
  NFR-RSCH-04) — traceability only, no code-path change, no new hazard.
- **Wave 3 (2026-07-05) — dead CTAs + consult-availability overclaim
  (honesty fixes, no new clinical hazard).** Six reachable dead controls
  (empty `Button { }`) were either wired — `NudgeDetailView` "Share via
  wallet" now opens the EXISTING `ShareWithClinicianView` consent-share flow
  (no new share path; same flow already reachable from Settings, full
  scope/range/recipient consent steps unchanged) — or converted to disabled
  honest stubs (SOON chip), so no control silently does nothing. And
  `PlanConsultView` no longer asserts "availability mirrors <clinician>'s
  calendar" over a simulated free/busy grid; the copy is now "Suggested
  times — your clinician will confirm." — removes a false trust claim in
  the care-scheduling flow (the consult request itself is real). A blocking
  dead-CTA grep in `build-ios.sh` keeps empty CTAs from returning. Nudges,
  units (mmol/L), provenance handling, the AFib lane, and the FR-NDG-06
  guard are untouched; no new FR, no RTM change needed.

## PR-96 — A6 "Daylight" re-skin; RK-ALARM-01 re-assessed — Amber Flame accepted (2026-06-16)

The A6 "Daylight" re-skin is a presentation change (six-colour palette, SF Pro
type, iris app icon, Liquid Glass chrome). Most of it carries **no clinical
hazard** — palette/type/icon/glass change no data, nudge, unit, or the AFib lane.
**One change is safety-relevant: it supersedes the PR-47 attention-tone control.**

- **RK-ALARM-01 (attention colour read as a medical warning) — RE-ASSESSED; amber
  accepted.** A6 retires the desaturated **clay** (`#BD7A33`) attention tone and
  moves the patient "worth a look" signal **back to Amber Flame** (`#FFB703`) — the
  hue PR-47 had moved away from because saturated amber can read as a warning light.
  This was flagged to the owner and **accepted by CN on 2026-06-16** (founder /
  design owner): Amber Flame is the patient attention tone going forward. The PR-47
  "clay over amber" decision is **superseded**, on the basis of the controls below.
  - **Why amber ≠ alarm here (the controls that hold the meaning to "notice"):**
    amber is used as a **fill / dot / border / icon** with **navy text** on light
    grounds (never amber alarm *text* on light — the locked contrast rule), not as a
    full-bleed saturated alarm state; colour is **never the only signal** — the
    "Worth a look" kicker label + demoted position (below the calm affirming hero) +
    metadata carry the meaning, preserving the colour-blind-safe rule; the copy keeps
    the non-threshold, non-alarm voice (`FR-REG-02`); and the patient app stays a
    **two-state** model (cerulean = in-range · amber = notice) — the saturated
    green/amber/red triage ramp remains console-only, never shown to the patient.
  - **AFib / cardiac lane:** untouched — still **display-only, route-to-cardiologist,
    no interpretation/alarm/trend** (`D9`/`FR-REG-03`; `T-NDG-02/03` still pass). The
    amber tone is not used on the cardiac lane.
  - **Residual risk: ACCEPTED (low).** Owner-confirmed presentation control; the tone
    signals *state* ("worth a look"), never an alarm, via context + label + position,
    not hue alone. Re-confirm at the next human-factors / regulatory review that
    amber-as-fill reads as "notice", not "warning".
- **Liquid Glass legibility (positive):** the new glass surfaces (tab bar, sheets)
  fall back to an **opaque** `LiviqaTheme.paper/paper2` fill under Reduce Transparency
  / Increase Contrast, so text contrast is preserved for low-vision users — no
  legibility regression introduced.
- **provenance-never-renders (`T-PROV-01`):** A6 added no `provenance` rendering. The
  guard's pre-existing failure on `develop` (ePRO "provenance receipt" strings in
  `JournalView`/`WalletView`) is **unrelated to A6** and tracked separately.
- No new clinical claim; HealthKit read-only (`FR-ARCH-04`), glucose unit (`OD-07`),
  and the nudge allow-list/guard (`FR-NDG-06`) are untouched.

## PR-46/47 — full HealthKit capture + Design System v2; controls hold (2026-06-09)

Step A widens ingestion to capture insulin, AFib burden, blood pressure, body
composition, and the full heart/respiratory panel. This is a **data-layer**
change — the new signals are read, arbitrated, and persisted, but **not rendered,
interpreted, or turned into a nudge** here (rendering = Step B). The top hazards
are directly engaged and the existing controls hold:

- **RK-GLU-01 (acting on glucose/insulin for dosing):** insulin delivery is now
  read from HealthKit (`insulinDelivery` → `InsulinDose`), but stays a **data
  source only — no insulin/dosing surface** (`FR-REG-04`). No UI/output path,
  no dose printed, no dosing verb. The glucose×insulin *observation* nudge is held
  to Step B and remains gated by the `FR-NDG-06` guard (a designated control) and
  the RQ-01 "describe vs advise" decision (Claus/counsel). Control: **holds.**
- **RK-CARD-01 (AFib read as diagnosis):** AFib burden is now read
  (`atrialFibrillationBurden` → `AFibBurden`), but the cardiac lane is unchanged —
  **display-only, route-to-cardiologist, no interpretation/alarm/trend** (`D9`/
  `OD-11`/`FR-REG-03`; `T-NDG-02/03`). The new read adds no rendering. Control: **holds.**
- **RK-PROV-01:** every new reading is `provenance = .real`, tier `good`/`estimate`
  — never `clinical`; the schema gate is untouched, the provenance-never-renders
  guard is unchanged. Control: **holds.**
- **Read-only structural (FR-ARCH-04):** the share/write set is still **empty** —
  the wider read set adds no write capability (`T-HK-RO-01`; updated
  `readSetIsFullCaptureSet`). The app still cannot mutate the user's health record.
- **New wellness/watch data (BP, body-comp, SpO₂, VO₂max):** no clinical
  interpretation rendered; these land in the wellness/watch lanes when surfaced
  (Step B). No new clinical hazard at the data layer.
- **RK-DATA-DUP-01 (NEW, low — duplicate/inflated metrics mislead the user):**
  a re-sync could re-insert boundary samples outside the delete window, inflating
  a metric (e.g. glucose 48 rows where 42). **Mitigated:** the window-replace now
  deletes the union of the requested window and the inserted rows' span, so re-sync
  converges. Verified by `reSyncIsIdempotent` (`T-MAP-02`, now green). Note: real
  HealthKit reads are already window-clipped by the query predicate; this hardened
  the mock/edge path and the contract.

**Design System v2 — clay as an anti-alarm control (PR-47):**
- **RK-ALARM-01 (attention colour read as a medical warning):** the patient app's
  attention tone moved from saturated **amber** (a warning-light reflex, trained by
  dashboards/traffic) to a desaturated **clay** (`#BD7A33`) that says "worth a
  look", not "something's wrong". This is a deliberate de-risking choice that
  supports the never-diagnostic voice and `FR-REG-02` (no threshold/alarm framing):
  colour must signal *state* (moss = in-range, clay = notice), never an alarm.
  Colour is never the only signal (label + position + metadata), preserving the
  colour-blind-safe rule. No new clinical claim; this is a presentation control.

## PR-28 — auth provider change (Ory → self-hosted Supabase GoTrue); sovereignty held (2026-06-03)

- **RK-SEC-RESIDENCY-02 (auth on US-parented infra, NFR-SEC-07):** NOT regressed.
  Ory Network is replaced by **Supabase Auth (GoTrue) self-hosted in the EU**
  (Scaleway), not Supabase Cloud. Real-PII auth stays on EU-sovereign infra;
  tokens are Keychain-only (NFR-SEC-01). The backend verifies the Supabase JWT
  locally (jose) and never calls a US service per request. Had this been wired to
  Supabase *Cloud*, it would breach NFR-SEC-07 — the control is "self-hosted EU
  GoTrue", recorded here and in `docs/Auth_Supabase_v01.md`.
- No new clinical hazard. The app-level consent gate + backend authz are unchanged.

## PR-20/21/24 — consent-direction, message gate, encrypted sync-cursors (2026-06-03)

This batch wires citizen↔care-team messaging + Sign in with Apple and hardens
incremental ingestion. No new clinical interpretation; the entries are
consent/confidentiality controls.

- **RK-CONSENT-DIR-01 (recipient records a consult without the citizen's
  consent):** mitigated. Recording consent is one-directional — the recipient may
  only set `recordingRequested`; `recordingConsent` is writable ONLY on the
  citizen route (`CitizenService.recordingConsent`). The recipient route was
  corrected (liviqa-backend `73453ae`) and is now locked by a regression test
  (`workspace.service.spec.ts`) asserting it writes `{ recordingRequested }` only
  and never `recordingConsent`. The console shows "requested → awaiting citizen
  consent" until the citizen grants, and only then "Recording — consented by the
  citizen". Verified live (request: requested=true/consent=false; citizen grant:
  consent=true). Linked: NFR-PRIV-01, Video_and_OAuth_Contract_v01 §recording.
- **RK-MSG-SCOPE-01 (messaging used to move health content / reach a citizen
  without consent):** mitigated. Citizen `POST /threads/:recipientId/messages`
  requires an active grant (`SharedService.requireActiveGrant` → 403 otherwise),
  caps the body at 4000 chars, and is audited (`message.send`). Messaging is not
  a health-content channel (D-BACKEND-SCOPE); raw health discussion stays in the
  consult. Verified: 403 on no active grant.
- **RK-PRIV-ATREST-02 (HealthKit sync cursors readable / cross-user leakage):**
  mitigated. `HKQueryAnchor`s are sealed with the device DEK (AES-256-GCM via
  KeyVault, the PR-8 control) and written to files namespaced per device-local
  user — never UserDefaults, never keyed to a server/account id (FR-ING-04). A
  wrong device key fails GCM authentication rather than returning garbage
  (`EncryptedAnchorStoreTests`). No raw samples are stored — only the opaque
  cursor. Linked: NFR-SEC-02, FR-ING-03/04.

No new clinical hazard introduced.

## PR-12 — FR-SHARE-02 device→sovereign egress; residency + leak hazards mitigated

The derived-share PUSH is now wired to the EU-sovereign backend.
- **RK-SEC-RESIDENCY-01 (real PII to US-parented cloud, NFR-SEC-07):** mitigated —
  `LiviqaBackendService` targets the sovereign backend (Scaleway+Ory); Supabase is
  demoted to `.supabaseSandbox`; default backend is `.mock`. Real-user cutover sets
  `.sovereign`.
- **RK-PRIV-EGRESS-01 (raw/provenance leaving device):** mitigated by construction —
  the only health payload sent is `DerivedShareBuilder`'s scoped daily aggregates;
  the service never serializes `HealthSamples`/provenance. Backend re-checks
  guardrails server-side. Verified live (PUT /shares 200; revoke immediate).
- **Residual:** transport is plain HTTP for `localhost` dev only; production uses
  TLS to `api.dfgworks.dk` (NFR-SEC-06). Dev bearer tokens are non-production.

## CORRECTION (2026-06-03) — retired off-spec egress module

A prior entry here described a `ShareBundle`/`SecureShareExporter` egress module.
That module duplicated and diverged from the canonical `DerivedShareBuilder`
(FR-SHARE-01) and assumed a local AES envelope instead of the contract's TLS
push to the EU-sovereign backend. It has been **retired**. The egress hazard is
owned by `DerivedShareBuilder` + the sovereign backend integration (below).

- **RK-PRIV-EGRESS-01 (raw/provenance/identifiers leaving device):** mitigated by
  `DerivedShareBuilder` (derived GROUPS only, no provenance/source; backend also
  strips) delivered over TLS (NFR-SEC-06) to an EU-sovereign backend (NFR-SEC-07,
  not US-parented Supabase). Control verified by `DerivedShareBuilderTests`.

## PR-8 — device-bound key material; data-at-rest hazard mitigated

PR-8 adds the AES-256 + Secure-Enclave key-wrap primitive (NFR-SEC-02 / OD-09).
No clinical interpretation; this is a confidentiality/integrity control.
- **RK-PRIV-ATREST-01 (on-device data readable if storage is extracted):** the
  data-encryption key (AES-256) is wrapped (ECIES: ECDH → HKDF-SHA256 → AES-GCM)
  to a P-256 device key whose private half lives in the **Secure Enclave** and
  never leaves it. Keychain items are `…ThisDeviceOnly`. A copied Keychain/
  backup is therefore not unwrappable on another device. Verified: wrong-device-
  key cannot unwrap (T-SEC-04), each wrap is forward-secret/unique (T-SEC-05).
- **Integrity:** AES-GCM authenticates every box — a single flipped byte throws
  rather than returning corrupted plaintext (T-SEC-02). No silent corruption.
- **Residual:** simulators without an SE fall back to a software P-256 key
  (still AES-256, still device-only Keychain); `KeyVault.isHardwareBacked`
  records which path is live for audit. Production hardware is SE-backed.

No new clinical hazard introduced.

## PR-6 — external context; privacy control added, no new clinical hazard

PR-6 adds the Open-Meteo weather/AQI signal. No clinical interpretation, no
health data leaves the device. New control:
- **Coarse-location:** coordinates are rounded to ~0.1° (~11 km) before any
  request, and a test proves requests carry only lat/lon + env fields (no health,
  no identifiers, no key) — mitigates a location-privacy leak (RK-PRIV-LOC-01).

No new clinical hazard introduced.

## PR-5 — nudge engine + FR-NDG-06: top hazards now mitigated in code

PR-5 is the first PR that renders interpretation/advice, so it directly engages
the top hazards. Mitigations are now **implemented and verified** (executed this
session), not just planned:

- **RK-CARD-01 (AFib read as diagnosis):** the cardiac lane is `displayOnly`.
  The only output is a `routeToClinician` nudge that explicitly states Liviqa
  does not interpret heart rhythm and routes to the cardiologist — no verdict,
  band, or trend. No-signal ⇒ no cardiac nudge (T-NDG-02/03).
- **RK-GLU-01 (acting on a glucose nudge for dosing):** no insulin/dosing
  surface; glucose output is band-status relative to the personal baseline only.
  The **FR-NDG-06 guard** (designated control) blocks any dose quantity, dosing
  verb, treatment directive, diagnostic claim, or clinical-normality verdict in
  ANY nudge string. Every engine output is run through the guard before release;
  violators are dropped and trapped (`assertionFailure`) in debug.
- **RK-PROV-01:** the nudge layer carries no `provenance`/tier and renders no
  source label; provenance guard still green.

Residual risk: heuristic thresholds (±1σ baseline) are wellness-grade, not
clinical — acceptable for the wellness/watch lanes; the constrained/display-only
lanes carry no interpretation. FR-NDG-06 tests are **blocking** (qms/VnV.md).

## PR-4 — real glucose/cardiac data now ingested; controls hold

PR-4 lets real device data flow HealthKit → store. Still no rendering, nudging,
or interpretation. Controls reinforced:
- **Read-only** is now structural: HealthKit share/write set is empty
  (`HealthKitService.shareTypes = []`, T-HK-RO-01) — the app cannot mutate the
  user's health record (closes the "app writes bad data back" failure mode).
- Glucose canonicalized to mmol/L at the read edge (OD-07) — no unit-confusion
  hazard from mixed mg/dL in the store.
- Ingested HealthKit data is `provenance = .real`, tier `good`/`estimate` (never
  clinical) — keeps RK-PROV-01 mitigation intact; clinical gate untouched.
- RK-CARD-01 / RK-GLU-01 unchanged: no AFib/glucose **rendering or nudge** added
  (still land in PR-5).

No new hazard introduced.

## PR-2 — data entities only, no new clinical hazard

PR-2 introduces glucose, AFib-burden, and insulin-dose **data entities** plus the
on-device store. These are data-layer types: nothing is rendered, interpreted, or
turned into a nudge here. Controls preserved:
- Clinical-tier rows cannot be SIMULATED (schema gate + type-level
  `ClinicalProvenance`) — guards RK-PROV-01.
- `InsulinDose` is a data source only; **no insulin/dosing surface** (FR-REG-04) —
  no UI/output path added.
- Samples cannot leave the device: store uses `cloudKitDatabase: .none` (NFR-PRIV-01).

No new hazard introduced. AFib/glucose rendering + nudge constraints are still
the open mitigations tracked below (land in PR-5).

## PR-1 — no new hazard

PR-1 is signing/identity configuration and repo relocation only. It introduces
**no analytical, clinical, or data-path code** and therefore **no new hazard**.
Logged per the QMS-lite "no safety-relevant change without a risk touch" rule.

## Pre-seeded top hazards (structure in place; mitigations land with their PRs)

| ID | Hazard | Cause | Planned mitigation | Linked req | Status |
|---|---|---|---|---|---|
| RK-CARD-01 | User reads an AFib signal as a diagnosis or acts on it without a clinician | Cardiac data rendered with interpretation/alarm/trend framing | **Display-only lane (D9):** render the signal, route to cardiologist, no interpretation; `FR-NDG-06` forbidden-construction guard (designated control, blocking tests) | D9, FR-REG-03, FR-NDG-06 | **mitigated** (PR-5; T-NDG-02/03/06) |
| RK-GLU-01 | User changes insulin/treatment based on a glucose nudge | Dosing/treatment language in nudge output | No insulin/dosing surface in MVP (`FR-REG-04`); allow-list output only; `FR-NDG-06` guard | FR-REG-04, FR-NDG-06 | **mitigated** (PR-5; T-NDG-06) |
| RK-PROV-01 | Synthetic/estimate data mistaken for clinical truth | `provenance`/tier shown or clinical field accepts SIMULATED | `provenance` never renders (blocking file guard — CORRECTION 2026-07-03: recorded as "CI/unit guard, blocking" since PR-2/3, but the shell guard was wired to no CI/build step and was exiting 1 on wallet-receipt word collisions until 2026-07-03, when the pattern was scoped to the data field and the guard wired as a blocking `build-ios.sh` step, PR-102); clinical-tier entities reject SIMULATED at schema level | NFR-PRIV-05, DataModel v1 | **mitigated** (PR-2/PR-3; T-PROV-01 — designated control inert until 2026-07-03, corrected PR-102; T-DM-01). The substantive never-renders rule held throughout (audit-verified) |
