// TodaySignalsDeriver.swift — the four Home "signals vs your normal" chips,
// derived on device from local HealthSamples so the Home screen shows YOUR data
// (not the demo seeds) the moment Apple Health is connected. Pure Foundation
// (NFR-PORT-01). nil ⇒ not enough real data yet → Home falls back to seeds.
import Foundation

public struct TodaySignals: Sendable, Equatable {
    public var sleep: String      // "6h52"
    public var inRange: String    // "61%"
    public var hrv: String        // "48"
    public var rhr: String        // "58"
    public var inRangeIsClay: Bool

    public init(sleep: String, inRange: String, hrv: String, rhr: String, inRangeIsClay: Bool) {
        self.sleep = sleep; self.inRange = inRange; self.hrv = hrv; self.rhr = rhr
        self.inRangeIsClay = inRangeIsClay
    }
}

public enum TodaySignalsDeriver {

    public static func derive(from s: HealthSamples,
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0) -> TodaySignals? {
        // Need at least one real signal, else stay on the demo seeds.
        guard !s.hrv.isEmpty || !s.sleep.isEmpty || !s.glucose.isEmpty || !s.restingHR.isEmpty
        else { return nil }

        let stats = PassportStatsDeriver.derive(from: s, tirLowMmol: tirLowMmol, tirHighMmol: tirHighMmol)

        let sleep = stats.avgSleepHours > 0 ? formatSleep(stats.avgSleepHours) : "—"
        let tir = stats.glucoseTimeInRange
        let inRange = s.glucose.isEmpty ? "—" : "\(tir)%"
        let hrv = latest(s.hrv).map { String(Int($0.rounded())) } ?? "—"
        let rhr = latest(s.restingHR).map { String(Int($0.rounded())) } ?? "—"

        return TodaySignals(
            sleep: sleep, inRange: inRange, hrv: hrv, rhr: rhr,
            inRangeIsClay: !s.glucose.isEmpty && tir < 70)
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
}
