// SeeWhyExplainerTests.swift — T-XPL-01: the universal "See why" decomposition
// and the published method notes (FR-XPL-01, Bevel absorb ②).
//
// What is pinned here:
//  · FR-NDG-06 (DESIGNATED CONTROL): every fixed template this feature can put on
//    a screen — surface, verdict echo, row label, row value, honest-absence copy,
//    footer, and every string in the four method notes — passes NudgeGuard. The
//    disclosure is new user-facing generated text, so it goes through the same
//    allow-list as a nudge.
//  · HONEST ABSENCE: a surface that cannot be decomposed from real data returns
//    `unexplained` copy and NO rows. It never emits a plausible-sounding blurb.
//  · SINGLE SOURCE: the Home register and the evening score legs are chosen by
//    the same functions that write the explanation, so the sentence on screen and
//    the arithmetic in the sheet cannot drift apart.
//  · PERSONAL BASELINE: no clinical/population framing leaks into the copy, and
//    the two places Liviqa does use a shared reference are NAMED.
import Testing
import Foundation
@testable import Liviqa

struct SeeWhyExplainerTests {

    // Real-shaped series (oldest → today).
    private let risingTir: [Double]  = [60, 62, 64, 72, 74, 76, 78]
    private let steadyTir: [Double]  = [80, 81, 79, 80, 82, 80, 81]
    private let lowTir: [Double]     = [62, 65, 61, 58, 60, 63, 59]
    private let risingSleep: [Double] = [6.2, 6.4, 6.1, 7.0, 7.2, 7.1, 7.4]
    private let steadySleep: [Double] = [7.0, 7.1, 6.9, 7.0, 7.1, 7.0, 7.0]
    private let hrvWeek: [Double]    = [48, 45, 39, 41, 44, 50, 52]

    // MARK: - Every template the feature can print

