// SleepNight.swift — ONE night model to rule every sleep surface.
//
// THE PRIME RULE (sleep visualisation wave 2026-08, after the same-screen
// contradiction CN photographed: tiles saying "Core 7h21m" while chart labels
// said "16h20m"): every figure on any sleep surface renders from ONE resolved
// object per night. Hero, stage tiles, hypnogram, chart labels, week columns,
// month/6M series — all read the SAME `SleepNight`, so a contradiction between
// two figures of one night is structurally impossible, and
// `assertInternalConsistency()` lets a test prove it stays that way.
//
// Construction invariants (why the figures cannot disagree):
//   • `asleepMin == deepMin + coreMin + remMin` — the total IS the sum of the
//     tiles, not a separately rounded figure.
//   • the per-stage minutes are the interval UNION of that stage's segments in
//     `segments` — the chart's blocks and the tiles' figures are the same list.
//   • `inBedMin` derives from `InBedSpan`s (a separate TYPE) or the night's
//     own envelope — it can never be added into `asleepMin` because no asleep
//     arithmetic accepts an `InBedSpan`.
//   • naps live in `naps`, split off by the resolver — never inside the night.
//
// Data honesty: everything optional is nil when the source did not record it —
// never reconstructed, never defaulted. Gaps are gaps (DaySeries discipline).
// NUMBERS ONLY: no sentences here (FR-NDG-06 templates live with the view).
// Pure Foundation — no SwiftData/SwiftUI/HealthKit (NFR-PORT-01).
import Foundation

// MARK: - The one-truth night

