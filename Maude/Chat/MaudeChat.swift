// MaudeChat.swift — Wellness-scope AI assistant: copy, deterministic guard,
// descriptive responder, and engine. v01 2026-06-09 · v02 2026-08-12 (A7.2
// Area ⑨: intent-routed templates for explain / plain-language / calibration;
// literacy-aware voice; honest answer-origin tracking; guard STRENGTHENED with
// titration/basal/bolus patterns — never weakened).
//
// COMPLIANCE CORE. The chat DESCRIBES and SUMMARISES the user's own data. It must
// never interpret disease, predict, give prognosis, triage, diagnose, or advise on
// treatment (MDR intended-purpose line — crossing it makes Maude a Class IIa device).
// The guard is DETERMINISTIC and sits between any model and the UI — it does not
// trust prompt instructions, because models drift. See
// 06_Regulatory/Maude_CounselMemo_AIChat_WellnessScope_v01_20260609.docx.
//
// DESIGNATED CONTROL (open ruling, DHF 2026-08-12): `safetyLine` is a FIXED
// string — a counsel memo is required before ANY copy change. The A7.2 canvas
// (b-learn.jsx AIRedirect) shows warmer, dose-specific wording; that divergence
// is NOTED for the memo and NOT adopted here. Only the PRESENTATION around the
// unchanged line (action chips to existing consent-first flows) shipped.
import Foundation

// MARK: - Fixed copy (identical everywhere: system prompt, consent, UI, store copy)

enum MaudeChatCopy {
    /// The single intended-purpose statement. Reuse verbatim — never reword.
    static let intendedPurpose =
        "Maude's assistant helps you explore and understand your own tracked data. " +
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
    You are Maude's assistant. You help the user explore and understand THEIR OWN
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
        // A7.2 Area ⑨ strengthening: dose-adjustment vocabulary that previously
        // slipped past the guard ("time to titrate my basal?"). Additive only —
        // the redirect behaviour may only get STRONGER.
        #"\b(titrat(e|es|ed|ing|ion)?|basal|bolus|prescri(be|bed|ption))\b"#,
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
        if matches(response, blockedIntent) { return MaudeChatCopy.safetyLine }

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
        return out.isEmpty ? MaudeChatCopy.safetyLine : out
    }
}

// MARK: - Literacy preference (FR-LIT-01 — first consumer)

/// The health-literacy preference captured by the onboarding LiteracyStep
/// (@AppStorage("literacyLevel"): "plain" | "both" | "clinical", default "both").
/// The responder uses it to pick the VOICE of an answer — never to hide data
/// ("Maude never hides your real data": the numbers stay one question away).
enum LiteracyLevel: String, Sendable, Equatable {
    case plain, both, clinical
    init(storage: String) { self = LiteracyLevel(rawValue: storage) ?? .both }
}

// MARK: - Health summary (the only data the responder may describe)

/// Today's post-meal rise facts, lifted from the REAL DayReplay derivation
/// (timestamped glucose curve). nil ⇒ the clause never renders — the assistant
/// must not guess at meals it cannot see.
struct TodayGlucoseRise: Equatable {
    /// Time of today's highest above-band reading ("13:40").
    var peakTimeText: String
    /// First back-in-band time after the last above-band run ("15:10"), if it
    /// has come back.
    var backByTimeText: String?
}

/// A small, already-derived snapshot of the user's OWN data. All optional — the
/// responder only states what's present. (Built on-device from AppState/HealthKit.)
struct ChatHealthSummary {
    var avgGlucoseMmol7d: Double?
    var glucoseTIRpct7d: Int?
    var sleepAvgHours7d: Double?
    var restingHRavg7d: Int?
    var hrvAvgMs7d: Int?
    var stepsAvg7d: Int?

