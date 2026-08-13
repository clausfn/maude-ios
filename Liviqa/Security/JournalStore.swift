// JournalStore.swift — ACCOUNT-scoped, device-local persistence for the private journal.
//
// The journal is the user's own free-text record (MVP scope). It is stored as
// JSON in Application Support with NSFileProtectionComplete, so iOS encrypts it
// at rest whenever the device is locked. It NEVER leaves the device from here —
// there is no upload path in this file (the opt-in `/journal` sync is a separate,
// consented surface).
//
// FR-JRNL-SCOPE-01 (2026-08-13 data-honesty incident). Until 10.101 the file was
// `Application Support/journal.v1.json` — one file per DEVICE. Every account that
// signed in on a phone read the same file, so a new account opened the previous
// person's journal. The store is now namespaced per ACCOUNT, following the shape
// `EncryptedAnchorStore` already uses for the vault (SHA-256 of the scope picks
// the directory, so the id never appears raw on disk and cannot traverse paths) —
// except the scope here is the signed-in ACCOUNT id, not the device-local one,
// because the leak being closed is between accounts on one device.
//
//   <Application Support>/journal/<sha256(accountID)>/journal.v1.json
//
// Consequences, by construction:
//   • no account id ⇒ no path ⇒ nothing is readable and nothing is written;
//   • an account with no file starts EMPTY — never with someone else's entries;
//   • sign-out needs to delete nothing: the next account cannot address the
//     previous account's path (and no writing is destroyed).
//
// FR-JRNL-SEED-01: the store also refuses to persist — and strips on read — the
// three demo bodies a pre-gate build wrote into the device file. The match is
// EXACT (whole trimmed body) against our own strings, so a citizen who wrote
// about their own 6.2 fasting glucose keeps every word they typed.
//
// Self-contained on purpose: no SwiftData schema dependency, no AppState coupling.
import Foundation
import CryptoKit

enum JournalStore {

    // MARK: - Locations

