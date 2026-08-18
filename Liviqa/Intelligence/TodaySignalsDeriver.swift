// TodaySignalsDeriver.swift — the Home "signals vs your normal" cards,
// derived on device from local HealthSamples so the Home screen shows YOUR data
// (not the demo seeds) the moment Apple Health is connected. Pure Foundation
// (NFR-PORT-01). nil ⇒ not enough real data yet → Home falls back to seeds.
//
// FR-TOD-07 (CN directive 2026-08-19 — "this is an app for all people"): the
// grid is no longer the fixed diabetic four. `homeCards(from:)` decides which
// domains earn a card from what the person ACTUALLY measures — a gym person
// with no CGM sees Sleep · Activity · Workouts · Heart and NO glucose card;
// glucose keeps its clinical treatment whenever it is present.
import Foundation

// MARK: - Whole-person Home domains (FR-TOD-07)

/// The seven Home-grid domains, in their CANONICAL display order (the order
/// cards render in — declaration order IS the contract). Sleep and glucose
/// lead as before; movement (activity, workouts) comes before the wearable
/// recovery/heart pair; body (weigh-ins) closes.
public nonisolated enum HomeDomain: String, Sendable, CaseIterable {
    case sleep, glucose, activity, fitness, recovery, heart, body
}

/// One Home-grid slot. `present == false` is a calibrating pad (the min-2
/// rule): the card renders in its skeleton state and claims nothing.
public nonisolated struct HomeCard: Sendable, Equatable {
    public let domain: HomeDomain
    public let present: Bool
    public init(domain: HomeDomain, present: Bool) {
        self.domain = domain; self.present = present
    }

    /// The pre-FR-TOD-07 fixed grid — kept ONLY for fixtures that carry no
    /// sample stream to derive availability from (LV001, sample-seed fallback).
    public static let classicFour: [HomeCard] = [
        HomeCard(domain: .sleep, present: true),
        HomeCard(domain: .glucose, present: true),
        HomeCard(domain: .recovery, present: true),
        HomeCard(domain: .heart, present: true),
    ]
}

