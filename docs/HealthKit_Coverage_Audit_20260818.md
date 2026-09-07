# HealthKit ingestion coverage audit — 2026-08-18

Branch `claude/a72-electric-ink` · sleep-incident wave (data-quality incident on the
signal the nudge engine consumes). Scope: every HK type Maude reads today vs the
full set a health-and-lifestyle app for people-who-measure should consider.

**Governing rule (held throughout): NO type is read without a named consumer.**
Collection without purpose is the thing we refuse. Every "should read? no" below
is a refusal with a reason, not an oversight.

Read mechanics (all types): `HKSampleQuery` window reads (90-day first backfill,
30-day steady-state — `AppState.refreshFromHealth`, `windowDays`), READ-ONLY
(`shareTypes = []`, FR-ARCH-04), provenance `.real` set at the reader and never
rendered, §2.3 tier arbitration per logical slot (`SourceArbiter`).

## 1 · Types read today (verified in `HealthKitService.readTypes` + a reader each)

| HK type | Read today | Consumer (screen / deriver) | Framing + notes |
|---|---|---|---|
| `bloodGlucose` | ✅ | Glucose detail (`GlucoseDetailDeriver`), Today, nudges | Canonical mmol/L at the reader (OD-07); meal-context metadata open (FR-ING-08) |
| `sleepAnalysis` (category) | ✅ | Sleep detail + derivers — **owned by the parallel sleep agent; not touched here** | Night bucket = day the night ends on; union-not-sum |
| `heartRateVariabilitySDNN` | ✅ | HRV learn (`HRVLearnDeriver`), Today, chat | Personal-baseline only |
| `restingHeartRate` | ✅ | Heart detail (`HeartDetailDeriver`) | Own ±1σ band, never a reference range |
| `stepCount` | ✅ | Activity (`ActivityDeriver`), Today ring | **Fixed this audit:** cumulative roll-up was a cross-source sum → double-count (§3) |
| `activeEnergyBurned` | ✅ | Activity, Fitness load fallback | Same fix as steps |
| `heartRate` (daily mean) | ✅ | Persisted `HeartDaily.hrMean`; donor export | Thin consumer — kept (one merged row/day, no extra query cost) |
| `heartRate` (in-workout) | ✅ | Fitness avg-HR + zones (`FitnessDeriver`, T-FIT-01) | Zones = fractions of OWN observed max, never 220−age |
| `walkingHeartRateAverage` | ✅ | Persisted `HeartDaily.walkHr`; **consented donor export** (`DonationPayload`) | In-app surface not yet built — RTM row FR-ING-18 names the Fitness recovery card as the pending consumer |
| `heartRateRecoveryOneMinute` | ✅ | Persisted `HeartDaily.hrRecovery`; **consented donor export** | Same as above (FR-ING-18) |
| `respiratoryRate` | ✅ | Vitals (`VitalsDeriver`) — own-band dot strip | On watch this is measured **during sleep**, so the daily figure already IS the sleep-respiratory signal (§2, "respiratory during sleep") |
| `oxygenSaturation` | ✅ | Vitals (`VitalsDeriver`) | Fraction→% at the reader |
| `vo2Max` | ✅ | Fitness (`FitnessDeriver`) — single canonical home | |
| `insulinDelivery` | ✅ | Glucose×insulin observation (`GlucoseDetailDeriver`, `NudgeGuard`) | FR-REG-04: data-layer only, never a dose surface |
| `atrialFibrillationBurden` | ✅ | D9 lane: Heart detail AFib card (`HeartDetailDeriver`), display-only re-presentation (OD-11) | **History depth verified:** = fetch window — 90 d first run, 30 d steady-state. Adequate for display-only; two report-only gaps in §4 |
| `bloodPressureSystolic/Diastolic` (correlation) | ✅ | Heart detail corridor | Paired via `HKCorrelation`; never a clinical range |
| `bodyMass` / `bodyFatPercentage` / `leanBodyMass` / `bodyMassIndex` | ✅ | Body detail (`BodyTrendDeriver`) | One merged row/day |
| `workoutType()` | ✅ | Fitness, Activity | FR-PROV-02 overlap dedup (`WorkoutDeduplicator`) |
| `appleSleepingWristTemperature` | ✅ **NEW this audit** | FR-ING-16: sleep-context deviation vs OWN rolling baseline; UI card = named RTM row (pending) | Night-bucketed by the sleep `nightDay` rule; §2.3 arbitration per night; mock covered; **not** a fever/population claim, ever |