    // A7.2 Area ⑨ — deeper derived facts for the designed example behaviours.
    // All real-deriver-fed and optional; the templates degrade honestly to the
    // shallower fields above when these are absent.
    /// Up-to-60-day HRV aggregation (HRVLearnDeriver) — explain-a-drop + Learn tier.
    var hrvDetail: HRVLearnDetail?
    /// Distinct days of the user's own tracked data (PassportStats.daysTracked).
    var daysOfData: Int?
    /// 30-day glucose TIR (TrendsSummary.month) — honest "vs your own month" clause.
    var tirMonthPct: Int?
    /// The band the user's own charts read glucose against (mmol/L, OD-07).
    var glucoseBandLo: Double?
    var glucoseBandHi: Double?
    /// Today's post-meal rise, only when the DayReplay deriver produced one.
    var todayRise: TodayGlucoseRise?
    /// Cross-signal observations that passed the Trends evidence gate (titles only).
    var gatedCorrelationTitles: [String] = []
    /// Literacy preference — voice selection only, never data hiding.
    var literacy: LiteracyLevel = .both

    /// At least one of the user's own numbers is present to describe.
    var hasAnyData: Bool {
        avgGlucoseMmol7d != nil || glucoseTIRpct7d != nil || sleepAvgHours7d != nil
            || restingHRavg7d != nil || hrvAvgMs7d != nil || stepsAvg7d != nil
    }

    static let empty = ChatHealthSummary()

    /// Demo summary — mirrors the synthetic values the rest of the app shows
    /// (TIR 68%, sleep 7h02, RHR 58, ~5.6k steps). Replace with an on-device
    /// builder from AppState/HealthKit when wiring real data.
    static let demo = ChatHealthSummary(
        avgGlucoseMmol7d: 6.7, glucoseTIRpct7d: 68,
        sleepAvgHours7d: 7.03, restingHRavg7d: 58, hrvAvgMs7d: 42, stepsAvg7d: 5600)

    /// The ONLY data handed to a cloud model: the user's own summarised numbers.
    /// (Never raw samples; never anything that isn't the user's own metric.)
    func promptContext() -> String {
        var lines: [String] = []
        if let g = avgGlucoseMmol7d { lines.append(String(format: "- 7-day average glucose: %.1f mmol/L", g)) }
        if let t = glucoseTIRpct7d  { lines.append("- 7-day glucose time-in-range: \(t)%") }
        if let s = sleepAvgHours7d  { lines.append(String(format: "- 7-day average sleep: %.2f hours", s)) }
        if let r = restingHRavg7d   { lines.append("- 7-day average resting heart rate: \(r) bpm") }
        if let v = hrvAvgMs7d       { lines.append("- 7-day average HRV: \(v) ms") }
        if let st = stepsAvg7d      { lines.append("- 7-day average steps: \(st) per day") }
        // Area ⑨ facts — still ONLY the user's own derived numbers, never raw samples.
        if let d = hrvDetail {
            lines.append("- HRV over the last \(d.windowDays) days: median \(d.medianMs) ms, range \(d.rangeLoMs)–\(d.rangeHiMs) ms")
        }
        if let m = tirMonthPct { lines.append("- 30-day glucose time-in-range: \(m)%") }
        if let n = daysOfData  { lines.append("- days of tracked data so far: \(n)") }
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
        // A7.2 Area ⑨: intent routing first — the four designed behaviours are
        // fixed descriptive templates filled with the user's OWN derived figures.
        // (The guard has already refused out-of-scope inputs; sanitizeOutput
        // still runs on whatever this returns.)
        switch ChatIntentClassifier.classify(prompt, summary: s) {
        case .explainHRVDrop: return Self.explainHRVDrop(s)
        case .hrvHistory:     return Self.hrvHistory(s)
        case .hrvBetterDays:  return Self.hrvBetterDays(s)
        case .plainGlucose:   return Self.plainGlucose(s)
        case .glucoseRange:   return Self.glucoseRange(s)
        case .mealRise:       return Self.mealRise(s)
        case .calibration:    return Self.calibration(s)
        case .whatLearning:   return Self.whatLearning(s)
        case .speedUp:        return Self.speedUp(s)
        case .safety, .generic: break
        }

        let q = prompt.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { q.contains($0) } }

