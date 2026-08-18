# Risk Register (ISO 14971-aligned)

_Hazard → cause → mitigation → residual risk → linked requirement. Cardiac/glucose/medication lanes carry the top entries. Safety-path code changes require a row here (or an explicit "no new hazard" PR note). Version: 2026-06-03._

## Health-summary export — the document a citizen hands their doctor was clinically misleading (2026-08-19, export redesign, branch claude/a72-electric-ink)

CN exported his real summary and found it unprofessional and in places clinically
misleading. The export is a SAFETY-RELEVANT surface: a clinician reads it as the
citizen's record. Hazards found in the shipped export and their mitigations:

| ID | Hazard | Cause | Mitigation | Residual | Linked req |
|---|---|---|---|---|---|
| RK-EXP-01 | Clinician misreads result recency/trend — every lab appears drawn on the same recent day | Sundhed-imported observations carried the PULL/import date as `effectiveDate`; the parsers read per-row specimen dates but `summarise()` flattened them and `canonicalize()` substituted `Date()` | Per-reading dates now survive the whole pipeline (`LabRow.readings`, one `HealthObservation` per reading, `specimenDate` field); a genuinely undated row stays nil and renders "date not recorded" — the import date NEVER renders as a result date; pull dates live in the document HEADER ("Sundhed.dk record as of <date>") | None while T-EXP-01 holds (parse→summarise→canonicalize date round-trip + nil-stays-nil pinned) | FR-EXP-01, day-axis integrity rule |
| RK-EXP-02 | A negative serology/antigen screen reads as a measured numeric value ("0 U/L") — or worse, as an alarming zero | Qualitative results had no type: Sundhed encodes some negative screens as `Vaerdi=0` + wording; the pipeline stored the 0 as a quantitative value | `SundhedResultKind{quantitative,qualitative,artifact}` typed at parse time on BOTH paths (closed in-page token allow-list keeps narrative off the bridge); qualitative rows store the source's wording, render as words ("Not detected"), are excluded from every numeric surface (`latestObservations`), the coded research body and MPC scaling | None while T-EXP-02 holds (0-encoded negativity, valueless worded results, aggregate exclusion all pinned) | FR-EXP-01, FR-NDG-06 posture |
| RK-EXP-03 | Zero-duration/volume collection bookkeeping rows ("0 min urine collection") read as results | No artifact concept | `isCollectionArtifact` flags value==0 in duration/volume units (or collection-time analytes); artifacts are excluded from the summary by default and listed honestly in its appendix; a genuine 0.0 count (basophils) is proven NOT to trip the rule | None while T-EXP-02 holds | FR-EXP-01 |
| RK-EXP-04 | Population reference ranges sneak into the document as judgements | Redesign adds a reference-interval display | ONLY the SOURCE's own captured interval renders, labelled "source reference interval"; nothing is invented; the personal-prior framing (own previous value + date) is the only comparison; every fixed framing string passes the FR-NDG-06 designated control (T-EXP-04) and the document generates NO sentences | None while T-EXP-04 holds | FR-EXP-01, FR-NDG-06 |

No new egress: the document leaves only via the citizen's explicit share action
(unchanged posture, `SundhedSinkTests` still green); the hidden
`Provenance{REAL,SIMULATED,EXTERNAL}` field still never renders (T-EXP-04
asserts its absence from the rendered text).

## Universal HealthKit read — the whole record lands on the phone (2026-08-19, FR-ING-19, CN directive)

The universal layer materially WIDENS the at-rest surface: from ~21 curated types
to every type the citizen grants — potentially reproductive health, symptoms,
mental-health assessments, audiology. New/updated rows:

| ID | Hazard | Cause | Mitigation | Residual | Linked req |
|---|---|---|---|---|---|
| RK-ING-13 | Sensitive special-category data at rest on the device is exposed (device loss, backup extraction) | Universal store holds every granted type, not a curated subset | SAME discipline as the sample store, verified by construction and test: on-device only (`cloudKitDatabase: .none`), `.completeUntilFirstUserAuthentication` file protection incl. WAL/SHM, NO egress path anywhere in the layer, GDPR erase via `UniversalHealthStore.eraseAll()` (T-UNI-09); the citizen chose every type on Apple's own sheet and can revoke in the Health app | Erase hook + browser entry land in the SAME integration PR (both lines reported in RTM/DHF); until then the layer is dormant — no call site constructs the reader, so no data can exist that the missing hook would strand. DPIA data-inventory re-run flagged to CN before tester exposure | FR-ING-19, NFR-PRIV-01, OD-09 |
| RK-NDG-05 | An unfamiliar type (a symptom severity, a mental-health score) gets an implied judgment the app has no validated basis for | A browser row framing a value as good/bad/normal | STRUCTURAL: the browser generates no sentences — values, units, counts, source names and a day chart only; recorded category codes decode to HealthKit's OWN words ("Mild", "Severe" — reading back what was written, never assessing it); no NudgeGuard wiring exists in the file; T-UNI-14 lints every string literal against a judgment lexicon | None while T-UNI-14 holds; any future per-type verdict must arrive as its own FR with its own deriver + FR-NDG-06 coverage | FR-ING-19, FR-NDG-06 |
| RK-ING-14 | The universal breadth silently distorts the four tuned core signals | Universal rows leaking into derivers/nudge inputs, or double-storage of tuned types | Type-set disjointness (storage set ∩ tuned readTypes = ∅, T-UNI-05) + source-lint isolation in BOTH directions (T-UNI-07) + a separate ModelContainer, so no LiviqaStore query can ever fetch a universal row | None while the T-UNI suite holds | FR-ING-19, FR-ING-01, FR-NDG-06 |

