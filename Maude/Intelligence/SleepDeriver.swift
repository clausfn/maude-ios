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
    private static let cal = Calendar(identifier: .gregorian)

    public static func derive(from s: HealthSamples) -> SleepSummary? {
        // ONE arithmetic for every surface: the Home chip reads the SAME
        // `SleepNight` models the Sleep detail screen renders
        // (`SleepNightBuilder` re-applies FR-SLP-10 — idempotent over
        // `arbitrated()` — so no caller that skips arbitration can
        // double-count an overlapping second source or grow "last night" by
        // an afternoon nap). The chip and the detail screen cannot disagree:
        // they read the same objects.
        let nights = SleepNightBuilder.nights(from: s, calendar: cal)
        guard let lastNight = nights.last else { return nil }

        let byDay = Dictionary(uniqueKeysWithValues: nights.map { ($0.date, $0) })
        let today = cal.startOfDay(for: Date())
        let week: [Double] = (0..<7).reversed().compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: today),
                  let night = byDay[d] else { return nil }
            return (Double(night.asleepMin) / 60 * 10).rounded() / 10
        }

        return SleepSummary(
            deepMin: lastNight.deepMin,
            coreMin: lastNight.coreMin,
            remMin:  lastNight.remMin,
            asleepMinutes: lastNight.asleepMin,
            nightlyHoursWeek: week.count >= 2 ? week : [])
    }
}
