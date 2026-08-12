// CareConnect.swift — citizen-side care-team surface (secure messaging + video
// consult join + recording consent), per Video_and_OAuth_Contract_v01.
//
// Sovereign-only capability (Ory-authenticated citizen role). Kept OFF the shared
// `SupabaseServiceProtocol` so mock/Supabase paths stay unaffected; AppState
// reaches it via `supabase as? CareConnect`. Pure Foundation value types
// (Android-portable, NFR-PORT-01). NOTE: messaging is NOT health content — raw
// health discussion belongs in the consult (D-BACKEND-SCOPE).
import Foundation

/// A citizen notification (active consult · unread message · access request).
public struct CitizenNotification: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable { case consult, message, accessRequest, unknown }
    public let id: String
    public let kind: Kind
    public let text: String
    public let at: Date?
}

/// A joinable video consultation the citizen can enter (same Jitsi room as the
/// recipient: `liviqa-consult-<id>`).
public struct ConsultSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let roomName: String
    public let recipientName: String
    public let recipientOrg: String?
    public let startedAt: Date?
    public let recordingRequested: Bool   // recipient asked
    public let recordingConsent: Bool     // ONLY the citizen grants this
}

/// One care-team conversation (the citizen ↔ a single recipient).
public struct CareThread: Identifiable, Equatable, Sendable {
    public var id: String { recipientId }
    public let recipientId: String
    public let recipientName: String
    public let recipientOrg: String?
    public let unread: Int
    public let lastMessageAt: Date?
    /// One-line preview of the newest message (A7 Care-tab thread rows).
    /// `nil` when the backend doesn't send it yet — rows fall back to the org line.
    public let lastMessagePreview: String?

    public init(recipientId: String, recipientName: String, recipientOrg: String?,
                unread: Int, lastMessageAt: Date?, lastMessagePreview: String? = nil) {
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.recipientOrg = recipientOrg
        self.unread = unread
        self.lastMessageAt = lastMessageAt
        self.lastMessagePreview = lastMessagePreview
    }
}

/// A single secure message.
public struct CareMessage: Identifiable, Equatable, Sendable {
    public enum Sender: String, Sendable { case citizen, recipient }
    public let id: String
    public let sender: Sender
    public let body: String
    public let readAt: Date?
    public let createdAt: Date
    public var isMine: Bool { sender == .citizen }
}

/// Citizen-side care-team capabilities on the sovereign backend. Every method is
/// Ory-authenticated and server-side consent-gated; a revoked/expired grant
/// yields a 403 the UI renders as "unavailable".
/// An upcoming SCHEDULED consultation — "when will my nurse call". Old calls
/// never surface here (they're audit material, not a landing view).
public struct ScheduledConsult: Identifiable, Equatable, Sendable {
    public let id: String
    public let at: Date
    public let kind: String            // consultation | check-in
    /// scheduled · proposed:citizen (awaiting the clinician) · proposed:recipient
    /// (awaiting YOU — accept/decline). Draft request flow, 2026-06-11.
    public let status: String
    public let recipientName: String
    public let recipientOrg: String?
    public init(id: String, at: Date, kind: String, status: String = "scheduled",
                recipientName: String, recipientOrg: String?) {
        self.id = id; self.at = at; self.kind = kind; self.status = status
        self.recipientName = recipientName; self.recipientOrg = recipientOrg
    }
}

public protocol CareConnect: Sendable {
    func fetchNotifications() async throws -> [CitizenNotification]

    // Video consult
    func fetchActiveConsults() async throws -> [ConsultSummary]
    /// Upcoming scheduled consultations (soonest first). Server-side filtered:
    /// scheduled + future only.
    func fetchScheduledConsults() async throws -> [ScheduledConsult]
    /// Answer a clinician-proposed slot (draft request flow).
    @discardableResult
    func respondToProposal(id: String, accept: Bool) async throws -> Bool
    /// Citizen requests a consult at a chosen time. Creates an appointment in
    /// status `proposed:citizen`, awaiting the clinician's accept / counter
    /// (FB-AOIWoD6l). Returns the created consult.
    @discardableResult
    func requestConsult(recipientId: String, at: Date, kind: String) async throws -> ScheduledConsult
    /// Mark the citizen as joined; returns the deterministic Jitsi room name.
    @discardableResult
    func joinConsult(id: String) async throws -> String
    /// The citizen grants/withdraws in-call recording consent (authoritative).
    @discardableResult
    func setRecordingConsent(consultId: String, consent: Bool) async throws -> Bool

    // Secure messaging
    func fetchThreads() async throws -> [CareThread]
    func fetchMessages(recipientId: String) async throws -> [CareMessage]
    @discardableResult
    func sendMessage(recipientId: String, body: String) async throws -> CareMessage

    /// Register this device's APNs token so the backend can send push reminders.
    func registerPushToken(_ token: String) async throws
}
