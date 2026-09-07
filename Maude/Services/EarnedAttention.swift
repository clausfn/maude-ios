// EarnedAttention.swift — FR-NOT-02 · the third calm micro-loop.
//
// The morning and evening editions are CLOCK loops: they fire because it is
// 07:30 or 21:30. This one is the only loop that fires because something in the
// user's own numbers earned it — so it is also the only one that needs a picker,
// a cadence ledger, and a hard content rail.
//
// WHAT THE NOTIFICATION SAYS (the rail, stated once):
//   The delivered text is a FIXED template chosen by the engine nudge's
//   ALLOW-LISTED category (`NudgeCategory`). It carries no number, no reading,
//   no derived sentence — there is no code path from a health value to a
//   notification string here, by construction, exactly as in EditionNotifications.
//   The nudge's own headline travels only in `userInfo`, unrendered, purely so
//   the tap can open that card's evidence view (Maude's answer to score
//   opacity is the shown work on the card, not a verdict in a banner).
//
// WHAT MAY INTERRUPT (deliberately narrow):
//   • `.bandStatus` and `.behaviouralLever` at engine priority ≥ 60. That is the
//     top of the ladder only: "glucose above/below your usual" (75), the
//     workout↔glucose coupling (70), "recovery looks low" (60). "Glucose steady"
//     (55), "short night" (45), "quieter day" (30) and the plain resting-HR echo
//     (20) never interrupt — nothing has changed enough to be worth a buzz.
//   • `.routeToClinician` (AFib, D9) is deliberately EXCLUDED. Apple Watch
//     already notifies for an irregular-rhythm signal at the moment it records
//     one; a second, opportunistically-timed echo hours later would be an alarm
//     Maude cannot time and cannot interpret. The nudge still sits at the top
//     of the edition, where the routing sentence belongs. See qms/RISK.md.
//   • `.verdict` / `.number` never interrupt.
//
// CADENCE: at most ONE per calendar day (FR-NDG-06 restated in the settings
// copy verbatim), and only inside a waking window that does not collide with the
// two edition notes. Both are pure functions below, so T-NOT-02 can prove them.
//
// Pure Foundation + UserNotifications; no SwiftUI, no AppState.
import Foundation
import UserNotifications

enum EarnedAttention {

    // MARK: - Identity + persisted cadence ledger

    /// One identifier ⇒ a newer alert always REPLACES a pending older one; the
    /// user can never accumulate a queue of these.
    static let requestID = "maude.attention.earned"

    /// When the last earned-attention alert was delivered (device-local; the
    /// one piece of state the cadence rule needs).
    static let lastAlertKey = "notif.earned.lastAlertAt"

