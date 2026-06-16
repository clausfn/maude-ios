// PhoneWatchSync.swift — iOS SIDE of the phone→watch descriptive glance.
// Lives in the Liviqa iOS target's synchronized folder, so it compiles into the
// app automatically (no manual "add to target" step). Pushes a DESCRIPTIVE
// snapshot to the watch via WatchConnectivity application-context (latest-state,
// low-frequency).
//
// Only the user's own numbers + an observational/affirming line travel — never a
// score, verdict, prediction, advice, or `provenance` (non-MDSW, same line as the
// phone). `AppState.syncWatchGlance()` (below) builds the payload from live Home
// state and calls `push` on every health refresh.
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

final class PhoneWatchSync: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSync()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Push the latest descriptive snapshot. Safe to call often; only the most
    /// recent context is delivered to the watch.
    func push(stateLine: String, signals: [[String: Any]]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let ctx: [String: Any] = ["stateLine": stateLine, "signals": signals]
        try? session.updateApplicationContext(ctx)
    }

    // MARK: WCSessionDelegate
    func session(_ s: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {}
    #if os(iOS)
    func sessionDidBecomeInactive(_ s: WCSession) {}
    func sessionDidDeactivate(_ s: WCSession) { WCSession.default.activate() }
    #endif
}
#endif

// MARK: - AppState → Apple Watch glance

extension AppState {

    /// Mirror the Home glance to a paired Apple Watch: the same affirming line the
    /// phone shows plus the four DESCRIPTIVE pillars (Glucose · Sleep · Recovery ·
    /// Heart), each the user's own value carrying the locked two-state dot. The
    /// values, defaults, and clay logic are taken verbatim from the phone Home
    /// (`TodayView.signalRow`) so the wrist never disagrees with the screen.
    ///
    /// Non-MDSW: only numbers + an observational line — never a score, verdict,
    /// prediction, advice, or `provenance`. No-op until a watch is paired and the
    /// session is active; called on every health refresh.
    @MainActor
    func syncWatchGlance() {
        let s = todaySignals   // nil ⇒ fall back to the same defaults the Home chips use
        // `trend` mirrors the phone Home chip sparklines (last-7, oldest→today) so the
        // wrist tap-through shows the same series. Empty ⇒ no sparkline (no fabrication).
        let signals: [[String: Any]] = [
            ["label": "Glucose",  "icon": "drop.fill",         "value": s?.inRange ?? "61%",  "clay": s?.inRangeIsClay ?? true, "trend": s?.inRangeWeek ?? []],
            ["label": "Sleep",    "icon": "moon.fill",         "value": s?.sleep   ?? "6h52", "clay": false,                   "trend": s?.sleepWeek   ?? []],
            ["label": "Recovery", "icon": "waveform.path.ecg", "value": s?.hrv     ?? "48",   "clay": false,                   "trend": s?.hrvWeek     ?? []],
            ["label": "Heart",    "icon": "heart.fill",        "value": s?.rhr     ?? "58",   "clay": false,                   "trend": s?.rhrWeek     ?? []],
        ]
        // Same approved affirming copy as the phone Home (TodayView.affirmHeadline).
        let stateLine = String(localized: "You're having a steady week.")
        #if canImport(WatchConnectivity)
        PhoneWatchSync.shared.push(stateLine: stateLine, signals: signals)
        #endif
    }
}
