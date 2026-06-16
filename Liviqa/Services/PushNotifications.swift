// PushNotifications.swift — APNs device-token plumbing + foreground/tap handling.
// SwiftUI has no native hook for didRegisterForRemoteNotifications, so we use a
// minimal UIApplicationDelegate (wired via @UIApplicationDelegateAdaptor in
// LiviqaApp) that posts the hex token; AppState forwards it to the backend
// (POST /me/push-token) so the reminder ladder can push to this device.
//
// It is also the UNUserNotificationCenter delegate so notifications DISPLAY in the
// foreground and a tapped *research invitation* opens the consent flow. Research
// invites are pushed from DfG Professional ("Contact Cohort"); for the local demo
// they arrive via `xcrun simctl push booted dev.liviqa.app <payload>` with
// userInfo {"type":"research"} (no APNs cloud / Partisia needed).
//
// NOTE: live remote delivery also needs the Push Notifications capability +
// aps-environment entitlement and an APNs-provisioned backend. Until then,
// registration fails gracefully (didFailToRegister) — no crash — and the local
// simctl push path still works for the demo.
import UIKit
import UserNotifications

extension Notification.Name {
    static let liviqaPushToken = Notification.Name("LiviqaPushToken")
    /// Posted when a research-invitation notification is received/tapped → AppState opens the flow.
    static let liviqaOpenResearch = Notification.Name("LiviqaOpenResearch")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Receive willPresent (foreground banners) and didReceive (taps).
        UNUserNotificationCenter.current().delegate = self
        return true
    }

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

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Show the banner even when the app is in the foreground (so the research
    /// invitation is visible during the demo without backgrounding the app).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// Tapping a research invitation routes into the consent flow (UC-RSCH).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let isResearch = (info["type"] as? String) == "research"
            || (info["kind"] as? String) == "research_invite"
            || (info["category"] as? String) == "research"
        if isResearch {
            NotificationCenter.default.post(name: .liviqaOpenResearch, object: nil)
        }
        completionHandler()
    }
}