Honesty control alongside: the HealthKit primer's "these — and only these" claim
(report-only finding ① of the 2026-08-18 audit, RK-ING-12) is CLOSED — the v03
lead claims only what is true in every configuration (the citizen chooses on
Apple's sheet; read-only; on-device; nothing uploaded).

## Sleep incident — the founder's own nights derived "brutally wrong" (2026-08-18, sleep-incident wave, branch claude/a72-electric-ink)

**Why this is a risk section.** Sleep is a signal the nudge engine consumes
(`NudgeEngine.sleepNudge` compares last night to the citizen's own baseline) and a
headline figure on Home, Today, Trends, the Sleep detail screen and the Passport. A field
report from CN's real device said the figures were "brutally wrong"; the device could not
be inspected, so this wave built the inspection instrument (FR-DIAG-01) and audited the
post-PR-109 sleep path against six failure shapes with pathological fixtures
(`SleepPathAuditTests`, red-then-green — evidence, not plausibility).

**RK-SLP-07 — a two-source night double-counts (7.5h derived as 11h03m; naps join the night).**
- *What users actually saw (honest statement):* on any device where a second source wrote
  sleep over a watch-staged night — the iPhone's own span, or a third-party sleep app —
  the Home SLEEP chip and the Sleep detail screen showed the night inflated by roughly
  the second source's whole span: a real 7.5h night rendered as **11h 03m** (test-pinned:
  663 min pre-fix), and as **12h 18m** with a second stage-writing app. At the same time
  Today/Trends/Correlation/Passport computed the same night differently (a full union →
  8h 15m), so adjacent screens contradicted each other. Separately, an afternoon nap
  landed in the same night bucket (t+6h rule) and grew "last night" and stretched the
  night chart's axis to the nap's end. Since PR-109's union fix shipped, this is the
  remaining — and now measured — mechanism consistent with the report. The nudge engine's
  sleep input used the full-union figure, so short-night nudges were fed a number ~45 min
  high for such nights (baseline-relative, so the bias partly cancels; still wrong).
- *Cause 1 (double-count):* every nightly total in `SleepDeriver` / `SleepDetailDeriver` /
  `BaselineDeriver` is the SUM of three per-stage-bucket unions (deep + REM +
  core/unspecified). Correct for one source, whose stages partition the night; wrong
  across sources — an undifferentiated span covers the same wall-clock minutes the
  watch's deep/REM buckets already counted. `SourceArbiter` keyed sleep by (stage, night),
  so different-stage segments from different sources never met, and all HealthKit sleep is
  one tier — arbitration removed nothing.
- *Cause 2 (nap merge):* the night bucket is a whole t+6h day; nothing separated the
  night's episode from a nap in the same bucket.
- *Mitigation (code, this branch):* `SleepNightResolver` (SourceArbiter.swift, pure,
  portable): per night, ONE source — stage detail beats an undifferentiated span, then the
  larger asleep total, then name (deterministic) — which is the stance Apple Health itself
  takes (it shows one source per night; it does not union across apps, so Liviqa now
  agrees with the screen the citizen checks it against). Then main-episode isolation: an
  unrecorded gap > 4h splits the bucket into episodes and the episode with the most asleep
  time is the night (recorded AWAKE bridges its gap; untimed aggregated sources are never
  split — dropping data on a guess would be fabrication in reverse). Wired in
  `arbitrated()` so EVERY consumer (nudge engine included) receives the resolved stream,
  and re-applied idempotently inside both sleep derivers for callers that skip
  arbitration. Exclusions are disclosed, not hidden: the FR-DIAG-01 report prints each
  excluded segment with its reason.
- *Verification:* `SleepPathAuditTests` (12 — shapes (a) multi-source, (b) naps,
  (c) inBed, (d) DST 25h/23h nights, (e) 09:00–17:00 shift worker, (f) unrecorded gaps;
  (a)+(b) were red pre-fix, the rest pin sound behaviour), `SleepNightResolverTests` (12),
  all 25 pre-existing sleep tests unchanged and green. No live HealthKit store in any test.
- *Residual:* when two sources cover DIFFERENT parts of one night (watch died at 03:00,
  phone covered the rest), the chosen source's part alone is counted — the honest
  direction (never inflate), identical to what Apple Health displays, and visible in the
  diagnostics report. A same-source overlap of unspecified over stages remains summed
  per-bucket (not observed from any real source; the diagnostics instrument would show
  it). ACCEPTED.

**RK-DIAG-01 — the instrument itself must not become a leak.**
- *Hazard:* a diagnostics export that read broadly or uploaded would be a privacy defect
  built in response to a data-quality defect.
- *Mitigation:* FR-DIAG-01 reads sleep timing ONLY (`readSleepDiagnostics` touches the
  `sleepAnalysis` type and nothing else); the report is a plain-text file built on device
  and handed to the share sheet — the app has no upload path for it; provenance and tier
  vocabulary never appear in the text (test-pinned); a structural lint fails the suite if
  any transport construct enters `Liviqa/Diagnostics/` (same posture as T-DON-02). Sample
  mode blocks generation (FR-SMP-04: sample mode never reads real data). T-DIAG-01
  (`SleepDiagnosticsTests`, 8).

## HealthKit coverage audit — the signal the nudge engine consumes must be the citizen's real day (2026-08-18, sleep-incident wave, branch claude/a72-electric-ink)

**Why this is a risk section.** CN's field report of "brutally wrong" sleep figures is a
data-quality incident on the signal the nudge engine and every personal-baseline surface
consume. The parallel sleep workstream owns the sleep read path; this audit owns the
NON-sleep breadth and found one defect of the same hazard class, added one new type with a
named purpose, and refused a list of types on purpose grounds. Artifact:
`docs/HealthKit_Coverage_Audit_20260818.md`.

**RK-ING-10 — a daily figure is a cross-source sum (steps / active energy up to ~2×).**
- *Hazard:* a Watch+iPhone citizen's steps and kcal read up to double on days both devices
  were carried. Wrong inputs flow into the activity baseline, the Today ring and the
  correlation grid — the citizen reads a day they did not have, and every "your usual"
  band learned from those days is inflated. Same hazard class as the PR-109 sleep
  double-count (multi-source overlap counted twice).
- *Cause:* `readDaily` summed raw `HKSampleQuery` samples across ALL sources for
  cumulative kinds; a raw sample query returns each source's samples for the same walk.
- *Mitigation (code, this branch):* pure `DailyRollup` — per (day, source) totals, the
  day's figure = the best-covering single source's total; sources never summed together;
  single-source days keep their full total. Property-tested (T-COV-01..04), no HK store
  constructed in any test.
- *Residual:* a mixed-coverage day under-counts the segment only the other device saw —
  the honest direction (never inflate). Exact source-priority merging is the named
  upgrade path (RTM FR-ING-17). ACCEPTED.

**RK-ING-11 — collection without purpose (new-type discipline).**
- *Hazard:* "full capture" drift: reading sensitive HK families (cycle tracking,
  medications, symptoms, gait, ECG) because they exist, without a surface that serves the
  citizen — maximizing held special-category data and the blast radius of any future
  defect or breach, and making the primer's honesty claim unmaintainable.
- *Mitigation (process, this audit):* every read type now has a named consumer or a
  dated RTM row naming its pending consumer (FR-ING-16/18); every considered-and-not-read
  type is listed with its refusal in the audit doc §2. Cycle tracking, medications and
  symptoms are explicitly refused pending their own design + DPIA touch; ECG/irregular
  rhythm may only enter via a dedicated D9 wave with its own risk entry.
- *Residual:* none new — the read set grew by exactly one type (nightly wrist
  temperature), night-bucketed, arbitration-covered, mock-covered, never framed against a
  population range. ACCEPTED.

**RK-ING-12 — the primer's "these — and only these" claim is false (report-only; file owned elsewhere).**
- *Hazard:* `HealthKitPrimerView` names six domains and claims exclusivity while the app
  requests ~21 types. The iOS system sheet does show the true full list, so consent
  itself stays informed — but the claim is ours and untrue, the exact failure mode the
  2026-08-13 data-honesty incident taught. OPEN: needed change specified in the audit doc
  §4.1 and RTM (report-only finding ①); owner = the onboarding surface.
- *Interim control:* the system authorization sheet (Apple-rendered, per-type) is the
  binding consent surface and is always truthful.

## Calendar load — reading how full a day was, without reading a person's life (2026-08-18, branch claude/a72-electric-ink)

**Why this is a risk section.** Nothing clinical changes. Two things do: the app starts
reading a **new source of personal data** — one that also contains OTHER PEOPLE's personal
data, since a meeting names the people in it — and a new signal joins the grid where
citizens read their own patterns. Both are honesty/privacy axes the QMS files here.

**RK-CAL-01 — event content is read, kept, logged or shown.**
*Cause.* An engineer adds one line. `event.title` is right there next to `event.startDate`,
the compiler is happy, and a debug `print` during an investigation is the classic way this
leaks. Nothing about the shape of EventKit resists it.
*Harm.* Liviqa would hold, on a citizen's phone, the titles, attendees and locations of
other people's appointments — data those people never consented to give us — and the
permission prompt would be a lie.
*Controls.*
- **One seam, and it is narrow by construction.** `CalendarLoadIngestor.intervals` is the
  only function in the app that reads events. It maps each `EKEvent` to a
  `ScheduledInterval` — two `Date`s and two `Bool`s — and after it returns, **no `EKEvent`
  exists anywhere in the app**, so no later edit can reach a title even by mistake.
- **A lint that fails the build, mutation-verified.** `T-CAL-02` extracts every
  `event.<member>` on that path and fails on anything outside
  `{status, startDate, endDate, isAllDay, availability}`; separately it fails on any of the
  eleven named content accessors; separately it asserts `events(matching:)`,
  `predicateForEvents(` and `requestFullAccessToEvents` appear in exactly one file and
  `import EventKit` in exactly two. Verified by mutation on 2026-08-18: inserting
  `_ = event.title` fails two independent checks. Each lint also fails if its target
  disappears — a lint that has stopped guarding anything must not pass quietly.
- **Nothing on the path logs.** `print`, `debugPrint`, `NSLog`, `os_log` and `Logger` are
  linted out of the ingestor, the deriver, the store and the copy file.
- **No field to keep it in.** `CalendarDayLoad` encodes to seven numeric keys; the test
  asserts every encoded value is a number, so adding a `String` fails the suite.
- **No calendar picker, deliberately.** Offering "choose which calendars" would require
  reading their names. The screen says so, in those words.
*Residual risk.* A future engineer could add a second EventKit importer with its own read.
The importer lint catches exactly that (it pins the set of importing files), which is why
it is written as an equality and not a "contains".

**RK-CAL-02 — a busy day is presented as a cause, or as a judgement.**
*Cause.* A grid that puts "your calendar was full" next to "your HRV dropped" invites a
causal reading, and the natural next sentence ("you're doing too much") is a judgement about
how a person should live — outside anything this app is entitled to say, and outside
FR-NDG-06's allow-list posture.
*Controls.*
- **Personal-baseline only.** The cell is |deviation| from this person's own usual booked
  hours, in the same z-bands as every other row. There is no population norm, and no
  recommended number of meetings, because no such thing exists.
- **The row cannot elect the week's hard day.** CALENDAR is deliberately excluded from
  `clusterDay`, `hardDayCount`, the week verdict and the pattern note. Those sentences name
  a day that stood out across SIGNALS; letting a full diary vote would be the app implying
  the diary moved a reading.
- **Every sentence passes the designated control.** `CalendarLoadCopy.guarded(_:fallback:)`
  is the single seam; `NudgeGuard.check` runs before any view can render, with an assertion
  in DEBUG and a neutral fallback in Release. `T-CAL-02` sweeps >1 000 generated sentences.
- **The disclaimer is explicit about cause**, not just about diagnosis: a notable day adds
  "A pattern in your own data, not a medical finding — and not read as a cause of anything
  else on this screen."
*Residual risk.* The citizen may still draw their own causal conclusion from two facts on
one screen. That is their reading of their own life, which is the point of the grid; what
the app must not do is assert it, and it does not.

**RK-CAL-03 — absence rendered as a fact about the person.** This is the RK-CHART-01 /
PR-111 failure mode, in a new source.
*Cause.* A calendar the citizen does not keep on this phone produces a week of zeroes.
Drawing those as "like your usual" would assert seven quiet days about someone whose diary
simply lives elsewhere.
*Controls.* Four distinct honest states, each with its own sentence: not connected /
calendar holds nothing in the window / fewer than three days of history (the same ≥3 rule
`Baseline.from` applies everywhere) / ready. An entirely empty history is `.noData`, never a
row of low cells. A display day with no stored reading is `.noData`, never a zero. Tested
four ways in `T-CAL-01`.

**RK-CAL-06 — a baseline built on days the calendar was not yet kept.** A quieter cousin
of RK-CAL-03, and the one most likely to have shipped unnoticed.
*Cause.* A refresh reads the whole 28-day rolling window in one go. Someone who started
keeping this calendar eight days ago gets twenty empty days in front of eight real ones. As
a mean, that is not "your usual" — it is mostly absence — and every ordinary week for the
next month would read "fuller than your usual".
*Controls.* `CalendarLoadDeriver.baselineWindow` starts the baseline at the first day with
a recorded entry. Days before it are excluded from the mean AND rendered `.noData`, through
the same accessor the readout uses, so the cell and the sentence cannot disagree. Empty days
*inside* the used stretch are kept: a genuinely clear Sunday is data about the person.
Tested both ways (`daysBeforeTheFirstEntryAreAbsenceNotQuietDays`,
`anEmptyDayInsideTheUsedStretchIsStillRealData`).

**RK-CAL-04 — one person's calendar numbers open under another person's account.** The
PR-111 cross-account journal exposure, pre-empted rather than repeated.
*Controls.* The store is ACCOUNT-scoped from the first commit, following `JournalStore`
exactly: `<Application Support>/calendar-load/<sha256(accountID)>/calendar-load.v1.json`.
No account id ⇒ no path ⇒ nothing written and nothing readable. An account with no file
starts empty. There is no unscoped path and never was one, so there is no legacy adoption
question. `NSFileProtectionComplete` + atomic writes. Tested: cross-account isolation, and
that the id never appears in the path.

**RK-CAL-05 — collection continues after the citizen says stop.**
*Controls.* Collection requires BOTH the account-scoped opt-in record and iOS's
`fullAccess`; `refresh` returns false and writes nothing if either is missing, so a refresh
can never start collection as a side effect. `replaceDays` refuses to create a record for
an account that never opted in — a write cannot start collection either. `disconnect`
deletes the file, so revoking removes what was collected and not merely the future of it.
*Closed (this branch).* `AppState.deleteAllData` now calls `CalendarLoadStore.eraseAll()`
alongside `ContextFlagStore.delete()` (step 2c-ii-b), so a full device erase removes every
account's calendar-load scope on the device. `eraseAll()` itself was already tested
(T-CAL-01, `eraseRemovesEveryAccountsCalendarScope`); the wiring was the outstanding line
and it has landed.

**Permission-copy correction filed here deliberately.** The write-only calendar prompt said
"It never reads your existing events." That was an app-wide claim, and it stopped being
true of the running app the moment this signal shipped. It now describes only the
permission it belongs to. The five existing non-English translations of that string carried
the old claim and were **removed** rather than left in place, so every locale falls back to
the accurate English source until they are re-translated — an English prompt is a smaller
harm than a false Danish one.

**Screen Time — no hazard, because nothing was built.** `docs/ScreenTime_Feasibility_20260813.md`.
The one code change it caused REMOVES a false affordance: the Data-sources "Screen Time"
row offered a "Connect Screen Time" button that, in every shipping build, read nothing and
changed nothing while looking like a connection (FR-SET-04).


## Opt-in sample mode — the honesty control the 2026-08-13 incident was missing (2026-08-14, branch claude/a72-electric-ink)

**Why this is a risk section and not just a feature.** Nothing clinical changes here. What
changes is an HONESTY behaviour: WHEN the app is allowed to put a number on screen that
nobody measured. That is the same axis the 2026-08-13 TestFlight incident failed on
(CHANGELOG PR-111), so it is filed here.

**RK-SMP-01 — a citizen reads an invented number as their own measurement.**
*Cause (the state before this change, stated plainly).* `AppState.isDemoData` was defined
as `!usingRealData`. That expression answers "have any real readings arrived?" — but every
screen that draws a fabricated stand-in value used it to answer a different question,
"may I draw a fabricated value?". So a brand-new REAL citizen, whose watch had simply not
synced yet, was indistinguishable from someone who had asked to see a demo. Seven
metric-detail screens returned `.designSeed`; Home printed a day score of 42/50 sleep, a
momentum strip reading "Recovery up 4 vs your usual", a 14-point "last 30 days" recovery
line, and an attention card whose canned sentence ("Late dinners are costing you sleep.")
overrode the engine's own. The single label that might have marked any of it was a chip
in one header, gated by `liviqaShowDemoChip`, **default FALSE**.
*Harm.* A person makes a judgement about their health — or about this app's trustworthiness
— on a figure that describes nobody. In a product whose whole claim is "your own normal,
never a population average", this is the most damaging failure available to it.
*Controls now in place.* (1) The two questions are separate properties (`hasNoRealReadings`
vs `isSampleMode`) and only the citizen's own request authorises a stand-in — the rule is a
pure function, `SampleModePolicy.mayRenderSampleValues`, and the test that pins it holds
`hasRealReadings: false` and asserts it changes nothing. (2) The stand-in blocks that had
no data behind them are DELETED rather than re-gated; sample mode derives real figures from
the synthetic record through the same derivers instead. (3) Labelling is app chrome on every
tab, every pushed detail and every value-bearing sheet, with no preference able to reach it.
(4) The old preference key no longer exists anywhere in the app, and a lint fails the run if
it returns.
*Deliberate consequence.* The watch glance is NOT updated while sample mode is on — a
watch face cannot carry this label, so it keeps the citizen's own last real values instead
of showing a synthetic number with nothing marking it.
*Residual risk.* A modal presented by a screen the app shell does not own would be drawn
above the banner. Every such presentation in the shell is covered; a NEW full-screen
presentation added later would need `.liviqaSampleModeBanner()` too. Not lint-enforced —
recorded as a review item rather than claimed as closed.
*Linked requirements.* FR-SMP-01, FR-SMP-03. *Status:* **mitigated** (T-SMP-01, T-SMP-03).

**RK-SMP-02 — the demo dataset is a real person's health record.**
*Cause.* The directive was to build the sample "inspired by my previous goldmine" — an
actual 60-day record belonging to an identified individual. The convenient implementation
is to ship that file.
*Harm.* Every tester, and eventually every user of a demo build, would hold one named
person's special-category health data. Irreversible on distribution, and precisely the
thing this application exists to refuse.
*Control.* `SampleDataset` is generated arithmetic from a fixed seed. It reproduces the
goldmine's SHAPE (CGM band and excursion structure, the short-night → lower-HRV → higher
next-day-curve coupling, weekday/weekend step rhythm, a scale used twice a week) and none
of its values. The file says so at the top, with the reason. Tests assert determinism,
plausible bands, and that the record has genuine variability rather than being a flat or
noisy fixture.
*Second-order control.* The sample deliberately carries **no AFib burden, no blood
pressure, no insulin doses, no labs, diagnoses or medicines** — the surfaces where an
invented value would look most like a clinical fact about the person holding the phone. A
demo must never simulate a rhythm finding (D9) or a dose (FR-REG-04).
*Residual risk.* None identified; the dataset cannot be re-identified because there is
nobody in it. *Linked requirements.* FR-SMP-02, D9, FR-REG-04. *Status:* **mitigated**
(T-SMP-02).

