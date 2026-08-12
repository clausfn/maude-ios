import Testing
import Foundation
@testable import Liviqa

// FR-PMS-01 / UC-19 — the post-market-surveillance report outbox. T-PMS-01.
// The designated property: the payload is a SUMMARY of the pattern and can
// never carry raw readings — enforced by construction and asserted here as a
// strict key allow-list on the encoded record.
struct PMSOutboxTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pms-outbox-test-\(UUID().uuidString).json")
    }

    private func sampleReport(note: String? = "Felt off after lunch") -> PMSReport {
        PMSReport(id: UUID(), createdAt: Date(), nudgeID: UUID(),
                  tag: "Sleep · meals",
                  headline: "Late dinners are costing you sleep.",
                  shownAt: "today · 13:40",
                  reason: .feltAlarmingOrUnsafe,
                  note: note,
                  status: .queued)
    }

    @Test func queueAndLoadRoundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(PMSOutboxStore.load(from: url) == nil)   // nothing queued yet

        let report = sampleReport()
        PMSOutboxStore.queue(report, at: url)
        PMSOutboxStore.queue(sampleReport(note: nil), at: url)

        let loaded = try #require(PMSOutboxStore.load(from: url))
        #expect(loaded.count == 2)
        #expect(loaded[0] == report)
        #expect(loaded[0].status == .queued)
        #expect(loaded[1].note == nil)
    }

    /// The summaries-only rail: the encoded payload may contain EXACTLY the
    /// allow-listed keys — nothing that could carry a reading, a series, or any
    /// raw health value.
    @Test func payloadIsSummaryOnly() throws {
        let data = try JSONEncoder().encode(sampleReport())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let allowed: Set<String> = ["id", "createdAt", "nudgeID", "tag", "headline",
                                    "shownAt", "reason", "note", "status"]
        #expect(Set(obj.keys).isSubset(of: allowed))
        // And specifically: no field family that could smuggle raw data.
        for forbidden in ["readings", "samples", "series", "mmol", "values", "glucose", "hrv"] {
            #expect(!obj.keys.contains { $0.lowercased().contains(forbidden) })
        }
    }

    @Test func statusUpdatePersists() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        PMSOutboxStore.queue(sampleReport(), at: url)
        var all = try #require(PMSOutboxStore.load(from: url))
        all[0].status = .sent
        PMSOutboxStore.save(all, to: url)
        let reloaded = try #require(PMSOutboxStore.load(from: url))
        #expect(reloaded[0].status == .sent)
    }

    @Test func reasonsMatchTheDesignedFixedChoices() {
        // ScrReportNudge's five single-select rows, verbatim.
        let labels = PMSReport.Reason.allCases.map(\.label)
        #expect(labels == ["It doesn't match how I feel",
                           "It felt alarming or unsafe",
                           "The numbers look wrong",
                           "It read like medical advice",
                           "Something else"])
    }
}
