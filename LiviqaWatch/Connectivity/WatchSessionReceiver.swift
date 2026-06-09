// WatchSessionReceiver.swift — WATCH SIDE. Add to the **Liviqa Watch App** target.
// Receives the descriptive snapshot from the phone (application context) and
// publishes it for the UI. Falls back to the demo snapshot until the phone pushes.
import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
final class WatchSessionReceiver: NSObject, ObservableObject {
    @Published var snapshot: WatchSnapshot = .demo

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    fileprivate func apply(_ ctx: [String: Any]) {
        guard let line = ctx["stateLine"] as? String,
              let raw = ctx["signals"] as? [[String: Any]] else { return }
        let signals = raw.compactMap { d -> WatchSignal? in
            guard let l = d["label"] as? String,
                  let i = d["icon"] as? String,
                  let v = d["value"] as? String else { return nil }
            return WatchSignal(label: l, icon: i, value: v, clay: (d["clay"] as? Bool) ?? false)
        }
        guard !signals.isEmpty else { return }
        snapshot = WatchSnapshot(stateLine: line, signals: signals)

        // Mirror the glucose in-range value to the shared App Group + refresh the
        // face complication (descriptive fact only).
        if let glucose = signals.first(where: { $0.label.lowercased() == "glucose" })?.value {
            UserDefaults(suiteName: "group.dev.liviqa.app")?.set(glucose, forKey: "watch.inRange")
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}

extension WatchSessionReceiver: WCSessionDelegate {
    nonisolated func session(_ s: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {}

    nonisolated func session(_ s: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        Task { @MainActor in self.apply(ctx) }
    }
}
#else
@MainActor
final class WatchSessionReceiver: ObservableObject {
    @Published var snapshot: WatchSnapshot = .demo
}
#endif
