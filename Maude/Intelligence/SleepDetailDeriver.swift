// SleepDetailDeriver.swift — everything the A7.2 Sleep metric-detail screen shows,
// derived on device from local `HealthSamples`. Pure Foundation — no SwiftData /
// SwiftUI / HealthKit (NFR-PORT-01) — unit-testable and Android-portable.
//
// NUMBERS ONLY: no sentences here. The view maps these figures onto fixed
// descriptive templates ("You slept like your usual self." …) — nothing
// generated, nothing prescriptive (FR-NDG-06 rail; templates guard-tested).
//
// INGESTION (checked against HealthKitService.readSleep, 2026-08-13): segments
// now carry their wall-clock START and the AWAKE stage, and a night is bucketed
// by the day it ends on. So the night timeline (the søkort depth chart), the
// wake-up moment, the AWAKE total and bedtime consistency are all derivable
// from real data — and each is returned as `nil` when the source did NOT give
// intra-night times (an aggregated import, a hand-logged night). The screen
// then falls back to the same honest reduced anatomy as before (stage totals +
// proportions + nightly week + duration-vs-last-week) rather than inventing a
// shape.
//
// BEDTIME IS COMPARED TO THE CITIZEN'S OWN USUAL — the mean of their own recent
// bedtimes — never to a recommended or "ideal" bedtime. There is no target here.
//
// nil ⇒ no asleep segments in the window → demo seeds (demo mode) or an honest
// empty state (real-data mode).
import Foundation

/// Last night drawn as a shape: the segments in time order on a 0…1 night axis,
/// where the stage totals sit, and the one wake-up worth annotating. Present
/// ONLY when the source retained intra-night times — never reconstructed.
///
/// DHF note (CN directive 2026-08-19): the BLOCK hypnogram — drawn from
/// `SleepNight.segments` — supersedes the søkort line chart this shape was
/// designed for. The shape is kept because it is derived from the SAME
/// `SleepNight` object at near-zero cost and the view still consumes it while
/// the block hypnogram lands; its soundings now carry the night's tile figures
/// verbatim, so it cannot contradict the tiles either.
public nonisolated struct SleepNightShape: Sendable, Equatable {

    /// Stage on the chart's own scale: 0 awake · 1 REM · 2 core · 3 deep.
    public struct Segment: Sendable, Equatable {
        public let stage: Int
        public let t0: Double
        public let t1: Double
        public init(stage: Int, t0: Double, t1: Double) {
            self.stage = stage; self.t0 = t0; self.t1 = t1
        }
    }

    /// A stage total printed in open water at the stage's longest stretch.
    public struct Sounding: Sendable, Equatable {
        public let stage: Int
        public let t: Double
        public let minutes: Int
        public init(stage: Int, t: Double, minutes: Int) {
            self.stage = stage; self.t = t; self.minutes = minutes
        }
    }

    /// The longest wake-up inside the night (≥5 min), if there was one.
    public struct Wake: Sendable, Equatable {
        public let t: Double
        public let clock: String        // "02:10"
        public let minutes: Int
        public init(t: Double, clock: String, minutes: Int) {
            self.t = t; self.clock = clock; self.minutes = minutes
        }
    }

    public let segments: [Segment]
    public let soundings: [Sounding]
    public let wake: Wake?
    public let startClock: String       // "23:04"
    public let endClock: String         // "06:14"

    public init(segments: [Segment], soundings: [Sounding], wake: Wake?,
                startClock: String, endClock: String) {
        self.segments = segments; self.soundings = soundings; self.wake = wake
        self.startClock = startClock; self.endClock = endClock
    }
}

/// Bedtime against the citizen's OWN usual (the mean of their own bedtimes this
/// week). Never a recommended bedtime — there is no correct hour here.
public nonisolated struct SleepBedtimeWeek: Sendable, Equatable {
    public let thisWeekClock: String        // mean bedtime, "23:04"
    public let prevWeekClock: String?
    /// The same two figures as minutes since 18:00 — so a bar can be drawn to
    /// the real relative lateness instead of an invented proportion.
    public let thisWeekMinutes: Int
    public let prevWeekMinutes: Int?
    public let nightsNearUsual: Int         // within ±30 min of their own mean
    public let nightCount: Int
    public init(thisWeekClock: String, prevWeekClock: String?,
                thisWeekMinutes: Int, prevWeekMinutes: Int?,
                nightsNearUsual: Int, nightCount: Int) {
        self.thisWeekClock = thisWeekClock; self.prevWeekClock = prevWeekClock
        self.thisWeekMinutes = thisWeekMinutes; self.prevWeekMinutes = prevWeekMinutes
        self.nightsNearUsual = nightsNearUsual; self.nightCount = nightCount
    }
}