    /// Application Support (created on demand). nil only if the OS refuses it.
    static func baseDirectory(fileManager: FileManager = .default) -> URL? {
        try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                             appropriateFor: nil, create: true)
    }

    /// PRE-10.101 location — one journal per DEVICE. Nothing reads this for
    /// display any more: it exists so `migrateLegacyIfNeeded` can adopt an
    /// existing citizen's entries into their account scope.
    static func legacyURL(base: URL? = JournalStore.baseDirectory()) -> URL? {
        base?.appendingPathComponent("journal.v1.json")
    }

    /// The account-scoped journal file. `accountID` is the signed-in user id;
    /// it is hashed into the directory name, never written raw.
    static func url(forAccount accountID: String,
                    base: URL? = JournalStore.baseDirectory()) -> URL? {
        guard let base, !accountID.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return base
            .appendingPathComponent("journal", isDirectory: true)
            .appendingPathComponent(scopeHash(accountID), isDirectory: true)
            .appendingPathComponent("journal.v1.json")
    }

    /// SHA-256 hex of the scope — same discipline as `EncryptedAnchorStore`: the
    /// account id never lands on disk in the clear and can't traverse paths.
    /// (It is a namespace, not a secret: hashing does not make one account's
    /// file unreadable to code that knows the other account's id.)
    static func scopeHash(_ scope: String) -> String {
        SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Legacy demo seeds (FR-JRNL-SEED-01)

    /// The EXACT bodies of the three demo entries that `JournalView.demoSeed`
    /// used to write into the device store before the seeding gate existed.
    ///
    /// This is a REMOVAL denylist, never a seed: nothing in this file (or any
    /// non-DEBUG code) constructs a `JournalEntry` from these strings, and
    /// `JournalSeedPostureTests` proves both halves — that these are the app's
    /// own seed bodies verbatim, and that they can only be *created* inside
    /// `#if DEBUG`.
    static let legacyDemoSeedBodies: [String] = [
        "Woke up with a 6.2 fasting. Evening walk yesterday clearly helped — second night in a row inside range by morning.",
        "Late dinner at 21:00 — curious if it shows up in deep sleep tonight. Slight stiffness in legs after the longer walk.",
        "Good day overall. Managed 42 active minutes despite the air quality alert. Skipped outdoor route, did indoor cycling instead.",
    ]

    /// EXACT whole-body match (trimmed) against our own seed strings. Substring
    /// matching is deliberately NOT used: a citizen writing "my 6.2 fasting was
    /// the best yet" must keep their entry.
    static func isLegacyDemoSeed(_ entry: JournalEntry) -> Bool {
        let body = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacyDemoSeedBodies.contains(body)
    }

    /// Drop the app's own demo bodies, keep everything else untouched and in
    /// order. Idempotent — running it twice changes nothing.
    static func purgingLegacyDemoSeeds(_ entries: [JournalEntry]) -> [JournalEntry] {
        entries.filter { !isLegacyDemoSeed($0) }
    }

    // MARK: - Primitives (URL-injectable, for tests and for the scoped API)

    /// Decode whatever is at `url`, exactly as stored. Private so no caller can
    /// accidentally surface a demo seed that is still on disk.
    private static func decode(at url: URL?) -> [JournalEntry]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([JournalEntry].self, from: data)
    }

    /// Loaded entries, or nil if nothing has been saved yet (first launch) or the
    /// file is unreadable — callers fall back to their starting set. Legacy demo
    /// seeds are stripped on the way out. `url` is injectable (and has NO device
    /// default: an unscoped read is exactly the defect this file removes).
    static func load(from url: URL?) -> [JournalEntry]? {
        guard let raw = decode(at: url) else { return nil }
        return purgingLegacyDemoSeeds(raw)
    }

    /// Atomically persist the journal, file-protected (encrypted at rest when the
    /// device is locked). Failures are swallowed — journaling must never crash.
    /// The app's own demo bodies are never written, in ANY configuration: that is
    /// what let a DEBUG seed become a citizen's "own" entry in the first place.
    @discardableResult
    static func save(_ entries: [JournalEntry], to url: URL?) -> Bool {
        guard let url else { return false }
        let clean = purgingLegacyDemoSeeds(entries)
        guard let data = try? JSONEncoder().encode(clean) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }

    // MARK: - Account-scoped API (what the app uses)

    /// Read one account's journal. nil ⇒ that account has never saved anything.
    static func load(forAccount accountID: String,
                     base: URL? = JournalStore.baseDirectory()) -> [JournalEntry]? {
        load(from: url(forAccount: accountID, base: base))
    }

    /// Write one account's journal.
    @discardableResult
    static func save(_ entries: [JournalEntry], forAccount accountID: String,
                     base: URL? = JournalStore.baseDirectory()) -> Bool {
        save(entries, to: url(forAccount: accountID, base: base))
    }

    /// THE entry point for the journal surface: migrate the pre-10.101 device
    /// file into this account's scope if it is still there, strip any demo seed
    /// left on disk (rewriting the file once so the cleanup is permanent), and
    /// return what the citizen actually wrote. An account with nothing of its
    /// own gets `[]` — never another account's entries.
    static func openForAccount(_ accountID: String,
                               base: URL? = JournalStore.baseDirectory(),
                               defaults: UserDefaults = .standard) -> [JournalEntry] {
        migrateLegacyIfNeeded(accountID: accountID, base: base, defaults: defaults)
        guard let scoped = url(forAccount: accountID, base: base),
              let raw = decode(at: scoped) else { return [] }
        let clean = purgingLegacyDemoSeeds(raw)
        if clean.count != raw.count { save(clean, to: scoped) }   // one-time, idempotent
        return clean
    }

    /// Erase ONE account's journal directory — the GDPR "delete all my data"
    /// path (T-DEL-01) and nothing else. Never touches another scope: another
    /// account's entries are another person's writing.
    static func eraseAccount(_ accountID: String,
                             base: URL? = JournalStore.baseDirectory(),
                             fileManager: FileManager = .default) {
        guard let file = url(forAccount: accountID, base: base) else { return }
        try? fileManager.removeItem(at: file.deletingLastPathComponent())
    }

    // MARK: - Legacy migration (FR-JRNL-SCOPE-01)

    enum LegacyMigration: Equatable {
        /// No pre-10.101 file to consider (or this account already has a journal).
        case notNeeded
        /// This account already adopted-or-declined the legacy file.
        case alreadyConsidered
        /// The legacy entries now live in this account's scope (count after purge).
        case adopted(Int)
        /// The legacy file names a DIFFERENT account as author — left untouched
        /// on disk so its rightful owner can still adopt it, and not shown here.
        case declinedForeignAuthor
        /// Nothing could be read or written; the legacy file is left exactly as is.
        case failed
    }

    /// UserDefaults marker key — per ACCOUNT, so declining for one account never
    /// blocks the rightful account from adopting later.
    static func migrationMarkerKey(_ accountID: String) -> String {
        "liviqa.journal.legacyConsidered.\(scopeHash(accountID))"
    }

    /// Adopt the pre-10.101 device-scoped journal into `accountID`'s scope, once.
    ///
    /// SAFETY ARGUMENT (why this cannot lose a citizen's writing):
    ///   1. it runs only when this account has NO scoped journal — an existing
    ///      journal is never overwritten;
    ///   2. an unreadable/corrupt legacy file is left exactly where it is
    ///      (`.failed`) rather than being rewritten or removed;
    ///   3. the legacy file is removed ONLY after the adopted entries have been
    ///      written to the new path AND read back and counted there. The writing
    ///      is moved, never deleted;
    ///   4. entries authored by a different account (`userId` set to someone
    ///      else) are never adopted, and in that case the legacy file is left
    ///      intact for whoever wrote it.
    @discardableResult
    static func migrateLegacyIfNeeded(accountID: String,
                                      base: URL? = JournalStore.baseDirectory(),
                                      defaults: UserDefaults = .standard,
                                      fileManager: FileManager = .default) -> LegacyMigration {
        guard let scoped = url(forAccount: accountID, base: base),
              let legacy = legacyURL(base: base) else { return .failed }
        let marker = migrationMarkerKey(accountID)
        if defaults.bool(forKey: marker) { return .alreadyConsidered }
        guard fileManager.fileExists(atPath: legacy.path) else { return .notNeeded }
        guard !fileManager.fileExists(atPath: scoped.path) else { return .notNeeded }
        guard let legacyEntries = decode(at: legacy) else { return .failed }

        // Authorship gate: adopt only when nothing in the file names someone else.
        // (Local entries carry no author at all; only sync-mapped ones do.)
        let account = UUID(uuidString: accountID)
        let foreign = legacyEntries.contains { entry in
            guard let owner = entry.userId else { return false }
            return owner != account
        }
        if foreign {
            defaults.set(true, forKey: marker)
            return .declinedForeignAuthor
        }

        let adopted = purgingLegacyDemoSeeds(legacyEntries)
        guard save(adopted, to: scoped),
              let verified = decode(at: scoped), verified.count == adopted.count else {
            return .failed                       // legacy file untouched
        }
        defaults.set(true, forKey: marker)
        try? fileManager.removeItem(at: legacy)  // the entries now live in `scoped`
        return .adopted(adopted.count)
    }
}
