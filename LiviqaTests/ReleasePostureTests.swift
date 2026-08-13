import Testing
import Foundation
@testable import Liviqa

// T1 TestProd wave — RELEASE CONFIG IS TESTPROD.
//
// Source-level lint of the `#if DEBUG` posture gates: demo logins, LV001/mock
// seeding, the retired sandbox wallet-rail detour. Unit tests always compile in
// Debug, so Release-only values can't be observed directly — instead these
// tests read the SOURCE and verify the gates are in place, failing the test
// run (not a review) on regression. The runtime half is
// `ReleasePosture.verify()`, executed at every Release launch.
struct ReleasePostureTests {

    // MARK: - Source access

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // LiviqaTests/
        .deletingLastPathComponent()   // repo root

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Per-line flag: the line is compiled ONLY in DEBUG builds (inside an
    /// active `#if DEBUG` branch). Minimal conditional-compilation walker —
    /// handles `#if DEBUG`, `#if !DEBUG`, `#else`, `#elseif`, `#endif`.
    private func debugOnlyLineFlags(_ src: String) -> [Bool] {
        enum Branch { case debugOnly, releaseOnly, other }
        var stack: [Branch] = []
        var flags: [Bool] = []
        for raw in src.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                let cond = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                if cond == "DEBUG" { stack.append(.debugOnly) }
                else if cond == "!DEBUG" { stack.append(.releaseOnly) }
                else { stack.append(.other) }
            } else if line.hasPrefix("#elseif") {
                if !stack.isEmpty { stack[stack.count - 1] = .other }
            } else if line.hasPrefix("#else") {
                if let top = stack.last {
                    stack[stack.count - 1] = top == .debugOnly ? .releaseOnly
                                           : top == .releaseOnly ? .debugOnly : .other
                }
            } else if line.hasPrefix("#endif") {
                _ = stack.popLast()
            }
            flags.append(stack.contains(.debugOnly))
        }
        return flags
    }

    /// Every line containing (or, with `wholeLine`, exactly equal after
    /// trimming to) `marker` must be DEBUG-only compiled.
    private func expectDebugGated(file: String, marker: String, wholeLine: Bool = false,
                                  sourceLocation: SourceLocation = #_sourceLocation) throws {
        let src = try source(file)
        let flags = debugOnlyLineFlags(src)
        let lines = src.components(separatedBy: "\n")
        var found = false
        for (i, raw) in lines.enumerated() {
            let hit = wholeLine
                ? raw.trimmingCharacters(in: .whitespaces) == marker
                : raw.contains(marker)
            guard hit else { continue }
            found = true
            #expect(flags[i],
                    "\(file):\(i + 1) — '\(marker)' must sit inside #if DEBUG",
                    sourceLocation: sourceLocation)
        }
        #expect(found, "\(file) — expected to find '\(marker)' (gate lint is stale?)",
                sourceLocation: sourceLocation)
    }

    // MARK: - Config gates

    @Test func simulatedLoginsAreDebugGated() throws {
        try expectDebugGated(file: "Liviqa/Config.swift", marker: "dfgWalletLoginEnabled = true")
        try expectDebugGated(file: "Liviqa/Config.swift", marker: "nationalIDLoginEnabled = true")
    }

    @Test func backendDefaultsToSovereignProdInRelease() throws {
        let src = try source("Liviqa/Config.swift")
        // The default (no env override) branch must be: DEBUG → .mock,
        // Release → sovereignProd. (`case "mock": return .mock` above it is
        // the LIVIQA_BACKEND env hook — local QA only, unreachable on
        // TestFlight installs, checked by ReleasePosture.verify at runtime.)
        let pattern = #"#if DEBUG\s*\n\s*return \.mock[^\n]*\n\s*#else\s*\n\s*return sovereignProd"#
        #expect(src.range(of: pattern, options: .regularExpression) != nil,
                "Config.backend default must be DEBUG→.mock / Release→sovereignProd")
    }

    @Test func sandboxWalletRailDetourIsRetired() throws {
        let src = try source("Liviqa/Config.swift")
        // The hard-coded sandbox container host must be gone entirely (T1 step 1).
        #expect(!src.contains("fnc.fr-par.scw.cloud"),
                "Config.swift — sandbox wallet-rail host has returned")
        // The local-dev override env READ is DEBUG-only (the doc comment above
        // the property may mention the variable name — only the code counts).
        try expectDebugGated(file: "Liviqa/Config.swift",
                             marker: #"environment["LIVIQA_WALLET_RAIL_URL"]"#)
    }

    @Test func walletRailRidesMainBackendByDefault() {
        // Runtime check (valid in any configuration when the env override is unset).
        guard ProcessInfo.processInfo.environment["LIVIQA_WALLET_RAIL_URL"] == nil else { return }
        #expect(Config.walletRailBaseURL == nil)
    }

    // MARK: - Demo/mock seeding gates

    @Test func lv001InjectionIsDebugGated() throws {
        try expectDebugGated(file: "Liviqa/AppState.swift", marker: "LV001Dataset.passportStats")
    }

    @Test func mockWalletSeedingIsDebugGated() throws {
        // signInDemo seeds + loadWallet fallback — every reference gated.
        try expectDebugGated(file: "Liviqa/AppState.swift", marker: "MockData.walletGrants")
        try expectDebugGated(file: "Liviqa/AppState.swift", marker: "MockData.walletEvents")
        try expectDebugGated(file: "Liviqa/AppState.swift", marker: "MockData.demoStudy")
    }

    @Test func coldStartSeedsAreEmptyInRelease() throws {
        // Every MockData reference in the seed table must be DEBUG-only.
        try expectDebugGated(file: "Liviqa/ColdStartSeeds.swift", marker: "MockData.")
    }

    @Test func demoLoginButtonIsDebugGated() throws {
        try expectDebugGated(file: "Liviqa/Views/AuthView.swift", marker: "appState.signInDemo()")
    }

    @Test func journalAndVaultDemoSeedsAreDebugGated() throws {
        // 2026-08-13: the seed no longer sits behind an `initialSeed` indirection
        // (the whole-line marker), so the check is now the STRONGER one — EVERY
        // line mentioning demoSeed must be DEBUG-compiled. Deeper posture (the
        // seed can't be persisted or read back) is `JournalSeedPostureTests`.
        try expectDebugGated(file: "Liviqa/Views/JournalView.swift", marker: "demoSeed")
        try expectDebugGated(file: "Liviqa/Views/JournalView.swift", marker: "VaultDocument.demo")
    }

    @Test func privacyProofSheetHasNoDemoGrants() throws {
        // Area ⑥ (2026-08-12) upgraded the posture: the proof sheet mirrors the
        // REAL grant store — the DEBUG-only demo grants are gone entirely. Guard
        // the stronger invariant: the demo type must never come back here.
        let src = try source("Liviqa/Views/InAppPrivacyView.swift")
        #expect(!src.contains("PrivacyGrant.demo"),
                "InAppPrivacyView must mirror real grants — no demo-grant seeds, even DEBUG-gated")
    }

    @Test func providerForcingIsDebugGated() throws {
        // A Release binary must never be steerable onto the mock data provider —
        // the -uiTestAutoDemo / LIVIQA_DATA forcing branches in the provider
        // resolver are compiled out of Release (Phase 0 audit fix, 2026-08-12).
        try expectDebugGated(file: "Liviqa/AppState.swift",
                             marker: #"arguments.contains("-uiTestAutoDemo")"#)
        try expectDebugGated(file: "Liviqa/AppState.swift",
                             marker: #"env["LIVIQA_DATA"] == "mock""#)
    }

    // MARK: - Runtime verifier is wired

    @Test func releasePostureVerifyRunsAtLaunch() throws {
        let app = try source("Liviqa/LiviqaApp.swift")
        #expect(app.contains("ReleasePosture.verify()"),
                "LiviqaApp must call ReleasePosture.verify() at startup")
    }
}
