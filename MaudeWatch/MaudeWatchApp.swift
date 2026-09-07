// MaudeWatchApp.swift — watchOS app entry point (single-target Watch App).
// Hosts the WatchConnectivity receiver and feeds its live snapshot to the glance
// (falls back to the demo snapshot until the phone pushes one).
import SwiftUI

@main
struct MaudeWatchApp: App {
    @StateObject private var sync = WatchSessionReceiver()

    var body: some Scene {
        WindowGroup {
            WatchHomeView(snapshot: sync.snapshot)
        }
    }
}
