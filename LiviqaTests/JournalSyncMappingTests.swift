import Testing
import Foundation
@testable import Liviqa

// T1 TestProd wave — real journal sync (the LiviqaBackendService stub trio is
// gone). Deterministic wire↔domain mapping for the citizen /journal routes:
// server rows are TEXT + `at` (+ createdAt); mood/tags/metric snapshots are
// device-local by design and never ride the wire.
struct JournalSyncMappingTests {

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    @Test func mapsServerRowToEntry() {
        let dto = JournalEntryDTO(
            id: "jrn_abc123",
            text: "Slept badly after the late dinner.",
            at: "2026-07-01T21:15:00.000Z",
            createdAt: "2026-07-02T06:00:00.000Z")
        let e = BackendMapping.journalEntry(from: dto)

        #expect(e.id == BackendMapping.stableUUID("jrn_abc123"))   // stable identity
        #expect(e.body == "Slept badly after the late dinner.")
        #expect(e.syncEnabled)                                     // came from the server
        #expect(e.mood == nil)                                     // device-local field
        #expect(e.tags.isEmpty)                                    // device-local field
        #expect(e.metrics == nil)                                  // device-local field
        #expect(e.createdAt == Self.iso.date(from: "2026-07-01T21:15:00.000Z"))
        #expect(e.updatedAt == Self.iso.date(from: "2026-07-02T06:00:00.000Z"))
    }

    @Test func missingCreatedAtFallsBackToAt() {
        let dto = JournalEntryDTO(id: "jrn_x", text: "t", at: "2026-06-30T08:00:00Z", createdAt: nil)
        let e = BackendMapping.journalEntry(from: dto)
        #expect(e.updatedAt == e.createdAt)
    }

    @Test func mappingIsDeterministic() {
        let dto = JournalEntryDTO(id: "jrn_same", text: "a", at: "2026-07-01T00:00:00Z", createdAt: nil)
        #expect(BackendMapping.journalEntry(from: dto).id == BackendMapping.journalEntry(from: dto).id)
    }

    @Test func decodesServerRowJSON() throws {
        // Wire shape per liviqa-backend citizen.controller (Prisma JournalEntry).
        let json = #"""
        [{"id":"cmcqjournal01","citizenId":"acc_1","text":"Morning walk before breakfast.",
          "at":"2026-07-03T07:30:00.000Z","createdAt":"2026-07-03T07:31:12.000Z"}]
        """#
        let rows = try JSONDecoder().decode([JournalEntryDTO].self, from: Data(json.utf8))
        #expect(rows.count == 1)
        let e = BackendMapping.journalEntry(from: rows[0])
        #expect(e.body == "Morning walk before breakfast.")
        #expect(e.syncEnabled)
    }
}