public nonisolated struct SleepNight: Sendable, Equatable {

    /// One resolved segment of the night, wall-clock, awake included.
    /// Present only when the chosen source retained intra-night times.
    public struct Segment: Sendable, Equatable {
        public let stage: SleepStage
        public let start: Date
        public let end: Date
        public init(stage: SleepStage, start: Date, end: Date) {
            self.stage = stage; self.start = start; self.end = end
        }
        public var minutes: Int { Int((end.timeIntervalSince(start) / 60).rounded()) }
    }

    /// A nap episode the resolver separated from the main night (FR-SLP-10).
    public struct Nap: Sendable, Equatable {
        /// Wall-clock start, when the source retained it.
        public let start: Date?
        public let asleepMin: Int
        public init(start: Date?, asleepMin: Int) {
            self.start = start; self.asleepMin = asleepMin
        }
    }

    /// The night bucket — the day the night ENDS on (`SleepNightRule.nightDay`).
    public let date: Date
    /// The resolver's chosen source for this night (honest source line).
    public let source: String?
    /// Names of same-night sources the resolver did NOT choose (disclosure).
    public let excludedSources: [String]
    public var excludedSourceCount: Int { excludedSources.count }

    // — Time in bed (never counts toward asleep; separate type upstream) —
    /// Whole-night in-bed span start/end. From the chosen source's in-bed
    /// union when it wrote one; otherwise the night's own timed envelope;
    /// nil when the night is untimed and no in-bed span exists.
    public let inBedStart: Date?
    public let inBedEnd: Date?
    /// TIME IN BED minutes (union of in-bed spans, or the envelope). nil when
    /// unknowable — never defaulted to the asleep total.
    public let inBedMin: Int?
    /// True when `inBedMin` came from source-written in-bed rows; false when
    /// it is the asleep envelope fallback.
    public let inBedIsFromSource: Bool

    // — Asleep (TIME ASLEEP is a separate figure from TIME IN BED) —
    /// == deepMin + coreMin + remMin, by construction.
    public let asleepMin: Int
    public let deepMin: Int
    /// Core + unspecified ("Core" in UI).
    public let coreMin: Int
    public let remMin: Int
    /// Awake INSIDE the night (between falling asleep and getting up); 0 when
    /// the source recorded no wake-ups or kept no times.
    public let awakeMin: Int

    /// The resolved segment list in time order, awake included — the hypnogram
    /// draws exactly this. nil when the chosen source kept no intra-night
    /// times (the screen falls back to totals; nothing is invented).
    public let segments: [Segment]?
    /// When the citizen actually fell asleep (first asleep segment start).
    public let fellAsleep: Date?
    /// When they woke for the last time (last asleep segment end).
    public let wokeUp: Date?

    /// Nap episodes the resolver split off this bucket — outside every total.
    public let naps: [Nap]

    // — Sleeping respiratory rate (descriptive only; the watch measures
    //   respiratory rate DURING sleep, so the daily figure for the morning the
    //   night ends on is the night's signal — coverage audit 2026-08-18) —
    /// That morning's respiratory-rate daily mean (breaths/min), if recorded.
    public let respiratoryRateMean: Double?
    /// The citizen's OWN mean over the other days in the derivation window
    /// (≥ 5 other days required — a "baseline" from less would be a claim the
    /// data can't carry). Never a population range.
    public let respiratoryRateBaseline: Double?

    public var hasStageDetail: Bool { deepMin > 0 || remMin > 0 }
    public var isTimed: Bool { segments != nil }

    /// 24-hour wall clocks for the two moments the screen prints.
    public var fellAsleepClock: String? { fellAsleep.map { SleepNight.clock($0) } }
    public var wokeUpClock: String? { wokeUp.map { SleepNight.clock($0) } }

    public init(date: Date, source: String?, excludedSources: [String],
                inBedStart: Date?, inBedEnd: Date?, inBedMin: Int?,
                inBedIsFromSource: Bool,
                asleepMin: Int, deepMin: Int, coreMin: Int, remMin: Int,
                awakeMin: Int, segments: [Segment]?,
                fellAsleep: Date?, wokeUp: Date?, naps: [Nap],
                respiratoryRateMean: Double? = nil,
                respiratoryRateBaseline: Double? = nil) {
        self.date = date; self.source = source; self.excludedSources = excludedSources
        self.inBedStart = inBedStart; self.inBedEnd = inBedEnd
        self.inBedMin = inBedMin; self.inBedIsFromSource = inBedIsFromSource
        self.asleepMin = asleepMin; self.deepMin = deepMin
        self.coreMin = coreMin; self.remMin = remMin; self.awakeMin = awakeMin
        self.segments = segments; self.fellAsleep = fellAsleep; self.wokeUp = wokeUp
        self.naps = naps
        self.respiratoryRateMean = respiratoryRateMean
        self.respiratoryRateBaseline = respiratoryRateBaseline
    }

    /// Fixed-format 24h wall clock ("23:04") — EN copy, mono digits.
    public static func clock(_ d: Date,
                             calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: Internal-consistency proof (used by tests)

    /// Every relation between the figures this object carries, checked. An
    /// empty result means no two figures on any screen rendering this night
    /// can contradict each other. Tolerances are the per-figure rounding of
    /// hours→minutes, nothing more.
    public func assertInternalConsistency() -> [String] {
        var violations: [String] = []

        // 1 — the hero equals the sum of the tiles, exactly.
        if asleepMin != deepMin + coreMin + remMin {
            violations.append("asleepMin \(asleepMin) != deep \(deepMin) + core \(coreMin) + rem \(remMin)")
        }
        if min(asleepMin, deepMin, coreMin, remMin, awakeMin) < 0 {
            violations.append("negative stage minutes")
        }

        if let segments {
            // 2 — the chart's blocks and the tiles agree: the per-stage UNION
            //     of the drawn segments is the tile figure (±1 min rounding).
            func unionMin(_ stages: Set<SleepStage>) -> Int {
                let iv = segments.filter { stages.contains($0.stage) }
                    .map { ($0.start.timeIntervalSinceReferenceDate, $0.end.timeIntervalSinceReferenceDate) }
                    .sorted { $0.0 < $1.0 }
                guard let first = iv.first else { return 0 }
                var total = 0.0, runStart = first.0, runEnd = first.1
                for (s, e) in iv.dropFirst() {
                    if s <= runEnd { runEnd = max(runEnd, e) }
                    else { total += runEnd - runStart; runStart = s; runEnd = e }
                }
                total += runEnd - runStart
                return Int((total / 60).rounded())
            }
            let checks: [(String, Set<SleepStage>, Int)] = [
                ("deep", [.deep], deepMin),
                ("rem", [.rem], remMin),
                ("core", [.core, .asleepUnspecified], coreMin)]
            for (name, stages, tile) in checks {
                let drawn = unionMin(stages)
                if abs(drawn - tile) > 1 {
                    violations.append("\(name) drawn \(drawn)m != tile \(tile)m")
                }
            }
            // 3 — segments are ordered and non-degenerate.
            for (a, b) in zip(segments, segments.dropFirst()) where a.start > b.start {
                violations.append("segments out of time order")
            }
            for s in segments where s.end <= s.start {
                violations.append("degenerate segment at \(s.start)")
            }
            // 4 — the printed clocks are the drawn edges.
            let asleepSegs = segments.filter { $0.stage != .awake }
            if let fell = fellAsleep, let first = asleepSegs.first?.start, fell != first {
                violations.append("fellAsleep != first asleep segment start")
            }
            if let woke = wokeUp, let last = asleepSegs.map(\.end).max(), woke != last {
                violations.append("wokeUp != last asleep segment end")
            }
        }

        // 5 — fell asleep before waking; in-bed brackets are ordered.
        if let f = fellAsleep, let w = wokeUp, f >= w {
            violations.append("fellAsleep >= wokeUp")
        }
        if let s = inBedStart, let e = inBedEnd, s >= e {
            violations.append("inBedStart >= inBedEnd")
        }
        // 6 — the envelope fallback can never be shorter than the sleep it
        //     wraps (source-written in-bed is reported as-is, even when odd).
        if !inBedIsFromSource, let bed = inBedMin, bed + 1 < asleepMin {
            violations.append("envelope inBedMin \(bed) < asleepMin \(asleepMin)")
        }
        // 7 — naps are outside the night's span.
        if let f = fellAsleep, let w = wokeUp {
            for nap in naps {
                if let ns = nap.start, ns >= f, ns < w {
                    violations.append("nap at \(ns) inside the night span")
                }
            }
        }
        return violations
    }
}

// MARK: - The 22:00 → 14:00 clock axis (week columns positioned by clock time)

/// The week chart's y-axis: wall-clock 22:00 the evening BEFORE the night's
/// day, down to 14:00 ON the night's day (16 clock hours). Positions are
/// computed from wall-clock components, so a block drawn at the 06:00 gridline
/// really started at 06:00 — including across a DST transition, where absolute
/// seconds and the wall clock disagree by an hour.
public nonisolated enum SleepClockAxis {
    /// Axis origin, hours-of-day on the evening before the night's day.
    public static let startHour: Double = 22
    /// Axis length in clock hours (22:00 → 14:00 next day).
    public static let spanHours: Double = 16

    /// `instant`'s position on night `night`'s axis as a fraction of the span.
    /// Deliberately UNCLAMPED: a bedtime before 22:00 returns < 0 and a wake
    /// after 14:00 returns > 1 — the caller clamps AND FLAGS (an edge marker),
    /// never silently drags a block onto the axis.
    public static func fraction(_ instant: Date, night: Date,
                                calendar: Calendar = Calendar(identifier: .gregorian)) -> Double {
        let originDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: night)) ?? night
        let instantDay = calendar.startOfDay(for: instant)
        let dayDelta = calendar.dateComponents([.day], from: originDay, to: instantDay).day ?? 0
        let c = calendar.dateComponents([.hour, .minute, .second], from: instant)
        let wallHours = Double(dayDelta) * 24
            + Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
        return (wallHours - startHour) / spanHours
    }
}

