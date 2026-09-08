// ReleasePosture.swift — RELEASE CONFIG IS TESTPROD (operating decision, T1 wave).
//
// A Release/TestFlight build must NEVER:
//   • present fabricated (demo/LV001/mock) data as the user's own,
//   • expose simulated identity logins (DfG wallet / national eID / demo entry),
//   • talk to Data for Good's backend, or any other remote host, at all.
//
// THAT LAST RULE IS INVERTED FROM LIVIQA, DELIBERATELY (2026-09-07). In Liviqa the
// posture was "the backend MUST be api.maude.app" — correct there, because that is
// Data for Good's own sovereign stack. Maude is PPCN's fork, one user, on-device;
// for Maude the same line reversed is the safety property: a shipped build must
// NEVER resolve to a sovereign backend, because the only sovereign hosts in this
// file belong to DfG. See PROVENANCE.md, DFG_SEPARATION.md and Config.backend.
//
// Swift has no value-level static assert, so the posture is enforced in two
// layers that both fail BEFORE a human review could miss them:
//   1. This file: `#if !DEBUG` runtime preconditions executed at process start
//     (MaudeApp.init). A regression crashes the very first Release launch —
//     it cannot survive a TestFlight smoke test.
//   2. `MaudeTests/ReleasePostureTests.swift`: source-level lint of the
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

        // No rail may be pointed at a remote host.
        precondition(Config.walletRailBaseURL == nil,
                     "Release posture violation: wallet rail routed to a remote host")

        // Default backend (no env override) must be on-device. `MAUDE_BACKEND` is a
        // local-QA hook; TestFlight and App Store installs cannot set process env,
        // so the default IS the shipped behaviour. A regression that repointed Maude
        // at DfG's stack crashes the very first Release launch rather than quietly
        // signing a PPCN build into someone else's production.
        if ProcessInfo.processInfo.environment["MAUDE_BACKEND"] == nil {
            if case .sovereign = Config.backend {
                preconditionFailure(
                    "Release posture violation: Maude resolved to a sovereign backend. "
                    + "Those hosts are Data for Good's — Maude ships on-device.")
            }
        }
        #endif
    }
}
