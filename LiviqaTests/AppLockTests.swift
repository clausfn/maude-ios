import Testing
import Foundation
import LocalAuthentication
@testable import Liviqa

// T-SEC-07 — NFR-SEC-08: the Face ID / app lock.
//
// Three claims are made to the citizen and one is made to the auditor:
//   · the lock engages on the documented scene transitions (cold launch and
//     background→active), covering everything;
//   · it uses `.deviceOwnerAuthentication`, so iOS presents ITS OWN passcode
//     fallback — which is what makes "No passcode leaves the device" literally
//     true: the app stores no secret of its own;
//   · it FAILS OPEN when biometry/passcode cannot be evaluated, because a
//     health record the owner cannot open is a worse failure than an unlocked
//     one — the data is already protected at rest by file protection.
//
// `LAContext` cannot be evaluated in a unit test (no biometry, no UI), and the
// scene-phase wiring lives in a `Scene` body, so this is a source-lint in the
// established style (ReleasePostureTests). Every assertion below names a
// construct whose removal or replacement is a real regression.
struct AppLockTests {

    private static let appFile   = "Liviqa/LiviqaApp.swift"
    private static let lockFile  = "Liviqa/Views/Onboarding/AppLockSetupView.swift"
    /// Every surface that can turn the lock on.
    private static let toggleFiles = [
        "Liviqa/Views/Onboarding/AppLockSetupView.swift",
        "Liviqa/Views/SettingsView.swift",
        "Liviqa/Views/AccountSecurityView.swift",
    ]

    private func source(_ f: String) throws -> String { try SourceLint.text(f) }

    // MARK: - The lock engages on the documented transitions

