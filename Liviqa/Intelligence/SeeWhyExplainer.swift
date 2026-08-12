// SeeWhyExplainer.swift — FR-XPL-01: the decomposition behind every verdict
// Liviqa prints, in the user's own terms (Bevel absorb ②).
//
// WHY THIS EXISTS. The single loudest complaint about score-first health apps is
// that the score cannot be interrogated: a number appears, and there is no way to
// ask what went into it. Liviqa's structural answer is that EVERY verdict surface
// opens, and what opens is the same arithmetic the deriver already ran — which
// numbers, over what window, against which personal baseline, and, where a figure
// is composed, the sum written out.
//
// RULES HELD IN THIS FILE
//  · NO NEW DERIVATION. Every builder takes figures the derivers already produced
//    and formats them. Nothing here reads HealthSamples or recomputes a claim.
//    Where a threshold appears in the copy it is the SAME constant the surface
//    used to pick its word — `todayTone` and `dayScoreLegs` are the single source
//    for the Home verdict and the evening score, so the explanation cannot drift
//    away from the thing it explains.
//  · HONEST ABSENCE. When a surface cannot be explained from real data (sample
//    seeds, a still-calibrating window, a band that has not been learned yet), the
//    builder returns `unexplained` copy that says exactly that. It never invents a
//    plausible-sounding reason and never dresses a seed as a derivation.
//  · FIXED TEMPLATES ONLY (FR-NDG-06 rail). Every sentence and row label here is a
//    fixed template; T-XPL-01 runs all of them through NudgeGuard.
//  · PERSONAL BASELINE ONLY — "your usual", never a population or clinical range.
//    The two places Liviqa does lean on a shared reference (the 70 % time-in-range
//    mark, and the 8-hour sleep leg of the evening score) are NAMED as such in the
//    copy rather than hidden. That is the point of the feature.
//
// Pure Foundation (NFR-PORT-01) — Android-portable, no SwiftUI, no HealthKit.
import Foundation

// MARK: - Model

/// One line of a decomposition: a plain label and the figure behind it.
public nonisolated struct SeeWhyRow: Sendable, Equatable, Identifiable {
    public let label: String
    public let value: String
    public var id: String { label + "\u{1}" + value }

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

/// The disclosure behind one verdict surface. Either it decomposes (`rows`) or it
/// says honestly why it cannot (`unexplained`) — never both, never neither.
public nonisolated struct SeeWhyExplanation: Sendable, Equatable, Identifiable {
    /// Stable per surface, so re-presenting the same disclosure is idempotent.
    public let id: String
    /// Where the verdict was printed — "Today · front page", "Sleep · last night".
    public let surface: String
    /// The verdict being explained, in the exact words the surface showed.
    public let verdict: String
    public let rows: [SeeWhyRow]
    /// Non-nil ⇒ this surface cannot be decomposed from real data right now.
    public let unexplained: String?
    /// The published method note this disclosure deep-links to.
    public let method: LearnTopic?
    public let footer: String

    public init(id: String, surface: String, verdict: String,
                rows: [SeeWhyRow] = [], unexplained: String? = nil,
                method: LearnTopic? = nil,
                footer: String = SeeWhyExplainer.footer) {
        self.id = id
        self.surface = surface
        self.verdict = verdict
        self.rows = unexplained == nil ? rows : []
        self.unexplained = unexplained
        self.method = method
        self.footer = footer
    }
}

/// The Home front-page register. Lives here (not in the view) so the verdict and
/// its explanation are picked by one function.
public nonisolated enum TodayTone: String, Sendable, Equatable {
    case steady, improving, uneven
}

/// One leg of the evening day score, with its arithmetic written out.
public nonisolated struct DayScoreLeg: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable { case sleep, glucose, recovery }
    public let kind: Kind
    public let name: String
    public let points: Double
    public let max: Double
    /// "6.9 h ÷ 8 h reference, capped at 1 × 50"
    public let line: String
    public var id: String { kind.rawValue }
}

