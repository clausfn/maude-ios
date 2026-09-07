// DayScoreComposer.swift — the evening day score, composed from the domains the
// person ACTUALLY tracks (CN directive 2026-08-19: "this is an app for all
// people", not the diabetic persona's fixed trio). Pure Foundation (NFR-PORT-01).
//
// WHAT CHANGED vs the shipped FR-TOD-05 score (SeeWhyExplainer.dayScoreLegs):
// the A7.2 design scored Sleep/50 · Glucose/30 · Movement/20; we shipped
// Recovery in movement's slot because steps were not ingested then. They are
// now (post-PR-109), so movement joins — and the score stops assuming a CGM.
//
// ADAPTIVITY RULES (all of them, nothing hidden):
//  · Four domains can carry a part: sleep, glucose, movement, recovery.
//  · Per-domain weights are FIXED for everyone and printed on the card:
//    sleep 50 · glucose 30 · movement 20 · recovery 20. A domain is never
//    re-weighted because another one is missing — the denominator shrinks
//    instead, and the "See why" sheet says so out loud.
//  · A day score keeps at most THREE parts (the design's three-part anatomy),
//    filled in fixed priority order sleep > glucose > movement > recovery.
//    So: a CGM user scores sleep+glucose+movement (/100 — the designed trio);
//    a gym user without a CGM scores sleep+movement+recovery (/90); a CGM
//    user without step data scores sleep+glucose+recovery (/100 — exactly the
//    shipped composition, so nobody's score changes shape for no reason).
//  · A domain with data that the cap outranks is NAMED in the disclosure —
//    it is dropped from the sum, never silently.
//  · Fewer than two domains with data ⇒ no score at all (one domain alone
//    isn't "a day" — the shipped rule, kept).
//  · Arithmetic per part (each line is printed, FR-TOD-05 anti-score-opacity):
//      sleep     min(lastNightHours / 8, 1) × 50      (fixed 8 h reference — NAMED)
//      glucose   todayTIR% / 100 × 30                  (the app's one clinical band)
//      movement  min(latestSteps / own prior-days mean, 1) × 20   (you vs you)
//      recovery  min(latestHRV  / own prior-days mean, 1) × 20    (you vs you)
//    movement/recovery need ≥ 4 days in the week series so the "own mean" is
//    real history (mean of the series MINUS the day being scored), mirroring
//    the shipped recovery leg. A ≤ 0 mean refuses the part rather than divide.
//  · The verdict is picked from the same three allow-listed sentences the card
//    always used, on the RATIO earned/possible (≥ 0.75 good · ≥ 0.60 steady),
//    so a /90 or /80 day is never judged against a /100 bar.
//
// Every sentence this file can emit passes NudgeGuard (FR-NDG-06, designated
// control) — pinned in DayScoreComposerTests.
import Foundation

