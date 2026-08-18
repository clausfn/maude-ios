import Testing
import Foundation
import SwiftData
@testable import Liviqa

// RK-STORE-01 — "I could not read it" must never become "it does not exist",
// and must never be followed by a write.
//
// This one bug shape has now caused five separate data-loss defects in Liviqa:
// the vault index replaced when unreadable; a journal note-save overwriting the
// whole file; the citizen's goals and ranges destroyed by a locked-launch read;
// and the two pinned here. Each was found the same way — by asking of every
// store, "what does a failed read do, and can a write follow it?"
//
// The rule these tests enforce: a store may fail to save, but it may never
// destroy. Refusing costs the citizen the one thing they just entered; allowing
// costs them everything they ever entered.
@MainActor
struct StoreFailClosedTests {

    private func tempDir() -> URL {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("liviqa-failclosed-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    // MARK: - 1. An empty read is not evidence of deletion

    /// HealthKit reports a DENIED read as an empty success, never an error. So
    /// revoking one type in Settings arrives at the coordinator looking exactly
    /// like "you recorded nothing this month" — and the coordinator used to
    /// delete the whole window on that basis and insert nothing back.
    @Test func anEmptyReadNeverDeletesStoredHistory() async throws {
        let container = try LiviqaStore.makeContainer(inMemory: true)
        let ctx = container.mainContext
        let coord = IngestionCoordinator(context: ctx, provider: MockDataProvider())

        let to = Date()
        let from = Calendar(identifier: .gregorian).date(byAdding: .day, value: -7, to: to)!

        let filled = try await coord.sync(from: from, to: to)
        #expect(filled.glucose > 0)
        let before = try ctx.fetch(FetchDescriptor<GlucoseSample>()).count
        #expect(before > 0)

        // The revocation shape: a well-formed read of the same window that
        // simply carries nothing.
        _ = try coord.persist(HealthSamples(), from: from, to: to)

        let after = try ctx.fetch(FetchDescriptor<GlucoseSample>()).count
        #expect(after == before,
                "an empty read deleted \(before - after) stored rows — the citizen's history")
        // The other streams the same call would have wiped.
        #expect(try ctx.fetch(FetchDescriptor<HeartDaily>()).count > 0)
        #expect(try ctx.fetch(FetchDescriptor<SleepSegment>()).count > 0)
    }

    /// The guard must not break the thing it sits in front of: a NON-empty read
    /// still replaces the window rather than accumulating duplicates.
    @Test func aRealReadStillReplacesTheWindow() async throws {
        let container = try LiviqaStore.makeContainer(inMemory: true)
        let ctx = container.mainContext
        let coord = IngestionCoordinator(context: ctx, provider: MockDataProvider())
        let to = Date()
        let from = Calendar(identifier: .gregorian).date(byAdding: .day, value: -7, to: to)!

        let first = try await coord.sync(from: from, to: to)
        _ = try await coord.sync(from: from, to: to)
        let stored = try ctx.fetch(FetchDescriptor<GlucoseSample>()).count
        #expect(stored == first.glucose, "re-sync duplicated instead of replacing")
    }

    // MARK: - 2. The journal refuses to overwrite writing it cannot read

    @Test func journalSaveRefusesOverAnUnreadableFile() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("journal.v1.json")

        // Not valid JSON for [JournalEntry] — the shape a partial write, a
        // model change, or file protection produces.
        try Data("{ not a journal }".utf8).write(to: file)
        let corruptBytes = try Data(contentsOf: file)

        let entry = JournalEntry(body: "the one note they just typed")
        let saved = JournalStore.save([entry], to: file)

        #expect(saved == false, "the save reported success while refusing")
        #expect(try Data(contentsOf: file) == corruptBytes,
                "the unreadable file was overwritten — everything previously written is gone")
    }

    @Test func journalSaveStillWritesWhenThereIsNoFileYet() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("journal.v1.json")

        let entry = JournalEntry(body: "first entry")
        #expect(JournalStore.save([entry], to: file))
        #expect(JournalStore.load(from: file)?.count == 1)

        // …and a normal subsequent save still replaces a readable file.
        let second = JournalEntry(body: "second entry")
        #expect(JournalStore.save([entry, second], to: file))
        #expect(JournalStore.load(from: file)?.count == 2)
    }

    // MARK: - 3. Context flags tell absent from unreadable

    @Test func contextFlagStoreDistinguishesAbsentFromUnreadable() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("flags.json")

        #expect(ContextFlagStore.loadOutcome(from: file) == .absent)

        let flag = ContextFlag(kind: .travelling, startedOn: Date(), note: "Lisbon")
        ContextFlagStore.save([flag], to: file)
        guard case .loaded(let back) = ContextFlagStore.loadOutcome(from: file) else {
            Issue.record("a saved file should read back as .loaded"); return
        }
        #expect(back.count == 1)

        try Data("not flags".utf8).write(to: file)
        #expect(ContextFlagStore.loadOutcome(from: file) == .unreadable)
    }

    @Test func contextFlagSaveRefusesOverAnUnreadableFile() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("flags.json")

        try Data("not flags".utf8).write(to: file)
        let corruptBytes = try Data(contentsOf: file)

        // The clobber: an empty in-memory list (the seed a failed read leaves)
        // plus the stretch the citizen just marked.
        let fresh = ContextFlag(kind: .unwell, startedOn: Date(), note: nil)
        ContextFlagStore.save([fresh], to: file)

        #expect(try Data(contentsOf: file) == corruptBytes,
                "marking one day overwrote every stretch already on disk")
    }
}
