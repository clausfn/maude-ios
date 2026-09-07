import Testing
import Foundation
import UserNotifications
@testable import Maude

// FR-NOT-01/02 — edition-model notification preferences + the local micro-loop
// templates (T-NOT-01). Three properties:
//   1. Defaults match the designed "Calm by default" ladder (study OFF).
//   2. Prefs persist (UserDefaults round-trip — the old toggles were throwaway).
//   3. FR-NDG-06 (DESIGNATED, never skipped): every string that can reach a
//      notification from EditionNotifications passes the forbidden-construction
//      guard, and the request builder only ever emits the fixed templates.
struct NotificationPrefTests {

    private func freshDefaults() -> UserDefaults {
        let name = "notif-pref-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // MARK: 1 · Designed defaults

    @Test func defaultsMatchTheCalmLadder() {
        let d = freshDefaults()
        #expect(EditionNotifications.isOn(EditionNotifications.Pref.morning, defaults: d))
        #expect(EditionNotifications.isOn(EditionNotifications.Pref.earned, defaults: d))
        #expect(EditionNotifications.isOn(EditionNotifications.Pref.evening, defaults: d))
        #expect(EditionNotifications.isOn(EditionNotifications.Pref.care, defaults: d))
        // The one designed default-OFF row: study & consent activity.
        #expect(!EditionNotifications.isOn(EditionNotifications.Pref.study, defaults: d))
    }

    // MARK: 2 · Persistence round-trip

    @Test func prefsPersistThroughUserDefaults() {
        let d = freshDefaults()
        d.set(false, forKey: EditionNotifications.Pref.morning)
        d.set(true, forKey: EditionNotifications.Pref.study)
        #expect(!EditionNotifications.isOn(EditionNotifications.Pref.morning, defaults: d))
        #expect(EditionNotifications.isOn(EditionNotifications.Pref.study, defaults: d))
        // Flip back — the stored value wins over the default either way.
        d.set(true, forKey: EditionNotifications.Pref.morning)
        #expect(EditionNotifications.isOn(EditionNotifications.Pref.morning, defaults: d))
    }

    // MARK: 3 · FR-NDG-06 guard on the notification allow-list (designated)

    @Test func templateStringsPassTheNudgeGuard() {
        for text in EditionNotifications.allTemplateStrings {
            #expect(NudgeGuard.check(text) == nil, "forbidden construction in: \(text)")
        }
    }

    // MARK: 4 · Request building is pure and pref-shaped

    @Test func requestBuilderHonoursPrefs() {
        #expect(EditionNotifications.requests(morning: false, evening: false).isEmpty)

        let both = EditionNotifications.requests(morning: true, evening: true)
        #expect(both.map(\.identifier) == [EditionNotifications.morningTemplate.id,
                                           EditionNotifications.eveningTemplate.id])

        let eveningOnly = EditionNotifications.requests(morning: false, evening: true)
        #expect(eveningOnly.map(\.identifier) == [EditionNotifications.eveningTemplate.id])
    }

    @Test func requestsAreCalmDailyEditionPings() throws {
        let requests = EditionNotifications.requests(morning: true, evening: true)
        for req in requests {
            // Content is exactly the allow-listed template text (no derived data).
            #expect(EditionNotifications.allTemplateStrings.contains(req.content.title))
            #expect(EditionNotifications.allTemplateStrings.contains(req.content.body))
            // Calm: silent, and deep-linking to the edition surface.
            #expect(req.content.sound == nil)
            #expect(req.content.userInfo["type"] as? String == "edition")
            // Daily repeating calendar trigger at the designed times.
            let trigger = try #require(req.trigger as? UNCalendarNotificationTrigger)
            #expect(trigger.repeats)
        }
        let morning = try #require(requests.first)
        let morningTrigger = try #require(morning.trigger as? UNCalendarNotificationTrigger)
        #expect(morningTrigger.dateComponents.hour == EditionNotifications.morningTemplate.hour)
        let evening = try #require(requests.last)
        let eveningTrigger = try #require(evening.trigger as? UNCalendarNotificationTrigger)
        // The closing note lands after 21:00, as the settings copy promises.
        #expect((eveningTrigger.dateComponents.hour ?? 0) >= 21)
    }
}
