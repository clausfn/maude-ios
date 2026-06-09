// ChatSuggestionsTests.swift — every contextual question the assistant offers must
// stay inside the wellness scope (the guard must never turn an offered question into
// the safety line). Otherwise we'd be suggesting prompts we then refuse.
import Testing
import Foundation
@testable import Liviqa

struct ChatSuggestionsTests {

    private func engine() -> ChatEngine {
        ChatEngine(summary: .demo)
    }

    private func nudge(_ tag: String, _ accent: NudgeAccent, _ body: String = "") -> Nudge {
        Nudge(time: "now", tag: tag, body: body, accent: accent,
              primaryAction: "", secondaryActions: [], reasoning: nil)
    }

    @Test func contextualSuggestionsAreAllInScope() {
        let nudges = [
            nudge("Sleep · meals", .sleep, "late dinner tracked with shorter sleep"),
            nudge("Glucose · cycling", .glucose, "glucose stayed in range after evening rides"),
            nudge("Recovery · HRV", .general, "your HRV dipped on high-load days"),
            nudge("Activity", .general, "fewer steps on rainy days"),
        ]
        let qs = ChatSuggestions.contextual(from: nudges)
        #expect(!qs.isEmpty)
        for q in qs {
            let answer = engine().respond(to: q)
            #expect(answer != LiviqaChatCopy.safetyLine, "offered question got refused: \(q)")
        }
    }

    @Test func cardiacNudgesProduceNoQuestions() {
        // Route-to-clinician nudges must never invite interpretive follow-ups.
        let qs = ChatSuggestions.contextual(from: [
            nudge("Irregular heart-rhythm signal", .cardiac, "your device recorded an irregular rhythm")
        ])
        // Falls back to the safe defaults (not cardiac-specific questions).
        #expect(qs == ChatSuggestions.defaults)
    }

    @Test func defaultsWhenNoNudges() {
        #expect(ChatSuggestions.contextual(from: []) == ChatSuggestions.defaults)
        for q in ChatSuggestions.defaults {
            #expect(engine().respond(to: q) != LiviqaChatCopy.safetyLine)
        }
    }
}
