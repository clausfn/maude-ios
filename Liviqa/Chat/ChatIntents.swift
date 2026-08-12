// ChatIntents.swift — A7.2 Area ⑨: intent routing + post-answer follow-ups for
// the wellness-scope assistant (b-learn.jsx AIExplain / AITranslate /
// AICalibration / AIRedirect, implemented as BEHAVIOUR — template routing in the
// deterministic responder — never canned chat history).
//
// COMPLIANCE: intents only select which DESCRIPTIVE template answers and which
// presentation (spark chart, calibration bar, action chips) accompanies it.
// ChatGuard still runs first (input refusal) and last (output sanitise) on every
// path — classification can never bypass it. Every ask-chip below is authored to
// pass the guard (pinned by ChatBehaviourTests; the ChatSuggestions discipline).
import Foundation

/// What kind of answer a prompt routes to. `.safety` is set by the ENGINE when
/// the guard refused — never by the classifier.
nonisolated enum ChatIntent: Sendable, Equatable {
    case explainHRVDrop      // AIExplain — the person's own week, own baseline
    case hrvHistory          // follow-up: own range/median over the window
    case hrvBetterDays       // follow-up: descriptive, evidence-gate honest
    case plainGlucose        // AITranslate — plain-language on request
    case glucoseRange        // follow-up: the band the user's own charts use
    case mealRise            // follow-up: general education, own day if derivable
    case calibration         // AICalibration — honest sparse-data answer
    case whatLearning        // follow-up: what the baselines are learning
    case speedUp             // follow-up: descriptive (more own days), no advice
    case safety              // guard refused → fixed safety line + care chips
    case generic             // everything else (existing descriptive templates)
}

nonisolated enum ChatIntentClassifier {

    /// Pure, deterministic prompt → intent. Checked AFTER the input guard, so a
    /// blocked prompt never reaches this. Order matters: specific before broad.
    static func classify(_ prompt: String, summary: ChatHealthSummary) -> ChatIntent {
        let q = prompt.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { q.contains($0) } }

        // Calibration — by wording, or (below, after its own follow-ups) because
        // there is simply no data to describe.
        if has(["look empty", "looks empty", "no data", "nothing here", "numbers empty",
                "where is my data", "where's my data", "why is there nothing", "still empty"]) {
            return .calibration
        }
        // The calibration follow-up chips must answer even with zero data, so
        // they are classified BEFORE the no-data fallback.
        if has(["what are you learning", "what is liviqa learning", "what are you watching"]) {
            return .whatLearning
        }
        if has(["speed it up", "speed this up", "go faster", "make it faster", "speed up"]) {
            return .speedUp
        }
        if !summary.hasAnyData { return .calibration }

        let hrv = has(["hrv", "variability"])
        if hrv && has(["dipped like this before", "happened before", "dropped before"]) {
            return .hrvHistory
        }
        if hrv && has(["lines up with", "line up with", "better hrv days", "higher hrv days"]) {
            return .hrvBetterDays
        }
        if hrv && has(["drop", "dip", "fell", "low", "down", "why"]) {
            return .explainHRVDrop
        }

        let glucose = has(["glucose", "sugar", "cgm"])
        if has(["good range", "target range", "what's a good", "whats a good"]) {
            return .glucoseRange
        }
        if has(["rise after", "rises after", "spike after", "go up after"])
            && (glucose || has(["meal", "meals", "lunch", "dinner", "eating", "eat", "it "])) {
            return .mealRise
        }
        if glucose && has(["explain", "new to this", "plain", "simple", "simply",
                           "beginner", "understand"]) {
            return .plainGlucose
        }

        return .generic
    }
}

// MARK: - Post-answer follow-ups (designed chips; suggestion presentation only)

/// One chip under an assistant answer. `ask` chips send a pre-vetted question;
/// action chips open existing consent-first surfaces (share / plan a consult /
/// the Learn tier) — they never generate text.
nonisolated struct ChatFollowUp: Identifiable, Equatable {
    nonisolated enum Kind: Equatable {
        case ask(String)      // sends this question (must pass the guard)
        case openLearnHRV     // opens the HRV knowledge screen (clinical tier)
        case shareSummary     // opens ShareWithClinicianView (summaries-only)
        case planConsult      // opens PlanConsultView
    }
    let id = UUID()
    let label: String
    let kind: Kind

    static func == (a: ChatFollowUp, b: ChatFollowUp) -> Bool {
        a.label == b.label && a.kind == b.kind
    }
}

nonisolated enum ChatFollowUps {

    /// The designed chips per intent. Canvas prompts are re-authored where the
    /// original would trip the guard or invite advice:
    ///  · "Is this a pattern?"  → "Has my HRV dipped like this before?"
    ///    (the original matches the guard's is-this-a-… diagnosis pattern)
    ///  · "What helps HRV?"     → "What lines up with my better HRV days?"
    ///    (advice-adjacent → descriptive, evidence-gate honest)
    static func followUps(for intent: ChatIntent) -> [ChatFollowUp] {
        switch intent {
        case .explainHRVDrop:
            return [ChatFollowUp(label: String(localized: "Has my HRV dipped like this before?"),
                                 kind: .ask("Has my HRV dipped like this before?")),
                    ChatFollowUp(label: String(localized: "Show me the numbers"),
                                 kind: .openLearnHRV),
                    ChatFollowUp(label: String(localized: "What lines up with my better HRV days?"),
                                 kind: .ask("What lines up with my better HRV days?"))]
        case .hrvHistory, .hrvBetterDays:
            return [ChatFollowUp(label: String(localized: "Show me the numbers"),
                                 kind: .openLearnHRV)]
        case .plainGlucose:
            return [ChatFollowUp(label: String(localized: "What's a good range?"),
                                 kind: .ask("What's a good range?")),
                    ChatFollowUp(label: String(localized: "Why does it rise after meals?"),
                                 kind: .ask("Why does it rise after meals?"))]
        case .calibration:
            return [ChatFollowUp(label: String(localized: "What are you learning?"),
                                 kind: .ask("What are you learning?")),
                    ChatFollowUp(label: String(localized: "Can I speed it up?"),
                                 kind: .ask("Can I speed it up?"))]
        case .safety:
            // Designed redirect presentation: the two chips route to EXISTING
            // consent-first flows (summaries-only share / plan a consult). They
            // are additive UI around the unchanged designated safety line.
            return [ChatFollowUp(label: String(localized: "Make a summary to share"),
                                 kind: .shareSummary),
                    ChatFollowUp(label: String(localized: "Plan a consultation"),
                                 kind: .planConsult)]
        case .glucoseRange, .mealRise, .whatLearning, .speedUp, .generic:
            return []
        }
    }
}
