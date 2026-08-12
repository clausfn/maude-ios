import Testing
import Foundation
import UserNotifications
@testable import Liviqa

// T-NOT-02 — FR-NOT-02 earned-attention micro-loop.
//
// Four properties, in order of how badly they'd hurt if they broke:
//   1. FR-NDG-06 (DESIGNATED, never skipped): every string this loop can ever
//      deliver passes the forbidden-construction guard, AND carries no digit —
//      an earned-attention alert must never put a reading in a banner.
//   2. Cadence: at most ONE per calendar day, ever.
//   3. Eligibility: only the top of the ladder may interrupt; a safety ROUTE, a
//      positive verdict and a plain number echo may not.
//   4. Shape: one replacing identifier, silent, delivered in this same wake
//      (no pre-scheduled trigger ⇒ nothing stale can arrive), deep-linking to
//      the nudge's own evidence view.
struct EarnedAttentionTests {

    private let cal = Calendar(identifier: .gregorian)

    private func at(_ hour: Int, day: Int = 12, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 8, day: day,
                                      hour: hour, minute: minute))!
    }

    private func nudge(_ category: NudgeCategory, priority: Int,
                       title: String = "Glucose above your usual",
                       lane: RegulatoryLane = .watch) -> EngineNudge {
        EngineNudge(category: category, lane: lane, title: title,
                    body: "Your glucose today is running above your usual range.",
                    priority: priority)
    }

    // MARK: 1 · FR-NDG-06 on the notification allow-list (designated control)

    @Test func everyTemplateStringPassesTheNudgeGuard() {
        #expect(!EarnedAttention.allTemplateStrings.isEmpty)
        for text in EarnedAttention.allTemplateStrings {
            #expect(NudgeGuard.check(text) == nil, "forbidden construction in: \(text)")
        }
    }

    /// The stricter rail for THIS loop: an alert built off-session, read on a
    /// lock screen, must not contain a reading value at all. No digits ⇒ no
    /// number can have leaked into the template.
    @Test func noTemplateCarriesAReadingValue() {
        for text in EarnedAttention.allTemplateStrings {
            #expect(text.rangeOfCharacter(from: .decimalDigits) == nil,
                    "a value reached notification copy: \(text)")
        }
    }

    /// Whatever the engine emitted, the DELIVERED text is the fixed template —
    /// the engine's own sentence (which may carry numbers) never travels.
    @Test func deliveredTextIsTheTemplateNotTheEngineSentence() throws {
        let engine = nudge(.bandStatus, priority: 75,
                           title: "Glucose above your usual")
        let pick = try #require(EarnedAttention.pick(from: [engine],
                                                     now: at(11),
                                                     lastAlertAt: nil,
                                                     calendar: cal))
        #expect(pick.template == EarnedAttention.bandTemplate)
        let request = EarnedAttention.request(for: pick)
        #expect(EarnedAttention.allTemplateStrings.contains(request.content.title))
        #expect(EarnedAttention.allTemplateStrings.contains(request.content.body))
        #expect(request.content.body != engine.body)
    }

    // MARK: 2 · Cadence — at most one a day

    @Test func neverTwiceInTheSameCalendarDay() {
        let morning = at(10)
        let evening = at(19)
        #expect(!EarnedAttention.hasAlertedToday(now: morning, lastAlertAt: nil, calendar: cal))
        #expect(EarnedAttention.hasAlertedToday(now: evening, lastAlertAt: morning, calendar: cal))
        // A pick is refused for the rest of that day…
        let candidates = [nudge(.bandStatus, priority: 75)]
        #expect(EarnedAttention.pick(from: candidates, now: evening,
                                     lastAlertAt: morning, calendar: cal) == nil)
        // …and allowed again the next day.
        let tomorrow = at(10, day: 13)
        #expect(!EarnedAttention.hasAlertedToday(now: tomorrow, lastAlertAt: morning, calendar: cal))
        #expect(EarnedAttention.pick(from: candidates, now: tomorrow,
                                     lastAlertAt: morning, calendar: cal) != nil)
    }

    @Test func cadenceLedgerRoundTrips() {
        let name = "earned-attention-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        #expect(EarnedAttention.lastAlertAt(defaults: d) == nil)
        let stamp = at(11)
        EarnedAttention.recordAlert(at: stamp, defaults: d)
        #expect(EarnedAttention.lastAlertAt(defaults: d) == stamp)
    }

    @Test func onlyOneRequestIdentifierExistsSoAlertsReplaceRatherThanStack() throws {
        let a = try #require(EarnedAttention.pick(from: [nudge(.bandStatus, priority: 75)],
                                                  now: at(11), lastAlertAt: nil, calendar: cal))
        let b = try #require(EarnedAttention.pick(from: [nudge(.behaviouralLever, priority: 60,
                                                               title: "Recovery looks low",
                                                               lane: .wellness)],
                                                  now: at(11), lastAlertAt: nil, calendar: cal))
        #expect(EarnedAttention.request(for: a).identifier
                == EarnedAttention.request(for: b).identifier)
        #expect(EarnedAttention.request(for: a).identifier == EarnedAttention.requestID)
    }

    // MARK: 3 · Eligibility — only the top of the ladder interrupts

    @Test func onlyBandStatusAndBehaviouralLeverMayInterrupt() {
        #expect(EarnedAttention.template(for: .bandStatus) != nil)
        #expect(EarnedAttention.template(for: .behaviouralLever) != nil)
        // D9: an AFib route is displayed and routed, never buzzed off-session.
        #expect(EarnedAttention.template(for: .routeToClinician) == nil)
        #expect(EarnedAttention.template(for: .verdict) == nil)
        #expect(EarnedAttention.template(for: .number) == nil)
    }

    @Test func theAFibRouteNeverProducesAnAlertEvenAtTopPriority() {
        let afib = EngineNudge(category: .routeToClinician, lane: .displayOnly,
                               title: "Irregular heart-rhythm signal",
                               body: "Please share this recording with your cardiologist.",
                               priority: 100)
        #expect(!EarnedAttention.isEligible(afib))
        #expect(EarnedAttention.pick(from: [afib], now: at(11),
                                     lastAlertAt: nil, calendar: cal) == nil)
    }

    @Test func lowPriorityNudgesStaySilent() {
        // "Glucose steady" (55), "short night" (45), "quieter day" (30) are all
        // real engine outputs that must never earn an interruption.
        let quiet = [nudge(.bandStatus, priority: 55, title: "Glucose steady"),
                     nudge(.behaviouralLever, priority: 45, title: "Short night", lane: .wellness),
                     nudge(.behaviouralLever, priority: 30, title: "Quieter day for movement", lane: .wellness),
                     nudge(.number, priority: 20, title: "Resting heart rate")]
        for n in quiet { #expect(!EarnedAttention.isEligible(n), "\(n.title) should stay silent") }
        #expect(EarnedAttention.pick(from: quiet, now: at(11),
                                     lastAlertAt: nil, calendar: cal) == nil)
    }

    @Test func highestPriorityWinsAndTiesAreDeterministic() throws {
        let low  = nudge(.behaviouralLever, priority: 60, title: "Recovery looks low", lane: .wellness)
        let high = nudge(.bandStatus, priority: 75, title: "Glucose above your usual")
        let pick = try #require(EarnedAttention.pick(from: [low, high], now: at(11),
                                                     lastAlertAt: nil, calendar: cal))
        #expect(pick.nudgeTag == "Glucose above your usual")
        // Same priority ⇒ same winner whichever order they arrive in.
        let a = nudge(.bandStatus, priority: 70, title: "Alpha")
        let b = nudge(.bandStatus, priority: 70, title: "Beta")
        #expect(EarnedAttention.pick(from: [a, b], now: at(11), lastAlertAt: nil, calendar: cal)
                == EarnedAttention.pick(from: [b, a], now: at(11), lastAlertAt: nil, calendar: cal))
    }

    @Test func nothingIsDeliveredWhenThePreferenceIsOff() {
        #expect(EarnedAttention.pick(from: [nudge(.bandStatus, priority: 75)],
                                     now: at(11), lastAlertAt: nil,
                                     enabled: false, calendar: cal) == nil)
    }

    // MARK: 4 · Timing — the ladder stays time-shaped

    @Test func alertsOnlyLandInsideTheWakingWindow() {
        #expect(!EarnedAttention.isWithinDeliveryWindow(at(3), calendar: cal))
        #expect(!EarnedAttention.isWithinDeliveryWindow(at(7), calendar: cal))   // morning edition
        #expect(EarnedAttention.isWithinDeliveryWindow(at(9), calendar: cal))
        #expect(EarnedAttention.isWithinDeliveryWindow(at(19), calendar: cal))
        #expect(!EarnedAttention.isWithinDeliveryWindow(at(21), calendar: cal))  // evening close
        #expect(EarnedAttention.pick(from: [nudge(.bandStatus, priority: 75)],
                                     now: at(3), lastAlertAt: nil, calendar: cal) == nil)
    }

    /// The wake we ask iOS for is never pointed at the middle of the night.
    @Test func theNextWakeIsAlwaysAimedInsideTheWindow() {
        for hour in 0..<24 {
            let next = BackgroundRefresh.nextBeginDate(after: at(hour, minute: 5), calendar: cal)
            #expect(next > at(hour, minute: 5))
            #expect(EarnedAttention.isWithinDeliveryWindow(next, calendar: cal),
                    "wake asked for outside the window from hour \(hour)")
        }
    }

    // MARK: 5 · Request shape

    @Test func theRequestIsSilentImmediateAndDeepLinked() throws {
        let pick = try #require(EarnedAttention.pick(from: [nudge(.bandStatus, priority: 75)],
                                                     now: at(11), lastAlertAt: nil, calendar: cal))
        let request = EarnedAttention.request(for: pick)
        #expect(request.content.sound == nil)                       // calm by design
        // No trigger ⇒ delivered in the same wake it was derived in: an alert can
        // never arrive describing a day that has already moved on.
        #expect(request.trigger == nil)
        #expect(request.content.userInfo["type"] as? String == "attention")
        #expect(request.content.userInfo["nudge"] as? String == "Glucose above your usual")
    }

    /// The deep-link tag is routing data, not copy — but it is still checked
    /// against the designated guard, and dropped rather than carried if it fails.
    @Test func anUnsafeHeadlineIsNeverCarriedAsADeepLink() throws {
        let bad = EngineNudge(category: .bandStatus, lane: .watch,
                              title: "Your readings are abnormal",
                              body: "…", priority: 75)
        let pick = try #require(EarnedAttention.pick(from: [bad], now: at(11),
                                                     lastAlertAt: nil, calendar: cal))
        #expect(pick.nudgeTag.isEmpty)
        #expect(EarnedAttention.request(for: pick).content.userInfo["nudge"] == nil)
    }
}