/// One night as a clock-positioned stacked column for the week view: the
/// column runs from bedtime to wake on the 22:00→14:00 axis, its bands are the
/// night's resolved stage segments. Only timed nights produce a column.
public nonisolated struct SleepClockColumn: Sendable, Equatable {

    public struct Band: Sendable, Equatable {
        public let stage: SleepStage
        /// Clamped to 0…1 on the axis (the flags say when clamping happened).
        public let y0: Double
        public let y1: Double
        public init(stage: SleepStage, y0: Double, y1: Double) {
            self.stage = stage; self.y0 = y0; self.y1 = y1
        }
    }

    /// The night bucket this column belongs to (x-position on the day axis).
    public let date: Date
    /// RAW axis fractions for the column's ends — may fall outside 0…1;
    /// `clippedTop`/`clippedBottom` say when the drawn column was cut.
    public let bedFraction: Double
    public let wakeFraction: Double
    /// True when the real bedtime lies before 22:00 (column cut at the top).
    public let clippedTop: Bool
    /// True when the real wake lies after 14:00 (column cut at the bottom).
    public let clippedBottom: Bool
    /// Stage bands in time order, clamped to the axis, awake included.
    public let bands: [Band]

    public init(date: Date, bedFraction: Double, wakeFraction: Double,
                clippedTop: Bool, clippedBottom: Bool, bands: [Band]) {
        self.date = date; self.bedFraction = bedFraction; self.wakeFraction = wakeFraction
        self.clippedTop = clippedTop; self.clippedBottom = clippedBottom
        self.bands = bands
    }

    /// Build the column for one night; nil when the night carries no times.
    public static func column(for night: SleepNight,
                              calendar: Calendar = Calendar(identifier: .gregorian)) -> SleepClockColumn? {
        guard let segments = night.segments, !segments.isEmpty else { return nil }
        // The column spans the same bracket the TIME IN BED figure uses.
        let colStart = night.inBedStart ?? segments.first!.start
        let colEnd = night.inBedEnd ?? segments.map(\.end).max()!
        func f(_ d: Date) -> Double { SleepClockAxis.fraction(d, night: night.date, calendar: calendar) }
        let bed = f(colStart), wake = f(colEnd)
        let bands: [Band] = segments.compactMap { seg in
            let y0 = f(seg.start), y1 = f(seg.end)
            guard y1 > 0, y0 < 1 else { return nil }     // fully off-axis
            return Band(stage: seg.stage, y0: max(0, y0), y1: min(1, y1))
        }
        return SleepClockColumn(date: night.date, bedFraction: bed, wakeFraction: wake,
                                clippedTop: bed < 0, clippedBottom: wake > 1,
                                bands: bands)
    }
}

