// ContextFlagStore.swift — device-local persistence for FR-CTX-04 context flags.
//
// Same shape and same promises as JournalStore / PMSOutboxStore: JSON in
// Application Support with NSFileProtectionComplete, so iOS encrypts it at rest
// whenever the device is locked. It NEVER leaves the device — there is no
// upload path here, and no share/export DTO carries a context flag.
//
// The user's optional note is their own words about their own life, so it is
// personal data: `AppState.deleteAllData` removes this file alongside the
// journal and the PMS outbox.
//
// Self-contained on purpose: no SwiftData schema dependency, no AppState coupling.
import Foundation

enum ContextFlagStore {

    /// Default on-device location (Application Support/context-flags.v1.json).
    static func defaultURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("context-flags.v1.json")
    }

    /// Loaded flags, or nil when nothing has been marked yet (or the file is
    /// unreadable) — callers fall back to an empty set, never to a fabricated
    /// one. `url` is injectable so tests round-trip a temp file.
    static func load(from url: URL? = ContextFlagStore.defaultURL()) -> [ContextFlag]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([ContextFlag].self, from: data)
    }

    /// Atomically persist, file-protected. Failures are swallowed — marking a
    /// day must never crash the app.
    static func save(_ flags: [ContextFlag], to url: URL? = ContextFlagStore.defaultURL()) {
        guard let url, let data = try? JSONEncoder().encode(flags) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Remove the file entirely (GDPR erase path).
    static func delete(at url: URL? = ContextFlagStore.defaultURL()) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