**RK-SMP-03 — sample data contaminates the citizen's real record.**
*Cause.* A demo mode implemented as "just ingest the fixture" would run synthetic readings
through the normal pipeline and persist them beside real ones, where nothing afterwards can
tell them apart — including the donation assembler, the clinician share and the passport.
*Harm.* Permanent corruption of the one store the app promises is the citizen's own, and a
route for fabricated readings into a clinical conversation or a research corpus.
*Control (structural, not procedural).* While sample mode is on, `refreshFromHealth`
performs no fetch, no persist and no derivation — the ingest path is not entered. The
synthetic record is a value type with no `ModelContext`, no store, no file handle and no
network type in the file at all (source-lint enforced). The overlay is in-memory; entering
snapshots the citizen's own surfaces and leaving restores them field for field. Erase
clears the flag with everything else.
*Verification.* Row counts across eleven entity types are asserted unchanged before,
during and after — including across a refresh performed while sample mode is on.
*Residual risk.* The donation gate now refuses on BOTH meanings (`isSampleMode ||
hasNoRealReadings`), so it is strictly stricter than before, not looser. *Linked
requirements.* FR-SMP-04, FR-DON-05, NFR-PRIV-01. *Status:* **mitigated** (T-SMP-04).

**RK-SMP-04 — the app turns sample mode on by itself.**
*Cause.* The tempting fix for "the app looks empty" is to show a sample automatically. That
would recreate the original defect exactly, with a nicer label on it.
*Control.* There is one entry function and it requires a named `SampleModePolicy.Entry`;
the enumeration has two cases, both a citizen's tap. A lint asserts the set of files that
may call it, so a third caller fails the run rather than a review. The flag is absent (not
`false`) on a fresh install, and a launch refresh is asserted unable to set it.
*Residual risk.* Sample mode persists across launches once chosen — deliberately, since it
is a choice the citizen made and the banner states it on every screen. *Linked
requirements.* FR-SMP-05. *Status:* **mitigated** (T-SMP-05).

**Honesty debt PAID, not deferred.** The onboarding screen that offered "Skip — explore
with sample data" and the declined screen that said "for now you'll explore with sample
data, clearly marked" both promised something the app did not do: neither turned any
sample on. Under the "every claim in shipped copy must be true of the running app" rule
these were false sentences on the second and third screens a new citizen reads. Both are
now either true (the offer exists and works) or removed.

## Donated data programme DON-2026-01 — app side (2026-08-13, branch claude/a72-electric-ink)

**Context and the decision this records.** CN, 2026-08-13, verbatim: *"forget about
anonymity. We need to have a cloud version of the data. and a permit to use it for the
training. You do what it needs to be able to work."* This RESOLVES OD-D1 of
`Liviqa_DonorDataProgramme_v01_20260813.md` **against** that document's own
recommendation: the donated corpus is for MODEL TRAINING, not verification only, and
anonymity is abandoned as a strategy. The corpus is identifiable special-category health
data; its protection is lawful basis + explicit consent + encryption + access control +
governance, and never a claim of anonymisation. Recorded here as a controller decision
with its date, not as a silent widening.

**What the app side does and does not do.** The training decision does not change one line
of app behaviour: the app assembles a consented extract, seals it, and hands it to the
donor. It never trains, never uploads, never holds a corpus, and cannot read a donation
back. Everything the decision DOES change — the §1.2(1) prohibition, the §2.3 consent
text (which currently promises donors the opposite), DPIA v02, the ROPA entry, the
consent-engine vocabulary — is owner/counsel work and is **not** closed by this section.
**No donation may be collected until §7.3 is satisfied**, and the consent text must be
corrected before it is put in front of a donor: shipping code whose consent form says
"not used to train an AI model" while the programme intends training would be the single
most damaging thing this programme could do.

**RK-DON-01 — the corpus is breached.** Cause: an identifiable, sample-level physiological
record of named individuals now exists at rest off-device. Harm: an Art. 33/34 notifiable
special-category breach with named humans to notify. App-side controls: the payload is
sealed on the donor's device with X25519+HKDF+AES-GCM to a programme public key whose
private half never exists in the app, the repository, or on any laptop (two hardware
tokens, two-person rule, §4.2/OD-D8); the store therefore never holds plaintext; the
sealed file is authenticated (tampering fails, never yields different plaintext);
plaintext exists only as an in-memory value between assembly and sealing and is never
written to disk. Residual: everything after the file leaves the phone is governance, not
code — isolation, access list, access log, erasure drill. Owner-side, unclosed here.

**RK-DON-02 — donated data renders as a citizen's own data.** The §6 hard rule, and the
failure mode is a well-intentioned engineer wiring a corpus reader "just to see the merge
in the UI". Controls are STRUCTURAL, not policy: (a) the payload types are **Encodable
only** — the app has no type that can decode a donation, so donated bytes cannot become
values on any screen in any build; (b) there is no `open` side to the sealer and no
recipient private key in the binary, so a sealed file is unreadable to the app even if a
decoder appeared; (c) no importer, no `fileImporter`, asserted by lint; (d)
`DataProviderKind` stays `{healthKit, mock, lv001}` — a `donated` provider fails the test
run; (e) the existing pinned call-site counts (`T-SUND-01`, `T-REC-01`) mean a corpus
loader cannot reach the store without moving a number a green test already guards.
`T-DON-02` (`DonationEgressTests` + the blocking `guard_donation_egress.sh`) enforces (a)–(d).