// MARK: - Ranges

/// The W range: a 7-day axis, the nights that HAVE data, and their
/// clock-positioned columns. Gaps stay visible (a day without a night simply
/// has no column); the mean states its true denominator.
public nonisolated struct SleepWeekRange: Sendable, Equatable {
    /// The full 7-day axis (every day, ascending) — gaps render as gaps.
    public let days: [Date]
    /// Only the nights WITH data, ascending by date.
    public let nights: [SleepNight]
    /// Clock-positioned columns — one per TIMED night (untimed nights appear
    /// in `nights` but produce no column; nothing is invented).
    public let columns: [SleepClockColumn]
    /// Mean asleep minutes across `nights` — nil when there are none.
    public let meanAsleepMin: Int?
    /// Mean time-in-bed minutes across the nights that have one; nil when none.
    public let meanInBedMin: Int?
    /// THE TRUE DENOMINATOR: how many of the 7 days actually have a night.
    public var nightsWithData: Int { nights.count }

    public init(days: [Date], nights: [SleepNight], columns: [SleepClockColumn],
                meanAsleepMin: Int?, meanInBedMin: Int?) {
        self.days = days; self.nights = nights; self.columns = columns
        self.meanAsleepMin = meanAsleepMin; self.meanInBedMin = meanInBedMin
    }

    public static let empty = SleepWeekRange(days: [], nights: [], columns: [],
                                             meanAsleepMin: nil, meanInBedMin: nil)
}

