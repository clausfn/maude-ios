// WalletModels.swift — Auth session, user profile, wallet grants and events.
import Foundation

// MARK: - Auth

struct UserSession: Equatable {
    let userId: UUID
    let email: String?
}

struct UserProfile: Codable {
    let id: UUID
    var displayName: String?
    var avatarURL: String?
    var createdAt: Date?
    /// Pseudonymous alias (e.g. "LV001") — what recipients see; used as the
    /// in-call display name so video never asks for (or shows) a real name.
    var alias: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName  = "display_name"
        case avatarURL    = "avatar_url"
        case createdAt    = "created_at"
    }
}

// MARK: - Wallet grants

enum RecipientType: String, Codable, CaseIterable {
    case research   = "research"
    case clinical   = "clinical"
    case employer   = "employer"
    case insurance  = "insurance"
    case publicGood = "public_good"

    var label: String {
        switch self {
        case .research:   return "Research"
        case .clinical:   return "Clinical"
        case .employer:   return "Employer"
        case .insurance:  return "Insurance"
        case .publicGood: return "Public Good"
        }
    }
}

struct WalletGrant: Identifiable, Codable, Equatable {
    let id: UUID
    var userId: UUID?
    var recipientName: String
    var recipientType: RecipientType
    var scopeKeys: [String]          // e.g. ["glucose", "hrv", "sleep"]
    var isActive: Bool
    var expiresAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case recipientName = "recipient_name"
        case recipientType = "recipient_type"
        case scopeKeys     = "scope_keys"
        case isActive      = "is_active"
        case expiresAt     = "expires_at"
        case createdAt     = "created_at"
    }
}

// MARK: - Wallet events

enum EventType: String, Codable {
    case accessRequest  = "access_request"
    case consentGranted = "consent_granted"
    case consentRevoked = "consent_revoked"
    case dataAccessed   = "data_accessed"
}

enum EventDecision: String, Codable {
    case approved = "approved"
    case denied   = "denied"
    case pending  = "pending"
}

struct WalletEvent: Identifiable, Codable {
    let id: UUID
    var userId: UUID?
    var eventType: EventType
    var actorName: String
    var scopeKeys: [String]
    var decision: EventDecision
    var occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case eventType  = "event_type"
        case actorName  = "actor_name"
        case scopeKeys  = "scope_keys"
        case decision
        case occurredAt = "occurred_at"
    }
}
