// ChatBehaviourTests.swift — A7.2 Area ⑨ acceptance tests for the four designed
// AI example behaviours (b-learn.jsx AIExplain / AITranslate / AICalibration /
// AIRedirect). The behaviours are intent-routed deterministic templates; these
// tests pin their honesty rails:
//  · explain uses the person's OWN week + baseline, never invented life context;
//  · plain-language claims ("vs your weeks") are computed or absent;
//  · calibration never fabricates a day counter (reconciled with Home);
//  · every offered follow-up chip passes the guard (never suggest-then-refuse);
//  · answer origin is honest ("on this iPhone" only when true).
import Testing
import Foundation
@testable import Maude

struct ChatBehaviourTests {

    // MARK: fixtures

    private func hrvDetail() -> HRVLearnDetail {
        HRVLearnDetail(latestMs: 52, windowDays: 60, rangeLoMs: 44, rangeHiMs: 58,
                       medianMs: 51, usualBand: 46.0...56.0,
                       weekSeries: [48, 45, 39, 41, 44, 50, 52],
                       weekTicks: ["M", "T", "W", "T", "F", "S", "S"],
                       weekLowMs: 39, weekLowDayName: "Wednesday",
                       dippedBelowUsual: true, recoveredToUsual: true)
    }

    private func richSummary() -> ChatHealthSummary {
        var s = ChatHealthSummary(avgGlucoseMmol7d: 6.7, glucoseTIRpct7d: 88,
                                  sleepAvgHours7d: 7.0, restingHRavg7d: 58,
                                  hrvAvgMs7d: 47, stepsAvg7d: 5600)
        s.hrvDetail = hrvDetail()
        s.daysOfData = 34
        s.tirMonthPct = 81
        s.glucoseBandLo = 3.9
        s.glucoseBandHi = 10.0
        s.todayRise = TodayGlucoseRise(peakTimeText: "13:40", backByTimeText: "14:35")
        return s
    }

    private func engine(_ s: ChatHealthSummary) -> ChatEngine { ChatEngine(summary: s) }

    // MARK: AIExplain — explain-a-drop from the person's own week