**RK-DON-03 — donated values reach a repository and become unerasable.** Git history,
forks, clones, CI caches and mirrors put a committed fixture beyond recall — no
withdrawal can reach it (§5.3). App-side prevention: the app writes NO donated value
anywhere but the sealed file (single `.write(to:)`, of sealed bytes, in a temporary
staging directory that is purged on every export, on withdrawal, and on demand); no
donated value is ever a fixture, seed or demo (every test in this wave builds its own
synthetic rows). Residual: the repo-lint half of §5.3's T-DON-03 (no donor code, donor
register schema or high-entropy fixture block anywhere in the repo) is a REPOSITORY
control and is not implemented by this PR — flagged as an open owner action.

**RK-DON-04 — an export happens without, or after, consent.** Cause: a flag left on, a
withdrawn donor, an expired grant, a build shipped with the donor surfaces reachable.
Controls: the flow requires a compile-time `-D LIVIQA_DONOR` (shipped binaries have a
constant `false`); a pure gate refuses on no-donor-build, no grant, wrong recipient type,
inactive grant, expired grant, empty scope, missing programme key, demo data, and empty
window — each with its own on-screen reason; the grant expires at 12 months with no
auto-renew; withdrawal deactivates the grant, appends a `consentRevoked` ledger event and
purges any staged file. Every export appends a `dataAccessed` ledger row carrying the
stream counts and the sealed file's SHA-256 — what left and when, never a value. Verified
by `T-DON-05`.

**RK-DON-05 — a donor is told something untrue on a consent screen.** Four surfaces
carried "Your individual readings never leave this phone." verbatim; for a donor that
sentence is false, and a false sentence on a consent screen corrodes every other promise
the product makes (§6.3, OD-D11). Control: the claim is a single-sourced function of
whether an active donation grant exists. **For every non-donor — everyone, in every
shipped build — the sentence renders unchanged, character for character** (asserted
verbatim by `T-DON-06`). For a donor it is replaced by a sentence that names the
exception specifically rather than softening the claim, and a lint fails the test run if
any view hard-codes the original sentence again.

**RK-DON-06 — fabricated or someone else's data enters the corpus.** Cause: a donor build
running on demo/mock data, or an LV001 fixture in the store. Controls: the assembler
drops every row whose provenance is not REAL (demo seeds are SIMULATED, LV001 is
EXTERNAL), and the gate refuses outright while the session is showing demo data. A
corpus that is meant to expose what synthetic data cannot must not be contaminated by
synthetic data. Verified by `T-DON-03`/`T-DON-05`.

**RK-DON-07 — a device name identifies the donor.** HealthKit source names are
user-editable and routinely carry a person's own name ("Claus' Apple Watch"). Left alone,
every donated row would have carried it. Control: sources are normalised to a device class
from a fixed allow-list; an unrecognised name becomes `unknown-<6 hex>` salted with the
grant reference, so two different devices stay distinguishable (dedup and arbitration
defects need that) while the string never leaves. Verified by `T-DON-03`.

**Not mitigated here, and named so it is not assumed:** consent validity under power
imbalance (§2.2, OD-D5), the lawful basis for the controller donating his own data, the
isolated environment and its access log, the erasure drill, the Scaleway DPA, the ROPA
entry, DPIA v02, and the correction of the donor consent text to match the training
decision. Each is a §7.3 gate and none of them is a code control.

## Data honesty — Settings asserted state it had never looked up (2026-08-13, branch claude/a72-electric-ink)

**RK-SET-01 (NEW) — a trust surface stated facts about the citizen's data that
were written into the source.** Reported by internal TestFlight testers. The
three "My data" rows in `SettingsView` carried their statuses as string
literals — `status: "Connected"` (Apple Health), `status: "3 files"` (Health
Vault), `status: "Not connected"` (Sundhedsplatformen) — so every citizen on
every device saw the same three answers regardless of what was true. Observed
consequences: a tester with an EMPTY encrypted space was told it held three
files, and Apple Health read "Connected" on a phone whose Home was still
showing the waiting-for-data state.

Harm class: this is not a clinical hazard, it is a TRUST and INTEGRITY hazard on
the surface whose whole job is to tell the citizen what the app holds and where
it came from. A citizen who believes documents are stored when none are may
delete their only copy elsewhere; a citizen told Apple Health is connected has
no reason to fix a connection that never worked, and will read an empty app as
"Liviqa has nothing to say about me" rather than "Liviqa is not reading
anything". Both corrupt the informed picture the consent and data-sovereignty
promises rest on.

Controls now in place:
- **Every status is derived** (`SettingsStatus`, pure Foundation): Apple Health
  from the real provider/read outcome on `AppState`; the vault from
  `HealthVaultSession.open`; Sundhed.dk from the persisted returning-user
  record; the account row from the real session; the version row from the
  bundle.
- **Unknown is a first-class answer.** Before the first read completes the row
  says "Not checked yet" / "Checking…" — it does not fall back to a reassuring
  default. This is the same discipline as the HealthKit wording rule below.
- **No number the app could not obtain.** In every non-`.ready` `VaultAccess`
  state (locked-until-unlock, key-unavailable, sealed-data-unreadable) the row
  names the state and prints NO count. Printing "0 files" over documents that
  are on disk but sealed would be the most damaging possible sentence on that
  row — it invites a reinstall, which would actually destroy them (the same
  reasoning as RK-VAULT-02).
- **Counts agree with the screen they link to.** Settings and Data sources now
  call one shared counter (`DataSourcesView.connectedSourceCount`), and the
  vault row is read with the same call the vault screen makes, so "N documents"
  in Settings is the N that screen lists. Each row also pushes the screen its
  status describes, so the two can be compared in one tap.
- **Regression guard.** `SettingsTruthTests.statusArgumentsAreNeverLiterals`
  parses every `connectedSourceRow` call in the source and fails the test run if
  a `status:` argument becomes a string literal again — including one hidden
  inside `String(localized:)`. Verified as a negative control (re-injecting
  `status: String(localized: "3 files")` fails the suite).

**HealthKit wording rule held (`AppState.HealthReadOutcome`).** HealthKit does
not report READ authorisation — a denied read is specified to look exactly like
an empty one. No Apple Health status added here claims a denial: the honest
statuses are "No readings yet" (the read completed and every requested type came
back empty) and "Couldn't be read" (the request threw).
`noAppleHealthStatusEverClaimsADenial` asserts this over every case. The same
correction was applied to the one-tap connect result in `DataSourcesView`, which
previously ended with "Connected. As your Health data fills in…" whatever came
back, and to its Release copy, which promised sample data a Release build never
shows.

**FR-WAL-09 claim gate widened to Settings.** The consent line under "Consent &
sharing" asserted "All sharing changes are independently logged and cannot be
altered" unconditionally, while the ledger screen it links to gates exactly that
claim on real consent-engine evidence (`ConsentLedgerView.headerClaim`,
T-WAL-09) and softens it to a design-intent statement while `CE_MODE=stub`.
Settings now renders that same gated sentence, so the strong append-only claim
cannot be made on Settings' own authority. Likewise the "You haven't shared data
with anyone" card no longer renders while the consent record is still being
read.

**No clinical hazard introduced.** Nothing here touches the nudge engine, the
AFib display-only lane (D9/FR-NDG-06), glucose units (OD-07), or any output
allow-list; no data is written, deleted or re-keyed by these changes, and the
vault is only OPENED for a count (read-only, no `add`/`delete` path added).
`provenance` remains a data field and never renders (`guard_provenance.sh`
green). Linked requirements: FR-SET-03 (new), FR-ARCH-05, FR-ING-15, FR-WAL-09.

**Residual risk.** (a) In DEBUG demo builds the Apple Health row may read
"Connected" from the demo seed — DEBUG-only, and Release cold-start seeds carry
`isConnected: false`. (b) If the consent-grant fetch FAILS (rather than being in
flight), Settings still renders the "no active sharing" card; distinguishing
"loaded and empty" from "could not load" needs a loaded/failed flag on
`AppState`, which this change does not own — carried as an open item.

## Journal cross-account exposure + fabricated entries + identifier-as-name (data-honesty incident, 2026-08-13, branch claude/a72-electric-ink)

Reported by internal TestFlight testers: glucose readings and journal entries
they never wrote, and a greeting that used an Apple private-relay identifier as
their name. Three hazards, all in the "what the app asserts about the citizen"
class rather than the clinical lane. No nudge, no metric, no clinical output
changed — but a fabricated entry that reads as the citizen's own words is an
input a clinician could be shown in a consult, so this is treated as a
data-integrity/privacy hazard, not cosmetics.

