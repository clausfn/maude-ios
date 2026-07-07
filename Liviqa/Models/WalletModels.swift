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
        case .research:   return String(localized: "Research")
        case .clinical:   return String(localized: "Clinical")
        case .employer:   return String(localized: "Employer")
        case .insurance:  return String(localized: "Insurance")
        case .publicGood: return String(localized: "Public Good")
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
    /// Consent-engine chain reference (`grant_…`) for this grant on the DATA
    /// for GOOD consent ledger. Optional/backward-compatible: absent on mock
    /// data, on pre-CE grants, and on backends without the CE seam (T1 wave).
    var ceGrantRef: String?

    init(id: UUID, userId: UUID? = nil, recipientName: String,
         recipientType: RecipientType, scopeKeys: [String], isActive: Bool,
         expiresAt: Date? = nil, createdAt: Date? = nil, ceGrantRef: String? = nil) {
        self.id = id
        self.userId = userId
        self.recipientName = recipientName
        self.recipientType = recipientType
        self.scopeKeys = scopeKeys
        self.isActive = isActive
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.ceGrantRef = ceGrantRef
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case recipientName = "recipient_name"
        case recipientType = "recipient_type"
        case scopeKeys     = "scope_keys"
        case isActive      = "is_active"
        case expiresAt     = "expires_at"
        case createdAt     = "created_at"
        case ceGrantRef    = "ce_grant_ref"
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

/// Consent-engine evidence attached to a ledger event (CE seam, sim mode).
/// The receipt is offline-verifiable against the consent contract's public key
/// (P7) — on-device the T1 wave DISPLAYS it (receipt id + short hash) without
/// cryptographic verification; on-device verification is a flagged follow-up.
/// All fields optional: pre-CE events and mock data carry none.
struct CEEvidence: Codable, Equatable {
    var receiptId: String?
    var grantRef: String?
    var contractSig: String?
    var eventHash: String?
    var txHash: String?
    var ceScopeKeys: [String]?
    var excludedScopeKeys: [String]?

    enum CodingKeys: String, CodingKey {
        case receiptId         = "receipt_id"
        case grantRef          = "grant_ref"
        case contractSig       = "contract_sig"
        case eventHash         = "event_hash"
        case txHash            = "tx_hash"
        case ceScopeKeys       = "ce_scope_keys"
        case excludedScopeKeys = "excluded_scope_keys"
    }

    /// Short display form of the event hash (first 10 hex chars), or nil.
    var shortHash: String? {
        guard let h = eventHash, !h.isEmpty else { return nil }
        return String(h.prefix(10))
    }
}

struct WalletEvent: Identifiable, Codable {
    let id: UUID
    var userId: UUID?
    var eventType: EventType
    var actorName: String
    var scopeKeys: [String]
    var decision: EventDecision
    var occurredAt: Date
    /// Evidence receipt from the DATA for GOOD consent ledger (optional —
    /// absent on mock data and pre-CE events; backward-compatible decode).
    var ce: CEEvidence?

    init(id: UUID, userId: UUID? = nil, eventType: EventType, actorName: String,
         scopeKeys: [String], decision: EventDecision, occurredAt: Date,
         ce: CEEvidence? = nil) {
        self.id = id
        self.userId = userId
        self.eventType = eventType
        self.actorName = actorName
        self.scopeKeys = scopeKeys
        self.decision = decision
        self.occurredAt = occurredAt
        self.ce = ce
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case eventType  = "event_type"
        case actorName  = "actor_name"
        case scopeKeys  = "scope_keys"
        case decision
        case occurredAt = "occurred_at"
        case ce
    }
}
