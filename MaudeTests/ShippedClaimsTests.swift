import Testing
import Foundation
@testable import Maude

// RK-COPY-01 — an absolute the code does not honour spends the credibility the
// honest disclosures elsewhere are earning.
//
// Maude asks to be believed about what it does and does not do. Six sentences
// shipped claims that the same build contradicts — each found by taking one
// absolute ("never", "only", "nothing", "cannot") and going to look for the
// code that would have to be true for it. This suite pins the retirements so
// no future edit can restore a sentence without restoring the mechanism.
//
// A grep lint is the right instrument here: these are literal strings in view
// files, the claim is what ships, and a wording regression is exactly the
// failure mode. Each entry names the code that made the claim false.
struct ShippedClaimsTests {

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // MaudeTests/
            .deletingLastPathComponent()      // repo root
    }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repoRoot().appendingPathComponent(relativePath),
                   encoding: .utf8)
    }

    /// One retired claim: the phrase, where it lived, and why it was false.
    private struct RetiredClaim {
        let phrase: String
        let file: String
        let contradictedBy: String
    }

    private let retired: [RetiredClaim] = [
        .init(phrase: "so it opens only for you",
              file: "Maude/Views/Onboarding/AppLockSetupView.swift",
              contradictedBy: """
              AppLockScreen.attempt() calls onUnlock() inside the \
              `guard context.canEvaluatePolicy(...) else` branch — the lock FAILS \
              OPEN on a device with neither biometrics nor a passcode set.
              """),
        .init(phrase: "It cannot be edited, deleted, or backdated",
              file: "Maude/Views/Onboarding/OnboardingSteps.swift",
              contradictedBy: """
              ConsentLedgerView.headerClaim(hasEvidence:) exists precisely to \
              WITHHOLD this claim until an event carries real consent-engine \
              evidence (FR-WAL-09). Onboarding asserted flat what every other \
              consent surface gates.
              """),
        .init(phrase: "No one, including Maude, can alter this record.",
              file: "Maude/Views/Onboarding/OnboardingSteps.swift",
              contradictedBy: "Same FR-WAL-09 gate as above."),
        .init(phrase: "Nothing is sent away",
              file: "Maude/Views/Onboarding/OnboardingSteps.swift",
              contradictedBy: """
              ChatView.send() takes a cloud branch when `consentCloud && \
              MistralClient.hasKey`, and hasKey is true in every Release build \
              (proxyBaseURL is non-nil whenever Config.backend is .sovereign).
              """),
        .init(phrase: "your device answers queries, your data never moves",
              file: "Maude/Views/InAppPrivacyView.swift",
              contradictedBy: """
              No such on-device query compute exists (no responder anywhere in \
              the tree), and the real research path — \
              AppState.contributeHealthResearch() — POSTs a payload.
              """),
        .init(phrase: "no recommended hour on this page",
              file: "Maude/Views/SleepDetailView.swift",
              contradictedBy: """
              The same screen's sleep score divides by a fixed 8-hour reference \
              and a 35% deep-and-REM share, and its own See-why panel says so.
              """),
    ]

    @Test func retiredAbsolutesHaveNotReturned() throws {
        for claim in retired {
            let src = try source(claim.file)
            #expect(!src.contains(claim.phrase), """
                \(claim.file) has restored the claim "\(claim.phrase)".
                It is contradicted by: \(claim.contradictedBy)
                Restore the mechanism before restoring the sentence.
                """)
        }
    }

    /// The onboarding ledger copy must sit on the SAME register the ledger
    /// screen itself uses without evidence — design intent, not a fact claim.
    @Test func onboardingLedgerCopyMatchesTheLedgerScreensOwnGatedRegister() throws {
        let onboarding = try source("Maude/Views/Onboarding/OnboardingSteps.swift")
        #expect(onboarding.contains("It is designed so"))
        // And the gate it is matching still exists.
        #expect(ConsentLedgerView.headerClaim(hasEvidence: false)
            .contains("designed so"))
        #expect(!ConsentLedgerView.headerClaim(hasEvidence: true)
            .contains("designed so"))
    }

    /// The shared Learn footer's "only to yourself" absolute is true of most
    /// method notes — but not the day score, whose own rows divide by an
    /// 8-hour reference. The note must not print both.
    @Test func theDayScoreNoteDoesNotClaimPurelyPersonalComparison() {
        let dayScore = LearnLibrary.dayScore
        let rows = dayScore.methodRows.map(\.value).joined(separator: " ")
        #expect(rows.contains("8-hour reference"),
                "if the fixed reference is gone, this test's premise needs revisiting")
        #expect(!dayScore.clinicalFooter.contains("compares you only to yourself"))

        // …while a note whose rule really is purely personal keeps the absolute.
        #expect(LearnLibrary.usualBand.clinicalFooter.contains("only to yourself"))
    }
}
