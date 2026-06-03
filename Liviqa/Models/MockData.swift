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

    init(time: String, tag: String, body: String, accent: NudgeAccent,
         primaryAction: String, secondaryActions: [String], reasoning: String?,
         dataPoints: [String] = [], dismissed: Bool = false,
         calibrationPrompt: String? = nil, calibrationAnchor: ProfileSheet.Section? = nil) {
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
    }

    static func == (lhs: Nudge, rhs: Nudge) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - MockData

enum MockData {

    // MARK: Rings

    static let rings: [MetricRing] = [
        .init(label: "Sleep",  value: "7h 02", progress: 0.62, warn: true,  subvalue: "−28 min"),
        .init(label: "TIR",    value: "68%",   progress: 0.68, warn: false, subvalue: "+3 pts"),
        .init(label: "HRV",    value: "42 ms", progress: 0.48, warn: true,  subvalue: "−8 ms"),
        .init(label: "Steps",  value: "5.6k",  progress: 0.55, warn: false),
    ]

    // MARK: Nudges

    static let todayNudges: [Nudge] = [
        .init(
            time: "07:14",
            tag: "Glucose · cycling",
            body: "Glucose dropped 35% more than usual after yesterday's ride, compared with your last six rides at similar intensity.",
            accent: .glucose,
            primaryAction: "Open",
            secondaryActions: ["Note in journal", "Later"],
            reasoning: "Your CGM trace from Wednesday 16:42–18:05 shows a steeper decline than your last six rides at similar intensity. Pattern detection flagged the delta as outside your personal baseline.",
            dataPoints: ["Wed 16:42 → 18:05", "−35% vs 6-ride avg", "5.8 mmol/L low"]
        ),
        .init(
            time: "12:30",
            tag: "Sleep · caffeine",
            body: "Sleep fragmented four nights running. Caffeine after 2pm correlates with this in your own data.",
            accent: .sleep,
            primaryAction: "Show pattern",
            secondaryActions: ["Note in journal"],
            reasoning: nil
        ),
        // OD-11 / RQ-13 [REGULATORY DECISION]: the cardiac/rhythm (AF) nudge is the concentrated
        // device-classification exposure (risk file H-10), flagged by both MDR and FDA. This interim
        // copy describes the user's own data only — no rhythm-monitoring claim, no clinician routing,
        // no threshold. FINAL disposition (constrain hard vs hold from MVP) is Claus's decision;
        // do not ship a rhythm-monitoring topic until OD-11 is resolved.
        .init(
            time: "16:00",
            tag: "Steady week",
            body: "Your tracked metrics have stayed steady over the past six weeks.",
            accent: .cardiac,
            primaryAction: "Note in journal",
            secondaryActions: ["Dismiss"],
            reasoning: nil
        ),
        .init(
            time: "21:00",
            tag: "Travel · prep",
            body: "Travel week ahead. Last three trips dropped your activity 40%. Yourcoach.health can share your prep plan with your coach if you allow it.",
            accent: .travel,
            primaryAction: "Share with coach",
            secondaryActions: ["Plan privately"],
            reasoning: nil
        ),
    ]

    // MARK: Wallet grants

