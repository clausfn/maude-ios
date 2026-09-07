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
        guard case .loaded(let flags) = loadOutcome(from: url) else { return nil }
        return flags
    }

    /// What a read actually found. `absent` and `unreadable` are DIFFERENT
    /// facts and the app must never collapse them: the file is written with
    /// `.completeFileProtection`, so a background launch on a locked phone
    /// reads nothing — and treating that as "never marked" loses every context
    /// stretch the citizen recorded the moment they mark the next one. Same
    /// discipline as `HealthContextStore.LoadOutcome`, which exists because
    /// this exact shape destroyed goals and ranges in the field (10.103).
    enum LoadOutcome: Equatable {
        case loaded([ContextFlag])
        case absent
        case unreadable
    }

    static func loadOutcome(from url: URL? = ContextFlagStore.defaultURL()) -> LoadOutcome {
        guard let url else { return .absent }
        guard FileManager.default.fileExists(atPath: url.path) else { return .absent }
        guard let data = try? Data(contentsOf: url),
              let flags = try? JSONDecoder().decode([ContextFlag].self, from: data)
        else { return .unreadable }
        return .loaded(flags)
    }

    /// Atomically persist, file-protected. Failures are swallowed — marking a
    /// day must never crash the app.
    static func save(_ flags: [ContextFlag], to url: URL? = ContextFlagStore.defaultURL()) {
        guard let url, let data = try? JSONEncoder().encode(flags) else { return }
        // FAIL CLOSED: never write over a file that exists but cannot be read
        // right now — that is the citizen's own record of travelling / unwell /
        // off-routine stretches, and the in-memory list we would be writing is
        // the empty seed a failed read produced.
        if case .unreadable = loadOutcome(from: url) { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Remove the file entirely (GDPR erase path).
    static func delete(at url: URL? = ContextFlagStore.defaultURL()) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
