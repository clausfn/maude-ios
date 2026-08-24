# QMS Change Log

_One entry per release/PR that touches a requirement or risk control. Maps to git tags. Conventional Commits. Version: 2026-06-03._

## PR-118 — FB-APC4qJBj: the clinical TIR ramp reaches Day Replay (2026-08-24, branch `develop`, FR-VIZ-06) — **ships in 10.106**

**Tester (10.105, verbatim):** *"Try to make yellow and red zones for better visualisation. You did before."* Right on both counts. The five-zone clinical ramp has shipped since PR-99 on Glucose detail and Metric detail behind `clinicalTIRZones` (default ON); Day Replay was never migrated onto it and hard-coded a single pale band, never reading the flag. The same 19.9 mmol/L reading therefore drew banded on one screen and unbanded on another. **The defect was that inconsistency, not a missing feature.**

**refactor(charts): extract, do not duplicate.** `clinicalZones` / `zoneBand` / `ZonePattern` lifted out of `GlucoseCurveView` into `ClinicalTIRZones` — one implementation, one palette, one set of boundaries. The extracted view was rewritten as a contiguous stack rather than offset siblings, because the offset form silently clipped when placed outside a GeometryReader (caught on the simulator: IN RANGE rendered at a third of its height and the curve drew *below* its own target band). Drawn rects are proven identical to the pre-refactor formula to 0.001 pt across four axis and personal-range configurations, so Glucose and Metric detail did not move a pixel.

**feat(day replay): follow the flag.** ON ⇒ the shared ramp; OFF ⇒ the previous single `fjordBright.opacity(0.07)` band with the legacy y-domain reproduced to the value. With zones on the domain widens to span at least 2.0–14.0 while still containing the day's own extremes — without that, an in-range day squeezes the amber band to a sliver, i.e. the ramp would be present and unreadable. The x-axis is untouched (PR-116 `hourSpan`/`fraction`/`nearestIndex` still pinned).

**fix(comments): two stale rules corrected.** `DayTimelineView.swift` and the `TrendsCharts.swift` header both still asserted "no red — personal-band framing only", which predates PR-105 and is now false for this screen. Both now state the actual rule: glucose charts carry the ramp, red is the documented RK-ALARM-01 exception, and severity never rests on colour alone.

**No new colour.** The five tokens signed off 2026-08-12 are the only ones, and a source lint fails the build if `TrendsCharts` reaches for them directly instead of drawing the shared view.

**Verified in the simulator in both flag states**, not on a clean compile: zones on shows amber HIGH, green IN RANGE with the curve inside it, rose LOW and hatched VERY LOW; zones off shows the single flat band and the tighter domain, unchanged.

**Recorded, not fixed:** ① on a day that never exceeds 13.9 the VERY HIGH band is a hairline — correct (nothing is up there) and identical to the two charts that already shipped; ② `GlucoseCurveView`'s call sites pass `yMax: 14.0` and its `y(_:)` clamps, so a reading above 14 draws flat along the top edge of Glucose and Metric detail — the tester's own 19.9 peak would plateau there. Day Replay does not have this problem. Out of scope here; raised for CN.

QMS: RTM FR-VIZ-06 · RISK RK-ALARM-01 extended · VnV T-VIZ-06 · `qms/BETA_FEEDBACK.md` FB-APC4qJBj OPEN → FIXED.

## PR-117 — a deliberate sweep for three bug shapes, and the 16 it found (2026-08-19, branch `claude/a72-electric-ink`, FR-ING-20, FR-JRN-05, FR-CTX-06, FR-VIZ-05, FR-HON-01)

**Why sweep.** Five separate data-loss defects in this app have had ONE shape: a read fails, is treated as "there is nothing there", and is then written over. Every one was found after it had already destroyed something. This PR stops waiting: three shapes were swept for across the whole codebase — (A) unreadable-treated-as-absent-then-overwritten, (B) a compacted or zero-filled day axis, (C) an absolute in shipped copy the code does not honour. **31 candidates, each put to an independent adversarial verifier told to default to rejection; 16 survived.** The verifiers also recorded what they cleared and why, so the pass is auditable rather than a list of hits.

**fix(ingestion): an empty read is not evidence of deletion (FR-ING-20, RK-STORE-01).** `IngestionCoordinator.persist` deleted each stream's window and inserted the rows it was handed — so a read carrying NOTHING deleted up to 90 days of glucose, heart, sleep, workouts, insulin, blood pressure, AFib burden and body composition, and put nothing back. The trigger is not hypothetical: **HealthKit reports a denied read as an empty success**, so revoking one type in Settings arrives indistinguishable from a quiet month, and the caller ran `persist` unguarded two lines after classifying that same read as the inferred-denial cue. All eight `replaceX` helpers now return early on empty rows; real deletions are unaffected (they arrive through the anchored deletion stream, where HealthKit names what it removed).

**fix(journal): refuse to overwrite writing we cannot read (FR-JRN-05).** `openForAccount` collapsed "no file", "unreadable now" and "no longer decodes" into `[]`, and both writers persisted that plus the new note over the citizen's entire journal — their own words, no server copy by design. `save(_:to:)` now fails closed.

**fix(context): flags survive a locked launch (FR-CTX-06).** Seeded from `load() ?? []` over a `.completeFileProtection` file, so a locked background launch emptied every travelling/unwell/off-routine stretch and the next mark made it permanent. Second-order: those flags ARE the nudge-suppression gate, so an explicit "don't compare me to my baseline this week" silently stopped applying. Now mirrors the `HealthContextStore` discipline — three outcomes, a restore retry on `protectedDataDidBecomeAvailable`, and never persisting a seed.

**fix(charts): the day replay stands on the clock (FR-VIZ-05, RK-CHART-03).** `DayReplay.Point` carries the true hour of every reading and `DayReplayChart` spaced by index anyway, under a handle labelled "00:00 → now" — the compaction disease in its most avoidable form, since the correct coordinate was already in the data. Also: the Vitals strip printed the primitive's default "last 14 nights" caption over however many readings existed, and the baseline spark's kicker claimed "Last 14 days" over N recorded points.

**fix(honesty): six absolutes the build contradicts (FR-HON-01, RK-COPY-01).** The app-lock screen said "so it opens only for you" while the lock **fails open** with no biometrics and no passcode set. Onboarding asserted the consent ledger "cannot be edited, deleted, or backdated — by anyone", flat, while `ConsentLedgerView.headerClaim(hasEvidence:)` exists precisely to withhold that claim without evidence (FR-WAL-09). "Nothing is sent away" about the assistant, while `ChatView.send()` takes a cloud branch in every Release build. And on the privacy screen itself — the one surface built to say what is shared — "Anonymous compute only, your device answers queries, your data never moves", describing compute that exists nowhere in the tree while the real research path POSTs a payload. Each retired against the code that refuted it and pinned by a lint that names that code, so restoring a sentence requires restoring the mechanism.

**Residuals, stated rather than absorbed:** a store may now fail to SAVE (the citizen can lose the one note or mark just entered — refusing costs one entry, allowing cost every entry); the long-trend charts (weight, body fat, VO₂max, BP dots) still space irregular readings by index, which needs a date-proportional axis in the primitive rather than a call-site change and is recorded OPEN rather than half-fixed; the app-lock fail-open control itself is unchanged, and whether it should fail closed is a CN decision.

Suites: T-STORE-01 (6), T-VIZ-05 (3), T-HON-01 (3). **Full unit run 891 tests / 112 suites — all green.** `guard_provenance.sh` green.

## PR-116 — the QMS rows PR-115 owed, and the two defects writing them uncovered (2026-08-19, branch `claude/a72-electric-ink`, FR-SLP-11/12/13, FR-CTX-05, FR-VIZ-04)

**docs(qms): the row debt, stated plainly.** PR-115 shipped the sleep-visualisation wave, the whole-person Home and the field-bug fixes, and merged **without** the requirement rows its own agents asked for. This entry closes that: FR-SLP-11 (one-truth night model), FR-SLP-12 (ranges state their true denominator and keep their axis), FR-SLP-13 (the sleep surfaces degrade honestly rather than estimate), FR-CTX-05 (the declared profile survives a locked launch), and RISK RK-CHART-02 / RK-COPY-01.

**How the rows were written.** Not from memory — 40 claimed guarantees were put to independent adversarial verifiers against the shipped source. **35 came back NARROWER than claimed** and are recorded at their verified scope; 5 were confirmed as stated. Two of the narrowings were not wording but live defects, and both were fixed before any row describing them was written.

**fix(charts): the day axis may not lie (FR-VIZ-04, RK-CHART-02).** Three sites dropped dayless slots before drawing, so a chart asserted continuity the record did not have — labels travelled correctly with the values, so nothing was mislabelled and three earlier reviews passed over it; the lie was in the spacing. ① `SleepDetailView.weekCard` drew only nights WITH data (a Mon/Wed/Fri week rendered as three adjacent bars) → now the full 7-day axis with nil gaps. ② `ActivityDeriver.series` compactMap-ped absent days out of the week for steps and active energy → the DRAWN series is now the whole window while the statistics still count recorded days only. ③ `FitnessDeriver` skipped week buckets with no workouts, **hiding a rest week** — the one thing a training-load chart most needs to show → a week inside the recorded span is a real measured 0 and keeps its slot, while weeks before the first recorded workout stay nil (a 0 there would invent a rest week that never happened). `UsualDayBars.values` is now `[Double?]`, so a gap is unrepresentable as a zero at the type level.

**fix(copy): an absolute the same screen contradicted (RK-COPY-01).** The Sleep bedtime footnote read *"There is no recommended hour on this page."* The bedtime card is scrupulous — but the same page's sleep score divides by a fixed 8-hour reference and a 35% deep-and-REM share, and that page's own See-why panel says so out loud. Narrowed to the card it is actually true of, and pinned by a source lint so the page-wide absolute cannot return. The fixed references themselves remain, disclosed; whether they belong in a baseline-relative product is recorded as an open CN decision.

Suite: **T-VIZ-04 = `LiviqaTests/DayAxisIntegrityTests`** (6 — sleep fallback axis, activity gaps, energy absent-vs-gap, fitness rest week, fitness pre-record weeks, copy lint). **Full unit run 879 tests / 109 suites — all green** (873 before this PR); UI target 130/130; `guard_provenance.sh` green.

## Universal HealthKit read — every data point, browsable, judged by no one (2026-08-19, branch `claude/a72-electric-ink`, FR-ING-19)

**CN directive recorded (2026-08-19, verbatim):** *"I want all data from Apple HealthKit — every data point."* — OVERRULES the 2026-08-18 coverage audit's named-consumer rule; controller decision filed in `qms/DHF.md` with the date, addendum §6 appended to the audit doc.

**feat(ingestion):** `UniversalHealthReader` + `UniversalSamples` (NEW) — full-set read authorization (120 quantity / 70 category / 2 correlation / 6 characteristic types on the iOS 26.5 SDK, plus workouts, ECG, audiogram, vision prescriptions, series types, state of mind, GAD-7/PHQ-9; share set EMPTY — read-only stays structural); anchored, batched, `hkUUID`-deduplicated storage of quantity + category samples + a characteristics snapshot in a parallel on-device SwiftData container (`cloudKitDatabase: .none`, file-protected, `UniversalHealthStore.eraseAll()`); the tuned pipelines' types are EXCLUDED from storage and universal rows can never enter those pipelines (RTM FR-ING-19; RISK RK-ING-13/14, RK-NDG-05; T-UNI-01..14).

**feat(browser):** `DataBrowserView` "Everything you measure" (NEW) — every type with data: latest value + recorded unit, count, sources, 14-day DaySeries mini-chart (gaps stay gaps); NO sentences generated, no judgment vocabulary (lint-pinned); no synthetic stream — real store or honest empty state.

**fix(honesty):** `HealthKitPrimerView` v03 — the "these — and only these" lead (untrue since PR-46; audit report-only finding ①) replaced with claims true in every configuration.

**Integration lines REPORTED, not landed** (owning files belong to concurrent workflows this wave; layer dormant until they land together): ① `DataSourcesView`: `NavigationLink { DataBrowserView() } label: { DataBrowserEntryRow() }.buttonStyle(.plain)`; ② `AppState.deleteAllData`: `UniversalHealthStore.eraseAll()`.

Suites: `UniversalReadTests` 14/14 green; **full unit run 873 tests / 108 suites — all green** (Sim F8ACD7F7, build `build/ddfb3`). Guards: `guard_donation_egress.sh` green; `guard_provenance.sh` red on `SleepDetailView.swift:912-959` (sleep workflow's in-flight sample builder — file owned by the concurrent sleep wave; this wave's SwiftUI files verified clean under the same pattern).

## HealthKit ingestion coverage audit — sleep-incident wave, non-sleep breadth (2026-08-18, branch `claude/a72-electric-ink`)

**fix(ingestion):** cumulative daily roll-up (steps, active energy) no longer sums raw samples across sources — a Watch+iPhone citizen read up to ~2× steps/kcal (same hazard class as the PR-109 sleep double-count). New pure `DailyRollup`: the day's figure is the best-covering single source's total, never a cross-source sum (RTM FR-ING-17, RISK RK-ING-10, T-COV-01..04).

**feat(ingestion):** nightly sleeping wrist temperature (`appleSleepingWristTemperature`) read with a named purpose — sleep-context deviation vs the citizen's OWN baseline; night-bucketed by the sleep `nightDay` rule, §2.3-arbitrated per night, deterministic mock coverage with zero RNG-draw impact on existing demo streams (RTM FR-ING-16, T-COV-05..08). Read-authorization set = exactly the set read (T-COV-09).

**docs(audit):** `docs/HealthKit_Coverage_Audit_20260818.md` — every type read verified against reader + consumer; every type not read refused with a reason (cycle tracking, medications, symptoms, gait, ECG explicitly refused pending their own design + risk work). Report-only findings filed: primer "these — and only these" claim untrue since PR-46 (RK-ING-12, owner = onboarding surface); AFib "days observed" line lacks its 30/90-day window; `observedTypes` MVP-only drift recorded as a decision.

**test(flake):** `BackupPostureTests` serialized (`@Suite(.serialized)`) — three tests raced one shared `UserDefaults` key under Swift Testing's default parallelism; zero assertions changed; 5/5 repeat runs green.

Suites: ingestion/arbitration/coverage 22/22 green; full unit run 673 tests / 89 suites — all green except the parallel sleep agent's in-flight red `SleepPathAuditTests` (their incident-reproduction tests, sleep-owned). Guards green: `guard_provenance.sh`, `guard_donation_egress.sh`. Build `build/ddsl2`, Sim F8ACD7F7.

## PR-112 — Donor programme DON-2026-01, app side: a sealed EXPORT the donor performs (2026-08-13, branch `claude/a72-electric-ink`)

**584 tests / 81 suites PASS**; Debug + donor-flag (`-D LIVIQA_DONOR`) builds green; provenance guard green; new blocking donation-egress guard green and mutation-checked.

**CN decision recorded (2026-08-13, verbatim):** *"forget about anonymity. We need to have a cloud version of the data. and a permit to use it for the training."* This resolves OD-D1 **against** the programme document's own v01 recommendation (the corpus is for model training, not verification only) and abandons anonymity as a strategy — the corpus is identifiable special-category data protected by lawful basis, consent, encryption, access control and governance. Recorded as a controller decision with its date; the app side is unaffected by it (the app never trains, never uploads, never holds a corpus).

### What shipped
- **`Liviqa/Donation/`** — programme constants + compile-time donor gate; Encodable-only payload and a pure assembler (four streams, REAL provenance only, device-class source normalisation, whole-week date shift with original UTC offsets carried); `LVDN1` X25519+HKDF+AES-GCM seal with no `open` side in the app; sealed device-local consent + export ledger reusing `WalletGrant`/`WalletEvent`; the export coordinator (assemble → seal → one file → share sheet).
- **`DonorExportView`** + a Settings entry, both behind the compile-time donor flag; every shipped binary has a constant `false`.
- **Conditional copy (§6.3 / OD-D11):** "Your individual readings never leave this phone." is unchanged, verbatim, for every non-donor; an active donation grant swaps it for a sentence that names the exception specifically. Single-sourced in `DonationCopy`, lint-guarded against re-hard-coding.
- **`scripts/guard_donation_egress.sh`** wired BLOCKING into `build-ios.sh` the day it was written.

### What did not change
`T-RSCH-05` and `T-SUND-01` are green and **unweakened** — the export model exists so that no invariant test had to be relaxed to ship this. Nothing about a non-donor's experience, copy or storage changes.

### Not closed here (owner/counsel, §7.3 gates)
DPIA v02, ROPA entry, Scaleway DPA, access agreements and custodian key ceremony (the programme public key is deliberately unset, so an export refuses on screen until it exists), the erasure drill, the repo-lint half of T-DON-03, and **correcting the §2.3 consent text, which currently promises donors the opposite of the training decision**. No donation may be collected until these are satisfied.

## PR-115 — Sleep viz v2 · whole-person Home · goals & calendar field bugs · universal HealthKit · health-summary document (2026-08-19)

Five waves integrated in one pass. **873 tests / 108 suites PASS**; both guards green; build green.

### Field bugs from CN's 10.103 device — both root-caused with red-run proof
- **"Goals and ranges get deleted" — TWO independent mechanisms.** (1) **Locked-launch clobber:** `healthcontext.v1.json` is written `NSFileProtectionComplete` and loaded once in `AppState.init`; the app cold-launches in the BACKGROUND routinely (BGTaskScheduler `.refresh`, HealthKit background delivery) — usually while the phone is locked, when the file EXISTS but reads FAIL. `load()` collapsed unreadable into nil = "never saved", so init kept the empty seed; the next Save wrote that seed over the stored profile (atomic rename ignores the read lock). **This is the same disease as the vault index and the journal note-save — unreadable treated as absent, third occurrence.** Fix: `LoadOutcome{loaded,absent,unreadable}`, a restore-retry on `protectedDataDidBecomeAvailable`/refresh/before-draft, and `saveHealthContext` as the single write path. (2) **Decimal-comma wipe:** the target editor parsed with `Double(String)` ("." only) while the Danish pad offers ONLY "," — and reformatted every keystroke, so typing a separator emptied the field under the cursor. CN literally could not enter a decimal range. Fix: String-backed draft, tolerant parse, no per-keystroke reformat. Found in passing: Sundhed imports merged memory-only (vanished on relaunch); ProfileSheet reseeded its draft on every `onAppear` (wiped unsaved edits); its draft defaulted to `.demo`. 14 tests.
- **"I can't connect calendar" — a silent-denial UX hole, not a missing key.** The usage key IS in the shipped 10.103 archive (verified). On iOS 17+, when calendar TCC is already decided against the app, `requestFullAccessToEvents()` returns denied INSTANTLY with no prompt — and 10.98 already shipped a write-only consult request, so an earlier "Don't Allow" made the 10.103 connect button a silent no-op whose only feedback rendered off the fold. Fix: `ConnectOutcome` with an honest line for every outcome and a Settings deep-link where Settings can actually fix it (`restricted` correctly offers none).

### Directive: every HealthKit data point (FR-ING-19, DHF override recorded)
`UniversalHealthReader` requests the full public type set with an EMPTY share set (read-only stays structural), anchored/deduplicated into its own on-device store; `DataBrowserView` — "Everything you measure" — is the single named consumer, values only, no verdicts. The HealthKit primer's "these and only these" claim is rewritten because it stopped being true. **DPIA note for CN:** the at-rest surface widens from ~21 curated types to the full granted set.

### Sleep visualisation v2 (CN: "build this much better")
One-truth `SleepNight` model where asleep == deep+core+rem BY CONSTRUCTION; in-bed is a separate compiler-enforced type that cannot enter an asleep total; `assertInternalConsistency()`/`assertAgreement()` make the photographed same-screen contradiction unrepresentable. Block hypnogram (four lanes, draw-time merge disclosed, totals exact) supersedes the søkort; D/W/M/6M ranges; week = clock-positioned night columns on a wall-clock-true 22:00→14:00 axis (DST-safe, edge clips disclosed). Awake uses `rust`, never `clinRed`.

### Whole-person Home (CN: "too focused on diabetes data")
Home's fixed diabetic 2×2 is superseded by an availability-driven grid: canonical order, membership by data, no day-to-day shuffle; a CGM-less person sees no glucose card, a gym person sees Activity + Workouts. Day score composes from the domains present with FIXED weights and a SHRINKING denominator ("out of 90"), capped at three parts with the excluded domain named. Activity/Fitness/Body/Vitals get first-class Insights entries. Logged meals mark the glucose curve at their real time.

### Health summary rebuilt as a document (CN: "not made for humans")
**Lab dates were being replaced by the import date** — the parsers captured them; the payload summariser dropped them and the store stamped `Date()`. Now one observation per reading with a real `specimenDate`; undated rows say "date not recorded"; the pull date moved to the header. **Negative screens encoded as `0` are typed at parse** (quantitative/qualitative/artifact) and render as words — with basophils 0.0 pinned as a real measured zero. NPU suffixes, HTML entities and Danish/English names normalised. The export is now an A4 PDF: page 1 is the 90-second clinical read (identity + freshness, major diagnoses, current medicines, latest key values with real dates and personal priors), then ten clinical panels, artifacts appendixed. 59 tests incl. a golden file and a PDF text-layer test.

### Integration applied here
Data-browser entry in Data sources · `UniversalHealthStore.eraseAll()` in the erase path · the passport's share button now presents the PDF document · the sleep sample fixture moved out of the view layer so T-PROV-01 passes (a view file may never construct the provenance field).

## PR-114 — SLEEP INCIDENT RESOLVED: multi-source double-count + daily roll-up double-count + the diagnostics instrument (2026-08-18, branch `claude/a72-electric-ink`)

CN's field report ("my sleep data was brutally wrong") diagnosed with red-run evidence on unmodified post-PR-109 code. **692 tests / 91 suites PASS**; both guards green; Release build green.

- **CONFIRMED: sleep multi-source double-count.** Nightly totals summed per-stage unions ACROSS SOURCES: a real 7.5 h Watch night + one overlapping iPhone/third-party span derived as **11 h 03 m** on Home and the detail screen (12 h 18 m with a second stage-writing app), while union-style consumers computed 8 h 15 m — three contradicting figures on adjacent screens. `SourceArbiter` keyed sleep by (stage, night) so cross-source overlaps never met. Apple Health picks ONE source per night; Liviqa now does too: `SleepNightResolver` (stage detail > larger total > name, deterministic) + main-episode isolation (a >4 h unrecorded gap splits the bucket — **naps no longer merge into the night**, the second confirmed defect). Wired through `arbitrated()` so every consumer incl. the nudge engine gets the resolved stream. RK-SLP-07 states honestly what users saw.
- **CONFIRMED, same class: cumulative daily roll-ups (steps, active energy) double-counted sources** — raw sample queries return every source's samples and `readDaily` summed them all; Watch+iPhone read up to ~2×. Fixed via pure `DailyRollup` (per-(day,source) totals, best-covering single source; documented trade-off: mixed-coverage days now under-count rather than inflate; exact merge is the named upgrade, FR-ING-17).
- **Sound and now pinned:** inBed never counts; DST nights keep real durations; the t+6h bucket holds for shift workers; unrecorded gaps never count as sleep.
- **FR-DIAG-01 — the instrument.** Settings → "Sleep diagnostics · 14-night report": every raw HK sample (source + bundle id + device, stage, start–end, drops marked) against every derived value with the exact computed-from and excluded-with-reason lists. Share-sheet export only (transport constructs lint-banned in Liviqa/Diagnostics/), Release-enabled so CN can run it on TestFlight, blocked in sample mode. RK-DIAG-01 covers the instrument's own leak hazard.
- **Coverage audit** (`docs/HealthKit_Coverage_Audit_20260818.md`): full enumeration with per-type purpose; wrist temperature added (night-bucketed, arbitration-equal, mock coverage, consumer named) — types without a named consumer refused. `BackupPostureTests` serialized (shared-defaults flake).
- **Follow-ups recorded:** untimed aggregated sleep undercounts in the union-style consumers (imported sleep only); a "second sleep source excluded" disclosure line on the Sleep detail (FR-PROV-02 style).

## PR-113 — Sample mode done right, calendar load as a real signal, Screen Time feasibility (2026-08-18, branch `claude/a72-electric-ink`)

CN directives 2026-08-13 (sample demo option, clearly labelled · onboarding expectation copy · calendar/screen-time signals). **652 tests / 86 suites PASS, run twice back-to-back** (hang-free); build green; both guards green.

### Sample mode (FR-SMP-*) — the incident's root cause fixed conceptually
`isDemoData` (= "no real readings yet") was the licence every fabricated stand-in asked. Now: `hasNoRealReadings` is an empty-state condition that licenses NOTHING; `isSampleMode` is the citizen's explicit request and the only authorisation (pure `SampleModePolicy`, test-pinned). **Four more hardcoded fabrications found on Home and REMOVED** (seeded day-score ring, canned momentum, canned 30-day recovery line, and a hand-written causal claim — "Late dinners are costing you sleep." — that had never passed NudgeGuard). Sample sessions run the REAL engine + derivers over a fully synthetic `SampleDataset` (goldmine's shape, none of its values; deliberate silences on AFib/BP/insulin/labs where invention would read clinical). Labelling is unremovable app CHROME ("SAMPLE DATA · Made-up numbers. Not your readings." + exit) — `liviqaShowDemoChip` deleted with a lint against its return. Contamination structurally impossible (ingest path not entered; enter/exit snapshot-restores 17 fields; erase clears the flag). Two false "explore with sample data" promises corrected. Onboarding gains the who-it's-for + expectation timeline sub-page, numbers checked against code.
- **Combined-run flake resolved as world (a)**: the contamination test counted rows in the SHARED on-disk store while parallel suites persisted/wiped it — test isolated (per-test defaults + in-memory container + mock seam), feature proven sound; the hanging test no longer awaits a live HealthKit path.

### Calendar load (FR-CTX-CAL-01…04) — density, never content
EventKit read keeps FIVE numbers per day (events, booked hours, longest back-to-back, meeting-free waking hours, span); titles/attendees/locations/notes have NO representation in the path — mutation-verified lint (inserting `_ = event.title` fails two tests). Opt-in ∧ full-access, account-scoped store, disconnect deletes the numbers, erase wipes them (RK-CAL-05 closed). Week-grid CALENDAR row is real (|z| vs own usual, `.noData` never zero); deliberately CANNOT vote in cluster-day/verdict — the app never implies a busy day moved a reading. Plist promise test-pinned to code; five stale translations of a now-false write-only string removed (accurate English over inaccurate Danish; re-translation flagged). Screen Time: not buildable as asked (sandboxed report extension) — feasibility doc written incl. the threshold-bit path; false "Connect Screen Time" affordance deleted.

## PR-111 — INCIDENT: fabricated journal entries and cross-account journal exposure (2026-08-13, branch `claude/a72-electric-ink`)

**Reported by internal TestFlight testers**, who sent screenshots of journal entries containing glucose values (6.2 and 7.1 mmol/L) on accounts they had just created. **536 tests / 77 suites PASS**; build green; provenance guard green.

### What it was
The three entries are `JournalView.demoSeed` **verbatim** — the app's own hardcoded placeholder text, not any person's readings. No citizen data was exposed and nothing left any device (the journal has no upload path). The entries were dated **10 June**: a build from before the July launch-audit gate wrote them into `journal.v1.json`, and every update since read the file back. The `#if DEBUG` gate stopped new seeding; nothing ever removed what was already on disk.

