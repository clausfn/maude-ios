import Testing
import Foundation
@testable import Liviqa

// FR-SHARE-02 — deterministic wire↔domain mapping for the sovereign backend.
struct BackendMappingTests {

    // Stable UUID: same input → same UUID; different input → different UUID;
    // RFC-4122 version/variant bits set.
    @Test func stableUUIDIsDeterministic() {
        let a = BackendMapping.stableUUID("dev-citizen-claus")
        let b = BackendMapping.stableUUID("dev-citizen-claus")
        let c = BackendMapping.stableUUID("grant_xyz")
        #expect(a == b)
        #expect(a != c)
        let bytes = withUnsafeBytes(of: a.uuid) { Array($0) }
        #expect(bytes[6] & 0xF0 == 0x50)   // version 5
        #expect(bytes[8] & 0xC0 == 0x80)   // RFC 4122 variant
    }

    @Test func eventTypeMapping() {
        #expect(BackendMapping.eventType("grant")   == .consentGranted)
        #expect(BackendMapping.eventType("revoke")  == .consentRevoked)
        #expect(BackendMapping.eventType("access")  == .dataAccessed)
        #expect(BackendMapping.eventType("refuse")  == .accessRequest)
        #expect(BackendMapping.eventType("request") == .accessRequest)
    }

    @Test func decisionMapping() {
        #expect(BackendMapping.decision("grant")   == .approved)
        #expect(BackendMapping.decision("refuse")  == .denied)
        #expect(BackendMapping.decision("request") == .pending)
    }

    @Test func recipientRoleMapsToClinicalDisplay() {
        #expect(BackendMapping.recipientType(forRole: "clinical_nurse") == .clinical)
        #expect(BackendMapping.recipientType(forRole: "health_coach")   == .clinical)
    }

    @Test func parseDateHandlesBothISOForms() {
        #expect(BackendMapping.parseDate("2026-06-03T07:00:00Z") != nil)
        #expect(BackendMapping.parseDate("2026-06-03T07:00:00.123Z") != nil)
        #expect(BackendMapping.parseDate(nil) == nil)
        #expect(BackendMapping.parseDate("") == nil)
    }

    // Round-trip the ISO writer used for CreateGrant.expiry.
    @Test func isoRoundTrip() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let s = BackendMapping.iso(now)
        #expect(BackendMapping.parseDate(s) != nil)
    }
}