public nonisolated struct TodaySignals: Sendable, Equatable {
    public var sleep: String      // "6h52"
    public var inRange: String    // "61%"
    public var hrv: String        // "48"
    public var rhr: String        // "58"
    public var inRangeIsClay: Bool

    // Last-7-day micro-trends for the Home chip sparklines (oldest→today, one
    // value per day that HAS data — no fabricated zeros). Empty ⇒ no sparkline.
    //
    // A series is SHORTER than the week whenever a day is missing, so its index
    // is NOT a day number. Anything drawing these against a day axis must use
    // `slots(for:over:)` below, which places each value on its own date and
    // leaves a gap where nothing was recorded.
    public var sleepWeek: [Double]
    public var inRangeWeek: [Double]
    public var hrvWeek: [Double]
    public var rhrWeek: [Double]
    /// The day each entry of the matching series belongs to (parallel, same
    /// count, ascending). Empty on the labelled demo fixtures, which carry a
    /// full week by construction — `DaySeries.aligned` handles that case and
    /// refuses to guess for any short series.
    public var sleepWeekDates: [Date]
    public var inRangeWeekDates: [Date]
    public var hrvWeekDates: [Date]
    public var rhrWeekDates: [Date]
    /// Today's glucose readings (mmol/L, chronological) for the CGM-style day curve.
    public var glucoseToday: [Double]

    // — Whole-person domains (FR-TOD-07). Same honesty rules as the four above:
    //   every figure from the real derivers, "—"/empty when nothing was measured.
    /// Latest day's steps, grouped ("8,412"); "—" when no step day exists.
    public var steps: String
    public var stepsWeek: [Double]
    public var stepsWeekDates: [Date]
    /// This week's daily-steps mean vs the person's OWN prior three weeks, in %
    /// (ActivityDeriver.pctVsUsual — nil until real history exists). Drives the
    /// momentum strip's "Steps +12%" (the A7.2 design's own item, droppable
    /// before steps lived here).
    public var stepsPctVsUsual: Int?
    /// Workout sessions in the last 7 days / the 7 days before those.
    public var workoutsWeek: Int
    public var workoutsPrevWeek: Int
    /// Weekly training-load points, oldest → current week (FitnessDeriver's
    /// published duration×intensity arithmetic — up to 4 buckets).
    public var workoutLoadWeeks: [Double]
    /// Mean of the PRIOR weeks' loads (the person's own usual week); nil below
    /// two prior weeks — the Workouts verdict then stays at its in-band word.
    public var workoutLoadUsual: Double?
    /// Weigh-ins over the last 30 days (kg, chronological) + the latest as text.
    public var weightSeries: [Double]
    public var weightLatest: String?
    /// The adaptive Home grid (ordered, ≥2 ≤6 cards) — what this person measures.
    public var cards: [HomeCard]

    public init(sleep: String, inRange: String, hrv: String, rhr: String, inRangeIsClay: Bool,
                sleepWeek: [Double] = [], inRangeWeek: [Double] = [],
                hrvWeek: [Double] = [], rhrWeek: [Double] = [], glucoseToday: [Double] = [],
                sleepWeekDates: [Date] = [], inRangeWeekDates: [Date] = [],
                hrvWeekDates: [Date] = [], rhrWeekDates: [Date] = [],
                steps: String = "—", stepsWeek: [Double] = [], stepsWeekDates: [Date] = [],
                stepsPctVsUsual: Int? = nil,
                workoutsWeek: Int = 0, workoutsPrevWeek: Int = 0,
                workoutLoadWeeks: [Double] = [], workoutLoadUsual: Double? = nil,
                weightSeries: [Double] = [], weightLatest: String? = nil,
                cards: [HomeCard] = HomeCard.classicFour) {
        self.sleep = sleep; self.inRange = inRange; self.hrv = hrv; self.rhr = rhr
        self.inRangeIsClay = inRangeIsClay
        self.sleepWeek = sleepWeek; self.inRangeWeek = inRangeWeek
        self.hrvWeek = hrvWeek; self.rhrWeek = rhrWeek
        self.sleepWeekDates = sleepWeekDates; self.inRangeWeekDates = inRangeWeekDates
        self.hrvWeekDates = hrvWeekDates; self.rhrWeekDates = rhrWeekDates
        self.glucoseToday = glucoseToday
        self.steps = steps; self.stepsWeek = stepsWeek; self.stepsWeekDates = stepsWeekDates
        self.stepsPctVsUsual = stepsPctVsUsual
        self.workoutsWeek = workoutsWeek; self.workoutsPrevWeek = workoutsPrevWeek
        self.workoutLoadWeeks = workoutLoadWeeks; self.workoutLoadUsual = workoutLoadUsual
        self.weightSeries = weightSeries; self.weightLatest = weightLatest
        self.cards = cards
    }

    /// The week series, addressed as a pair so a caller can never reach for
    /// the values and forget the dates.
    public enum WeekSeries: Sendable, CaseIterable {
        case sleep, inRange, hrv, rhr, steps
    }

    public func values(_ series: WeekSeries) -> [Double] {
        switch series {
        case .sleep:   return sleepWeek
        case .inRange: return inRangeWeek
        case .hrv:     return hrvWeek
        case .rhr:     return rhrWeek
        case .steps:   return stepsWeek
        }
    }

    public func dates(_ series: WeekSeries) -> [Date] {
        switch series {
        case .sleep:   return sleepWeekDates
        case .inRange: return inRangeWeekDates
        case .hrv:     return hrvWeekDates
        case .rhr:     return rhrWeekDates
        case .steps:   return stepsWeekDates
        }
    }

    /// One slot per day of `window`, or nil when the series carries no dates and
    /// is too short to place — in which case the caller must draw it WITHOUT day
    /// labels rather than label it wrongly.
    public func slots(for series: WeekSeries, over window: [Date]) -> [DaySlot]? {
        DaySeries.aligned(values: values(series), dates: dates(series), over: window)
    }
}