public nonisolated struct SleepWeekDetail: Sendable, Equatable {

    /// One night of the week bars (only nights that HAVE data), oldest → latest.
    public struct Night: Sendable, Equatable {
        public let label: String     // narrow weekday letter ("M")
        public let hours: Double
        public let isLastNight: Bool
        public init(label: String, hours: Double, isLastNight: Bool) {
            self.label = label; self.hours = hours; self.isLastNight = isLastNight
        }
    }

    // Last night (the most recent night with asleep data).
    public let asleepMin: Int
    public let deepMin: Int
    public let coreMin: Int          // core + unspecified ("Light"/"Core" in UI)
    public let remMin: Int
    /// Minutes awake INSIDE the night (between falling asleep and getting up).
    /// 0 when the source recorded no wake-ups, or recorded no awake stage.
    public let awakeMin: Int
    /// True when real stage structure exists (deep or REM present); otherwise
    /// the source only gave an undifferentiated total.
    public var hasStageDetail: Bool { deepMin > 0 || remMin > 0 }

    /// Nights −6…0 with data, oldest → latest.
    public let nights: [Night]
    /// Mean asleep minutes across `nights` (includes last night).
    public let weekMeanMin: Int
    /// Same figure for nights −13…−7; nil when that window has no nights.
    public let prevWeekMeanMin: Int?
    /// Dominant source name among the window's nights (honest source line).
    public let source: String?
    /// Last night as a shape — nil when the source kept no intra-night times.
    public let shape: SleepNightShape?
    /// Bedtime vs the citizen's own usual — nil below 3 timed nights.
    public let bedtime: SleepBedtimeWeek?

    // — The one-truth surface (sleep visualisation wave 2026-08) —
    /// LAST NIGHT as the one resolved model. The legacy figures above are
    /// COPIES of this object's fields (assigned in `derive`, verified by
    /// `assertAgreement()`), so hero, tiles, hypnogram and labels cannot
    /// disagree: they all render one object.
    public let night: SleepNight
    /// W — 7 nights + clock-positioned stacked columns (22:00→14:00 axis).
    public let week: SleepWeekRange
    /// M — per-night duration on a 30-day day axis; gaps are gaps.
    public let month: SleepLongRange
    /// 6M — per-night duration on a 182-day axis + weekly stage aggregates.
    public let sixMonths: SleepLongRange

    public init(asleepMin: Int, deepMin: Int, coreMin: Int, remMin: Int,
                awakeMin: Int = 0,
                nights: [Night], weekMeanMin: Int, prevWeekMeanMin: Int?,
                source: String?, shape: SleepNightShape? = nil,
                bedtime: SleepBedtimeWeek? = nil,
                night: SleepNight,
                week: SleepWeekRange = .empty,
                month: SleepLongRange = .empty,
                sixMonths: SleepLongRange = .empty) {
        self.asleepMin = asleepMin; self.deepMin = deepMin
        self.coreMin = coreMin; self.remMin = remMin; self.awakeMin = awakeMin
        self.nights = nights; self.weekMeanMin = weekMeanMin
        self.prevWeekMeanMin = prevWeekMeanMin; self.source = source
        self.shape = shape; self.bedtime = bedtime
        self.night = night; self.week = week
        self.month = month; self.sixMonths = sixMonths
    }

    /// Proof for tests: the legacy figures and the shape agree with `night`
    /// (the one object), and `night` itself is internally consistent. Empty
    /// means no sleep surface reading this value can contradict itself.
    public func assertAgreement() -> [String] {
        var v = night.assertInternalConsistency()
        if asleepMin != night.asleepMin { v.append("detail asleepMin != night") }
        if deepMin != night.deepMin { v.append("detail deepMin != night") }
        if coreMin != night.coreMin { v.append("detail coreMin != night") }
        if remMin != night.remMin { v.append("detail remMin != night") }
        if awakeMin != night.awakeMin { v.append("detail awakeMin != night") }
        if let shape {
            for (stage, tile) in [(3, night.deepMin), (1, night.remMin), (2, night.coreMin)] {
                if let sounding = shape.soundings.first(where: { $0.stage == stage }),
                   sounding.minutes != tile {
                    v.append("shape sounding stage \(stage) \(sounding.minutes)m != tile \(tile)m")
                }
            }
        }
        if let weekNight = week.nights.last, weekNight.date == night.date,
           weekNight != night {
            v.append("week range's last night != the night model")
        }
        return v
    }
}