### The more serious finding, same file
`journal.v1.json` was **device-scoped, not account-scoped**, and `signOut()` deleted nothing — it cleared an in-memory array that nothing ever loaded into, while `JournalView` held its own `@State` read straight from disk. **Any new account on a used device opened the previous person's journal.** Today's contents were our seeds; on a device where someone had written real entries, it would have been theirs.

### A third defect, found while fixing the first two
`DataSourcesView`'s "add a note" inserted into `AppState.journalEntries` (the list nothing loads) and then called `JournalStore.save()` on it — **overwriting the entire journal file with that single note**. Silent, complete loss of the citizen's own writing. Fixed: load → prepend → save, into the scope it loaded from.

### Fixes
- **Account-scoped journal:** `<AppSupport>/journal/<sha256(accountID)>/journal.v1.json`, following `EncryptedAnchorStore`'s hashing discipline but scoped by the signed-in ACCOUNT (the exposure was between accounts on one device). No unscoped path exists any more. Sign-out now leaves nothing addressable while deleting nothing.
- **Legacy adoption, not deletion:** the old file is migrated into the opening account's scope only when that account has no journal, only after the entries are written AND read back at the new path, never over an existing journal, and never when the entries name a different author. **Residual risk stated plainly:** pre-10.101 files carry no author and local entries have `userId == nil`, so if the first account to open after the update is not the author, that account adopts them — once, after which the exposure is closed permanently (today every account sees them, every time). Deleting unattributed files would guarantee no adoption but would destroy real writing to defend against a case we cannot detect, which the non-destructive rule forbids. Operational control: testers who shared a device should erase and re-import rather than trust an adopted journal.
- **Seed purge:** exact whole-body match against our own three strings only — a citizen who wrote about a 6.2 fasting glucose in their own words keeps their entry (tested: prefixes, seed-plus-own-sentence, and own-words variants are all preserved). Nothing is logged.
- **Seed can no longer reach Release by any path:** `JournalSeedPostureTests` asserts the bodies are constructed only inside `#if DEBUG` anywhere in `Liviqa/`, that the denylist matches the seed verbatim (editing the seed without the denylist fails the build), that the store never constructs an entry, and that `save` filters seeds and the bytes on disk agree.
- **Name resolution** (`DisplayNameResolution.swift`, pure): the declared onboarding name wins; a backend `displayName` equal to the local-part of the account's own email is treated as a placeholder, not a name; an address is never rendered as a person's name; no name known → greet without one. `setDisplayName` refuses addresses.
- **Settings tells the truth:** the hardcoded "Apple Health — Connected", "Health Vault — 3 files" and "Sundhedsplatformen — Not connected" literals are replaced by real state, read through the SAME call the destination screen makes so the counts cannot disagree; unknown states say so rather than defaulting to reassurance. `SettingsTruthTests` fails if a status literal returns.
- RISK: RK-JRNL-XACCT-01, RK-JRNL-FABRIC-01, RK-ACC-NAME-01. RTM: FR-JRNL-SCOPE-01, FR-JRNL-SEED-01, FR-ACC-NAME-01, FR-JRNL-PERSIST-01 amended.

### Deferred, recorded
The journal file is still plaintext JSON under `NSFileProtectionComplete` rather than CryptoBox-sealed like the vault — scoping was the incident; encryption is a separate, riskier change (key availability on unsigned builds). The path hash is a namespace, not a secret.

## PR-110 — Design-QA fixes: scroll edge (really), accessibility chrome, HRV single-source, heart weight (2026-08-13 overnight, branch `claude/a72-electric-ink`)

Driven by a 91-frame sweep in both themes plus large-text frames (`20_Build/a72_designqa_20260813/`). **485 tests / 73 suites PASS** (was 463/70). Build green, provenance guard green.

### The scroll-edge fix in PR-109 did not work — two stacked bugs, now fixed AND verified on device
PR-109's `liviqaScrollEdge()` was merged believing it worked; the sweep proved it did not (content at full opacity under the Dynamic Island in all six scrolled frames). Root causes, both reproduced on device before changing anything:
1. **The band resolved to 14 pt.** It sized itself from `proxy.safeAreaInsets.top` inside a `GeometryReader` carrying `.ignoresSafeArea(edges: .top)` — ignoring an edge CONSUMES that inset for the subtree, so the proxy read 0 and the band rendered 0 + 14 pt: present, measurable, invisible.
2. **`.overlay` lays out inside its host's safe area** even when the host's content does not — so the first corrected attempt drew a correct band *below* the clock while cards kept printing above it. (Caught in an intermediate frame before it could be reported as fixed.)
Fix: the band ignores the top safe area to reach the Island strip, and takes its height from the WINDOW's inset (`LiviqaWindowInsets.top`) because the ignore has just zeroed every proxy reading. Opaque across the inset, then eased out; mirrored bottom band replaces the hard cut at the tab bar. Verified in both themes with before/after captures; scroll offset unchanged, so the `LIVIQA_SCROLL_TO=bottom` hook still lands identically. Extended in integration to Care, Journal, Privacy and Settings.

### `.dynamicTypeSize` clamps in this codebase are INERT (worth knowing before relying on one again)
The tab bar carried `.dynamicTypeSize(...xLarge)` and it did nothing: every Liviqa font resolves through `UIFontMetrics.scaledFont(for:)`, which reads the SYSTEM content-size category and never sees SwiftUI's environment clamp. So at accessibility sizes icons grew ~19→37 pt, six labels collided with no gutter, "Settings" truncated, and the taller bar sliced content that reserved a hard-coded 96 pt. Fixed by measuring the live `UIFontMetrics` scale and dividing it back out above a 1.25× cap (the intent that was always declared), a real gutter, two-line/scaling labels that never truncate a destination name, and a measured `contentBottomInset` replacing the fixed 96. Chart y-axis columns now size to their widest real label ("100 %" was rendering as "1…"). New row NFR-A11Y-03; NFR-UI-EDGE-01 rewritten to name both failure modes so this cannot regress silently. **One more inert clamp is documented and deliberately left**: `TodayView` Home signal cards carry the same ineffective clamp, but the sweep flagged no defect there and layout was not changed without evidence.

### Two screens disagreed about the same HRV week (correctness)
Recovery/Insights plotted Friday as the week's high; the HRV Learn page called Friday the low. Cause: `applyLV001DatasetIfNeeded()` replaces `todaySignals` with the LV001 composed aggregates AFTER derivation but leaves `hrvLearn` on the original stream — one week-shaped fact with two sources. **Real sessions were never affected** (both paths derive the same seven numbers from the same samples); it is a demo-dataset artefact, but it was visible and contradictory. `TodaySignals.hrvWeek` is now the single canonical week: the Learn detail re-anchors its series, ticks, low value, low day and dip/recovery flags onto it (the 60-day range/median keep naming their own window in copy), and the assistant's "dipped on <day>" template reads the reconciled object. Pinned by `namedExtremeMatchesTheCanonicalWeek` plus a negative control asserting the *un*-reconciled detail names a different day, so the fixture cannot go stale and start proving nothing.

### Heart hero no longer borrows alarm weight
A full-bleed crimson/pink hero carried the reassuring verdict "Resting lower than your usual band" — the app's heaviest red-family surface attached to a calm message, with the two themes differing sharply in chroma. `accentHeart` is UNCHANGED (CN-approved). What changed is treatment: a new hero weight where the full plate is reserved for verdicts that actually warrant attention and calm verdicts get a quiet tinted plate; because the quiet plate is alpha over each theme's own card, paper and midnight now carry equal weight. Pinned by `weightAndVerdictNeverDisagree`.

