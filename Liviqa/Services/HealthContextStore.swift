// HealthContextStore.swift — device-local persistence for the declared health
// profile (HealthContext) · A7.2 Area ⑧, 2026-08-12.
//
// The census found ProfileSheet edits were held only in AppState memory
// (seeded from ColdStart) — "Stays on device" was true, but so was "gone on
// relaunch". Same pattern as JournalStore: JSON in Application Support with
// NSFileProtectionComplete, no upload path, best-effort (a failing disk can
// never crash profile editing). Wiped by deleteAllData (GDPR erase) alongside
// the journal.
import Foundation

enum HealthContextStore {
    /// Default on-device location (Application Support/healthcontext.v1.json).
    static func defaultURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("healthcontext.v1.json")
    }

    /// The stored profile, or nil when nothing was ever saved (callers keep
    /// their cold-start seed then). `url` injectable for tests.
    static func load(from url: URL? = HealthContextStore.defaultURL()) -> HealthContext? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HealthContext.self, from: data)
    }

    /// Atomically persist, file-protected (encrypted at rest when locked).
    static func save(_ context: HealthContext, to url: URL? = HealthContextStore.defaultURL()) {
        guard let url, let data = try? JSONEncoder().encode(context) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Remove the stored profile (GDPR erase path).
    static func delete(at url: URL? = HealthContextStore.defaultURL()) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
