// ReleasePosture.swift — RELEASE CONFIG IS TESTPROD (operating decision, T1 wave).
//
// A Release/TestFlight build must NEVER:
//   • present fabricated (demo/LV001/mock) data as the user's own,
//   • expose simulated identity logins (DfG wallet / national eID / demo entry),
//   • talk to any host but the sovereign prod backend (api.liviqa.app) —
//     including the retired sandbox wallet-rail detour.
//
// Swift has no value-level static assert, so the posture is enforced in two
// layers that both fail BEFORE a human review could miss them:
//   1. This file: `#if !DEBUG` runtime preconditions executed at process start
//     (LiviqaApp.init). A regression crashes the very first Release launch —
//     it cannot survive a TestFlight smoke test.
//   2. `LiviqaTests/ReleasePostureTests.swift`: source-level lint of the
//     `#if DEBUG` gates (demo logins, LV001 injection, mock seeding, sandbox
//     rail host) — a regression fails the unit-test run in any configuration.
import Foundation

enum ReleasePosture {

    /// Call once at app start. No-op in DEBUG (demo builds are demo by design).
    static func verify() {
        #if !DEBUG
        // Simulated identity logins are compile-time false in Release (PR-102).
        precondition(Config.dfgWalletLoginEnabled == false,
                     "Release posture violation: DfG wallet simulated login enabled")
        precondition(Config.nationalIDLoginEnabled == false,
                     "Release posture violation: national-eID simulated login enabled")

        // Path A Connect Sundhed.dk embeds sundhed.dk in an in-app WebView — never in Release.
        precondition(Config.sundhedWebConnectEnabled == false,
                     "Release posture violation: in-app Sundhed.dk WebView enabled")

        // All rails ride the sovereign prod backend — no sandbox detour (T1).
        precondition(Config.walletRailBaseURL == nil,
                     "Release posture violation: wallet rail routed off the main backend")

        // Default backend (no env override) must be sovereign prod on liviqa.app.
        // `LIVIQA_BACKEND` env is a local-QA hook; TestFlight/App Store installs
        // cannot set process env, so the default IS the shipped behaviour.
        if ProcessInfo.processInfo.environment["LIVIQA_BACKEND"] == nil {
            if case .sovereign(let baseURL, let devToken, _) = Config.backend {
                precondition(baseURL.host == "api.liviqa.app",
                             "Release posture violation: backend is not api.liviqa.app")
                precondition(devToken == nil,
                             "Release posture violation: dev seed token in Release")
            } else {
                preconditionFailure("Release posture violation: non-sovereign backend in Release")
            }
        }
        #endif
    }
}