    /// Everything a user can be shown by this feature, in every branch.
    private func allExplanations() -> [SeeWhyExplanation] {
        var out: [SeeWhyExplanation] = []

        // Home hero — all three registers, plus sample / cold-start / thin data.
        out.append(SeeWhyExplainer.todayHero(
            tone: .uneven, verdict: "A more uneven week — that happens.",
            tirWeek: lowTir, sleepWeek: steadySleep,
            hasRealSignals: true, coldStart: false))
        out.append(SeeWhyExplainer.todayHero(
            tone: .improving, verdict: "This week is trending gently up.",
            tirWeek: risingTir, sleepWeek: steadySleep,
            hasRealSignals: true, coldStart: false))
        out.append(SeeWhyExplainer.todayHero(
            tone: .improving, verdict: "This week is trending gently up.",
            tirWeek: steadyTir, sleepWeek: risingSleep,
            hasRealSignals: true, coldStart: false))
        out.append(SeeWhyExplainer.todayHero(
            tone: .steady, verdict: "You're having a steady week.",
            tirWeek: steadyTir, sleepWeek: steadySleep,
            hasRealSignals: true, coldStart: false))
        out.append(SeeWhyExplainer.todayHero(
            tone: .steady, verdict: "You're having a steady week.",
            tirWeek: [], sleepWeek: [], hasRealSignals: false, coldStart: false))
        out.append(SeeWhyExplainer.todayHero(
            tone: .steady, verdict: "Learning your normal.",
            tirWeek: [], sleepWeek: [], hasRealSignals: true, coldStart: true))
        out.append(SeeWhyExplainer.todayHero(
            tone: .improving, verdict: "This week is trending gently up.",
            tirWeek: [70, 74], sleepWeek: [7.0, 7.4],
            hasRealSignals: true, coldStart: false))

        // Signal cards — every domain, with and without a learned band.
        for domain in [SeeWhyExplainer.SignalDomain.sleep, .glucose, .recovery, .heart] {
            out.append(SeeWhyExplainer.signalCard(
                domain: domain, verdict: "Steady", value: "48",
                series: hrvWeek, band: 41.0...52.0,
                hasRealSignals: true, coldStart: false))
            out.append(SeeWhyExplainer.signalCard(
                domain: domain, verdict: "Steady", value: "48",
                series: [48, 50], band: nil,
                hasRealSignals: true, coldStart: false))
            out.append(SeeWhyExplainer.signalCard(
                domain: domain, verdict: "—", value: "—",
                series: [], band: nil, hasRealSignals: true, coldStart: true))
            out.append(SeeWhyExplainer.signalCard(
                domain: domain, verdict: "Steady", value: "48",
                series: [], band: nil, hasRealSignals: false, coldStart: false))
        }

        // Evening day score — three legs, two legs, and the sample case.
        let three = SeeWhyExplainer.dayScoreLegs(sleepHours: 6.9, tirPct: 78,
                                                 hrvLatest: 52, hrvPriorMean: 45)
        let two = SeeWhyExplainer.dayScoreLegs(sleepHours: 6.9, tirPct: 78,
                                               hrvLatest: nil, hrvPriorMean: nil)
        out.append(SeeWhyExplainer.dayScore(legs: three, verdict: "A steady day.",
                                            fromRealSignals: true))
        out.append(SeeWhyExplainer.dayScore(legs: two, verdict: "A lighter day — they happen.",
                                            fromRealSignals: true))
        out.append(SeeWhyExplainer.dayScore(legs: [], verdict: "A good day — mostly thanks to sleep.",
                                            fromRealSignals: false))

        // A marked day (FR-CTX-04) — a declared verdict still shows its work.
        for kind in ContextFlagKind.allCases {
            out.append(SeeWhyExplainer.markedDay(
                verdict: kind.todayHeadline, kindLabel: kind.label,
                startedText: "9 Aug", isOpen: true))
            out.append(SeeWhyExplainer.markedDay(
                verdict: kind.todayHeadline, kindLabel: kind.label,
                startedText: "9 Aug", isOpen: false))
        }

        // Metric-detail heroes — derived and seed branches.
        out.append(SeeWhyExplainer.sleepHero(
            verdict: "You slept like your usual self.", asleepMin: 430,
            weekMeanMin: 425, nightCount: 7, rest: 44.8, depth: 25.2, rhythm: 19.2,
            deepMin: 80, remMin: 104, source: "Apple Watch", isSeed: false))
        out.append(SeeWhyExplainer.sleepHero(
            verdict: "Last night, as your watch recorded it.", asleepMin: 402,
            weekMeanMin: 0, nightCount: 1, rest: nil, depth: nil, rhythm: nil,
            deepMin: 0, remMin: 0, source: nil, isSeed: false))
        out.append(SeeWhyExplainer.sleepHero(
            verdict: "You slept like your usual self.", asleepMin: 430,
            weekMeanMin: 430, nightCount: 7, rest: nil, depth: nil, rhythm: nil,
            deepMin: 0, remMin: 0, source: nil, isSeed: true))

        out.append(SeeWhyExplainer.glucoseHero(
            verdict: "In range 78% of the week — more than last week.",
            inRangePct: 78, prevWeekPct: 71, avgMmol: 6.4, gmiPct: 6.1,
            dayCount: 7, source: "Dexcom G7", isSeed: false))
        out.append(SeeWhyExplainer.glucoseHero(
            verdict: "In range 78% of the week.", inRangePct: 78, prevWeekPct: nil,
            avgMmol: 6.4, gmiPct: nil, dayCount: 3, source: nil, isSeed: false))
        out.append(SeeWhyExplainer.glucoseHero(
            verdict: "In range 88% of the week.", inRangePct: 88, prevWeekPct: 81,
            avgMmol: 6.2, gmiPct: 6.1, dayCount: 7, source: nil, isSeed: true))

        out.append(SeeWhyExplainer.heartHero(
            verdict: "Your heart is running calm.", rhrLatest: 58,
            band: 56.0...61.0, windowDays: 60, seriesCount: 14, isSeed: false))
        out.append(SeeWhyExplainer.heartHero(
            verdict: "Your heart, as recorded this week.", rhrLatest: nil,
            band: nil, windowDays: 0, seriesCount: 0, isSeed: false))
        out.append(SeeWhyExplainer.heartHero(
            verdict: "Your heart is running calm.", rhrLatest: 58,
            band: 56.0...61.0, windowDays: 60, seriesCount: 14, isSeed: true))

        out.append(SeeWhyExplainer.recoveryHero(
            verdict: "Recovery · stress (HRV)", latest: "48 ms",
            band: 41.0...52.0, seriesCount: 7, hasRealValue: true))
        out.append(SeeWhyExplainer.recoveryHero(
            verdict: "Recovery · stress (HRV)", latest: "48 ms",
            band: nil, seriesCount: 2, hasRealValue: true))
        out.append(SeeWhyExplainer.recoveryHero(
            verdict: "Recovery · stress (HRV)", latest: "42 ms",
            band: nil, seriesCount: 0, hasRealValue: false))

        out.append(SeeWhyExplainer.fitnessHero(
            verdict: "3 rides in — right around your usual load.", weekCount: 3,
            loadPoints: 312, loadUsual: 255, weeksCompared: 4, isSeed: false))
        out.append(SeeWhyExplainer.fitnessHero(
            verdict: "A quiet training week so far.", weekCount: 0,
            loadPoints: 0, loadUsual: nil, weeksCompared: 1, isSeed: false))
        out.append(SeeWhyExplainer.fitnessHero(
            verdict: "Three rides in.", weekCount: 3, loadPoints: 312,
            loadUsual: 255, weeksCompared: 4, isSeed: true))

        out.append(SeeWhyExplainer.activityHero(
            verdict: "4 days above your usual line this week.", daysAboveUsual: 4,
            usualSteps: 8300, usualFromHistory: true, pctVsUsual: 12,
            weekStepsTotal: 58400, dayCount: 7, isSeed: false))
        out.append(SeeWhyExplainer.activityHero(
            verdict: "Your week on foot, day by day.", daysAboveUsual: 0,
            usualSteps: 8300, usualFromHistory: false, pctVsUsual: nil,
            weekStepsTotal: 41000, dayCount: 5, isSeed: false))
        out.append(SeeWhyExplainer.activityHero(
            verdict: "You were on your feet on six days out of seven.",
            daysAboveUsual: 4, usualSteps: 8300, usualFromHistory: true,
            pctVsUsual: 12, weekStepsTotal: 58400, dayCount: 7, isSeed: true))

        out.append(SeeWhyExplainer.bodyHero(
            verdict: "Down 1.4 kg — a slow drift, nothing sudden.", deltaKg: -1.4,
            sinceMonth: "March", corridor: 70.5...72.0, pointCount: 11,
            source: "InBody", isSeed: false))
        out.append(SeeWhyExplainer.bodyHero(
            verdict: "Your measurements, as recorded.", deltaKg: nil,
            sinceMonth: "July", corridor: nil, pointCount: 1,
            source: nil, isSeed: false))
        out.append(SeeWhyExplainer.bodyHero(
            verdict: "Down 1.4 kg — drifting gently, not dieting.", deltaKg: -1.4,
            sinceMonth: "March", corridor: 70.5...72.0, pointCount: 11,
            source: nil, isSeed: true))

        let vitals = [
            VitalFact(name: "Oxygen saturation", unit: "%", latest: 97,
                      band: 95.5...98.0, decimals: 0, typical: true),
            VitalFact(name: "Respiratory rate", unit: "breaths/min", latest: 14.0,
                      band: 13.4...14.7, decimals: 1, typical: true),
        ]
        out.append(SeeWhyExplainer.vitalsHero(
            verdict: "Everything reads typical for you.", vitals: vitals, isSeed: false))
        out.append(SeeWhyExplainer.vitalsHero(
            verdict: "Everything reads typical for you.", vitals: [], isSeed: false))
        out.append(SeeWhyExplainer.vitalsHero(
            verdict: "Everything reads typical for you.", vitals: vitals, isSeed: true))

        // "Your usual" baseline detail.
        for topic in [LearnTopic.hrv, .usualBand] {
            out.append(SeeWhyExplainer.baseline(
                name: "HRV", verdict: "Right in your usual range.", value: 48,
                unit: "ms", band: 41.0...52.0, learnedFromDays: 30,
                seriesCount: 30, isSeed: false, method: topic))
            out.append(SeeWhyExplainer.baseline(
                name: "Sleep", verdict: "A little above your usual range.", value: 8.4,
                unit: "h", band: 6.5...7.8, learnedFromDays: nil,
                seriesCount: 3, isSeed: false, method: topic))
            out.append(SeeWhyExplainer.baseline(
                name: "RHR", verdict: "Right in your usual range.", value: 58,
                unit: "bpm", band: 56.0...61.0, learnedFromDays: nil,
                seriesCount: 0, isSeed: true, method: topic))
        }

        // Insight evidence — gated and below the gate.
        out.append(SeeWhyExplainer.nudge(
            verdict: "Late dinners are costing you sleep.", n: 14, nUnit: "nights",
            baselineDays: 30, r: -0.62, pText: "≤0.01", isGated: true,
            baselineNeeded: nil))
        out.append(SeeWhyExplainer.nudge(
            verdict: "We're still learning your baseline.", n: 6, nUnit: "nights",
            baselineDays: 30, r: nil, pText: nil, isGated: false,
            baselineNeeded: 30))
        out.append(SeeWhyExplainer.nudge(
            verdict: "We're still learning your baseline.", n: 6, nUnit: "nights",
            baselineDays: 30, r: nil, pText: nil, isGated: false,
            baselineNeeded: nil))

        return out
    }