        if has(["glucose", "sugar", "cgm"]) {
            if has(["range", "tir", "in range"]), let t = s.glucoseTIRpct7d {
                // FR-LIT-01: plain literacy keeps the same number in plain voice.
                return s.literacy == .plain
                    ? "You were in your comfortable middle band about \(t)% of the last 7 days."
                    : "In your data, you spent about \(t)% of the last 7 days in your target glucose range."
            }
            if let g = s.avgGlucoseMmol7d {
                return String(format: "Your average glucose over the last 7 days was %.1f mmol/L.", g)
            }
        }
        if has(["sleep", "slept", "asleep"]), let h = s.sleepAvgHours7d {
            let hrs = Int(h); let mins = Int((h - Double(hrs)) * 60)
            return "Your average sleep over the last 7 days was \(hrs)h \(String(format: "%02d", mins))m."
        }
        if has(["hrv", "variability", "recovery"]), let v = s.hrvAvgMs7d {
            return "Your average HRV over the last 7 days was \(v) ms."
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

    // MARK: Area ⑨ fixed templates (descriptive only; own-figures only)

    /// AIExplain — a drop explained against the person's own week and baseline.
    /// No life context ("meetings", "dinner") is ever asserted: the responder
    /// only knows the numbers.
    private static func explainHRVDrop(_ s: ChatHealthSummary) -> String {
        let definition = "HRV is the small variation in time between your heartbeats — "
            + "more variation usually means you're well-rested."
        if let d = s.hrvDetail {
            if let low = d.weekLowMs, let day = d.weekLowDayName, d.dippedBelowUsual {
                let drop = " Yours was lowest on \(day) at \(low) ms, against your usual "
                    + "~\(d.medianMs) ms (your \(d.windowDays)-day median)."
                let tail = d.recoveredToUsual
                    ? " Your latest reading, \(d.latestMs) ms, is back in your usual range."
                    : " Your latest reading, \(d.latestMs) ms, hasn't come back to your usual yet — Maude keeps comparing it against your own days."
                return definition + drop + tail
            }
            if let lo = d.weekSeries.min(), let hi = d.weekSeries.max(), d.weekSeries.count >= 2 {
                return definition + " This week yours stayed close to your own usual — "
                    + "between \(Int(lo.rounded())) and \(Int(hi.rounded())) ms, "
                    + "around your \(d.windowDays)-day median of \(d.medianMs) ms."
            }
            return definition + " Your latest reading is \(d.latestMs) ms, around your "
                + "\(d.windowDays)-day median of \(d.medianMs) ms."
        }
        if let v = s.hrvAvgMs7d {
            return definition + " Your 7-day average is \(v) ms. Maude doesn't have enough of "
                + "your own days yet to say what's usual for you, so it can't call this a drop or a rebound."
        }
        return definition + " There aren't enough of your own readings yet for Maude to "
            + "compare a change against your usual."
    }

    /// Follow-up: the person's own longer window, honestly labelled.
    private static func hrvHistory(_ s: ChatHealthSummary) -> String {
        guard let d = s.hrvDetail else {
            return "Maude doesn't have enough of your own days yet to show a longer history — "
                + "it compares you only with yourself, so that picture builds as your days come in."
        }
        return "Across your last \(d.windowDays) days, your HRV has ranged "
            + "\(d.rangeLoMs)–\(d.rangeHiMs) ms around a median of \(d.medianMs) ms. "
            + "Dips and rebounds inside that spread are part of your own normal."
    }

    /// Follow-up (re-authored from the canvas's advice-adjacent "What helps HRV?"):
    /// descriptive, evidence-gate honest — never a cause claim, never a tip.
    private static func hrvBetterDays(_ s: ChatHealthSummary) -> String {
        var lead = "Maude doesn't guess at causes."
        if let d = s.hrvDetail, let hi = d.weekSeries.max() {
            lead = "Your highest HRV this week was \(Int(hi.rounded())) ms. " + lead
        }
        if s.gatedCorrelationTitles.isEmpty {
            return lead + " When a link in your own data passes the evidence gate, "
                + "it appears on your Trends screen — nothing involving HRV has passed it yet."
        }
        return lead + " In your own data, these links have passed the evidence gate so far: "
            + s.gatedCorrelationTitles.joined(separator: " · ")
            + ". You can see them on your Trends screen."
    }

    /// AITranslate — plain-language glucose on request. The "vs your own weeks"
    /// clause is COMPUTED against the user's own month (or dropped); the
    /// post-meal clause renders only from the real timestamped day curve.
    private static func plainGlucose(_ s: ChatHealthSummary) -> String {
        guard let t = s.glucoseTIRpct7d else {
            return "Think of glucose as the fuel in your blood. You want it to stay in a "
                + "comfortable middle band most of the day. Maude doesn't have glucose "
                + "readings from you yet, so there's nothing of your own to translate — "
                + "once readings arrive, this answer fills in with your own week."
        }
        var text = "Think of glucose as the fuel in your blood. You want it to stay in a "
            + "comfortable middle band most of the day. This week you were in that band "
            + "\(t)% of the time"
        if let m = s.tirMonthPct {
            if t >= m + 3      { text += " — a little above your own month's average." }
            else if t <= m - 3 { text += " — a little below your own month's average." }
            else               { text += " — right around your own month's average." }
        } else {
            text += "."
        }
        if let rise = s.todayRise {
            text += rise.backByTimeText.map {
                " Today's highest reading came at \(rise.peakTimeText), and it was back "
                + "in your band by \($0) on its own."
            } ?? " Today's highest reading came at \(rise.peakTimeText) — a rise after eating is expected."
        }
        return text
    }

    /// Follow-up: the band the user's OWN charts read against — never framed as
    /// a target set for them personally. mmol/L canonical (OD-07).
    private static func glucoseRange(_ s: ChatHealthSummary) -> String {
        let lo = s.glucoseBandLo ?? 3.9, hi = s.glucoseBandHi ?? 10.0
        func f(_ v: Double) -> String {
            v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
        }
        return "Maude reads your days against the band \(f(lo))–\(f(hi)) mmol/L — the same "
            + "band your time-in-range charts use. It compares you only with your own days; "
            + "your care team may read your numbers against a band chosen for you."
    }

    /// Follow-up: general education, clearly framed as general; the personal
    /// clause renders only from the real day curve.
    private static func mealRise(_ s: ChatHealthSummary) -> String {
        var text = "In general — not specific to you — a rise after eating is expected: "
            + "carbohydrate from food reaches the blood as glucose, and the level settles "
            + "again as your body takes it up."
        if let rise = s.todayRise {
            text += rise.backByTimeText.map {
                " In your own data today, the highest reading came at \(rise.peakTimeText) "
                + "and was back in your band by \($0)."
            } ?? " In your own data today, the highest reading came at \(rise.peakTimeText)."
        }
        return text
    }

    /// AICalibration — the honest sparse-data answer. Reconciled with Home's
    /// deliberate no-fake-day-counter stance: a real day count is stated when
    /// one exists; NO "day 1 of ~14" style progress is ever fabricated. The
    /// "about 3 days" expectation matches TodayView's baselineBuildingCard.
    private static func calibration(_ s: ChatHealthSummary) -> String {
        let days = s.daysOfData ?? 0
        let lead: String
        if days >= 1 {
            lead = days == 1
                ? "Maude has 1 day of your own readings so far."
                : "Maude has \(days) days of your own readings so far."
        } else {
            lead = "Your readings are only starting to come in."
        }
        var text = lead + " It's still learning your normal, so it's watching more than "
            + "talking right now. Once it has enough of your own days to compare against, "
            + "your daily edition fills in — and every insight will be measured against "
            + "you, not averages."
        if days < 3 {
            text += " The first ones typically appear after about 3 days."
        }
        return text
    }

    /// Follow-up: what the baselines are learning — descriptive.
    private static func whatLearning(_ s: ChatHealthSummary) -> String {
        "From your own days, Maude is learning what's usual for you — your typical sleep "
            + "length, your overnight heart-rate variability, your resting heart rate, and "
            + "how much of the day your glucose spends in your band. Each new day of your "
            + "own readings sharpens that picture."
    }

    /// Follow-up: authored descriptively (how the system works), never as advice.
    private static func speedUp(_ s: ChatHealthSummary) -> String {
        "More of your own days is the only ingredient. Nights with your watch worn and days "
            + "with your devices along give Maude more of you to compare against — the "
            + "baseline builds by itself from there."
    }
}

// MARK: - Engine (orchestrates request → guard → responder → guard)

/// One assistant answer + honest metadata for the presentation layer.
nonisolated struct ChatReply: Equatable {
    /// Where the shown text was generated. `.onDevice` includes guard refusals
    /// on the cloud path (the prompt never left the phone) and cloud fallbacks.
    /// The "Answered on this iPhone" proof line may ONLY render for `.onDevice`.
    nonisolated enum Origin: Equatable { case onDevice, cloud }
    let text: String
    let origin: Origin
    /// Which behaviour answered — presentation only (spark chart, calibration
    /// bar, follow-up chips). `.safety` ⇔ the fixed safety line.
    let intent: ChatIntent
}

struct ChatEngine {
    var responder: ChatResponder = LocalDataResponder()
    var summary: ChatHealthSummary = .empty

