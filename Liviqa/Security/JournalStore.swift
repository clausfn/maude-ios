// JournalStore.swift — device-local persistence for the private journal.
//
// The journal is the user's own free-text record (MVP scope). It is stored as
// JSON in Application Support with NSFileProtectionComplete, so iOS encrypts it
// at rest whenever the device is locked. It NEVER leaves the device — there is no
// upload path here (consistent with the on-device-by-default principle).
//
// Self-contained on purpose: no SwiftData schema dependency, no AppState coupling.
import Foundation

enum JournalStore {
    /// Default on-device location (Application Support/journal.v1.json).
    static func defaultURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("journal.v1.json")
    }

    /// Loaded entries, or nil if nothing has been saved yet (first launch) or the
    /// file is unreadable — callers fall back to their starting set. `url` is
    /// injectable so tests can round-trip a temp file without touching the app store.
    static func load(from url: URL? = JournalStore.defaultURL()) -> [JournalEntry]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([JournalEntry].self, from: data)
    }

    /// Atomically persist the journal, file-protected (encrypted at rest when the
    /// device is locked). Failures are swallowed — journaling must never crash.
    static func save(_ entries: [JournalEntry], to url: URL? = JournalStore.defaultURL()) {
        guard let url, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