public nonisolated enum SleepDetailDeriver {

    private static let cal = Calendar(identifier: .gregorian)

    public static func derive(from s: HealthSamples, now: Date = Date()) -> SleepWeekDetail? {
        // ONE MODEL PER NIGHT (FR-SLP-10 + sleep visualisation wave 2026-08):
        // the builder re-applies the resolver (idempotent over `arbitrated()`),
        // so an overlapping second source can never double-count a night and a
        // nap can never join it — and EVERY figure below (hero, tiles, shape,
        // week bars, ranges) is read off the same [SleepNight] array. The
        // same-screen contradiction (tiles vs chart labels) is structurally
        // impossible: there is no second arithmetic to disagree with.
        let allNights = SleepNightBuilder.nights(from: s, calendar: cal)
        guard let lastNight = allNights.last else { return nil }

        let byDay = Dictionary(uniqueKeysWithValues: allNights.map { ($0.date, $0) })
        let today = cal.startOfDay(for: now)
        let symbols = cal.veryShortWeekdaySymbols

        func nightsIn(_ fromOffset: Int, _ toOffset: Int) -> [SleepNight] {
            (fromOffset...toOffset).compactMap { off in
                cal.date(byAdding: .day, value: off, to: today).flatMap { byDay[$0] }
            }
        }

        let week = nightsIn(-6, 0)
        let prev = nightsIn(-13, -7)
        let nights = week.map { n in
            SleepWeekDetail.Night(
                label: symbols[(cal.component(.weekday, from: n.date) - 1) % symbols.count],
                hours: (Double(n.asleepMin) / 60 * 10).rounded() / 10,
                isLastNight: n.date == lastNight.date)
        }
        let weekMeanMin = week.isEmpty ? lastNight.asleepMin
            : Int((Double(week.map(\.asleepMin).reduce(0, +)) / Double(week.count)).rounded())
        let prevMeanMin: Int? = prev.isEmpty ? nil
            : Int((Double(prev.map(\.asleepMin).reduce(0, +)) / Double(prev.count)).rounded())

        // Honest source line: the source behind the most nights (ties by name).
        let source = Dictionary(grouping: allNights.compactMap(\.source), by: { $0 })
            .max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }?.key

        return SleepWeekDetail(
            asleepMin: lastNight.asleepMin,
            deepMin: lastNight.deepMin,
            coreMin: lastNight.coreMin,
            remMin: lastNight.remMin,
            awakeMin: lastNight.awakeMin,
            nights: nights,
            weekMeanMin: weekMeanMin,
            prevWeekMeanMin: prevMeanMin,
            source: source,
            shape: nightShape(of: lastNight),
            bedtime: bedtime(week: week, prev: prev),
            night: lastNight,
            week: SleepNightBuilder.weekRange(nights: allNights, now: now, calendar: cal),
            month: SleepNightBuilder.longRange(nights: allNights, now: now, dayCount: 30, calendar: cal),
            sixMonths: SleepNightBuilder.longRange(nights: allNights, now: now, dayCount: 182, calendar: cal))
    }

    // MARK: - Intra-night shape (nil unless the source kept wall-clock times)

    /// Chart stage scale: 0 awake · 1 REM · 2 core · 3 deep.
    private static func chartStage(_ stage: SleepStage) -> Int {
        switch stage {
        case .awake:  return 0
        case .rem:    return 1
        case .deep:   return 3
        default:      return 2      // core + unspecified
        }
    }

    /// Last night drawn on a 0…1 axis — FROM THE ONE MODEL: the segments are
    /// `night.segments`, the sounding figures are the night's OWN stage tiles
    /// (`deepMin`/`remMin`/`coreMin`), so a chart label can never disagree with
    /// a tile. Returns nil — deliberately, rather than guessing — when the
    /// night is untimed, has too few segments to be an anatomy, or is
    /// degenerate.
    static func nightShape(of night: SleepNight) -> SleepNightShape? {
        guard let segs = night.segments, segs.count >= 3,
              let lo = segs.first?.start,
              let hi = segs.map(\.end).max() else { return nil }
        let span = hi.timeIntervalSince(lo)
        guard span > 3600 else { return nil }

        func t(_ d: Date) -> Double { min(1, max(0, d.timeIntervalSince(lo) / span)) }
        func dur(_ s: SleepNight.Segment) -> TimeInterval { s.end.timeIntervalSince(s.start) }
        let segments = segs.map {
            SleepNightShape.Segment(stage: chartStage($0.stage),
                                    t0: t($0.start), t1: t($0.end))
        }

        // Soundings: the tile figures themselves, printed over each stage's
        // longest stretch — the figure IS the tile, the position is just where
        // there is room to print it.
        var soundings: [SleepNightShape.Sounding] = []
        for (stage, minutes) in [(3, night.deepMin), (1, night.remMin), (2, night.coreMin)] {
            guard minutes > 0,
                  let longest = segs.filter({ chartStage($0.stage) == stage })
                      .max(by: { dur($0) < dur($1) }) else { continue }
            soundings.append(.init(stage: stage,
                                   t: (t(longest.start) + t(longest.end)) / 2,
                                   minutes: minutes))
        }

        // The one wake-up worth annotating: the longest, and only from 5 min.
        var wake: SleepNightShape.Wake? = nil
        if let longest = segs.filter({ $0.stage == .awake && $0.minutes >= 5 })
            .max(by: { dur($0) < dur($1) }) {
            wake = .init(t: (t(longest.start) + t(longest.end)) / 2,
                         clock: clock(longest.start),
                         minutes: longest.minutes)
        }

        return SleepNightShape(segments: segments, soundings: soundings, wake: wake,
                               startClock: clock(lo), endClock: clock(hi))
    }

    /// 24-hour wall clock, "23:04". Fixed format (EN copy, mono digits).
    static func clock(_ d: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: - Bedtime vs the citizen's OWN usual

    /// Minutes since 18:00 — the anchor that lets bedtimes either side of
    /// midnight be averaged without the wrap turning 23:50 and 00:10 into noon.
    private static func sinceEvening(_ d: Date) -> Int {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return (((c.hour ?? 0) * 60 + (c.minute ?? 0)) - 18 * 60 + 1440) % 1440
    }

    private static func clockFromEvening(_ minutes: Int) -> String {
        let m = ((minutes + 18 * 60) % 1440 + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// Bedtime consistency against the citizen's OWN mean bedtime this week.
    /// nil below 3 timed nights — a "usual" drawn from one or two nights would
    /// be a claim the data can't carry. The night's bedtime = when the citizen
    /// actually fell asleep (`SleepNight.fellAsleep`), not when they went to bed.
    static func bedtime(week: [SleepNight], prev: [SleepNight]) -> SleepBedtimeWeek? {
        func bedtimes(_ nights: [SleepNight]) -> [Int] {
            nights.compactMap(\.fellAsleep).map(sinceEvening)
        }
        let thisWeek = bedtimes(week)
        guard thisWeek.count >= 3 else { return nil }
        let mean = thisWeek.reduce(0, +) / thisWeek.count
        let near = thisWeek.filter { abs($0 - mean) <= 30 }.count
        let last = bedtimes(prev)
        let prevMean = last.count >= 3 ? last.reduce(0, +) / last.count : nil
        return SleepBedtimeWeek(thisWeekClock: clockFromEvening(mean),
                                prevWeekClock: prevMean.map(clockFromEvening),
                                thisWeekMinutes: mean,
                                prevWeekMinutes: prevMean,
                                nightsNearUsual: near,
                                nightCount: thisWeek.count)
    }

    // MARK: - Transparent decomposed sleep score (anti-score-opacity)

    /// The three visible fractions of the sleep score — the SAME stance as the
    /// evening day score (FR-TOD-05): no model, no opacity, the legend shows the
    /// exact arithmetic. REST is last night vs an 8 h reference (the accepted
    /// FR-TOD-05 divisor); DEPTH is the deep+REM share of the night vs a stated
    /// 35% reference; RHYTHM is last night vs the user's OWN week mean (within
    /// ±2 h). nil unless stage detail exists AND ≥4 nights this week — a partial
    /// score would be an opaque one.
    public struct Score: Sendable, Equatable {
        public let rest: Double      // 0…50
        public let depth: Double     // 0…30
        public let rhythm: Double    // 0…20
        public var total: Int { Int((rest + depth + rhythm).rounded()) }
    }

    public static func score(of d: SleepWeekDetail) -> Score? {
        guard d.hasStageDetail, d.nights.count >= 4, d.asleepMin > 0 else { return nil }
        let night = Double(d.asleepMin) / 60
        let rest = min(night / 8.0, 1) * 50
        let depthShare = Double(d.deepMin + d.remMin) / Double(d.asleepMin)
        let depth = min(depthShare / 0.35, 1) * 30
        let mean = Double(d.weekMeanMin) / 60
        let rhythm = max(0, 1 - abs(night - mean) / 2.0) * 20
        return Score(rest: rest, depth: depth, rhythm: rhythm)
    }
}