    /// On-device deterministic path (default). Guard-first, guard-last.
    func respond(to prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MaudeChatCopy.safetyLine }
        // 1. Refuse out-of-scope requests before any generation.
        if ChatGuard.inputIsOutOfScope(trimmed) { return MaudeChatCopy.safetyLine }
        // 2. Generate a descriptive candidate, then 3. sanitise it.
        let candidate = responder.candidate(for: trimmed, summary: summary)
        return ChatGuard.sanitizeOutput(candidate)
    }

    /// On-device answer + presentation metadata. Same guard path as `respond`.
    func reply(to prompt: String) -> ChatReply {
        let text = respond(to: prompt)
        let intent: ChatIntent = text == MaudeChatCopy.safetyLine
            ? .safety
            : ChatIntentClassifier.classify(prompt, summary: summary)
        return ChatReply(text: text, origin: .onDevice, intent: intent)
    }

    /// Enhanced (cloud) path — only when the user opted into cloud consent. The guard
    /// runs BEFORE (no out-of-scope request ever reaches Mistral) and AFTER (any drift
    /// in the model's answer is blocked → safety line). Falls back to the on-device
    /// deterministic answer if the network/model fails. `origin` is honest: `.cloud`
    /// only when Mistral's (sanitised) answer is actually shown.
    func replyCloud(to prompt: String) async -> ChatReply {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ChatReply(text: MaudeChatCopy.safetyLine, origin: .onDevice, intent: .safety)
        }
        // Guard refusal happens BEFORE any network call — nothing left the phone.
        if ChatGuard.inputIsOutOfScope(trimmed) {
            return ChatReply(text: MaudeChatCopy.safetyLine, origin: .onDevice, intent: .safety)
        }
        guard MistralClient.hasKey else { return reply(to: trimmed) }
        let userMessage = """
        The user's own tracked data (the ONLY data you may describe):
        \(summary.promptContext())

        The user asks: \(trimmed)
        """
        do {
            let candidate = try await MistralClient.complete(
                system: MaudeChatCopy.systemPrompt, user: userMessage)
            let text = ChatGuard.sanitizeOutput(candidate)
            let intent: ChatIntent = text == MaudeChatCopy.safetyLine
                ? .safety
                : ChatIntentClassifier.classify(trimmed, summary: summary)
            return ChatReply(text: text, origin: .cloud, intent: intent)
        } catch {
            let text = ChatGuard.sanitizeOutput(responder.candidate(for: trimmed, summary: summary))
            let intent: ChatIntent = text == MaudeChatCopy.safetyLine
                ? .safety
                : ChatIntentClassifier.classify(trimmed, summary: summary)
            return ChatReply(text: text, origin: .onDevice, intent: intent)
        }
    }

    /// Back-compat string API (tests + existing callers).
    func respondCloud(to prompt: String) async -> String {
        await replyCloud(to: prompt).text
    }
}

// MARK: - Message model (UI)

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    /// Presentation metadata (A7.2 Area ⑨) — origin drives the honest proof
    /// footer; intent drives the in-bubble spark / calibration bar / chips.
    var origin: ChatReply.Origin = .onDevice
    var intent: ChatIntent = .generic
    var isSafetyLine: Bool { role == .assistant && text == MaudeChatCopy.safetyLine }
}
