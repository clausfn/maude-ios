// PushNotifications.swift — APNs device-token plumbing.
// SwiftUI has no native hook for didRegisterForRemoteNotifications, so we use a
// minimal UIApplicationDelegate (wired via @UIApplicationDelegateAdaptor in
// LiviqaApp) that posts the hex token; AppState forwards it to the backend
// (POST /me/push-token) so the reminder ladder can push to this device.
//
// NOTE: actual delivery also needs (1) the Push Notifications capability +
// aps-environment entitlement on the App ID, and (2) APNs provisioned on the
// backend. Until then, registration fails gracefully (didFailToRegister) — no crash.
import UIKit
import UserNotifications

extension Notification.Name {
    static let liviqaPushToken = Notification.Name("LiviqaPushToken")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .liviqaPushToken, object: hex)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected before the Push capability/APNs are in place — non-fatal.
        print("[push] APNs registration unavailable: \(error.localizedDescription)")
    }
}