    @Test func explainDropUsesOwnFigures() {
        let r = engine(richSummary()).respond(to: "What is HRV and why did mine drop?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.contains("39"))            // the person's own low
        #expect(r.contains("Wednesday"))     // their own low day
        #expect(r.contains("51"))            // their own window median
        #expect(r.contains("60-day"))        // the REAL window label
    }

    @Test func explainDropNeverInventsLifeContext() {
        // The canvas answer names "three back-to-back meetings and a later
        // dinner" — context the app cannot know. The template must never claim it.
        let r = engine(richSummary()).respond(to: "What is HRV and why did mine drop?")
            .lowercased()
        #expect(!r.contains("meeting"))
        #expect(!r.contains("dinner"))
        #expect(!r.contains("busy day"))
    }

    @Test func explainDropSparseDataIsHonest() {
        // Only the 7-day average exists → no drop/rebound verdict is claimed.
        let s = ChatHealthSummary(hrvAvgMs7d: 42)
        let r = engine(s).respond(to: "why did my hrv drop?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.contains("42"))
        #expect(r.lowercased().contains("doesn't have enough of your own days"))
    }

    @Test func hrvHistoryDescribesOwnWindow() {
        let r = engine(richSummary()).respond(to: "Has my HRV dipped like this before?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.contains("44"))
        #expect(r.contains("58"))
        #expect(r.contains("60 days"))
    }

    @Test func hrvBetterDaysNeverAdvises() {
        // Re-authored from the canvas's advice-adjacent "What helps HRV?".
        let r = engine(richSummary()).respond(to: "What lines up with my better HRV days?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.lowercased().contains("doesn't guess at causes"))
        #expect(!r.lowercased().contains("you should"))
        #expect(!r.lowercased().contains("try "))
    }

    // MARK: AITranslate — plain language on request

    @Test func plainGlucoseTranslationUsesOwnWeek() {
        let r = engine(richSummary()).respond(to: "Explain my glucose like I'm new to this.")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.contains("fuel in your blood"))
        #expect(r.contains("88%"))
    }

    @Test func plainGlucoseComparativeClauseIsComputed() {
        // 88% this week vs an 81% own-month figure → honestly "above".
        let above = engine(richSummary()).respond(to: "Explain my glucose like I'm new to this.")
        #expect(above.contains("above your own month's average"))
        // No month figure → the comparative claim is CUT, never asserted.
        var s = richSummary(); s.tirMonthPct = nil
        let cut = engine(s).respond(to: "Explain my glucose like I'm new to this.")
        #expect(!cut.lowercased().contains("month's average"))
        #expect(!cut.lowercased().contains("better than most weeks"))
    }

    @Test func plainGlucosePostMealClauseOnlyFromRealCurve() {
        let with = engine(richSummary()).respond(to: "Explain my glucose like I'm new to this.")
        #expect(with.contains("13:40"))
        #expect(with.contains("14:35"))
        var s = richSummary(); s.todayRise = nil
        let without = engine(s).respond(to: "Explain my glucose like I'm new to this.")
        #expect(!without.lowercased().contains("rose after"))
        #expect(!without.contains("13:40"))
    }

    @Test func literacyShapesVoiceNeverHidesNumbers() {
        var plain = richSummary(); plain.literacy = .plain
        let p = engine(plain).respond(to: "How much of my week was glucose in range?")
        #expect(p.contains("88%"))
        #expect(p.lowercased().contains("comfortable middle band"))
        var clinical = richSummary(); clinical.literacy = .clinical
        let c = engine(clinical).respond(to: "How much of my week was glucose in range?")
        #expect(c.contains("88%"))
        #expect(c.lowercased().contains("target glucose range"))
    }

    @Test func rangeAnswerUsesOwnConfiguredBand() {
        let r = engine(richSummary()).respond(to: "What's a good range?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.contains("3.9"))
        #expect(r.contains("10"))
        #expect(r.contains("mmol/L"))                      // OD-07 canonical unit
        #expect(!r.lowercased().contains("you should"))
    }

    // MARK: AICalibration — honest sparse-data answer

    @Test func calibrationNeverFabricatesADayCounter() {
        // Reconciled with TodayView's deliberate no-fake-day-counter stance: the
        // canvas's "day 1 of about 14" must NOT ship.
        let r = engine(.empty).respond(to: "Why do my numbers look empty?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.lowercased().contains("watching more than talking"))
        #expect(!r.lowercased().contains("of about 14"))
        #expect(!r.lowercased().contains("day 1 of"))
        #expect(r.contains("about 3 days"))   // same expectation Home sets
    }

    @Test func calibrationStatesARealDayCountWhenOneExists() {
        var s = ChatHealthSummary(); s.daysOfData = 1
        let r = engine(s).respond(to: "Why do my numbers look empty?")
        #expect(r.contains("1 day of your own readings"))
    }

    @Test func emptySummaryAnswersCalibrationForAnyDataQuestion() {
        // With nothing to describe, the old "I can describe your glucose…" offer
        // was misleading — the honest calibration answer takes over.
        let r = engine(.empty).respond(to: "What was my average glucose last week?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(r.lowercased().contains("watching more than talking"))
    }

    @Test func speedUpAnswerIsDescriptiveNotAdvice() {
        let r = engine(.empty).respond(to: "Can I speed it up?")
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(ChatGuard.sanitizeOutput(r) == r)          // survives the sanitiser whole
        #expect(!r.lowercased().contains("you should"))
        #expect(!r.lowercased().contains("make sure"))
    }

    // MARK: AIRedirect — designed presentation around the UNCHANGED safety line

    @Test func redirectIntentIsSafetyAndLineIsUnchanged() {
        let reply = engine(richSummary()).reply(to: "Should I change my insulin dose?")
        #expect(reply.intent == .safety)
        #expect(reply.text == MaudeChatCopy.safetyLine)   // designated control, verbatim
    }

    @Test func redirectFollowUpsAreConsentFirstActionsOnly() {
        let chips = ChatFollowUps.followUps(for: .safety)
        #expect(chips.count == 2)
        for chip in chips {
            if case .ask = chip.kind {
                Issue.record("redirect chips must never send text back into the model: \(chip.label)")
            }
        }
        #expect(chips.contains { $0.kind == .shareSummary })
        #expect(chips.contains { $0.kind == .planConsult })
    }

    // MARK: follow-up chips — never suggest a question we then refuse

    @Test func everyOfferedFollowUpPassesTheGuard() {
        let intents: [ChatIntent] = [.explainHRVDrop, .hrvHistory, .hrvBetterDays,
                                     .plainGlucose, .glucoseRange, .mealRise,
                                     .calibration, .whatLearning, .speedUp, .generic]
        let e = engine(richSummary())
        for intent in intents {
            for chip in ChatFollowUps.followUps(for: intent) {
                if case .ask(let q) = chip.kind {
                    #expect(!ChatGuard.inputIsOutOfScope(q),
                            "offered chip trips the input guard: \(q)")
                    #expect(e.respond(to: q) != MaudeChatCopy.safetyLine,
                            "offered chip got refused: \(q)")
                }
            }
        }
    }

    // MARK: honest answer origin ("Answered on this iPhone" may never lie)

    @Test func onDeviceReplyCarriesOnDeviceOrigin() {
        let reply = engine(richSummary()).reply(to: "What was my average glucose last week?")
        #expect(reply.origin == .onDevice)
    }

    @Test func guardRefusalOnCloudPathNeverLeftThePhone() async {
        // The input guard refuses BEFORE any network call → origin stays onDevice
        // even on the consented cloud path.
        let reply = await engine(richSummary()).replyCloud(to: "Should I change my insulin dose?")
        #expect(reply.text == MaudeChatCopy.safetyLine)
        #expect(reply.origin == .onDevice)
        #expect(reply.intent == .safety)
    }

    // MARK: all Area ⑨ templates survive the output sanitiser whole

    @Test("Templates are guard-clean end to end", arguments: [
        "What is HRV and why did mine drop?",
        "Has my HRV dipped like this before?",
        "What lines up with my better HRV days?",
        "Explain my glucose like I'm new to this.",
        "What's a good range?",
        "Why does it rise after meals?",
        "What are you learning?",
        "Can I speed it up?",
    ])
    func templatesSurviveSanitiser(prompt: String) {
        let r = engine(richSummary()).respond(to: prompt)
        #expect(r != MaudeChatCopy.safetyLine)
        #expect(ChatGuard.sanitizeOutput(r) == r)
    }
}
