// SleepDetailDeriver.swift — everything the A7.2 Sleep metric-detail screen shows,
// derived on device from local `HealthSamples`. Pure Foundation — no SwiftData /
// SwiftUI / HealthKit (NFR-PORT-01) — unit-testable and Android-portable.
//
// NUMBERS ONLY: no sentences here. The view maps these figures onto fixed
// descriptive templates ("You slept like your usual self." …) — nothing
// generated, nothing prescriptive (FR-NDG-06 rail; templates guard-tested).
//
// INGESTION HONESTY (checked against HealthKitService.readSleep): sleep segments
// are stored as (startOfDay, stage, hours) — the segment's wall-clock START TIME
// and the awake/inBed stages are NOT retained. Therefore this deriver cannot
// produce a night timeline (the søkort depth chart), a wake-up annotation, an
// AWAKE total, or bedtime consistency. Those elements render only from the
// clearly-demo design seeds; the real screen shows the honest reduced anatomy
// (stage totals + proportions + nightly week + duration-vs-last-week).
//
// nil ⇒ no asleep segments in the window → demo seeds (demo mode) or an honest
// empty state (real-data mode).
import Foundation

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

    public init(asleepMin: Int, deepMin: Int, coreMin: Int, remMin: Int,
                nights: [Night], weekMeanMin: Int, prevWeekMeanMin: Int?,
                source: String?) {
        self.asleepMin = asleepMin; self.deepMin = deepMin
        self.coreMin = coreMin; self.remMin = remMin
        self.nights = nights; self.weekMeanMin = weekMeanMin
        self.prevWeekMeanMin = prevWeekMeanMin; self.source = source
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

        return SleepWeekDetail(
            asleepMin: Int(((deepH + remH + coreH) * 60).rounded()),
            deepMin: Int((deepH * 60).rounded()),
            coreMin: Int((coreH * 60).rounded()),
            remMin: Int((remH * 60).rounded()),
            nights: nights,
            weekMeanMin: Int((weekMean * 60).rounded()),
            prevWeekMeanMin: prevMean.map { Int(($0 * 60).rounded()) },
            source: source)
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