    /// FR-NDG-06 is a designated control: EVERY string this feature can render
    /// goes through the allow-list, exactly as a nudge would.
    @Test func everyDisclosureTemplatePassesNudgeGuard() {
        let all = allExplanations()
        #expect(all.count > 40)
        for e in all {
            for text in [e.surface, e.verdict, e.footer] + [e.unexplained].compactMap({ $0 })
                + e.rows.map(\.label) + e.rows.map(\.value) {
                #expect(NudgeGuard.check(text) == nil,
                        "forbidden construction in See-why template: \(text)")
            }
        }
    }

    /// Personal-baseline rail: the disclosure never borrows clinical-normality
    /// language, and never claims a comparison against other people.
    ///
    /// NOTE on "reference range": the phrase is deliberately NOT banned, because
    /// the vitals disclosure uses it to DENY one ("none of them is a clinical
    /// reference range") — the same reason NudgeGuard is written to catch
    /// affirmative claims and let disclaimers through. `vitalsDeniesAClinicalRange`
    /// below pins that it stays a denial.
    @Test func noPopulationOrNormalityLanguage() {
        let banned = ["normal range", "healthy range", "average person",
                      "compared to others", "percentile", "everyone else"]
        for e in allExplanations() {
            let blob = ([e.surface, e.verdict, e.footer]
                        + [e.unexplained].compactMap { $0 }
                        + e.rows.map { $0.label + " " + $0.value })
                .joined(separator: " ").lowercased()
            for phrase in banned {
                #expect(!blob.contains(phrase), "population framing leaked: \(phrase)")
            }
        }
    }

    @Test func vitalsDeniesAClinicalRange() {
        let e = SeeWhyExplainer.vitalsHero(
            verdict: "Everything reads typical for you.",
            vitals: [VitalFact(name: "Oxygen saturation", unit: "%", latest: 97,
                               band: 95.5...98.0, decimals: 0, typical: true)],
            isSeed: false)
        #expect(e.rows.contains { $0.value.contains("None of them is a clinical reference range") })
    }

    /// Every disclosure carries the verbatim personal-baseline footer.
    @Test func everyDisclosureCarriesTheBaselineFooter() {
        for e in allExplanations() {
            #expect(e.footer == SeeWhyExplainer.footer)
            #expect(e.footer.contains("compares you only to yourself"))
            #expect(e.footer.contains("not a diagnostic measure"))
        }
    }

    // MARK: - Honest absence, not a vague blurb

    /// A surface built from sample seeds must SAY it is sample data and emit no
    /// rows — an invented decomposition is the exact failure this feature exists
    /// to prevent.
    @Test func sampleDataExplainsItselfWithNoRows() {
        let seeds: [SeeWhyExplanation] = [
            SeeWhyExplainer.todayHero(tone: .steady, verdict: "You're having a steady week.",
                                      tirWeek: [], sleepWeek: [],
                                      hasRealSignals: false, coldStart: false),
            SeeWhyExplainer.signalCard(domain: .glucose, verdict: "Steady", value: "61%",
                                       series: [], band: nil,
                                       hasRealSignals: false, coldStart: false),
            SeeWhyExplainer.dayScore(legs: [], verdict: "A steady day.", fromRealSignals: false),
            SeeWhyExplainer.sleepHero(verdict: "x", asleepMin: 430, weekMeanMin: 430,
                                      nightCount: 7, rest: nil, depth: nil, rhythm: nil,
                                      deepMin: 0, remMin: 0, source: nil, isSeed: true),
            SeeWhyExplainer.glucoseHero(verdict: "x", inRangePct: 88, prevWeekPct: nil,
                                        avgMmol: 6.2, gmiPct: nil, dayCount: 7,
                                        source: nil, isSeed: true),
            SeeWhyExplainer.heartHero(verdict: "x", rhrLatest: 58, band: nil,
                                      windowDays: 0, seriesCount: 0, isSeed: true),
            SeeWhyExplainer.vitalsHero(verdict: "x", vitals: [], isSeed: true),
        ]
        for e in seeds {
            #expect(e.rows.isEmpty, "a sample-data surface must not print rows")
            #expect(e.unexplained != nil)
        }
    }

    @Test func coldStartSaysThereIsNothingToExplainYet() {
        let hero = SeeWhyExplainer.todayHero(
            tone: .steady, verdict: "Learning your normal.",
            tirWeek: [], sleepWeek: [], hasRealSignals: true, coldStart: true)
        #expect(hero.rows.isEmpty)
        #expect(hero.unexplained != nil)
        #expect(hero.method == .usualBand)

        let card = SeeWhyExplainer.signalCard(
            domain: .sleep, verdict: "—", value: "—", series: [], band: nil,
            hasRealSignals: true, coldStart: true)
        #expect(card.rows.isEmpty)
        #expect(card.unexplained != nil)
    }

    /// Under four days there is no earlier/later half to compare, so the hero
    /// says so rather than inventing a split.
    @Test func thinSeriesRefusesToSplitTheWeek() {
        let hero = SeeWhyExplainer.todayHero(
            tone: .improving, verdict: "This week is trending gently up.",
            tirWeek: [70, 74], sleepWeek: [7.0, 7.4],
            hasRealSignals: true, coldStart: false)
        #expect(hero.rows.isEmpty)
        #expect(hero.unexplained != nil)
    }

    /// A band that has not been learned is named as absent, never approximated.
    @Test func missingBandIsStatedNotFaked() {
        let card = SeeWhyExplainer.signalCard(
            domain: .recovery, verdict: "Steady", value: "48 ms",
            series: [48, 50], band: nil, hasRealSignals: true, coldStart: false)
        let baseline = card.rows.first { $0.label == SeeWhyExplainer.lBaseline }
        #expect(baseline?.value.contains("not drawn yet") == true)
    }

    // MARK: - The arithmetic actually matches

    @Test func halvesMatchTheHomeSplit() throws {
        let h = try #require(SeeWhyExplainer.halves([1, 1, 1, 3, 3, 3]))
        #expect(abs(h.early - 1) < 0.0001)
        #expect(abs(h.late - 3) < 0.0001)
        #expect(SeeWhyExplainer.halves([1, 2, 3]) == nil)   // too thin to split
        #expect(SeeWhyExplainer.trendingUp([1, 1, 1, 3, 3, 3], by: 1.5))
        #expect(!SeeWhyExplainer.trendingUp([1, 1, 1, 3, 3, 3], by: 2.5))
    }

    /// The legs the ring is drawn from ARE the legs the sheet prints.
    @Test func dayScoreLegsMatchThePublishedFormula() {
        let legs = SeeWhyExplainer.dayScoreLegs(sleepHours: 6.4, tirPct: 78,
                                                hrvLatest: 52, hrvPriorMean: 45)
        #expect(legs.count == 3)
        #expect(abs(legs[0].points - min(6.4 / 8, 1) * 50) < 0.0001)
        #expect(abs(legs[1].points - 78.0 / 100 * 30) < 0.0001)
        #expect(abs(legs[2].points - min(52.0 / 45.0, 1) * 20) < 0.0001)

        // Caps hold: a very long night cannot buy more than its 50.
        let capped = SeeWhyExplainer.dayScoreLegs(sleepHours: 11, tirPct: 100,
                                                  hrvLatest: 90, hrvPriorMean: 45)
        #expect(abs(capped[0].points - 50) < 0.0001)
        #expect(abs(capped[2].points - 20) < 0.0001)

        // Legs are omitted, never zero-filled, when the data is absent.
        #expect(SeeWhyExplainer.dayScoreLegs(sleepHours: nil, tirPct: 78,
                                             hrvLatest: nil, hrvPriorMean: nil).count == 1)
    }

    /// The score sheet prints the sum of the legs and the honest denominator.
    @Test func dayScoreSheetAddsUpAndNamesTheFixedReference() throws {
        let legs = SeeWhyExplainer.dayScoreLegs(sleepHours: 6.4, tirPct: 78,
                                                hrvLatest: 52, hrvPriorMean: 45)
        let e = SeeWhyExplainer.dayScore(legs: legs, verdict: "A steady day.",
                                         fromRealSignals: true)
        let total = Int(legs.reduce(0) { $0 + $1.points }.rounded())
        let added = try #require(e.rows.first { $0.label == SeeWhyExplainer.lTotal })
        #expect(added.value.contains("\(total) out of 100"))

        // The one non-personal leg is named, not hidden.
        let reference = try #require(e.rows.first { $0.label == SeeWhyExplainer.lReference })
        #expect(reference.value.contains("8-hour reference"))

        // Two legs ⇒ the denominator is honest about it.
        let two = SeeWhyExplainer.dayScoreLegs(sleepHours: 6.4, tirPct: 78,
                                               hrvLatest: nil, hrvPriorMean: nil)
        let partial = SeeWhyExplainer.dayScore(legs: two, verdict: "A steady day.",
                                               fromRealSignals: true)
        #expect(partial.rows.contains { $0.value.contains("out of 80") })
        #expect(e.method == .dayScore)
    }

    /// The register and its explanation are picked by one function.
    @Test func toneAndExplanationCannotDisagree() {
        #expect(SeeWhyExplainer.todayTone(tirIsClay: true, tirWeek: risingTir,
                                          sleepWeek: risingSleep) == .uneven)
        #expect(SeeWhyExplainer.todayTone(tirIsClay: false, tirWeek: risingTir,
                                          sleepWeek: steadySleep) == .improving)
        #expect(SeeWhyExplainer.todayTone(tirIsClay: false, tirWeek: steadyTir,
                                          sleepWeek: risingSleep) == .improving)
        #expect(SeeWhyExplainer.todayTone(tirIsClay: false, tirWeek: steadyTir,
                                          sleepWeek: steadySleep) == .steady)

        // Uneven names the shared clinical mark rather than passing it off as
        // "your usual" — that naming is the honesty requirement.
        let uneven = SeeWhyExplainer.todayHero(
            tone: .uneven, verdict: "A more uneven week — that happens.",
            tirWeek: lowTir, sleepWeek: steadySleep,
            hasRealSignals: true, coldStart: false)
        #expect(uneven.rows.contains { $0.value.contains("70%") })
    }

    /// The window row always reports the REAL day count — never a round number
    /// the data does not have.
    @Test func windowRowReportsRealCoverage() throws {
        let card = SeeWhyExplainer.signalCard(
            domain: .recovery, verdict: "Steady", value: "48 ms",
            series: [48, 45, 39, 41, 44], band: 39.0...48.0,
            hasRealSignals: true, coldStart: false)
        let window = try #require(card.rows.first { $0.label == SeeWhyExplainer.lWindow })
        #expect(window.value.contains("5 days"))
        #expect(window.value.contains("gaps are left as gaps"))
    }

    /// Recovery is the app's HRV surface, so its disclosure links to the HRV
    /// article (Area ⑨ entry point); the rest link to the "your usual" note.
    @Test func recoveryDisclosureLinksToTheHRVArticle() {
        #expect(SeeWhyExplainer.SignalDomain.recovery.method == .hrv)
        #expect(SeeWhyExplainer.SignalDomain.sleep.method == .usualBand)
        #expect(SeeWhyExplainer.SignalDomain.heart.method == .usualBand)
        #expect(SeeWhyExplainer.SignalDomain.glucose.method == .usualBand)
    }

    /// Below the evidence gate the disclosure states the refusal — it never
    /// dresses a weak correlation as a finding.
    @Test func belowTheGateTheDisclosureStatesTheRefusal() {
        let e = SeeWhyExplainer.nudge(
            verdict: "We're still learning your baseline.", n: 6, nUnit: "nights",
            baselineDays: 30, r: nil, pText: nil, isGated: false, baselineNeeded: 30)
        #expect(e.method == .evidenceGate)
        #expect(e.rows.contains { $0.value.contains("refuses to assert") })
        #expect(!e.rows.contains { $0.label.contains("Strength") })
    }

    /// A gated insight publishes both thresholds it cleared.
    @Test func gatedInsightPublishesItsThresholds() {
        let e = SeeWhyExplainer.nudge(
            verdict: "Late dinners are costing you sleep.", n: 14, nUnit: "nights",
            baselineDays: 30, r: -0.62, pText: "≤0.01", isGated: true,
            baselineNeeded: nil)
        #expect(e.rows.contains { $0.value.contains("0.40") })
        #expect(e.rows.contains { $0.value.contains("0.60") })
        #expect(e.rows.contains { $0.value.contains("0.05") })
    }
}

