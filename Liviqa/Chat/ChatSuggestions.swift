// ChatSuggestions.swift — contextual, pre-vetted questions for the assistant.
// The nudge engine discovers a pattern in the user's data; the assistant offers
// DESCRIPTIVE follow-ups about that same pattern. Every suggestion is authored to
// stay in scope (it asks the assistant to describe the user's own numbers — never to
// interpret, predict, or advise) so it always passes the guard. v01 2026-06-09.
import Foundation

enum ChatSuggestions {

    // Topic question sets — descriptive only.
    private static let sleep    = ["What was my average sleep this week?",
                                   "Which nights did I sleep the least?"]
    private static let glucose  = ["How much of my week was glucose in range?",
                                   "What was my average glucose this week?"]
    private static let hrv      = ["What was my average HRV this week?"]
    private static let activity = ["How many steps did I average this week?"]

    /// Shown when there are no nudges to key off.
    static let defaults = ["What was my average glucose last week?",
                           "How much did I sleep on average?",
                           "How much of my week was glucose in range?"]

    /// Build follow-up questions from the user's current nudges. Cardiac / heart-rhythm
    /// nudges are route-to-clinician — they get NO questions (never invite interpretation).
    static func contextual(from nudges: [Nudge], cap: Int = 4) -> [String] {
        var out: [String] = []
        for n in nudges {
            if n.accent == .cardiac { continue }
            let t = (n.tag + " " + n.body).lowercased()
            if t.contains("rhythm") || t.contains("afib") || t.contains("cardiac") { continue }
            if t.contains("sleep")    { out += sleep }
            if t.contains("glucose") || t.contains("cgm") { out += glucose }
            if t.contains("hrv") || t.contains("recovery") || t.contains("variability") { out += hrv }
            if t.contains("step") || t.contains("activity") { out += activity }
        }
        var seen = Set<String>(); var uniq: [String] = []
        for q in out where !seen.contains(q) { seen.insert(q); uniq.append(q) }
        return Array((uniq.isEmpty ? defaults : uniq).prefix(cap))
    }
}
