// CalendarLoadStore.swift — device-local, ACCOUNT-scoped persistence for
// calendar DENSITY (FR-CTX-CAL-01). Numbers only; no event content exists to
// store, by construction (see CalendarLoad.swift).
//
// Scoping follows `JournalStore` exactly, and for the same reason (2026-08-13
// data-honesty incident, PR-111): a device-scoped file means the next account
// on a shared phone opens the previous person's readings. A calendar is one
// person's life — and, through their meetings, other people's — so it is
// scoped by the signed-in ACCOUNT:
//
//   <Application Support>/calendar-load/<sha256(accountID)>/calendar-load.v1.json
//
// Consequences, by construction:
//   • no account id ⇒ no path ⇒ nothing is written and nothing is readable;
//   • an account with no file starts EMPTY, never with someone else's days;
//   • `disconnect` deletes the file, so revoking really does remove what was
//     collected, not just stop collecting.
//
// There is NO upload path in this file and no share/export DTO carries a
// `CalendarDayLoad`. The donation export never sees it (its four streams are
// fixed and REAL-provenance HealthKit only).
import Foundation
import CryptoKit

/// The whole persisted record: the citizen's opt-in and the numbers.
struct CalendarLoadRecord: Codable, Equatable {
    var version: Int = 1
    /// When the citizen turned this on. Its presence IS the opt-in — there is
    /// no separate "enabled" default that could read true without a decision.
    var optedInAt: Date
    /// Rolling window, oldest first, at most `CalendarLoadDeriver.historyDays`.
    var days: [CalendarDayLoad]
}

enum CalendarLoadStore {

    // MARK: - Locations

    static func baseDirectory(fileManager: FileManager = .default) -> URL? {
        try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                             appropriateFor: nil, create: true)
    }

    /// SHA-256 hex of the scope — same discipline as `JournalStore`: the account
    /// id never lands on disk in the clear and cannot traverse paths. (A
    /// namespace, not a secret.)
    static func scopeHash(_ scope: String) -> String {
        SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func url(forAccount accountID: String,
                    base: URL? = CalendarLoadStore.baseDirectory()) -> URL? {
        guard let base, !accountID.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return base
            .appendingPathComponent("calendar-load", isDirectory: true)
            .appendingPathComponent(scopeHash(accountID), isDirectory: true)
            .appendingPathComponent("calendar-load.v1.json")
    }

    // MARK: - Read / write

    /// The account's record, or nil when the citizen has never turned this on
    /// (or the file is unreadable). Callers fall back to an honest empty state,
    /// never to a fabricated one.
    static func load(forAccount accountID: String?,
                     base: URL? = CalendarLoadStore.baseDirectory()) -> CalendarLoadRecord? {
        guard let accountID, let url = url(forAccount: accountID, base: base),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CalendarLoadRecord.self, from: data)
    }

    /// True only when this account has actually opted in AND a record exists.
    /// No literal, no default — the honest connected state (PR-111: Settings
    /// must never print a hardcoded "Connected").
    static func isOptedIn(forAccount accountID: String?,
                          base: URL? = CalendarLoadStore.baseDirectory()) -> Bool {
        load(forAccount: accountID, base: base) != nil
    }

    /// Record the citizen's opt-in with no days yet. Returns false when there is
    /// no account scope to write into (nothing is written in that case).
    @discardableResult
    static func optIn(forAccount accountID: String?, at date: Date = Date(),
                      base: URL? = CalendarLoadStore.baseDirectory()) -> Bool {
        guard let accountID else { return false }
        let existing = load(forAccount: accountID, base: base)
        return save(CalendarLoadRecord(optedInAt: existing?.optedInAt ?? date,
                                       days: existing?.days ?? []),
                    forAccount: accountID, base: base)
    }

    /// Replace the stored days, keeping the opt-in date. Refuses to create a
    /// record for an account that never opted in — collection cannot start by
    /// a write.
    @discardableResult
    static func replaceDays(_ days: [CalendarDayLoad], forAccount accountID: String?,
                            base: URL? = CalendarLoadStore.baseDirectory()) -> Bool {
        guard let accountID, var record = load(forAccount: accountID, base: base) else { return false }
        record.days = Array(days.sorted { $0.dayStart < $1.dayStart }
            .suffix(CalendarLoadDeriver.historyDays))
        return save(record, forAccount: accountID, base: base)
    }

    @discardableResult
    private static func save(_ record: CalendarLoadRecord, forAccount accountID: String,
                             base: URL? = CalendarLoadStore.baseDirectory()) -> Bool {
        guard let url = url(forAccount: accountID, base: base),
              let data = try? JSONEncoder().encode(record) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return true
        } catch { return false }
    }

    // MARK: - Revoke / erase

    /// Turning it off. Deletes the numbers as well as the opt-in, so nothing
    /// keeps being collected AND nothing collected stays behind.
    static func disconnect(forAccount accountID: String?,
                           base: URL? = CalendarLoadStore.baseDirectory()) {
        guard let accountID, let url = url(forAccount: accountID, base: base) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// GDPR erase path — removes every account's calendar-load scope on this
    /// device (the erase is asked for by the person holding the phone).
    static func eraseAll(base: URL? = CalendarLoadStore.baseDirectory()) {
        guard let base else { return }
        try? FileManager.default.removeItem(
            at: base.appendingPathComponent("calendar-load", isDirectory: true))
    }
}
