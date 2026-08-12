// EditionNotifications.swift — FR-NOT-01/02 edition-model notification prefs +
// the two REAL local micro-loops (morning ping · evening close) · A7.2 Area ⑧.
//
// PREFS (persisted, @AppStorage-compatible UserDefaults keys): the five designed
// "Calm by default" rows — morning edition / earned attention / evening wind-down
// / care messages / study & consent activity (default OFF). NotificationSettingsView
// binds these; `resync()` turns the two edition prefs into actual scheduling.
//
// WHAT IS REAL vs PREFERENCE-ONLY (honesty ledger):
//   • Morning edition + evening wind-down → REAL on-device local notifications
//     (UNCalendarNotificationTrigger, daily). Content is a FIXED template below —
//     built on this phone, carries NO health data, checked against the FR-NDG-06
//     guard in tests. Tapping deep-links to Today (the edition surface).
//   • Earned attention → preference stored; NO alert is scheduled. The nudge
//     engine runs at app refresh (foreground) — there is no background picker
//     yet, so scheduling one would be theatre. FR-NDG-06 cadence ("at most one a
//     day") is enforced by the engine when the loop lands (RTM T-NOT-02 open).
//   • Care messages / study & consent activity → preference stored; delivery
//     rides remote push (not APNs-provisioned yet). The study pref IS live in one
//     real place: PushNotifications gates the foreground banner of research/study
//     payloads on it.
//
// FR-NDG-06 (designated): the templates are static allow-listed strings — no
// derived text can reach a notification from here BY CONSTRUCTION.
import Foundation
import UserNotifications

enum EditionNotifications {

    // MARK: - Preference keys (UserDefaults / @AppStorage)

    enum Pref {
        static let morning = "notif.morningEdition"       // default ON
        static let earned  = "notif.earnedAttention"      // default ON (engine-gated)
        static let evening = "notif.eveningWindDown"      // default ON
        static let care    = "notif.careMessages"         // default ON
        static let study   = "notif.studyActivity"        // default OFF (designed)
    }

    /// Designed defaults ("Calm by default" ladder): everything on except
    /// study & consent activity. `bool(forKey:)` returns false when unset, so
    /// the ON-default rows must read through this helper.
    static func isOn(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: key) == nil { return key != Pref.study }
        return defaults.bool(forKey: key)
    }

    // MARK: - Allow-listed templates (FR-NDG-06 — static, no health data)

    /// (identifier, title, body, hour, minute) for the two real local loops.
    /// Times are fixed and calm by design: the morning note lands with the
    /// morning edition, the closing note after 21:00 (design: "after 21:00").
    static let morningTemplate = (id: "liviqa.edition.morning",
                                  title: String(localized: "Your morning edition"),
                                  body: String(localized: "Today's edition is ready when you are."),
                                  hour: 7, minute: 30)
    static let eveningTemplate = (id: "liviqa.edition.evening",
                                  title: String(localized: "Evening wind-down"),
                                  body: String(localized: "A short closing note on your day is ready."),
                                  hour: 21, minute: 30)

    /// Every string that can ever reach a notification from this file — the
    /// allow-list the FR-NDG-06 guard test walks.
    static var allTemplateStrings: [String] {
        [morningTemplate.title, morningTemplate.body,
         eveningTemplate.title, eveningTemplate.body]
    }

    // MARK: - Request building (pure — unit-testable without UNUserNotificationCenter)

    /// The pending requests the current prefs ask for. Pure function of the two
    /// booleans so tests can assert identifiers/triggers without the center.
    static func requests(morning: Bool, evening: Bool) -> [UNNotificationRequest] {
        var out: [UNNotificationRequest] = []
        for (on, t) in [(morning, morningTemplate), (evening, eveningTemplate)] where on {
            let content = UNMutableNotificationContent()
            content.title = t.title
            content.body = t.body
            content.sound = nil                          // calm: silent by design
            content.userInfo = ["type": "edition"]       // tap → Today (edition surface)
            var comps = DateComponents()
            comps.hour = t.hour; comps.minute = t.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            out.append(UNNotificationRequest(identifier: t.id, content: content, trigger: trigger))
        }
        return out
    }

    // MARK: - Scheduling

    /// Re-schedule the edition loops from the persisted prefs. Idempotent: always
    /// removes both pending edition requests first, then adds what's enabled.
    /// Quietly does nothing when notification permission isn't granted (the
    /// Settings screen requests permission when a toggle is switched on).
    static func resync(defaults: UserDefaults = .standard) {
        let center = UNUserNotificationCenter.current()
        let ids = [morningTemplate.id, eveningTemplate.id]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let wanted = requests(morning: isOn(Pref.morning, defaults: defaults),
                              evening: isOn(Pref.evening, defaults: defaults))
        guard !wanted.isEmpty else { return }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
               || settings.authorizationStatus == .provisional else { return }
            for req in wanted { center.add(req) }
        }
    }
}
