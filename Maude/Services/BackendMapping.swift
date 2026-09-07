// BackendMapping.swift — Pure, framework-free translation between the sovereign
// backend wire vocabulary (string IDs, camelCase, role/event enums) and the app's
// domain enums. Kept separate from MaudeBackendService so these deterministic
// transforms are unit-testable without URLSession (NFR-PORT-01).
//
// FR-SHARE-02 · maps openapi.yaml schemas → Maude domain types.
import Foundation
import CryptoKit

enum BackendMapping {

    // MARK: - Stable IDs
    // Backend IDs are opaque strings (e.g. "grant_abc", "dev-citizen-claus"); the
    // app's domain types are UUID-keyed. Derive a STABLE (deterministic) UUID from
    // the backend id so `Identifiable`/diffing stay consistent across fetches.
    // The original backend string is retained separately by MaudeBackendService
    // for path calls (revoke / share push).
    static func stableUUID(_ backendID: String) -> UUID {
        let digest = SHA256.hash(data: Data(backendID.utf8))
        var b = Array(digest.prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50   // version 5 (name-based)
        b[8] = (b[8] & 0x3F) | 0x80   // RFC 4122 variant
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    // MARK: - Recipient role → display type
    // Backend roles are clinical_nurse | health_coach. The app's RecipientType has
    // no "coach" case; both are care recipients, so both map to `.clinical` for
    // display only — the authoritative role is preserved server-side and in the
    // grant's recipientRole. (Display approximation, not a scope decision.)
    static func recipientType(forRole role: String) -> RecipientType {
        switch role {
        case "clinical_nurse": return .clinical
        case "health_coach":   return .clinical
        default:               return .clinical
        }
    }

    // MARK: - Ledger event type → app event type
    // Backend: request | grant | revoke | access | refuse.
    static func eventType(_ backend: String) -> EventType {
        switch backend {
        case "grant":  return .consentGranted
        case "revoke": return .consentRevoked
        case "access": return .dataAccessed
        case "refuse": return .accessRequest
        default:       return .accessRequest   // "request"
        }
    }

    static func decision(_ backendEventType: String) -> EventDecision {
        switch backendEventType {
        case "grant":  return .approved
        case "revoke": return .approved   // an actioned revoke is an approved request to stop
        case "refuse": return .denied
        case "access": return .approved
        default:       return .pending    // "request"
        }
    }

    // MARK: - Dates
    // Backend emits ISO-8601 date-times, sometimes with fractional seconds. Parse
    // both forms; fall back to nil so a malformed date can never crash a fetch.
    static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        if let d = isoFractional.date(from: s) { return d }
        return isoPlain.date(from: s)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// ISO-8601 writer for outbound dates (CreateGrant.expiry, share asOf).
    static func iso(_ d: Date) -> String { isoOut.string(from: d) }
    private static let isoOut = ISO8601DateFormatter()

    // MARK: - Journal (T1 TestProd wave — real /journal sync)
    // The server row is TEXT + `at` (+ createdAt); mood/tags/metric snapshots
    // are device-local by design and never ride the wire. Deterministic and
    // URLSession-free so `JournalSyncMappingTests` can pin the behaviour.
    static func journalEntry(from dto: JournalEntryDTO) -> JournalEntry {
        let at = parseDate(dto.at) ?? Date()
        return JournalEntry(
            id: stableUUID(dto.id),
            userId: nil,
            body: dto.text,
            mood: nil,
            metrics: nil,
            tags: [],
            syncEnabled: true,
            createdAt: at,
            updatedAt: parseDate(dto.createdAt) ?? at)
    }
}
