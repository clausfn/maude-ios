import Testing
import Foundation
@testable import Liviqa

// FR-JRNL-SCOPE-01 / FR-JRNL-SEED-01 — the 2026-08-13 data-honesty incident.
//
// Two defects, one store: the journal file was DEVICE-scoped (so a new account
// on a used phone opened the previous person's entries), and a pre-gate build
// had written three demo entries into it that then read as the citizen's own
// words.
//
// Everything here runs against an injected base directory and an injected
// UserDefaults suite — the app's real journal is never touched by the tests.
// @MainActor to match the project's default isolation.
@MainActor
struct JournalScopeTests {

    // MARK: - Fixtures

    private let accountA = "11111111-1111-1111-1111-111111111111"
    private let accountB = "22222222-2222-2222-2222-222222222222"

    private func makeBase() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-scope-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "journal-scope-\(UUID().uuidString)")!
    }

    private func entry(_ body: String, userId: UUID? = nil) -> JournalEntry {
        JournalEntry(id: UUID(), userId: userId, body: body, mood: nil, metrics: .empty,
                     tags: [], syncEnabled: false, createdAt: Date(), updatedAt: Date())
    }

    /// Write entries to a URL WITHOUT going through `JournalStore.save` — so a
    /// test can plant exactly what a June build left on disk (demo seeds and all).
    private func writeRaw(_ entries: [JournalEntry], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: url)
    }

    // MARK: - (a) Isolation between accounts

    @Test func oneAccountCanNeverReadAnothersJournal() {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }

        let mine = [entry("Walked the long way home. Legs tired, head clear.")]
        JournalStore.save(mine, forAccount: accountA, base: base)

        // B has never written anything → B sees nothing, and opens EMPTY.
        #expect(JournalStore.load(forAccount: accountB, base: base) == nil)
        #expect(JournalStore.openForAccount(accountB, base: base, defaults: defs).isEmpty)
        // A still has every word.
        #expect(JournalStore.load(forAccount: accountA, base: base) == mine)
        // Different scopes ⇒ different files, and the id is not on disk in the clear.
        let aURL = JournalStore.url(forAccount: accountA, base: base)
        let bURL = JournalStore.url(forAccount: accountB, base: base)
        #expect(aURL != bURL)
        #expect(!(aURL?.path.contains(accountA) ?? true))
    }

    @Test func bothAccountsKeepTheirOwnEntries() {
        let base = makeBase()
        defer { try? FileManager.default.removeItem(at: base) }

        let a = [entry("A's morning note.")]
        let b = [entry("B's evening note."), entry("B's second note.")]
        JournalStore.save(a, forAccount: accountA, base: base)
        JournalStore.save(b, forAccount: accountB, base: base)

        #expect(JournalStore.load(forAccount: accountA, base: base) == a)
        #expect(JournalStore.load(forAccount: accountB, base: base) == b)
    }

    @Test func noAccountIdMeansNoPathAndNoWrite() {
        let base = makeBase()
        defer { try? FileManager.default.removeItem(at: base) }

        #expect(JournalStore.url(forAccount: "", base: base) == nil)
        #expect(JournalStore.url(forAccount: "   ", base: base) == nil)
        #expect(JournalStore.save([entry("nowhere")], forAccount: "", base: base) == false)
        #expect(JournalStore.load(forAccount: "", base: base) == nil)
    }

    // MARK: - (b) Migration preserves an existing citizen's entries

    @Test func legacyDeviceFileIsAdoptedIntoTheSignedInAccountScope() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))

        let real = [entry("Blood test tomorrow — fasting from 22:00."),
                    entry("Knee felt better on the flat route.")]
        try writeRaw(real, to: legacy)

        let opened = JournalStore.openForAccount(accountA, base: base, defaults: defs)

        #expect(opened == real)                                    // nothing lost
        #expect(JournalStore.load(forAccount: accountA, base: base) == real)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))  // moved, not copied
    }

    @Test func afterAdoptionTheNextAccountStartsEmpty() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))
        try writeRaw([entry("Only I wrote this.")], to: legacy)

        _ = JournalStore.openForAccount(accountA, base: base, defaults: defs)
        let second = JournalStore.openForAccount(accountB, base: base, defaults: defs)

        #expect(second.isEmpty)
    }

    @Test func migrationNeverOverwritesAJournalTheAccountAlreadyHas() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))

        let owned = [entry("Mine, written after the update.")]
        JournalStore.save(owned, forAccount: accountA, base: base)
        try writeRaw([entry("Older, unattributed.")], to: legacy)

        let outcome = JournalStore.migrateLegacyIfNeeded(accountID: accountA, base: base, defaults: defs)

        #expect(outcome == .notNeeded)
        #expect(JournalStore.load(forAccount: accountA, base: base) == owned)
        #expect(FileManager.default.fileExists(atPath: legacy.path))   // left for its owner
    }

    @Test func migrationIsIdempotent() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))
        let real = [entry("One entry, adopted once.")]
        try writeRaw(real, to: legacy)

        let first  = JournalStore.migrateLegacyIfNeeded(accountID: accountA, base: base, defaults: defs)
        let second = JournalStore.migrateLegacyIfNeeded(accountID: accountA, base: base, defaults: defs)
        let third  = JournalStore.openForAccount(accountA, base: base, defaults: defs)

        #expect(first == .adopted(1))
        #expect(second == .alreadyConsidered)
        #expect(third == real)
    }

    @Test func entriesAuthoredByAnotherAccountAreNotAdopted() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))
        let owner = UUID(uuidString: accountB)!
        let theirs = [entry("Their words, their account.", userId: owner)]
        try writeRaw(theirs, to: legacy)

        let declined = JournalStore.migrateLegacyIfNeeded(accountID: accountA, base: base, defaults: defs)

        #expect(declined == .declinedForeignAuthor)
        #expect(JournalStore.openForAccount(accountA, base: base, defaults: defs).isEmpty)
        #expect(FileManager.default.fileExists(atPath: legacy.path))   // preserved…
        // …and the account that DID write them can still adopt them.
        #expect(JournalStore.openForAccount(accountB, base: base, defaults: defs) == theirs)
    }

    @Test func anUnreadableLegacyFileIsLeftExactlyAsItIs() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))
        let garbage = Data("{ not a journal".utf8)
        try garbage.write(to: legacy)

        let outcome = JournalStore.migrateLegacyIfNeeded(accountID: accountA, base: base, defaults: defs)

        #expect(outcome == .failed)
        #expect(try Data(contentsOf: legacy) == garbage)   // byte-for-byte untouched
    }

    // MARK: - Purge (FR-JRNL-SEED-01)

    @Test func migrationDropsTheDemoSeedsAndKeepsEverythingElse() throws {
        let base = makeBase(); let defs = makeDefaults()
        defer { try? FileManager.default.removeItem(at: base) }
        let legacy = try #require(JournalStore.legacyURL(base: base))

        let seeds = JournalStore.legacyDemoSeedBodies.map { entry($0) }
        let ownWords = entry("Woke up with a 6.2 fasting this morning — best week yet.")
        try writeRaw([seeds[0], ownWords, seeds[1], seeds[2]], to: legacy)

        let opened = JournalStore.openForAccount(accountA, base: base, defaults: defs)

        #expect(opened == [ownWords])                       // only OUR strings removed
        #expect(JournalStore.load(forAccount: accountA, base: base) == [ownWords])  // cleanup persisted
    }

    @Test func purgeMatchesWholeBodiesOnlyNeverFragments() {
        let seed = JournalStore.legacyDemoSeedBodies[0]
        let citizenOwnWords = [
            entry("Woke up with a 6.2 fasting."),                       // a prefix of ours
            entry(seed + " Also: rain all day."),                       // ours plus their own
            entry("6.2 fasting again. Evening walk yesterday clearly helped."),
        ]
        let kept = JournalStore.purgingLegacyDemoSeeds(citizenOwnWords + [entry(seed)])
        #expect(kept == citizenOwnWords)
    }

    @Test func purgeIgnoresSurroundingWhitespaceOnOurOwnSeed() {
        let padded = entry("\n  " + JournalStore.legacyDemoSeedBodies[1] + "  \n")
        #expect(JournalStore.isLegacyDemoSeed(padded))
        #expect(JournalStore.purgingLegacyDemoSeeds([padded]).isEmpty)
    }

    @Test func purgeIsIdempotent() {
        let mixed = JournalStore.legacyDemoSeedBodies.map { entry($0) } + [entry("Mine.")]
        let once = JournalStore.purgingLegacyDemoSeeds(mixed)
        #expect(JournalStore.purgingLegacyDemoSeeds(once) == once)
    }

    @Test func aDemoSeedCanNeverBeWrittenToDisk() {
        let base = makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let mine = entry("A real note.")
        JournalStore.save(JournalStore.legacyDemoSeedBodies.map { entry($0) } + [mine],
                          forAccount: accountA, base: base)
        #expect(JournalStore.load(forAccount: accountA, base: base) == [mine])
    }

    @Test func seedsAlreadyOnDiskNeverReachTheReader() throws {
        let base = makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let url = try #require(JournalStore.url(forAccount: accountA, base: base))
        try writeRaw(JournalStore.legacyDemoSeedBodies.map { entry($0) }, to: url)

        #expect(JournalStore.load(from: url)?.isEmpty == true)
    }

    // MARK: - (c) Sign-out / erase

    @Test func eraseRemovesOnlyThatAccountsJournal() {
        let base = makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let a = [entry("A's note.")]
        let b = [entry("B's note.")]
        JournalStore.save(a, forAccount: accountA, base: base)
        JournalStore.save(b, forAccount: accountB, base: base)

        JournalStore.eraseAccount(accountA, base: base)

        #expect(JournalStore.load(forAccount: accountA, base: base) == nil)
        #expect(JournalStore.load(forAccount: accountB, base: base) == b)
    }

    @Test func signOutLeavesNothingAddressableAndDeletesNothing() async {
        let base = makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let state = AppState(supabase: MockSupabaseService())
        let signedIn = UUID(uuidString: accountA)!
        state.session = UserSession(userId: signedIn, email: "a@example.com")
        let mine = [entry("Written while signed in.")]
        JournalStore.save(mine, forAccount: state.journalAccountID ?? "", base: base)

        #expect(state.journalAccountID == signedIn.uuidString)
        await state.signOut()

        #expect(state.journalAccountID == nil)          // no scope ⇒ nothing readable
        #expect(state.journalEntries.isEmpty)           // dropped from memory
        // …and the writing itself is still there, sealed in its own scope.
        #expect(JournalStore.load(forAccount: signedIn.uuidString, base: base) == mine)
    }
}
