// DisplayNameResolution.swift — UC-01 · FR-ACC-NAME-01
//
// ONE pure function decides what the app may call a person.
//
// The incident (2026-08-13): the daily edition greeted internal testers with
// "Good morning, 75sg6pvfys." — the local-part of an Apple private-relay address
// that `/me` returns as `displayName`. The name the citizen typed in onboarding
// only applied when the backend value was EMPTY, so a placeholder beat a real,
// declared name.
//
// The rules, in order:
//   1. the name declared on this device (UC-01, `maude.profile.displayName`)
//      wins — it is what the citizen chose to be called, and it never left the
//      phone;
//   2. otherwise a backend `displayName` is used, but ONLY if it is a name:
//      anything containing "@" is an address, and anything equal to the
//      local-part of the account's own email is a placeholder, not a name.
//      This is not Apple-specific — any provider that echoes the mailbox name
//      is treated the same way;
//   3. otherwise NOTHING is known, and the caller greets without a name
//      ("Good morning.") rather than inventing one or showing an identifier.
//
// Pure Foundation, no state, no I/O — `DisplayNameResolutionTests` covers the
// table without a simulator.
import Foundation

enum DisplayNameResolution {

    /// The name to greet with, or nil when no name is known.
    /// - declared: the device-local name captured in onboarding.
    /// - backend:  whatever `/me` returned as `displayName`.
    /// - accountEmail: the signed-in account's own email, when known.
    nonisolated static func resolve(declared: String?,
                                    backend: String?,
                                    accountEmail: String?) -> String? {
        if let declared = trimmedNonEmpty(declared), !isEmailShaped(declared) {
            return declared
        }
        if let backend = trimmedNonEmpty(backend),
           !isPlaceholder(backend, accountEmail: accountEmail) {
            return backend
        }
        return nil
    }

    /// True when `candidate` is an identifier rather than a person's name.
    nonisolated static func isPlaceholder(_ candidate: String, accountEmail: String?) -> Bool {
        guard let value = trimmedNonEmpty(candidate) else { return true }
        // An address (or any fragment carrying a domain) is never a name.
        if isEmailShaped(value) { return true }
        // The mailbox name of the account's OWN address is a placeholder — this
        // is what private-relay sign-ins hand back.
        if let local = localPart(ofEmail: accountEmail),
           value.compare(local, options: .caseInsensitive) == .orderedSame {
            return true
        }
        return false
    }

    /// The part before "@" of an email address, when the string looks like one.
    nonisolated static func localPart(ofEmail email: String?) -> String? {
        guard let email = trimmedNonEmpty(email),
              let at = email.firstIndex(of: "@") else { return nil }
        return trimmedNonEmpty(String(email[email.startIndex..<at]))
    }

    // MARK: - Helpers

    nonisolated private static func isEmailShaped(_ value: String) -> Bool {
        value.contains("@")
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}
