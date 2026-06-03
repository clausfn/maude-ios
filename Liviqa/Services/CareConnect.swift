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
public protocol CareConnect: Sendable {
    func fetchNotifications() async throws -> [CitizenNotification]

    // Video consult
    func fetchActiveConsults() async throws -> [ConsultSummary]
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
}