// MARK: - Published method notes (the other half of FR-XPL-01)

@MainActor
struct LearnMethodNoteTests {

    private var notes: [LearnArticle] {
        [LearnLibrary.usualBand, LearnLibrary.dayScore,
         LearnLibrary.evidenceGate, LearnLibrary.verdictWords]
    }

    private func strings(_ a: LearnArticle) -> [String] {
        [a.plainBackLabel, a.plainTitle, a.plainKicker, a.plainVerdict, a.plainBody,
         a.meaningKicker, a.meaningHeadline, a.meaningBody, a.deeperLinkLabel,
         a.plainFooter, a.clinicalBackLabel, a.clinicalTitle, a.clinicalKicker,
         a.clinicalVerdict, a.inPlainWords, a.methodKicker, a.methodHeadline,
         a.clinicalFooter]
        + a.methodRows.flatMap { [$0.label, $0.value] }
    }

    /// FR-NDG-06 on the published notes too — a method note is user-facing text.
    @Test func everyMethodNoteStringPassesNudgeGuard() {
        for note in notes {
            for text in strings(note) {
                #expect(NudgeGuard.check(text) == nil,
                        "forbidden construction in method note \(note.topic.rawValue): \(text)")
            }
        }
    }

    /// A method note publishes the RULE and carries no live figures — that is
    /// what makes it impossible for one to claim a number the user lacks.
    @Test func methodNotesCarryNoFabricatedFigures() {
        for note in notes {
            #expect(note.stat == nil)
            #expect(note.statSub == nil)
            #expect(note.weekChart == nil)
            #expect(note.weekHeadline == nil)
            #expect(!note.methodRows.isEmpty)
        }
    }

    /// The four rules the RTM row names are actually published, in the numbers
    /// the code uses.
    @Test func theRulesArePublishedAsTheCodeAppliesThem() {
        let band = strings(LearnLibrary.usualBand).joined(separator: " ")
        #expect(band.contains("mean − 1 SD … mean + 1 SD"))

        let score = strings(LearnLibrary.dayScore).joined(separator: " ")
        #expect(score.contains("8-hour reference"))
        #expect(score.contains("÷ 100 × 30"))
        #expect(score.contains("week average"))

        let gate = strings(LearnLibrary.evidenceGate).joined(separator: " ")
        #expect(gate.contains("|r| ≥ 0.40"))
        #expect(gate.contains("≤ 0.05"))
        #expect(gate.contains("≥ 10"))
        #expect(gate.contains("|r| ≥ 0.60"))

        let words = strings(LearnLibrary.verdictWords).joined(separator: " ")
        #expect(words.contains("allow-list"))
    }

    /// Every topic the See-why sheet can deep-link to resolves to a real article
    /// — a dead link in a trust feature is worse than no link.
    @Test func everyLearnTopicHasAnArticleAndABlurb() {
        for topic in LearnTopic.allCases {
            #expect(!SeeWhySheetView.methodBlurb(topic).isEmpty)
        }
        for note in notes {
            #expect(!note.plainTitle.isEmpty)
            #expect(!note.plainBody.isEmpty)
        }
        // The HRV article stays reachable with no derived detail at all.
        let hrv = LearnLibrary.hrv(detail: nil)
        #expect(hrv.stat == nil)
        #expect(NudgeGuard.check(hrv.meaningHeadline) == nil)
        #expect(NudgeGuard.check(hrv.meaningBody) == nil)
    }
}
