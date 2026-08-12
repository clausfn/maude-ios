// MockData.swift — Seed data for demo mode and previews.
import Foundation
import SwiftUI

// MARK: - MetricRing

enum DataSource {
    case healthKit
    case mock
}

struct MetricRing: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let progress: Double
    let warn: Bool
    var subvalue: String?
    var source: DataSource

    init(label: String, value: String, progress: Double, warn: Bool,
         subvalue: String? = nil, source: DataSource = .mock) {
        self.label    = label
        self.value    = value
        self.progress = progress
        self.warn     = warn
        self.subvalue = subvalue
        self.source   = source
    }
}

// MARK: - NudgeAccent

enum NudgeAccent {
    case glucose, sleep, cardiac, travel, general
}

// MARK: - Nudge

/// Evidence behind a nudge — the always-on trust mechanism (Design System v2).
/// The gate (Welltory-style refusal to over-assert): r ≥ 0.4, p ≤ 0.05, N ≥ need.
/// Below the gate we DON'T claim a pattern — we show the still-learning state.
struct NudgeEvidence: Hashable {
    enum Confidence: Hashable { case gated, emerging, learning }

    var confidence: Confidence
    var n: Int                  // sample size (e.g. 42)
    var nUnit: String           // "nights", "rides", "days"…
    var baselineDays: Int       // personal baseline window (e.g. 90)
    var r: Double?              // Pearson r (nil while learning)
    var p: String?             // e.g. "<0.01" — string preserves the "<"
    var lever: String?         // the one controllable lever, named in plain language

    // Plain-sentence + one-chart hero (Alternative C). All optional so a nudge
    // without a quantified chart still renders the sentence + evidence row.
    var headline: String?       // the declarative sentence (overrides body in the hero)
    var chartLabel: String?     // e.g. "OF YOUR RESTLESS NIGHTS"
    var chartPercent: Double?  // 0…1 → the single confirm bar
    var chartCaption: String?  // the quiet line under the bar

    // Still-learning (confidence == .learning)
    var baselineNeeded: Int?    // nights/days needed before the gate opens (e.g. 30)
    var learningNote: String?   // "Keep wearing it to sleep. ~19 nights to go."

    var isGated: Bool { confidence != .learning }
}

struct Nudge: Identifiable, Hashable {
    let id = UUID()
    let time: String
    let tag: String
    let body: String
    let accent: NudgeAccent
    let primaryAction: String
    let secondaryActions: [String]
    let reasoning: String?
    var dataPoints: [String]
    var dismissed: Bool
    /// When set, shows a one-line calibration prompt at the bottom of the card.
    /// Used when the nudge depends on a declared datum the user hasn't yet filled in.
    var calibrationPrompt: String?
    /// Deep-link anchor for the calibration prompt — which ProfileSheet section to open.
    var calibrationAnchor: ProfileSheet.Section?
    /// Always-on evidence metadata (Design v2). nil ⇒ legacy nudge (no evidence row).
    var evidence: NudgeEvidence?

    init(time: String, tag: String, body: String, accent: NudgeAccent,
         primaryAction: String, secondaryActions: [String], reasoning: String?,
         dataPoints: [String] = [], dismissed: Bool = false,
         calibrationPrompt: String? = nil, calibrationAnchor: ProfileSheet.Section? = nil,
         evidence: NudgeEvidence? = nil) {
        self.time               = time
        self.tag                = tag
        self.body               = body
        self.accent             = accent
        self.primaryAction      = primaryAction
        self.secondaryActions   = secondaryActions
        self.reasoning          = reasoning
        self.dataPoints         = dataPoints
        self.dismissed          = dismissed
        self.calibrationPrompt  = calibrationPrompt
        self.calibrationAnchor  = calibrationAnchor
        self.evidence           = evidence
    }

    static func == (lhs: Nudge, rhs: Nudge) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - MockData

enum MockData {

    // MARK: Rings

    static let rings: [MetricRing] = [
        .init(label: String(localized: "Sleep"),  value: "7h 02", progress: 0.62, warn: true,  subvalue: "−28 min"),
        .init(label: "TIR",    value: "68%",   progress: 0.68, warn: false, subvalue: String(localized: "+3 pts")),
        .init(label: "HRV",    value: "42 ms", progress: 0.48, warn: true,  subvalue: "−8 ms"),
        .init(label: String(localized: "Steps"),  value: "5.6k",  progress: 0.55, warn: false),
    ]

    // MARK: Nudges

