import Testing
import Foundation
@testable import Liviqa

// Area ⑥ sharing & consent rails — T-RSCH-07 (consent-safety default) and
// T-WAL-09 (CE-stub non-evidentiary receipt claim gating), plus the k ≥ 5
// grouping-phrase translation (NFR-RSCH-04) and the token no-health-data
// description rail (FR-DFG-07).
struct ConsentSurfaceTests {

    // MARK: - T-RSCH-07 — study-consent toggles default OFF, join gated on ≥1

    @Test func studyConsentDefaultsAreAllOff() {
        // The consent-safety default: NOTHING pre-selected, for any study.
        let study = ResearchStudy(
            id: UUID(), name: "Any study", sponsor: "Any sponsor",
            vouchedByDfG: true, purpose: "p",
            dataCategories: ["activity", "sleep", "glucose"], cohortK: 5)
        #expect(StudyConsentView.initialSelection(for: study).isEmpty)
        #expect(StudyConsentView.initialSelection(for: MockData.demoStudy).isEmpty)
    }

    @Test func joinRequiresAtLeastOneCategory() {
        #expect(!StudyConsentView.canJoin(selected: [], working: false))
        #expect(StudyConsentView.canJoin(selected: ["sleep"], working: false))
        #expect(!StudyConsentView.canJoin(selected: ["sleep"], working: true))
        #expect(!StudyConsentView.canJoin(selected: [], working: true))
    }

    // MARK: - NFR-RSCH-04 — grouping phrase is a translation, never a lowering

    @Test func groupingPhraseMatchesCanvasAtKFive() {
        // "at least 4 other people" == k ≥ 5, the exact canvas wording.
        #expect(ResearchStudy.groupingPhrase(cohortK: 5) == "at least 4 other people")
    }

    @Test func groupingPhraseClampsToKFloor() {
        // A mis-seeded k below the floor must never lower the promise.
        #expect(ResearchStudy.groupingPhrase(cohortK: 3) == "at least 4 other people")
        #expect(ResearchStudy.groupingPhrase(cohortK: 0) == "at least 4 other people")
        // Larger cohorts may promise more, never less.
        #expect(ResearchStudy.groupingPhrase(cohortK: 8) == "at least 7 other people")
    }

    // MARK: - T-WAL-09 — evidentiary gating (CE_MODE=stub ⇒ non-evidentiary)

    @Test func evidenceRequiresReceiptIdAndEventHash() {
        #expect(!CEEvidence().isEvidentiary)
        #expect(!CEEvidence(receiptId: "rcpt_1").isEvidentiary)
        #expect(!CEEvidence(eventHash: "7f3a99c21e00").isEvidentiary)
        #expect(!CEEvidence(receiptId: "", eventHash: "").isEvidentiary)
        #expect(CEEvidence(receiptId: "rcpt_1", eventHash: "7f3a99c21e00").isEvidentiary)
    }

    @Test func proofNumberOnlyFromEvidentiaryReceipts() {
        // No evidence → no proof number, ever.
        #expect(CEEvidence().proofNumber == nil)
        #expect(CEEvidence(receiptId: "rcpt_1").proofNumber == nil)
        // Evidence → short 0x form of the event hash.
        let ce = CEEvidence(receiptId: "rcpt_1", eventHash: "7f3a99deadbeefc21e")
        #expect(ce.proofNumber == "0x7f3a99…c21e")
    }

    @Test func slipHasNoProofRowOrSignedClaimWithoutEvidence() {
        let grant = WalletGrant(
            id: UUID(), recipientName: "Mette Holm",
            recipientType: .clinical, scopeKeys: ["glucose", "sleep_duration"],
            isActive: true, createdAt: Date())
        let slip = ReceiptSlipModel.build(recipientName: "Mette Holm",
                                          grant: grant, evidence: nil)
        #expect(!slip.rows.contains { $0.label == "Proof number" })
        #expect(!slip.rows.contains { $0.label == "Signed at" })
        #expect(!slip.claim.contains("signed"))
        #expect(slip.claim.contains("kept in your consent record"))
        // The standing promise renders regardless.
        #expect(slip.rows.contains { $0.label == "Your individual readings" && $0.value == "0 shared — ever" })
    }

    @Test func slipCarriesProofRowAndSignedClaimWithEvidence() {
        let grant = WalletGrant(
            id: UUID(), recipientName: "Mette Holm",
            recipientType: .clinical, scopeKeys: ["glucose"],
            isActive: true, createdAt: Date())
        let ce = CEEvidence(receiptId: "rcpt_1", eventHash: "7f3a99deadbeefc21e")
        let slip = ReceiptSlipModel.build(recipientName: "Mette Holm",
                                          grant: grant, evidence: ce)
        #expect(slip.rows.contains { $0.label == "Proof number" && $0.value == "0x7f3a99…c21e" })
        #expect(slip.rows.contains { $0.label == "Signed at" })
        #expect(slip.claim.contains("signed so nobody can change it"))
    }

    @Test func slipStubEvidenceIsTreatedAsNoEvidence() {
        // A stub-mode receipt (id but no hash) must not unlock the claims.
        let stub = CEEvidence(receiptId: "stub_1")
        let slip = ReceiptSlipModel.build(recipientName: "X", grant: nil, evidence: stub)
        #expect(!slip.rows.contains { $0.label == "Proof number" })
        #expect(!slip.claim.contains("signed"))
    }

    @Test func ledgerHeaderClaimGatesOnEvidence() {
        #expect(ConsentLedgerView.headerClaim(hasEvidence: true)
                == "Nobody can edit this — not even us.")
        let soft = ConsentLedgerView.headerClaim(hasEvidence: false)
        #expect(soft.contains("designed so"))
        #expect(!soft.hasPrefix("Nobody"))
    }

    @Test func latestEvidenceMatchesByGrantRefThenActor() {
        let good = CEEvidence(receiptId: "rcpt_1", grantRef: "grant_A", eventHash: "aa11bb22cc33")
        let stub = CEEvidence(receiptId: "stub", grantRef: "grant_B")
        let events = [
            WalletEvent(id: UUID(), eventType: .consentGranted, actorName: "Someone Else",
                        scopeKeys: [], decision: .approved, occurredAt: Date(), ce: stub),
            WalletEvent(id: UUID(), eventType: .consentGranted, actorName: "Mette Holm",
                        scopeKeys: [], decision: .approved, occurredAt: Date(), ce: good),
        ]
        // By grant ref.
        #expect(events.latestEvidence(forGrantRef: "grant_A", recipientName: "n/a")?.grantRef == "grant_A")
        // By actor name when the grant has no CE ref.
        #expect(events.latestEvidence(forGrantRef: nil, recipientName: "Mette Holm")?.grantRef == "grant_A")
        // Stub evidence never matches (non-evidentiary).
        #expect(events.latestEvidence(forGrantRef: "grant_B", recipientName: "Someone Else") == nil)
    }

    // MARK: - FR-DFG-07 — tokens never carry health data

    @Test func donationDescriptionIsCauseNameOnly() {
        let d = TokenWalletView.donationDescription(cause: "Diabetes Research Centre")
        #expect(d == "Donated to Diabetes Research Centre")
        // By construction there is no slot for a reading — assert no digits
        // beyond what the cause name itself carries.
        #expect(!d.contains("mmol"))
        #expect(!d.contains("%"))
    }
}
