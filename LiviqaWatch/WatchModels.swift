// WatchModels.swift — the small, descriptive snapshot the watch shows.
// DESCRIPTIVE ONLY (non-MDSW): the watch reports the user's own numbers + an
// affirming/observational line. No scores, verdicts, prediction, or advice.
import SwiftUI

/// One wellness pillar row on the wrist.
struct WatchSignal: Identifiable {
    let id = UUID()
    let label: String       // "Glucose", "Sleep", "Recovery", "Heart"
    let icon: String        // SF Symbol
    let value: String       // "68%", "7h02", "42 ms", "55 bpm"
    let clay: Bool          // false = in range (moss), true = worth noticing (clay)
    /// Last-7-day descriptive series (oldest→today), mirrored from the phone Home
    /// chips. Powers the tap-through sparkline. Empty ⇒ no trend yet (no sparkline).
    let trend: [Double]

    init(label: String, icon: String, value: String, clay: Bool, trend: [Double] = []) {
        self.label = label; self.icon = icon; self.value = value
        self.clay = clay; self.trend = trend
    }
}

/// The whole glance. Demo seeds for now — wire to HealthKit-on-watch /
/// WatchConnectivity from the phone next (kept descriptive at the source).
struct WatchSnapshot {
    var stateLine: String           // affirming, descriptive ("A steady day")
    var signals: [WatchSignal]

    static let demo = WatchSnapshot(
        stateLine: "A steady day",
        signals: [
            WatchSignal(label: "Glucose",  icon: "drop.fill",          value: "68%",   clay: false, trend: [62, 65, 61, 70, 66, 64, 68]),
            WatchSignal(label: "Sleep",    icon: "moon.fill",          value: "7h02",  clay: false, trend: [6.5, 7.1, 6.8, 7.4, 6.9, 7.2, 7.0]),
            WatchSignal(label: "Recovery", icon: "waveform.path.ecg",  value: "42 ms", clay: true,  trend: [48, 45, 44, 46, 41, 43, 42]),
            WatchSignal(label: "Heart",    icon: "heart.fill",         value: "55",    clay: false, trend: [57, 56, 58, 55, 56, 54, 55]),
        ])
}