    /// A cold launch starts LOCKED when the pref is on — read straight from
    /// UserDefaults at `@State` initialisation, so there is no frame of visible
    /// content before the overlay appears.
    @Test func coldLaunchStartsLockedWhenEnabled() throws {
        let src = try source(Self.appFile)
        let pattern = #"@State\s+private\s+var\s+isLocked\s*=\s*UserDefaults\.standard\.bool\(forKey:\s*"appLockEnabled"\)"#
        #expect(src.range(of: pattern, options: .regularExpression) != nil,
                "LiviqaApp must initialise isLocked from the persisted pref, or a cold launch flashes content")
    }

    /// Backgrounding re-arms the lock, so returning to the app requires Face ID.
    @Test func backgroundingReArmsTheLock() throws {
        let src = try source(Self.appFile)
        let onChange = try #require(
            SourceLint.body(ofDeclarationContaining: ".onChange(of: scenePhase)", in: src),
            "LiviqaApp must observe scenePhase (lint is stale)")
        // Shape-agnostic: `if phase == .background` and `case .background` both
        // satisfy the guarantee. What must never change is that the background
        // transition arms the lock and no transition clears it.
        #expect(onChange.contains("phase == .background") || onChange.contains("case .background"),
                "the lock must re-arm on the background transition")
        #expect(onChange.contains("appLockEnabled"),
                "…only while the citizen has the lock switched on")
        #expect(onChange.contains("isLocked = true"))
        #expect(!onChange.contains("isLocked = false"),
                "a scene transition must never UNLOCK — only a successful evaluation may")
    }

    /// The app-switcher snapshot must not contain the citizen's readings. iOS
    /// photographs the window on `.inactive`, so a cover has to be up by then —
    /// and it must be a COVER, never an authentication prompt (a system alert
    /// or share sheet also goes inactive; costing the user a Face ID round-trip
    /// for that would be a bug, and would train them to dismiss prompts).
    @Test func inactiveCoversTheAppSwitcherSnapshotWithoutPrompting() throws {
        let src = try source(Self.appFile)
        let onChange = try #require(
            SourceLint.body(ofDeclarationContaining: ".onChange(of: scenePhase)", in: src),
            "LiviqaApp must observe scenePhase (lint is stale)")
        #expect(onChange.contains("phase == .inactive") || onChange.contains("case .inactive"),
                "the privacy cover must go up on .inactive — that is when iOS snapshots the window")

        let overlay = try #require(SourceLint.body(ofDeclarationContaining: ".overlay {", in: src),
                                   "LiviqaApp must present the cover as an overlay (lint is stale)")
        #expect(overlay.contains("AppPrivacyCover"),
                "the overlay must render the privacy cover")

        // The cover itself is inert: no biometric evaluation anywhere in it.
        let coverSrc = try source("Liviqa/Views/Onboarding/AppLockSetupView.swift")
        let cover = try #require(
            SourceLint.body(ofDeclarationContaining: "struct AppPrivacyCover", in: coverSrc),
            "AppPrivacyCover must exist (lint is stale)")
        #expect(!cover.contains("LAContext") && !cover.contains("evaluatePolicy"),
                "the privacy cover must never prompt for authentication")
    }

    /// The lock screen is an overlay on the ROOT group, so it covers the whole
    /// app — including onboarding and any sheet-free content behind it.
    @Test func theLockOverlaysEverything() throws {
        let src = try source(Self.appFile)
        let overlay = try #require(SourceLint.body(ofDeclarationContaining: ".overlay {", in: src),
                                   "LiviqaApp must present the lock as an overlay (lint is stale)")
        #expect(overlay.contains("if isLocked"))
        #expect(overlay.contains("AppLockScreen"))
    }

    /// Only a successful `evaluatePolicy` may clear the lock. (The one other
    /// `isLocked = false` in the file is inside the DEBUG-only screenshot hook.)
    @Test func onlyAnAuthenticatedUnlockClearsTheLockInRelease() throws {
        let src = try source(Self.appFile)
        let clears = SourceLint.matches(#"isLocked\s*=\s*false"#, in: src)
        #expect(!clears.isEmpty, "LiviqaApp must have an unlock path (lint is stale)")
        for clear in clears {
            let openers = SourceLint.openersAbove(lineIndex: clear.n - 1, in: src)
            // The unlock callback is written inline — `AppLockScreen { isLocked = false }`
            // — so the trailing closure's owner can be the line itself.
            let fromLockScreen = clear.line.contains("AppLockScreen")
                || openers.contains { $0.contains("AppLockScreen") }
            let debugOnly = src.components(separatedBy: "\n")[..<(clear.n - 1)]
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#if DEBUG")
                       || $0.trimmingCharacters(in: .whitespaces).hasPrefix("#endif") }
                .last?.trimmingCharacters(in: .whitespaces).hasPrefix("#if DEBUG") == true
            #expect(fromLockScreen || debugOnly,
                    "\(Self.appFile):\(clear.n) — the lock may only be cleared by AppLockScreen's unlock callback (or a DEBUG-only hook)")
        }
    }

    // MARK: - System authentication, no secret of our own

    /// Every LocalAuthentication call uses `.deviceOwnerAuthentication`.
    /// `.deviceOwnerAuthenticationWithBiometrics` has NO passcode fallback —
    /// adopting it would lock out any citizen whose Face ID stops matching.
    @Test func everyAuthenticationUsesTheSystemPolicyWithPasscodeFallback() {
        var calls = 0
        for file in SourceLint.swiftFiles(in: "Liviqa") {
            #expect(!file.source.contains("deviceOwnerAuthenticationWithBiometrics"),
                    "\(file.path) — the biometrics-only policy has no passcode fallback")
            for (n, line) in SourceLint.codeLines(file.source)
            where line.contains("canEvaluatePolicy(") || line.contains("evaluatePolicy(") {
                calls += 1
                #expect(line.contains(".deviceOwnerAuthentication"),
                        "\(file.path):\(n) — LocalAuthentication must use .deviceOwnerAuthentication: \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(calls >= 4, "expected the setup + runtime + settings evaluations, found \(calls) (lint is stale?)")
    }

    /// The app stores no passcode/PIN of its own — that is what makes the
    /// onboarding promise ("No passcode leaves the device") literally true. Any
    /// line that combines a persistence API with a passcode/PIN concept fails.
    @Test func noCustomPasscodeIsStoredAnywhere() {
        let storage = ["UserDefaults", "@AppStorage", "SecItemAdd", "SecItemUpdate",
                       "Keychain", "KeyVault", "keychain", "SessionTokenStore"]
        let secret = #"(?i)\b(passcode|pincode|pin_code|userpin|lockpin)\b"#
        var hits: [String] = []
        for file in SourceLint.swiftFiles(in: "Liviqa") {
            for (n, line) in SourceLint.codeLines(file.source)
            where line.range(of: secret, options: .regularExpression) != nil {
                if storage.contains(where: { line.contains($0) }) {
                    hits.append("\(file.path):\(n) — \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(hits.isEmpty, "the app must never persist a passcode of its own: \(hits)")
    }

    /// No custom passcode ENTRY either — a `SecureField` for a lock code would
    /// mean the app had invented one.
    @Test func thereIsNoCustomPasscodeEntryField() throws {
        let lock = try source(Self.lockFile)
        #expect(!lock.contains("SecureField"),
                "the lock screen must not collect a code — iOS presents its own passcode sheet")
        #expect(!lock.contains("TextField"))
    }

    // MARK: - Fail OPEN when biometry is unavailable

    /// If the device cannot evaluate the policy at all (biometry removed,
    /// passcode cleared), the runtime lock screen UNLOCKS rather than stranding
    /// the citizen outside their own health record.
    @Test func theRuntimeLockFailsOpenWhenBiometryIsUnavailable() throws {
        let src = try source(Self.lockFile)
        let attempt = try #require(SourceLint.body(ofDeclarationContaining: "private func attempt()", in: src),
                                   "AppLockScreen.attempt() not found (lint is stale)")
        // The `guard canEvaluatePolicy … else { … }` block: it must unlock.
        let guardElse = #"guard\s+context\.canEvaluatePolicy\([^)]*\)\s*else\s*\{[^}]*\}"#
        let range = try #require(attempt.range(of: guardElse, options: .regularExpression),
                                 "AppLockScreen must guard on canEvaluatePolicy before evaluating")
        let block = String(attempt[range])
        #expect(block.contains("onUnlock()"),
                "unavailable biometry must FAIL OPEN — the citizen is never locked out of their own data")
        #expect(!block.contains("authFailed = true"),
                "an unavailable device is not a failed attempt; it must not leave the lock on screen")
    }

    /// A failed (not unavailable) attempt keeps the lock on and offers a retry —
    /// failing open must not extend to a wrong face.
    @Test func aFailedAttemptKeepsTheLockAndOffersRetry() throws {
        let src = try source(Self.lockFile)
        let attempt = try #require(SourceLint.body(ofDeclarationContaining: "private func attempt()", in: src),
                                   "AppLockScreen.attempt() not found (lint is stale)")
        #expect(attempt.contains("if success { onUnlock() } else { authFailed = true }"),
                "only a successful evaluation may unlock; a failure must set the retry state")
        #expect(src.contains("Button { attempt() }"), "the citizen must be able to retry")
    }

    /// Enabling the lock is gated on the device actually being able to evaluate
    /// the policy, so the pref can never be switched on for a device that would
    /// then be unopenable.
    @Test func enablingIsGatedOnTheDeviceBeingAbleToAuthenticate() throws {
        for file in Self.toggleFiles {
            let src = try source(file)
            guard src.contains("appLockEnabled = true") else {
                Issue.record("\(file) — no enable path found (lint is stale)")
                continue
            }
            for (n, line) in SourceLint.matches(#"appLockEnabled\s*=\s*true"#, in: src) {
                let before = src.components(separatedBy: "\n")[..<(n - 1)].suffix(12).joined(separator: "\n")
                #expect(before.contains("canEvaluatePolicy(.deviceOwnerAuthentication"),
                        "\(file):\(n) — the lock may only be enabled after canEvaluatePolicy succeeded")
            }
        }
    }

    /// Turning the lock OFF is never gated on authentication succeeding — the
    /// citizen can always get back to an unlocked app.
    @Test func disablingTheLockIsNeverGated() throws {
        for file in ["Liviqa/Views/SettingsView.swift", "Liviqa/Views/AccountSecurityView.swift"] {
            let src = try source(file)
            let offs = SourceLint.matches(#"appLockEnabled\s*=\s*false"#, in: src)
            #expect(!offs.isEmpty, "\(file) — no disable path found (lint is stale)")
            for (n, _) in offs {
                let before = src.components(separatedBy: "\n")[..<(n - 1)].suffix(4).joined(separator: "\n")
                #expect(!before.contains("canEvaluatePolicy"),
                        "\(file):\(n) — switching the lock OFF must not require authentication")
            }
        }
    }

    // MARK: - The promise the UI makes matches the mechanism

    /// The onboarding copy asserts no passcode leaves the device; the Info.plist
    /// must carry the Face ID usage string that iOS requires to make that work.
    @Test func faceIDUsageDescriptionIsDeclared() throws {
        let plist = try source("Liviqa/Info.plist")
        #expect(plist.contains("NSFaceIDUsageDescription"),
                "Info.plist must declare NSFaceIDUsageDescription or the prompt never appears")
    }
}