### Copy and theme consistency
- **"Sample data" no longer appears mid-sentence** ("Kept Sample data for counting" — the previous night's chip fix applied in a prose slot). A demo seed is never *named* as a device: the sentence omits it and the demo label moves to a header chip where a label belongs. New test T-DED-06 locks the rule; every prose interpolation of a source/recipient name in those files was swept.
- **Midnight primary buttons read as disabled** (2.46:1 — "Share now", "Add to my DfG wallet" vs a cream sibling "Done"). Unified at token level with no new palette value (light = moss's light, dark = invertBG's dark): **14.64:1**, with disabled states still unmistakably quieter (10.1:1 separation from the live fill).
- Heatmap "worth noticing" swatch no longer shifts severity between themes (bright yellow → the same orange as morning, lifted for the marine ground; still capped short of red).
- Glucose peak annotation moved out of the zone key's corner into a padded caption ("Highest today 11.2 mmol/L at 13:40"); Vitals verdict gutter, Sleep annotation clipping, Journal/Care trailing insets, Activity double negative, and the declined screen's wrong step counter all fixed.

**Deferred, recorded:** Reduce Transparency branch is code-verified only (`simctl` will not set it headlessly — needs one manual device check); the Glucose TIR key row still ends at the viewport edge and wants trailing content padding.

## PR-109 — Day-axis integrity, real sleep/HR ingestion, scroll edge, consult stage (2026-08-13 overnight, branch `claude/a72-electric-ink`)

**463 tests / 70 suites PASS** (was 418/62). Build green, Release build green (warnings 36 → 2), provenance guard green.

### Charts could show a value against the WRONG DAY (RK-CHART-01)
Series like `TrendsRange.tirDaily` and `TodaySignals.inRangeWeek` are COMPACTED — one entry per day that has data — and carried no dates, while the axis labels were computed separately. Three live mis-labellings were confirmed in code before anything was changed:
- `WeekInContextView` passed a 3-value series with a 7-letter tick row: three values read under seven day letters.
- `TrendsView` drew a 90-day quarter as N adjacent bars spanning the full width, with a hardcoded "TODAY" end label that was false whenever the last reading was not today.
- `TodayView.recoveryTrend` labelled the month card with fixed −29/−15/0 day offsets over a compacted series.
**Fix:** new `DaySeries`/`DaySlot` primitive (pure Foundation) that places each value on its own date and **refuses to guess** — a dateless series is only placed when it covers the window 1:1, else the caller drops the day labels. Dates now flow through `TrendsRange` (`tirDailyDates`, `hrvDailyDates`, `windowStart/End`) and `TodaySignals` (four date arrays + `slots(for:over:)`). `AreaTrendChart`, `MonthTrendLine`, `TIRTrendBarChart` and `DailyBarsChart` take an optional day axis: one column per day, the curve BREAKS at a gap, and a missing day draws **nothing** — never a zero (which would assert 0% in range) and never a shifted neighbour. `MetricDetailView` (same defect, fixed in integration) now derives its day letters from the slot dates instead of a fixed M–S row, and bar emphasis follows the last day that actually has a reading. Scope: presentation-integrity only — the nudge engine and the correlation evidence gate always worked from dated samples, so no decision logic was affected. New rows NFR-VIZ-DAY-01, NFR-UI-EDGE-01; 14 new alignment tests, negative-control verified (restoring index alignment failed 5 of them).
- **Marked-day neutrality now shipped** on the TIR bars (the FR-CTX-04 clause that previously read "NOT shipped — bar↔date alignment is not derivable").

### Two real sleep-data bugs fixed by the ingestion work
Ingesting intra-night segment times surfaced them: **a night spanning midnight was split into two half-nights**, and **a fragmented night's union collapsed to its longest fragment** (every segment shared one instant), understating sleep. Nights are now bucketed by start-of-day of *t*+6 h and the union runs on real starts.
- **T-FIT-01 closed:** heart rate inside each workout interval is ingested, arbitrated and consumed, so Fitness average-HR and Z1–Z4 time-in-zone light up on real data (zone edges are fractions of the citizen's OWN observed max, printed as such — "not a population scale, and not a target"), and stay honestly absent without beats.
- Sleep depth chart, wake-up moment, AWAKE tile and bedtime card now render from the citizen's own night; bedtime compares only to their own mean, needs ≥3 timed nights, and states there is no recommended hour.
- **Inferred-denial cue:** on a completed read with zero samples across every type, the honest declined screen appears. HealthKit's `authorizationStatus` answers for writing only, so denial and "granted but empty" genuinely cannot be told apart from inside the app — the copy says so and never accuses the system of denying access.
- Demo consistency: LV001 GMI 6.8% → 6.1% anchored to its own glucose seed, and each sparkline's last point now equals its chip.

### Other
- **Scroll edge:** `liviqaScrollEdgeSoft()` was a no-op below iOS 26 / with the glass flag off — which is why the sweep saw content under the Dynamic Island. New `liviqaScrollEdge()` fades from the paper token, sized from the real safe-area inset, firmer under Reduce Transparency; an overlay with hit-testing off, so content size, offsets and the snapshot hook are untouched.
- **Consult stage placeholder:** the black rectangle is replaced by a derived stage (`CallStageDeriver`): initials, name · organisation, an honest status line, self-tile caption and a retry affordance. `.live` renders nothing extra — when media is up, Liviqa claims nothing.
- **Consent-surface explicitness:** `createGrantAndShare` now passes `ShareGranularity.summariesOnly(for: scopeGroups)` instead of `nil`. The wire body is unchanged, but summaries-only is now stated AT the consent surface rather than inherited from a backend client default two layers down; `ConsultShareTests` asserts the explicit map.
- **RTM hygiene:** FR-SET-02 corrected to `implemented` (backup posture has been `@AppStorage` since the onboarding work); FR-PAT-02 stays `planned` but its evidence was understated and is now accurate.
- **Known residual:** `MiniSparkline` and the Home signal chips still draw compacted series — they carry no day labels and make no per-day claim, so nothing can be misread onto a date (recorded in RISK). `WeekInContextView.weeklyCard` computes its delta as last − first available day, which is a coarse statistic on a gappy week — flagged for a copy/derivation review, not changed.

## PR-108 — Bevel absorb build + vault data-loss fixes + test-debt closure (2026-08-13 overnight, branch `claude/a72-electric-ink`)

CN approved the Bevel absorbs 2026-08-13 (which also cleared FR-REC-03's doc-first gate). Built overnight while CN slept; every decision reserved for CN was left untouched and written up instead. **418 tests / 62 suites PASS** (was 282/51); build green; provenance guard green.

### Two data-loss defects found and fixed in the shipped vault (headline)
Sent to explain why the sweep saw the vault's failure state, the investigation instead found defects reachable on real devices — both present in build 10.99:
- **Silent destruction of the document index.** `add()`/`delete()` loaded the encrypted metadata index with `try?` and then saved: a key that could not open the index would start a FRESH one and write it over the old — erasing the only record of the citizen's stored documents. Triggerable on any transient key-read failure (e.g. before first unlock).
- **Vault relocation.** `LocalUserScope.current()` re-minted an ephemeral UUID per call whenever the Keychain was unusable, so the storage folder moved each launch and documents disappeared from view.
- **Root cause of the observed symptom** was NOT the Secure Enclave: unsigned QA builds carry no entitlements, so every Keychain call returns `errSecMissingEntitlement (-34018)`. The designed fallback keyed on `SecureEnclave.isAvailable` (true even on simulator, where enclave ops genuinely succeed), so it could never fire — the failure was key STORAGE, not key TYPE.
- **Fix:** key type (enclave → software P-256) separated from key storage (Keychain → file-based `DeviceKeyFileStore`, atomic, `NSFileProtectionComplete`, backup-excluded, hashed names), chosen once per provisioning so device key and wrapped DEK can never come from different stores. **Never re-keys**; refuses to write over an unreadable index. Four honest access states (`ready` / `lockedUntilDeviceUnlock` / `keyUnavailable` / `sealedDataUnreadable`) — the "unreadable" message now appears ONLY when sealed data genuinely cannot be opened, and the UI's encryption sentence follows `KeyVault.protection` exactly (no key claim at all before provisioning). RISK: **RK-VAULT-02**.
- **Deliberate dead end, for CN:** `sealedDataUnreadable` cannot add documents, because auto-re-keying would destroy data. Recommend an explicit, consented "start a new encrypted space" action behind a two-step confirm — NOT built (destructive; needs CN's design call + a QMS row).

### App-switcher privacy leak (found by writing T-SEC-07)
The lock engaged on `.background` only, so the snapshot iOS takes on `.inactive` could contain the citizen's readings in the app switcher. Added `AppPrivacyCover` on `.inactive` — a cover, never a prompt, so a system alert or share sheet costs no Face ID round-trip; the real lock still runs on background→active. Pinned by `inactiveCoversTheAppSwitcherSnapshotWithoutPrompting`.

### Bevel absorbs (CN-approved top-5)
- **③ FR-CTX-04 context status flag** — travelling / unwell / off-routine, stored on device, wiped by erase. `NudgeEngine` gate suppresses baseline-deviation streams while marked; **tests prove the marked-day output is a strict SUBSET of the unmarked output**, so the flag can never create or escalate a nudge. AFib route-to-clinician and the resting-HR number deliberately survive suppression. Today shows an honest "calibrating around your trip" register instead of a second card; marked days render NEUTRAL (flat slate + hatch) in the week grid and are excluded from the cluster-day pick. 13 tests (T-CTX-04). RISK: RK-CTX-01.
- **④ FR-REC-03 any-lab import** — PDFKit text layer first, Vision OCR fallback, conservative analyte allow-list with explicit refusal (never guesses), unit normalisation to canonical units, review-before-save, and framing against the citizen's OWN prior value — never a population reference range (that would be a `clinicalNormality` violation). 20 tests.
- **② FR-XPL-01 universal see-why + method notes** — `SeeWhyHeroRow`/`seeWhySheet` across the metric screens with the decomposition in the user's own terms; published method notes in the Learn tier; the HRV learn entry points Area ⑨ could not reach are now wired.
- **⑤ FR-NOT-02 micro-loops** — content stays allow-listed and built on device.
- **① FR-WID-01** — source + `LiviqaWidgets/SETUP.md` prepared; `project.pbxproj` untouched per repo rule, so the two Widget-Extension targets remain a short Xcode-GUI task for CN.

### Test debt closed (49 new tests, every assertion mutation-checked)
`SundhedSinkTests` (T-SUND-01, 8) · `HealthRecordStoreTests` (T-REC-01/02, 12) · `ResearchContributionTests` (T-RSCH-05, 8) · `AppLockTests` (T-SEC-07, 12) · `ConsultShareTests` (T-PRO-01, 9) + shared `SourceLint` helpers that skip comments (the Sundhed files *document* the removed upload path — a naive grep would match its own history). The source was broken five ways to confirm each test fails, then reverted byte-exact. **All five guarantees held.** Two fragilities surfaced and are now guarded: `ensureCoveringGrant` is dead code one `await` from restoring automatic upload; the consult share's summaries-only granularity comes from a `??` default two layers below the consent surface (holds on the wire, asserted via a `URLProtocol` stub, but the consent surface should state it explicitly).
- **Release chain hardened:** `scripts/archive_upload.sh` did not run `guard_provenance.sh` — the release path was weaker than the dev path. Added as a blocking pre-archive step; verified that `archive_upload_isolated.sh` (the real headless path) delegates to it, so the shipping chain is now covered.
- `qms/VnV.md` updated; the stale "gaps to author" list is superseded.
## RELEASE build 10.99 — A7.2 full-screen app to TestFlight (2026-08-13, develop `6255b06` + version bump; CN directive "ship 10.99")

First TestFlight build carrying the complete A7.2 designed application (PR-105 reskin + PR-106 Home/Insights anatomy + PR-107 waves 1–4, all nine areas). Supersedes 10.70 as the newest internal build; the 10.71–10.98 wave never reached TestFlight.

- **Content:** 74 designed screens — onboarding flow (11 frames + declined/lock/MitID/identity), Home day + evening editions, Insights + Trends (evidence-gated correlations), 8 metric details incl. the clinical glucose surface, care lane, consent/sharing core, encrypted document vault, settings/notifications/voice journal, Learn tier + 4 assistant behaviours, watch deltas.
- **Pre-flight gates (all green):** provenance guard T-PROV-01 ✓; **Release-configuration compile ✓** (DEBUG hook families verified compiled out); unit bundle 282 tests / 51 suites ✓ (Debug, develop `6255b06`); designated controls re-verified in-suite (FR-NDG-06 NudgeGuard, ProvenanceGuard, terminology/advice-voice lint, ReleasePosture incl. provider-forcing and demo-seed gating); watch scheme ✓; 58-frame on-device sweep ✓.
- **Posture:** signing = Fonden Data For Good PS258XSNL8, bundle `dev.liviqa.app` (ASC app 6776228205), export `app-store-connect`/automatic; the exported .ipa is additionally gated by `scripts/guard_release_posture.sh` (get-task-allow=false, Apple Distribution cert, beta-reports-active) — a failure ABORTS the upload.
- **Distribution scope:** **INTERNAL TestFlight only.** Promotion to the external group "Liviqa beta tester" remains blocked pending the standing gates — DPIA v02 signed (RK-SUND-01 covers the shipped in-app sundhed flows + diagnoses + external cohort), written Trifork/sundhed.dk sanction artifact (or `sundhedWebConnectEnabled` gated off for external builds), and the ClickUp decisions task z8nrz7c35v (self-signup lock).
- **Known-state notes carried into this build:** notification channels beyond morning/evening are preference-only and labelled so; PMS reports queue on-device (no backend endpoint); watch complication absent (no Widget-Extension target); SRS v06 rows remain `[PROV]` pending CN ratification.

## PR-107 build wave 4 — Areas ⑦ Integrations/vault, ⑧ Settings/journal/watch, ⑨ Knowledge/AI (2026-08-13 early, branch `claude/a72-electric-ink`)

Final code wave — all nine areas now built. Combined iOS build green; **watch scheme green; 282 tests / 51 suites PASS** (all agent-authored suites executed in-simulator).

- **feat(vault) — FR-ING-15 implemented.** Real encrypted document store (`HealthVaultStore`): random 256-bit DEK, ECIES-wrapped by a Secure-Enclave-resident P-256 key (HKDF-SHA256 → AES-GCM), every document AND the metadata index sealed at rest, hashed on-disk names, atomic writes, no upload path; software fallback recorded in `isHardwareBacked` and UI claims follow it. Tests prove ciphertext-at-rest, delete-really-deletes, tamper-fails-loud. Vault wiped on GDPR erase — with ⑧'s real "keep my documents" branch. HealthVaultView + DataSourcesView rebuilt (manual entry mmol/L, honest Sundhedsplatformen gate, vault import). RISK: RK-VAULT-01 removed hazard (claims now true). **Known issue:** headless-simulator app launch renders the honest could-not-open state (keychain context) — crypto proven by in-sim tests; track for device verification.
- **feat(settings/notifications) — FR-NOT-01.** Edition-ladder rebuild: morning + evening notes REALLY scheduled (local, silent, allow-listed static text, guard-tested, deep-link Home); earned-attention + care toggles honestly preference-only until their channels exist (status line says so); study & consent activity default OFF and genuinely gating. AccountSecurityView (new), DeleteDataView (new — 30-day retention figure REMOVED as unverifiable against the erase route; open compliance item), profile persistence fixed (edits survived relaunch for the first time), regulatory copy single-sourced. Info.plist mic string corrected (old consultation-only claim would have become false).
- **feat(journal) — FR-JRN-04.** On-device voice capture: AVAudioEngine + SFSpeech with `requiresOnDeviceRecognition = true` (designated assertion T-JRN-04); audio in protected journal storage; honest audio-only fallback when on-device recognition is unavailable.
- **feat(learn/ai) — FR-LIT-01 consumers live.** Reusable two-tier LearnArticle (HRV plain/clinical over the real 60-day deriver, window honestly labelled); four assistant behaviours as REAL intent routing (explain-a-drop from own week, literacy-aware plain language, honest calibration answer, redirect presentation around the VERBATIM safety line — designated control untouched). Guard STRENGTHENED (titration/basal/bolus/prescription vocabulary gap closed, pinned both ways). Seven-item counsel-memo divergence list recorded (canvas claims the app cannot honestly make).
- **Watch/FR-WID-01:** glance + pillar detail deltas shipped; complication BLOCKED on a missing Widget-Extension target (pbxproj surgery out of bounds) — 4-step Xcode recipe recorded in RTM, row stays planned.
- **Cross-area:** ⑧ fixed ⑨'s ChatView ViewBuilder-local-funcs build breaker; ⑦'s erase seam consumed by ⑧'s keep-documents branch as designed.

## PR-107 build wave 3 — Areas ⑤ Care & PRO & ⑥ Sharing/consent (2026-08-12 night, branch `claude/a72-electric-ink`)

Third code wave — the consent core. Combined build green; **238 tests / 46 suites PASS** (one posture-test update in integration: the proof sheet's DEBUG demo grants were REMOVED in favour of a real-grant mirror, so `privacyDemoGrantsAreDebugGated` became the stronger `privacyProofSheetHasNoDemoGrants` — no demo seeds there, even DEBUG-gated).

- **feat(care) — Area ⑤ (b-care.jsx).** Care tab rebuilt (live-consult hero, inline thread cards, verbatim urgency footer); thread view gains org/role subtitle, date dividers, genuine read receipts (existing `readAt` — no new storage); plan-consult verdict header + fallback-phone card; pre-visit "ready" only inside the real join window; waiting room re-anatomied; incoming call reskin (consent line strictly strengthened); ConsultView → full-bleed call stage. **Honesty fixes:** "clinician has been notified" removed (the app only polls); the unprompted recording-Allow removed (consent affordance only against a real request); "add to calendar" phrased as the user action it is.
- **feat(pro) — FR-PRO-01 [PROV].** The pre-visit share tick now ARMS a real per-consult grant (24 h expiry, summaries-only, purpose `consultation`) + derived payload via `createGrantAndShare`; un-tick revokes (new `POST /grants/{id}/revoke` client route). Console-side PRO contract documented (render-only payload; EVERY PRO view must write a citizen-ledger event — event kind does not exist yet; threads `lastMessagePreview`). RISK: RK-CONSULT-SHARE-01.
- **feat(consent) — Area ⑥ (b-sharing.jsx), claim-gating by construction.** `CEEvidence.isEvidentiary` (receipt id AND event hash — CE stub attaches neither, so a stub id alone can never unlock claims, TESTED): stub mode says "kept in your consent record…designed so nobody can edit it", real evidence unlocks "signed so nobody can change it" + proof number + brass evidence block (FR-WAL-09 implemented; RK-WAL-09). **StudyConsentView data-category toggles flipped to default OFF, join disabled until ≥1 on** (FR-RSCH-07; RK-RSCH-07 — consent-safety default). Receipt slip rebuilt; wallet register purge + Stop vocabulary; UC-11 CreateGrantView; Research hub (FR-RSCH-06, honest empty states, k≥5 floor clamp in the grouping phrase); token wallet donate-first over real ledger sums with the consent-record claim WITHHELD until token events actually log (FR-DFG-07 partial); proof sheet mirrors real grants.
- **Divergences (all toward honesty, documented in RISK):** "Every reading" mode NOT built (RK-SHARE-03 — awaiting CN ruling); documents row SOON/disabled (FR-ING-15 open); "Until I stop it" → 12-month confirmed grants (no open-ended backend expiry exists); share scopes default all-OFF; hub no-op "Keep" → "See your wallet".
- **Colour ruling (recorded):** the wallet "Stop" action renders in the established `rust` boundary/system token (same family as the degraded-store banner) — an action affordance, NOT a health signal; clinical `clinRed` remains glucose-charts-only. Flag for CN if a quieter treatment is preferred.
- **Verification:** dd5/dd6 agent builds green; combined dd build green; 238/46 unit pass incl. new `ConsentSurfaceTests` (T-RSCH-07 defaults-off, T-WAL-09 stub-vs-evidentiary gating, k-phrase floor); screenshot QA: Care tab + wallet + share form.

## PR-107 build wave 2 — Areas ② Today/Insights remainder & ④ Metric details (2026-08-12 night, branch `claude/a72-electric-ink`)

Second code wave. Combined build green; **full unit bundle 226 tests / 45 suites PASS** (one lint failure found and fixed in integration: `TerminologyTests.noAdviceVoiceInCitizenCopy` caught wave-1 Face ID copy "only you should open it" → reworded — the guard net works on agent-written copy).

- **feat(trends) — FR-TOD-06 (Area ②).** `TrendsDeriver` (week/month/quarter TIR series + personal usual band mean±1σ; correlations behind a real evidence gate — |r|≥0.4 AND p≤0.05 AND N≥10 paired days, STRONG only at |r|≥0.6; aggregate tiles vs the previous equal window; InsightCompare; 30-day HRV closing FR-TOD-05's deriver gap). `TrendsView` v03: ALL canned demo copy deleted; N·r·p chips always visible (FR-XPL-01); "Derived on this device from N days" footer; honest empty/still-learning states. Wired from momentum "See the trend →" + `LIVIQA_OPEN_TRENDS` hook.
- **feat(pms) — UC-19/FR-PMS-01 (Area ②).** Report-a-nudge intake from NudgeDetailView: 5-reason picker + note; `PMSReport` payload summary-only BY CONSTRUCTION (no field can carry a reading); file-protected on-device outbox, wiped by GDPR erase; **queue-only with honest copy** — the backend exposes no PMS endpoint yet (verified); consent-ledger-style receipt; urgent-care footer. RISK: RK-PMS-01.
- **feat(today/insights polish) (Area ②).** Calibrating state to canvas ("Sample data" chip, skeleton tiles); full-form greeting; InsightCompare card; signal sparklines now carry the real mean±1σ band; DayTimelineView rebuilt editorial (verdict band, scrub chart + moment card; `DayReplayDeriver`); WeekInContext disclaimer aligned, WEATHER row (permanent noData) hidden, rust down-delta → ink.
- **feat(metrics) — Area ④, seven screens on the glucose pattern.** Per-domain derivers + views: Sleep (transparent Rest/Depth/Rhythm score ≥4-night gated; stage bars; søkort/bedtime demo-only — intra-night times not ingested, verified), Heart (RHR vs own 91-day band; BP dot-range from real correlation samples; **AFib lane display-only by construction** — type carries no trend/band fields, routes to clinician share; rose, no red), Fitness (published load formula, 4-week blocks vs own usual, VO₂max long trend; avg-HR/zones honest-absent until HR-in-interval ingestion — deriver ready+tested), Activity (steps/kcal vs own prior-3-weeks), Body (long trends + derived milestones, window-honest kickers), Vitals (DotBandStrip vs own mean±σ, "Typical" verdicts, never clinical ranges — FR-VIT-01 implemented), Baselines re-anatomy over real `BaselineDeriver`. New pillars fitness/activity/body/vitals; passport "Your data, in depth" entries.
- **Guard catches this wave:** design package's own VO₂max copy ("up 2.1 mL/kg·min") trips the FR-NDG-06 dose rule — unit moved to the chart axis; 95 fixed templates verified through NudgeGuard; mock provider's raw name "Mock" surfaced as a device label → mapped to "Sample data" at all three render sites (integration fix).
- **Verification:** builds dd2/dd4 green per agent + combined dd green; 226/45 unit pass incl. new TrendsDeriver/DayReplay/PMSOutbox/SleepDetail/HeartDetail/FitnessActivity/BodyVitalsBaseline suites; screenshot QA: Trends, sleep, heart, fitness vs canvases.
- **Open (tracked in RTM):** weather context line = opt-in/UX decision only (OpenMeteo provider exists, zero call sites); calibrating day-counter kept honest-absent; evening auto-palette decision; HR-in-interval ingestion (T-FIT-01); persisted long-history for body/VO₂max; research-invitation duplication (card + footer line) flagged for design ruling.

## PR-107 build wave 1 — Areas ① Onboarding & ③ Glucose (2026-08-12 night, branch `claude/a72-electric-ink`)

First code wave of the A7.2 full-screen program (census v01 → SRS v06 diff proposal → this build). Both areas built by supervised agents, integrated and verified by the session: combined build green; **full suite green (exit 0)**; designated controls re-run explicitly — `NudgeGuardTests` (FR-NDG-06 blocking), `ProvenanceGuardTests`, `GlucoseDetailDeriverTests`: 17/17 pass; screenshot QA vs canvases (16 onboarding frames + glucose detail).

- **feat(onboarding) — Area ①, the designed flow (f-onboarding.jsx).** New `Liviqa/Views/Onboarding/`: flow machine + shared chrome (9-segment progress, back chevron, n/9 counter, ambient accent glow), Canvas dawn-fjord cover + Ready finale (stroke-drawn iris, Reduce-Motion static), Why-Liviqa, governance sub-pager + "What's kept, anonymously" data-minimisation card, name capture (device-local `displayName` overlay), passport step over real `healthContext` → ProfileSheet editors, sharing explainer, backup posture persisted (`BackupPreference`; sovereign = visible non-selectable "Coming soon"), literacy step (`literacyLevel` plain|both|clinical, default both — consumers land with FR-LIT-01), how-Liviqa-learns. `AuthView`/`HealthKitPrimerView` restyled IN PLACE — every real GoTrue/HealthKit state kept. Satellites: HealthKit-declined honest screen, Face ID app lock (`.deviceOwnerAuthentication`, fails open, Settings toggle, NSFaceIDUsageDescription), MitID calm prompt fronting the Sundhed session, study-enrollment IdentityVerify (ID_METHODS seed, dfg_mpc preferred, UI-only stub, decline always available). PrivacyDeclarationView remains the first gate (FR-REG-01).
- **Honesty/posture decisions (Area ①):** "Try it without an account" is DEBUG-only until FR-ARCH-06 ships an honest Release sample-data mode; no fabricated greeting names (primer greets by name only when one exists); wallet sim flows stay behind Config flags under a disclosure.
- **feat(glucose) — Area ③, the clinical screen (screen-glucose.jsx).** New `GlucoseDetailDeriver` (pure Foundation: week/prev-week TIR, 5-band distribution, avg, GMI gated on ≥14 distinct days, per-day spans, timed today-points, peak/runs/back-in-range, dominant source) + `GlucoseDetailView` (teal hero, TIR proportion bar + plain-language sentence, day curve with true wall-clock x, week range bars, week-over-week compare, share CTA → existing consent flow, honest empty state). `GlucoseCurveView` extended default-off (`hours`, `redOutOfRange`, `targetLabel`, `peakLabel`). **NEW token `clinRed`** documented as glucose-clinical-charts-only (RK-ALARM-01) — red re-strokes out-of-range curve segments inside the flag-gated clinical charts and exists nowhere else. **Insulin dots resolved toward the QMS:** `InsulinReading` stays data-layer-only, never rendered (FR-REG-04) — the census contradiction is closed, not built. Demo seeds strictly demo-gated; underivable canvas claims replaced by derived templates ("your best since May" → week-over-week compare). 12 deriver unit tests; `qms/RISK.md` touched (clinRed scope, GMI display-only, demo honesty).
- **Known follow-ups:** LV001 GMI seed 6.8 vs 6.1 mismatch (DEBUG); below-range red re-stroke flagged for design review; inferred-denial cue for the declined screen; identity-check consent-ledger receipt awaits the real verifier.

## PR-106 — A7.2 Home screen anatomy (2026-08-12, branch `claude/a72-electric-ink`; CN directive same day: build the DESIGNED screens, not just the reskin)

Structural rebuild of Home/Today to the `screen-home.jsx` canvas (design source of truth). Presentation-layer only: all values come from the existing `TodaySignals`/`AppState` paths; nudge generation, baselines, and provenance handling untouched.

- **feat(home) — verdict hero + iris day-arc.** TODAY kicker + serif verdict headline + moss underline + sub-line (existing honest `affirmHeadline/affirmSub` derivations), with a new `IrisDayArc` (fjordBright/ink/amber concentric arcs, progress = fraction of day elapsed) as the brand-mark timepiece. Cold start keeps the calibrating card in the hero slot (`IrisDayArc` low-progress + "Learning your normal." + honest progress capsule).
- **feat(home) — momentum strip.** "SINCE LAST WEEK" — deltas computed vs the mean of the user's OWN week series (`weekDelta`: hrv ≥2, sleep ≥15 min, in-range ≥3 pts; suppressed on cold start; demo seeds only in demo mode); wrapping `FlowLayout` so items never truncate; "See the trend →" into `WeekInContextView`.
- **feat(home) — verdict-first signal cards.** `signalRow` chips → 2×2 `SignalCardView` grid: domain accent left-rule, verdict WORD first (serif; "As usual" / "Steady" / "On the way up" / "Worth a look" / "Calm"), mono value + unit after, `BaselineSpark` (7-day polyline over a personal-band tint), glucose card carries the "Zones & TIR →" chip. All verdicts "—" on cold start. NavigationLinks to `MetricDetailView` unchanged.
- **feat(home) — ONE attention card / quiet line.** `insightHero` → `attentionCard` (amber surface, "Worth a look" kicker, same first-nudge content + evidence path — FR-NDG coupling unchanged, display treatment only) — or, when no nudge earned attention, the `quietLine` all-clear ("Nothing needs your attention today."). Never both; nothing on cold start.
- **feat(home) — share card + colophon.** Standing "who can see your week" card driven by live `WalletGrant` state (first active clinical grant's name in the headline; "N active shares · summaries only · 0 raw exports — ever" meta; both buttons route to the Privacy tab via new `onOpenPrivacy`). Footer colophon replaces the tagline: "Printed on your device — nothing left it today." (or "— you chose what to share." once research contribution happened) + "Governed by the Data for Good Foundation."
- **feat(appbar).** "On device" chip (moss ring-dot) in the app bar → opens `InAppPrivacyView` as a sheet.
- **chore(debug).** `LIVIQA_SCROLL_TO=bottom` DEBUG-only snapshot hook (joins the existing `-uiTestAutoDemo` family) to screenshot below-the-fold Home headlessly.
- **feat(home) — evening edition (post-21:00, `7e8589e`).** Home becomes the designed ending: closing note (allow-listed verdict from the same week helpers as the morning hero, brass underline, near-full day-arc), `ScoreRing` day score — three VISIBLE fractions added up (sleep vs 8 h, today's TIR, HRV vs own week mean; ≥2 real domains required, demo seeds only in demo mode, hidden on cold start; anti-score-opacity by construction), `MonthTrendLine` with dashed "your usual" average (real data honestly labelled "Last 7 days" until a 30-day deriver exists), tomorrow hook (real open question from the user's own series or the plain promise — never an invented experiment). `LIVIQA_EDITION=evening|day` DEBUG force.
- **feat(insights) — week verdict hero + grid header (`ff58f69`).** DWeek anatomy: serif week verdict derived from the correlation grid itself (the "everything else held" grammar is only used when exactly ONE day carried deviations), how-to-read header on the grid card, serif pattern headline named from the cluster day; app bar retitled "Insights" (the hero carries "Your week").
- **Verification:** Debug/sim build green; screenshot QA vs the `screen-home.jsx` canvas — hero+arc, momentum wrap, 2×2 verdict cards, attention card, week card, share card (live grant data), colophon all verified on-device 2026-08-12.
- **Safety notes:** no new FR (presentation of existing requirement surfaces); red still clinical-TIR-only (heart card = rose per PR-105); attention card amber = the established worth-a-look treatment; provenance field still never rendered; momentum/verdict language is baseline-relative and non-diagnostic by construction (allow-listed verdict words only).

## PR-105 — A7.2 "Electric Ink" reskin (2026-08-12, branch `claude/a72-electric-ink`; CN approved the 5 gate decisions same day)

Skin only — IA/copy/navigation unchanged; dark "Evening" args untouched except the two documented exceptions. Source: the A7.2 design handoff (`design_handoff_liviqa_a7`, revised package) — the outcome of Christel's review rounds 3–4 (52 of 57 threads resolved by the package; 5 partial → copy pass / feature backlog).

- **feat(theme) — Theme.swift v04.** Full A7.2 light-token swap: electric paper `0xE9F1FA`, softened-cobalt ink `0x2A4FAE` (+stepped inks), fjord teal `0x077E77` (text/buttons) + NEW graphic-only `fjordBright 0x00B5AC`, cool hairlines, saturated domain accents, cobalt invert + DfG cobalt. Amber deliberately MODE-SPLIT (light `0xFFC533` / dark stays `0xFFB703`).
- **APPROVED DEVIATIONS (CN 2026-08-12):** (1) `accentHeart` = rose-punch `0xD9486B` (dark lift `0xF07E9B`), NOT the package's `0xE62E3D` — a second saturated red would collide with the red-is-clinical-glucose-only lock (RK-ALARM-01; see RISK PR-105). (2) `ink4` darkened `0x8C96BB → 0x7E88B0` — the package value fails even the 3:1 large-text floor.
- **feat(safety-viz) — TIR colour-safety ramp + overlays.** The clinical ramp is replaced (plum/red-rose/green/amber/sienna, dark lifts verified ≥3:1 on plate) and bands are never colour-alone: HATCH on very-low, DOTS on very-high, in-band text labels (GlucoseCurveView) — closes the deuteranopia hazard flagged in the A7 direction review.
- **feat(assets).** AccentColor (was empty) light/dark set; LaunchBackground → paper/marine; DfG colour logo from the package; LiviqaMark → cobalt+`00B5AC`; reversed marks + WatchMark → white+`00E0D0`; AppIcon.icon → mid-cobalt ground (gradient refinement deferred to Icon Composer GUI), white iris, `00E0D0` ring.
- **feat(ui) — structural patterns.** Solid icon squares + white glyphs (Settings source/nav rows, DataSources rows; Journal vault → neutral solid ink); masthead iris wears the app-icon badge tile (cobalt gradient, white iris @72%); tab-bar inactive icons `.medium` + labels `.semibold` (colour already solid ink3 — 5.45:1 verified); off-state sweep found nothing left to fix.
- **feat(watch).** WatchTheme A6 navy/honeydew/Frosted-Blue → A7.2 marine/plate/off-white/lifted-teal; watch amber stays `0xFFB703`.
- **Verification:** build green after every commit; WCAG recomputed for all key pairs (ink 6.52:1 paper / 7.43:1 card; ink3 5.45:1; clayText 6.72:1 on amber2; teal text 4.93:1 on cards — teal text stays OFF bare paper by rule); screenshot QA vs package canvases pending in this branch's QA pass.
- **Known/accepted:** light amber now aliases `tirHigh` exactly (accepted with the amber renewal); `fjordBright`/recovery solid squares are sub-3:1 by design → adjacent text labels are mandatory (all converted rows have them).

## PR-104 — Sundhed.dk on-device record wave (builds 10.71→10.98) + Phase 0 robustness (2026-08-12, `feat/sundhed-connect` → develop `f115739`; fixes `530b32d`)

**Dated catch-up notice (QMS integrity):** the 10.71→10.98 wave was developed 2026-07-08→2026-08-10 and merged 2026-08-12 WITHOUT contemporaneous QMS entries — a violation of the repo's own RTM-row-before-merge rule, found by the 2026-08-12 external-testing audit. This entry, the PR-104 rows in `RTM.md`, the PR-104 hazards in `RISK.md`, and the DHF entry are the after-the-fact record; the gap itself is part of the record.

- **feat(sundhed) — Path B: PDF import (10.80–10.87).** Sundhed.dk journal PDF parsed on device: labs + journal diagnoses extracted into the record; import is user-initiated, file never leaves the device.
- **feat(sundhed) — Path A: live in-app connect (10.88).** `SundhedWebSessionView`: the citizen signs in to sundhed.dk with MitID inside a WKWebView (credentials never visible to Liviqa); an injected document-start interceptor captures the SPA's own same-origin API responses across four Min Sundhedsjournal pages (medicine, labs, diagnoses, hospital journal) + a DOM read for ICD-10 codes, reduced in-page to codes/aggregates. **Terminal sink is the on-device store ONLY** — the earlier automatic upload was removed; nothing leaves the device from this flow.
- **feat(record) — canonical on-device health record store (10.89).** `Liviqa/Health/HealthRecordStore.swift` + schema (`HealthObservation`/`HealthCondition`/`HealthMedication`): source-agnostic (Sundhed live/PDF today; OCR/HealthKit later), per-source dedup/supersession, file-protected SwiftData, cloudKit `.none`. Off-device ONLY via the explicit "contribute to research" action (coded catalog v0.4.0 body → existing consented ingest client).
- **fix(store) — data recorded then randomly lost (10.93, `d9f4df6`).** Root cause: `FileProtectionType.complete` on the main SQLite file only (key evicted on lock; WAL siblings unprotected) + a bare `try?` silently nulling the ModelContainer. Fix: `.completeUntilFirstUserAuthentication` across store+`-wal`/`-shm`; loud log + in-memory fallback instead of silent no-op.
- **feat(sundhed) — diagnoses UX (10.94–10.98).** Plain-language condition names + start dates (month precision), major-conditions-lead/minor-collapse tiering, returning-user pull gated on login. Display-only presentation of the citizen's OWN national record — no interpretation, no nudge coupling.
- **fix(intelligence) — sleep nudge union-not-sum (`574b971`).** `sleepNudge` now compares real nightly totals (union of asleep segments via `SleepReading.mergedAsleepHours`, same grouping as SleepDeriver) instead of individual fragments vs a fragment baseline. Correctness improvement to baseline-relative sleep; pinned by `SleepMergeTests`.
- **fix(store) — Phase 0 robustness (2026-08-12, `530b32d`).** (1) `HealthStore.ingest()` save no longer `try?`-swallowed — failure throws and surfaces as honest user copy; (2) degraded persistence is user-visible (`AppState.storeDegraded` → Home banner) when the on-disk store fails to open; (3) `-uiTestAutoDemo`/`LIVIQA_DATA` provider-forcing compiled out of Release + new posture lint `providerForcingIsDebugGated`.
- **Verification:** develop @ `530b32d` Debug/sim build green; **full `LiviqaTests` run 2026-08-12: 161 tests / 34 suites, ALL PASS** (see VnV.md).
- **Open owner gates (external-testing blockers, tracked in the 2026-08-12 audit):** written Trifork/sundhed.dk sanction artifact filed (or `sundhedWebConnectEnabled` gated off for external builds); DPIA v02 covering the shipped in-app flows + diagnoses + external cohort, signed; SRS v06 absorbing the [PROV] FR ids below.

## PR-103 — TestProd app wave (T1): rails, GDPR surfaces, real journal sync, consent receipts, honest cold start (2026-07-07, branch `feat/testprod-app`)

Operating decision: **RELEASE CONFIG IS TESTPROD** — no new build configuration; the Release build IS the test-production build, and every demo path is `#if DEBUG`-gated.

- **feat(rails) — sandbox wallet-rail detour retired.** `Config.walletRailBaseURL` no longer hard-codes the Scaleway sandbox container for prod builds: ALL rails (grants, ledger, wallet issuance, care surface) ride `api.liviqa.app` in Release. A DEBUG-only `LIVIQA_WALLET_RAIL_URL` env override remains for local dev against a split backend. **Deploy gating is the owner's step — route parity (journal, care, issuance routes) must land on `api.liviqa.app` before this branch ships.**
- **feat(posture) — Release-posture enforcement.** New `Liviqa/ReleasePosture.swift`: `#if !DEBUG` runtime preconditions executed at every Release launch (simulated logins off, wallet rail on the main backend, default backend = sovereign prod, no dev seed token) — a regression crashes the first launch, not a review. Plus `LiviqaTests/ReleasePostureTests.swift`: a source-lint suite (conditional-compilation walker) verifying every demo gate (`dfgWalletLoginEnabled`/`nationalIDLoginEnabled`, `.mock` default, LV001 injection, mock wallet/care/research seeding, AuthView demo button, Journal/Vault/Privacy demo seeds, ColdStart seed table, sandbox rail host absence) — fails the unit-test run in any configuration.
- **feat(gdpr) — Export my data is real (FR-GDPR-01 [PROV]).** The Settings export button (previously a fake 2-second "Export ready in Files" animation) now fetches `GET /me/export` on the sovereign backend (honest device-local JSON on mock/demo) and presents the share sheet; progress + honest failure state with retry.
- **feat(gdpr) — Delete flow erases server-side, SERVER FIRST (FR-GDPR-02 [PROV]).** `AppState.eraseEverythingServerFirst()`: `POST /me/erase` must confirm BEFORE the local wipe (`deleteAllData()`), so a network failure can never strand server data behind a success message the user already saw. New retryable failure state in the Settings flow; copy updated to say servers + device. Ordering pinned by `EraseOrderingTests`.
- **feat(journal) — silent data loss ends: real journal sync (FR-JRNL-SYNC-01).** The `LiviqaBackendService` stub trio (fetch→`[]`, upsert echo, delete no-op) is replaced with the citizen `/journal` routes (`GET`/`PUT /journal`, `DELETE /journal/{id}`), with a local-UUID↔backend-id map for update/delete addressing. Server rows carry TEXT + timestamp only; mood/tags/metric snapshots stay device-local by design. Mapping pinned by `JournalSyncMappingTests`.
- **feat(wallet) — consent receipts in the ledger (FR-WAL-CE-01 [PROV], P7 display wave).** `WalletGrant.ceGrantRef` + `WalletEvent.ce` (`CEEvidence`) decode the backend's CE evidence (`detail.ce`: receipt_id, grant_ref, contract_sig, event_hash, tx_hash, scope keys) — optional/backward-compatible. `ConsentLedgerView` shows a per-event "Evidence receipt" (copyable receipt id, short hash, "Verified by the DATA for GOOD consent ledger") and now claims **"verified" ONLY when evidence exists**. On-device cryptographic verification of the receipt = flagged follow-up. Decode pinned by `ReceiptDecodeTests`.
- **feat(cold-start) — honest first run in Release (FR-COLD-01 [PROV]).** NO mock seeding on shipped builds: all `AppState` seeds route through `ColdStart` (demo in DEBUG, EMPTY in Release — rings, nudges, passport, correlation week, tokens 47→0, `HealthContext.demo`→empty, connected sources honest); `loadWallet` mock fallback, research demo study, `signInDemo` seeds, Journal/Vault demo entries and Privacy demo grants all DEBUG-gated; AuthView's "Continue without an account" demo entry is DEBUG-only. First real run backfills **90 days** of HealthKit history (steady state 30) so baselines fill from existing Health data; a genuinely empty start shows the honest "Building your baseline / first insights after ~3 days" card with "—" signal chips and no seeded sparklines. 13 new `Localizable.xcstrings` keys with `needs_review` translations (da/nb/sv/es/pt).
- **Verification:** `guard_provenance.sh` green · Debug build green · Release build (`-configuration Release`, iPhone 17 sim) green · `LiviqaTests` green incl. 4 new suites (`ReleasePostureTests`, `JournalSyncMappingTests`, `ReceiptDecodeTests`, `EraseOrderingTests`).

## PR-102 — Pre-launch audit fixes, waves 1–5 (2026-07-03 → 2026-07-05, launch-readiness audit)

### Wave 1 (2026-07-03, audit Day 1 "stop the lies")
- **fix(privacy) — "Delete permanently" now actually deletes (T-DEL-01).** Implemented `AppState.deleteAllData()`: wipes every on-device SwiftData sample entity (all 13 `LiviqaStore.models`, per-type `context.delete(model:)` + save), removes the journal file (`journal.v1.json`), clears the encrypted HealthKit sync anchors for the local scope (`EncryptedAnchorStore.clear()`), clears the Keychain session token (`SessionTokenStore.clear()`), signs out, clears `liviqa.citizenCred.validUntil`, and resets every health-derived in-memory surface to first-launch seeds. `SettingsView`'s final "Delete permanently" button now **awaits the erase before** showing "All local data deleted." — that confirmation was previously shown while nothing was deleted (`deleteAllData()` did not exist; GDPR Art. 17 exposure in a health app). Test `T-DEL-01_deleteAllData_purgesEverything` to be authored in the verification pass.
- **fix(auth) — simulated identity logins are DEBUG-only.** `Config.dfgWalletLoginEnabled` / `Config.nationalIDLoginEnabled` now compile to `false` in Release/TestFlight (`#if DEBUG` gate) — the DfG Wallet / national-eID tiles no longer render on shipped builds, so their `signInDemo()` route is unreachable there. Backstop: `applyLV001DatasetIfNeeded()` is a **no-op in non-DEBUG builds**, so no Release path (including "Continue without an account") can ever inject the fabricated LV001 record ("3499 days tracked") as the user's own data. The pitch flow is unchanged in Debug/demo builds.
- **fix(sec) — no Mistral key compiles into Release binaries.** `LiviqaSecrets.mistralAPIKey` is `#if DEBUG`-gated (empty string in Release, referenced nowhere on the Release path); `MistralClient` now branches: Debug = direct EU Mistral call with the local gitignored key (unchanged); Release = backend proxy `POST {apiBase}/ai/chat` `{system, user}` → `{content}` on the sovereign API base, authorised with the Keychained session bearer (NFR-SEC-01) — the key stays server-side (proxy route prepared in liviqa-backend in parallel). `hasKey` in Release now means "proxy reachable" (sovereign backend), keeping the ChatView consent-toggle + on-device fallback semantics intact. **Owner action (open): rotate the Mistral key** — it compiled into earlier builds.
- **risk:** safety-path note added to `qms/RISK.md` (PR-102) — both flow changes remove hazards (fabricated-data-as-own, false deletion assurance); no new clinical hazard, no change to nudges, units, provenance, or the FR-NDG-06 guard.

### Wave 2 (2026-07-03, audit Day 2–3 "guards + QMS integrity")
- **fix(qms) — designated control T-PROV-01 made real (was inert AND red).** `scripts/guard_provenance.sh` was wired to no build/CI step and exited 1 on wallet-receipt word collisions ("provenance receipt", UC-24b/UC-21 comments/copy in `JournalView`/`WalletView`) — while VnV/RTM/RISK recorded it as green and blocking. Pattern scoped to the provenance DATA FIELD (`.provenance` access, `provenance:` label, `Provenance` type/enum-case — not the bare word; verified green on the tree, red on a data-field fixture, green on receipt-vocabulary fixture) and the guard is now a **blocking step in `build-ios.sh`** before xcodebuild (`set -e` aborts the build). `project.pbxproj` deliberately not hand-edited. The substantive never-renders rule held throughout — no view renders the field (audit-verified).
- **docs(qms) — false T-PROV-01 records corrected in place (history kept):** `VnV.md` T-PROV-01 row, `RTM.md` NFR-PRIV-05 row, `RISK.md` RK-PROV-01 row each now carry a dated CORRECTION noting the guard was inert from 2026-06-03 until fixed + wired on 2026-07-03. Also corrected: the `VnV.md` "T-PROV-01 — procedure & result (PR-3)" section ("wired as a required CI check" was never true) and the `VnV.md` "CI note" (no `.github/workflows/` has ever existed in this repo — actual enforcement is the blocking `build-ios.sh` step; standing up real CI stays an open owner action).
- **docs(qms) — 8 missing RTM rows added (FR-QMS-03 cardinal violation closed):** FR-RSCH-03, FR-WAL-08, FR-PROV-02, FR-PAT-01, FR-PAT-02, FR-PAS-03, FR-ING-08, NFR-RSCH-04 — each row names its design element and its covering test (`WorkoutDedupTests` T-DED-01..05, `PatternEngineTests` T-PAT-01..04, `tirRespectsCustomBand`) or an explicit named test gap. RTM version bumped to 2026-07-03. **Found in passing:** the PR-99 changelog entry below claims `T-RSCH-01`/`T-CONSENT-REACT-01` were authored — neither exists in `LiviqaTests/`, and `RK-CONSENT-REACT` (referenced from `ConsentReactivation.swift`) is absent from RISK.md; recorded as test gaps in the new RTM rows, tests still to be authored (consent-critical).

### Wave 3 (2026-07-05, audit Day 4–5 "CTAs + honest copy")
- **fix(ui) — six dead CTAs resolved (audit §5 HIGH: empty `Button { }` closures in reachable shipping views).** One wired, five converted to the repo's honest-stub pattern (disabled, "SOON" chip, dashed stroke — the `JournalView` "Scan the label" pattern), each marked `// HONEST-STUB` for the new guard:
  - `NudgeDetailView` "Share via wallet" — **WIRED** to the existing multi-step `ShareWithClinicianView(nudge:onDismiss:)` consent-share flow (sheet) — the exact flow the card copy promises, and it already accepts the nudge; the Liquid-Glass `MorphActionCluster` share affordance now opens the same sheet (its journal affordance stays a follow-up).
  - `NudgeDetailView` primary action — **STUB**: the labels are heterogeneous per-nudge behaviours ("Remind me to wind down at 20:30", "Note in journal", "Share with coach"…), each needing its own handler (notifications, journal hand-off) — a generic no-op or wrong handler would be a new lie.
  - `ConsentLedgerView` "Technical details" — **STUB**: the cryptographic proof surface ("proof on demand") doesn't exist yet; rendering raw event fields would masquerade as proof. Navigation chevron dropped.
  - `MetricBaselineView` "Log what's working" + "See your 90-day baseline ›" — **STUB ×2**: no metric→journal quick-log routing exists (journal state lives in the Journal tab) and `BaselineMetric` carries no time series / no 90-day history surface exists.
  - `InAppPrivacyView` "Manage scope" — **STUB**: no per-scope editor exists; pause/resume above it remains the live control.
- **fix(copy) — consult availability no longer claims a calendar linkage that doesn't exist (audit MEDIUM).** `PlanConsultView`: "Greyed times are already booked. Availability mirrors <clinician>'s calendar." → **"Suggested times — your clinician will confirm."** The grid is deterministic simulated free/busy (`isBusy()` hash, as its own doc comment says); the consult request POST itself is real. Corrects the PR-95 copy claim below. `Localizable.xcstrings` key swapped (the old key had no translations; the new key awaits da/es/nb/pt/sv).
- **chore(ci) — dead-CTA guard added to `build-ios.sh` (blocking, before xcodebuild):** the build fails on any `Button { }` empty closure in `Liviqa/` Swift sources unless the line carries an explicit `// HONEST-STUB` marker (all six disabled stubs, incl. the pre-existing `JournalView` one, are marked). Verified: guard green on the tree, red on an offending fixture. Still to author (owner): the audit's `noDeadPrimaryCTAs` XCUITest tap-sweep (test plan row 8).

### Wave 4 (2026-07-05, audit Day 6 "localization sweep")
- **fix(l10n) — 83 untranslated `Localizable.xcstrings` keys (video-consult + research-flow, plus the Wave-3 "Suggested times" key) drafted into all five languages (da/nb/sv/es/pt).** Every draft is written with state **`needs_review`** (not `translated`) — owner review pending before any of it counts as done. Register matched to the existing catalog (du-form da/nb/sv, tú es, formal European pt); glossary `localization/TERMS.json` v03 applied (nudge→indsigt/innsikt/insikt/observación/observação; samtykke/samtycke/consentimiento/consentimento; time-in-range terms; `neverTranslate` brands untouched, incl. "Liquid Glass" kept verbatim). Format specifiers preserved and machine-checked per language against the EN reference (positional `%1$@…` where EN uses them); decimal commas per locale ("MÅL 3,9–10,0"); HRV→VFC in es/pt per existing usage. Validation: catalog is valid JSON, `xcrun xcstringstool compile` green for all five lproj outputs, and per-language counts reconcile — before: 559 translated / 83 missing; after: 559 translated + 83 needs_review = 642 = total keys, 0 missing per language; a structural diff confirms exactly those 83 entries changed and only by gaining the five `needs_review` string units. Copy-only change: no safety path, units, provenance, or FR touched — no RISK/RTM delta.

### Wave 5 (2026-07-05, audit Day 7 "docs & release policy")
- **docs(release) — `GOLIVE_CHECKLIST.md` rewritten against reality (audit cross-check verdict: FAIL).** The old file claimed build 10.20 / 114 tests (actual at audit @ 0558bdd: **10.70 / 126 tests in 28 suites**), said the Watch target "must be created in Xcode" (it is **built AND embedded** — `ValidateEmbeddedBinary …/Watch/Liviqa Watch.app` in the audited build log), and asserted "Release build green" without evidence. The rewrite states only what the 2026-07-03 audit verified, lists Release build / LiviqaUITests / device archive / Watch runtime explicitly as **NOT yet run**, and adds a §0 release-gates block: (1) demo-login flags compile-time OFF outside DEBUG (enforced in code, wave 1 — Release spot-check pending); (2) Mistral key rotated + backend `/ai/chat` proxy live before any public build (key burned — compiled into builds ≤ 10.70); (3) post-deploy route parity green via `liviqa-backend/scripts/route-parity.sh` (8 client-called routes currently 404 on api.liviqa.app); (4) `guard_provenance.sh` green as the blocking `build-ios.sh` step (real CI still absent); (5) owner review of the 83 × 5 `needs_review` localization drafts from wave 4.
- **docs(brand) — repo `CLAUDE.md` brand line corrected (audit Low: doc drift).** Line 8 claimed "aperture mark image, Lato" as the locked brand; the shipped code has been iris mark + SF Pro (+ IBM Plex Mono for numbers/kickers) + the A6 "Daylight" six-colour palette since the PR-96 re-skin — aperture + Lato retired 2026-06-17. Code was already A6-correct; only the instruction doc was stale (and was steering agents toward a dead brand).

### PR-102 status at close (2026-07-05) — what is done vs. open
All five waves are on branch `fix/launch-audit-20260703`; nothing was deployed and no key was rotated by this work (owner-only by design). **Open owner actions:** (1) rotate the Mistral key and deploy the backend `/ai/chat` proxy — hard gate for any public build; (2) deploy liviqa-backend HEAD to api.liviqa.app and run `route-parity.sh` to exit 0; (3) review the 83 × 5 `needs_review` translations in `Localizable.xcstrings`; (4) run the Release build, LiviqaUITests, and device archive (audit §7 commands); (5) stand up real CI around `./build-ios.sh` (no `.github/workflows/` exists); (6) author the tests recorded above as gaps: `T-DEL-01`, `T-RSCH-01`, `T-CONSENT-REACT-01`, and the `noDeadPrimaryCTAs` XCUITest sweep.

## PR-101 — Flighty tab-bar magnifier: rest pill + screen-magnify limit (2026-06-17, build 10.70, CN reference: Flighty)
- **refine(chrome) #1 — resting selection pill fills the whole tab.** Replaced the small oval with a snug rounded-rect (squircle) that wraps both the symbol and the label with even padding (Flighty rest pill), behind the content. Verified on the Paper theme. (build 10.70)
- **decision #2 — "lens overflows the bar + magnifies the screen content behind it" is NOT feasible with `.layerEffect`.** Applying the magnify shader at the body level (over the `NavigationStack`/`ScrollView`) makes SwiftUI fail to rasterize the hierarchy → it renders the system red "unavailable" placeholder (verified on the Simulator). Reverted to the working bar-level magnifier: the lens magnifies the bar's own opaque surface + icons (chromatic aberration), staying within the bar. A real loupe over live screen content would require an `ImageRenderer` snapshot pipeline (capture on drag-start, magnify the snapshot) — a separate, heavier effort, deferred pending CN go-ahead.

## PR-101 — Flighty tab-bar magnifier: real Metal shader (2026-06-17, build 10.69, CN reference: Flighty)
- **fix(chrome) — on-device empty lens (root cause).** `.layerEffect` only samples the layer it's attached to; the bar surface was real `.glassEffect`/`.ultraThinMaterial` added AFTER the effect — a private backdrop layer the shader **cannot sample** — so between icons the lens magnified nothing and read as an empty/frosted oval on device (the Simulator masked it with different compositing). Fix: the bar is now an OPAQUE `Capsule(paper2)` drawn as the row's background and flattened with the icons via `.compositingGroup()` BEFORE the `layerEffect`, so the lens magnifies a real, populated surface (also why Flighty's bar is opaque). Geometry-derived `maxSampleOffset` (`capR+halfLen`); shader simplified for opaque/premultiplied content. Verified magnifying Home/Care/Privacy in the light (Paper) theme; balloon-expansion bug (flexible `Capsule` sibling) caught + fixed. (build 10.69)
- **fix(chrome) — magnifier didn't enlarge on a real device (build 66 showed an empty/opaque oval).** Two device-only causes removed: the shader was disabled under Reduce Transparency / Increase Contrast (showed a solid opaque capsule) → now the magnify `layerEffect` is ALWAYS on while pressing; and the bar sat inside a `GlassEffectContainer` which can starve the sampled layer on device → container dropped (no glass pill left to merge). Magnification 1.7×→2.0×, `maxSampleOffset` 60→80, and the rim is now always a thin chromatic STROKE (never an opaque fill). Verified magnifying in the light (Paper) theme on the iOS 26 Simulator. (build 10.68)
- **refine(chrome) — resting selection chip is a wide OVAL** (per CN: not round). Drawn at the selected tab's measured frame (w = slot×1.30, h = barHeight×0.62), behind the row, never magnified; becomes the glass lens on touch. (build 10.67)
- **feat(chrome) — the lens actually magnifies the icons.** The stock `.glassEffect` only frosts (it never enlarges), which is why earlier takes read grey. Replaced with a Metal `layerEffect` (`Magnifier.metal`, `tabMagnifier`): inside a horizontal CAPSULE centred on the finger it samples the tab-row pixels and ENLARGES them (1.7×) with radial chromatic aberration toward the rim + a faint glass body + edge highlight. Real pixel work (iOS 17+ `layerEffect`) → renders the SAME on Simulator and device. Driven by `DragGesture(minimumDistance:0)`; capsule bigger than a tab, centred on the bar; tracks the finger; lift selects; a thin SwiftUI chromatic-rainbow capsule rim is drawn over it.
- **build dependency:** needs the Metal Toolchain component (`xcodebuild -downloadComponent MetalToolchain`, 688 MB — installed).
- **accessibility:** under Reduce Transparency / Increase Contrast the shader is disabled (no distortion) and a plain solid capsule shows instead; per-cell `.isButton` + `.accessibilityAction(.default)` keep selection usable for VoiceOver. Flag off / iOS 17–25 still select by tap with the legacy dot.
- **Verified on the iOS 26 Simulator (real press-drag via computer-use):** the Care icon + label visibly enlarge inside the capsule with RGB fringing — the picture-reference effect, on the Simulator. **Shipped TestFlight 10.66.**

## PR-101 — Flighty glass-capsule magnifier tab bar (2026-06-17, build 10.65, superseded same day by the Metal shader above)
- **feat(chrome) — the selection pill becomes a piece of glass on touch.** Per CN's Flighty frames: a `DragGesture(minimumDistance: 0)` on the bar transforms the resting selection chip into a CAPSULE glass lens (`GlassMagnifierLens` — clear iOS 26 `.glassEffect` + a pronounced chromatic rainbow rim, `LiquidGlass.swift`). The lens is bigger than a tab (≈1.6 slots), **centred vertically on the bar** (no pop-up), and sits OVER the menu items so the real glass refracts/magnifies THEM — no fake glyph copy, no size-change; it fades in/out and tracks the finger 1:1. On lift it selects the tab under the finger; the lens fades. Finger hit-tested against measured tab frames (`TabFrameKey`).
- **rest state:** a subtle selection chip behind the active tab (glass on) that becomes the lens on touch; flag-off keeps the legacy dot. No slide.
- **accessibility:** selection works without the gesture — each cell is an `.isButton` element with `.accessibilityAction(.default)` → `select(item)` (VoiceOver double-tap).
- **three-tier ladder kept:** iOS 26 clear glass lens → iOS 17–25 `.ultraThinMaterial` capsule → opaque `paper2` capsule under Reduce Transparency / Increase Contrast. Flag off / iOS < 26 = the prior bar (tap-to-select, dot), no lens. Behind the `liquidGlass` flag.
- **Iteration history (all caught + fixed on the iOS 26 Simulator):** (1) a gliding selection pill — wrong, "not a slider"; (2) a circular bubble that popped above the bar with a fake magnified glyph + size change — wrong; (3) THIS: a centred glass capsule over the content that refracts the real icons, with the chromatic edge. `glassEffectID` morph cross-faded on a 6-slot bar; `.position` ballooned the bar full-screen — both avoided.
- **Verified (real press-drag via computer-use):** capsule shape, size, vertical centring, chromatic rainbow rim, finger tracking, tap-select, drag-release-select, clean rest chip. **Shipped TestFlight 10.65.** KNOWN: the clear-glass refraction of the icons renders only on a physical iOS 26 device — the Simulator draws the lens interior frosted.

## PR-100 — Visual-system promotion #1–4: TIR zones, graded heatmap, visual nudge, cross-source cards (2026-06-16, PR-99 proposal · Option B · CN sign-off)
- **feat(viz) #4 — cross-source correlation cards promoted to Insights (flagged, default OFF).** `CorrelationCard` + the three charts (`HbA1cDriftChart` lab-vs-lived glucose, `FinanceSleepChart` money↔sleep, `AlcoholHRChart` dining↔recovery) moved out of the DEBUG Glass Lab into production `CorrelationCards.swift`; new `CrossSourcePatterns` section on `WeekInContextView` behind `@AppStorage("crossSourceCards")` + a **Settings → Cross-source patterns** toggle. **Default OFF on purpose:** these run on SIMULATED cross-source pitch data (D5) — real users never see fabricated data unless they opt in. Headline grammar is observation-not-causation; each card carries its sample size + "a pattern, not a diagnosis". This is the "Apple can't" differentiator (health × spending × lab). Build green.
- **feat(viz) #3 — visual nudge + real-data sparkline on the Home hero (LIVE).** The Today nudge surface shows a domain icon (glucose/sleep/cardiac) behind `@AppStorage("visualNudge")` (default ON) plus a `MiniSparkline` drawn from the **real** `todaySignals` weekly series for the nudge's domain (in-range / sleep / HRV) — no fabricated numbers; renders only when ≥2 real points exist. Settings toggle added.
- **feat(viz) #1 — clinical TIR zones LIVE on the glucose chart.** `GlucoseCurveView.showsClinicalZones` draws the international-consensus AGP bands (very-low/low/target/high/very-high — `tirVeryLow…tirVeryHigh`, target = the one sanctioned clinical green) behind the curve, target labelled, y-axis target ticks green; replaces the single moss band. Wired in `MetricDetailView` via `@AppStorage("clinicalTIRZones")` — **default ON** (CN signed off), one tap to revert. Red appears ONLY here (RK-ALARM-01 honoured). Lab-validated; real component rendered on the iOS 26 Simulator.
- **feat(viz) #2 — graded deviation heatmap (flagged, default OFF).** `WeekInContextView.fill()`/`readout()`/legend remap the five `CorrelationCell` levels the model **already computes** to a calm cool→warm ramp capped at deep amber (`devMed`/`devHigh`/`devOutlier`; never red) + magnitude wording + the cluster ring as the non-colour pre-attentive signal (colour-blind-safe). Behind `@AppStorage("gradedHeatmap")` — awaiting CN flip.
- **tokens (PR-99 lab):** clinical TIR scale + deviation ramp + Option-B accents (indigo sleep / slate financial) added additively to `Theme.swift`. Lab system (visual nudge, 3 cross-source correlation cards, colourful-calm screen, full proof matrix) lives in `_GlassLab` (DEBUG) pending promotion.
- **Verified:** build green; iOS 17 floor + Reduce-Transparency/Contrast/Motion + Dynamic-Type fallbacks intact.

## PR-99 — Research participation flow + reactivate-withdrawn-consents (2026-06-16, scoped by CN)
- **feat(research) UC-RSCH · FR-RSCH-01/02/03** — research-participation flow, built from the Novo storyboard's previously mockup-only screens: a matched **research-opportunity card** on Home (`ResearchOpportunityCard`, s09); a **study review + informed consent** screen (`StudyConsentView`, s10 — "Vouched by Data for Good", per-category data toggles, **aggregate-only · k ≥ 5 · withdraw any time**, Approve & join / Decline); a **joined** confirmation (s11). Approve creates a scoped `WalletGrant` to the sponsor via the existing consent model + logs a `consentGranted` ledger event; nothing is shared before approval. `NFR-RSCH-04`: k ≥ 5 floor surfaced.
- **feat(consent) FR-WAL-08 · UC-CONSENT-REACT** — *"reactivate withdrawn consents"*, done legally. Revocation stays one-way (the withdrawal remains in the consent-evidence ledger); reactivation creates a **fresh** active grant per withdrawn one (new id + timestamp + `consentGranted` event) behind an explicit confirmation sheet listing each recipient/scope + the aggregate-only/k ≥ 5 disclosure — never a silent un-revoke. Entry point in Privacy when withdrawn grants exist.
- **risk** — `RK-CONSENT-REACT` added to RISK.md: reactivation is re-consent, not restoration; pending legal review of the bulk-confirm UX.
- **Verified** — build green (iOS Sim, build 10.48); all four screens screenshotted real (s09/s10/s11 + reactivate sheet); `T-RSCH-01` / `T-CONSENT-REACT-01` authored.

## PR-98 — Liquid Glass: design exploration → promoted to real screens (2026-06-16, build 10.49, design dir by CN)
- **Progressive enhancement, iOS 17 floor kept** (CN: "no exclusive phones"). New `Liviqa/Views/LiquidGlass.swift` + `GlassComponents.swift`; all effects behind `@AppStorage("liquidGlass")` (default ON, **Settings → Liquid Glass**) and `if #available(iOS 26, *)`. Three-tier ladder on every surface: iOS 26 real `.glassEffect` → iOS 17–25 `.ultraThinMaterial` → opaque `paper2` under Reduce Transparency / Increase Contrast. Motion resolves to rest via `LiviqaMotion.reduced`. Flag off / iOS < 26 = prior app byte-for-byte. Builds on PR-96 (Daylight).
- **Chrome promoted:** floating tab bar → real Liquid Glass (`.liviqaBarGlass`); soft scroll-edge dissolve on Today + Insights (`.liviqaScrollEdgeSoft`).
- **Interactive surfaces (additive, no locked-screen content rewritten):** new `DayTimelineView` ("Scrub your day", reached from a flagged Insights entry) hosting the interactive glass scrubber + ambient tide field + clear-glass day summary; `MorphActionCluster` on `NudgeDetailView` ("act on this moment"; "Why" reveals evidence depth).
- **Driven from data (CN):** scrubber uses the real `todaySignals.glucoseToday` curve (demo series in demo mode, calm empty state otherwise — never fabricated numbers on a real screen); ambient field breath from resting HR, calm from sleep, tide from circadian phase.
- **Calm attention (CN; RK-ALARM-01):** the "worth noticing" cue in the scrubber/readout uses the navy ink tone, not the bright Amber-Flame alarm dot. In-range stays moss.
- **Design record:** `GLASS_EXPLORATION.md`. DEBUG Glass Lab (`_GlassLab.swift`, `-glassLab`) + `-dayLab` preview hooks (excluded from Release).
- **Verified:** build green; real glass + scrubber + ambient field rendered on the iOS 26 Simulator; opaque fallback confirmed under Increase Contrast; AI-tell + meds grep clean. **Shipped TestFlight 10.49.**
- **Known:** Release-only Swift-6 async warning at `AppState.swift:338` (PR-97 offload) — tracked for a Swift-6 concurrency pass; non-breaking. **Pending CN sign-off:** tab-bar minimize-on-scroll, concentric corners on existing cards, sheet-glass upgrade.

## PR-97 — Beta fixes: Dynamic Type genuinely scales + Home→Insights nav lag (2026-06-16, FB-AEkAWxal · FB-AJR9AqEk, approved by CN)
- **fix(a11y) FB-AEkAWxal** — *"changed text size and it did not change; font is small."* Root cause: the `Theme.swift` font helpers built every face from a FIXED point size (`.system(size:)` and `.custom(_:size:)` **without** `relativeTo:`), so nothing scaled with the iOS text-size setting — and NFR-A11Y-01 had been marked "implemented" on the false belief that `Font.custom(_:size:)`/SF Pro `.system(size:)` auto-scale (they do not; the PR-96 Daylight type switch kept the same fixed-size pattern). Fixed in ONE place: SF Pro helpers (`lato`/`liviqaH1/H2/Body/Caption`) now route through `UIFontMetrics(forTextStyle:).scaledFont(for:)`, and the IBM Plex Mono helpers (`liviqaKicker`/`liviqaMono`) gain `relativeTo:`. All ~566 call-sites scale from this single change; the default (Large) look is unchanged. The two intentional chrome clamps (tab bar `…xLarge`, Home chips `…xxLarge`) are kept.
- **fix(perf) FB-AJR9AqEk** — *"Home→Insights won't respond, delay, have to push many times."* Root cause: `AppState.refreshFromHealth()` ran the whole deriver chain (NudgeEngine, PatternEngine, CorrelationDeriver O(samples·days·signals), PassportStats/TodaySignals/Sleep) **synchronously on the main actor**, so tab taps during the refresh were dropped. Fix: the pure, `Sendable` deriver chain now runs in a `Task.detached(.userInitiated)` and only the `@Observable` assignments hop back to main — awaiting it suspends the main actor, so navigation stays responsive. Also removed the redundant per-appearance `refreshFromHealth()` `.task` on Home that raced the tap (the app-level one-time `.task` already covers launch).
- **chore(test):** push-permission prompt is suppressed under `-uiTestAutoDemo` so it can't block automated snapshots.
- **Doc correction:** `SESSION_iOS_GOLIVE.md` and `RTM.md` (NFR-A11Y-01) corrected — the prior "Dynamic Type implemented" claim was false; now genuinely implemented and re-verified.
- **Verified:** build green, no warnings; Dynamic Type re-verified in the simulator at Large vs accessibility-extra-large (`/tmp/dt_default.png` vs `/tmp/dt_xxxl.png`) — hero/body/kickers grow, chrome stays one line. Nav-lag fix is build-verified; the stall only reproduces on a real device (HealthKit path), where the main-thread block is now removed. Build bumped to 10.48.

## PR-96 — A6 "Daylight" six-colour re-skin: palette, SF Pro, iris .icon, Liquid Glass (2026-06-16, GitHub PR #1, design by CN)
- **feat(theme):** `Theme.swift` recoloured to the locked **six-colour Daylight palette** (Punch Red · Honeydew · Frosted Blue · Cerulean · Oxford Navy · Amber Flame). Retires fern-green/lime, brown-clay, near-black; dark mode = deep navy. Every `LiviqaTheme.*` call site recolours automatically. No green hue in the UI (Cerulean carries consent/in-range).
- **feat(type):** headlines/body → system **SF Pro** (Dynamic Type); **IBM Plex Mono** kept for numbers/kickers; removed Lato/Schibsted/Instrument/Spline `.ttf` + trimmed `UIAppFonts`.
- **feat(brand):** in-app iris marks → Oxford Navy + green ring; app icon → hand-authored layered **`AppIcon.icon`** (Liquid Glass on iOS 26, flattened on 17–25), replacing the flat `.appiconset`. Mark never redrawn.
- **feat(liquid-glass):** floating `.ultraThinMaterial` tab-bar capsule + glass sheets (assistant, consent receipt), each with an **opaque fallback** under Reduce Transparency / Increase Contrast. Today glass cards tried + reverted; Today large-title deferred (brand-lock).
- **fix(hex):** purged stray legacy hex literals (`0xC47D11 → 0xFFB703`; tokenised hardcoded greys/greens, removing stray fern-green from the correlation grid + wallet).
- **⚠ RISK — RK-ALARM-01 re-opened:** the attention tone reverts clay → **Amber Flame**, reversing the PR-47 anti-warning-light control. Documented + flagged for clinical confirmation in `qms/RISK.md` (PR-96); design record in `qms/DHF.md`.
- **Verified:** build green per commit; **130 unit + 2 UI tests, 0 failures** (incl. blocking `T-NDG-06*` / `T-PROV-01` guards); Paper + Midnight + Increase-Contrast on the Simulator. Merged to `develop` (merge `32f4b33`).

## PR-95 — Video consult: simulated availability + waiting-room grace (2026-06-15, FB-AOIWoD6l, scoped by CN)
- **feat(consult):** `PlanConsultView` now shows **free/busy availability** — booked times are greyed/struck-through and unselectable, the selection auto-moves to a free slot on day change, with "availability mirrors <clinician>'s calendar" (deterministic simulated EMR/HIS free/busy; swaps to a live SMART-Slot feed later).
- **feat(consult):** `WaitingRoomView` gains the **15-minute grace → reschedule**: if no clinician joins within 15 min, the screen offers a warm apology + "Reschedule" (per the use case). Still polls in case they join late.
- **fix:** `PreVisitCheckView` net check reworked to an AsyncStream (removed a Swift-6 captured-var data-race warning).
- **Verified:** build green, no warnings.

## PR-94 — Video consult Stage F: virtual waiting room (2026-06-15, FB-AOIWoD6l / FB-AIEzHyog)
- **feat(consult):** new `WaitingRoomView` (Min Læge *venteværelse*). On a booked consult within the join window (15 min before → 30 min after), the Care tab shows an **"I'm ready"** button; tapping it opens a calm dark waiting screen (gentle pulse, "<clinician> will join shortly", "your clinician has been notified you're waiting"). It then **waits passively** — polling the active-consult feed — and when the clinician starts the consult it **joins and opens the call automatically** (no self-timed "join" link). Honest by design: no fabricated queue position or minute-ETA.
- Polls `fetchActiveConsults` directly (not the global ring) to avoid double-presenting the incoming-call overlay. Demo mode (no backend) just waits.
- Stage F of `Liviqa_VideoConsult_Spec_v01`; the citizen-side flow (request → check-in + device test → calendar/reminders → waiting room → auto-launch) is now complete.
- **Verified:** build green.

## PR-93 — Video consult Stage C/D (iOS): calendar invite + reminder ladder (2026-06-15, FB-AOIWoD6l)
- **feat(consult):** the "Add to my calendar" EventKit event now carries the **app deep link** (`liviqa://consult`, in `url` + notes) and the spec **reminder ladder as calendar alarms** — day-before (-24h), -1h, and -10m — reused so calendar alarms and (future) push don't double-fire. Title clarified to "Liviqa video consultation".
- iOS side of Stage C/D. The server-generated `.ics` email (stable `UID`/`SEQUENCE`/`VTIMEZONE`) + push delivery remain backend follow-ups; a deep-link URL handler for `liviqa://consult/{id}` is a small follow-up.
- **Verified:** build green.

## PR-92 — Video consult Stage E: pre-visit check-in + device test (2026-06-15, FB-AOIWoD6l / FB-AOUGIncO)
- **feat(consult):** new `PreVisitCheckView` — Epic's eCheck-in pattern with the US billing stripped: (1) a **per-visit share-consent** gate ("share my consented metrics for this consult", default off, raw data stays on device), and (2) a **camera / microphone / connection test** with green (ready) / amber (needs attention) / red (blocked) status + plain-language fixes, plus a "You're ready" banner. Camera/mic via `AVCaptureDevice.authorizationStatus`/`requestAccess`; connectivity via `NWPathMonitor`. Reachable from the request confirmation ("Test your camera & connection"); designed as the entry gate for the waiting room.
- Addresses the "confusing start on video" feedback (FB-AOUGIncO) and is Stage E of `Liviqa_VideoConsult_Spec_v01`.
- **Verified:** build green; `NSCameraUsageDescription`/`NSMicrophoneUsageDescription` present so the permission checks are safe.

## PR-91 — Video consult Stage A: citizen request posts to backend (2026-06-15, beta feedback FB-AOIWoD6l)
- **feat(consult):** `CareConnect.requestConsult(recipientId:at:kind:)` added to the protocol + implemented in `LiviqaBackendService` (`POST /appointments/request`, status `proposed:citizen`). `PlanConsultView` now takes a `recipientId`, captures a **fallback phone** (`@AppStorage consultFallbackPhone`, framed "so your clinician can reach you if the video drops"), and its **"Request this time" actually posts** + refreshes the care inbox — closing the long-standing "the request doesn't do anything" gap (the button was local-only). `MessagesView` passes the care-team recipient id. Demo/no-backend keeps the local confirmation.
- The accept/decline side was already wired (`respondToProposal`); this completes the request half of the request→accept loop on iOS.
- First increment of the full video-consult spec (`Liviqa_VideoConsult_Spec_v01`, grounded in Min Læge / Sundhedsplatformen-Epic / FHIR R4 + iCalendar). Stages B–G (counter UX, virtual waiting room, reminder ladder, eCheck-in + device test, real SMART-Slot feed, .ics invite) to follow; slot/best-practice design awaits the Telecare North reference.
- **Verified:** build green. Defaults locked: 10-min slot base, 15-min join/grace, 24h cancel (per spec).

## PR-90 — Research consents revocable in Privacy (2026-06-15, follow-up to FB-AIJMHfz6)
- **feat(privacy):** `WalletView` (the Privacy tab) gains a **"Research contributions"** section — the two onboarding consents ("Anonymous cohort discovery", "Discoverable for anonymous research") as labelled toggles bound to the same `@AppStorage` keys, so a citizen can review and **turn them off any time** (GDPR — consent must be as easy to withdraw as to give). Caption restates anonymous/aggregated, raw-stays-on-device.
- Completes the "revocable in Privacy" promise from PR-88. CE-ledger event on backend connect remains the deeper follow-up.
- **Verified:** build green. Toggles mirror the locked card pattern; bound to the onboarding storage so onboarding ↔ Privacy stay in sync.

## PR-89 — Onboarding heavy copy → progressive disclosure (2026-06-15, beta feedback FB-AGtO8N6h #3)
- **feat(onboarding):** new `ExpandableNote` component (ⓘ summary line + chevron, moss card) — taps to reveal detail. Converts the second body paragraph on `DfGOnboardingView` Pages 1 ("You can't be quietly overridden") and 2 ("What if someone disputes it?") from text walls into tap-to-expand notes, so each page leads with one idea and tucks the depth a tap away.
- Implements Brian's FB-AGtO8N6h #3 ("most explanation text needs rework — tooltip box?"). **FB-AGtO8N6h is now fully closed** (#1 logo PR-84, #2 consent boxes PR-88, #3 here).
- **Verified (simulator):** build green; Page 1 renders the collapsed note + (with the text wall gone) the consent box now sits above the fold. Pending TestFlight ship (10.44).

## PR-88 — Anonymous-research consent boxes on DfG onboarding (2026-06-15, beta feedback FB-AIJMHfz6 / FB-AGtO8N6h #2)
- **feat(consent):** `DfGOnboardingView` Page 1 gains an opt-in **"Contribute to research — optional"** section with two consent checkboxes (**default OFF**): "Allow me to be included in anonymous cohort discovery" and "Allow me and my data to be discovered for anonymous research", each with a one-line plain-language explanation. New `ConsentCheckRow` component styled to the locked card pattern (moss fill + white checkmark when on; moss2/moss3 card).
- **wire:** persisted via `@AppStorage` (`consentCohortDiscovery`, `consentResearchDiscoverable`). Default OFF = freely-given consent (GDPR Art. 9). Surfacing/revoke in Privacy and the CE-ledger event are tracked as a follow-up.
- Implements Brian's FB-AIJMHfz6 (build 10.43) and **closes FB-AGtO8N6h #2** (build 10.40). FB-AGtO8N6h #3 (tooltip/progressive-disclosure copy) remains PROPOSED.
- **Verified (simulator):** build green; onboarding renders the section both unchecked and checked. Pending TestFlight ship (bump 10.44).

## PR-87 — LV001 real-data demo: graphs show Claus's goldmine (2026-06-13, beta feedback FB-AN9QOlAh)
- **feat(data):** new `LV001Dataset` (Ingestion) — `passportStats`, `rings`, `todaySignals` (+ weekly sparkline series), and the 7-day `correlationWeek`, composed from the consented goldmine export (glucose/HRV/RHR/steps/exercise daily aggregates + de-duplicated sleep). Real, trustworthy figures: TIR 88%, GMI ~6.8%, 3 499 days tracked, HRV median 27 ms, RHR 70, ~7.2 h sleep, 20 sources. Mirrors the `PatternSeed.lv001` idiom — values embedded as Swift, no raw JSON bundled, no timestamps/locations (location hard-rule respected).
- **wire:** `AppState.applyLV001DatasetIfNeeded()` loads it when `profile.alias == "LV001"` and not on live HealthKit (`usingRealData`) — a real device with the user's own Health data still wins. Called from `signInDemo` and a `defer` in `refreshFromHealth` so it survives the simulator's HealthKit-auth throw. Fixes "graphs not showing my real data when logged in as Claus" — previously graphs were local-HealthKit-or-MockData only, with no account/upload path and `LV001Provider` an unwired stub.
- **Verified (simulator):** Home chips Sleep 7h10 / Glucose 88% / Recovery 27 / Heart 70; "Your Week" TIR 88% with the real 86→100% weekly curve, HRV 27 ms; 7-day grid shows the LV001 pattern. Bump build 10.43.
- **Still open (FB-AN9QOlAh part a):** "font is massive" — pending the specific screen.

## PR-85 — Care team on the citizen video call (2026-06-13, beta feedback FB-AIPKcW7v)
- **fix(consult):** ConsultView gains an "In this call" card under the video — recipient role · organisation + a live presence dot — so the citizen can see who they're speaking with. Previously the call only carried a generic "Care team" Jitsi tile (FB-AIPKcW7v, build 10.39).
- Reuses existing consult data (`recipientName` / `recipientOrg`) and the recording-card style; no new backend, no new FR. Two new labels ("In this call", "In the room") localized da/nb/sv/es/pt.
- **Verified:** simulator build green. In-call screen is backend-gated (live consult), so visual confirmation is on-device on 10.42, not simulator. Bump build 10.42.

## PR-84 — Onboarding DfG logo readable on light canvas (2026-06-13, beta feedback FB-AGtO8N6h)
- **fix(brand):** `DfGOnboardingView` Page 1 sits on `LiviqaTheme.paper` (cream) but used the white/negative DfG mark → invisible. Locked logo rule is light bg → colour variant; swapped `dfg-logo-negative` → `dfg-logo`. Other negative-mark usages audited and left as-is (white-on-navy tiles / inverted token card are correct).
- Addresses FB-AGtO8N6h #1 (build 10.40). #2 (consent toggles) and #3 (tooltip copy) tracked as PROPOSED in `qms/BETA_FEEDBACK.md`.
- **Verified:** simulator build green; onboarding screenshot shows the colour mark on cream. Bump build 10.41.

## PR-83 — String Catalog audit: untranslated/mixed-language sweep (2026-06-12)
- **Audit**: catalog itself was 100% translated (345 keys × 5, zero stale) — the visible language mix came from strings that never entered the catalog: 17 view literals added after the last extraction, model/demo data rendered through String variables (MockData, VaultModels, WalletModels, LifestyleModels, HealthContext, HealthVaultView demo vault), the intelligence layer (NudgeEngine/NudgeModel/CorrelationDeriver compose nudges in English at runtime), and four bypass patterns: `.uppercased()` before Text, custom components taking `String` (secondaryButton, signalChip), `String` vars in Text, and a hardcoded `en_US_POSIX` weekday formatter.
- **Fix**: 212 new keys × 5 languages (catalog now 557 keys, all `translated`); model/demo strings wrapped in `String(localized:)` at the source; intelligence-layer sentences localized with interpolated keys (`%@`/`%lld`); correlation-grid weekday letters now derived from the day's actual date via the current locale (da: M T O T F L S) instead of static English letters; CorrelationDeriver weekday name now uses `Locale.autoupdatingCurrent`; fixed one translated-but-identical da value (OR USE AN IDENTITY WALLET).
- **Guardrails held**: brand-locked terms untouched (Liviqa, DfG, Apple Health/Watch, Health Vault, Sundhed.dk, Sundhedsplatformen, MitID, MyHealth@EU, FMK, drug names, Yourcoach.health, Rigshospitalet); glucose stays mmol/L; GMI headline untouched; provenance still never rendered.
- **Verified**: simulator build green; Today + Auth screenshots clean in da and es (no English remnants).

## [Unreleased] — develop

### PR-82 — Norwegian, Swedish, Spanish, Portuguese interfaces (2026-06-12)
- **feat(l10n):** full catalog coverage in nb/sv/es/pt (345/345 strings each, authored against
  the TERMS v03 glossary; brands/format specifiers untouched; pt is European Portuguese).
  Same xliff pipeline as Danish. Console got matching chrome dictionaries for all four the same
  night. Danish verified on-device; the other four verified at catalog level (identical rail).
- 126 tests ✅.

### PR-81 — Danish interface, first full pass (2026-06-12)
- **feat(l10n):** all 337 catalog strings + 6 permission strings translated to Danish (TERMS v03
  glossary enforced: indsigt/samtykke/deling/tilbagekald/behandlerteam/Behandling; brands and
  format specifiers untouched). Tab titles + greeting converted to `String(localized:)`.
  Sim-verified in da: tabs Hjem/Indsigter/Behandling/Dagbog/Privatliv/Indstillinger, greeting
  "Sen aften", dates "FRE. · 12 JUN.", buttons ("Se evidensen →").
- **Known limit (FR-L10N-02, backlog):** intelligence-layer output (nudge bodies, Today signal
  kickers, deriver sentences) is generated text, not literals — needs String(localized:)
  templates in the derivers. Static chrome is fully Danish.
- nb/sv/es/pt: same pipeline, pending authoring (FR-L10N-03: push catalog to Weblate component).
  126 tests ✅.

### PR-80 — Language selector (2026-06-12, CN request)
- **feat(l10n):** Settings ▸ Display gains a Language picker — System default + en/da/nb/sv/es/pt
  via the real iOS rail (AppleLanguages override, applies next launch; all six registered as
  project localizations). Honest status per language: English complete, others "in review"
  (terminology approved in Weblate; interface translation follows). Console got the matching
  top-bar selector the same hour. 126 tests ✅.

### PR-79 — Brand v2: A4 Navy + Bright Fern (2026-06-12, CN sign-off via design handoff)
- **BRAND CHANGE, signed off explicitly:** palette navy #112744 (ink), paper #F8F5EC / card
  #FFFCF4, fern #31780E light / #4EB818 dark (replaces moss), seal #BF2D24 / #CD4830 (replaces
  rust); dark surfaces grounded on the brand navy. Type: Schibsted Grotesk (UI), Spline Sans
  Mono (kickers/numerics), Instrument Serif bundled for headline use; Lato/IBM Plex kept as
  fallback assets. Mark: IRIS replaces aperture (app icon 1024, LiviqaMark/Reversed imagesets —
  asset-embedded, never redrawn). lato()/liviqaKicker helper names retained so 300+ call sites
  re-themed without churn.
- Console rebranded same day (tokens, marks, favicons, hex sweep — commit in console repo);
  website next. Source: claude.ai/design handoff bundle (A4 direction, accessibility-resolved
  tokens: fern-on-light 5.04:1, bright fern on navy 5.86:1).
- Sim build ✅ · 126 tests ✅ · dark-mode home verified on-device colours.
_Risk:_ visual only; no behaviour change. Presenter PDFs (Folkemødet) show v1 — flagged.

### PR-78 — Localization foundation + terminology governance (2026-06-11)
- **feat(l10n):** `Liviqa/Localizable.xcstrings` (Apple String Catalog, en source) added;
  `da` registered in knownRegions; `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`. Xcode now
  populates the catalog from code literals at build; Danish translation = export → translate →
  import, zero code changes.
- **feat(terms):** `localization/TERMS.json` — the CANONICAL glossary (Claus owns it; every
  Danish term is `proposed` until he flips it to `approved`). Locked vocabulary (nudge/indsigt,
  samtykke, borger-never-patient in citizen app, "shown, not judged", supplement/FMK boundary),
  never-translate brand list, and the banned advice-voice patterns. Console carries a copy at
  docs/TERMS.json + a [no-advice-voice] ci-guard reading it.
- **test:** TerminologyTests (T-TERM-01..03): glossary parses, no advice-voice in citizen-facing
  string literals (Views + Intelligence; patterns from the glossary), catalog present.
  126 tests in 28 suites ✅.
- Plan of record: Weblate (self-hosted, sandbox) layered on these files when Danish work starts —
  git stays the source of truth; Weblate's glossary gets seeded from TERMS.json.

_Requirements touched:_ FR-NDG (voice enforcement now mechanical), QMS terminology control.
_Risk:_ none — guards only constrain; no behaviour change.

### PR-77 — Health Vault browser, Open Banking picker, Screen Time connect (2026-06-11, CN feedback)
- **feat(vault):** Health Vault opens a FILE-LEVEL browser — 7 folders / 17 files (labs, clinical
  letters, meds, food photos, finance, consents, device exports — names consistent with LV001's
  record). Every file row carries a lock; tapping explains previews open after the live
  production test. No contents rendered.
- **feat(finance):** source row de-branded to "Bank account · Open Banking"; tap opens a
  consent-first sheet: WHY money patterns explain health patterns (daily totals + categories
  only, never transactions/merchants), the confidentiality promise (often more private than
  health data → lives in the Health Vault on device, never in any clinician share, erase in one
  tap), then a PSD2 bank picker (10 DK/EU banks — Revolut one of many). Picking a bank marks the
  source connected.
- **feat(device):** Screen Time connectable via its own one-number-per-day consent sheet.
- `DataSourceConnection` gains mutable connection state. Sim build ✅ · 123 tests ✅.

_Requirements touched:_ D-STORE, FR-PROV-01 (source transparency).
_Risk:_ none new — vault renders names only; finance connect is simulated until PSD2 integration.

### PR-76 — PatternEngine: long-horizon detectors on the citizen side (2026-06-11)
- **feat(intelligence, FR-PAT-01):** `PatternEngine` — the citizen-side twin of the console's
  generic detector engine (same detectors, same thresholds, same chart-note discipline; ids
  D-ARR-01, D-ERA-01, D-WCG-01, D-SLP-01, D-GAP-01, D-EXP-01, D-TRD-01, D-BENCH-01, D-DRIFT-01).
  Pure functions over `PatternInput` aggregates; values COMPUTED into wording, never authored;
  threshold gating (e.g. AFib stays quiet <3 months after an episode; white-coat needs ≥10 mmHg).
  One engine, any citizen — 10k-user deployments run the same functions over per-citizen inputs.
- **feat(feed):** in demo mode the LV001 findings (real mined aggregates, mirrors the console's
  LV001_INPUT) render as pattern cards in the nudge feed via the new transparency presentation —
  citizen sentence leads, "Why this?" opens the chart-note title + fact + detector id. Real-data
  path awaits the on-device summarisation pipeline (FR-PAT-02, backlog).
- Tests T-PAT-01..04 (months computed, active-phase quiet, threshold gating, seed coverage).
  123 tests in 27 suites ✅. Sim build + home screenshot ✅ (pattern cards live in the feed below
  the engine nudges; tab-level screenshot pending manual QA).
- Audit: method/thresholds per detector in the console repo `docs/pattern-register/` (shared ids).

_Requirements touched:_ FR-PAT-01 (new), FR-NDG (presentation reuse).
_Risk:_ display-only findings; no new interpretive lane.

### PR-75 — Real-data alignment + transparency-first nudge presentation (2026-06-11)
- **feat(seeds):** demo stream re-seeded to the founder's REAL mined levels (HealthKit export,
  7.1M records): RHR ~72 (workout-day bump ~76), HRV ~27 (poor-night dip ~22), sleep 7.4 h typical
  with Deep 12% / REM 20% (the 2025 regime; short nights ~5.9 kept). Console (LV001) and app now
  tell the SAME person's story.
- **feat(nudges):** new presentation — the insight sentence LEADS (full ink, 15.5pt); a "Why
  this?" expander opens the numbers behind it IN the card: evidence text, mono data-point chips,
  and the provenance line "Computed on this device · your data, your baseline · shown, not
  judged." Mirrors the console's evidence→meaning structure in the citizen's voice.
- **feat(model):** `EngineNudge` gains optional `evidence`/`points` (defaults keep all emits
  valid); card adapter passes them through, with an honest provenance default otherwise.
- Sim build ✅ · 119 tests in 26 suites ✅ · home screenshot shows real-level signals (7h09 / 28 / 75).
  ("Why this?" expansion verified by build+tests; tap-through pending next manual QA pass.)

_Requirements touched:_ FR-NDG (presentation only — allow-list untouched), FR-PROV-01.
_Risk:_ none new; transparency surface reduces misread-as-advice risk.

### PR-74 — Dual-recording workout dedup: counted once, insights from both (2026-06-11, CN feature request)
- **feat(ingestion, FR-PROV-02):** `WorkoutDeduplicator` clusters same-type workouts whose times
  overlap ≥60% of the shorter recording (the founder's real case: bike computer → Strava + Apple
  Watch logging one ride, starts ~40 s apart). One PRIMARY per session feeds all counting (tier >
  payload richness > duration); the primary is **enriched** with fields it lacks from duplicates
  (watch energy onto computer distance) — merged, never blended. Wired into
  `HealthSamples.arbitrated()` (exact-start keying missed real duals); merge report via
  `workoutMergeReport()` → `AppState.workoutMerges`.
- **feat(ui):** Data sources shows a **"Recorded twice — counted once"** disclosure card (moss)
  listing each merge: kept source, merged sources, gained fields. Inform, don't silently fix.
- **feat(demo):** MockDataProvider seeds the most recent ride as a dual recording so the card demos.
- Tests T-DED-01..05 (`WorkoutDedupTests`) + arbitration suite ✅. Sim build ✅.

_Requirements touched:_ FR-PROV-02 (new), FR-PROV-01.
_Risk:_ reduces over-counting hazard (double-counted activity inflating training-load signals).

### PR-73 — DfG onboarding lockup (2026-06-11, CN beta feedback 03:32)
- **fix(onboarding):** the DfG screen opens on the full navy canvas with the **inverted white
  logo, centred, 92pt** and the "DATA FOR GOOD FOUNDATION" kicker centred + enlarged (13pt,
  wider tracking). Snapshot hook `LIVIQA_SHOW_DFG_ONBOARDING=1`. Sim-verified. 114 tests ✅.

### PR-72 — Overnight batch: booking-request draft, Messages re-entry, test alignment (2026-06-11)
- **feat(care, DRAFT):** clinician-proposed consultation slots appear as **"Proposed time"** cards
  with inline **Accept / Decline** (`ScheduledConsult.status`, `respondToProposal`) — the citizen
  half of the Telecare-North-style request flow (FB-AOIWoD6l; final design pending CN material).
- **feat(care):** quiet **Messages** row restores the secure-messaging entry (care-team list stays
  off the front page per CN); unread badge in clay.
- **fix(test):** T-ING-02 glucose band 3.0–15.0 (a TIR 50–75% persona legitimately reaches the
  ATTD >13.9 band; the old ≤12 cap enforced clinically false seeds).
- E2E verified vs local + public sandbox (request → counter → accept → scheduled); sim screenshot
  of the proposal card. 114 tests ✅.

### PR-71 — Data screens: root-caused implausibility + per-metric clinical charts (2026-06-11)
- **Phase 0 root-cause table:**
  | Screen | Source | Why wrong/empty | Class |
  |---|---|---|---|
  | Insights TIR (flat, 100%) | demo seeds → TodaySignalsDeriver | glucose generator `6.2±1.8 floor 3.6` could never leave 3.9–10 → TIR 100%; 6 pts/day, no meals | Seed plausibility |
  | Home glucose chip 100% | same | same | Seed |
  | Metric details (4 pillars) | AreaTrendChart for all | one generic line for four data shapes | Convention |
  | Real-device empties | TodaySignalsDeriver | derive() needs ≥1 signal else demo seeds + truthful demo badge; ChartPlaceholder for hints | OK — honest by design (documented) |
- **fix(seeds):** founder-persona CGM day curve — hourly points, baseline ~6.3 mmol/L, MEAL
  EXCURSIONS 07:30/12:30/19:00 (ATTD bands; lands TIR 50–75%, mean 8–10) · RHR 52–68 with
  +4 bpm morning-after-workout · HRV 25–55 ms, lower after poor sleep · steps 4–12k with
  weekend rhythm · ~2 short nights/week which WORSEN next-day glucose (+1.1 mmol/L shift,
  amplified excursions) — cross-metric coherence matches the nudge stories. Verified: TIR 71%.
- **feat(charts):** `DailyBarsChart` (discrete days = bars, never interpolated lines; optional
  dashed goal line) — sleep + TIR weeks use it (TIR carries the 70% consensus target rule);
  RHR/HRV stay on AreaTrendChart whose personal mean±1σ band + tight y-domain already satisfy
  the baseline-deviation convention (conventions cited in code).
- Screenshots: before/after Insights (100% flat → 71% varied), glucose detail (day curve with
  meal excursions + weekly bars + 70% line), heart (baseline band), sleep (stages 16/60/24% +
  duration bars). 114 tests ✅. Out of scope (no such screens exist yet): BP, weight, AFib-burden,
  steps detail — flagged for when those surfaces are built.

### PR-70 — Video call: no name prompt, alias as identity (2026-06-11, CN beta feedback)
- **fix(consult):** the call never asks for a name — the citizen joins as their pseudonymous
  alias (**LV001**) automatically (`userInfo.displayName` on the room URL; `/me` now returns
  `alias`; demo session carries it too). Real names never enter the video layer; the console
  side stays "Care team". 114 tests ✅.

### PR-69 — Consent view fixed + beta-feedback register (2026-06-11, FB AFf8FjC1)
- **fix(privacy):** grant-card scope chips were crushed into vertical letter-shreds — the
  FlexHStack was a stub (plain HStack). Now a real `FlowLayout` (Layout protocol) + chips collapse
  to deduped consent GROUPS ("Glucose", "Activity", "Recovery"…) with lineLimit(1)+fixedSize.
  Sim-verified. 114 tests ✅.
- **docs(qms):** `qms/BETA_FEEDBACK.md` — all 10 TestFlight submissions fetched via the ASC API,
  triaged with status (3 fixed, 4 superseded, 1 narrative, booking-request workflow PROPOSED
  pending CN's Telecare North material).

### PR-68 — Consultation cleanup from live device testing (2026-06-11, CN beta feedback)
- **fix(consult):** Jitsi call is now titled **"Liviqa video call"** (no raw room id) and the
  citizen toolbar is reduced to **mic · camera · hang up** — chat/polls/invite/moderator and the
  Jitsi welcome screen are gone (`config.subject`, `toolbarButtons`, `disablePolls`,
  `disableInviteFunctions` on the room URL).
- **fix(care):** Care tab shows **Plan + In progress + Scheduled (grouped by day, calendar-style)**
  only — the "Your care team" list is removed per CN. Scheduled cards show time + clinic.
- **fix(data):** care-surface calls (consults, notifications, messages, appointments) ride the
  sandbox rail on prod builds (same DB/login) — TestFlight now gets the 4h stale-call window, the
  scheduled list, and access notifications without touching the frozen prod container.
- **feat(notify):** starting a consult auto-sends a care-team message ("I am starting a secure
  video consultation…") so the citizen is notified IN-APP the moment a call begins (push remains
  backlog; console shows a "citizen notified in-app" chip). Verified live on the sandbox.
- 114 tests ✅. Known-open: mic-mute behaviour to re-verify on device with the cleaned toolbar
  (suspected speaker/mic feedback from two devices in one room during the test).

### PR-67 — Care tab: scheduled consultations, no stale calls (2026-06-11)
- **feat(care):** new **"Scheduled"** section on the Care tab — upcoming consultations from the
  backend (`GET /appointments`): "Video consultation · <clinician> · <date/time> · Tomorrow/in N
  days". Honest empty state: *"No consultation scheduled. Your care team books these with you."*
  Old/cancelled appointments never surface (server-filtered). `ScheduledConsult` model,
  `CareConnect.fetchScheduledConsults`, `AppState.scheduledConsults` (loaded in refreshCareInbox).
- Incoming-call ring untouched. The stale "ready to talk" pile is fixed server-side (4h freshness
  window on active consults). Sim-verified vs local backend: populated + empty-state screenshots.
  114 tests ✅.

### PR-66 — DfG wallet login: real OID4VP rail + Liviqa Citizen credential check (2026-06-11)
- **feat(auth):** the first-screen DfG Wallet flow now (a) frames the present step as
  **presenting the Liviqa Citizen credential** from the My DfG wallet (sign-in IS the proof the
  credential is stored), (b) offers **"Get your Liviqa Citizen credential"** inline (real Partisia
  issuance via the UC-A rail; sandbox backends only, `Config.walletIssuanceEnabled`), and
  (c) drives the **REAL `/auth/wallet/start` → poll `/auth/wallet/result` rail** when a sovereign
  backend is reachable — the verified ref derives from the backend's pseudonymous subject. Graceful
  fallback to the timed walkthrough when no backend (TestFlight prod unaffected). DEBUG hooks:
  `LIVIQA_OPEN_DFG=1`; `LIVIQA_WALLET_STEP=verifying` now runs the live verification.
- Sim-verified vs local backend: present step (credential rows + issue link) and verified step
  with a REAL subject-derived CE ref (UUID-tail, not the sim's hex). 114 tests ✅.
- **feat(config):** wallet rails now WORK on TestFlight — on prod builds they are ROUTED to the
  sandbox container (`Config.walletRailBaseURL`; same DB + JWT secret as prod, so the same login
  works) instead of hidden. Verified: prod GoTrue token (citizen account) → sandbox
  `/issuance/citizen-credential` → 201, real Partisia offer. Prod backend itself untouched
  (Kim's rule: credential rails stay sandbox-side).

### PR-65 — Wallet follow-on UCs: expiry/renewal UX + UC-24a/b receipts (2026-06-10)
- **feat(wallet):** short-validity/renewal UX — the Privacy "Your credential" row shows
  "Valid until <date> · tap to renew" (persisted `citizenCredentialValidUntil`); the credential
  sheet carries a moss validity line ("short validity by design — renew any time").
- **feat(UC-24a):** grant Share Receipts now carry a REAL on-device existence proof
  ("Data history on record: N days · computed on device") — eligibility pre-screening without
  moving data.
- **feat(UC-24b):** per-journal-entry **ePRO provenance receipt** (checkmark-seal action on entry
  cards; prefers a study grant) — attests "recorded on device under an active grant", never the
  content (ALCOA+). DEBUG `LIVIQA_DEMO_EPRO=1`. Sim-verified vs local backend (real Partisia QR).
- 114 tests ✅.

### PR-64 — UC-A: Liviqa Citizen credential issuance into My DfG (2026-06-10)
- **feat(wallet):** "Your credential" row on Privacy → issues the citizen's own **Liviqa Citizen**
  sign-in credential (pseudonymous: role + member id + date) via `POST /issuance/citizen-credential`
  on the sovereign backend → REAL Partisia-sandbox offer rendered as QR + same-device deep link
  (`ShareReceiptSheet` gains a `.citizenCredential` kind). `SovereignSharing.issueCitizenCredential`,
  `AppState.issueCitizenCredential`. DEBUG `LIVIQA_DEMO_CITIZEN_CRED=1`.
- Verified live on Sim against localhost:3001 (partisia mode): real `haip-vci://` QR. 114 tests ✅.

### PR-63 — iGrant.io wallet + 2×2 identity-wallet grid (2026-06-10)
- **feat(auth):** added `IDProvider.iGrant` (iGrant.io EUDI Data Wallet, teal; SD-JWT selective disclosure
  + consent receipt). Sign-in now offers four identity wallets in a 2×2 grid: AltID · e-Boks ID ·
  iGrant.io · DfG Wallet. Verified on-device. Build ✅, 114 tests ✅.

### PR-62 — AltID + e-Boks ID identity-wallet login (simulated eIDAS 2.0) (2026-06-10)
- **feat(auth):** `IDProviderLoginView` — reusable simulated identity-wallet sign-in. `IDProvider.altID`
  (Denmark's official EUDI / eIDAS 2.0 wallet — EUDI blue; unlock → selective disclosure with
  zero-knowledge proof, e.g. "Over 18" without revealing date of birth → verify → EUDI ref) and `.eBoks`
  (e-Boks ID wallet — burgundy; proof-of-age, "you decide when/where"). Three sign-in identity options now:
  AltID · e-Boks ID · DfG Wallet. Brand-coloured authority grounds; descriptive, no "simulated" labels;
  text wordmarks (not official logos). `Config.nationalIDLoginEnabled`; `AppState.signInWithProvider`.
- Verified: AltID/e-Boks steps screenshot-clean; AuthView shows all 3 options; live verify auto-run
  mirrors the DfG flow. Build ✅, 114 tests ✅.

### PR-61 — DfG Wallet login flow (eIDAS 2.0 + Partisia, simulated) (2026-06-10)
- **feat(auth):** `DfGWalletLoginView` — in-app, high-fidelity simulation of the DfG Wallet identity
  use cases for demos/pilots (no live Partisia backend): unlock → selective disclosure (prove facts,
  hide name/DOB/address) → Partisia verification (MPC signature + CE-ledger anchoring) → "Verified with
  Partisia" + CE ref → into Liviqa. DfG-branded navy authority ground; descriptive, no "simulated" labels.
- **feat(auth):** "Continue with DfG Wallet" on `AuthView` (`Config.dfgWalletLoginEnabled`);
  `AppState.signInWithDfGWallet`; Settings shows a "Verified with Partisia · CE ref" badge.
- Verified live (tap-through auto-ran verification, generated CE ref). Build ✅, 114 tests ✅. Care tab restored (10.21).

### PR-60 — Real data across all surfaces + sleep made real (production integrity) (2026-06-10)
- **feat(sleep):** `SleepDeriver` — last-night Deep/Light/REM breakdown + asleep total + nightly week
  from on-device HealthKit; mock sleep enriched into stages; `AppState.sleepSummary`. Sleep detail shows
  real stages/headline/trend (demo fallback). +5 `SleepDeriverTests`.
- **feat(integrity):** all pillar detail screens + Insights now show the user's REAL derived values and
  week series (`TodaySignals` + `correlationWeek`); the illustrative delta is hidden whenever the value
  is real; glucose "Today" curve uses today's real readings (`TodaySignals.glucoseToday`).
- **feat(arch):** app-level one-time `refreshFromHealth` in `MainTabView` (every tab has data regardless
  of entry tab) + `isRefreshing` reentrancy guard.
- **test:** suite 106 → 114 green. 5-tab smoke clean.

### PR-59 — Data-visualization overhaul (Oura/Whoop caliber, brand-locked) (2026-06-10)
- **feat(viz):** `AreaTrendChart` upgraded — smoothed Catmull-Rom curves, left y-axis scale (max/mean/min,
  unit-aware), the personal **"your normal" band** (mean ±1σ of the user's OWN data — descriptive, not a
  clinical range) with a dashed mean line, subtle data-point dots. Lifts Insights (TIR + Recovery/HRV),
  all pillar detail screens, and nudge evidence at once. Units wired (% / ms / bpm / h).
- **feat(viz):** `MiniSparkline` — 7-day micro-trend under each Home signal chip. `TodaySignals` gains
  real per-day series (`sleepWeek/inRangeWeek/hrvWeek/rhrWeek`), derived in `TodaySignalsDeriver` (one
  value per day WITH data, ≥2-point rule, no fabricated zeros; demo week in demo mode, no spark when
  real-but-missing).
- **feat(viz):** `GlucoseCurveView` rebuilt (smoothed, y-axis with personal target high/low, NOW dot)
  and surfaced as a CGM-style "Today" curve inside the moss target band on the glucose detail; sleep
  detail now shows stages + weekly trend. All descriptive-only / brand-locked.
- **test:** +3 week-series cases (`DeriverRobustnessTests`). Suite 106 → 109 green.

### PR-58 — Go-live readiness (Wave 1–5): real HealthKit default + ship polish (2026-06-10)
- **feat(ingestion):** real on-device HealthKit is now the DEFAULT provider on a Health-capable
  platform (`AppState.resolveProviderKind` + `HealthProviderFactory.isRealHealthDataAvailable`);
  Simulator / no-Health / `-uiTestAutoDemo` / `LIVIQA_DATA=mock` fall back to demo. `usingRealData`
  drives the "Demo data" flag accurately (true only after a non-empty HealthKit fetch).
- **fix(integrity):** with real data the nudge feed trusts the engine even when empty — never shows
  `MockData` seeds unlabelled as the user's own (no-AI-tell). Build bump 1.0 (10.18 → 10.19).
- **a11y:** Dynamic Type confirmed working (clamped tab bar + Home chips so chrome doesn't wrap at
  accessibility sizes); `AreaTrendChart` accessibilityValue summary; "Back"/"Send message" labels;
  care thread loading state.
- **feat(journal):** private journal now persists across relaunch — `JournalStore` (JSON in App
  Support, `.completeFileProtection`, on-device only; injectable URL for tests); `JournalView` loads
  saved entries / auto-saves on change. MVP gap closed.
- **fix(crash-safety):** audited derivation+render path for sparse/empty real data (no `Int(NaN)` traps,
  guarded divisions, gated force-unwraps); the new real-data default is crash-safe.
- **test:** `ProviderResolutionTests` (6) + `DeriverRobustnessTests` (5) + `JournalStoreTests` (4).
  Suite 91 → 106 green. Release config compiles.
- **docs:** `GOLIVE_CHECKLIST.md` (human Apple steps), `docs/APP_PRIVACY_NOTES.md`, `HANDOFF_TO_BACKEND.md`,
  `SESSION_iOS_GOLIVE.md`. Frozen backend contract untouched; Share-Receipt wallet preserved.

### PR-57 — Fix "can't see the message" in care threads (beta feedback) (2026-06-10)
- **fix(ui):** `MessageThreadView` — explicit composer text colour (never follows the
  system label colour, so typed text stays visible in any appearance); reliable
  scroll-to-latest on open / new message / keyboard focus (latest no longer hidden
  behind the keyboard); interactive keyboard dismiss; stronger recipient-bubble
  separation; selectable text. `DEBUG LIVIQA_OPEN_THREAD` deep-link for verification.
- Verified prior beta items already in place: consent token collapsed under "Technical
  details" (`ConsentLedgerView`); DfG logo + high-contrast balance card (`TokenWalletView`).
  Care/video-consult **flow** rework remains a separate, larger track.

### PR-56 — Rich detail screens (Phase 5) — tap a Home pillar → descriptive detail (2026-06-10)
- **feat(ui):** `MetricDetailView` (Sleep/Glucose/Recovery/Heart). Sleep shows a
  **stages timeline** (Deep/Light/REM/Awake stacked bar + legend, mins + %, "time
  asleep of in bed"); the others show a week `AreaTrendChart`. Each screen carries the
  big value, a delta pill, a descriptive observation ("a pattern in your own data, not
  a medical finding"), and a "Discuss in the assistant" hand-off.
- **feat(ui):** Home signal chips are now tappable — `NavigationLink(WellnessPillar)` +
  `navigationDestination`. Oura-depth presentation, **descriptive-only / non-MDSW** (no
  scores, verdicts, prediction, or advice).

### PR-54/55 — Liviqa Watch app (watchOS) — descriptive wellness glance (2026-06-10)
- **feat(watch):** `LiviqaWatch/` scaffold — `WatchHomeView` (calm affirming line +
  wellness pillars Glucose/Sleep/Recovery/Heart, two-state moss/clay), `WatchModels`
  (descriptive snapshot), `WatchTheme` (locked Midnight palette), `LiviqaWatchApp`.
  Descriptive-only, non-MDSW (no scores/verdicts/advice — same line as the phone).
- **feat(watch):** WatchConnectivity — `PhoneWatchSync` (iOS→watch descriptive
  app-context push) + `WatchSessionReceiver` (live snapshot, mirrors in-range to the
  App Group, reloads the complication).
- **feat(watch):** `LiviqaComplication` (WidgetKit watchOS) — descriptive in-range
  face complication (circular/rectangular/corner/inline).
- watchOS + Widget **targets must be created in Xcode** (cannot hand-edit pbxproj
  safely); source is inert until then (iOS build unaffected). See
  `LiviqaWatch/README_SETUP.md`.

### PR-50–52 — v2 redesign (calm wellness companion): nav IA · Home · Stress pillar (2026-06-10)
- **feat(ui):** 5-tab IA Home·Insights·Journal·Privacy·Settings (Care off the bar);
  Home leads with a calm affirming state + wellness-pillar signals (Recovery = stress
  axis, descriptive); Insights gains a descriptive Recovery·Stress (HRV) trend.
  Design System v2; brand + two-state colour intact; descriptive-only.

### PR-53 — Assistant hand-off (Phase 4) — "Discuss in the assistant"
- NudgeDetailView gains a "Discuss in the assistant" secondary CTA; Insights recovery
  card gains "Ask the assistant about this →". Opens the guarded chat (appState.showAssistant).
  Liviqa's descriptive-only version of Oura's "Dive in with Advisor".


### PR-49 — Assistant: visible entry point + build 1.0(10.17) (2026-06-09)
- **fix(ui):** added a visible ✨ "Ask" button in the app bar (next to the avatar) on
  every main screen → opens the assistant directly. Was previously only reachable via
  a buried row in the profile sheet. `AppState.showAssistant` + MainTabView sheet.
- build bump 10.16 → 10.17 for TestFlight.


### PR-48 — Assistant: contextual questions from the nudge engine (2026-06-09)
- **feat(chat):** `ChatSuggestions` — descriptive, pre-vetted follow-up questions keyed
  to the user's current nudges (sleep / glucose / HRV / activity). Cardiac / heart-rhythm
  nudges (route-to-clinician) produce **no** questions. Chat starter now shows
  "Based on what your data showed" with contextual prompts; falls back to defaults.
- **feat(data):** HRV added to `ChatHealthSummary` (+ responder + cloud context) so
  recovery-themed questions are answerable.
- **test:** `ChatSuggestionsTests` — every offered question stays in scope (guard never
  refuses a suggestion); cardiac → defaults only. 13 chat tests total green.
- Whoop/Oura-style companion pattern, mapped to descriptive-only (non-MDSW): the engine
  finds the pattern, the assistant describes it on request — never interprets/advises.


### PR-47 — Assistant: Mistral cloud "Enhanced" mode (opt-in) (2026-06-09)
- **feat(chat):** `MistralClient.swift` — Mistral EU chat-completions (mistral-small-latest);
  `ChatEngine.respondCloud` runs the deterministic guard BEFORE (no out-of-scope ask
  reaches Mistral) and AFTER (drift → safety line), with on-device fallback on error.
  Only the user's own summarised numbers (`promptContext`) are sent — never raw samples.
- **feat(ui):** "Enhanced answers (cloud)" consent toggle is now live (enabled only when a
  key is present); off = on-device deterministic answers (default). Async send + thinking
  state; assistant markdown emphasis stripped for display.
- **security:** API key in gitignored `Liviqa/Secrets.swift` (template committed); NOT in
  git. Key still ships in the binary → move behind an api.liviqa.app proxy before public
  release (flagged). Verified live: Mistral answered descriptively; guard tests still green (10).


### PR-46 — Wellness-scope AI assistant (non-MDSW) + deterministic guard (2026-06-09)
- **feat(chat):** `Liviqa/Chat/LiviqaChat.swift` — wellness-scope assistant: fixed
  copy (intended purpose / static safety line / AI label / system prompt),
  **deterministic `ChatGuard`** (input refusal + output sanitise; blocks prediction/
  prognosis/diagnosis/symptom/triage/treatment → safety line; strips imperatives +
  sexual-function meds), `LocalDataResponder` (descriptive-only, on-device), `ChatEngine`
  (guard-first/guard-last). Compliance authority: counsel memo (06_Regulatory).
- **feat(ui):** `ChatView.swift` — standalone consent (3 toggles, defaults off,
  withdrawable; cloud + research wired-but-disabled), persistent AI label, descriptive
  chat. In-memory history only (no persistence); withdrawal purges + resets consent.
  Entry = one row in ProfileSheet (brand/chrome/nav unchanged).
- **test(chat):** `LiviqaTests/ChatGuardTests` — 10 acceptance tests green (red-team
  prompts → safety line; descriptive answered; drift blocked; meds stripped; copy clean).
- **build:** on-device default; cloud "Enhanced" mode NOT built. No real LLM yet
  (deterministic). Open decision (LLM/cloud) flagged to DfG Works. See
  docs/AIChat_BuildNote_v01.md.
- Verified: builds (iOS Sim); consent + chat screenshots on Midnight.


### PR-52 — TestFlight 1.0(10.11–10.12) — beta-feedback UI fixes + Midnight contrast sweep (2026-06-09)
- **fix(ui) [beta feedback]:** read the 4 TestFlight `betaFeedbackScreenshotSubmissions`
  via the ASC API and fixed each (tester on Midnight/dark theme):
  - **DfG Tokens (`TokenWalletView`):** the cost pills + In-app/Charity toggle used
    `LiviqaTheme.ink` (a TEXT colour, light in Midnight) as a *background* with white
    text → white-on-cream, unreadable. Swapped to `invertBG`/`invertFG`. Balance card
    now shows the **DfG logo** (`dfg-logo`/`dfg-logo-negative`), not the Liviqa mark.
  - **`ConsultView` secure shell:** `fill(ink)` + white text → fixed always-dark
    video stage (`#0C1520`); avatar tint to a light overlay.
  - **`AreaTrendChart` (TIR graphic):** gradient area fill boosted 0.45/0.06 → 0.55/0.10
    so it reads on dark (the "graphic does not work" report was an older build w/o fill).
- **fix(ui) [NFR-UI contrast]:** swept ALL views for the Midnight trap — `ink`/`paper`
  used as a surface, hardcoded white surfaces, flipped-text. Zero offenders remain;
  verified Midnight Home renders clean.
- **fix(settings):** theme-picker `@AppStorage` default was `.midnight` while the app
  defaults to `.paper` → picker showed the wrong selection on fresh install. Aligned to
  `.paper`. Stale "video off" comment in `MessagesView` corrected (video is on).
- **build(release):** 10.10 → **10.11** (feedback) → **10.12** (settings/contrast), via
  the new `scripts/archive_upload_isolated.sh` (headless build through an isolated
  keychain — sidesteps the locked login keychain that hung codesign; restores the
  search list on exit, no login-keychain changes, no lost passwords).

### PR-51 — Console GoTrue login + onboarding-reinstate + live Home data (2026-06-09)
- **feat(console) [sandbox.liviqa.app]:** real GoTrue login replacing the rejected
  `dev-*` bearer tokens — role buttons authenticate per seeded account (link-by-email),
  no `DEV_AUTH`, no dev token in the bundle. Reset the 4 role passwords via the GoTrue
  admin API. In-app persona switcher removed (role from the account); Sign out → /login.
- **feat(ios) [start flow]:** onboarding-version gate replays the consent/start flow once
  (it had stopped appearing because the `hasSeen*` flags persisted) + re-prompts HealthKit.
- **feat(ios) [own data]:** Home signal chips + insight hero now driven by live HealthKit
  (`TodaySignalsDeriver`); Data Sources gained Connect-Health-&-sync + Import-a-file.
- **infra:** self-hosted Jitsi white-labelled to "Liviqa" (watermark off, runtime patch).

### PR-50 — TestFlight build 1.0(10.9) — Design System v2 screen build-out (2026-06-09)
- **feat(ui) [NFR-UI-*]:** built the remaining v2 screens from the locked design
  explorations (`_liviqa_design_reference/.../explorations/`), reusing the v2 token
  layer — no brand/logo/palette changes (iterate-on-locked rule):
  - **Correlation moment** (`NudgeDetailView`) → Alternative C: plain declarative
    sentence → one confirm chart → always-on evidence metadata (N·baseline·r·p) →
    named lever → "see the data" depth tier. **Still-learning state** (refuse to
    assert below the gate r≥0.4/p≤0.05/N≥need) implemented — the trust mechanism.
  - **Evidence components** (`EvidenceComponents.swift`): `ConfidenceChip`
    (gated/emerging/learning), `EvidenceMetadataRow`, `LeverCallout`,
    `SingleConfirmBar`, `BaselineProgressBar`, `NavBackHeader`, `FlowRow`.
  - **Baseline** → the **Aperture-arc gauge** (`ApertureArcGauge` + `MetricBaselineView`):
    open ring, moss arc = your normal band, today's dot on it, **never a 0–100
    percentile**; reachable from the passport wellness rows. Clay when it drifts.
  - **Week** (`WeekInContextView`) → two-state heatmap (moss in-range / clay worth-
    noticing) with the lit **cluster column** highlighted + named.
  - **Journal** → tap-first **quick-capture** grid (mood/meal/symptom/voice/upload)
    + context suggestions + mood sheet; every entry marked "🔒 on device" (the v1
    emotional-load fix: lead with actions, not a blank prompt).
  - **Consent history** (`ConsentLedgerView`) → Alternative A plain-language
    timeline with pins + "✓ verified" + "Technical details ›".
  - **Privacy** (`InAppPrivacyView`) → "circle of trust": nothing shared by default,
    per-recipient grant cards, **one-tap pause with an immediate receipt** (shows
    its work, not a spinner). Legal/MDR prose moved below the fold.
- **feat(model):** additive `NudgeEvidence` on `Nudge` (confidence, N, baseline,
  r, p, lever, chart, still-learning) — populated on demo nudges to exercise all
  three confidence states. Non-breaking (defaults nil).
- **chore(reg) [FR-REG-03]:** genericised the nudge share copy (no condition /
  recipient hard-coding). Kept current tab IA (Today·Trends·Wallet·Care·Journal) —
  the 5-tab rename stays HELD for Claus (and Care is needed for video). No new
  insulin/AFib nudge copy (RQ-01 still open).
- **build(release):** `CURRENT_PROJECT_VERSION` 10.8 → **10.9**. Today screen
  verified on the simulator (Paper ground, Home-C hero); all screens compile clean
  (sim build SUCCEEDED). Ships video (PR-49) + this build-out together.

### PR-49 — TestFlight build 1.0(10.8) — sovereign video consult ON (2026-06-09)
- **feat(consult) [NFR-SEC-07 SATISFIED]:** live video for the Care/consult flow,
  on a **self-hosted EU Jitsi** (Scaleway fr-par; instance `liviqa-jitsi`, public
  `163.172.173.186` → `163-172-173-186.sslip.io`, docker-jitsi-meet stable-9646,
  Let's Encrypt/ZeroSSL TLS, `ENABLE_AUTH=0`/`ENABLE_GUESTS=1`, `JVB_ADVERTISE_IPS`
  set). Verified live: web 200 over valid TLS, prosody ws + BOSH 200, arbitrary
  rooms serve. This closes the NFR-SEC-07 control that barred a US-parented video
  provider on the PII path — no `meet.jit.si`, EU-sovereign self-host instead.
  (Sovereignty rule consciously waived for Jitsi-the-OSS this session; we still
  self-hosted in-EU rather than using a US public instance.)
- **feat(consult):** `Config.videoConsultEnabled = true`; `Config.jitsiDomain` →
  new `jitsiSovereignDomain`. `Info.plist` gained `NSCameraUsageDescription` +
  `NSMicrophoneUsageDescription`. `ConsultView` `WKWebView` grants getUserMedia
  (WKUIDelegate `requestMediaCapturePermissionFor` → `.grant`) and pins
  `#config.disableDeepLinking=true&prejoinPageEnabled=false` so the call stays
  in-app. Deterministic room `liviqa-consult-<id>` unchanged.
- **feat(console):** B2B console `VITE_JITSI_DOMAIN` repointed meet.jit.si → the
  sovereign host; rebuilt + redeployed to `sandbox.liviqa.app` (rclone sync + Edge
  purge). Citizen + clinician now land in the same room on the same EU server.
- **build(release):** `CURRENT_PROJECT_VERSION` 10.7 → **10.8**; archived + uploaded
  headlessly (API key `656L9P8JY3`, issuer `830c96d2…`). Upload UUID
  `a76b4e78-7853-44d2-baf8-72dd4de4ec0e`. Compiles clean (sim build SUCCEEDED).
- **Hardening (open):** move behind `meet.liviqa.app` (A record), lock SG to
  80/443/4443/UDP-10000, decide recording storage/retention before prod recording.

### PR-48 — TestFlight build 1.0(10.5) — HealthKit-connect pilot (2026-06-09)
- **build(release):** `CURRENT_PROJECT_VERSION` 10.4 → **10.5**; archived + uploaded
  to TestFlight **headlessly** via `scripts/archive_upload.sh` + the App Store
  Connect API key (`656L9P8JY3`) — `xcodebuild -allowProvisioningUpdates` minted
  the Apple **Distribution** cert + App Store profile under the DfG account
  (PS258XSNL8), bundle `dev.liviqa.app`. `Config/ExportOptions.plist` team confirmed
  PS258XSNL8. Upload UUID `e7732e90-7101-422d-8a82-1ae01ae57fd1`.
- **Ships:** PR-46 full HealthKit capture + Connect→authorize wiring + PR-47 Paper/
  clay. Release config = `sovereignProd` (api.liviqa.app, health 200), `authEnabled
  = false` (demo sign-in), video gated off.
- **Tester scope:** connect HealthKit → real on-device data renders (the pilot
  goal). **Backend derived-share upload needs auth** (`authEnabled`/GoTrue JWT —
  ClickUp Sprint-0 P0); demo mode has no sovereign session, so the push is a no-op.
  A follow-up build flips auth once GoTrue is verified end-to-end.
- Verified: ARCHIVE/EXPORT/UPLOAD all succeeded; build processing in App Store Connect.

### PR-47 — Design System v2 foundation: Paper default + clay attention tone (2026-06-09)
- **feat(theme):** added the Design System v2 signal tokens to `Liviqa/Theme.swift` —
  `clay`/`clay2`/`clay3`/`clayText`/`clayRev` (the single patient "worth noticing"
  attention tone, `#BD7A33`), the confidence ramp (`confHigh`/`confEmerging`/
  `confLearning`), the semantic type scale (`liviqaH1/H2/Body/Caption`) and
  `LiviqaTheme.Tracking`. Base palette already matched the design's `colors.css`
  (same `Liviqa_Design_Tokens_v01` source); Lato + IBM Plex Mono already bundled.
- **feat(theme) [NFR-UI-CLAY-01 / FR-REG-02]:** swept the patient view layer from
  `LiviqaTheme.amber` → `LiviqaTheme.clay` (`amber2`→`clay2`) across
  `Liviqa/Views/*.swift`. Rationale: amber reads as a warning light; the app is
  pitched below the medical-device line with a never-diagnostic voice, so the
  attention tone must NOT be an alarm. Two-state patient logic: moss = in-range,
  clay = worth-noticing. (Amber token retained for engine/console use.) This is a
  regulatory-relevant choice — clay avoids threshold/alarm framing (FR-REG-02).
- **feat(theme) [NFR-UI-THEME-01]:** default theme flipped Midnight → **Paper**
  (`LiviqaApp.themeModeRaw`), the design ground. Midnight still selectable in
  Settings; dynamic tokens flip the whole app via the single root scheme.
- Source: `claude.ai/design` handoff bundle (`_liviqa_design_reference/`), chat
  intent + locked screen directions (Correlation C, Home C, Baseline arc, Week
  heatmap, Consent A, Privacy one-tap, Journal quick-capture, 5-tab IA).
- Verified: `xcodebuild` (iOS Sim) BUILD SUCCEEDED; LiviqaTests 78/78 green;
  Today screen screenshotted in Paper + Midnight — glucose arc now moss→clay.

### PR-46 — Full HealthKit capture (Step A) + auth wiring + ingestion fixes (2026-06-09)
- **feat(ingestion) [FR-ING-01]:** expanded the HealthKit read set from the 7-type
  MVP set to the full capture set — added insulin delivery, AFib burden, blood
  pressure (sys/dia correlation), body composition (mass/fat%/lean/BMI), and the
  extended heart/respiratory panel (heart rate, walking HR, HR-recovery,
  respiratory rate, SpO₂, VO₂max). New value types + readers in
  `HealthSamples.swift` / `HealthKitService.swift`; arbitration extended
  (`SourceArbiter`); persisted into the existing `@Model` entities + idempotent
  replace helpers (`IngestionCoordinator`). Still **read-only** — share/write set
  stays empty (FR-ARCH-04). Identifiers bound via `if let` so unsupported types
  are skipped, not compile errors.
- **fix(onboarding) [FR-ING-01/02]:** the HealthKit primer "Connect" now actually
  requests read authorization + switches off demo data (`AppState.dataProviderKind
  = .healthKit` + `refreshFromHealth()`); skip stays on demo (never an error state).
  Previously the button only set the seen-flag → live ingestion never triggered.
- **fix(ingestion) [FR-ING-09, T-MAP-02]:** re-sync idempotency — the window-replace
  delete now covers the union of the requested window and the inserted rows' span,
  so a daily/boundary sample whose timestamp falls just outside the window is no
  longer re-inserted on every sync (was: 48 glucose rows where 42 expected). Fixes
  a pre-existing `reSyncIsIdempotent` failure. No data dropped.
- **fix(test):** `NudgeEngineTests` fixture gave the baseline HRV zero variance
  (constant 55) — always in-band by design (see `baselineBands`), so the low day
  never fired the recovery nudge. Gave the baseline realistic variance. Pre-existing
  failure, now green.
- **test(healthkit):** `readSetIsMvpReadSet` → `readSetIsFullCaptureSet` — asserts
  the MVP types + the new capture types are present and the set is ≥20.
- Regulatory posture unchanged at the data layer: **insulin stays dose-blind**
  (`FR-REG-04`, InsulinDose data-source only, no surface), **AFib stays
  display-only** (`OD-11`/D9), new readings are `provenance = .real`, tier
  good/estimate (never clinical). Rendering/nudging of the new signals = Step B.
- Verified: `xcodebuild` (iOS Sim) BUILD SUCCEEDED; LiviqaTests **78/78 green**
  (2 pre-existing failures fixed); baseline-stash confirmed Step A added zero new
  regressions.

### PR-45 — Demo-first TestFlight build for UI testing (auth gated) + 1.0(10.4) (2026-06-04)
- **feat(config):** `Config.authEnabled` (default **false**). While false the auth
  screen hides the live Apple + email sign-in and shows a single **"Enter Liviqa"**
  (demo) entry — TestFlight UI testers never hit a broken sign-in (GoTrue secret
  not yet verified end-to-end; Apple provider disabled; GoTrue signup disabled).
- Rationale: UI testing must not depend on the backend/auth layer. Demo mode
  renders all 5 screens with deterministic synthetic data. Flip `authEnabled` true
  once `SUPABASE_JWT_SECRET == GOTRUE_JWT_SECRET` is confirmed + Apple enabled
  (see docs/Auth_Deploy_Handoff_v01.md).
- **build(release):** `CURRENT_PROJECT_VERSION` 10.3 → **10.4**.
- Verified: builds (iOS Sim); auth screen shows white aperture logo + lone
  "Enter Liviqa" on Midnight.

### PR-44 — TestFlight feedback fixes: secondary-screen Midnight contrast (2026-06-04)
- Source: 3 TestFlight beta-feedback items on build 1.0(10.2) (iPhone 16, iOS 26.6).
- **fix(ui) [fb3 "Check Color on buttons"]:** `NudgePrimaryButtonStyle` used
  `LiviqaTheme.ink` as a surface + white text → cream-on-cream (invisible) on
  Midnight. Now invert tokens. Affected "Open"/"Show pattern" nudge CTAs.
- **fix(ui) [fb2 "Same"]:** `NudgeDetailView` had a hardcoded `Color.white` card
  (pale text unreadable on Midnight) + a dark-green RGB body/stroke on the share
  card. Now `paper2`/`ink2`/`moss3` tokens; flat `ChartPlaceholder` replaced with
  the gradient `AreaTrendChart`.
- **fix(ui) [fb1 "Graphic for Time in range does not work"]:** `AreaTrendChart`
  fill was nearly invisible on Midnight (moss .30 over dark). Strengthened
  gradient (.45→.06) + added baseline gridlines so it reads as a chart.
- **fix(ui) sweep (same root cause, reachable secondary screens):**
  PrivacyDeclaration "Understood" + DfGOnboarding "Got it" buttons, ProfileSheet
  count badge, and the TokenWallet balance card — all `ink`-as-surface+white →
  invert tokens. TokenWallet's code-drawn `apertureMini` (brand-rule violation)
  replaced with the locked `LiviqaApertureMark` asset (theme-aware variant).
- ConsultView shell left as-is (behind disabled `videoConsultEnabled` flag, v1).
- Verified: builds (iOS Sim); Trends TIR chart screenshot shows visible fill+grid.

### PR-43 — TestFlight build 1.0(10.2) + ASC attach helper (2026-06-04)
- **build(release):** `CURRENT_PROJECT_VERSION` 2 → **10.2** (MARKETING_VERSION
  unchanged at 1.0) — updates the existing **1.0 internal test train**
  (TestFlight shows `1.0 (10.2)`). Archived → exported → uploaded (altool:
  *UPLOAD SUCCEEDED*, Delivery UUID `f6667962-…`).
- **chore(ci):** `scripts/asc_attach_build.py` — stdlib-only App Store Connect
  client (ES256 JWT signed via openssl, DER→raw conversion) that polls a build's
  `processingState` until VALID and reports group assignment.
- **verified:** build reached **VALID**; export compliance pre-answered
  (`ITSAppUsesNonExemptEncryption=false` → API `usesNonExemptEncryption:false`);
  not expired. Internal **Internal DfG** group auto-distributes processed builds
  (API confirms internal groups can't be manually assigned: 422
  `ENTITY_UNPROCESSABLE`), so 1.0(10.2) is live for internal testers.
- No requirement/risk-control change; release-engineering only.

### PR-42 — Oura redesign #8: theme-aware aperture logo (white ring on Midnight) (2026-06-04)
- **fix(brand):** `LiviqaApertureMark` now auto-selects the asset variant from
  `colorScheme` — **reversed** (white `#F7F5F1` ring, the locked dark-bg brand
  mark) on Midnight, **primary** (ink ring) on Paper. `reversed:` is now an
  optional override, kept only for the Wallet watermark on an invert surface.
- **fix(ui):** app bar / AuthView / PrivacyDeclaration / Care empty-state marks
  switched from forced `reversed: false`/`true` to auto → the logo was invisible
  (dark mark on dark) and read like a faint spinner on Midnight; now visible.
- Locked aperture **asset unchanged** (no code redraw, brand cardinal rule); no
  rotation on the mark (the only `rotationEffect`s are chart ring trims).
- Verified: builds (iOS Sim); Today app-bar logo renders the white ring on Midnight.

### PR-41 — Oura redesign #7: runtime Display options + demo-chip default-off (2026-06-04)
- **feat(ui):** SettingsView **DISPLAY** zone — Theme segmented (Midnight/Paper →
  `liviqaThemeMode`, drives root tokens), Reduce-motion toggle (`liviqaReduceMotion`,
  read by `LiviqaMotion`), Demo-data-chip toggle (`liviqaShowDemoChip`). All three
  are real (no dead toggles); each writes `@AppStorage` consumed by live code.
- **fix(brand):** `liviqaShowDemoChip` **defaults OFF** — the "Demo data" chip is a
  forbidden `demo` label on customer-facing UI (CLAUDE.md cardinal rule); hidden by
  default, toggle retained for the real-vs-cohort integrity marker (FR-ARCH-05).
- **fix(ui):** profile avatar (Settings) + tab-bar avatar use invert tokens (were
  `ink`+white → invisible on Midnight).
- Verified: builds (iOS Sim); Paper/Midnight switch confirmed end-to-end; Today
  renders with no provenance label by default.

### PR-40 — Oura redesign #6: Journal Midnight contrast (2026-06-04)
- **fix(ui):** JournalView selected calendar-day pill, active filter chip, and FAB
  used `LiviqaTheme.ink` as a *surface* + white text → invisible on Midnight.
  Switched to invert-surface tokens. No copy/data-model change.
- Verified: builds (iOS Sim); calendar/filter/FAB all legible on Midnight + Paper.

### PR-39 — Oura redesign #5: Care surface + demo threads (2026-06-04)
- **feat(ui):** demo care-team threads (`MockData.demoCareThreads` — Nurse/Coach/GP)
  seeded into demo sign-in so the Care tab shows content; `MessageThreadView` demo
  message fallback + local send when no live backend.
- **fix(ui):** thread-row avatar invert tokens (was invisible on Midnight); richer
  empty-state card (aperture + headline) when genuinely unconnected.
- Verified: builds (iOS Sim); Care list + avatars legible on Midnight.

### PR-38 — Oura redesign #4: Wallet invert summary + CE toast (2026-06-04)
- **feat(ui):** Wallet summary card now an **invert surface** (was `ink`+white →
  invisible on Midnight); watermark aperture mark theme-aware; replaced bespoke CE
  toast with shared `LiviqaToastData` + `.liviqaToast` (withdraw → rust dot).
- Verified: builds (iOS Sim); summary card + watermark + "LV" avatar legible.

### PR-37 — Oura redesign #3: Trends (gradient trend + interactive grid) (2026-06-04)
- **feat(ui):** `AreaTrendChart` (generic gradient-area line + draw-in) in
  OuraComponents. WeekInContextView: TIR trend hero; 7-day grid cells now tappable
  → **day-readout** with StatusPill; theme-aware level fills (model `.color` was
  light-only hex); row/col highlight + selection ring.
- **feat(dev):** `LIVIQA_TAB` env (DEBUG) to deep-link the initial tab for snapshots.
- **fix(ui):** tab-bar/Today avatar contrast on Midnight (invert tokens).
- Verified: builds (iOS Sim); Trends renders gradient chart + interactive grid.

### PR-36 — Oura redesign #2b: Today screen wired (2026-06-04)
- **feat(ui):** TodayView radial **glucose hero** (RingView 68% TIR + glow + mono
  6.2 mmol/L + In-range StatusPill + GlucoseCurveView + stat row) and **mini-ring
  vitals** (Sleep/HRV/Steps), replacing the old flat rings row. Copy/data unchanged.
- **chore:** demo profile name → `LV001` (no real names, per task); DEBUG
  `-uiTestAutoDemo` launch hook for headless snapshotting.
- Verified: builds (iOS Sim); Today renders the Oura hero on Midnight + Paper.

### PR-35 — Oura redesign #2: shared ring/curve/toast components (2026-06-04)
- **feat(ui):** `OuraComponents.swift` — `RingView` (gradient moss→amber arc +
  glow + draw-in, resting state = full arc, Reduce-Motion-gated via system flag
  OR in-app `liviqaReduceMotion`), `MiniRing` (vitals + delta), `GlucoseCurveView`
  (target band + amber gradient area fill + NOW dot + x-ticks), `Toast`
  (invert-surface pill, status dot, mono timestamp, slide-up, ~2.8s auto-dismiss),
  `Delta`/`StatusPill`/`SourceChip`. VoiceOver labels on rings + curve.
- Self-contained (no screen wired yet) → no visual regression. Builds (iOS Sim).
- Next: wire into Today (radial hero + mini-ring vitals), then Trends grid,
  Wallet invert summary, Care, Journal, + debug menu.

### PR-34 — Oura redesign #1: Midnight theme foundation (NFR-UI-THEME-01) (2026-06-04)
- **feat(theme):** `Theme.swift` v02 — every `LiviqaTheme.*` colour is now a
  **dynamic token** (`Color.dyn(light,dark)`): light = Paper, dark = **Midnight**
  (tokens locked from the design brief; no invented hues). One root
  `.preferredColorScheme` flip (LiviqaApp, `@AppStorage("liviqaThemeMode")`,
  **default Midnight**) recolours all ~200 existing call sites — zero per-view
  churn, status bar + tab icons invert automatically.
- **feat(theme):** new hooks — `gridEmpty`, `heroGlow`, `homeIndicator`,
  `cardShadow` (per-mode), invert-surface set (`invertBG/FG/Sub/Line`), and
  `Radius.{card,hero,vitals}`. `Mode` enum (midnight/paper) for the runtime switch.
- **fix(ui):** AuthView's Apple + email-sign-in buttons used `ink` as a *surface*
  + white text (broke on Midnight when ink→cream) → switched to invert-surface
  tokens (correct on both themes). Launch background made theme-aware.
- Verified: builds for the iOS Simulator; Midnight renders the whole sign-in
  screen dark with the cream Lato wordmark + moss accent.
- Next: shared Oura components (RingView/MiniRing/GlucoseCurve/Toast), then
  Today → Trends → Wallet → Care → Journal. Brand/logo/copy unchanged; no
  provenance rendered; cardiac stays display-only.

### PR-33 — Full app-wide Lato rollout + TestFlight build 1.0(2) (2026-06-03)
- **feat(brand):** converted **all ~199** non-mono `.font(.system(size:…))` calls
  across every view to `.font(.lato(…))` — the whole app now renders in Lato
  (headlines/body), matching liviqa.app. Monospaced/rounded faces preserved
  (kickers/numbers stay IBM Plex Mono; one calendar day-number stays monospaced).
- **release:** bumped to build **1.0 (2)**, re-archived + uploaded to TestFlight —
  "UPLOAD SUCCEEDED" (Delivery UUID 3698bb2f-7ebe-49f4-a9cd-cfeb8b820493). This is
  the first fully brand-aligned build (icon + embedded mark + Lato/Plex fonts +
  paper launch). (Build 1.0(1) predated the brand work.)
- Verified: builds for the iOS Simulator; sign-in screen confirmed in Lato.
  Inner screens not screenshot-QA'd here (no tap-automation bridge) — eyeball in
  TestFlight for any Lato metric/wrap shifts; layouts mostly use
  minimumScaleFactor/flexible frames so risk is low.

### PR-32 — Brand alignment to liviqa.app (mark asset, Lato + IBM Plex Mono, launch) (2026-06-03)
- **feat(brand):** embed the **locked aperture mark** as an image asset
  (`LiviqaMark`/`LiviqaMarkReversed`, the same SVGs as the website) and rewrite
  `LiviqaApertureMark` to render it — no more code-drawn mark (brand kit §1:
  "embed the asset, never redraw"; code redraws caused prior drift). Same API, so
  all call sites are unchanged.
- **feat(brand):** bundle the site's real OFL fonts — **Lato** (Regular/Bold/
  Black) + **IBM Plex Mono** (Regular/Medium) — via `UIAppFonts`. `Theme` now uses
  IBM Plex Mono for kickers/numbers and adds `Font.lato(_:_:)`; the sign-in
  wordmark renders in Lato Black. (Full headline/body Lato rollout across all
  views is a follow-up — needs per-screen visual QA for metric shifts.)
- **feat(brand):** branded **launch screen** — paper `#F7F5F1` (`LaunchBackground`)
  instead of the default black.
- Palette already matched the kit (Theme tokens = design tokens). App icon = PR-29.
- Verified: builds for the iOS Simulator; fonts in the bundle, mark + launch color
  in `Assets.car`, PostScript names confirmed (no system fallback); sign-in screen
  matches liviqa.app (paper, aperture mark, Lato wordmark).

### PR-31 — First TestFlight upload (2026-06-03)
- **release:** Liviqa **1.0 (1)** archived (Release/live-data), signed with a
  freshly-minted Apple Distribution cert + App Store profile (all created headless
  via the App Store Connect API key), exported, and **uploaded to TestFlight** —
  "UPLOAD SUCCEEDED" (Delivery UUID 097e69a0-49fd-4e88-88d7-a66740b78b83). Bundle
  `dev.liviqa.app`, team PS258XSNL8.
- **fix(appstore):** added `NSHealthUpdateUsageDescription` — Apple rejects upload
  (90683) without the HealthKit *write* purpose string even though Liviqa is
  read-only.
- Found via the existing DfG App Store Connect record (Liviqa / `dev.liviqa.app`)
  + App ID `486FL49R3M` — so the earlier `app.liviqa.ios` plan was dropped; reused
  the existing identifier (no new App ID / app record).
- **State:** `api.liviqa.app` LIVE (TLS, `/me`→401 auth-gated). `auth.liviqa.app`
  (GoTrue) NOT yet deployed → sign-in won't work for testers until it's up
  (see `liviqa-backend/docs/Deploy_Prod_Hosts_Prompt_v01.md`). Hold external
  testers until auth is live.

### PR-30 — TestFlight prep: live-data Release config + App Store gaps (2026-06-03)
- **Decisions (locked):** DfG team `PS258XSNL8`; bundle `app.liviqa.ios`; canonical
  hosts on `liviqa.app`; video consult **gated off** in v1; external testers,
  synthetic data only. Gap list: `docs/TestFlight_Readiness_v01.md`.
- **feat(config):** `Config.backend` now ships **live in Release/TestFlight** —
  Release → `sovereignProd` (`api.liviqa.app` + Supabase GoTrue `auth.liviqa.app`);
  Debug → `.mock`; `LIVIQA_BACKEND` env still overrides. New `sovereignProd`
  preset; `sovereignStaging` repointed to `api.liviqa.app`.
- **feat(config):** `videoConsultEnabled = false` — `MessagesView` hides the
  consult-join section (no EU Jitsi / camera-mic in v1; messaging stays).
- **chore(signing):** `Config/Signing.xcconfig` (local, gitignored) → team
  `PS258XSNL8`, bundle `app.liviqa.ios`, group `group.app.liviqa.ios`.
- **fix(entitlements):** add `com.apple.developer.applesignin` (the SIWA button
  was wired without its entitlement) so the App ID gets the capability under
  automatic signing.
- **chore(appstore):** `Info.plist` `ITSAppUsesNonExemptEncryption=false`;
  added **`PrivacyInfo.xcprivacy`** (health/email/userID/message content, no
  tracking; UserDefaults reason CA92.1) — bundled, build verified.
- **docs:** `docs/INTENDED_USE.md` (FR-QMS-01); `docs/TestFlight_Readiness_v01.md`.
- Verified: `xcodebuild build` (iPhone 17 Pro sim) succeeds; privacy manifest in
  the .app; bundle id `app.liviqa.ios`.
- **Still blocked (needs your Apple login):** no DfG signing identity in this
  Mac's Keychain → add the DfG Apple ID in Xcode (automatic signing mints the
  Apple Distribution cert); register App ID `app.liviqa.ios` + App Group + the
  App Store Connect record; privacy nutrition labels; archive + upload.

### PR-29 — App icon (the AppIcon set had no image) (2026-06-03)
- **fix(brand):** the `AppIcon.appiconset` declared icon slots but contained **no
  image** → blank/default icon. Installed the locked aperture app-icon
  (`Brand_Assets/liviqa_appicon_aperture_1024.png`), flattened onto the brand
  off-white `#F7F5F1` (opaque, no alpha — iOS requires it; the alpha came from the
  source's rounded corners, which iOS masks itself). Single 1024 universal entry;
  actool generates all sizes. Cardinal rule honoured — locked mark, not redrawn.
- Note: delete the old app from the simulator/device once (iOS caches the blank
  icon) and re-run to see it.

### PR-28 — Auth: revert Ory → Supabase Auth (self-hosted GoTrue, EU) (FR-AUTH-01) (2026-06-03)
- **Decision:** Ory Network dropped (custom domains $70/mo, unjustified for the
  sandbox). Auth = **Supabase Auth (GoTrue) self-hosted on Scaleway (EU)** —
  sovereign + $0 license, so NFR-SEC-07 still holds (self-hosted EU GoTrue, NOT
  Supabase Cloud/US). See `docs/Auth_Supabase_v01.md`; backend `AuthGuard`
  already verifies the Supabase JWT (jose, HS256/JWKS, link-by-email).
- **feat(auth):** new `SupabaseAuthClient` (GoTrue) — `login` (password grant),
  `loginWithApple` (native `id_token` grant), `user` (session check), `logout`,
  with pure body builders + response parsers. `LiviqaBackendService` now takes a
  `SupabaseAuthClient` (was `OryAuthClient`): sign-in obtains the Supabase access
  token, persists it via `SessionTokenStore` (Keychain, NFR-SEC-01), and presents
  it as the backend bearer. `currentSession` validates the token via GoTrue.
- **feat(config):** `Config.supabaseAuthURL` (self-hosted GoTrue) + `.sovereign(…,
  authURL:)`; `sovereignStaging` points auth at it; `sovereignLocal` keeps the dev
  seed token (no Supabase needed locally). `LIVIQA_BACKEND` env override unchanged.
- **revert:** removed `OryAuthClient` + `OryAuthParsingTests` + `OryAppleParsingTests`.
  `AppleSignInCoordinator` is unchanged (its id_token + raw nonce now feed GoTrue).
- **test:** `SupabaseAuthParsingTests` (T-SBA-01..05) — password/Apple grant
  bodies, token + user parsing, nonce helpers. 8-suite simulator run green.

### PR-27 — Anchor cadence fix + re-entrancy guard + testable AnchorSync (FR-ING-03/04) (2026-06-03)
- **fix(ingestion):** correct per-type background-delivery cadence — step count
  `.hourly` (high churn), every other signal `.immediate`.
- **fix(ingestion):** re-entrancy guard in `ObserverRegistry` — an observer
  wake-up during an in-flight sync is coalesced (`beginSync`/`endSync`), so two
  `ingestDelta()` passes never overlap.
- **refactor(ingestion):** extract a portable `AnchorSync.advance(store:key:fetch:)`
  seam (no HealthKit) — loads the encrypted anchor, runs the source from it,
  persists the advanced anchor. The HK query is injected, so the
  anchor-advances-on-sync behaviour is testable with a fake.
- **test:** `EncryptedAnchorStoreTests.anchorAdvancesOnEachSync` (T-ANCH-08) —
  fake provider; each sync resumes from the prior cursor and moves it forward; a
  no-new-anchor sync leaves it put. 9-suite simulator run green.

### PR-26 — Sign in with Apple: ASAuthorizationController → Ory OIDC (FR-AUTH-01) (2026-06-03)
- **feat(auth):** `AppleSignInCoordinator` runs the native `ASAuthorizationController`
  flow with a SHA-256-hashed nonce, returning the Apple `id_token` + the RAW
  nonce. `AuthView`'s "Continue with Apple" now calls it →
  `AppState.signInWithApple` → `LiviqaBackendService.signInWithApple` (the PR-22
  Ory OIDC submit), persisting the Ory session token in the Keychain. No silent
  demo fallback; the Demo button stays the separate never-fail path. User cancel
  is swallowed; other errors surface.
- **test:** moved the Apple/OIDC parsing tests into their own `OryAppleParsingTests`
  (OIDC submit body, Apple success envelope) + a nonce test (deterministic
  SHA-256, correct length, run-to-run uniqueness).
- Note: the Apple sheet needs the "Sign in with Apple" entitlement to complete on
  device; the parsing/nonce logic is unit-tested headlessly.
- **chore(e2e):** local-QA hooks so the Care tab can be exercised against the
  local backend without changing shipped defaults — `Config.backend`/`jitsiDomain`
  read `LIVIQA_BACKEND` / `LIVIQA_JITSI_DEMO` env (defaults stay `.mock` / `nil`),
  and `NSAllowsLocalNetworking` lets the app reach `http://localhost`. Backend
  seed now provisions an **active consult session** (nurse↔LV001) so the consult
  is joinable out of the box (liviqa-backend `prisma/seed.ts`).

### PR-25 — Jitsi config decision: EU-sovereign default, demo domain quarantined (2026-06-03)
- **chore(config):** `Config.jitsiDomain` stays `nil` (secure-shell default — no
  live media until a real EU-sovereign Jitsi/Whereby domain is set), with a TODO
  to set it before any production/TestFlight build (NFR-SEC-07). Adds
  `Config.jitsiDemoDomain = "meet.jit.si"` clearly marked LOCAL-PARITY ONLY
  (US-operated — never a production default), for dev to join the same room the
  console uses.

### PR-24 — Anchored incremental HealthKit + encrypted on-device anchors (FR-ING-03/04) (2026-06-03)
- **feat(ingestion):** `HealthKitService+Anchored` — `HKAnchoredObjectQuery` per
  MVP type starting from a persisted `HKQueryAnchor`, plus `HKObserverQuery` +
  `enableBackgroundDelivery` at a per-type cadence (glucose `.immediate`, the
  rest `.hourly`). Exposed behind a framework-free capability protocol
  `IncrementalHealthSource` (`ingestDelta()` / `startBackgroundObservers` /
  `stopBackgroundObservers`) so the portable layer and demo providers stay
  HealthKit-free (NFR-PORT-01).
- **feat(security):** `EncryptedAnchorStore` — seals each anchor with the device
  DEK (KeyVault → AES-256-GCM/`CryptoBox`) and writes it to a file under
  Application Support, namespaced (SHA-256) per **device-local** user
  (`LocalUserScope`, a Keychain UUID — never UserDefaults, never a server/account
  id). `AnchorCodec` does the `HKQueryAnchor ⇆ Data` secure-coding archive.
- **test:** `EncryptedAnchorStoreTests` (T-ANCH-01..06) — encrypted round-trip,
  ciphertext-at-rest, per-key + per-user-scope isolation, wrong-DEK auth failure,
  remove/clear; `AnchorCodecTests` (T-ANCH-07) — HKQueryAnchor round-trip. All
  pass in the iOS Simulator.
- Verified: `xcodebuild build` (iPhone 17 Pro sim) succeeds; observer/background-
  delivery paths run on device (entitlement-gated).

### PR-23 — Correlation grid UI in Health Passport (FR-PAS-05 / DM-06 follow-up) (2026-06-03)
- **feat(ui):** `HealthPassportView.correlationCard` renders the 7×signal grid
  from the **live** `appState.correlationWeek` (built on-device by
  `CorrelationDeriver`, PR-17) — day headers, per-signal rows, deviation heat-map
  cells, legend, and the pattern note/sources/strength. Reuses the locked visual
  language from `WeekInContextView` (cardinal rule: iterate, don't rebuild — the
  locked mock view is untouched).
- **a11y (NFR-A11Y-01):** every cell carries `"<metric>, <day>: <level>"` using
  the existing `CorrelationLevel.accessibilityLabel`; decorative headers/legend
  are `accessibilityHidden`. No trust chips (NFR-PRIV-05).
- Verified: app builds for the iOS Simulator; deriver tests (T-COR-01) green.

### PR-22 — Sign in with Apple via Ory OIDC-native (2026-06-03)
- **feat(auth):** `OryAuthClient.loginWithApple(idToken:nonce:)` runs Ory's native
  social flow — GET login flow → POST the Apple `id_token` to the `oidc` method
  (`id_token_nonce` binds the token to the SIWA request) → reuse
  `parseLoginSuccess` (Ory returns the same `session_token` envelope as password).
  Pure `oidcSubmitBody` builder for testability.
- **feat(services):** `LiviqaBackendService.signInWithApple` (was a `notAvailable`
  stub) now performs the real Ory OIDC login when an `OryAuthClient` is present,
  sets the bearer, and persists the session token via `SessionTokenStore`
  (Keychain, NFR-SEC-01); local-dev (no Ory) keeps the seed-token fallback.
- **test:** `OryAuthParsingTests` gains T-ORY-04 (OIDC submit body: method/
  provider/id_token/nonce; nonce omitted when empty) and T-ORY-05 (Apple OIDC
  success parse). Run in the iOS Simulator.

### PR-21 — (backend) recording-consent direction regression test (2026-06-03)
- Backend change lives in **liviqa-backend** (commit `test(consult): …`). The
  recipient route already set `recordingRequested` (not `recordingConsent`, fixed
  in `73453ae`); this batch adds `workspace.service.spec.ts` asserting the
  recipient route writes `{ recordingRequested }` only and never touches
  `recordingConsent` (privacy-critical). Console already reflects the corrected
  direction (liviqa-b2b-console `dd7090d`): button "Request recording" → sets
  requested; "Recording — consented by the citizen" only when
  `recordingConsent === true`; `guard:ci` green.
- Verified: backend `npm test` green; live curl — nurse request →
  requested=true/consent=false, citizen consent → consent=true.

### PR-20 — (backend) citizen secure-messaging routes (2026-06-03)
- Backend change lives in **liviqa-backend** (commit `feat(citizen): secure-
  messaging threads routes`). Adds `@Roles('citizen')` `GET /threads`,
  `GET /threads/:recipientId/messages` (marks recipient→citizen read on open),
  `POST /threads/:recipientId/messages` (active-grant-gated, body cap 4000,
  audited `message.send`). JSON shapes match the iOS `ThreadDTO`/`MessageDTO`;
  `CareConnect`/`LiviqaBackendService` already consume them (PR-18). Backend
  `citizen.service.spec.ts` + live curl as `dev-citizen-claus` verify list/read/
  send and the 403 on no active grant.

### PR-19 — Care tab: secure messaging + video consult UI (2026-06-03)
- **feat(ui):** new **Care** tab (`MainTabView`) → `MessagesView`: lists active
  consults to join and secure message threads with the care team (loads via
  `AppState.refreshCareInbox`; pull-to-refresh). `MessageThreadView` is a chat
  (bubbles + composer) over `CareConnect.fetchMessages`/`sendMessage`.
- **feat(ui):** `ConsultView` joins the deterministic EU room
  (`https://<jitsiDomain>/liviqa-consult-<id>`) in a `WKWebView` (inline media);
  falls back to a secure shell when no EU domain is set (NFR-SEC-07). The
  citizen owns recording consent (Allow/Stop → `setRecordingConsent`), reflecting
  a recipient request; the consented-only framing is shown beside the call.
- Verified: SourceKit clean (no lints); full Xcode/simulator build pending
  (sandbox has no iOS runtime). Live data needs the deferred backend `/threads`
  routes; consult/notifications routes already exist.

### PR-18 — Citizen CareConnect client + Ory token Keychain persistence (2026-06-03)
- **docs:** `docs/Video_and_OAuth_Contract_v01.md` — cross-repo contract for the
  citizen side of the recipient workflow already in `liviqa-backend`/
  `liviqa-b2b-console` (Ory bearer model, deterministic Jitsi room
  `liviqa-consult-<id>`, recording-consent direction, citizen endpoint set).
- **feat(services):** `CareConnect` capability (sovereign-only, off the shared
  protocol) + `LiviqaBackendService` conformance — `GET /notifications`,
  `GET /consults/active`, `POST /consults/:id/join`,
  `POST /consults/:id/recording-consent` (citizen-authoritative), and the new
  messaging routes `GET /threads`, `GET/POST /threads/:recipientId/messages`.
  Portable value types (`ConsultSummary`, `CareThread`, `CareMessage`,
  `CitizenNotification`) + wire DTOs.
- **feat(security):** `SessionTokenStore` (Keychain, device-only) persists the
  Ory session token (NFR-SEC-01 / FR-AUTH-03). `LiviqaBackendService` restores it
  on init (stay-signed-in), saves on Ory login, clears on sign-out;
  `currentSession` revalidates via `whoami`.
- **feat(state):** `AppState.careConnect` + `refreshCareInbox()` (threads /
  active consults / notifications).
- Verified: service layer typechecks clean via swiftc. UI + live calls pending.
- Backend deferred (needs the backend repo): citizen `/threads*` routes and the
  recipient recording route writing `recordingRequested` (not `recordingConsent`).

### chore — backend contract cross-check + bug-hunt (2026-06-03)
- Verified `LiviqaBackendService` against the actual `liviqa-backend` repo
  controllers/services (not just openapi): routes `/me`, `/grants`, `/ledger?limit`,
  `/recipients`, `POST /grants`, `POST /grants/{id}/revoke`, `PUT /shares/{grantId}`
  all match. DTOs match: `CreateGrantDto` (recipientId/recipientRole/scopeKeys/
  granularity/expiry/delivery), `PushShareDto` `{ asOf, payload:{ metrics, insights } }`
  == `DerivedShareRequest`, grant/ledger reads (`expiresAt`/`createdAt`/`occurredAt`),
  and `/me` `AuthedAccount` (`id,kind,role,email,displayName,org`) == `AccountDTO`.
  `Gran` = summary|trend|events|detailed|off → our `"summary"` default is valid and
  the backend clamps to the role template regardless. No client change required.
- Bug-hunt over PR-15/16/17 + sharing/backend client: full pure layer typechecks
  clean together; no defects found.

### PR-17 — On-device 7-day correlation grid (FR-PAS-05 / DM-06) (2026-06-03)
- **feat(intelligence):** `CorrelationDeriver` (pure Foundation) builds the
  7-day × 7-signal grid as a deviation-from-usual heat map: each cell is the
  day's value vs the user's OWN window baseline (|z| → low/medium/high/outlier),
  personal-baseline-relative only. Derives glucose/sleep/HRV/exercise from local
  samples; spending/calendar/weather stay `noData` (connector-only — never
  fabricated). Emits a plain-language `patternNote`, named `patternSources`, and
  `patternStrength` (Steady/Moderate/Strong). New portable `CorrelationGrid`.
- **feat(models):** `CorrelationWeek.from(_:)` adapts the grid to the
  presentation model; `AppState.refreshFromHealth` populates `correlationWeek`
  from the same on-device samples (grid UI consumer remains a follow-up — no
  view renders the grid yet).
- **safety:** the pattern note is run through `NudgeGuard` in tests (no clinical
  /diagnostic/normative language).
- **test:** `CorrelationDeriverTests` (T-COR-01) + swiftc driver — 7×7 shape,
  oldest-first ordering, external columns `noData`, outlier-day detection and
  naming, steady-week path, guard-clean notes.

### PR-16 — On-device Health Passport stats derivation (FR-PAS-05 / DM-05) (2026-06-03)
- **feat(intelligence):** `PassportStatsDeriver` (pure Foundation) computes the
  sensor half of the Passport from local `HealthSamples`: `totalReadings`,
  `daysTracked` (distinct calendar days across all streams), `glucoseTimeInRange`
  (% in the 3.9–10.0 mmol/L band by default, or the user's `ClinicalTargets`
  band, FR-PAS-03), and `avgSleepHours` (asleep stages only — `awake`/`inBed`
  excluded). New `DerivedPassportStats` value type (NFR-PORT-01).
- **feat(models):** `PassportStats.compose(derived:…)` composes the sensor half
  with the count half (nudges, connected sources, journal, consent decisions).
- **feat(state):** `AppState.refreshFromHealth` now refreshes `passportStats`
  from the same arbitrated on-device samples, so the Passport reflects live data
  instead of the static `MockData` seed.
- **test:** `PassportStatsDeriverTests` (T-PAS-01) + swiftc driver — TIR 70%,
  avg-sleep excludes awake, daysTracked, totalReadings, empty-safe, custom band.

### PR-15 — Nudge engine: workout↔glucose coupling rule (§6.2 lead example) (2026-06-03)
- **feat(intelligence):** `NudgeEngine.workoutGlucoseNudge` — the prototype's
  lead example ("glucose dropped X% more than usual after yesterday's ride").
  Per workout it computes the glucose change (mean of the hour before start −
  mean of the two hours after end), groups by workout type, and fires only when
  the LATEST same-type session's drop is materially steeper (>1σ and ≥15%) than
  the user's OWN prior same-type sessions (Baseline needs ≥3). Within-user
  correlation only — no targets, no population norm, no advice.
- **safety:** output runs through `NudgeGuard` (FR-NDG-06) like every stream;
  copy stays clean (personal "more than usual", glucose accent, lane `.watch`).
- **test:** `WorkoutGlucoseNudgeTests` (T-NDG-08) + swiftc driver — fires on a
  steep latest ride, silent on typical drops, silent without ≥3 prior sessions;
  guard-clean. Pure Foundation (Android-portable, NFR-PORT-01 / NFR-MAINT-02).

### PR-14 — Ory Network auth (real session tokens) for the sovereign backend (2026-06-03)
- **feat(auth):** `OryAuthClient` runs the Ory Network NATIVE login flow
  (`GET /self-service/login/api` → `POST {ui.action}` password → `session_token`;
  `GET /sessions/whoami`; `POST /self-service/logout/api`). Pure response parsers
  are unit-tested (`OryAuthParsingTests`, verified via swiftc) without networking.
- **feat(services):** `LiviqaBackendService` takes an optional `OryAuthClient`.
  When present, `signInWithEmail` performs a real Ory login and the returned
  session token becomes the backend `Authorization: Bearer` (openapi: "prod: Ory
  session token"); `currentSession` validates via whoami; `signOut` revokes.
  When absent (local dev), the static seed token remains the identity.
- **feat(config):** `Config.oryURL` (Ory project) + `.sovereign(…, oryURL:)`;
  `sovereignLocal` (seed tokens, no Ory) and `sovereignStaging` (real Ory login)
  presets. Default backend stays `.mock`.
- Note: Apple/OIDC-native via Ory not wired yet (email/password is the path);
  session token is in-memory (Keychain persistence = follow-up).

### PR-13 — FR-SHARE-02 UI: live recipient picker + consented share send (2026-06-03)
- **feat(ui):** `ShareWithClinicianView` wired to the sovereign backend — step 3
  loads the real care directory (`GET /recipients`) and lets the citizen pick a
  recipient; step 1 toggles map to consent GROUP keys (glucose→glucose, sleep→
  sleep, HRV→recovery, activity→activity; nudges ride along as insights, not a
  scope group); "Send" creates the grant (group scope, 48h expiry) and pushes the
  derived package. Falls back to the simulated flow on `.mock`/demo.
- **feat(state):** `AppState.createGrantAndShare(recipientId:role:scopeGroups:
  rangeDays:expiry:)` — create grant → derive (fetch→arbitrate→DerivedShareBuilder)
  → `PUT /shares/{grantId}` → reload wallet. `pushDerivedShare` gains `rangeDays`.
  Raw samples/provenance never leave the device.
- **feat(ui):** `WalletView` "granted since" now uses the grant's real `createdAt`;
  grants + consent ledger already render from the live mapping (PR-12). Withdraw →
  `POST /grants/{id}/revoke` via `toggleGrant` (one-way, evidenced).
- Verified: sourcekit clean; full Xcode build pending on-device (sandbox has no
  simulator runtime). Backend write loop already proven live (PR-12).
- Completes FR-SHARE-02 / UC-07/11/12 on the citizen surface.

### PR-12 — FR-SHARE-02: EU-sovereign backend client + derived-share push (2026-06-03)
- **feat(services):** `LiviqaBackendService` implements `SupabaseServiceProtocol`
  against the EU-sovereign backend (NestJS/Scaleway+Ory) per `openapi.yaml` /
  `Liviqa_iOS_Backend_Contract_v01` — `GET /me`, `GET /recipients`, `GET /grants`,
  `POST /grants`(+`/revoke`), `GET /ledger`, and the new `pushDerivedShare →
  PUT /shares/{grantId}` (body from `DerivedShareBuilder`, FR-SHARE-01).
- **feat(services):** `SovereignSharing` protocol (recipient directory + grant
  create + derived-share push) reached via `AppState.sovereign`; `AppState`
  gains `pushDerivedShare(grantId:scopeGroups:)` (fetch→arbitrate→derive→push;
  raw/provenance never leave device).
- **feat(config):** `Config.Backend` (`.mock` default · `.supabaseSandbox` ·
  `.sovereign(baseURL:devToken:)`) + `makeService()`; `AppState.init` selects it.
  Supabase demoted to sandbox-only (NFR-SEC-07); default stays `.mock`.
- **feat(services):** `BackendMapping` — pure, testable wire↔domain transforms
  (stable UUIDv5 from opaque backend ids; ledger event/decision maps; tolerant
  ISO-8601 parse; role→display-type). `BackendMappingTests` (T-BMAP-01..06).
- **verify:** mapping driver green via swiftc; full write loop exercised live
  against `http://localhost:3001` (`dev-citizen-claus`): create grant (group
  scope) → 201, `PUT /shares` (DerivedShareBuilder body) → 200, revoke → ok.
- Maps to FR-WAL-* / UC-07/11/12/13. Closes the open device→backend seam.

### CORRECTION — re-anchor to SRS/UseCases v05 + sovereign backend (2026-06-03)
- **revert(sharing):** retired the off-spec `ShareBundle`/`ShareBundleBuilder`/
  `SecureShareExporter` + `SharingTests` introduced below. They duplicated the
  existing, on-contract `DerivedShareBuilder` (FR-SHARE-01) and diverged from it
  (individual scope keys vs consent GROUPS; a local AES envelope vs the contract's
  TLS `PUT /shares/{grantId}`). `DerivedShareBuilder` is the canonical builder.
- **docs(qms):** re-anchored RTM to actual SRS IDs — FR-SHARE-01 (DerivedShareBuilder),
  FR-SHARE-02 (sovereign wiring, planned), **NFR-SEC-07** (cloud holding real PII
  must be EU-sovereign — `liviqa-backend`/Scaleway+Ory, not US-parented Supabase),
  FR-PROV-01 (SourceArbiter). Root cause of the divergence: building from the
  derived RTM instead of `Liviqa_SRS_v05`/`Liviqa_UseCases_v05` and
  `docs/Sovereign_Backend_Integration_v01.md`.
- **feat(ingestion):** `SourceArbiter` (FR-PROV-01) retained — highest tier wins,
  lower fills gaps, never blends clinical with estimate; wired into
  `AppState.refreshFromHealth()` before persist/engine. Verified via swiftc.
- Retained as on-spec: PR-7 (FR-ARCH-05/UC-05), PR-8 KeyVault (NFR-SEC-01/02).

### PR-9 [RETIRED] — scoped, derived-only, encrypted share boundary (2026-06-03)
- **feat(sharing):** `ShareBundle` / `DailySummary` — the ONLY shape data may
  leave the device. Derived daily aggregates only: no raw intraday samples, no
  `source`, and NEVER `provenance` (internal arbitration stays on-device).
- **feat(sharing):** `ShareScope` maps consent scope keys → unlockable metrics
  (deny-by-default; `calendar`/unknown scopes unlock nothing).
- **feat(sharing):** `ShareBundleBuilder` reduces `HealthSamples` to one row per
  metric per day (mean for rates, sum for counts/minutes; sleep counts asleep
  time only) filtered to the grant's scopes.
- **feat(sharing):** `SecureShareExporter` JSON-encodes then AES-256-GCM-seals
  the bundle via `KeyVault.cryptoBox()` — the PR-8 primitive becomes an enforced
  egress control. Bundle dates are whole-second so the encrypted round-trip is
  byte-stable.
- **feat(security):** `KeyVault(requireUserPresence:)` opt-in — gates the Secure-
  Enclave device key on Face/Touch ID (passcode fallback) via `SecAccessControl`.
- **test:** `SharingTests` (T-SHARE-01..05): scope filtering, no-provenance/
  no-source/no-raw guard on serialized JSON, deny-by-default, encrypt round-trip,
  one-row-per-metric-per-day.

_Requirements touched:_ FR-ARCH-04, NFR-PRIV-01, NFR-SEC-02.
_Risk:_ mitigates RK-PRIV-EGRESS-01 (raw/identifying data leaving device); no new
clinical hazard. See `qms/RISK.md`.
_Verification note:_ all 11 sharing checks executed this session via a `swiftc`
driver. KeyVault biometric path runs on device.

### PR-8 — Secure Enclave key-wrap + AES-256 verification (2026-06-03)
- **feat(security):** `CryptoBox` — AES-256-GCM authenticated encryption
  (nonce‖ct‖tag combined box); `keyBitCount` exposed for strength assertions.
- **feat(security):** `KeyWrap` — ECIES wrap of the data-encryption key (DEK) to
  a P-256 device key (ECDH → HKDF-SHA256 → AES-GCM), versioned HKDF context,
  fresh ephemeral per wrap. `AgreementPrivateKey` abstraction unifies software
  and `SecureEnclave.P256` keys so unwrap is identical on both paths.
- **feat(security):** `KeyVault` — mints a 256-bit DEK on first use, wraps it to
  a Secure-Enclave device key (private half never leaves the SE; only its
  `.dataRepresentation` is stored), persists the wrapped DEK in the Keychain
  (`…AfterFirstUnlockThisDeviceOnly`). Software P-256 fallback for simulators;
  `isHardwareBacked` records the live path. `reset()` for wipe/sign-out.
- **test:** `CryptoTests` (T-SEC-01..06) — AES-256 round-trip, GCM tamper
  rejection, wrap/unwrap recovery, wrong-device-key failure, per-wrap
  uniqueness, serialization round-trip.

_Requirements touched:_ NFR-SEC-02, OD-09.
_Risk:_ mitigates RK-PRIV-ATREST-01 (data-at-rest) + adds integrity guarantee;
no new clinical hazard. See `qms/RISK.md`.
_Verification note:_ all 10 crypto checks executed this session via a `swiftc`
driver (software P-256). Secure-Enclave + Keychain paths run on device.

### PR-7 — UI wiring: live L1→L2→L3 feed + demo-data badge (2026-06-03)
- **feat(app):** `AppState.refreshFromHealth()` runs the on-device pipeline —
  active `HealthDataProvider` (mock or HealthKit) → `IngestionCoordinator.persist`
  (L2, on-device only) → `NudgeEngine` (L3) — and publishes the capped,
  FR-NDG-06-clean feed. Falls back to existing nudges if nothing fires, so the
  Today feed is never empty. SwiftData container is optional → a store failure
  can never crash launch.
- **feat(app):** provider is selectable via `AppState.dataProviderKind`
  (`.mock` default for the synthetic demo user; `.healthKit` for real data) with
  no code change at the call sites.
- **feat(intelligence):** `EngineNudge → Nudge` card adapter (`EngineNudge+Card.swift`)
  — the single seam between domain output and the locked prototype card. No
  clinical copy added; card text comes straight from the engine.
- **feat(ui):** `TodayView` shows a neutral "DEMO DATA" badge when the feed is
  synthetic (FR-ARCH-05). `MainTabView` triggers `refreshFromHealth()` on appear.
- **refactor(ingestion):** split `IngestionCoordinator.sync` into `sync` +
  `persist(_:from:to:)` so a caller can fetch once and reuse samples for L3.
- Prototype design untouched (cardinal rule): wiring is additive (one new param,
  one extension file, one additive badge).

_Requirements touched:_ FR-ARCH-05 (demo-data disclosure), L1→L2→L3 integration.
_Risk:_ no new clinical hazard. The display-only AFib lane stays display-only
(`EngineNudge` → `.cardiac` accent, no clinician routing implied by the card).
_Verification note:_ asset-less `xcodebuild` (device, signing off) shows **0 new
errors** in any wired file; remaining errors are the authoring-sandbox macro
plugins only. UI rendering verified by the user in Xcode.

### fix — resolve `Nudge` type collision with locked prototype (2026-06-03)
- The PR-5 engine type `Nudge` collided with the locked prototype's
  presentation-layer `Nudge` card view-model (`Liviqa/Models/MockData.swift`),
  producing "invalid redeclaration / ambiguous for type lookup" — the hard error
  that blocked the Xcode build. Renamed the engine output type to `EngineNudge`
  across `NudgeModel`/`NudgeGuard`/`NudgeEngine` (prototype left untouched, per
  the cardinal rule). A future UI PR maps `EngineNudge` → the `Nudge` card.
- Verified: full `xcodebuild` (device, signing off) shows the `Nudge` clash gone
  (0 errors); all remaining build errors are the authoring-sandbox's inability to
  run Swift macro plugins (`@Model`, `@Observable`, `#Preview`) + their cascades,
  which do not occur in a normal Xcode toolchain.

### PR-6 — Open-Meteo weather/AQI context (coarse, no health egress) (2026-06-03)
- **feat(context):** `OpenMeteoWeatherProvider` fetches current weather +
  European AQI (FR-CTX-01). Coordinate is coarsened to ~0.1° (~11 km) before any
  request (privacy control); air-quality is best-effort (non-fatal). Keyless,
  EU-hosted. `MockWeatherProvider` for offline/tests.
- **feat(context):** pure `OpenMeteo` URL builders — requests carry only
  lat/lon + named env fields, proven by test (no health data, no identifiers,
  no key). `Coordinate`/`WeatherSnapshot` value types, Foundation-only.
- **feat(context):** `WeatherContextMapper` → `WeatherContext` entity
  (provenance EXTERNAL); coarse coordinate is not persisted.
- **test:** `WeatherContextTests` (T-CTX-01..04).

_Requirements touched:_ FR-CTX-01, FR-CTX-02.
_Risk:_ no new clinical hazard; adds a privacy control (coarse location, no
health egress). See `qms/RISK.md`.
_Verification note:_ coarsening + URL-privacy + mock executed via `swiftc` this
session; entity mapping (SwiftData) runs in Xcode.

### PR-5 — On-device nudge engine + FR-NDG-06 guard + AFib display-only (2026-06-03)
- **feat(intelligence):** `NudgeEngine` — on-device, heuristic, personal-baseline
  -relative (±1σ). Emits the strict allow-list only (verdict / number / band-status
  / behavioural-lever / route-to-clinician), capped at 4 ("4 nudges, not 48 charts").
- **feat(safety):** `NudgeGuard` — **FR-NDG-06 designated control**. Blocks dose
  quantities, dosing verbs, treatment directives, affirmative diagnostic claims,
  and clinical-normality verdicts in any nudge string. Every engine output is
  validated before release; violators dropped + trapped in debug.
- **feat(cardiac):** AFib/cardiac is `displayOnly` (D9) — the only output is a
  route-to-clinician nudge (no verdict/band/interpretation), top priority so it
  always survives the cap. No signal ⇒ no cardiac nudge.
- **feat(model):** `RegulatoryLane` (wellness/watch/constrained/displayOnly),
  `Baseline`, `Nudge`, `NudgeCategory`, `ClinicalSignals` — pure Foundation,
  Android-portable, carries no `provenance`.
- **test:** `NudgeGuardTests` (T-NDG-06/06b/06c, blocking), `NudgeEngineTests`
  (T-NDG-01..07, T-BASE-01).

_Requirements touched:_ FR-NDG-01..06, D9/FR-REG-03, L3 lane map.
_Risk:_ RK-CARD-01, RK-GLU-01 now **mitigated** (was the top MDR exposure). See `qms/RISK.md`.
_Verification note:_ entire layer compiled **and executed** via `swiftc` harness
this session — guard blocks all bad strings, engine caps + routes correctly.
Swift Testing suites re-run in Xcode.

### PR-4 — HealthKitService (read-only) + L1→L2 persistence (2026-06-03)
- **feat(ingestion):** `HealthKitService` reads the MVP set on-device. Share/write
  set is **empty** — read-only by construction (FR-ARCH-04). Blood glucose read
  directly in canonical mmol/L (OD-07); all readings `provenance = .real`.
  Daily metrics aggregated per day (sum for steps/energy, mean for HRV/RHR).
- **feat(ingestion):** `HealthProviderFactory` resolves `.healthKit` →
  `HealthKitService` where the SDK exists, else Mock (`#if canImport(HealthKit)`).
- **feat(ingestion):** `IngestionCoordinator` + `SampleMapper` normalize
  `HealthSamples` into SwiftData entities (glucose, HeartDaily [HRV+RHR merged],
  sleep, workouts). Re-sync of a window is idempotent (replace-range, no dupes).
  Steps/active-energy stay on `HealthSamples` for L3 derivations (no raw entity).
- **test:** `HealthKitTests` (T-HK-RO-01/02/03), `MappingTests` (T-MAP-01/02).

_Requirements touched:_ FR-ARCH-04, FR-ING-02..05, FR-ING-09, OD-07, OD-09.
_Risk:_ glucose values now flow from device→store; still data-layer only, no
interpretation/rendering. AFib/insulin remain unsurfaced. See `qms/RISK.md`.
_Verification note:_ `HealthKitService` typechecks against the real HealthKit
SDK via `swiftc` this session; `IngestionCoordinator` (SwiftData macro) + Swift
Testing suites run in Xcode on the dev machine.

### PR-3 — L1 ingestion seam + provenance guard (2026-06-03)
- **feat(ingestion):** framework-free `HealthSamples` aggregate + value readings
  (`GlucoseReading`, `DailyMetric`, `SleepReading`, `WorkoutReading`) for the MVP
  read set (FR-ING-01). Single aggregate, no upload method anywhere (FR-ING-07).
- **feat(ingestion):** `HealthDataProvider` protocol — read-only by contract
  (auth + fetch only, no write surface, FR-ARCH-04) — with `DataProviderKind`
  (`isDemoData` drives the FR-ARCH-05 indicator) and `HealthProviderFactory`.
- **feat(ingestion):** `MockDataProvider` — deterministic, seeded synthetic
  demo user; every reading `provenance = .simulated` so the clinical gate stays
  satisfied. `LV001Provider` real-data stub, inert unless `LV001_DEMO` flag set
  (no synthetic fallback — would violate the clinical gate).
- **feat(guard):** `scripts/guard_provenance.sh` — **blocking** T-PROV-01: fails
  if `provenance` appears in any SwiftUI file. Plus type-level guards (T-PROV-02/03).
- **refactor(model):** move portable enums `SleepStage`/`InsulinKind` into
  framework-free `CoreTypes.swift` (shared by L1 and L2; NFR-PORT-01).
- **test:** `LiviqaTests/IngestionTests.swift` (T-ING-01..05),
  `LiviqaTests/ProvenanceGuardTests.swift` (T-PROV-02/03).

_Requirements touched:_ FR-ING-01, FR-ING-07, FR-ARCH-04 (partial), FR-ARCH-05
(data flag), NFR-PORT-01, NFR-PRIV-05 (provenance render guard).
_Risk:_ no new hazard; the provenance-never-renders control is now enforced.
_Verification note:_ pure L1 + core layer typechecks clean via `swiftc` in this
session; the file guard runs green here. Swift Testing suites + SwiftData run in Xcode.

### PR-2 — Typed L2 data model (2026-06-03)
- **feat(model):** 12 typed sample entities (`GlucoseSample`, `InsulinDose`,
  `HeartDaily`, `BPReading`, `AFibBurden`, `SleepSegment`, `Workout`,
  `BodyComposition`, `LabResult`, `MedicationRecord`/`MedicationInteraction`,
  `WeatherContext`, `CalendarLoad`) per DataModel v1 §2.1, each carrying
  `source` + `tier{clinical,good,estimate}` + `provenance{REAL,SIMULATED,EXTERNAL}`.
- **feat(model):** clinical-tier rejects SIMULATED — schema gate
  (`validateTierProvenance`, throwing on every init) plus a type-level
  `ClinicalProvenance` (no `.simulated` case) for clinical constructors.
- **feat(model):** glucose canonical mmol/L (`GlucoseUnit`, OD-07); `provenance`
  is data-only (no user-facing label exists on the enum).
- **feat(store):** on-device `SwiftData` container (`LiviqaStore`) with
  `cloudKitDatabase: .none` (samples never sync, NFR-PRIV-01) + file-protection
  complete. Not yet wired into app launch (ingestion is its first writer, PR-4).
- **test:** `LiviqaTests/DataModelTests.swift` — clinical/SIMULATED rejection,
  mmol/L conversion, type-level clinical constructor, SwiftData schema round-trip.

_Requirements touched:_ DataModel v1 §2.1, OD-07, OD-09 (partial), NFR-PRIV-01.
_Risk:_ glucose/AFib/insulin **data** entities introduced — data-layer only, no
rendering or interpretation; insulin has no MVP surface (FR-REG-04). See `qms/RISK.md`.
_Verification note:_ this authoring session cannot run the SwiftData macro plugin
or the iOS Simulator; tests are authored and run in Xcode on the dev machine.

### PR-1 — Deployment-agnostic signing + QMS scaffold (2026-06-03)
- **chore:** relocate locked Phase-1 prototype to non-synced canonical clone
  `~/Developer/DataForGood/liviqa-ios` (baseline, no code change).
- **feat(signing):** centralise all signing/identity in `Config/Signing.xcconfig`
  (gitignored) + `Config/Signing.example.xcconfig`; wire
  `DEVELOPMENT_TEAM` / `PRODUCT_BUNDLE_IDENTIFIER` / `APP_GROUP` via build
  settings; remove hardcoded Team ID and bundle IDs from the project, Info.plist,
  and entitlements. Account swap → DfG is now an xcconfig edit (D-STORE).
- **feat(healthkit):** enable HealthKit capability + `NSHealthShareUsageDescription`
  (read-only enforced in code, later PR — `FR-ARCH-04`).
- **docs:** add `docs/SIGNING.md` (setup + migration runbook).
- **chore(qms):** scaffold RTM, DHF, RISK, CHANGELOG, VnV.

_Requirements touched:_ D-STORE, FR-ARCH-04 (partial), FR-QMS-02/03/05.
_Risk:_ no new hazard (see `qms/RISK.md`).