public nonisolated enum DayScoreComposer {

    // MARK: Model

    public enum Domain: String, Sendable, CaseIterable {
        case sleep, glucose, movement, recovery
    }

    /// One part of the score, with its arithmetic written out.
    public struct Part: Sendable, Equatable, Identifiable {
        public let domain: Domain
        public let name: String         // display name ("Movement")
        public let points: Double
        public let max: Double          // the domain's fixed weight
        public let line: String         // "8,200 steps ÷ your own 7,400-step …"
        public var id: String { domain.rawValue }
    }

    /// The composed score. `parts` is what the ring draws; `dropped` is any
    /// domain that HAD data but was outranked by the three-part cap.
    public struct Score: Sendable, Equatable {
        public let parts: [Part]
        public let dropped: [Domain]

        /// Points earned / possible, unrounded (the verdict is picked on these).
        public var earned: Double { parts.reduce(0) { $0 + $1.points } }
        public var possible: Double { parts.reduce(0) { $0 + $1.max } }
        public var total: Int { Int(earned.rounded()) }
        public var outOf: Int { Int(possible.rounded()) }

        /// Allow-listed verdict, thresholded on the RATIO so a score out of 90
        /// or 80 is judged on its own denominator, never against 100.
        public var verdict: String {
            let ratio = possible > 0 ? earned / possible : 0
            if ratio >= 0.75,
               let top = parts.max(by: { $0.points / $0.max < $1.points / $1.max }) {
                return String(localized: "A good day — mostly thanks to \(top.name.lowercased()).")
            }
            if ratio >= 0.60 { return String(localized: "A steady day.") }
            return String(localized: "A lighter day — they happen.")
        }
    }

    // MARK: Published constants (the rules above, as code)

    /// Fixed per-domain weights — the same for every person, always.
    public static func weight(_ d: Domain) -> Double {
        switch d {
        case .sleep: return 50
        case .glucose: return 30
        case .movement: return 20
        case .recovery: return 20
        }
    }

    /// Fixed fill order for the three slots.
    public static let priority: [Domain] = [.sleep, .glucose, .movement, .recovery]
    /// The design's three-part anatomy.
    public static let partLimit = 3
    /// An "own mean" needs this many days in the week series before a
    /// vs-your-own-usual part is derived (mirrors the shipped recovery leg).
    public static let minSeriesDays = 4

    // MARK: Compose

    /// Build the day score from whatever the person actually has.
    /// - Parameters:
    ///   - sleepHours: last night's asleep hours (`sleepWeek.last`), nil = no sleep data.
    ///   - tirPct: the latest day's time-in-range % (`inRangeWeek.last`), nil = no CGM.
    ///   - stepsWeek: last-7-day steps series, days WITH data only, oldest → latest
    ///     (`ActivityWeekDetail.stepsWeek`; [] = no step data).
    ///   - hrvWeek: last-7-day HRV series, same shape (`TodaySignals.hrvWeek`).
    /// - Returns: nil when fewer than two domains have usable data.
    public static func compose(sleepHours: Double?,
                               tirPct: Double?,
                               stepsWeek: [Double],
                               hrvWeek: [Double]) -> Score? {
        var available: [Domain: Part] = [:]

        if let h = sleepHours {
            available[.sleep] = Part(
                domain: .sleep, name: String(localized: "Sleep"),
                points: min(h / 8, 1) * weight(.sleep), max: weight(.sleep),
                line: String(localized: "\(SeeWhyExplainer.hours(h)) ÷ an 8-hour reference, capped at 1, × 50"))
        }
        if let tir = tirPct {
            available[.glucose] = Part(
                domain: .glucose, name: String(localized: "Glucose"),
                points: tir / 100 * weight(.glucose), max: weight(.glucose),
                line: String(localized: "\(SeeWhyExplainer.pct(tir)) of readings in range ÷ 100 × 30"))
        }
        if let (latest, ownMean) = latestVsOwnMean(stepsWeek) {
            available[.movement] = Part(
                domain: .movement, name: String(localized: "Movement"),
                points: min(latest / ownMean, 1) * weight(.movement), max: weight(.movement),
                line: String(localized: "\(grouped(latest)) steps ÷ your own \(grouped(ownMean))-step week average, capped at 1, × 20"))
        }
        if let (latest, ownMean) = latestVsOwnMean(hrvWeek) {
            available[.recovery] = Part(
                domain: .recovery, name: String(localized: "Recovery"),
                points: min(latest / ownMean, 1) * weight(.recovery), max: weight(.recovery),
                line: String(localized: "\(SeeWhyExplainer.num(latest)) ms ÷ your own \(SeeWhyExplainer.num(ownMean)) ms week average, capped at 1, × 20"))
        }

        guard available.count >= 2 else { return nil }   // one domain alone isn't a "day"

        let ranked = priority.filter { available[$0] != nil }
        let kept = Array(ranked.prefix(partLimit))
        let dropped = Array(ranked.dropFirst(partLimit))
        return Score(parts: kept.compactMap { available[$0] }, dropped: dropped)
    }

    /// Latest value of a days-with-data week series against the mean of its
    /// PRIOR days (the series minus the day being scored). nil under
    /// `minSeriesDays`, or when the prior mean isn't positive.
    static func latestVsOwnMean(_ series: [Double]) -> (latest: Double, ownMean: Double)? {
        guard series.count >= minSeriesDays, let latest = series.last else { return nil }
        let prior = series.dropLast()
        let mean = prior.reduce(0, +) / Double(prior.count)
        guard mean > 0 else { return nil }
        return (latest, mean)
    }

    // MARK: "See why" (FR-XPL-01 — the same numbers the ring is drawn from)

    public static func seeWhy(_ score: Score, fromRealSignals: Bool) -> SeeWhyExplanation {
        let id = "today.dayscore"
        let surface = String(localized: "Evening · how today scored")
        guard fromRealSignals, !score.parts.isEmpty else {
            return SeeWhyExplainer.sampleData(id: id, surface: surface, verdict: score.verdict)
        }
        var rows = score.parts.map {
            SeeWhyRow($0.name, "\($0.line) = \(Int($0.points.rounded()))/\(Int($0.max))")
        }
        rows.append(SeeWhyRow(SeeWhyExplainer.lTotal, String(localized:
            "\(score.total) out of \(score.outOf) — there is no model behind it, only these lines added together.")))
        rows.append(SeeWhyRow(SeeWhyExplainer.lWindow, String(localized:
            "Each part is the most recent day with readings in your last 7 days, set against the reference printed on its own line.")))
        rows.append(SeeWhyRow(SeeWhyExplainer.lReference, referenceLine(for: score)))
        if score.outOf < 100 {
            rows.append(SeeWhyRow(SeeWhyExplainer.lNumbers, String(localized:
                "Only the parts you actually track are added — \(score.parts.count) had data today, so the score is out of \(score.outOf) rather than 100.")))
        }
        for domain in score.dropped {
            rows.append(SeeWhyRow(SeeWhyExplainer.lWord, String(localized:
                "A day score keeps its three biggest parts, so \(displayName(domain).lowercased()) is not folded in today even though it has data — it keeps its own card on this screen.")))
        }
        return SeeWhyExplanation(id: id, surface: surface, verdict: score.verdict,
                                 rows: rows, method: .dayScore)
    }

    /// Which shared reference (if any) this composition leans on — NAMED, per
    /// the FR-XPL-01 stance, instead of passing as "your usual".
    static func referenceLine(for score: Score) -> String {
        let domains = Set(score.parts.map(\.domain))
        if domains.contains(.sleep) {
            return String(localized: "The sleep part is measured against a fixed 8-hour reference rather than your own average — it is the one part of this score that is not purely about you, and it is printed here so you can allow for it.")
        }
        if domains.contains(.glucose) {
            return String(localized: "The glucose part counts readings inside the shared clinical target band rather than a band of your own — the other parts compare you only to yourself.")
        }
        return String(localized: "Every part of this score is measured against your own week — no shared reference is used.")
    }

    static func displayName(_ d: Domain) -> String {
        switch d {
        case .sleep: return String(localized: "Sleep")
        case .glucose: return String(localized: "Glucose")
        case .movement: return String(localized: "Movement")
        case .recovery: return String(localized: "Recovery")
        }
    }

    /// "8,200" — grouped integer for step counts. Fixed to the EN copy register
    /// (the app's copy rail), so the printed arithmetic is deterministic.
    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "en_US")   // POSIX drops the grouping separator
        return f.string(from: NSNumber(value: v.rounded())) ?? String(Int(v.rounded()))
    }
}