    static let todayNudges: [Nudge] = [
        // The correlation moment (Design v2 · Alternative C) — gated/high. This is
        // the screen the Home hero opens; it must comprehend → trust → name the lever.
        .init(
            time: "07:02",
            tag: String(localized: "Sleep · meals"),
            body: String(localized: "Late dinners track with restless sleep in your own data."),
            accent: .sleep,
            primaryAction: String(localized: "Remind me to wind down at 20:30"),
            secondaryActions: [String(localized: "Note in journal"), String(localized: "Later")],
            reasoning: String(localized: "Across your last 42 logged nights, meal timing and sleep disruption move together — later dinners, more restless nights. The relationship passes the gate (r ≥ 0.4, p ≤ 0.05) against your 90-day baseline."),
            evidence: NudgeEvidence(
                confidence: .gated, n: 42, nUnit: String(localized: "nights"), baselineDays: 90,
                r: 0.62, p: "<0.01",
                lever: String(localized: "Eat earlier and, in your data, the pattern eases. Dinner before 20:30 is the lever."),
                headline: String(localized: "78% of your restless nights followed a meal after 20:30."),
                chartLabel: String(localized: "Of your restless nights"), chartPercent: 0.78,
                chartCaption: String(localized: "…came after a late meal. Only 22% followed an early one.")
            )
        ),
        .init(
            time: "07:14",
            tag: String(localized: "Glucose · cycling"),
            body: String(localized: "Glucose dropped 35% more than usual after yesterday's ride, compared with your last six rides at similar intensity."),
            accent: .glucose,
            primaryAction: String(localized: "Open"),
            secondaryActions: [String(localized: "Note in journal"), String(localized: "Later")],
            reasoning: String(localized: "Your CGM trace from Wednesday 16:42–18:05 shows a steeper decline than your last six rides at similar intensity. Pattern detection flagged the delta as outside your personal baseline."),
            dataPoints: [String(localized: "Wed 16:42 → 18:05"), String(localized: "−35% vs 6-ride avg"), String(localized: "5.8 mmol/L low")],
            evidence: NudgeEvidence(
                confidence: .emerging, n: 6, nUnit: String(localized: "rides"), baselineDays: 90,
                r: 0.48, p: nil,
                lever: nil,
                headline: String(localized: "Your glucose drops faster after your hardest rides.")
            )
        ),
        // Still-learning — the refusal to over-assert. Below the gate we say so plainly.
        .init(
            time: "12:30",
            tag: String(localized: "Sleep · caffeine"),
            body: String(localized: "There's a hint that afternoon caffeine and lighter sleep move together — but it isn't strong enough to show you yet. We won't assert a pattern we can't stand behind."),
            accent: .sleep,
            primaryAction: "",
            secondaryActions: [String(localized: "Note in journal")],
            reasoning: nil,
            evidence: NudgeEvidence(
                confidence: .learning, n: 11, nUnit: String(localized: "nights"), baselineDays: 90,
                r: nil, p: nil, lever: nil,
                headline: String(localized: "We're still learning your sleep baseline."),
                baselineNeeded: 30,
                learningNote: String(localized: "Keep wearing it to sleep. We'll surface this the moment it's real — about 19 nights from now.")
            )
        ),
        // OD-11 / RQ-13 [REGULATORY DECISION]: the cardiac/rhythm (AF) nudge is the concentrated
        // device-classification exposure (risk file H-10), flagged by both MDR and FDA. This interim
        // copy describes the user's own data only — no rhythm-monitoring claim, no clinician routing,
        // no threshold. FINAL disposition (constrain hard vs hold from MVP) is Claus's decision;
        // do not ship a rhythm-monitoring topic until OD-11 is resolved.
        .init(
            time: "16:00",
            tag: String(localized: "Steady week"),
            body: String(localized: "Your tracked metrics have stayed steady over the past six weeks."),
            accent: .cardiac,
            primaryAction: String(localized: "Note in journal"),
            secondaryActions: [String(localized: "Dismiss")],
            reasoning: nil
        ),
        .init(
            time: "21:00",
            tag: String(localized: "Travel · prep"),
            body: String(localized: "Travel week ahead. Last three trips dropped your activity 40%. Yourcoach.health can share your prep plan with your coach if you allow it."),
            accent: .travel,
            primaryAction: String(localized: "Share with coach"),
            secondaryActions: [String(localized: "Plan privately")],
            reasoning: nil
        ),
    ]

    // MARK: Wallet grants