The read-authorization request (`readTypes`) equals this table exactly —
asserted by `T-COV-09 readSetMatchesWhatIsFetched`.

## 2 · Types considered and NOT read — each with its refusal

| HK type / family | Should read? | Reason |
|---|---|---|
| Blood-oxygen sleep contexts | No | The daily SpO₂ own-band strip is the Vitals design; a sleep-scoped SpO₂ has no designed consumer. Revisit only with a sleep-apnea lane design + risk review. |
| `appleSleepingBreathingDisturbances` (iOS 18) | Not here | Sleep-path type — belongs to the sleep agent's scope; flagged to them, not added by this audit. |
| `bodyTemperature`, `basalBodyTemperature` | No | Thermometer spot-checks; no consumer. Wrist temperature (added) is the continuous personal-baseline signal. |
| Cycle tracking (`menstrualFlow`, ovulation, etc.) | No | **Highest-sensitivity family; no designed consumer.** Reading it without a purposeful surface is exactly the collection-without-purpose we refuse. Requires its own consent framing, DPIA touch and design before any read. |
| Medications (iOS 16+ dose events) | No | The medication list arrives via sundhed.dk self-access import (clinical source of truth); a second, partial HealthKit copy would create two competing lists. High sensitivity, no consumer. |
| Symptoms (headache, nausea, …) | No | The journal is the self-report surface, account-scoped and deliberate. Importing symptom categories would duplicate it with weaker context. |
| Mindfulness (`mindfulSession`) | No | No consumer; a minutes-of-mindfulness figure invites a score, which the product refuses. |
| Dietary (carbs, energy, caffeine, …) | No, not yet | Would only be honest next to glucose with a designed meals surface; third-party logging coverage is too patchy to correlate against without fabricating absence-as-zero. Named future candidate, needs design first. |
| Hydration (`dietaryWater`) | No | No consumer. |
| Walking/gait metrics (speed, steadiness, asymmetry, 6-min walk) | No | Falls-risk/mobility lane does not exist; adding it is a product decision with its own risk file section. |
| `distanceWalkingRunning`, `flightsClimbed`, exercise/stand time | No | Steps + active energy + workouts already carry the movement story; more counters add surface, not signal. |
| `physicalEffort`, cycling power/FTP (iOS 17) | No | Fitness screen's load model is deliberately duration×own-relative-intensity; power metering is a training-platform feature, not this product. |
| ECG (`electrocardiogramType`) / `irregularHeartRhythmEvent` | Not here | Would extend the D9 display-only lane. Safety-path: any change needs its own design + RISK entry, not a coverage-audit side effect. Flagged as a candidate for a dedicated D9 wave. |
| Audio exposure, UV, time in daylight | No | No consumer. |
| Blood alcohol, peripheral perfusion, electrodermal | No | No consumer. |

## 3 · Defect found and fixed: cumulative daily roll-up double-counted sources

Same class as the two PR-109 sleep bugs (multi-source double-counting) — found in
the NON-sleep path this audit owns.

- **Evidence (code):** `HealthKitService.readDaily` summed every sample in the
  day across ALL sources for `cumulative: true` kinds (steps, active energy). A
  raw `HKSampleQuery` returns each source's samples — an iPhone in the pocket
  and a watch on the wrist both write step samples for the same walk. The
  Health app's own displayed total merges sources; the raw sum does not.