public nonisolated enum TodaySignalsDeriver {

    public static func derive(from s: HealthSamples,
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0,
                              now: Date = Date()) -> TodaySignals? {
        // Need at least one real signal, else stay on the demo seeds. FR-TOD-07
        // widens the gate: a gym person with ONLY steps/workouts (no CGM, no
        // HRV) is a person with data, not a cold start.
        guard !s.hrv.isEmpty || !s.sleep.isEmpty || !s.glucose.isEmpty || !s.restingHR.isEmpty
                || !s.steps.isEmpty || !s.activeEnergy.isEmpty || !s.workouts.isEmpty
                || !s.bodyComposition.isEmpty
        else { return nil }

        let stats = PassportStatsDeriver.derive(from: s, tirLowMmol: tirLowMmol, tirHighMmol: tirHighMmol)

        // Sleep chip = LAST NIGHT's asleep total — the same figure the Sleep pillar
        // detail shows, and consistent with the "latest reading" semantic of the HRV/
        // RHR chips below. Previously this used the multi-night AVERAGE
        // (stats.avgSleepHours), which read ~54 min off from the detail's last-night
        // value (Home 4h12 vs detail 5h06) — the "front page doesn't match" bug. The
        // average still lives in PassportStats where an average is actually intended.
        let lastNightHours = SleepDeriver.derive(from: s).map { Double($0.asleepMinutes) / 60.0 } ?? 0
        let sleep = lastNightHours > 0 ? formatSleep(lastNightHours) : "—"
        let tir = stats.glucoseTimeInRange
        let inRange = s.glucose.isEmpty ? "—" : "\(tir)%"
        let hrv = latest(s.hrv).map { String(Int($0.rounded())) } ?? "—"
        let rhr = latest(s.restingHR).map { String(Int($0.rounded())) } ?? "—"

        let sleepW = sleepWeekSeries(s, now: now)
        let tirW   = tirWeekSeries(s, lo: tirLowMmol, hi: tirHighMmol, now: now)
        let hrvW   = dailyWeekSeries(s.hrv, now: now)
        let rhrW   = dailyWeekSeries(s.restingHR, now: now)

        // — Whole-person figures, from the REAL derivers (never re-derived here).
        let stepsW = dailyWeekSeries(s.steps, now: now)
        let stepsHeadline = latest(s.steps).map(groupedInt) ?? "—"
        let activity = ActivityDeriver.derive(from: s, now: now)
        let fitness = FitnessDeriver.derive(from: s, now: now)
        let today = cal.startOfDay(for: now)
        let weights = weightSeries(s, today: today)

        return TodaySignals(
            sleep: sleep, inRange: inRange, hrv: hrv, rhr: rhr,
            inRangeIsClay: !s.glucose.isEmpty && tir < 70,
            sleepWeek: sleepW.values,
            inRangeWeek: tirW.values,
            hrvWeek: hrvW.values,
            rhrWeek: rhrW.values,
            glucoseToday: glucoseTodaySeries(s, now: now),
            sleepWeekDates: sleepW.dates,
            inRangeWeekDates: tirW.dates,
            hrvWeekDates: hrvW.dates,
            rhrWeekDates: rhrW.dates,
            steps: stepsHeadline,
            stepsWeek: stepsW.values,
            stepsWeekDates: stepsW.dates,
            stepsPctVsUsual: activity?.pctVsUsual,
            workoutsWeek: workoutCount(s, offsets: 0...6, today: today),
            workoutsPrevWeek: workoutCount(s, offsets: 7...13, today: today),
            workoutLoadWeeks: fitness?.loadWeeks.compactMap(\.points) ?? [],
            workoutLoadUsual: fitness?.loadUsual,
            weightSeries: weights,
            weightLatest: weights.last.map { String(format: "%.1f", $0) },
            cards: homeCards(from: s, now: now))
    }

    // MARK: - Adaptive grid availability (FR-TOD-07 — pure, testable)

    /// Grid bounds: never fewer than 2 cards, never more than 6 (two columns).
    public static let gridMin = 2
    public static let gridMax = 6

    /// The honest cold-start grid: the universal wearable domains, all in their
    /// calibrating state. Deliberately NO glucose — a glucose card nobody
    /// measures is the diabetes-first defect this feature removes; the card
    /// appears with the first real reading.
    public static let calibratingCards: [HomeCard] =
        [HomeDomain.sleep, .activity, .recovery, .heart].map { HomeCard(domain: $0, present: false) }

    /// The window (days, ending today) inside which one reading makes a domain
    /// 'present'. Daily signals use the chip week; workouts get two weeks (a
    /// rest week must not evict the card); weigh-ins are sparse by nature.
    static func presenceWindowDays(_ domain: HomeDomain) -> Int {
        switch domain {
        case .sleep, .glucose, .activity, .recovery, .heart: return 7
        case .fitness: return 14
        case .body: return 30
        }
    }

    /// The one shared yardstick for the overflow cut: days with data in the
    /// LAST 7 DAYS, whatever the domain. Measuring richness inside each
    /// domain's own presence window would let a 30-day trickle of weigh-ins
    /// out-count four real gym sessions — recency is one week for everyone.
    static let richnessWindowDays = 7

    /// Which domains earn a Home card, in canonical display order.
    ///
    /// Rules (all decided here, nowhere else):
    ///  · present ⇔ ≥1 reading inside the domain's own recent window;
    ///  · more than 6 present → keep the 6 with the most days with data in the
    ///    shared last-7-day richness window, ties broken by canonical order;
    ///  · fewer than 2 present → pad with calibrating cards (present:false)
    ///    from the universal set (sleep · activity · recovery · heart);
    ///  · nothing present → the 4-card calibrating default;
    ///  · display order is ALWAYS canonical (`HomeDomain.allCases`), so the
    ///    grid can never shuffle day to day — only membership follows the data.
    public static func homeCards(from s: HealthSamples, now: Date = Date()) -> [HomeCard] {
        let today = cal.startOfDay(for: now)

        func daysWithData(_ domain: HomeDomain, windowDays: Int) -> Int {
            guard let first = cal.date(byAdding: .day, value: -(windowDays - 1),
                                       to: today) else { return 0 }
            let days: Set<Date>
            switch domain {
            case .sleep:    days = Set(s.sleep.map { cal.startOfDay(for: $0.date) })
            case .glucose:  days = Set(s.glucose.map { cal.startOfDay(for: $0.ts) })
            case .activity: days = Set((s.steps + s.activeEnergy).map { cal.startOfDay(for: $0.date) })
            case .fitness:  days = Set(s.workouts.map { cal.startOfDay(for: $0.start) })
            case .recovery: days = Set(s.hrv.map { cal.startOfDay(for: $0.date) })
            case .heart:    days = Set(s.restingHR.map { cal.startOfDay(for: $0.date) })
            case .body:     days = Set(s.bodyComposition.filter { $0.weightKg != nil }
                                        .map { cal.startOfDay(for: $0.ts) })
            }
            return days.filter { $0 >= first && $0 <= today }.count
        }

        let richness = Dictionary(uniqueKeysWithValues: HomeDomain.allCases.map {
            ($0, daysWithData($0, windowDays: richnessWindowDays))
        })
        var present = HomeDomain.allCases.filter {
            daysWithData($0, windowDays: presenceWindowDays($0)) > 0
        }

        if present.isEmpty { return calibratingCards }

        if present.count > gridMax {
            // Keep the richest; canonical position wins a tie. Membership may
            // change with the data — the ORDER of survivors never does.
            let ranked = present.enumerated().sorted {
                let (ri, rj) = (richness[$0.element, default: 0], richness[$1.element, default: 0])
                return ri != rj ? ri > rj : $0.offset < $1.offset
            }
            let kept = Set(ranked.prefix(gridMax).map(\.element))
            present = present.filter { kept.contains($0) }
        }

        var cards = present.map { HomeCard(domain: $0, present: true) }
        if cards.count < gridMin {
            for pad in [HomeDomain.sleep, .activity, .recovery, .heart]
            where !present.contains(pad) && cards.count < gridMin {
                cards.append(HomeCard(domain: pad, present: false))
            }
            let order = HomeDomain.allCases
            cards.sort { order.firstIndex(of: $0.domain)! < order.firstIndex(of: $1.domain)! }
        }
        return cards
    }

    /// A week series and the days it actually covers, always built together.
    private typealias WeekSeries = (values: [Double], dates: [Date])
    private static let emptyWeek: WeekSeries = ([], [])

    /// Today's glucose readings (mmol/L) in chronological order; [] if <2 today.
    private static func glucoseTodaySeries(_ s: HealthSamples, now: Date) -> [Double] {
        let today = cal.startOfDay(for: now)
        let todays = s.glucose
            .filter { cal.isDate($0.ts, inSameDayAs: today) }
            .sorted { $0.ts < $1.ts }
            .map { $0.mmol }
        return todays.count >= 2 ? todays : []
    }

    // MARK: 7-day micro-trend series (oldest→today; one value per day WITH data).

    private static let cal = Calendar(identifier: .gregorian)
    private static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
    private static func recentDays(_ count: Int = 7, now: Date) -> [Date] {
        let today = cal.startOfDay(for: now)
        return (0..<count).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    /// Pair the last-7-day values with the days they came from, dropping days
    /// with no reading. Under 2 days ⇒ empty (nothing to trend).
    private static func weekSeries(now: Date, _ valueFor: (Date) -> Double?) -> WeekSeries {
        let pairs = recentDays(now: now).compactMap { d in valueFor(d).map { (d, $0) } }
        guard pairs.count >= 2 else { return emptyWeek }
        return (pairs.map(\.1), pairs.map(\.0))
    }

    /// Daily-mean metric (HRV, resting HR, steps) → last-7-day series, days with data only.
    private static func dailyWeekSeries(_ metrics: [DailyMetric], now: Date) -> WeekSeries {
        guard !metrics.isEmpty else { return emptyWeek }
        var byDay: [Date: Double] = [:]
        for m in metrics { byDay[cal.startOfDay(for: m.date)] = m.value }   // already daily
        return weekSeries(now: now) { byDay[$0] }
    }

    /// Per-day total asleep hours over the last 7 days, days with data only.
    private static func sleepWeekSeries(_ s: HealthSamples, now: Date) -> WeekSeries {
        guard !s.sleep.isEmpty else { return emptyWeek }
        // Union per night (dedupes overlapping iPhone + Watch segments), asleep
        // stages only — mirrors the SLEEP chip's nightly total.
        var byDay: [Date: [SleepReading]] = [:]
        for seg in s.sleep where asleepStages.contains(seg.stage) {
            byDay[cal.startOfDay(for: seg.date), default: []].append(seg)
        }
        return weekSeries(now: now) { day in
            byDay[day].map { SleepReading.mergedAsleepHours($0, asleep: asleepStages) }
        }
    }

    /// Per-day time-in-range % over the last 7 days, days with glucose only.
    private static func tirWeekSeries(_ s: HealthSamples, lo: Double, hi: Double, now: Date) -> WeekSeries {
        guard !s.glucose.isEmpty else { return emptyWeek }
        let low = min(lo, hi), high = max(lo, hi)
        var total: [Date: Int] = [:], inR: [Date: Int] = [:]
        for g in s.glucose {
            let d = cal.startOfDay(for: g.ts)
            total[d, default: 0] += 1
            if g.mmol >= low && g.mmol <= high { inR[d, default: 0] += 1 }
        }
        return weekSeries(now: now) { d in
            guard let t = total[d], t > 0 else { return nil }
            return Double(inR[d] ?? 0) / Double(t) * 100
        }
    }

    /// Workouts whose day sits `offsets` days before today (0 = today).
    private static func workoutCount(_ s: HealthSamples, offsets: ClosedRange<Int>, today: Date) -> Int {
        s.workouts.filter {
            let d = cal.startOfDay(for: $0.start)
            guard let off = cal.dateComponents([.day], from: d, to: today).day else { return false }
            return offsets.contains(off)
        }.count
    }

    /// Weigh-ins (kg) over the last 30 days, chronological.
    private static func weightSeries(_ s: HealthSamples, today: Date) -> [Double] {
        guard let first = cal.date(byAdding: .day, value: -29, to: today) else { return [] }
        return s.bodyComposition
            .filter {
                let d = cal.startOfDay(for: $0.ts)
                return $0.weightKg != nil && d >= first && d <= today
            }
            .sorted { $0.ts < $1.ts }
            .compactMap(\.weightKg)
    }

    /// Most recent value in a daily series.
    private static func latest(_ m: [DailyMetric]) -> Double? {
        m.max(by: { $0.date < $1.date })?.value
    }

    private static func formatSleep(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int(((hours - Double(h)) * 60).rounded())
        return m == 60 ? "\(h + 1)h00" : "\(h)h\(String(format: "%02d", m))"
    }

    /// "8412" → "8,412" — fixed grouping, deterministic in every locale (EN copy rail).
    private static func groupedInt(_ v: Double) -> String {
        let digits = Array(String(Int(v.rounded())))
        var out: [Character] = []
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0, i % 3 == 0, ch.isNumber { out.append(",") }
            out.append(ch)
        }
        return String(out.reversed())
    }
}

