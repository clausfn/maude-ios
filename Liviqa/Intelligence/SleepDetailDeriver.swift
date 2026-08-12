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
    /// Dominant source name among the window's segments (honest source line).
    public let source: String?
    /// Last night as a shape — nil when the source kept no intra-night times.
    public let shape: SleepNightShape?
    /// Bedtime vs the citizen's own usual — nil below 3 timed nights.
    public let bedtime: SleepBedtimeWeek?

    public init(asleepMin: Int, deepMin: Int, coreMin: Int, remMin: Int,
                awakeMin: Int = 0,
                nights: [Night], weekMeanMin: Int, prevWeekMeanMin: Int?,
                source: String?, shape: SleepNightShape? = nil,
                bedtime: SleepBedtimeWeek? = nil) {
        self.asleepMin = asleepMin; self.deepMin = deepMin
        self.coreMin = coreMin; self.remMin = remMin; self.awakeMin = awakeMin
        self.nights = nights; self.weekMeanMin = weekMeanMin
        self.prevWeekMeanMin = prevWeekMeanMin; self.source = source
        self.shape = shape; self.bedtime = bedtime
    }
}

public nonisolated enum SleepDetailDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    private static let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    public static func derive(from s: HealthSamples, now: Date = Date()) -> SleepWeekDetail? {
        let segs = s.sleep.filter { asleep.contains($0.stage) && $0.hours > 0 }
        guard !segs.isEmpty else { return nil }

        var byDay: [Date: [SleepReading]] = [:]
        for seg in segs { byDay[cal.startOfDay(for: seg.date), default: []].append(seg) }
        guard let lastDay = byDay.keys.max() else { return nil }

        // Awake segments live outside `segs` (they are not sleep) but belong to
        // the night's anatomy — kept per night bucket for the shape + tile.
        var awakeByDay: [Date: [SleepReading]] = [:]
        for seg in s.sleep where seg.stage == .awake && seg.hours > 0 {
            awakeByDay[cal.startOfDay(for: seg.date), default: []].append(seg)
        }

        // Per-bucket union (two-source de-dup), then sum — each minute once.
        func stageHours(_ night: [SleepReading], _ stages: Set<SleepStage>) -> Double {
            SleepReading.mergedAsleepHours(night, asleep: stages)
        }
        func nightHours(_ night: [SleepReading]) -> Double {
            stageHours(night, [.deep]) + stageHours(night, [.rem])
                + stageHours(night, [.core, .asleepUnspecified])
        }

        let lastNight = byDay[lastDay] ?? []
        let deepH = stageHours(lastNight, [.deep])
        let remH  = stageHours(lastNight, [.rem])
        let coreH = stageHours(lastNight, [.core, .asleepUnspecified])

        let today = cal.startOfDay(for: now)
        let symbols = cal.veryShortWeekdaySymbols

        func nightsIn(_ fromOffset: Int, _ toOffset: Int) -> [(day: Date, hours: Double)] {
            (fromOffset...toOffset).compactMap { off in
                guard let d = cal.date(byAdding: .day, value: off, to: today),
                      let segs = byDay[d] else { return nil }
                return (d, nightHours(segs))
            }
        }

        let week = nightsIn(-6, 0)
        let prev = nightsIn(-13, -7)
        let nights = week.map { n in
            SleepWeekDetail.Night(
                label: symbols[(cal.component(.weekday, from: n.day) - 1) % symbols.count],
                hours: (n.hours * 10).rounded() / 10,
                isLastNight: n.day == lastDay)
        }
        let weekMean = week.isEmpty ? nightHours(lastNight)
            : week.map(\.hours).reduce(0, +) / Double(week.count)
        let prevMean: Double? = prev.isEmpty ? nil
            : prev.map(\.hours).reduce(0, +) / Double(prev.count)

        let source = Dictionary(grouping: segs, by: \.source)
            .max { $0.value.count < $1.value.count }?.key

        // — Intra-night surfaces (only where the source kept real times) —
        let lastAwake = awakeByDay[lastDay] ?? []
        let shape = nightShape(asleep: lastNight, awake: lastAwake)
        // The AWAKE tile counts only wake-ups INSIDE the night, so it can never
        // include time awake before falling asleep or after getting up.
        let awakeMin = shape == nil ? 0
            : Int((insideNight(lastAwake, asleep: lastNight) * 60).rounded())
        let bedtimeWeek = bedtime(byDay: byDay, week: week.map(\.day), prev: prev.map(\.day))

        return SleepWeekDetail(
            asleepMin: Int(((deepH + remH + coreH) * 60).rounded()),
            deepMin: Int((deepH * 60).rounded()),
            coreMin: Int((coreH * 60).rounded()),
            remMin: Int((remH * 60).rounded()),
            awakeMin: awakeMin,
            nights: nights,
            weekMeanMin: Int((weekMean * 60).rounded()),
            prevWeekMeanMin: prevMean.map { Int(($0 * 60).rounded()) },
            source: source,
            shape: shape,
            bedtime: bedtimeWeek)
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

    /// Awake hours that fall between falling asleep and getting up.
    private static func insideNight(_ awake: [SleepReading],
                                    asleep night: [SleepReading]) -> Double {
        guard let lo = night.map(\.intervalStart).min(),
              let hi = night.map(\.intervalEnd).max() else { return 0 }
        return awake
            .filter { $0.intervalStart >= lo && $0.intervalEnd <= hi }
            .reduce(0) { $0 + $1.hours }
    }

    /// Last night drawn on a 0…1 axis. Returns nil — deliberately, rather than
    /// guessing — when the segments carry no start times, when there are too
    /// few of them to be an anatomy, or when the span is degenerate.
    static func nightShape(asleep night: [SleepReading],
                           awake: [SleepReading]) -> SleepNightShape? {
        let timed = (night + awake).filter { $0.start != nil && $0.hours > 0 }
            .sorted { $0.intervalStart < $1.intervalStart }
        guard timed.count >= 3,
              night.allSatisfy({ $0.start != nil }),
              let lo = timed.first?.intervalStart,
              let hi = timed.map(\.intervalEnd).max() else { return nil }
        let span = hi.timeIntervalSince(lo)
        guard span > 3600 else { return nil }

        func t(_ d: Date) -> Double { min(1, max(0, d.timeIntervalSince(lo) / span)) }
        let segments = timed.map {
            SleepNightShape.Segment(stage: chartStage($0.stage),
                                    t0: t($0.intervalStart), t1: t($0.intervalEnd))
        }

        // Soundings: each stage's TOTAL, printed over that stage's longest
        // stretch — the figure is the real total, the position is just where
        // there is room to print it.
        var soundings: [SleepNightShape.Sounding] = []
        for stage in [3, 1, 2] {                     // deep, REM, core
            let group = timed.filter { chartStage($0.stage) == stage }
            guard let longest = group.max(by: { $0.hours < $1.hours }) else { continue }
            let minutes = Int((group.reduce(0) { $0 + $1.hours } * 60).rounded())
            guard minutes > 0 else { continue }
            soundings.append(.init(stage: stage,
                                   t: (t(longest.intervalStart) + t(longest.intervalEnd)) / 2,
                                   minutes: minutes))
        }

        // The one wake-up worth annotating: the longest, and only from 5 min.
        var wake: SleepNightShape.Wake? = nil
        if let longest = awake.filter({ $0.start != nil && $0.hours * 60 >= 5 })
            .max(by: { $0.hours < $1.hours }),
           longest.intervalStart >= lo, longest.intervalEnd <= hi {
            wake = .init(t: (t(longest.intervalStart) + t(longest.intervalEnd)) / 2,
                         clock: clock(longest.intervalStart),
                         minutes: Int((longest.hours * 60).rounded()))
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

    /// The night's bedtime = when the citizen actually fell asleep (the first
    /// asleep segment), not when they went to bed.
    private static func bedtimeOf(_ night: [SleepReading]) -> Date? {
        night.compactMap(\.start).min()
    }

    /// Bedtime consistency against the citizen's OWN mean bedtime this week.
    /// nil below 3 timed nights — a "usual" drawn from one or two nights would
    /// be a claim the data can't carry.
    static func bedtime(byDay: [Date: [SleepReading]],
                        week: [Date], prev: [Date]) -> SleepBedtimeWeek? {
        func bedtimes(_ days: [Date]) -> [Int] {
            days.compactMap { byDay[$0].flatMap(bedtimeOf) }.map(sinceEvening)
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
