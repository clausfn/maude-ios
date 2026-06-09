// LiviqaChat.swift — Wellness-scope AI assistant: copy, deterministic guard,
// descriptive responder, and engine. v01 2026-06-09.
//
// COMPLIANCE CORE. The chat DESCRIBES and SUMMARISES the user's own data. It must
// never interpret disease, predict, give prognosis, triage, diagnose, or advise on
// treatment (MDR intended-purpose line — crossing it makes Liviqa a Class IIa device).
// The guard is DETERMINISTIC and sits between any model and the UI — it does not
// trust prompt instructions, because models drift. See
// 06_Regulatory/Liviqa_CounselMemo_AIChat_WellnessScope_v01_20260609.docx.
import Foundation

// MARK: - Fixed copy (identical everywhere: system prompt, consent, UI, store copy)

enum LiviqaChatCopy {
    /// The single intended-purpose statement. Reuse verbatim — never reword.
    static let intendedPurpose =
        "Liviqa's assistant helps you explore and understand your own tracked data. " +
        "It is not a medical device and does not give medical advice."

    /// The ONLY routing-to-care text allowed. Fixed; never triggered dynamically by
    /// what the data shows (a dynamic "your data warrants a doctor" is itself triage).
    static let safetyLine =
        "I can only describe your own tracked data — I can't give medical advice or " +
        "interpret symptoms. For anything about your health or symptoms, please talk " +
        "to your clinician."

    /// Persistent AI disclosure (EU AI Act Art. 50).
    static let aiLabel = "AI assistant · describes your own data"

    /// System prompt seed for any model (the guard is still required on top).
    static let systemPrompt = """
    You are Liviqa's assistant. You help the user explore and understand THEIR OWN
    tracked data (glucose, heart rate, sleep, activity). You are not a medical device
    and you do not give medical advice.
    You MAY: report the user's own numbers, trends, averages, and changes over time;
    describe correlations within the user's data when they ask ("in your data, X tends
    to coincide with Y"); give general, non-personalised health education clearly
    framed as general information.
    You MUST NOT, under any circumstances: predict, estimate, or score disease risk;
    give a prognosis or say a condition is progressing/improving; interpret symptoms,
    diagnose, or suggest what a symptom means; recommend treatment, medication, doses,
    or changes to medication; tell the user to seek medical care based on their data.
    If a request needs any of the above, respond only with the safety line.
    Describe; do not advise. Stay strictly within the user's own data.
    """
}

// MARK: - Deterministic guard

/// Pure, testable. Two layers of defence:
///  1. `screenInput`  — refuse out-of-scope *requests* before any model runs.
///  2. `sanitizeOutput` — block/rewrite *responses* that drift across the line.
enum ChatGuard {

    /// Intent patterns that are out of the wellness scope (prediction / prognosis /
    /// diagnosis / symptom-interpretation / triage / treatment). Lowercased regex.
    private static let blockedIntent: [String] = [
        #"\brisk\b"#,                                             // "...heart attack risk"
        #"\b(getting|develop(ing|ment)?|progress(ing|ion)?|prognos|deteriorat)"#,
        #"\b(will i|am i (going|likely|at risk)|going to i)"#,
        #"\b(diagnos|do i have|have i got|could (this|it|that) be|is (this|that|it) (a |my |an )?\w+)"#,
        #"\bsymptom"#,
        #"\b(chest|flutter|palpitation|dizzy|faint|numb|short(ness)? of breath|pain)\b"#,
        #"\b(hypo|hyper)\b"#,
        #"\b(afib|a-fib|arrhythmia|heart attack|cardiac|stroke|seizure)\b"#,
        #"\b(insulin|dose|dosing|medication|medicine|meds?|treat(ment)?|therapy)\b"#,
        #"\bshould i\b"#,
        #"\b(see|call|visit|go to)\b.{0,16}\b(doctor|gp|clinician|nurse|hospital|er|a&e|emergency)\b"#,
        #"\b(is it (normal|serious|dangerous|bad)|am i (ok|okay|fine|unwell|sick|ill))\b"#,
    ]