- **RK-JRNL-XACCT-01 (NEW, high — one citizen reads, or shares, another
  citizen's journal):** `journal.v1.json` lived at one DEVICE path, and
  `AppState.signOut()` only cleared an in-memory array while `JournalView` held
  its own `@State` loaded straight from disk. A second account on the same phone
  (a shared TestFlight device, a resold phone) opened the previous person's
  private writing, and the GDPR export (Art. 20) would have exported it as
  theirs. **Mitigated by construction:** the store is now namespaced per ACCOUNT
  (`journal/<sha256(accountID)>/journal.v1.json`), following the vault's
  `EncryptedAnchorStore`/`LocalUserScope` shape but scoped to the signed-in
  account, because the leak is between accounts on one device. No account id ⇒
  no path ⇒ nothing readable and nothing writable; a new account starts EMPTY;
  sign-out deletes nothing and leaves nothing addressable to the next account.
  Export and "delete all my data" are likewise account-scoped (erase removes THIS
  account's scope plus the unattributed legacy file — never another account's
  scope, which is another person's writing). Tests: `JournalScopeTests`
  (isolation, sign-out, erase). Linked: NFR-PRIV-01, FR-JRNL-SCOPE-01.
  **RESIDUAL RISK — first-adopter ambiguity (accepted, low, stated plainly):**
  the pre-10.101 file carries no author. On first run after the update it is
  adopted into the FIRST signed-in account's scope. If the first account to open
  the app is not the one that wrote the entries, that account adopts them — the
  same visibility that exists today for every account, narrowed to exactly one
  adoption and then closed forever. The alternative (deleting the unattributed
  file) was rejected: it would destroy real writing to defend against a case we
  cannot detect. Partial detection IS applied — entries whose `userId` names a
  different account are never adopted, and the file is left intact for its
  owner — but local entries carry no `userId`, so it does not cover the common
  case. Operational control: testers who shared a device should erase and
  re-import rather than trust an adopted journal.
- **RK-JRNL-FABRIC-01 (NEW, high — fabricated entries read as the citizen's own
  record):** three `JournalView.demoSeed` entries (one carrying a 6.2 mmol/L
  fasting glucose) were written to the device store by a June build before the
  seeding gate existed, and every later build read them back. The `#if DEBUG`
  gate stopped new seeding but nothing cleaned up what was on disk.
  **Mitigated:** a one-time, idempotent purge by EXACT whole-body match against
  the app's own three strings, applied on read, on migration and on write. The
  write-path filter is the structural fix — the seed cannot be persisted in any
  configuration, which is precisely how a DEBUG value became "the citizen's
  words". Narrowness is the safety property: a citizen who wrote their own note
  about a 6.2 fasting glucose keeps it (prefix, suffix and quoting cases are
  tested). Seeding is additionally gated on a demo session. Nothing containing
  entry text is logged. Tests: `JournalSeedPostureTests` (source lints incl. "a
  seed body compiled into Release anywhere fails", "the denylist is the seed
  verbatim") + the purge tests in `JournalScopeTests`. Linked: FR-ARCH-05,
  FR-JRNL-SEED-01.
- **RK-ACC-NAME-01 (NEW, medium — an account identifier is shown to the citizen
  as their name, and to a clinician in a consult):** `/me` returns the
  private-relay mailbox name as `displayName`, and the onboarding-declared name
  only applied when that value was EMPTY, so Home greeted "Good morning,
  75sg6pvfys." **Mitigated:** one pure resolver (`DisplayNameResolution`)
  decides — declared name wins; an "@"-bearing string or a value equal to the
  local-part of the account's own email is a placeholder, not a name; nothing
  known ⇒ no name rather than an invented or identifier one. Applied once in
  `AppState`, so every surface reading `profile?.displayName` is fixed at the
  source. Tests: `DisplayNameResolutionTests`. Linked: UC-01, NFR-PRIV-05,
  FR-ACC-NAME-01. **Residual:** when the account email is unknown (a session
  restored without it) a bare mailbox-shaped id cannot be recognised as such and
  would still render; in the observed sovereign path `/me` always carries the
  email. Follow-up (NOT in this change): `LiviqaAppBar.initials(nil)` falls back
  to the letter "C" when no name is known — no longer an email fragment, but
  still a stand-in; owner of the chrome to replace it with a neutral mark.

No new clinical hazard; RK-NDG-*/RK-CARD-01/RK-GLU-01 controls untouched (no
engine input, threshold or output surface changed). `scripts/guard_provenance.sh`
green — no provenance field reaches a view.

## Ingestion — HR-in-interval + intra-night sleep (2026-08-13, branch claude/a72-electric-ink)

Two ingestion gaps closed (T-FIT-01 workout heart-rate; sleep segment start
times + the AWAKE stage). Both are READ-side only — the HealthKit share/write
set stays empty (FR-ARCH-04) and no new output surface is created. Three
safety-relevant consequences, each with its control:

- **Nudge INPUT changes (nightly sleep totals).** Sleep is now bucketed by the
  night's END day (`HealthKitService.nightDay`, boundary 18:00) and the nightly
  union is taken over the segments' REAL start times. Previously every segment
  of a night shared one start-of-day instant, so `mergedAsleepHours` collapsed a
  fragmented night to its longest fragment, and a night spanning midnight was
  split into two half-nights. Both made the engine's "Short night" comparison
  read off a wrong nightly total. This is a correction toward the true value,
  not a new claim: `NudgeEngine`'s baseline arithmetic, its thresholds and its
  allow-listed output are untouched (`NudgeEngineTests`, `SleepMergeTests`,
  `SleepDeriverTests` all green). No new hazard; RK-NDG-* controls unchanged.
- **Heart-rate zones could have imported a population scale.** They do not:
  every zone edge is a fraction of the citizen's OWN observed maximum in the
  window, the card's foot prints that number and the words "not a population
  scale, and not a target", and `WorkoutHeartRateIngestionTests` asserts both
  the derived value (own max, not 220−age) and the copy. Guards the
  personal-baseline-only rail and the FR-FIT-01 no-targets designation.
- **AWAKE is now ingested.** Every asleep total in the app filters on the asleep
  stage set, so awake minutes can never inflate a sleep duration —
  asserted directly (`SleepNightShapeTests.awakeNeverInflatesAsleepTotals`).

`provenance` handling is unchanged: the new `HeartRateSample` carries it as a
data field only, and `scripts/guard_provenance.sh` stays green.

**RK-CTX-04 control widened (FR-CTX-04, designated interaction rule).** Demo
`PatternEngine` findings were appended to the feed AFTER `NudgeEngine` had run,
so they bypassed the context-flag suppression gate: on a day the citizen had
marked "travelling / unwell / off routine", the feed could still grow. The
append is now gated on the same flag (`AppState.refreshFromHealth`:
`if !real, !markedToday`), preserving the one rule the flag exists to keep — a
flag can only ever REMOVE cards, never add or re-rank one. Proven by
`HealthReadOutcomeTests.markedDaySuppressesDemoPatternFindings` (output on a
marked day ⊆ output unmarked). These cards remain DEBUG + mock-provider only.

**No hazard introduced by the inferred-denial cue.** The new screen states only
what the app can observe (a read completed and brought back nothing) and
explicitly says the two possible causes cannot be told apart from inside the
app — HealthKit does not report read authorisation. Asserting a denial would
have been a claim the software cannot substantiate.

## Care & sharing — device-sweep fixes (2026-08-13, branch claude/a72-electric-ink)

**RK-CONSULT-STAGE-01 (NEW) — the in-call stage said nothing when it had no
picture.** The device sweep captured `ConsultView`'s stage as a fully black
rectangle: the room webview had produced no frame (no camera on the simulator,
and an EU room that the device could not reach) and the app drew nothing over
it. Hazard: a citizen sitting in front of a black rectangle cannot tell whether
they are connected, muted, unseen, or waiting — and a call surface that implies
a live connection it does not have is a trust failure on a consultation path.
Controls now in place:

- The room webview reports its REAL load state (`WKNavigationDelegate`:
  finished / failed / content-process died). Anything short of loaded content is
  covered by `CallStagePlaceholder` — the brass witness ring, who you are
  talking to (name · organisation, FB 10.39), and one honest line.
- **Every line is derived by `CallStageDeriver` (pure Foundation) and asserted**
  (`CallStageDeriverTests`): `.live` is the only phase that prints nothing (the
  video provider owns the surface and Liviqa claims nothing); a stage with no
  configured room may not say "connecting"; an unreachable room says "Not
  connected" and offers a retry; "Waiting for your camera" is sayable only while
  a connection is actually being attempted.
- The self tile reports a LOCAL device fact — "No camera on this device" /
  "Camera off" — read from `AVCaptureDevice` hardware + already-answered
  authorisation. Neither call raises a permission dialog; camera/mic capture
  consent is unchanged and still the webview's own getUserMedia prompt.
- `CallStagePlaceholderRenderTests` renders the placeholder off-screen and
  counts lit pixels, so the blank-rectangle failure mode itself is under test.
- **Safety copy untouched**: the citizen-owned recording-consent banner and the
  summaries-only note are byte-identical. No new consent affordance, no change
  to what leaves the device. Residual: LOW — once media is up the provider owns
  the surface, so a remote participant who turns their camera off mid-call still
  gets the provider's own avatar treatment, not ours (accepted: reading the
  provider's track state would need the Jitsi iframe API on this path).

**RK-SHARE-04 (NEW) — the "summaries only" guarantee rested on a default two
layers below the consent surface.** Found while hardening T-PRO-01. Hazard: the
share screens promise summaries only, but `AppState.createGrantAndShare` passes
`granularity: nil` and the value that actually goes on the wire comes from
`LiviqaBackendService.createGrant`'s `?? "summary"` default. The promise is true
today (asserted on the wire by `ConsultShareTests.theWireBodyCarriesSummariesOnlyGranularity`),
but a refactor of that default would widen **every** share silently, with no
screen changing a word. Mitigations landed: `ShareGranularity` (pure Foundation)
names the map once; `ShareWithClinicianView` states it explicitly
(`requestedGranularity`) and DERIVES its consent copy from it, so a wider detail
level would strip the "summaries only" wording from the screen instead of
leaving a false promise (`ShareGranularityTests`). **OPEN (one line, AppState —
not owned by this change): `AppState.swift:1056` should pass
`granularity: ShareGranularity.summariesOnly(for: scopeGroups)` instead of `nil`,
after which `ConsultShareTests.swift:135` flips from expecting `nil` to expecting
the explicit map.** Until then the wire value is correct but implicit. Residual:
LOW (behaviour unchanged today), tracked on FR-SHARE-02 / FR-PRO-01.

## FR-XPL-01 — universal "See why" + published method notes (Bevel absorb ②, 2026-08-13)

This change adds a new user-facing generated-text surface on top of **every**
verdict the app prints, and publishes the app's decision rules in the Learn tier.
It is a safety-path change on two counts: new output copy (FR-NDG-06 territory),
and the fact that an explanation makes a verdict feel more authoritative than the
verdict alone. Three hazards were considered.

**RK-XPL-01a — the explanation reads as a clinical justification.** A panel
headed "the arithmetic" invites the user to treat the number as clinically
meaningful. Controls:

- **Every string is a fixed template in `SeeWhyExplainer` (pure Foundation) and
  every one of them goes through `NudgeGuard`** — the same designated control the
  engine's output passes. `SeeWhyExplainerTests.everyDisclosureTemplatePassesNudgeGuard`
  sweeps >40 explanations across every builder and every branch (surface, verdict
  echo, row labels and values, honest-absence copy, footer). Nothing on this
  surface is composed at runtime; the figures are substituted into frozen text.
- **The verbatim personal-baseline footer is carried on every disclosure**
  ("compares you only to yourself · not a diagnostic measure"), asserted by test.
- **A banned-phrase test** additionally rejects "normal range", "healthy range",
  "reference range", "percentile", "average person" and "compared to others" —
  belt-and-braces over the guard, because this panel is where population framing
  would be most tempting to reach for.
- **The disclosure is moss (trust), never clay or clinical red.** An explanation
  is not an alarm, and the colour rails say so.

**RK-XPL-01b — a plausible-sounding explanation is invented for a figure that was
never derived.** The dangerous failure here is not silence: it is a confident
decomposition of a demo seed or a still-calibrating window. Controls:

- **`SeeWhyExplanation` cannot hold both rows and an absence** — its initialiser
  drops the rows whenever `unexplained` is set, so an honest state can never leak
  half a decomposition. `sampleDataExplainsItselfWithNoRows` and
  `coldStartSaysThereIsNothingToExplainYet` pin it.
- **No new derivation exists in this feature.** Every builder takes figures the
  derivers already produced; nothing in the file reads `HealthSamples`. A thin
  series (<4 days) refuses to split the week rather than inventing halves; a band
  that has not been learned is named as absent rather than approximated.
- **One source for the verdict and its explanation.** `todayTone` and
  `dayScoreLegs` moved into the explainer and TodayView now calls them, so the
  sentence on the screen and the arithmetic in the sheet are chosen by the same
  function and cannot drift apart.
- **Two honesty fixes fell out of applying the rule.** The Home Heart card's
  verdict word was the constant "Calm" regardless of the reading — a verdict with
  no derivation behind it — and now reads off the same own-usual band the card
  already draws. `MetricDetailView`'s canned recovery observation ("higher meeting
  load and later meals") was rendering over real readings and is now gated to the
  illustrative values it was written for.

**RK-XPL-01c — a shared reference passes as "your usual".** Liviqa is
personal-baseline-relative except in two places, and an explanation that quietly
omitted them would be worse than no explanation. Controls:

- **The 70% time-in-range mark is labelled as a shared clinical mark** wherever it
  decides a word (Home hero, Home glucose card, glucose detail), with the
  sentence "everything else compares you to you" alongside it.
- **The 8-hour sleep leg of the evening score is named as a fixed reference**, in
  the disclosure and again in the published `day-score` method note; the sleep
  detail's rest/depth legs name their fixed references (8 h, 35% deep-and-REM
  share) the same way. `dayScoreSheetAddsUpAndNamesTheFixedReference` asserts it.
- **The evidence gate is published as the code applies it** (|r| ≥ 0.40, p ≤ 0.05,
  N ≥ 10, strong at 0.60) and the below-gate disclosure states the refusal rather
  than softening it.

Residual risk: the disclosure explains *how* a figure was produced, never *what it
means for health* — that boundary is held by the fixed templates and the guard,
not by user interpretation, and remains the reason no clinical framing is offered
anywhere on the surface. Danish translation of the new copy is a separate gate.

## FR-NOT-02 — earned-attention micro-loop off session (Bevel absorb ⑤, 2026-08-13)

Until now every notification Liviqa could send was a **clock** loop: fixed text
at a fixed hour. This change adds the first notification whose existence depends
on the user's own numbers, and it is decided while the app is in the background —
a safety-path change on two counts (new generated-output surface, and a decision
taken with no one watching). Three hazards were considered.

**RK-NOT-02a — an interruption is read as a clinical verdict.** A banner on a
lock screen is the least contextualised surface the product has: no evidence row,
no baseline, no "why this?". Controls:

- **The delivered text is a fixed template, chosen by the nudge's allow-listed
  `NudgeCategory` and nothing else.** There is no code path from a health value
  to notification copy in `EarnedAttention` — the same by-construction property
  `EditionNotifications` already had. The engine's own sentence (which legitimately
  carries numbers, e.g. "about 20% more than usual") never travels.
- **No reading can appear at all.** `EarnedAttentionTests.noTemplateCarriesAReadingValue`
  asserts the templates contain no decimal digit whatsoever — a stricter rail than
  FR-NDG-06 alone, applied because this surface is read out of context.
- **FR-NDG-06 (designated control) covers every deliverable string**, and the one
  non-template string in the path — the nudge headline carried unrendered in
  `userInfo` for the deep link — is re-checked with `NudgeGuard` and *dropped*
  rather than carried if it ever failed.
- **The banner's job is to hand over to the shown work.** Tapping opens that
  nudge's evidence view, which is Liviqa's structural answer to score opacity.
  The alert says only that one thing is worth a look; the workings are on the card.

**RK-NOT-02b — a stale or context-blind alert alarms the user.** An
opportunistically-woken app could easily deliver something true six hours ago, or
something the user had already explained away. Controls:

- **Derive and deliver in the same wake.** The request carries `trigger == nil`;
  nothing is ever pre-scheduled. If the app is not woken inside the delivery
  window, the alert simply does not exist.
- **FR-CTX-04 suppression is not allowed to go silently missing.** The context
  store is written `NSFileProtectionComplete`, so on a locked device it reads as
  "no flags marked" — which would turn the suppression gate into no gate at all.
  The pass therefore refuses to run unless `isProtectedDataAvailable` is true, and
  hands the slot back. (HealthKit is closed on a locked device anyway; this makes
  the reason explicit rather than incidental.)
- **The AFib / route-to-clinician lane is deliberately excluded from this loop.**
  Apple Watch already notifies for an irregular-rhythm signal at the moment it
  records one. A second, opportunistically-timed echo hours later would be an
  alarm Liviqa can neither time nor interpret — and D9 forbids interpretation.
  The routing nudge still sits at the top of the edition, which is where the
  "share this with your cardiologist" sentence belongs. `EarnedAttentionTests.theAFibRouteNeverProducesAnAlertEvenAtTopPriority`
  proves it cannot fire even at priority 100.
- **Only the top of the ladder may interrupt** (`.bandStatus` / `.behaviouralLever`
  at engine priority ≥ 60). "Glucose steady", "short night", "quieter day" and the
  plain resting-HR echo are all real engine outputs that stay silent.
- **At most one a day**, enforced by a pure function over a device-local ledger,
  and by a single request identifier so alerts replace rather than stack. This is
  the "At most one a day" the Notifications screen states verbatim.

**RK-NOT-02c — the loop promises more than iOS delivers.** BGAppRefreshTask is
opportunistic: it does not run in Low Power Mode, when Background App Refresh is
off, or when iOS has not learned a usage pattern. Controls:

- **Every failure mode is silence.** Never woken, woken while locked, woken at
  03:00, woken with nothing earned — all produce no notification. There is no
  branch that substitutes something weaker to fill the gap.
- **Demo data can never notify.** The pass returns early unless the resolved
  provider is `.healthKit` *and* the fetch returned readings; a mock/demo run
  produces no alert. (Honest-data rail: an alert about fabricated numbers is
  exactly the failure this loop was built to avoid.)
- **The UI says so.** `NotificationSettingsView`'s status line now reads that
  earned attention is worked out on this phone "when iOS lets the app wake between
  09:00 and 20:00 — some days it will not, and then you simply hear nothing."
  It no longer says the channel "applies later", because it no longer does.

**Residual risk.** The wake itself is unverified on hardware: the loop has unit
proof of every decision it makes, but no device QA yet of a real BGAppRefreshTask
firing (tracked on the RTM row). Because the unverified path fails to silence,
the residual is a *missed* alert, not a wrong one. No new hazard introduced to
the cardiac or glucose lanes; no new data leaves the device (the pass reads
HealthKit and writes one local notification, nothing else).

## FR-REC-03 — any-lab PDF/photo import (Bevel absorb ④, 2026-08-13)

A new *entry point into the canonical health record* is a safety-path change:
until now every row in `HealthRecordStore` came from a structured source
(Sundhed.dk, HealthKit, or the citizen typing it). This one comes from reading
paper. Two hazards were considered.

**RK-REC-03a — a misread number enters the record and is later trusted.**
OCR does not fail loudly; it fails plausibly ("6.4" read as "64"). Controls:

- **Review before save is structural.** `LabReportImportView` has no path from
  picking a file to `HealthStore.ingest` that does not pass through the review
  list. Every recognised row is shown with its value, its unit, the source line
  it came from, and a switch; the Save button counts what will be written
  ("Save 12 to my record") and is disabled at zero.
- **Nothing is guessed.** A known analyte in a unit the parser cannot convert
  *exactly*, a number that is ambiguous under EN/DA grouping ("1.234"), a
  censored bound ("<0.6"), and a value outside a deliberately absurd-wide
  readable bound are ALL refused and listed as unread lines with their reason.
  The bound is an OCR-sanity gate, never a clinical range, and is never shown.
- **Low-confidence rows arrive switched OFF.** Below 0.5 recognition confidence
  the row defaults to excluded and says so; the citizen must opt it in.
- **An edited value replaces the machine's, and an unparseable edit saves
  nothing** — the row cannot silently fall back to the OCR reading.
- **Unit confusion is closed at the edge (OD-07).** Glucose lands in mmol/L and
  HbA1c in the NGSP % headline whatever the report printed, using the SAME
  conversion the Sundhed Path B parser uses (`SundhedParsers.hba1cIFCCtoNGSP`) —
  no second standard. Converted rows show their work ("Printed as 108 mg/dL").
  T-REC-03 covers normalisation, the allow-list, and each refusal class.

**RK-REC-03b — an imported value is read as a clinical verdict.** A lab report
arrives covered in reference intervals; carrying those into Liviqa would import
exactly the population-normal framing the product exists to avoid. Controls:

- **The lab's bands are structurally unreadable.** Bracketed text, anything
  behind a reference/interval keyword, and both sides of an "a – b" span are
  exclusion zones in the number scanner — the parser cannot pick a value out of
  a printed range even if it wanted to, and nothing in the result type can carry
  one.
- **Framing is the citizen's OWN prior value or nothing.** `LabPriorFraming`
  produces one sentence: the previous stored value for that analyte with its
  date and the change since, or "No earlier … on this phone". A prior in a
  different unit is not compared at all. There is no verdict, no band, no
  adjective.
- **FR-NDG-06 (designated control) is applied to this new generated text.**
  These sentences are the only generated copy in the import path.
  `LabReportParserTests.everyFramingSentencePassesNudgeGuard` runs
  `NudgeGuard.check` over every sentence the path can produce, for all 15
  analytes in both directions, and additionally bans population/advice
  vocabulary. The sentences deliberately carry no unit token.
- **Provenance is untouched.** Rows are stamped `HealthDataSource.paperScan`
  with the file name as `sourceDetail` — user-facing source labels, not the
  `Provenance{REAL,SIMULATED,EXTERNAL}` data field, which this feature neither
  reads nor renders. `scripts/guard_provenance.sh` green.
- **No red.** The screen's only signal colours are moss and brass; `clinRed` and
  the `tir*` ramp appear nowhere in it.

**On-device rail.** Reading happens in `LabReportOCR`: PDFKit for a text layer,
`VNRecognizeTextRequest` otherwise. Noted honestly: the iOS SDK
(iPhoneSimulator 26.5) has **no** `requiresOnDeviceRecognition` property to set —
it was a macOS-only switch — so the guarantee rests on the platform behaviour
that iOS text recognition runs on device, not on a flag we set. The code carries
that note at the exact line where such a flag would go. No network call exists in
the import path.

**The file itself.** Discarded after parsing by default (the Sundhed Path B
precedent), with an explicit opt-in to hand it to the existing encrypted
document vault (`HealthVaultStore`, unmodified). The done card states which of
the two actually happened, including when the vault write failed.

Residual risk: a transcription error the citizen does not catch during review is
stored as their own value — the same residual risk as manual entry, and the
reason the source line is printed under every row. The importer reads 15
analytes; anything else is listed as unread, so a report can be partially
imported without the citizen being told it was complete (it never claims to be).

## FR-WID-01 — home-screen widgets + complication (Bevel absorb ①, 2026-08-13)

Source-complete, **target-pending**: no WidgetKit target exists yet, so none of
this code executes on a device today. The risk note is filed now because the
design decides a safety-path question — *what may leave the app's process*.

New hazard considered: **RK-WID-01 — guarded text or hidden data escapes the app
through the widget channel.** A widget extension is a separate process with its
own sandbox; whatever the app writes into the shared App Group is rendered
outside every in-app guard. Controls:

- **Allow-list by construction.** `LiviqaWidgetSnapshot` has six explicit
  `CodingKeys` (`schema`, `derivedAt`, `edition`, `verdict`, `chips`,
  `timeInRange`) and carries no raw samples, identifiers, or clinician data.
  `provenance` is absent, has no key, and must never be added; T-WID-01 asserts
  the encoded top-level key set, so a new stored property cannot start crossing
  the boundary unnoticed. `scripts/guard_provenance.sh LiviqaWidgets` green.
- **FR-NDG-06 re-checked at the boundary (designated control).** The verdict
  sentence is the same allow-listed line Home and the wrist show, but the
  publisher does not assume that: `NudgeGuard.check` runs immediately before the
  write, a violation is replaced by the neutral steady line (never the offending
  text, never a blank), and DEBUG traps. Every *static* string the extension can
  render is collected in `WidgetCopy.allStatic` and swept by T-WID-02 — needed
  because `NudgeGuard` itself is not a member of the extension targets.
- **Red stays clinical.** The widget's time-in-range is two-state — inside your
  range (`moss`) on an outside track (`line`). `clinRed` and the five-band `tir*`
  ramp appear nowhere in `LiviqaWidgets/`; a home-screen surface is not a
  clinical surface. The attention state remains the locked amber `clay`.
- **No composite score.** The absorb exists because Bevel's opaque score was its
  loudest complaint. The widget shows the sentence and the decomposed parts
  behind it. Adding a single blended figure to this surface would reintroduce the
  hazard the feature was built to avoid.
- **Fails closed, never stale-and-silent.** The App Group id comes from the
  Info.plist `LiviqaAppGroup` (`$(APP_GROUP)`); if it is missing or unexpanded
  the store reads `nil` and writes `false` rather than guessing a container.
  When the app has nothing honest to publish it *clears* the snapshot, so a
  figure cannot outlive its data, and every surface carries "as of HH:MM".

Residual risk: a widget necessarily shows a cached value that may be minutes or
hours old. Mitigated by the mandatory timestamp on every family that has room for
one (small, medium, `.accessoryRectangular`) rather than by promising freshness.
`.accessoryCircular`/`.accessoryCorner`/`.accessoryInline` have no room for a
timestamp and therefore carry only the figure — accepted, as they carry a single
descriptive number with no interpretation.

### RK-WID-02 (OPEN — finding on a designated control, NOT changed here)

While sweeping widget copy through `NudgeGuard`, the `clinicalNormality` rule was
found to be narrower than its own documentation. The pattern is:

    \bab?normal\b|\bwithin\s+normal\b|\bhealthy\s+range\b|\bnormal\s+(range|limits)\b

`\bab?normal\b` matches "abnormal" and "anormal" but **not** a bare "normal" used
as a predicate. Confirmed by direct evaluation: `"Your readings are normal."` and
`"That is normal for you."` both PASS the guard, while `"abnormal"`,
`"within normal limits"` and `"normal range"` are caught. The comment above the
rule says it rejects "normal/abnormal", so the intent appears to have been
`\b(ab)?normal\b`.

Not changed in this PR: `NudgeGuard` is a **designated blocking control**, and
widening it is a deliberate act that needs its own review, a red-team pass over
existing shipped strings, and CN sign-off — not a side effect of a widget PR.

Current exposure: **nil in practice.** Every string this feature can render is
either fixed copy in `WidgetCopy` (swept, clean) or one of the three fixed
allow-listed week sentences from `AppState.watchStateLine(for:)`; none contains
"normal". The finding is logged for the control's owner to rule on, together with
the `blockedIntent` widening already recorded under Area ⑨.

## FR-CTX-04 — context status flag (Bevel absorb ③, 2026-08-13)

The user can mark a stretch of days as **travelling / unwell / off-routine**. The
marker is *declared* data — Liviqa never infers it — and it touches a designated
safety control, so it gets a row rather than a "no new hazard" note.

New hazard considered: **RK-CTX-01 — a context flag silences something the user
needed to see.** A feature whose whole purpose is "say less" can, done carelessly,
suppress a safety route or hide a reading. Controls:

- **Suppression-only, enforced by shape, not by review.** `NudgeEngine.generate`
  takes `context: [ContextWindow]` and uses it in exactly one place: an `if
  !suppressesBaselineDeviations(...)` around the baseline-comparison streams.
  There is no branch anywhere that emits, re-ranks or rewrites a nudge *because*
  a flag exists. `T-CTX-04e` proves it structurally rather than by sampling
  sentences: for every flag kind, the marked-day output is a strict **subset** of
  the unmarked output, compared on category+title+body+priority — so a flag can
  neither add a nudge nor raise a priority. `T-CTX-04d` proves a flag over an
  empty store produces nothing at all. This is the **FR-NDG-06 interaction rule**
  and its tests are blocking.
- **The safety route is outside the gate.** The D9 AFib route-to-clinician is
  emitted before the gate and is never suppressed (`T-CTX-04f` asserts the route
  and its `displayOnly` lane survive an active flag). A self-declared travel note
  must never silence a cardiac route. Today's UI mirrors this: `hasClinicianRoute`
  keeps the attention card on screen even on a marked day, and the calm context
  note stands in only when no route is present.
- **Nothing is hidden, only re-read.** The plain resting-HR number echo is also
  outside the gate (`T-CTX-04b`): a marked day still shows the user their own
  reading. Marked days stay in every derivation, aggregate and chart — the flag
  changes how a day is *read*, never what it contains, and no surface fabricates
  or omits a value because of it.
- **Charts go neutral, never alarming and never invented.** In the week grid a
  marked column takes one flat slate tint plus the shared `ZoneHatch` (the same
  hatch the TIR zones use, so the state survives greyscale and colour-blindness),
  is excluded from `clusterDay`/`hardDayCount`, and `.noData` still reads as
  empty — marking a day never invents a reading for it. The week verdict drops
  "steady, day after day" for "steady around the days you marked" rather than
  overclaiming across days the user told us were atypical. **No red anywhere**:
  the tint is `accentFinance` (slate/context); `clinRed` and the `tir*` ramp are
  untouched and stay exclusive to clinical glucose.
- **The Trends TIR chart now carries the same neutrality (2026-08-13).** It could
  not before: `TrendsRange.tirDaily` was a bare `[Double]`, so no bar knew its
  date and "which bar is Tuesday" was unanswerable. With `tirDailyDates` +
  `TrendsRange.tirSlots` each bar sits on its own calendar day, and
  `TrendsView.markedDates` hands the chart the marked days by date. A marked bar
  takes the same flat `accentFinance` tint + `ZoneHatch` as the week grid — never
  the deviation ramp, never the "today" emphasis colour — while its height stays
  exactly the recorded value. The marked-days annotation strip stays: the chart
  says what the flag did *and* did not change.
- **Copy through the guard.** Every string the feature introduces is a fixed
  template selected by enum — never assembled from readings and never from the
  user's note. `T-CTX-04k` runs all of them through `NudgeGuard.check`.
- **The note is out of the intelligence layer by construction.** `ContextFlag`
  holds the user's optional free text; the engine is handed `ContextWindow`,
  which has *no note field*. `T-CTX-04m` asserts two flags with different notes
  project to equal windows, so the text cannot become an inference input.

Privacy: the flags are the user's own words about their own life, so they are
personal data. `ContextFlagStore` is device-local JSON with
`NSFileProtectionComplete`, has no upload path, appears in no share or export
DTO, and `AppState.deleteAllData` removes the file alongside the journal and the
PMS outbox.

Residual risk (accepted, and stated on-screen): a user may mark days and forget,
quieting comparisons longer than they intended. Mitigated by visibility rather
than by expiry — the Today register carries a "Marked · Travelling" kicker every
day it is active, the entry row reads "tap when you're back to your routine", and
Settings → "Days you've marked" shows the open stretch with its start date. No
automatic expiry was added: silently un-marking a user's declared trip would be a
second, worse surprise.

## Chart day-axis alignment — a value read against the wrong day (2026-08-13)

Latent defect found and closed on the reading surfaces (Today · Insights/Week ·
Trends). It is a **presentation-integrity** hazard, not a new feature, so it gets
a row: the numbers were always right; the day they were drawn under was not.

Hazard: **RK-CHART-01 — the user reads their own value against the wrong day.**
Daily series (`TrendsRange.tirDaily`/`hrvDaily`, `TodaySignals.*Week`) carry one
entry per day THAT HAS DATA. Charts drew them at evenly spaced x-positions and
labelled the axis from a *separately* computed list of calendar days. The two
only agree when every day of the window has a reading — one missing day (watch on
the charger, sensor warm-up) shifted every later value one column, so a Saturday
number appeared under Sunday's letter, and the Trends hero's "lately…" tail could
describe a day well back in the window. Nothing in the type system objected,
because both sides were plain arrays. Consequence class: the user draws a
conclusion about the wrong day of their own life, and may repeat it to a
clinician. No clinical *decision* logic was affected — the nudge engine, the
evidence gate and every aggregate always worked from dated samples, never from
these display arrays.

Controls now in place:

- **Dates travel with values.** `TrendsRange` carries `tirDailyDates` /
  `hrvDailyDates` plus `windowStart`/`windowEnd`; `TodaySignals` carries a date
  array per week series. The deriver builds value and date in one pass, so they
  cannot desync.
- **One alignment primitive, unit tested.** `Liviqa/Intelligence/DaySeries.swift`
  (pure Foundation) turns a dated series into one `DaySlot` per calendar day.
  Axis labels derive from those slot dates, so a chart cannot claim a span its
  data does not cover.
- **Refuse to guess.** `DaySeries.aligned` places a dateless series only when it
  holds exactly one value per day of the window (unambiguous). A short dateless
  series returns `nil` and the view drops the day labels rather than mislabelling
  them — the same refuse-to-assert stance the evidence gate takes.
- **A gap renders as a gap.** A day with no reading draws no bar, no dot and no
  line through it. Never a zero (which would assert 0% in range), never an
  interpolated segment (which would assert an observation nobody made).
- **Regression tests that fail on the defect.** `LiviqaTests/DayAxisAlignmentTests`
  (14 tests). Verified by re-introducing index alignment inside `DaySeries.slots`:
  5 tests fail; restored, 14/14 pass.

Residual: sparklines with no day axis (Home signal chips, the "This week" teaser)
still draw a compacted series. They carry no day labels and make no per-day
claim, so nothing can be misread onto a date; left as-is deliberately.

## Two screens, one signal, opposite claims (design-QA 2026-08-13)

Sibling of RK-CHART-01 and found by the same sweep. DAY-01 fixed *where* a value
is drawn; this is about *which series* is drawn at all.

Hazard: **RK-CHART-02 — two surfaces describe the same signal, over the same
window, and contradict each other.** The Recovery pillar and the Insights week
plotted Friday as the week's HRV **high**; the HRV clinical detail annotated
"20 ms — your low, Friday" and the plain tier read "Yours dipped on Friday."
Both are labelled "this week", both draw the same seven day letters. Cause:
`HRVLearnDetail` derives its week straight from the daily SDNN stream, while
every other HRV surface plots `TodaySignals.hrvWeek`. With real data the two are
the same seven numbers by construction (same samples, same "one value per day
with data over the last 7 days" rule), so nothing ever disagreed in a real
session — but `AppState.applyLV001DatasetIfNeeded()` REPLACES `todaySignals`
with composed aggregates *after* derivation and left `hrvLearn` on the original
stream. Consequence class: the citizen cannot tell which screen is true of their
own body, and the app's core promise — that it only ever describes their own
data — is the thing put in doubt. The same detail feeds the assistant's
explain-a-drop template, so the contradiction could also be spoken.

No clinical decision logic was affected: the nudge engine, the evidence gate and
every aggregate work from dated samples, never from these display series. The
FR-NDG-06 output allow-list is untouched — the templates were always allow-listed
sentences; only the day they named was wrong.

Controls now in place:

- **One source for the week.** `HRVLearnDeriver.reconciled(_:with:)` re-anchors
  every week-shaped fact (series, low value, low day, latest value, and the
  copy built from them) onto the app's canonical week before any view sees it.
  The Learn entry point and the assistant summary both go through it.
- **One window rule.** Both the Recovery pillar and the Learn chart resolve their
  seven days through `DaySeries.days(endingOn:count:)` + `DaySeries.aligned`, so
  neither can define the window differently.
- **The long window keeps its own figures, and names them.** Range, median and
  the own-usual band still come from the up-to-60-day stream — no other surface
  draws them — and the copy states that window ("Your 60-day range 18–34 ms")
  next to a card kicked "This week", so a reader is never asked to reconcile two
  spans silently.
- **Regression tests that fail on the defect.**
  `HRVLearnDeriverTests.namedExtremeMatchesTheCanonicalWeek` over four week
  shapes, with `reconciliationActuallyMovesTheNamedDay` as the negative control:
  it asserts that the *un*-reconciled detail names a different day, so the
  fixture cannot quietly go stale and start proving nothing.

Residual: reconciliation happens at the view/summary seam, not inside
`AppState`, because the LV001 substitution that causes the divergence lives
there. Any FUTURE surface that reads `appState.hrvLearn` directly would
re-open the gap. The narrow fix — nulling `hrvLearn` alongside `glucoseDetail`
in `applyLV001DatasetIfNeeded()`, which already carries exactly this reasoning
for glucose — is recommended to the owner of `AppState.swift`; it would make
the divergence impossible at the source rather than corrected downstream.

## Hero weight as an alarm signal (design-QA 2026-08-13)

Hazard: **RK-ALARM-01 (extension) — a reassuring message delivered at alarm
weight.** The lock has always been about the clinical red MARK: `clinRed` is
glucose-TIR-only, and Heart already used the approved rose substitute rather
than the design package's saturated `#E62E3D`. The sweep showed the lock has a
gap it did not cover: a non-red token still reads as an alarm when it fills the
largest surface on the screen at full saturation. The Heart hero carried
"Resting lower than your usual band." — a calm, allow-listed sentence — on a
full-bleed crimson plate in paper and a bright rose plate in midnight, the two
themes carrying visibly different emotional weight for identical content.
Consequence class: a citizen reads alarm into a normal day, or (worse over time)
learns to discount the treatment and misses the day it means something.

Control: hero WEIGHT is now chosen by the verdict, on the same branch that picks
the sentence (`HeartDetailView.Model.needsAttention` → `MetricHero.weight`). The
full-bleed plate is reserved for "Resting above your usual band — worth a look";
calm and descriptive verdicts get the quiet plate. Palette untouched:
`accentHeart` 0xD9486B / 0xF07E9B stands exactly as approved (CN 2026-08-12) —
this is treatment, not colour. Because the quiet plate is alpha over each
theme's own card ground, paper and midnight now carry the same weight.
`MetricDetailCopyTests.weightAndVerdictNeverDisagree` pins the coupling.

Residual: the other domain heroes keep the full-bleed plate unconditionally.
That is accepted — their tints (sleep indigo, glucose teal, recovery sea blue,
body indigo) do not read as alarm at any area. If a future domain is given a
warm tint, it inherits this rule rather than the default.

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
- **RK-VAULT-02 (NEW, 2026-08-13) — a recoverable key state must not be shown
  as lost data, and must never re-key over sealed data (FR-ING-15).** Hazard:
  the first build treated EVERY key-provisioning failure as one thing and
  rendered "Your documents are unreadable without this device's key" with
  "Add a document" disabled. On the device sweep this fired for a purely
  environmental reason (an unsigned build has no `application-identifier`, so
  every Keychain call returns errSecMissingEntitlement −34018) — but the same
  code path runs on real hardware at first unlock, on restore-from-backup and
  after a passcode change, where telling a citizen their health documents are
  unreadable is a false alarm that invites a reinstall (which WOULD destroy
  them). Second hazard, quieter: `add`/`delete` loaded the index with `try?`,
  so a key that could not open the index would start a fresh one and write it
  OVER the old one — silent destruction of the only record of the documents on
  disk. Mitigation: `KeyVault` now separates KEY TYPE (Secure Enclave, else a
  software P-256 key — `protection`/`isHardwareBacked`, and the UI sentence is
  rendered from it, including "no claim at all" before provisioning) from KEY
  STORAGE (Keychain, else a device-local file with `NSFileProtectionComplete`,
  excluded from backup, used only when the Keychain answers
  errSecMissingEntitlement/errSecNotAvailable — `storage`). `KeyFailure`
  classifies a locked device (errSecInteractionNotAllowed / a
  complete-protection file read before first unlock) as a WAIT, never as loss,
  and never as grounds to move key material. Key material that exists but
  cannot be used raises `CryptoError.sealedKeyUnreadable` and is NEVER
  replaced — re-keying would orphan documents still on disk. `VaultAccess`
  gives the screen four named states (`ready` / `lockedUntilDeviceUnlock` /
  `keyUnavailable` / `sealedDataUnreadable`); only the last shows the
  unreadable sentence, the two middle ones are retryable and claim no loss,
  and "Add a document" is enabled from `canAddDocuments` (a prepared key AND
  an index this key can open). `HealthVaultStore.loadIndex` now distinguishes
  "no index" from "unreadable index" and `add`/`delete` refuse on the latter.
  `LocalUserScope` persists device-locally instead of re-minting an ephemeral
  id per call when the Keychain is unusable — an unstable scope would hide the
  citizen's own documents behind a new folder each launch. Asserted by
  T-ING-15 (`HealthVaultStoreTests`: fresh space is ready+writable, an
  unprovisionable key is recoverable not unreadable, sealed-data-unreadable is
  reported AND non-destructive with byte-identical files afterwards, add never
  overwrites an unreadable index) and `KeyVaultFallbackTests` (DEK stable
  across instances, hardware claim follows the live path, unusable key
  material never silently replaced, failure classification, device-file store
  round-trip/isolation/hashed names, scope stability).
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
