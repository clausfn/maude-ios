import Testing
import Foundation
@testable import Liviqa

// FR-TOD-07 — the adaptive Home signal grid: Home shows what the person
// measures (CN directive 2026-08-19, "this is an app for all people").
//
// Invariants under test:
//  · availability truth table — each domain earns its card iff it has ≥1
//    reading in its own recent window; a CGM-less person gets NO glucose card
//    (the diabetes-first defect), a watch-less person no recovery card;
//  · grid bounds — never fewer than 2 cards, never more than 6; overflow keeps
//    the domains with the richest recent data;
//  · ordering stability — display order is ALWAYS canonical, so cards can
//    never shuffle day to day; only membership follows the data;
//  · sample mode — the sample person (workouts + steps in SampleDataset) shows
//    the whole-person grid through the SAME pure function;
//  · guard — every new fixed template (verdict words, momentum items, "See
//    why" copy) passes NudgeGuard (FR-NDG-06 rail).
//
// Pure value fixtures only: no HealthKit store is constructed and no live
// read is awaited anywhere in this file.
struct TodayGridAvailabilityTests {

    private let cal = Calendar(identifier: .gregorian)

    /// A fixed anchor mid-day, so day windows never straddle a test run.
    private var now: Date {
        cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
    }
    private func day(_ back: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -back, to: now)!)
    }

    // MARK: fixture streams (one helper per domain — provenance stays a data field)

    private func sleep(_ s: inout HealthSamples, daysBack: [Int]) {
        for d in daysBack {
            s.sleep.append(SleepReading(date: day(d), stage: .core, hours: 7,
                                        source: "Watch", tier: .good, provenance: .real))
        }
    }
    private func glucose(_ s: inout HealthSamples, daysBack: [Int]) {
        for d in daysBack {
            s.glucose.append(GlucoseReading(ts: day(d).addingTimeInterval(9 * 3600), mmol: 6.1,
                                            source: "CGM", tier: .good, provenance: .real))
        }
    }
    private func steps(_ s: inout HealthSamples, daysBack: [Int], value: Double = 8412) {
        for d in daysBack {
            s.steps.append(DailyMetric(date: day(d), kind: .steps, value: value,
                                       source: "iPhone", tier: .estimate, provenance: .real))
        }
    }
    private func workouts(_ s: inout HealthSamples, daysBack: [Int]) {
        for d in daysBack {
            let start = day(d).addingTimeInterval(17 * 3600)
            s.workouts.append(WorkoutReading(start: start, end: start.addingTimeInterval(3600),
                                             type: "Cycling", durMin: 60, kcal: 480,
                                             source: "Watch", tier: .estimate, provenance: .real))
        }
    }
    private func hrv(_ s: inout HealthSamples, daysBack: [Int]) {
        for d in daysBack {
            s.hrv.append(DailyMetric(date: day(d), kind: .hrvSDNN, value: 48,
                                     source: "Watch", tier: .good, provenance: .real))
        }
    }
    private func rhr(_ s: inout HealthSamples, daysBack: [Int]) {
        for d in daysBack {
            s.restingHR.append(DailyMetric(date: day(d), kind: .restingHR, value: 58,
                                           source: "Watch", tier: .good, provenance: .real))
        }
    }
    private func weight(_ s: inout HealthSamples, daysBack: [Int]) {
        for d in daysBack {
            s.bodyComposition.append(BodyCompositionReading(ts: day(d).addingTimeInterval(8 * 3600),
                                                            weightKg: 74.2,
                                                            source: "Scale", tier: .good,
                                                            provenance: .real))
        }
    }

    private func presentDomains(_ cards: [HomeCard]) -> [HomeDomain] {
        cards.filter(\.present).map(\.domain)
    }

    // MARK: - Availability truth table

    @Test func aGymPersonWithNoCGMGetsNoGlucoseCard() {
        // CN's canonical example: sleep + steps + workouts + heart, no CGM.
        var s = HealthSamples()
        sleep(&s, daysBack: [0, 1, 2, 3])
        steps(&s, daysBack: [0, 1, 2, 3, 4])
        workouts(&s, daysBack: [1, 3])
        rhr(&s, daysBack: [0, 1, 2])
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(presentDomains(cards) == [.sleep, .activity, .fitness, .heart])
        #expect(!cards.contains { $0.domain == .glucose })   // the defect, removed
        #expect(!cards.contains { $0.domain == .recovery })  // no HRV → no card
    }

    @Test func aWatchlessUserGetsNoRecoveryCard() {
        var s = HealthSamples()
        sleep(&s, daysBack: [0, 1])
        glucose(&s, daysBack: [0, 1, 2])
        steps(&s, daysBack: [0, 1])
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(presentDomains(cards) == [.sleep, .glucose, .activity])
        #expect(!cards.contains { $0.domain == .recovery })
    }

    @Test func eachDomainEarnsItsCardIffItHasRecentData() {
        // One domain at a time: the card appears for exactly that domain.
        for domain in HomeDomain.allCases {
            var s = HealthSamples()
            switch domain {
            case .sleep:    sleep(&s, daysBack: [1])
            case .glucose:  glucose(&s, daysBack: [1])
            case .activity: steps(&s, daysBack: [1])
            case .fitness:  workouts(&s, daysBack: [1])
            case .recovery: hrv(&s, daysBack: [1])
            case .heart:    rhr(&s, daysBack: [1])
            case .body:     weight(&s, daysBack: [1])
            }
            let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
            #expect(presentDomains(cards) == [domain],
                    "only \(domain) has data, so only \(domain) may claim presence")
        }
    }

    @Test func aReadingOutsideItsWindowDoesNotEarnACard() {
        var s = HealthSamples()
        sleep(&s, daysBack: [9])        // sleep window is 7 days — too old
        glucose(&s, daysBack: [8])      // glucose window is 7 days — too old
        workouts(&s, daysBack: [10])    // fitness window is 14 days — PRESENT
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(presentDomains(cards) == [.fitness])
    }

    // MARK: - Grid bounds (min 2 · max 6)

    @Test func sevenPresentDomainsAreCutToTheSixRichest() {
        var s = HealthSamples()
        sleep(&s, daysBack: [0, 1, 2, 3, 4])
        glucose(&s, daysBack: [0, 1, 2, 3])
        steps(&s, daysBack: [0, 1, 2, 3, 4, 5])
        workouts(&s, daysBack: [1, 3, 5])
        hrv(&s, daysBack: [0, 1, 2, 3])
        rhr(&s, daysBack: [0, 1, 2, 3])
        weight(&s, daysBack: [2])                       // least rich → cut
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(cards.count == TodaySignalsDeriver.gridMax)
        #expect(!cards.contains { $0.domain == .body })
        #expect(cards.allSatisfy { $0.present })
    }

    @Test func theRichnessCutIsByData_NotByAFixedFavourite() {
        // Same seven domains, but now HEART is the sparse one — it is cut, and
        // body (rich weigh-in history) survives. The grid follows the data.
        var s = HealthSamples()
        sleep(&s, daysBack: [0, 1, 2, 3, 4])
        glucose(&s, daysBack: [0, 1, 2, 3])
        steps(&s, daysBack: [0, 1, 2, 3, 4, 5])
        workouts(&s, daysBack: [1, 3, 5])
        hrv(&s, daysBack: [0, 1, 2, 3])
        rhr(&s, daysBack: [6])                           // one old day — sparse
        weight(&s, daysBack: [0, 2, 4, 6, 8, 10, 12])    // rich
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(cards.count == TodaySignalsDeriver.gridMax)
        #expect(!cards.contains { $0.domain == .heart })
        #expect(cards.contains { $0.domain == .body && $0.present })
    }

    @Test func aSingleDomainIsPaddedToTwoCards_PadClaimsNothing() {
        var s = HealthSamples()
        glucose(&s, daysBack: [0, 1])
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(cards.count == TodaySignalsDeriver.gridMin)
        #expect(cards.map(\.domain) == [.sleep, .glucose])   // canonical order
        #expect(cards.first { $0.domain == .glucose }?.present == true)
        #expect(cards.first { $0.domain == .sleep }?.present == false)  // calibrating pad
    }

    @Test func emptySamplesYieldTheCalibratingDefault_WithoutGlucose() {
        let cards = TodaySignalsDeriver.homeCards(from: .empty, now: now)
        #expect(cards == TodaySignalsDeriver.calibratingCards)
        #expect(cards.map(\.domain) == [.sleep, .activity, .recovery, .heart])
        #expect(cards.allSatisfy { !$0.present })
        #expect(!cards.contains { $0.domain == .glucose })
    }

    // MARK: - Ordering stability

    @Test func displayOrderIsAlwaysCanonical_SoRichnessChangesCannotShuffleCards() {
        // Day A: activity much richer than sleep. Day B: reversed. Same
        // availability → identical card order both days.
        var a = HealthSamples()
        sleep(&a, daysBack: [0])
        steps(&a, daysBack: [0, 1, 2, 3, 4, 5, 6])
        rhr(&a, daysBack: [0, 1])
        var b = HealthSamples()
        sleep(&b, daysBack: [0, 1, 2, 3, 4, 5, 6])
        steps(&b, daysBack: [0])
        rhr(&b, daysBack: [0, 1])
        let cardsA = TodaySignalsDeriver.homeCards(from: a, now: now)
        let cardsB = TodaySignalsDeriver.homeCards(from: b, now: now)
        #expect(cardsA == cardsB)
        #expect(cardsA.map(\.domain) == [.sleep, .activity, .heart])
    }

    @Test func theSameDataYieldsTheSameGridTheNextDay() {
        // Shift every reading one day older AND the clock one day forward —
        // the person's situation is unchanged, so the grid must be too.
        var s = HealthSamples()
        sleep(&s, daysBack: [0, 1, 2])
        steps(&s, daysBack: [0, 1, 2, 3])
        workouts(&s, daysBack: [2, 4])
        let today = TodaySignalsDeriver.homeCards(from: s, now: now)
        let tomorrow = TodaySignalsDeriver.homeCards(
            from: s, now: cal.date(byAdding: .day, value: 1, to: now)!)
        // One day on, every reading is one day older but still in-window.
        #expect(today == tomorrow)
    }

    @Test func classicDiabeticKeepsTheDesignedLeadOrder() {
        // The A7.2 four, no movement data: the canvas order survives intact.
        var s = HealthSamples()
        sleep(&s, daysBack: [0, 1])
        glucose(&s, daysBack: [0, 1])
        hrv(&s, daysBack: [0, 1])
        rhr(&s, daysBack: [0, 1])
        let cards = TodaySignalsDeriver.homeCards(from: s, now: now)
        #expect(cards.map(\.domain) == [.sleep, .glucose, .recovery, .heart])
        #expect(cards.allSatisfy { $0.present })
    }

    // MARK: - TodaySignals carries the whole-person figures

    @Test func deriveRunsForAGymPersonWithNoClassicSignals() throws {
        // Steps + workouts ONLY: before FR-TOD-07 this returned nil (cold
        // start for a person with plenty of data).
        var s = HealthSamples()
        steps(&s, daysBack: [0, 1, 2, 3], value: 8412)
        workouts(&s, daysBack: [1, 3, 9])
        let sig = try #require(TodaySignalsDeriver.derive(from: s, now: now))
        #expect(sig.steps == "8,412")
        #expect(sig.stepsWeek.count == 4)
        #expect(sig.stepsWeek.count == sig.stepsWeekDates.count)   // day-axis rule
        #expect(sig.workoutsWeek == 2)          // days −1, −3
        #expect(sig.workoutsPrevWeek == 1)      // day −9
        #expect(sig.inRange == "—")             // nothing invented for glucose
        #expect(sig.glucoseToday.isEmpty)
        #expect(!sig.cards.contains { $0.domain == .glucose })
    }

    @Test func stepsWeekSeriesShipsWithMatchingDates() throws {
        var s = HealthSamples()
        steps(&s, daysBack: [6, 3, 0])
        let sig = try #require(TodaySignalsDeriver.derive(from: s, now: now))
        #expect(sig.values(.steps).count == 3)
        #expect(sig.values(.steps).count == sig.dates(.steps).count)
        #expect(sig.dates(.steps) == sig.dates(.steps).sorted())
    }

    @Test func fitnessFiguresComeFromTheRealDeriver() throws {
        var s = HealthSamples()
        // Four weekly rides at 60 load points each (480 kcal / 60 min / 8 = ×1.0).
        workouts(&s, daysBack: [0, 8, 15, 22])
        let sig = try #require(TodaySignalsDeriver.derive(from: s, now: now))
        let fit = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(sig.workoutLoadWeeks == fit.loadWeeks.map(\.points))
        #expect(sig.workoutLoadUsual == fit.loadUsual)
    }

    @Test func weightSeriesAndLatestComeFromWeighIns() throws {
        var s = HealthSamples()
        weight(&s, daysBack: [20, 10, 2])
        let sig = try #require(TodaySignalsDeriver.derive(from: s, now: now))
        #expect(sig.weightSeries.count == 3)
        #expect(sig.weightLatest == "74.2")
        #expect(sig.cards.contains { $0.domain == .body && $0.present })
    }

    // MARK: - Sample mode + fixtures

    @Test func theSamplePersonShowsTheWholePersonGrid() throws {
        // SampleDataset carries steps, energy, workouts and weigh-ins — the
        // sample person's grid must show movement, through the SAME pure path.
        let sig = try #require(TodaySignalsDeriver.derive(from: SampleDataset.samples(now: now),
                                                          now: now))
        #expect(sig.cards.count >= TodaySignalsDeriver.gridMin)
        #expect(sig.cards.count <= TodaySignalsDeriver.gridMax)
        #expect(sig.cards.contains { $0.domain == .activity && $0.present })
        #expect(sig.cards.contains { $0.domain == .fitness && $0.present })
        // Canonical order holds on the sample too.
        let order = HomeDomain.allCases
        let indices = sig.cards.map { order.firstIndex(of: $0.domain)! }
        #expect(indices == indices.sorted())
    }

    @Test func fixturesWithoutSampleStreamsKeepTheClassicFour() {
        // LV001 and the test fixtures construct TodaySignals directly — the
        // default card list is the pre-FR-TOD-07 grid, never an empty one.
        let sig = TodaySignals(sleep: "7h10", inRange: "88%", hrv: "27", rhr: "70",
                               inRangeIsClay: false)
        #expect(sig.cards == HomeCard.classicFour)
        #expect(sig.cards.map(\.domain) == [.sleep, .glucose, .recovery, .heart])
    }

    // MARK: - FR-NDG-06: every new fixed template passes the guard

    @Test func newVerdictWordsAndMomentumItemsPassTheNudgeGuard() {
        let templates = [
            "As usual", "Above your usual", "Below your usual", "Steady",
            "Steps +12%", "Steps −8%", "Workouts +1", "Workouts −2",
        ]
        for t in templates {
            #expect(NudgeGuard.check(t) == nil, "guard rejected: \(t)")
        }
    }

    @Test func newSeeWhyBuildersAreGuardCleanInEveryState() {
        let explanations = [
            SeeWhyExplainer.activityCard(verdict: "As usual", value: "8,412",
                                         series: [7000, 8000, 9000, 8412],
                                         band: 7000...9000,
                                         hasRealSignals: true, coldStart: false),
            SeeWhyExplainer.activityCard(verdict: "As usual", value: "—", series: [],
                                         band: nil, hasRealSignals: true, coldStart: false),
            SeeWhyExplainer.activityCard(verdict: "—", value: "—", series: [],
                                         band: nil, hasRealSignals: false, coldStart: true),
            SeeWhyExplainer.fitnessCard(verdict: "As usual", sessions: 3,
                                        loadWeeks: [60, 55, 70, 62], loadUsual: 61.7,
                                        hasRealSignals: true, coldStart: false),
            SeeWhyExplainer.fitnessCard(verdict: "As usual", sessions: 1,
                                        loadWeeks: [60], loadUsual: nil,
                                        hasRealSignals: true, coldStart: false),
            SeeWhyExplainer.fitnessCard(verdict: "As usual", sessions: 0,
                                        loadWeeks: [], loadUsual: nil,
                                        hasRealSignals: false, coldStart: false),
            SeeWhyExplainer.bodyCard(verdict: "Steady", value: "74.2",
                                     series: [74.6, 74.4, 74.1, 74.2],
                                     band: 74.0...74.6,
                                     hasRealSignals: true, coldStart: false),
            SeeWhyExplainer.bodyCard(verdict: "Steady", value: "—", series: [],
                                     band: nil, hasRealSignals: true, coldStart: false),
        ]
        for e in explanations {
            #expect(NudgeGuard.check(e.verdict) == nil)
            if let u = e.unexplained { #expect(NudgeGuard.check(u) == nil) }
            for row in e.rows {
                #expect(NudgeGuard.check(row.label) == nil, "label: \(row.label)")
                #expect(NudgeGuard.check(row.value) == nil, "row: \(row.value)")
            }
            #expect(NudgeGuard.check(e.footer) == nil)
        }
    }

    @Test func fitnessVerdictConstantIsSharedWithItsCopy() {
        // The Workouts word and its "See why" sentence must share ONE constant.
        #expect(SeeWhyExplainer.loadUsualFraction == 0.25)
    }
}