- **Effect:** a Watch+iPhone citizen's steps/kcal read up to ~2× on days both
  devices were carried. (CN wears both — consistent with "brutally wrong"
  figures beyond sleep; not claimed as THE reported defect, which is
  sleep-owned.)
- **Fix:** pure `DailyRollup` (in `HealthSamples.swift`): per (day, source)
  totals, the day's figure = the best-covering single source's total; sources
  are never summed together; a day only one device witnessed keeps that
  device's full total. Mean kinds unchanged.
- **Tests:** T-COV-01…04 (`HealthKitCoverageTests`). Trade-off documented: a
  mixed-coverage day (phone-only segment the watch missed) now under-counts
  slightly rather than double-counting — the honest direction. The exact-merge
  upgrade path (HKStatisticsQuery source priority) is noted in RTM FR-ING-17.

## 4 · Report-only findings (files not owned by this audit)

1. **HealthKit primer claims "these — and only these" over six rows, but the
   app requests ~21 types** (`Maude/Views/HealthKitPrimerView.swift`, lead
   copy + `dataTypes`). Untrue since PR-46's full-capture expansion; wrist
   temperature widens it further. Needed change (screen owner): either add
   rows — heart & respiration panel (HR, walking HR, HR recovery, respiratory,
   SpO₂, VO₂max), blood pressure, insulin, AFib burden, body composition,
   wrist temperature — or reword the lead to name the six domains and point at
   the system sheet for the full list, and drop "only these". The system
   authorization sheet does show the true full list, so the citizen's consent
   itself is informed; the primer's claim is still ours and must be true.
2. **AFib "N days observed" line carries no window** (`HeartDetailView`):
   N is distinct days within the 30/90-day fetch window, but the line reads as
   all-time. Suggested copy: "… · N of the last 30 days observed".
3. **`observedTypes` (background delivery) covers only the MVP 7** — new BP /
   body / AFib / wrist-temp data does not wake a background refresh; it lands
   on the next foreground sync. Deliberate battery posture; recorded here so
   the drift from `readTypes` is a decision, not an accident.
4. **Extended-panel mock coverage:** the demo user generates no BP / insulin /
   AFib / body-comp streams, so those demo screens run on design seeds, not
   `MockDataProvider` output. Wrist temperature is mock-covered from day one;
   backfilling the rest changes the demo persona and needs a product decision.

## 5 · Verification

- `T-COV-01…09` (`MaudeTests/HealthKitCoverageTests.swift`) — pure-value; no
  HK store constructed, no live path awaited.
- Existing suites: `HealthKitTests`, `IngestionTests`, `ArbitrationTests`
  unchanged and green; full suite green (counts in the wave report).
- `scripts/guard_provenance.sh` + `scripts/guard_donation_egress.sh` green.
- QMS: RTM rows FR-ING-16/17/18 + RISK section "HealthKit coverage audit"
  (2026-08-18).

## 6 · Addendum (2026-08-19) — governing rule OVERRULED by CN directive (FR-ING-19)

CN, verbatim, 2026-08-19: *"I want all data from Apple HealthKit — every data
point."* This supersedes §0's governing rule ("NO type is read without a named
consumer") for the READ SET: authorization now asks for the full public set,
with **completeness of the citizen's own record** as the stated purpose and
**DataBrowserView "Everything you measure"** as the one named consumer for the
breadth layer. The override is recorded as a controller decision in
`qms/DHF.md` (2026-08-19 entry); requirement + risk rows: RTM FR-ING-19, RISK
RK-ING-13/14 + RK-NDG-05. The four tuned pipelines this audit verified are
unchanged — the universal layer stores everything EXCEPT their types, and
`MaudeTests/UniversalReadTests.swift` (T-UNI-01..14) pins the isolation.
Report-only finding ① (§4.1, the primer's "these — and only these" lead) is
CLOSED by `HealthKitPrimerView` v03.
