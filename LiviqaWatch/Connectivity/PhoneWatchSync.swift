// PhoneWatchSync.swift — iOS SIDE. Add to the **Liviqa (iOS)** target after the
// watch target exists. Pushes a DESCRIPTIVE snapshot to the watch via
// WatchConnectivity application-context (latest-state, low-frequency).
//
// Only the user's own numbers + an observational/affirming line travel — never
// scores, verdicts, prediction, or advice (non-MDSW, same line as the app).
//
// Usage from the app (e.g. after refreshFromHealth / when Home appears):
//   PhoneWatchSync.shared.push(
//       stateLine: "A steady day",
//       signals: [
//         ["label":"Glucose","icon":"drop.fill","value":"68%","clay":false],
//         ["label":"Sleep","icon":"moon.fill","value":"7h02","clay":false],
//         ["label":"Recovery","icon":"waveform.path.ecg","value":"42 ms","clay":true],
//         ["label":"Heart","icon":"heart.fill","value":"55","clay":false],
//       ])
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