    static let walletGrants: [WalletGrant] = [
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000001")!,
            userId: nil,
            recipientName: "Diabetes Nurse · University Hospital",
            recipientType: .clinical,
            scopeKeys: ["glucose", "activity"],
            isActive: true,
            expiresAt: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
            createdAt: Date()
        ),
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000002")!,
            userId: nil,
            recipientName: "Sports Coach · Yourcoach.health",
            recipientType: .clinical,
            scopeKeys: ["hrv", "training_load"],
            isActive: true,
            expiresAt: Calendar.current.date(byAdding: .day, value: 90, to: Date()),
            createdAt: Date()
        ),
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000003")!,
            userId: nil,
            recipientName: "Stress & absence study (DK/NO)",
            recipientType: .research,
            scopeKeys: ["hrv", "sleep", "calendar"],
            isActive: true,
            expiresAt: nil,
            createdAt: Date()
        ),
        .init(
            id: UUID(uuidString: "a1000000-0000-0000-0000-000000000004")!,
            userId: nil,
            recipientName: "Risk Dept · Insurer A",
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
        patternNote: "Wednesday was a high-load day — three back-to-back meetings, elevated spending, and your HRV took a noticeable dip. Your glucose and sleep both recovered by Thursday once the pressure eased.",
        patternSources: ["Calendar", "Spending", "HRV"],
        patternStrength: "Strong"
    )

    // MARK: Care threads (demo mode — secure messaging surface)

    static let demoCareThreads: [CareThread] = [
        CareThread(recipientId: "care-nurse",
                   recipientName: "Diabetes Nurse",
                   recipientOrg: "University Hospital",
                   unread: 2,
                   lastMessageAt: nil),
        CareThread(recipientId: "care-coach",
                   recipientName: "Sports Coach",
                   recipientOrg: "Yourcoach.health",
                   unread: 0,
                   lastMessageAt: nil),
        CareThread(recipientId: "care-gp",
                   recipientName: "General Practitioner",
                   recipientOrg: "City Health Clinic",
                   unread: 0,
                   lastMessageAt: nil),
    ]

    /// Demo conversation for a care thread (used when no live backend is connected).
    static func demoMessages(for recipientId: String) -> [CareMessage] {
        let now = Date()
        func ago(_ mins: Int) -> Date { now.addingTimeInterval(Double(-mins * 60)) }
        switch recipientId {
        case "care-nurse":
            return [
                CareMessage(id: "n1", sender: .recipient,
                            body: "Hi — I had a look at the time-in-range trend you shared. Nice improvement this week.",
                            readAt: now, createdAt: ago(180)),
                CareMessage(id: "n2", sender: .citizen,
                            body: "Thanks. The evening walks seem to help the overnight numbers.",
                            readAt: now, createdAt: ago(170)),
                CareMessage(id: "n3", sender: .recipient,
                            body: "Agreed. Let's keep the basal as-is and review again in two weeks.",
                            readAt: nil, createdAt: ago(20)),
            ]
        case "care-coach":
            return [
                CareMessage(id: "c1", sender: .recipient,
                            body: "Your HRV dipped after the late sessions — let's pull Thursday's intensity back a notch.",
                            readAt: now, createdAt: ago(1440)),
            ]
        default:
            return [
                CareMessage(id: "g1", sender: .recipient,
                            body: "Everything looks stable. Message me here if anything changes.",
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
            dataDescription: "Heart rate, sleep, steps, glucose",
            privacyNote: "Read-only. Never written back to Apple Health."
        ),
        .init(
            name: "Health Vault",
            icon: "doc.fill",
            iconColorHex: 0xC47D11,
            category: .health,
            isConnected: true,
            lastSync: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            dataDescription: "3 uploaded documents",
            privacyNote: "Stored on device only. You manage uploads."
        ),
        .init(
            name: "Calendar",
            icon: "calendar",
            iconColorHex: 0xCC3333,
            category: .context,
            isConnected: true,
            lastSync: Date(),
            dataDescription: "Meeting count and load — not content",
            privacyNote: "Event titles and attendees are never read."
        ),
        .init(
            name: "Revolut / Open Banking",
            icon: "creditcard.fill",
            iconColorHex: 0x1B2A4A,
            category: .financial,
            isConnected: false,
            lastSync: nil,
            dataDescription: "Daily spend totals and category patterns",
            privacyNote: "Transaction details and merchant names are never stored."
        ),
        .init(
            name: "Screen Time",
            icon: "hourglass",
            iconColorHex: 0xC47D11,
            category: .device,
            isConnected: false,
            lastSync: nil,
            dataDescription: "Total daily screen time only",
            privacyNote: "App names and content are never accessed."
        ),
        .init(
            name: "Sundhedsplatformen",
            icon: "cross.case.fill",
            iconColorHex: 0x2992A5,
            category: .health,
            isConnected: false,
            lastSync: nil,
            dataDescription: "Danish health records — consultations and lab results",
            privacyNote: "Connection requires your MitID. Data stays on device."
        ),
    ]

    // MARK: Token transactions

    static let tokenTransactions: [TokenTransaction] = [
        .init(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            description: "Stress & absence study · DK/NO",
            amount: 12,
            type: .earned
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
            description: "Used: extended nudge history (90 days)",
            amount: 5,
            type: .spent
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -8, to: Date())!,
            description: "Copenhagen Heart Study — Rigshospitalet",
            amount: 8,
            type: .earned
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!,
            description: "Donated to DfG research fund",
            amount: 20,
            type: .donated
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -21, to: Date())!,
            description: "Monthly contribution — LADA longitudinal cohort",
            amount: 15,
            type: .earned
        ),
        .init(
            date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!,
            description: "Air quality & chronic illness study",
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
            actorName: "Insurer A",
            scopeKeys: ["glucose", "activity", "sleep"],
            decision: .denied,
            occurredAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        ),
        .init(
            id: UUID(uuidString: "b1000000-0000-0000-0000-000000000002")!,
            userId: nil,
            eventType: .consentGranted,
            actorName: "Diabetes Nurse · University Hospital",
            scopeKeys: ["glucose", "activity"],
            decision: .approved,
            occurredAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        ),
    ]
}
