import Testing
import Foundation
@testable import Maude

// The private journal must survive relaunch (MVP: timestamped free-text entries).
// These verify the serialization the file store depends on, plus a real round-trip.
// @MainActor: the app's models are main-actor-isolated (project default isolation),
// so comparisons run on the main actor too (Swift-6-clean).
@MainActor
struct JournalStoreTests {

    private func sample() -> [JournalEntry] {
        var e = JournalEntry(body: "Evening walk helped the overnight numbers.", tags: ["Glucose", "Mood"])
        e.mood = 4
        e.metrics = MetricSnapshot(glucoseMgdl: 6.2 * 18, hrvMs: 52, sleepHours: 7.2,
                                   stepsCount: 9200, activeCalories: 420)
        let plain = JournalEntry(body: "Quick note, no metrics.", tags: [])
        return [e, plain]
    }

    // Codable round-trip (dates, optionals, nested snake_case MetricSnapshot).
    @Test func entriesEncodeAndDecodeEqual() throws {
        let entries = sample()
        let data = try JSONEncoder().encode(entries)
        let back = try JSONDecoder().decode([JournalEntry].self, from: data)
        #expect(back == entries)
    }

    // Full store round-trip on disk (file-protected write + read back). Uses a
    // temp file so the app's real journal store is never touched by tests.
    @Test func storeSaveThenLoadReturnsSameEntries() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let entries = sample()
        JournalStore.save(entries, to: tmp)
        let loaded = JournalStore.load(from: tmp)
        #expect(loaded == entries)
    }

    // No saved file → load returns nil (so the view shows its starting set).
    @Test func loadFromMissingFileIsNil() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-missing-\(UUID().uuidString).json")
        #expect(JournalStore.load(from: missing) == nil)
    }

    // A note created via the local initialiser carries an empty (all-nil) metric
    // snapshot — no fabricated numbers — and round-trips unchanged.
    @Test func entryWithoutMetricsRoundTrips() throws {
        let e = JournalEntry(body: "Just a thought.", tags: [])
        let data = try JSONEncoder().encode([e])
        let back = try JSONDecoder().decode([JournalEntry].self, from: data)
        #expect(back.first?.metrics == .empty)
        #expect(back.first?.metrics?.glucoseMgdl == nil)
        #expect(back.first?.body == "Just a thought.")
    }
}