/// The M / 6M ranges: per-night duration on a day axis (DaySeries discipline —
/// a day without a night is a nil slot, never a zero), plus weekly aggregates
/// whose stage mix exists only where EVERY contributing night carries real
/// stage detail. Every average states its true denominator.
public nonisolated struct SleepLongRange: Sendable, Equatable {

    public struct WeekAggregate: Sendable, Equatable {
        public let weekStart: Date
        /// THE TRUE DENOMINATOR for this week's figures.
        public let nightCount: Int
        public let meanAsleepMin: Int
        /// Mean per-night stage minutes — non-nil ONLY when every night in
        /// this week has stage detail (a mix blending staged and unstaged
        /// nights would misstate both).
        public let meanDeepMin: Int?
        public let meanCoreMin: Int?
        public let meanRemMin: Int?
        public init(weekStart: Date, nightCount: Int, meanAsleepMin: Int,
                    meanDeepMin: Int?, meanCoreMin: Int?, meanRemMin: Int?) {
            self.weekStart = weekStart; self.nightCount = nightCount
            self.meanAsleepMin = meanAsleepMin
            self.meanDeepMin = meanDeepMin; self.meanCoreMin = meanCoreMin
            self.meanRemMin = meanRemMin
        }
    }

    /// One slot per day of the window: that night's asleep HOURS, or nil.
    public let slots: [DaySlot]
    /// Mean asleep minutes across nights with data — nil when there are none.
    public let meanAsleepMin: Int?
    /// THE TRUE DENOMINATOR behind `meanAsleepMin`.
    public let nightsWithData: Int
    /// Weekly aggregates, ascending — only weeks that have at least one night.
    public let weeks: [WeekAggregate]

    public init(slots: [DaySlot], meanAsleepMin: Int?, nightsWithData: Int,
                weeks: [WeekAggregate]) {
        self.slots = slots; self.meanAsleepMin = meanAsleepMin
        self.nightsWithData = nightsWithData; self.weeks = weeks
    }

    public static let empty = SleepLongRange(slots: [], meanAsleepMin: nil,
                                             nightsWithData: 0, weeks: [])
}

// MARK: - Builder (raw or arbitrated samples → [SleepNight])

