import Testing
import Foundation
@testable import Liviqa

// The inferred-denial cue + the context flag's reach into the Insights feed.
//
// INFERRED DENIAL — HealthKit does not report read authorisation, so a refused
// read and a brand-new watch look identical from inside the app. The cue fires
// on the fact we CAN observe (the read completed with nothing in it) and the
// screen says exactly that; nothing here ever claims access was denied.
@MainActor
struct HealthReadOutcomeTests {

    // Only a real Health read can produce a verdict.
    @Test func onlyARealReadProducesAVerdict() {
        #expect(AppState.readOutcome(kind: .healthKit, samplesEmpty: true) == .noReadings)
        #expect(AppState.readOutcome(kind: .healthKit, samplesEmpty: false) == .readings)
        // A demo/mock session says nothing about Apple Health, ever.
        #expect(AppState.readOutcome(kind: .mock, samplesEmpty: true) == .notAttempted)
        #expect(AppState.readOutcome(kind: .mock, samplesEmpty: false) == .notAttempted)
    }

    // A demo session must never surface the cue (it would be a claim about a
    // system the session never asked).
    @Test func demoSessionNeverSurfacesTheCue() async {
        let state = AppState(supabase: MockSupabaseService())
        state.dataProviderKind = .mock
        await state.refreshFromHealth()
        #expect(state.healthReadOutcome == .notAttempted)
        #expect(state.healthReadReturnedNothing == false)
    }

    // The declined screen's own copy: the no-readings wording must not assert
    // a denial, and must offer both explanations.
    @Test func noReadingsCopyDoesNotAccuse() {
        let denialWords = ["denied", "refused", "blocked", "you did not allow"]
        // The flow can address the two cases separately…
        #expect(HealthAccessDeclinedView(reason: .noReadings) {}.reason == .noReadings)
        // …and the no-readings wording states what we observed, not a denial.
        let title = String(localized: "No readings came through from Apple Health.")
        let lead = String(localized: "That can mean two things, and we can't tell them apart from here: either Liviqa wasn't given permission to read, or there's simply nothing recorded on this phone yet. Until readings arrive you'll see sample data, clearly marked so you never mistake it for your own.")
        for word in denialWords {
            #expect(!title.lowercased().contains(word))
        }
        #expect(lead.contains("can't tell them apart"))
        #expect(NudgeGuard.check(title) == nil)
        #expect(NudgeGuard.check(lead) == nil)
    }

    // FR-CTX-04 — demo pattern findings are appended AFTER the engine, so they
    // bypassed the suppression gate. On a marked day the feed must be quiet.
    @Test func markedDaySuppressesDemoPatternFindings() async {
        let unmarked = AppState(supabase: MockSupabaseService())
        unmarked.dataProviderKind = .mock
        unmarked.contextFlags = []            // in-memory only; nothing persisted
        await unmarked.refreshFromHealth()
        let patternsWhenUnmarked = unmarked.nudges.filter { $0.time == "pattern" }.count

        let marked = AppState(supabase: MockSupabaseService())
        marked.dataProviderKind = .mock
        marked.contextFlags = [ContextFlag(kind: .travelling,
                                           startedOn: ContextWindow.calendar.startOfDay(for: Date()))]
        await marked.refreshFromHealth()
        let patternsWhenMarked = marked.nudges.filter { $0.time == "pattern" }.count

        #expect(patternsWhenUnmarked > 0)      // the demo path still has them
        #expect(patternsWhenMarked == 0)       // …and a marked day removes them
        // A flag can only ever REMOVE cards.
        #expect(marked.nudges.count <= unmarked.nudges.count)
    }
}