    static func lastAlertAt(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: lastAlertKey) as? Date
    }

    static func recordAlert(at date: Date, defaults: UserDefaults = .standard) {
        defaults.set(date, forKey: lastAlertKey)
    }

    // MARK: - Gates

    /// Engine priority a nudge must reach before it may interrupt the day.
    static let minimumPriority = 60

    /// Local hours in which an earned alert may be delivered. Starts after the
    /// morning edition note (07:30) has had time to be read, ends before the
    /// evening close (21:30) — the ladder stays time-shaped, and nothing can
    /// arrive at night.
    static let deliveryWindow: Range<Int> = 9..<20

    static func isWithinDeliveryWindow(_ now: Date, calendar: Calendar = .current) -> Bool {
        deliveryWindow.contains(calendar.component(.hour, from: now))
    }

    /// The one-per-day rule, as a function of the ledger alone.
    static func hasAlertedToday(now: Date, lastAlertAt: Date?,
                                calendar: Calendar = .current) -> Bool {
        guard let lastAlertAt else { return false }
        return calendar.isDate(lastAlertAt, inSameDayAs: now)
    }

    // MARK: - Allow-listed templates (FR-NDG-06 — static, no health data)

    /// The complete set of text this loop can ever deliver. One entry per
    /// interrupting category; nothing is interpolated into either field.
    struct Template: Equatable, Sendable {
        let category: NudgeCategory
        let title: String
        let body: String
    }

    static let bandTemplate = Template(
        category: .bandStatus,
        title: String(localized: "One thing sits outside your usual"),
        body: String(localized: "One of your own numbers is away from your usual today. Maude has shown its working in today's edition."))

    static let leverTemplate = Template(
        category: .behaviouralLever,
        title: String(localized: "One thing worth a minute"),
        body: String(localized: "Something in your own pattern moved away from your usual today. Maude has shown its working in today's edition."))

    static var allTemplates: [Template] { [bandTemplate, leverTemplate] }

    /// Every string that can ever reach a notification from this file — the
    /// allow-list the FR-NDG-06 guard test walks (T-NOT-02).
    static var allTemplateStrings: [String] {
        allTemplates.flatMap { [$0.title, $0.body] }
    }

    /// The template an allow-listed engine category maps to, or nil when that
    /// category may never interrupt.
    static func template(for category: NudgeCategory) -> Template? {
        switch category {
        case .bandStatus:        return bandTemplate
        case .behaviouralLever:  return leverTemplate
        // Deliberately silent (see the file header): a safety ROUTE, a positive
        // verdict, and a plain number echo are all read in the edition, not in a
        // banner.
        case .routeToClinician, .verdict, .number: return nil
        }
    }

    /// Whether a single engine nudge is allowed to interrupt at all.
    static func isEligible(_ nudge: EngineNudge) -> Bool {
        template(for: nudge.category) != nil && nudge.priority >= minimumPriority
    }

    // MARK: - The pick (pure — this is what T-NOT-02 proves)

    struct Pick: Equatable, Sendable {
        let template: Template
        /// The engine nudge's own headline. Travels in `userInfo` only — never
        /// rendered — so the tap can open that card's evidence view. Empty when
        /// the deep link cannot be trusted, in which case the tap opens Home.
        let nudgeTag: String
    }

    /// Decide whether today has earned an interruption, and with what text.
    /// Every gate is here and nowhere else: preference → window → one-per-day →
    /// eligibility. Returns nil (silence) whenever any of them closes.
    static func pick(from nudges: [EngineNudge],
                     now: Date,
                     lastAlertAt: Date?,
                     enabled: Bool = true,
                     calendar: Calendar = .current) -> Pick? {
        guard enabled else { return nil }
        guard isWithinDeliveryWindow(now, calendar: calendar) else { return nil }
        guard !hasAlertedToday(now: now, lastAlertAt: lastAlertAt, calendar: calendar) else { return nil }

        // Highest engine priority wins; ties break on the headline so the same
        // input always produces the same alert (no coin-flip between runs).
        let winner = nudges
            .filter(isEligible)
            .sorted { $0.priority != $1.priority ? $0.priority > $1.priority : $0.title < $1.title }
            .first
        guard let winner, let template = template(for: winner.category) else { return nil }

        // Belt and braces: the engine already drops anything the designated
        // guard rejects, but the deep-link tag is the one string here that did
        // not come from the static allow-list — so it is checked again, and
        // dropped rather than carried if it ever failed.
        let tag = NudgeGuard.check(winner.title) == nil ? winner.title : ""
        return Pick(template: template, nudgeTag: tag)
    }

    // MARK: - Request building (pure — testable without UNUserNotificationCenter)

    /// The local notification for a pick. `trigger == nil` ⇒ delivered in this
    /// same wake: the alert is never scheduled ahead, so it can never arrive
    /// describing a day that has moved on.
    static func request(for pick: Pick) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = pick.template.title
        content.body  = pick.template.body
        content.sound = nil                             // calm: silent by design
        var info: [String: String] = ["type": "attention"]
        if !pick.nudgeTag.isEmpty { info["nudge"] = pick.nudgeTag }
        content.userInfo = info
        return UNNotificationRequest(identifier: requestID, content: content, trigger: nil)
    }
}