/// Builds the night models. Works identically on RAW samples (the resolver
/// runs here — idempotent) and on `arbitrated()` output (already resolved;
/// the naps/exclusions the arbitration carried in their own streams are
/// merged back in) — test-pinned: both paths yield the same nights.
public nonisolated enum SleepNightBuilder {

    static let asleepStages: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    /// Every night in `samples`, ascending by date.
    public static func nights(from s: HealthSamples,
                              calendar: Calendar = Calendar(identifier: .gregorian)) -> [SleepNight] {
        let resolutions = SleepNightResolver.resolutions(s.sleep, calendar: calendar)
        guard !resolutions.isEmpty else { return [] }

        // Carried metadata (survives arbitration in its own streams).
        let carriedNaps = Dictionary(grouping: s.sleepNaps) { calendar.startOfDay(for: $0.date) }
        var carriedExclusions: [Date: Set<String>] = [:]
        for e in s.sleepExclusions {
            carriedExclusions[calendar.startOfDay(for: e.night), default: []].formUnion(e.excludedSources)
        }
        let inBedByNight = Dictionary(grouping: s.sleepInBed) { calendar.startOfDay(for: $0.date) }

        // Sleeping respiratory rate: daily means by day + the OWN baseline.
        let respByDay: [Date: Double] = Dictionary(
            s.heartExtras.filter { $0.kind == .respiratoryRate }
                .map { (calendar.startOfDay(for: $0.date), $0.value) },
            uniquingKeysWith: { a, _ in a })

        return resolutions.compactMap { r in
            night(bucket: r.night, resolution: r.resolution,
                  carriedNaps: carriedNaps[r.night] ?? [],
                  carriedExclusions: carriedExclusions[r.night] ?? [],
                  inBed: inBedByNight[r.night] ?? [],
                  respByDay: respByDay,
                  calendar: calendar)
        }
    }

    private static func night(bucket: Date,
                              resolution: SleepNightResolver.Resolution,
                              carriedNaps: [SleepReading],
                              carriedExclusions: Set<String>,
                              inBed: [InBedSpan],
                              respByDay: [Date: Double],
                              calendar: Calendar) -> SleepNight? {
        let nightSegs = resolution.night.filter { $0.hours > 0 }
        let asleepSegs = nightSegs.filter { asleepStages.contains($0.stage) }
        guard !asleepSegs.isEmpty else { return nil }

        // Stage minutes: per-stage interval union (each wall-clock minute once).
        func stageMin(_ stages: Set<SleepStage>) -> Int {
            Int((SleepReading.mergedAsleepHours(nightSegs, asleep: stages) * 60).rounded())
        }
        let deep = stageMin([.deep])
        let rem = stageMin([.rem])
        let core = stageMin([.core, .asleepUnspecified])

        // Timed anatomy — only when the chosen source kept every start.
        let timed = nightSegs.allSatisfy { $0.start != nil }
        let sorted = nightSegs.sorted { $0.intervalStart < $1.intervalStart }
        let segments: [SleepNight.Segment]? = timed
            ? sorted.map { .init(stage: $0.stage, start: $0.intervalStart, end: $0.intervalEnd) }
            : nil
        let fellAsleep = timed ? asleepSegs.compactMap(\.start).min() : nil
        let wokeUp = timed ? asleepSegs.map(\.intervalEnd).max() : nil

        // Awake INSIDE the night (between falling asleep and getting up):
        // union of the awake segments clipped to the asleep envelope.
        var awake = 0
        if timed, let lo = fellAsleep, let hi = wokeUp {
            let inside = nightSegs.filter {
                $0.stage == .awake && $0.intervalStart >= lo && $0.intervalEnd <= hi
            }
            awake = Int((SleepReading.mergedAsleepHours(
                inside.map { SleepReading(date: $0.date, stage: .asleepUnspecified,
                                          hours: $0.hours, start: $0.start,
                                          source: $0.source, tier: $0.tier,
                                          provenance: $0.provenance) },
                asleep: [.asleepUnspecified]) * 60).rounded())
        }

        // TIME IN BED: the chosen source's in-bed union — or the envelope of
        // the whole resolved night when that source wrote no in-bed rows.
        var inBedStart: Date? = nil, inBedEnd: Date? = nil
        var inBedMin: Int? = nil, inBedFromSource = false
        let sourceInBed = inBed.filter { $0.source == resolution.chosenSource && $0.hours > 0 }
        if !sourceInBed.isEmpty {
            inBedFromSource = true
            let iv = sourceInBed
                .map { ($0.intervalStart.timeIntervalSinceReferenceDate,
                        $0.intervalEnd.timeIntervalSinceReferenceDate) }
                .sorted { $0.0 < $1.0 }
            var total = 0.0, runStart = iv[0].0, runEnd = iv[0].1
            for (s, e) in iv.dropFirst() {
                if s <= runEnd { runEnd = max(runEnd, e) }
                else { total += runEnd - runStart; runStart = s; runEnd = e }
            }
            total += runEnd - runStart
            inBedMin = Int((total / 60).rounded())
            if sourceInBed.allSatisfy({ $0.start != nil }) {
                inBedStart = sourceInBed.map(\.intervalStart).min()
                inBedEnd = sourceInBed.map(\.intervalEnd).max()
            }
        } else if timed, let lo = sorted.first?.intervalStart,
                  let hi = sorted.map(\.intervalEnd).max() {
            inBedStart = lo; inBedEnd = hi
            inBedMin = Int((hi.timeIntervalSince(lo) / 60).rounded())
        }

        // Naps: what the resolver split off here + what arbitration carried —
        // deduplicated, then grouped into episodes.
        var seen = Set<String>()
        let napSegs = (resolution.excludedOtherEpisodes + carriedNaps).filter {
            seen.insert("\($0.source)|\($0.stage.rawValue)|\($0.intervalStart.timeIntervalSinceReferenceDate)|\($0.hours)").inserted
        }
        let naps: [SleepNight.Nap] = SleepNightResolver.napEpisodes(napSegs).compactMap { episode in
            let mins = Int((SleepNightResolver.asleepHours(episode) * 60).rounded())
            guard mins > 0 else { return nil }
            return SleepNight.Nap(start: episode.compactMap(\.start).min(), asleepMin: mins)
        }.sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }

        // Exclusion disclosure: resolver findings + carried, chosen source out.
        var excluded = carriedExclusions
        excluded.formUnion(resolution.excludedOtherSources.map(\.source))
        excluded.remove(resolution.chosenSource ?? "")

        // Sleeping respiratory rate vs the citizen's OWN other days.
        let resp = respByDay[bucket]
        let others = respByDay.filter { $0.key != bucket }.map(\.value)
        let baseline: Double? = others.count >= 5
            ? others.reduce(0, +) / Double(others.count) : nil

        return SleepNight(
            date: bucket,
            source: resolution.chosenSource,
            excludedSources: excluded.sorted(),
            inBedStart: inBedStart, inBedEnd: inBedEnd,
            inBedMin: inBedMin, inBedIsFromSource: inBedFromSource,
            asleepMin: deep + core + rem,
            deepMin: deep, coreMin: core, remMin: rem, awakeMin: awake,
            segments: segments, fellAsleep: fellAsleep, wokeUp: wokeUp,
            naps: naps,
            respiratoryRateMean: resp,
            respiratoryRateBaseline: resp != nil ? baseline : nil)
    }

    // MARK: Ranges

    /// The 7-day week range ending on `now`'s day.
    public static func weekRange(nights: [SleepNight], now: Date,
                                 calendar: Calendar = Calendar(identifier: .gregorian)) -> SleepWeekRange {
        let days = DaySeries.days(endingOn: now, count: 7, calendar: calendar)
        let window = Set(days)
        let inWindow = nights.filter { window.contains($0.date) }.sorted { $0.date < $1.date }
        let columns = inWindow.compactMap { SleepClockColumn.column(for: $0, calendar: calendar) }
        let bedMins = inWindow.compactMap(\.inBedMin)
        return SleepWeekRange(
            days: days, nights: inWindow, columns: columns,
            meanAsleepMin: inWindow.isEmpty ? nil
                : inWindow.map(\.asleepMin).reduce(0, +) / inWindow.count,
            meanInBedMin: bedMins.isEmpty ? nil : bedMins.reduce(0, +) / bedMins.count)
    }

    /// A duration-per-night day series over the last `dayCount` days.
    public static func longRange(nights: [SleepNight], now: Date, dayCount: Int,
                                 calendar: Calendar = Calendar(identifier: .gregorian)) -> SleepLongRange {
        let days = DaySeries.days(endingOn: now, count: dayCount, calendar: calendar)
        let window = Set(days)
        let inWindow = nights.filter { window.contains($0.date) }.sorted { $0.date < $1.date }
        let byDay = Dictionary(uniqueKeysWithValues: inWindow.map { ($0.date, $0) })
        let slots = days.map { DaySlot(date: $0, value: byDay[$0].map { Double($0.asleepMin) / 60 }) }

        var byWeek: [Date: [SleepNight]] = [:]
        for n in inWindow {
            guard let ws = calendar.dateInterval(of: .weekOfYear, for: n.date)?.start else { continue }
            byWeek[ws, default: []].append(n)
        }
        let weeks = byWeek.keys.sorted().map { ws -> SleepLongRange.WeekAggregate in
            let ns = byWeek[ws]!
            let allStaged = ns.allSatisfy(\.hasStageDetail)
            func mean(_ f: (SleepNight) -> Int) -> Int { ns.map(f).reduce(0, +) / ns.count }
            return SleepLongRange.WeekAggregate(
                weekStart: ws, nightCount: ns.count,
                meanAsleepMin: mean(\.asleepMin),
                meanDeepMin: allStaged ? mean(\.deepMin) : nil,
                meanCoreMin: allStaged ? mean(\.coreMin) : nil,
                meanRemMin: allStaged ? mean(\.remMin) : nil)
        }
        return SleepLongRange(
            slots: slots,
            meanAsleepMin: inWindow.isEmpty ? nil
                : inWindow.map(\.asleepMin).reduce(0, +) / inWindow.count,
            nightsWithData: inWindow.count,
            weeks: weeks)
    }
}
