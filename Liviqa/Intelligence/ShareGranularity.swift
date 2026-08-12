// ShareGranularity.swift — the consent surface's EXPLICIT detail level.
// Pure Foundation, no SwiftUI, no I/O.
//
// WHY THIS EXISTS (fragility found by T-PRO-01, 2026-08-13):
// the "summaries only" guarantee the share screens print is currently true
// because `LiviqaBackendService.createGrant` fills `granularity` in with a
// `?? summary` default two layers below the consent surface — the screens pass
// nothing and trust it. That default is the only thing standing between the
// promise on screen and a wider grant on the wire; a refactor of it would widen
// every share silently, with no screen changing a word.
//
// So the map is named here, once, and the consent copy is DERIVED from the same
// map that the consent surface requests. Copy and payload cannot drift apart:
// if a future detail level is ever introduced, `isSummariesOnly` goes false and
// the screen stops printing "summaries only" on its own.
//
// Rail: FR-SHARE-02 / DerivedShareBuilder — the packager can only build derived
// summaries, so `summary` is the only level Liviqa is able to honour today.
import Foundation

enum ShareGranularity {
    /// The only detail level Liviqa can actually package (FR-SHARE-02).
    static let summary = "summary"

    /// The explicit per-group map for a consented set of areas.
    /// Empty in → empty out (nothing consented, nothing requested).
    static func summariesOnly(for groups: Set<String>) -> [String: String] {
        Dictionary(uniqueKeysWithValues: groups.map { ($0, summary) })
    }

    /// True only when EVERY consented group is at summary level. An empty map
    /// is not a promise about anything, so it is not "summaries only" either.
    static func isSummariesOnly(_ granularity: [String: String]) -> Bool {
        !granularity.isEmpty && granularity.values.allSatisfy { $0 == summary }
    }

    /// Suffix the area list carries on the consent surfaces. Derived, never typed.
    static func areaSuffix(_ granularity: [String: String]) -> String {
        isSummariesOnly(granularity)
            ? String(localized: " — summaries only")
            : String(localized: " — mixed detail")
    }

    /// The consent surface's own sentence about detail level.
    static func label(_ granularity: [String: String]) -> String {
        isSummariesOnly(granularity)
            ? String(localized: "Summary for every area — never your individual readings")
            : String(localized: "Mixed — check each area before you share")
    }
}