    static let walletGrants: [WalletGrant] = [
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000001")!,
            userId: nil,
            recipientName: String(localized: "Diabetes Nurse · University Hospital"),
            recipientType: .clinical,
            scopeKeys: ["glucose", "activity"],
            isActive: true,
            expiresAt: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
            createdAt: Date()
        ),
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000002")!,
            userId: nil,
            recipientName: String(localized: "Sports Coach · Yourcoach.health"),
            recipientType: .clinical,
            scopeKeys: ["hrv", "training_load"],
            isActive: true,
            expiresAt: Calendar.current.date(byAdding: .day, value: 90, to: Date()),
            createdAt: Date()
        ),
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000003")!,
            userId: nil,
            recipientName: String(localized: "Stress & absence study (DK/NO)"),
            recipientType: .research,
            scopeKeys: ["hrv", "sleep", "calendar"],
            isActive: true,
            expiresAt: nil,
            createdAt: Date()
        ),
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000004")!,
            userId: nil,
            recipientName: String(localized: "Risk Dept · Insurer A"),
            recipientType: .insurance,
            scopeKeys: ["activity", "sleep"],
            isActive: false,
            expiresAt: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 30)),
            createdAt: Date()
        ),
    ]

    // MARK: Health Passport

    static let passportStats = PassportStats(
        totalReadings:      7240,
        nudgesGenerated:    312,
        sourcesConnected:   4,
        daysTracked:        847,
        glucoseTimeInRange: 84,
        avgSleepHours:      7.08,
        journalEntries:     127,
        consentDecisions:   6
    )

    // MARK: Correlation grid (7 days × 7 metrics)
    // Column order: glucose · sleep · hrv · exercise · spending · calendar · weather

    static let correlationWeek = CorrelationWeek(
        days: [
            CorrelationDay(dayLabel: "M", dateOffset: 6,
                values: [.high, .medium, .medium, .high, .low, .medium, .low]),
            CorrelationDay(dayLabel: "T", dateOffset: 5,
                values: [.medium, .high, .medium, .medium, .medium, .high, .medium]),
            CorrelationDay(dayLabel: "W", dateOffset: 4,
                values: [.low, .low, .outlier, .low, .outlier, .outlier, .medium]),
            CorrelationDay(dayLabel: "T", dateOffset: 3,
                values: [.high, .medium, .medium, .high, .medium, .high, .medium]),
            CorrelationDay(dayLabel: "F", dateOffset: 2,
                values: [.medium, .low, .low, .medium, .outlier, .high, .low]),
            CorrelationDay(dayLabel: "S", dateOffset: 1,
                values: [.low, .high, .high, .low, .medium, .low, .high]),
            CorrelationDay(dayLabel: "S", dateOffset: 0,
                values: [.medium, .high, .high, .medium, .low, .low, .high]),
        ],
        patternNote: String(localized: "Wednesday was a high-load day — three back-to-back meetings, elevated spending, and your HRV took a noticeable dip. Your glucose and sleep both recovered by Thursday once the pressure eased."),
        patternSources: [String(localized: "Calendar"), String(localized: "Spending"), "HRV"],
        patternStrength: String(localized: "Strong")
    )

    // MARK: Care threads (demo mode — secure messaging surface)

    static let demoCareThreads: [CareThread] = [
        CareThread(recipientId: "care-nurse",
                   recipientName: String(localized: "Diabetes Nurse"),
                   recipientOrg: String(localized: "University Hospital"),
                   unread: 2,
                   lastMessageAt: nil,
                   lastMessagePreview: String(localized: "Agreed. Let's keep the basal as-is and review again in two weeks.")),
        CareThread(recipientId: "care-coach",
                   recipientName: String(localized: "Sports Coach"),
                   recipientOrg: "Yourcoach.health",
                   unread: 0,
                   lastMessageAt: nil,
                   lastMessagePreview: String(localized: "Your HRV dipped after the late sessions — let's pull Thursday's intensity back a notch.")),
        CareThread(recipientId: "care-gp",
                   recipientName: String(localized: "General Practitioner"),
                   recipientOrg: String(localized: "City Health Clinic"),
                   unread: 0,
                   lastMessageAt: nil,
                   lastMessagePreview: String(localized: "Everything looks stable. Message me here if anything changes.")),
    ]

    /// DEBUG screenshot seeds for the care video frames (hero · incoming · consult ·
    /// waiting). Only reachable behind the `LIVIQA_OPEN_CARE` DEBUG hook — never a
    /// Release data path. Role-named like the demo threads (no fabricated person).
    static let demoActiveConsult = ConsultSummary(
        id: "demo-consult-1",
        roomName: "liviqa-consult-demo-1",
        recipientName: String(localized: "Diabetes Nurse"),
        recipientOrg: String(localized: "University Hospital"),
        startedAt: Date(),
        recordingRequested: true,
        recordingConsent: false)

    static var demoScheduledConsult: ScheduledConsult {
        ScheduledConsult(id: "demo-sched-1",
                         at: Date().addingTimeInterval(10 * 60),
                         kind: "consultation",
                         recipientName: String(localized: "Diabetes Nurse"),
                         recipientOrg: String(localized: "University Hospital"))
    }

    /// Demo conversation for a care thread (used when no live backend is connected).
    static func demoMessages(for recipientId: String) -> [CareMessage] {
        let now = Date()
        func ago(_ mins: Int) -> Date { now.addingTimeInterval(Double(-mins * 60)) }
        switch recipientId {
        case "care-nurse":
            return [
                CareMessage(id: "n1", sender: .recipient,
                            body: String(localized: "Hi — I had a look at the time-in-range trend you shared. Nice improvement this week."),
                            readAt: now, createdAt: ago(180)),
                CareMessage(id: "n2", sender: .citizen,
                            body: String(localized: "Thanks. The evening walks seem to help the overnight numbers."),
                            readAt: now, createdAt: ago(170)),
                CareMessage(id: "n3", sender: .recipient,
                            body: String(localized: "Agreed. Let's keep the basal as-is and review again in two weeks."),
                            readAt: nil, createdAt: ago(20)),
            ]
        case "care-coach":
            return [
                CareMessage(id: "c1", sender: .recipient,
                            body: String(localized: "Your HRV dipped after the late sessions — let's pull Thursday's intensity back a notch."),
                            readAt: now, createdAt: ago(1440)),
            ]
        default:
            return [
                CareMessage(id: "g1", sender: .recipient,
                            body: String(localized: "Everything looks stable. Message me here if anything changes."),
                            readAt: now, createdAt: ago(2880)),
            ]
        }
    }

    // MARK: Data source connections

    static let connectedSources: [DataSourceConnection] = [
        .init(
            name: "Apple Health",
            icon: "heart.fill",
            iconColorHex: 0xFF3B30,
            category: .health,
            isConnected: true,
            lastSync: Date(),
            dataDescription: String(localized: "Heart rate, sleep, steps, glucose"),
            privacyNote: String(localized: "Read-only. Never written back to Apple Health.")
        ),
        .init(
            name: "Health Vault",
            icon: "doc.fill",
            iconColorHex: 0xFFB703,
            category: .health,
            isConnected: true,
            lastSync: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            dataDescription: String(localized: "17 documents in 7 folders"),
            privacyNote: String(localized: "Stored on device only. You manage uploads.")
        ),
        .init(
            name: String(localized: "Calendar"),
            icon: "calendar",
            iconColorHex: 0xCC3333,
            category: .context,
            isConnected: true,
            lastSync: Date(),
            dataDescription: String(localized: "Meeting count and load — not content"),
            privacyNote: String(localized: "Event titles and attendees are never read.")
        ),
        .init(
            name: String(localized: "Bank account · Open Banking"),
            icon: "creditcard.fill",
            iconColorHex: 0x1B2A4A,
            category: .financial,
            isConnected: false,
            lastSync: nil,
            dataDescription: String(localized: "Daily spend totals and category patterns"),
            privacyNote: String(localized: "Transaction details and merchant names are never stored.")
        ),
        .init(
            name: String(localized: "Screen Time"),
            icon: "hourglass",
            iconColorHex: 0xFFB703,
            category: .device,
            isConnected: false,
            lastSync: nil,
            dataDescription: String(localized: "Total daily screen time only"),
            privacyNote: String(localized: "App names and content are never accessed.")
        ),
        .init(
            name: "Sundhedsplatformen",
            icon: "cross.case.fill",
            iconColorHex: 0x2992A5,
            category: .health,
            isConnected: false,
            lastSync: nil,
            dataDescription: String(localized: "Danish health records — consultations and lab results"),
            privacyNote: String(localized: "Connection requires your MitID. Data stays on device.")
        ),
    ]

    // MARK: Token transactions

    static let tokenTransactions: [TokenTransaction] = [
        .init(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            description: String(localized: "Stress & absence study · DK/NO"),
            amount: 12,
            type: .earned
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
            description: String(localized: "Used: extended nudge history (90 days)"),
            amount: 5,
            type: .spent
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -8, to: Date())!,
            description: String(localized: "Copenhagen Heart Study — Rigshospitalet"),
            amount: 8,
            type: .earned
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!,
            description: String(localized: "Donated to DfG research fund"),
            amount: 20,
            type: .donated
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -21, to: Date())!,
            description: String(localized: "Monthly contribution — LADA longitudinal cohort"),
            amount: 15,
            type: .earned
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!,
            description: String(localized: "Air quality & chronic illness study"),
            amount: 7,
            type: .earned
        ),
    ]

    // MARK: Wallet events

    static let walletEvents: [WalletEvent] = [
        .init(
            id: UUID(uuidString: "b1000000-0000-0000-0000-000000000001")!,
            userId: nil,
            eventType: .accessRequest,
            actorName: String(localized: "Insurer A"),
            scopeKeys: ["glucose", "activity", "sleep"],
            decision: .denied,
            occurredAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        ),
        .init(
            id: UUID(uuidString: "b1000000-0000-0000-0000-000000000002")!,
            userId: nil,
            eventType: .consentGranted,
            actorName: String(localized: "Diabetes Nurse · University Hospital"),
            scopeKeys: ["glucose", "activity"],
            decision: .approved,
            occurredAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        ),
    ]
}