// MARK: - "See why" for the whole-person cards (FR-XPL-01 · FR-TOD-07)
//
// Same contract as every builder in SeeWhyExplainer.swift: fixed templates only
// (guard-checked in TodayGridAvailabilityTests), no new derivation — every
// figure printed here was handed in by the deriver that computed it. These live
// in this file (not SeeWhyExplainer.swift) because the FR-TOD-07 wave owns this
// file; the idiom and the shared row labels are SeeWhyExplainer's own.
public extension SeeWhyExplainer {

    /// Half-width of the "around your usual" comparison for weekly training
    /// load — the ONE constant the Workouts verdict and its copy share.
    static let loadUsualFraction = 0.25

    static func activityCard(verdict: String, value: String, series: [Double],
                             band: ClosedRange<Double>?, hasRealSignals: Bool,
                             coldStart: Bool) -> SeeWhyExplanation {
        let id = "today.signal.activity"
        let surface = String(localized: "Today · activity card")
        if coldStart {
            return stillLearning(id: id, surface: surface, verdict: verdict,
                                 have: series.count, need: 4)
        }
        guard hasRealSignals else {
            return sampleData(id: id, surface: surface, verdict: verdict)
        }
        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "Latest day's steps: \(value)")),
            SeeWhyRow(lWindow, dayWindow(series.count, of: String(localized: "step counts"))),
        ]
        if let band {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual \(num(band.lowerBound))–\(num(band.upperBound)) steps a day — the middle of those days plus their usual spread.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual band needs at least four days with readings — it is not drawn yet.")))
        }
        rows.append(SeeWhyRow(lWord, String(localized: "Inside your own band reads as “As usual”; outside it, the word names the direction. Your own days are the only reference — never a step target.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    static func fitnessCard(verdict: String, sessions: Int, loadWeeks: [Double],
                            loadUsual: Double?, hasRealSignals: Bool,
                            coldStart: Bool) -> SeeWhyExplanation {
        let id = "today.signal.fitness"
        let surface = String(localized: "Today · workouts card")
        if coldStart {
            return stillLearning(id: id, surface: surface, verdict: verdict,
                                 have: loadWeeks.count, need: 2)
        }
        guard hasRealSignals else {
            return sampleData(id: id, surface: surface, verdict: verdict)
        }
        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "Sessions in the last 7 days: \(sessions)")),
            SeeWhyRow(lWindow, String(localized: "Weekly training load over your last \(count(loadWeeks.count, String(localized: "week"), String(localized: "weeks"))) — how long you moved × how hard, from your own recordings.")),
        ]
        if let usual = loadUsual, usual > 0 {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual week: \(num(usual)) load points — the mean of your own prior weeks, never a plan or target.")))
            rows.append(SeeWhyRow(lWord, String(localized: "Within a quarter of your usual week reads as “As usual”; outside that, the word names the direction.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual training week needs at least two prior weeks with sessions — it is not drawn yet.")))
            rows.append(SeeWhyRow(lWord, String(localized: "Until your usual week exists the card stays at “As usual” rather than guessing.")))
        }
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }

    static func bodyCard(verdict: String, value: String, series: [Double],
                         band: ClosedRange<Double>?, hasRealSignals: Bool,
                         coldStart: Bool) -> SeeWhyExplanation {
        let id = "today.signal.body"
        let surface = String(localized: "Today · body card")
        if coldStart {
            return stillLearning(id: id, surface: surface, verdict: verdict,
                                 have: series.count, need: 4)
        }
        guard hasRealSignals else {
            return sampleData(id: id, surface: surface, verdict: verdict)
        }
        var rows: [SeeWhyRow] = [
            SeeWhyRow(lNumbers, String(localized: "Latest weight: \(value) kg")),
            SeeWhyRow(lWindow, dayWindow(series.count, of: String(localized: "weigh-ins"))),
        ]
        if let band {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual \(num(band.lowerBound, 1))–\(num(band.upperBound, 1)) kg — the middle of those days plus their usual spread.")))
        } else {
            rows.append(SeeWhyRow(lBaseline, String(localized: "Your usual band needs at least four days with readings — it is not drawn yet.")))
        }
        rows.append(SeeWhyRow(lWord, String(localized: "Inside your own band reads as “Steady”; outside it, the word names the direction. Nothing here is a clinical judgement of the reading.")))
        return SeeWhyExplanation(id: id, surface: surface, verdict: verdict,
                                 rows: rows, method: .usualBand)
    }
}
