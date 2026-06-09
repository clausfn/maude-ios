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
}

/// The whole glance. Demo seeds for now — wire to HealthKit-on-watch /
/// WatchConnectivity from the phone next (kept descriptive at the source).
struct WatchSnapshot {
    var stateLine: String           // affirming, descriptive ("A steady day")
    var signals: [WatchSignal]

    static let demo = WatchSnapshot(
        stateLine: "A steady day",
        signals: [
            WatchSignal(label: "Glucose",  icon: "drop.fill",          value: "68%",   clay: false),
            WatchSignal(label: "Sleep",    icon: "moon.fill",          value: "7h02",  clay: false),
            WatchSignal(label: "Recovery", icon: "waveform.path.ecg",  value: "42 ms", clay: true),
            WatchSignal(label: "Heart",    icon: "heart.fill",         value: "55",    clay: false),
        ])
}
