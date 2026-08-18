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

    /// What a restore attempt actually found. `unreadable` is the case the
    /// 10.103 field bug ("my goals and ranges get deleted") hid inside nil:
    /// this file carries NSFileProtectionComplete, so whenever iOS launches the
    /// app in the background while the phone is LOCKED (BGAppRefresh wake,
    /// HealthKit background delivery, prewarming) the file EXISTS but cannot
    /// be read. Treating that as "never saved" seeded an empty profile over
    /// the citizen's edits — and the next Save (an atomic rename, which does
    /// not care that the old file was read-locked) clobbered the store.
    /// BackgroundRefresh.swift already refuses to run its gate on exactly this
    /// ground ("an unreadable gate would silently become NO gate"); the same
    /// discipline applies here: an unreadable profile is NOT an absent one.
    enum LoadOutcome: Equatable {
        case loaded(HealthContext)  // the stored profile
        case absent                 // nothing ever saved — a cold-start seed is honest
        case unreadable             // a file EXISTS but cannot be read/decoded NOW — never fall back to a seed
    }

    /// The stored profile, distinguished from "nothing there" and "there, but
    /// locked/corrupt right now". `url` injectable for tests.
    static func loadOutcome(from url: URL? = HealthContextStore.defaultURL()) -> LoadOutcome {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return .absent }
        guard let data = try? Data(contentsOf: url),
              let context = try? JSONDecoder().decode(HealthContext.self, from: data) else {
            return .unreadable
        }
        return .loaded(context)
    }

    /// The stored profile, or nil when nothing was ever saved (callers keep
    /// their cold-start seed then). Collapses `unreadable` into nil — restore
    /// paths that must not clobber use `loadOutcome` instead.
    static func load(from url: URL? = HealthContextStore.defaultURL()) -> HealthContext? {
        if case .loaded(let context) = loadOutcome(from: url) { return context }
        return nil
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
