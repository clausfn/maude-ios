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
// It is ALSO where the FR-NOT-02 background wake is registered: BGTaskScheduler
// requires its launch handler to exist before the app finishes launching, and
// this delegate is the only pre-scene hook a SwiftUI app has. The wake itself
// lives in BackgroundRefresh.swift.
//
// NOTE: live remote delivery also needs the Push Notifications capability +
// aps-environment entitlement and an APNs-provisioned backend. Until then,
// registration fails gracefully (didFailToRegister) — no crash — and the local
// simctl push path still works for the demo.
import UIKit
import UserNotifications

extension Notification.Name {
    static let liviqaPushToken = Notification.Name("LiviqaPushToken")
    /// Posted when a research-invitation notification is TAPPED → AppState opens the flow.
    static let liviqaOpenResearch = Notification.Name("LiviqaOpenResearch")
    /// Posted when a research invitation is DELIVERED in the foreground → bell badge + Care card.
    static let liviqaResearchReceived = Notification.Name("LiviqaResearchReceived")
    /// Posted when a local edition note (morning/evening — FR-NOT-02) is TAPPED
    /// → MainTabView fronts the Home tab (the edition surface).
    static let liviqaOpenEdition = Notification.Name("LiviqaOpenEdition")
    /// Posted when an earned-attention alert (FR-NOT-02) is TAPPED. `object` is
    /// the nudge headline the alert was about, so AppState can open THAT card's
    /// evidence view — the shown work, which is the point of the alert. Absent
    /// object ⇒ open the edition (Home).
    static let liviqaOpenAttention = Notification.Name("LiviqaOpenAttention")
}

private func isResearchPayload(_ info: [AnyHashable: Any]) -> Bool {
    (info["type"] as? String) == "research"
        || (info["kind"] as? String) == "research_invite"
        || (info["category"] as? String) == "research"
}

private func isEditionPayload(_ info: [AnyHashable: Any]) -> Bool {
    (info["type"] as? String) == "edition"
}

private func isAttentionPayload(_ info: [AnyHashable: Any]) -> Bool {
    (info["type"] as? String) == "attention"
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Receive willPresent (foreground banners) and didReceive (taps).
        UNUserNotificationCenter.current().delegate = self
        // FR-NOT-02 earned-attention loop: the BGTaskScheduler launch handler
        // MUST be registered before launch finishes, or iOS throws when the task
        // fires. Scheduling the first wake is safe here too (it is a no-op when
        // the preference is off, or when the platform refuses).
        BackgroundRefresh.register()
        BackgroundRefresh.schedule()
        // Re-arm the next opportunistic wake every time the app leaves the
        // foreground (iOS holds one pending request per identifier, so this just
        // refreshes the earliest-begin date). This is a NotificationCenter
        // observer rather than `applicationDidEnterBackground` on purpose: this
        // is a scene-based SwiftUI app, where that delegate method is never
        // called — the UIApplication notification still is.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { BackgroundRefresh.schedule() }
            }
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
        // Delivered while foreground → badge the bell + drop a Care card, and show the banner.
        if isResearchPayload(notification.request.content.userInfo) {
            NotificationCenter.default.post(name: .liviqaResearchReceived, object: nil)
            // FR-NOT-01: the "Study & consent activity" pref (default OFF) gates
            // the foreground BANNER of study payloads — the in-app surfaces
            // (bell badge, Care card) still update above, so nothing consent-
            // relevant is silently lost.
            if !EditionNotifications.isOn(EditionNotifications.Pref.study) {
                completionHandler([.list])
                return
            }
        }
        completionHandler([.banner, .sound, .list])
    }

    /// Tapping routes to the surface the note is ABOUT (FR-NOT-02 §3): a
    /// research invitation opens the consent flow (UC-RSCH); a morning/evening
    /// edition note fronts Home (Home IS the edition); an earned-attention alert
    /// opens the evidence view of the very nudge that earned it.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if isResearchPayload(info) {
            NotificationCenter.default.post(name: .liviqaOpenResearch, object: nil)
        } else if isAttentionPayload(info) {
            // `nudge` is the headline the alert was built from — unrendered
            // routing data, never shown in the banner.
            NotificationCenter.default.post(name: .liviqaOpenAttention,
                                            object: info["nudge"] as? String)
        } else if isEditionPayload(info) {
            NotificationCenter.default.post(name: .liviqaOpenEdition, object: nil)
        }
        completionHandler()
    }
}