/// A vitals row as the Vitals screen already derived it.
public nonisolated struct VitalFact: Sendable, Equatable {
    public let name: String
    public let unit: String
    public let latest: Double
    public let band: ClosedRange<Double>
    public let decimals: Int
    public let typical: Bool

    public init(name: String, unit: String, latest: Double,
                band: ClosedRange<Double>, decimals: Int, typical: Bool) {
        self.name = name; self.unit = unit; self.latest = latest
        self.band = band; self.decimals = decimals; self.typical = typical
    }
}

// MARK: - Builders

public nonisolated enum SeeWhyExplainer {

    /// The personal-baseline footer, carried verbatim on every disclosure.
    public static let footer = String(localized: "Computed on this device · compares you only to yourself · not a diagnostic measure.")

    // Row labels — the user's terms, not the engine's.
    static let lNumbers    = String(localized: "The numbers")
    static let lWindow     = String(localized: "The window")
    static let lBaseline   = String(localized: "Your own baseline")
    static let lArithmetic = String(localized: "The arithmetic")
    static let lReference  = String(localized: "The one shared reference")
    static let lTotal      = String(localized: "Added up")
    static let lSource     = String(localized: "Where it comes from")
    static let lWord       = String(localized: "How the word was picked")

    /// The honest stand-in when a surface is showing sample figures.
    static func sampleData(id: String, surface: String, verdict: String) -> SeeWhyExplanation {
        SeeWhyExplanation(
            id: id, surface: surface, verdict: verdict,
            unexplained: String(localized: "These are sample figures, not your readings — so there is no arithmetic of yours to show. Connect Apple Health and this page fills with your own days, and this panel with the numbers behind them."),
            method: .verdictWords)
    }

    /// The honest stand-in while the baseline is still being learned.
    static func stillLearning(id: String, surface: String, verdict: String,
                              have: Int, need: Int) -> SeeWhyExplanation {
        SeeWhyExplanation(
            id: id, surface: surface, verdict: verdict,
            unexplained: String(localized: "There is nothing to decompose yet — Liviqa has \(have) of the \(need) days it needs before it will compare anything to your usual. Until then it says so instead of guessing."),
            method: .usualBand)
    }

    // MARK: Shared arithmetic (the SAME split the Home verdict uses)

    /// Average of the earlier half of a series against the later half. nil below
    /// four days — too thin to split honestly.
    public static func halves(_ series: [Double]) -> (early: Double, late: Double)? {
        guard series.count >= 4 else { return nil }
        let half = series.count / 2
        let early = series.prefix(half), late = series.suffix(series.count - half)
        return (early.reduce(0, +) / Double(early.count),
                late.reduce(0, +) / Double(late.count))
    }

    /// True when the later half of a real series sits `delta` above the earlier half.
    public static func trendingUp(_ series: [Double], by delta: Double) -> Bool {
        guard let h = halves(series) else { return false }
        return h.late - h.early >= delta
    }

    /// Thresholds, named once so the copy and the verdict cannot disagree.
    public static let tirTargetPct = 70.0        // shared clinical mark (ATTD consensus)
    public static let tirTrendPoints = 5.0       // "trending up" for time in range
    public static let sleepTrendHours = 0.4      // "trending up" for nightly sleep
    public static let hrvTrendMs = 2.0           // "on the way up" for recovery

    /// The Home register — picked here so `todayHero` explains the same decision.
    public static func todayTone(tirIsClay: Bool, tirWeek: [Double], sleepWeek: [Double]) -> TodayTone {
        if tirIsClay { return .uneven }
        if trendingUp(tirWeek, by: tirTrendPoints) || trendingUp(sleepWeek, by: sleepTrendHours) {
            return .improving
        }
        return .steady
    }

    // MARK: Home · front-page verdict

    public static func todayHero(tone: TodayTone, verdict: String,
                                 tirWeek: [Double], sleepWeek: [Double],
                                 hasRealSignals: Bool, coldStart: Bool) -> SeeWhyExplanation {
        let surface = String(localized: "Today · front page")
        let id = "today.hero"
        if coldStart {
            return SeeWhyExplanation(
                id: id, surface: surface, verdict: verdict,
                unexplained: String(localized: "There is no verdict to take apart yet — Liviqa is still collecting your first days. It will not compare you to anything until it has your own days to compare against."),
                method: .usualBand)
        }
        guard hasRealSignals else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = []
        switch tone {
        case .uneven:
            let latest = tirWeek.last.map { "\(Int($0.rounded()))%" } ?? "—"
            rows.append(SeeWhyRow(lNumbers, String(localized: "Time in range, latest day: \(latest) of your readings")))
            rows.append(SeeWhyRow(lWindow, dayWindow(tirWeek.count, of: String(localized: "glucose"))))
            rows.append(SeeWhyRow(lReference, String(localized: "Glucose is the one signal Liviqa also holds against a shared clinical mark — 70% of readings in range. Every other word on this page is measured against your own usual.")))
            rows.append(SeeWhyRow(lWord, String(localized: "Under that mark the week reads as uneven. It is a description of the readings, nothing more.")))
        case .improving:
            if let h = halves(tirWeek), h.late - h.early >= tirTrendPoints {
                rows.append(SeeWhyRow(lNumbers, String(localized: "Time in range: \(pct(h.early)) earlier in the week, \(pct(h.late)) in the later days")))
                rows.append(SeeWhyRow(lWindow, dayWindow(tirWeek.count, of: String(localized: "glucose"))))
                rows.append(SeeWhyRow(lBaseline, String(localized: "Your own earlier days this week — no target, and no comparison to anyone else.")))
                rows.append(SeeWhyRow(lArithmetic, String(localized: "\(pct(h.late)) − \(pct(h.early)) = \(signedPoints(h.late - h.early)). It takes 5 points or more to read as trending up.")))
            } else if let h = halves(sleepWeek) {
                rows.append(SeeWhyRow(lNumbers, String(localized: "Nightly sleep: \(hours(h.early)) earlier in the week, \(hours(h.late)) in the later nights")))
                rows.append(SeeWhyRow(lWindow, dayWindow(sleepWeek.count, of: String(localized: "sleep"))))
                rows.append(SeeWhyRow(lBaseline, String(localized: "Your own earlier nights this week — no target, and no comparison to anyone else.")))
                rows.append(SeeWhyRow(lArithmetic, String(localized: "\(hours(h.late)) − \(hours(h.early)) = \(signedMinutes(h.late - h.early)). It takes about 25 minutes to read as trending up.")))
            }
        case .steady:
            rows.append(SeeWhyRow(lNumbers, String(localized: "Sleep, glucose and recovery all sat inside the spread of your own recent days.")))
            rows.append(SeeWhyRow(lWindow, dayWindow(max(tirWeek.count, sleepWeek.count), of: String(localized: "readings"))))
            rows.append(SeeWhyRow(lBaseline, String(localized: "The later half of your week against the earlier half — your days only.")))
            rows.append(SeeWhyRow(lWord, String(localized: "Nothing moved far enough to change the word: time in range needs 5 points and sleep needs about 25 minutes between the halves of your week.")))
        }
        if rows.isEmpty {
            return SeeWhyExplanation(
                id: id, surface: surface, verdict: verdict,
                unexplained: String(localized: "This line needs at least four days with readings before it can be split into an earlier and a later half. Liviqa has fewer than that right now."),
                method: .usualBand)
        }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .verdictWords)
    }

    // MARK: Home · one signal card

    public nonisolated enum SignalDomain: String, Sendable {
        case sleep, glucose, recovery, heart

        var surface: String {
            switch self {
            case .sleep:    return String(localized: "Today · sleep card")
            case .glucose:  return String(localized: "Today · glucose card")
            case .recovery: return String(localized: "Today · recovery card")
            case .heart:    return String(localized: "Today · heart card")
            }
        }
        var readingLabel: String {
            switch self {
            case .sleep:    return String(localized: "Last night's sleep")
            case .glucose:  return String(localized: "Time in range today")
            case .recovery: return String(localized: "Latest heart-rate variability")
            case .heart:    return String(localized: "Latest resting heart rate")
            }
        }
        var unit: String {
            switch self {
            case .sleep:    return String(localized: "hours")
            case .glucose:  return "%"
            case .recovery: return "ms"
            case .heart:    return "bpm"
            }
        }
        var method: LearnTopic { self == .recovery ? .hrv : .usualBand }
    }

    public static func signalCard(domain: SignalDomain, verdict: String, value: String,
                                  series: [Double], band: ClosedRange<Double>?,
                                  hasRealSignals: Bool, coldStart: Bool) -> SeeWhyExplanation {
        let id = "today.signal." + domain.rawValue
        if coldStart {
            return stillLearning(id: id, surface: domain.surface, verdict: verdict,
                                 have: series.count, need: 4)
        }
        guard hasRealSignals else {
            return sampleData(id: id, surface: domain.surface, verdict: verdict)
        }

        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, "\(domain.readingLabel): \(value)"),
            SeeWhyRow(lWindow, dayWindow(series.count, of: String(localized: "readings"))),
        ]
        if let band {
            let decimals = domain == .sleep ? 1 : 0
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual \(num(band.lowerBound, decimals))–\(num(band.upperBound, decimals)) \(domain.unit) — the middle of those days plus their usual spread.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual band needs at least four days with readings — it is not drawn yet.")))
        }
        switch domain {
        case .sleep:
            rows.append(SeeWhyRow(lWord, String(localized: "Liviqa compares the later half of your week with the earlier half. About 25 minutes more reads as “A little longer”; anything smaller stays “As usual”.")))
        case .glucose:
            rows.append(SeeWhyRow(lReference, String(localized: "Under 70% of readings in range reads as “Worth a look”; at or above it reads as “Steady”. This is the one shared clinical mark in the app — everything else compares you to you.")))
        case .recovery:
            rows.append(SeeWhyRow(lWord, String(localized: "A gain of 2 ms or more between the halves of your week reads as “On the way up”; anything smaller stays “Steady”.")))
        case .heart:
            rows.append(SeeWhyRow(lWord, String(localized: "Inside your own band reads as “Calm”; outside it, the word names the direction. Nothing here is a clinical judgement of the reading.")))
        }
        return SeeWhyExplanation(id: id, surface: domain.surface, verdict: verdict,
                                 rows: rows, method: domain.method)
    }

    // MARK: Evening · the day score

    /// The evening score, decomposed. The SAME function the ring is built from, so
    /// the printed arithmetic is the arithmetic.
    public static func dayScoreLegs(sleepHours: Double?, tirPct: Double?,
                                    hrvLatest: Double?, hrvPriorMean: Double?) -> [DayScoreLeg] {
        var legs: [DayScoreLeg] = []
        if let h = sleepHours {
            legs.append(DayScoreLeg(
                kind: .sleep, name: String(localized: "Sleep"),
                points: min(h / 8, 1) * 50, max: 50,
                line: String(localized: "\(hours(h)) ÷ an 8-hour reference, capped at 1, × 50")))
        }
        if let tir = tirPct {
            legs.append(DayScoreLeg(
                kind: .glucose, name: String(localized: "Glucose"),
                points: tir / 100 * 30, max: 30,
                line: String(localized: "\(pct(tir)) of readings in range ÷ 100 × 30")))
        }
        if let hrv = hrvLatest, let mean = hrvPriorMean, mean > 0 {
            legs.append(DayScoreLeg(
                kind: .recovery, name: String(localized: "Recovery"),
                points: min(hrv / max(mean, 1), 1) * 20, max: 20,
                line: String(localized: "\(num(hrv)) ms ÷ your own \(num(mean)) ms week average, capped at 1, × 20")))
        }
        return legs
    }

    public static func dayScore(legs: [DayScoreLeg], verdict: String,
                                fromRealSignals: Bool) -> SeeWhyExplanation {
        let id = "today.dayscore"
        let surface = String(localized: "Evening · how today scored")
        guard fromRealSignals, !legs.isEmpty else {
            return sampleData(id: id, surface: surface, verdict: verdict)
        }
        var rows = legs.map {
            SeeWhyRow($0.name, "\($0.line) = \(Int($0.points.rounded()))/\(Int($0.max))")
        }
        let total = Int(legs.reduce(0) { $0 + $1.points }.rounded())
        let outOf = Int(legs.reduce(0) { $0 + $1.max })
        rows.append(SeeWhyRow(lTotal, String(localized: "\(total) out of \(outOf) — there is no model behind it, only these lines added together.")))
        rows.append(SeeWhyRow(lWindow, String(localized: "Last night's sleep, today's readings so far, and today's recovery against your own week.")))
        rows.append(SeeWhyRow(lReference, String(localized: "The sleep leg is measured against a fixed 8-hour reference rather than your own average — it is the one part of this score that is not purely about you, and it is printed here so you can allow for it.")))
        if legs.count < 3 {
            rows.append(SeeWhyRow(lNumbers, String(localized: "Only \(legs.count) of the three parts had data today, so the score is out of \(outOf) rather than 100.")))
        }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .dayScore)
    }

    // MARK: Home · a marked day (FR-CTX-04)

    public static func markedDay(verdict: String, kindLabel: String,
                                 startedText: String, isOpen: Bool) -> SeeWhyExplanation {
        SeeWhyExplanation(
            id: "today.context",
            surface: String(localized: "Today · marked day"),
            verdict: verdict,
            rows: [
                SeeWhyRow(lNumbers, String(localized: "Nothing was measured to produce this line — you told Liviqa these days are \(kindLabel.lowercased()).")),
                SeeWhyRow(lWindow, isOpen
                          ? String(localized: "From \(startedText), still open until you clear it.")
                          : String(localized: "From \(startedText).")),
                SeeWhyRow(lWord, String(localized: "While a day is marked, Liviqa stops reading it as drifting from your usual. It can only ever remove a comparison — it never adds one, and it never changes a number.")),
                SeeWhyRow(lBaseline, String(localized: "Your readings on marked days are still recorded, still counted, and still shown on every detail screen.")),
            ],
            method: .verdictWords)
    }

    // MARK: Metric details

    public static func sleepHero(verdict: String, asleepMin: Int, weekMeanMin: Int,
                                 nightCount: Int, rest: Double?, depth: Double?,
                                 rhythm: Double?, deepMin: Int, remMin: Int,
                                 source: String?, isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.sleep"
        let surface = String(localized: "Sleep · last night")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "Asleep last night: \(minText(asleepMin))")),
            SeeWhyRow(lWindow, dayWindow(nightCount, of: String(localized: "sleep"))),
        ]
        if nightCount >= 3 {
            let diff = asleepMin - weekMeanMin
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your own week average: \(minText(weekMeanMin)) a night.")))
            rows.append(SeeWhyRow(lArithmetic, String(localized: "\(minText(asleepMin)) − \(minText(weekMeanMin)) = \(signedMins(diff)). Inside half an hour either way reads as your usual self.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "A week average needs three nights or more — until then the screen only reports what your watch recorded.")))
        }
        if let rest, let depth, let rhythm {
            rows.append(SeeWhyRow(String(localized: "Rest (50)"), String(localized: "\(minText(asleepMin)) ÷ an 8-hour reference, capped at 1, × 50 = \(Int(rest.rounded()))")))
            rows.append(SeeWhyRow(String(localized: "Depth (30)"), String(localized: "Deep \(minText(deepMin)) + REM \(minText(remMin)) as a share of the night ÷ a fixed 35% reference, capped at 1, × 30 = \(Int(depth.rounded()))")))
            rows.append(SeeWhyRow(String(localized: "Rhythm (20)"), String(localized: "How far last night sat from your own week average, over a two-hour span, × 20 = \(Int(rhythm.rounded()))")))
            rows.append(SeeWhyRow(lReference, String(localized: "Two of those three legs lean on fixed references (8 hours, a 35% deep-and-REM share) rather than your own average. They are named here rather than hidden inside a score.")))
        }
        if let source { rows.append(SeeWhyRow(lSource, source)) }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .dayScore)
    }

    public static func glucoseHero(verdict: String, inRangePct: Int, prevWeekPct: Int?,
                                   avgMmol: Double, gmiPct: Double?, dayCount: Int,
                                   source: String?, isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.glucose"
        let surface = String(localized: "Glucose · this week")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "\(inRangePct) of every 100 readings this week fell inside the target band, at an average of \(num(avgMmol, 1)) mmol/L.")),
            SeeWhyRow(lWindow, dayWindow(dayCount, of: String(localized: "glucose"))),
        ]
        if let prev = prevWeekPct {
            let diff = inRangePct - prev
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your own week before: \(prev)% in range.")))
            rows.append(SeeWhyRow(lArithmetic, String(localized: "\(inRangePct)% − \(prev)% = \(signedInt(diff)) points. Three points either way is the step at which the sentence changes.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "There is no earlier week to compare against yet, so the sentence states this week only.")))
        }
        rows.append(SeeWhyRow(lReference, String(localized: "The target band here is the shared clinical one (3.9–10.0 mmol/L) — glucose is the single place Liviqa uses a clinical range rather than your own usual.")))
        if let gmi = gmiPct {
            rows.append(SeeWhyRow(String(localized: "GMI"), String(localized: "\(num(gmi, 1))% — an estimate computed from your average glucose over this window, not a laboratory result.")))
        }
        if let source { rows.append(SeeWhyRow(lSource, source)) }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .verdictWords)
    }

    public static func heartHero(verdict: String, rhrLatest: Int?,
                                 band: ClosedRange<Double>?, windowDays: Int,
                                 seriesCount: Int, isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.heart"
        let surface = String(localized: "Heart · this week")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = []
        if let rhr = rhrLatest {
            rows.append(SeeWhyRow(lNumbers, String(localized: "Latest resting heart rate: \(rhr) bpm")))
        } else {
            rows.append(SeeWhyRow(lNumbers, String(localized: "No resting heart rate has been recorded in this window.")))
        }
        rows.append(SeeWhyRow(lWindow, dayWindow(seriesCount, of: String(localized: "resting heart rate"))))
        if let band {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual \(num(band.lowerBound))–\(num(band.upperBound)) bpm — the middle of your last \(windowDays) days plus their usual spread.")))
            rows.append(SeeWhyRow(lWord, String(localized: "Inside that band the sentence says calm; outside it, the sentence names the direction and nothing else.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual band is not learned yet, so the screen only reports what was recorded.")))
        }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    /// Recovery pillar (HRV) — the legacy descriptive detail screen.
    public static func recoveryHero(verdict: String, latest: String,
                                    band: ClosedRange<Double>?, seriesCount: Int,
                                    hasRealValue: Bool) -> SeeWhyExplanation {
        let id = "detail.recovery"
        let surface = String(localized: "Recovery · stress (HRV)")
        guard hasRealValue else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "Latest heart-rate variability: \(latest)")),
            SeeWhyRow(lWindow, dayWindow(seriesCount, of: String(localized: "heart-rate variability"))),
        ]
        if let band {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual \(num(band.lowerBound))–\(num(band.upperBound)) ms — the middle of those days plus their usual spread.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual band needs at least four days with readings — it is not drawn yet.")))
        }
        rows.append(SeeWhyRow(lWord, String(localized: "This screen describes the readings and their shape. It does not score them, and there is no target to reach.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .hrv)
    }

    public static func fitnessHero(verdict: String, weekCount: Int, loadPoints: Int,
                                   loadUsual: Double?, weeksCompared: Int,
                                   isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.fitness"
        let surface = String(localized: "Training · this week")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        let priorWeeks = max(0, weeksCompared - 1)
        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "\(count(weekCount, String(localized: "session"), String(localized: "sessions"))) logged, \(loadPoints) load points this week.")),
            SeeWhyRow(lWindow, priorWeeks > 0
                      ? String(localized: "This week against your previous \(count(priorWeeks, String(localized: "week"), String(localized: "weeks"))).")
                      : String(localized: "This week only — there are no earlier weeks in the window yet.")),
        ]
        if let usual = loadUsual, usual > 0 {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your own usual: \(num(usual)) load points a week.")))
            rows.append(SeeWhyRow(lArithmetic, String(localized: "\(loadPoints) ÷ \(num(usual)) = \(num(Double(loadPoints) / usual * 100))% of your usual. Above 115% reads as your biggest block; below 85% reads as a lighter week.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "A usual weekly load needs a few weeks of history — until then the sentence only counts what you logged.")))
        }
        rows.append(SeeWhyRow(lWord, String(localized: "Load points add up how long and how hard you moved. Only your own week-to-week change matters — there is no target.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    public static func activityHero(verdict: String, daysAboveUsual: Int,
                                    usualSteps: Double, usualFromHistory: Bool,
                                    pctVsUsual: Int?, weekStepsTotal: Int,
                                    dayCount: Int, isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.activity"
        let surface = String(localized: "Activity · this week")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "\(weekStepsTotal) steps across \(count(dayCount, String(localized: "day"), String(localized: "days"))) this week.")),
            SeeWhyRow(lWindow, dayWindow(dayCount, of: String(localized: "steps"))),
        ]
        if usualFromHistory {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual line: \(num(usualSteps)) steps a day, averaged over your PREVIOUS weeks — a week is never compared against itself.")))
            rows.append(SeeWhyRow(lArithmetic, String(localized: "\(daysAboveUsual) of this week's days sat above that line.")))
            if let pct = pctVsUsual {
                rows.append(SeeWhyRow(String(localized: "The hero figure"), String(localized: "\(signedInt(pct))% is this week's daily average against that same usual line.")))
            }
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual line needs a few earlier weeks. Until it exists the dashed line is this week's own average, and the screen says so.")))
        }
        rows.append(SeeWhyRow(lWord, String(localized: "There are no step goals here — only your own line.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    public static func bodyHero(verdict: String, deltaKg: Double?, sinceMonth: String,
                                corridor: ClosedRange<Double>?, pointCount: Int,
                                source: String?, isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.body"
        let surface = String(localized: "Body · long trend")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        var rows: [SeeWhyRow] = [
            SeeWhyRow(lWindow, String(localized: "\(count(pointCount, String(localized: "reading"), String(localized: "readings"))), starting \(sinceMonth).")),
        ]
        if let delta = deltaKg {
            rows.insert(SeeWhyRow(lNumbers, String(localized: "Change across the window: \(signedKg(delta)).")), at: 0)
            rows.append(SeeWhyRow(lArithmetic, String(localized: "Latest reading minus the first reading in the window. Half a kilo either way is the step at which the sentence changes.")))
        } else {
            rows.insert(SeeWhyRow(lNumbers, String(localized: "Not enough readings to state a change — the screen shows them as recorded.")), at: 0)
        }
        if let corridor {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your own corridor \(num(corridor.lowerBound, 1))–\(num(corridor.upperBound, 1)) kg — the middle of your readings plus their usual spread. No goal weight, no body-mass class.")))
        }
        if let source { rows.append(SeeWhyRow(lSource, source)) }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    public static func vitalsHero(verdict: String, vitals: [VitalFact],
                                  isSeed: Bool) -> SeeWhyExplanation {
        let id = "detail.vitals"
        let surface = String(localized: "Vitals · last 14 nights")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }
        guard !vitals.isEmpty else {
            return SeeWhyExplanation(
                id: id, surface: surface, verdict: verdict,
                unexplained: String(localized: "No overnight vitals have been recorded in this window, so there is nothing to take apart."),
                method: .usualBand)
        }
        var rows = vitals.map { v in
            SeeWhyRow(v.name, String(localized: "Latest \(num(v.latest, v.decimals)) \(v.unit) against your own typical \(num(v.band.lowerBound, v.decimals))–\(num(v.band.upperBound, v.decimals)) \(v.unit)"))
        }
        rows.append(SeeWhyRow(lWindow, String(localized: "The nights in the last fortnight that carried a reading — gaps are left as gaps.")))
        rows.append(SeeWhyRow(lBaseline, String(localized: "Every band on this screen is the middle of your own readings plus their usual spread. None of them is a clinical reference range.")))
        rows.append(SeeWhyRow(lWord, String(localized: "Inside your band reads as typical; outside it reads as worth a look, and nothing further is claimed.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    // MARK: "Your usual" baseline detail

    public static func baseline(name: String, verdict: String, value: Double,
                                unit: String, band: ClosedRange<Double>,
                                learnedFromDays: Int?, seriesCount: Int,
                                isSeed: Bool, method: LearnTopic) -> SeeWhyExplanation {
        let id = "baseline." + name.lowercased()
        let surface = String(localized: "\(name) · your usual")
        guard !isSeed else { return sampleData(id: id, surface: surface, verdict: verdict) }

        let inBand = band.contains(value)
        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "Today: \(num(value, 1)) \(unit)")),
            SeeWhyRow(lWindow, learnedFromDays.map {
                String(localized: "Learned from your last \($0) days on this phone.")
            } ?? dayWindow(seriesCount, of: String(localized: "readings"))),
            SeeWhyRow(lBaseline, String(localized: "Your usual \(num(band.lowerBound, 1))–\(num(band.upperBound, 1)) \(unit).")),
            SeeWhyRow(lArithmetic, String(localized: "The middle of those days, plus the spread they usually have — one standard deviation each way. It re-learns as new days arrive.")),
            SeeWhyRow(lWord, inBand
                      ? String(localized: "Today's figure sits inside that band, so the line reads as your usual range.")
                      : String(localized: "Today's figure sits outside that band, so the line names the direction. One day is a data point, not a story.")),
        ]
        if learnedFromDays == nil && seriesCount < 5 {
            rows.append(SeeWhyRow(lReference, String(localized: "A learned band needs at least five of your own days.")))
        }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: method)
    }

    // MARK: Insight (correlation) detail

    public static func nudge(verdict: String, n: Int, nUnit: String, baselineDays: Int,
                             r: Double?, pText: String?, isGated: Bool,
                             baselineNeeded: Int?) -> SeeWhyExplanation {
        let id = "nudge.evidence"
        let surface = String(localized: "Insight · the evidence")
        guard isGated else {
            return SeeWhyExplanation(
                id: id, surface: surface, verdict: verdict,
                rows: [
                    SeeWhyRow(lNumbers, String(localized: "\(n) \(nUnit) so far, against a baseline of \(baselineDays) days.")),
                    SeeWhyRow(lWindow, baselineNeeded.map {
                        String(localized: "\(n) of the \($0) needed before Liviqa will assert anything.")
                    } ?? String(localized: "Still below the number of days Liviqa needs.")),
                    SeeWhyRow(lWord, String(localized: "Below the gate Liviqa refuses to assert a pattern. Saying “still learning” is the honest answer, and it is the one you get.")),
                ],
                method: .evidenceGate)
        }
        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "\(n) \(nUnit), against a baseline of \(baselineDays) days.")),
        ]
        if let r {
            rows.append(SeeWhyRow(String(localized: "Strength (r)"), String(localized: "\(num(abs(r), 2)) — it takes 0.40 to be shown at all, and 0.60 to be called strong.")))
        }
        if let pText {
            rows.append(SeeWhyRow(String(localized: "Chance of coincidence (p)"), String(localized: "\(pText) — anything looser than 0.05 is not shown.")))
        }
        rows.append(SeeWhyRow(lBaseline, String(localized: "Your own paired days only. Liviqa never pools your data with anyone else's to reach this.")))
        rows.append(SeeWhyRow(lWord, String(localized: "Two things moving together is not proof that one causes the other — the sentence describes the pattern, it does not explain it.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .evidenceGate)
    }

    // MARK: - Formatting helpers (display only)

    static func dayWindow(_ days: Int, of what: String) -> String {
        days <= 0
            ? String(localized: "No days with \(what) in this window yet.")
            : String(localized: "The \(count(days, String(localized: "day"), String(localized: "days"))) in this window that carried \(what) — gaps are left as gaps, never filled in.")
    }

    /// "1 day" / "6 days" — no fabricated plural grammar in the templates.
    static func count(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n) \(n == 1 ? one : many)"
    }

    static func num(_ v: Double, _ decimals: Int = 0) -> String {
        String(format: "%.\(max(0, decimals))f", v)
    }
    static func pct(_ v: Double) -> String { "\(Int(v.rounded()))%" }
    static func hours(_ v: Double) -> String { String(format: "%.1f h", v) }
    static func signedPoints(_ v: Double) -> String {
        let n = Int(v.rounded())
        return n >= 0 ? "+\(n) points" : "\(n) points"
    }
    static func signedInt(_ v: Int) -> String { v >= 0 ? "+\(v)" : "\(v)" }
    static func signedMinutes(_ hoursDelta: Double) -> String {
        let m = Int((hoursDelta * 60).rounded())
        return m >= 0 ? "+\(m) minutes" : "\(m) minutes"
    }
    static func signedMins(_ mins: Int) -> String {
        mins >= 0 ? "+\(mins) minutes" : "\(mins) minutes"
    }
    static func signedKg(_ v: Double) -> String {
        v >= 0 ? String(format: "+%.1f kg", v) : String(format: "%.1f kg", v)
    }
    static func minText(_ mins: Int) -> String {
        "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
    }
}