    /// Phrases in a *response* that are imperatives/advice → stripped if the rest is
    /// otherwise descriptive. (Belt-and-braces; most advice trips `blockedIntent`.)
    private static let imperativeLead: [String] = [
        #"(?im)^\s*(so )?you should\b.*$"#,
        #"(?im)^\s*(i (would )?recommend|consider|try to|make sure( to)?|be sure to|you (could|might want to)|i suggest)\b.*$"#,
    ]

    /// Sexual-function medications — stripped silently from any rendered text
    /// (existing cardinal rule; dignity + relevance).
    private static let strippedMeds: [String] =
        ["sildenafil", "viagra", "tadalafil", "cialis", "vardenafil", "levitra", "avanafil", "stendra"]

    private static func matches(_ text: String, _ patterns: [String]) -> Bool {
        let t = text.lowercased()
        for p in patterns where t.range(of: p, options: .regularExpression) != nil { return true }
        return false
    }

    /// True when the *user request* is outside the wellness scope and must be refused.
    static func inputIsOutOfScope(_ prompt: String) -> Bool {
        matches(prompt, blockedIntent)
    }

    /// Final gate on a candidate *response*. Returns the text to show the user:
    /// the safety line if anything crosses the line, otherwise the cleaned text.
    static func sanitizeOutput(_ response: String) -> String {
        // Hard block: any out-of-scope content → safety line, nothing else.
        if matches(response, blockedIntent) { return LiviqaChatCopy.safetyLine }

        var out = response
        // Strip advice/imperative lines.
        for p in imperativeLead {
            out = out.replacingOccurrences(of: p, with: "", options: .regularExpression)
        }
        // Strip sexual-function meds (whole word, case-insensitive).
        for med in strippedMeds {
            out = out.replacingOccurrences(
                of: #"(?i)\b"# + NSRegularExpression.escapedPattern(for: med) + #"\b"#,
                with: "", options: .regularExpression)
        }
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? LiviqaChatCopy.safetyLine : out
    }
}

// MARK: - Health summary (the only data the responder may describe)

/// A small, already-derived snapshot of the user's OWN data. All optional — the
/// responder only states what's present. (Built on-device from AppState/HealthKit.)
struct ChatHealthSummary {
    var avgGlucoseMmol7d: Double?
    var glucoseTIRpct7d: Int?
    var sleepAvgHours7d: Double?
    var restingHRavg7d: Int?
    var stepsAvg7d: Int?

    static let empty = ChatHealthSummary()

    /// Demo summary — mirrors the synthetic values the rest of the app shows
    /// (TIR 68%, sleep 7h02, RHR 58, ~5.6k steps). Replace with an on-device
    /// builder from AppState/HealthKit when wiring real data.
    static let demo = ChatHealthSummary(
        avgGlucoseMmol7d: 6.7, glucoseTIRpct7d: 68,
        sleepAvgHours7d: 7.03, restingHRavg7d: 58, stepsAvg7d: 5600)

    /// The ONLY data handed to a cloud model: the user's own summarised numbers.
    /// (Never raw samples; never anything that isn't the user's own metric.)
    func promptContext() -> String {
        var lines: [String] = []
        if let g = avgGlucoseMmol7d { lines.append(String(format: "- 7-day average glucose: %.1f mmol/L", g)) }
        if let t = glucoseTIRpct7d  { lines.append("- 7-day glucose time-in-range: \(t)%") }
        if let s = sleepAvgHours7d  { lines.append(String(format: "- 7-day average sleep: %.2f hours", s)) }
        if let r = restingHRavg7d   { lines.append("- 7-day average resting heart rate: \(r) bpm") }
        if let st = stepsAvg7d      { lines.append("- 7-day average steps: \(st) per day") }
        return lines.isEmpty ? "(no tracked data available)" : lines.joined(separator: "\n")
    }
}

