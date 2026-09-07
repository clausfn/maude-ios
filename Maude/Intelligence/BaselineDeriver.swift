// BaselineDeriver.swift — the per-domain learned "your usual" baselines that the
// restyled MetricBaselineView shows (UC-08: "Your normal, never a percentile").
// Pure Foundation (NFR-PORT-01).
//
// HOW IT'S LEARNED (published arithmetic, also printed on the screen): each
// domain's band is the mean ±1σ of the user's OWN readings over the local
// window (30 days steady state, 90 on first run). ≥5 days of data are required
// before a band is claimed — below that the screen keeps its honest demo/empty
// framing. No population chart, no percentile, no clinical reference range.
import Foundation

public nonisolated struct DomainBaseline: Sendable, Equatable {
    public enum Domain: String, Sendable, CaseIterable {
        case sleep      // nightly asleep hours
        case hrv        // ms
        case rhr        // bpm
    }

    public let domain: Domain
    public let latest: Double
    public let band: ClosedRange<Double>
    public let unit: String                 // "h", "ms", "bpm"
    /// Last-14-days context series (days with data), oldest → latest.
    public let series: [Double]
    /// Days of own data the band was learned from.
    public let learnedFromDays: Int

    public var latestIsTypical: Bool { band.contains(latest) }

    public init(domain: Domain, latest: Double, band: ClosedRange<Double>,
                unit: String, series: [Double], learnedFromDays: Int) {
        self.domain = domain; self.latest = latest; self.band = band
        self.unit = unit; self.series = series; self.learnedFromDays = learnedFromDays
    }
}

public nonisolated struct BaselineBook: Sendable, Equatable {
    public let entries: [DomainBaseline]
    public init(entries: [DomainBaseline]) { self.entries = entries }
    public func entry(_ d: DomainBaseline.Domain) -> DomainBaseline? {
        entries.first { $0.domain == d }
    }
}

public nonisolated enum BaselineDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    private static let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]

    public static func derive(from s: HealthSamples, now: Date = Date()) -> BaselineBook? {
        let today = cal.startOfDay(for: now)

        func fromDaily(_ metrics: [DailyMetric], _ domain: DomainBaseline.Domain,
                       unit: String) -> DomainBaseline? {
            let sorted = metrics.sorted { $0.date < $1.date }
            let values = sorted.map(\.value)
            guard let band = HeartDetailDeriver.band(values),
                  let latest = values.last else { return nil }
            let recent = sorted.filter {
                abs(cal.dateComponents([.day], from: cal.startOfDay(for: $0.date),
                                       to: today).day ?? 99) <= 13
            }.map(\.value)
            return DomainBaseline(
                domain: domain, latest: (latest * 10).rounded() / 10, band: band,
                unit: unit, series: recent.count >= 2 ? recent : [],
                learnedFromDays: Set(sorted.map { cal.startOfDay(for: $0.date) }).count)
        }

        // Sleep: nightly merged asleep hours per night.
        func sleepBaseline() -> DomainBaseline? {
            let segs = s.sleep.filter { asleep.contains($0.stage) && $0.hours > 0 }
            guard !segs.isEmpty else { return nil }
            var byDay: [Date: [SleepReading]] = [:]
            for seg in segs { byDay[cal.startOfDay(for: seg.date), default: []].append(seg) }
            let nights = byDay.keys.sorted().map { day -> (Date, Double) in
                let night = byDay[day] ?? []
                let h = SleepReading.mergedAsleepHours(night, asleep: [.deep])
                    + SleepReading.mergedAsleepHours(night, asleep: [.rem])
                    + SleepReading.mergedAsleepHours(night, asleep: [.core, .asleepUnspecified])
                return (day, (h * 10).rounded() / 10)
            }
            let values = nights.map(\.1)
            guard let band = HeartDetailDeriver.band(values),
                  let latest = values.last else { return nil }
            let recent = nights.filter {
                abs(cal.dateComponents([.day], from: $0.0, to: today).day ?? 99) <= 13
            }.map(\.1)
            return DomainBaseline(
                domain: .sleep, latest: latest, band: band, unit: "h",
                series: recent.count >= 2 ? recent : [],
                learnedFromDays: nights.count)
        }

        let entries = [
            sleepBaseline(),
            fromDaily(s.hrv, .hrv, unit: "ms"),
            fromDaily(s.restingHR, .rhr, unit: "bpm"),
        ].compactMap { $0 }

        return entries.isEmpty ? nil : BaselineBook(entries: entries)
    }
}
