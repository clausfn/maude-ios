// SleepDeriver.swift — last-night sleep-stage breakdown + nightly trend.
//
// Descriptive-only (non-MDSW): reports the user's OWN stage minutes and nightly
// totals from on-device HealthKit sleep. No score, no "good/bad" verdict, no
// recommended duration. Pure Foundation (Android-portable).
import Foundation

public nonisolated struct SleepSummary: Sendable, Equatable {
    public let deepMin: Int
    public let coreMin: Int     // "Light" in the UI (core + unspecified)
    public let remMin: Int
    public let asleepMinutes: Int
    public let nightlyHoursWeek: [Double]   // last 7 nights' total asleep hours

    /// True when real stage structure exists (deep or REM present) — otherwise the
    /// source only gave an undifferentiated total and the stage bar is not shown.
    public var hasStageDetail: Bool { deepMin > 0 || remMin > 0 }
    public var asleepHoursText: String {
        let h = asleepMinutes / 60, m = asleepMinutes % 60
        return "\(h)h \(String(format: "%02d", m))m"
    }
}

public nonisolated enum SleepDeriver {
    private static let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
    private static let cal = Calendar(identifier: .gregorian)

    public static func derive(from s: HealthSamples) -> SleepSummary? {
        let segs = s.sleep.filter { asleep.contains($0.stage) }
        guard !segs.isEmpty else { return nil }

        var byDay: [Date: [SleepReading]] = [:]
        for seg in segs { byDay[cal.startOfDay(for: seg.date), default: []].append(seg) }
        guard let lastDay = byDay.keys.max(), let night = byDay[lastDay] else { return nil }

        // Union overlapping same-stage segments (two-source de-dup) within each
        // exclusive bucket, then sum. Deep/REM/Core partition a single source's
        // night, so the summed merged buckets count each wall-clock minute once.
        func hours(_ stages: Set<SleepStage>) -> Double {
            SleepReading.mergedAsleepHours(night, asleep: stages)
        }
        let deepH = hours([.deep])
        let remH  = hours([.rem])
        let coreH = hours([.core, .asleepUnspecified])
        let asleepH = deepH + remH + coreH

        func nightHours(_ segs: [SleepReading]) -> Double {
            SleepReading.mergedAsleepHours(segs, asleep: [.deep])
                + SleepReading.mergedAsleepHours(segs, asleep: [.rem])
                + SleepReading.mergedAsleepHours(segs, asleep: [.core, .asleepUnspecified])
        }

        let today = cal.startOfDay(for: Date())
        let week: [Double] = (0..<7).reversed().compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: today),
                  let segs = byDay[d] else { return nil }
            return (nightHours(segs) * 10).rounded() / 10
        }

        return SleepSummary(
            deepMin: Int((deepH * 60).rounded()),
            coreMin: Int((coreH * 60).rounded()),
            remMin:  Int((remH * 60).rounded()),
            asleepMinutes: Int((asleepH * 60).rounded()),
            nightlyHoursWeek: week.count >= 2 ? week : [])
    }
}