// MARK: - Descriptive responder

/// Produces a *candidate* descriptive answer from the summary. It never advises;
/// the guard still sanitises its output. A deterministic responder is compliant by
/// construction — it literally cannot diagnose. (A real on-device LLM can later
/// implement this protocol; the guard stays in front of it unchanged.)
protocol ChatResponder {
    func candidate(for prompt: String, summary: ChatHealthSummary) -> String
}

struct LocalDataResponder: ChatResponder {
    func candidate(for prompt: String, summary s: ChatHealthSummary) -> String {
        let q = prompt.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { q.contains($0) } }

        if has(["glucose", "sugar", "cgm"]) {
            if has(["range", "tir", "in range"]), let t = s.glucoseTIRpct7d {
                return "In your data, you spent about \(t)% of the last 7 days in your target glucose range."
            }
            if let g = s.avgGlucoseMmol7d {
                return String(format: "Your average glucose over the last 7 days was %.1f mmol/L.", g)
            }
        }
        if has(["sleep", "slept", "asleep"]), let h = s.sleepAvgHours7d {
            let hrs = Int(h); let mins = Int((h - Double(hrs)) * 60)
            return "Your average sleep over the last 7 days was \(hrs)h \(String(format: "%02d", mins))m."
        }
        if has(["resting", "heart rate", "hr", "pulse", "bpm"]), let r = s.restingHRavg7d {
            return "Your average resting heart rate over the last 7 days was \(r) bpm."
        }
        if has(["step", "active", "activity", "move", "walk"]), let st = s.stepsAvg7d {
            return "You averaged about \(st.formatted()) steps a day over the last 7 days."
        }
        // No descriptive match → offer what CAN be described (never advise / interpret).
        return "I can describe your own tracked data — for example your glucose, sleep, "
            + "resting heart rate, or activity averages and trends. What would you like to see?"
    }
}

// MARK: - Engine (orchestrates request → guard → responder → guard)

struct ChatEngine {
    var responder: ChatResponder = LocalDataResponder()
    var summary: ChatHealthSummary = .empty

    /// On-device deterministic path (default). Guard-first, guard-last.
    func respond(to prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return LiviqaChatCopy.safetyLine }
        // 1. Refuse out-of-scope requests before any generation.
        if ChatGuard.inputIsOutOfScope(trimmed) { return LiviqaChatCopy.safetyLine }
        // 2. Generate a descriptive candidate, then 3. sanitise it.
        let candidate = responder.candidate(for: trimmed, summary: summary)
        return ChatGuard.sanitizeOutput(candidate)
    }

    /// Enhanced (cloud) path — only when the user opted into cloud consent. The guard
    /// runs BEFORE (no out-of-scope request ever reaches Mistral) and AFTER (any drift
    /// in the model's answer is blocked → safety line). Falls back to the on-device
    /// deterministic answer if the network/model fails.
    func respondCloud(to prompt: String) async -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return LiviqaChatCopy.safetyLine }
        if ChatGuard.inputIsOutOfScope(trimmed) { return LiviqaChatCopy.safetyLine }
        guard MistralClient.hasKey else { return respond(to: trimmed) }
        let userMessage = """
        The user's own tracked data (the ONLY data you may describe):
        \(summary.promptContext())

        The user asks: \(trimmed)
        """
        do {
            let candidate = try await MistralClient.complete(
                system: LiviqaChatCopy.systemPrompt, user: userMessage)
            return ChatGuard.sanitizeOutput(candidate)
        } catch {
            return ChatGuard.sanitizeOutput(responder.candidate(for: trimmed, summary: summary))
        }
    }
}

// MARK: - Message model (UI)

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var isSafetyLine: Bool { role == .assistant && text == LiviqaChatCopy.safetyLine }
}
