import Testing
import Foundation
import CryptoKit
@testable import Maude

// T-DON-05 — consent first, and the copy that follows from it.
//
// Two guarantees live here:
//   1. NOTHING EXPORTS WITHOUT AN ACTIVE GRANT. The gate is a pure function, so
//      every refusal (no donor build, no grant, wrong recipient, withdrawn,
//      expired, no programme key, demo data, nothing in the window) is proved
//      rather than hoped for.
//   2. THE UNCONDITIONAL PROMISE STILL RENDERS FOR EVERY NON-DONOR. "Your
//      individual readings never leave this phone" is exactly what a citizen
//      with no donation grant reads — in every shipped build, that is everyone.
//      Only an active donation grant swaps it for the donor's own sentence,
//      which names the exception specifically instead of softening the claim.
@MainActor
struct DonationConsentTests {

    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func grant(active: Bool = true,
                       type: RecipientType = .controllerInternal,
                       expires: Date? = nil,
                       scopes: [String] = ["sleep"]) -> WalletGrant {
        WalletGrant(id: UUID(), recipientName: DonationProgramme.recipientName,
                    recipientType: type, scopeKeys: scopes, isActive: active,
                    expiresAt: expires ?? now.addingTimeInterval(86_400 * 300),
                    createdAt: now, ceGrantRef: "DON-2026-01-TEST01")
    }

    private func refusal(donorBuild: Bool = true,
                         grant: WalletGrant?,
                         key: Bool = true,
                         demo: Bool = false,
                         rows: Int = 10) -> DonationExport.Refusal? {
        DonationExport.refusal(isDonorBuild: donorBuild, grant: grant,
                               hasProgrammeKey: key, isDemoData: demo,
                               rowCount: rows, now: now)
    }

    // MARK: - 1. The gate

    @Test func anActiveDonationGrantIsRequiredForEveryExport() {
        #expect(refusal(grant: nil) == .noActiveGrant)
        #expect(refusal(grant: grant(active: false)) == .noActiveGrant,
                "a withdrawn donor must not be able to export again")
        #expect(refusal(grant: grant(expires: now.addingTimeInterval(-1))) == .noActiveGrant,
                "an expired grant is not a donation licence (§2.6 — 12 months, no auto-renew)")
        #expect(refusal(grant: grant(scopes: [])) == .noActiveGrant,
                "a grant covering nothing permits nothing")
        #expect(refusal(grant: grant(type: .research)) == .noActiveGrant,
                "only a controller-internal donation grant permits a donation")
        #expect(refusal(grant: grant()) == nil, "an active, scoped, unexpired grant proceeds")
    }

    @Test func theOtherRefusalsAreOrderedSoNothingIsReadTooEarly() {
        // No donor build wins over everything: nothing is even considered.
        #expect(refusal(donorBuild: false, grant: nil) == .notADonorBuild)
        // Consent is checked before the key, the data source and the store.
        #expect(refusal(grant: nil, key: false, demo: true, rows: 0) == .noActiveGrant)
        #expect(refusal(grant: grant(), key: false) == .noProgrammeKey)
        #expect(refusal(grant: grant(), demo: true) == .demoData,
                "invented readings must never enter the collection")
        #expect(refusal(grant: grant(), rows: 0) == .nothingInWindow)
    }

    /// Every refusal says something a donor can act on — no silent failure and
    /// no generic error.
    @Test func everyRefusalCarriesItsOwnCopy() {
        let all: [DonationExport.Refusal] = [.notADonorBuild, .noActiveGrant, .noProgrammeKey,
                                             .demoData, .nothingInWindow, .storeUnavailable,
                                             .sealFailed, .writeFailed]
        var seen = Set<String>()
        for refusal in all {
            #expect(refusal.message.count > 30, "\(refusal) needs a real explanation")
            #expect(seen.insert(refusal.message).inserted, "\(refusal) reuses another refusal's copy")
        }
    }

    /// No programme key is pinned yet, so a donor build refuses at the key step
    /// rather than sealing a file to nobody.
    @Test func withNoProgrammeKeyConfiguredTheExportRefuses() {
        #expect(DonationProgramme.programmePublicKey() == nil)
        #expect(refusal(grant: grant(), key: DonationProgramme.programmePublicKey() != nil)
                == .noProgrammeKey)
    }

    // MARK: - 2. A build without the donor flag can do nothing at all

    @Test func aShippedBuildHasNoDonationStateAndCanRecordNothing() {
        #expect(DonationProgramme.isDonorBuild == false)
        let state = AppState(supabase: MockSupabaseService())
        #expect(state.hasActiveDonationGrant == false)
        #expect(state.donationGrant == nil)
        #expect(state.donationExports.isEmpty)
        #expect(state.recordDonationGrant(reference: "DON-2026-01-X", scopes: ["sleep"]) == false,
                "a non-donor build must not be able to record a donation grant")
        #expect(state.withdrawDonationGrant() == false)
        do {
            _ = try state.exportDonation()
            Issue.record("a build without the donor flag must never produce a donation file")
        } catch let refusal as DonationExport.Refusal {
            #expect(refusal == .noActiveGrant || refusal == .storeUnavailable)
        } catch {
            Issue.record("unexpected error from the donation gate: \(error)")
        }
    }

    // MARK: - 3. The sealed device record

    private func store(_ dir: URL) -> DonationConsentStore {
        DonationConsentStore(box: CryptoBox(key: SymmetricKey(size: .bits256)),
                             userScope: "test-scope", directory: dir)
    }

    @Test func theRecordRoundTripsAndSurvivesRelaunch() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let key = SymmetricKey(size: .bits256)
        let a = DonationConsentStore(box: CryptoBox(key: key), userScope: "s", directory: dir)
        #expect(try a.load().grant == nil, "an empty store is an empty record, not a failure")

        var record = DonationRecord()
        record.grant = grant()
        record.events = [WalletEvent(id: UUID(), eventType: .consentGranted,
                                     actorName: DonationProgramme.recipientName,
                                     scopeKeys: ["sleep"], decision: .approved, occurredAt: now)]
        record.exports = [DonationExportRecord(id: UUID(), occurredAt: now,
                                               grantReference: "DON-2026-01-TEST01",
                                               windowStart: now.addingTimeInterval(-90 * 86_400),
                                               windowEnd: now, dateShiftDays: 14,
                                               counts: ["sleep": 42], fileName: "f.lvdn",
                                               byteCount: 1_024, sealedDigest: "ab12")]
        try a.save(record)

        // A fresh store with the same key (a relaunch) reads it back.
        let b = DonationConsentStore(box: CryptoBox(key: key), userScope: "s", directory: dir)
        let loaded = try b.load()
        #expect(loaded.grant?.ceGrantRef == "DON-2026-01-TEST01")
        #expect(loaded.exports.first?.counts == ["sleep": 42])
        #expect(loaded.exports.first?.rowCount == 42)
        #expect(loaded.events.count == 1)
    }

    @Test func aRecordSealedToAnotherKeyIsReportedNotOverwritten() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        var record = DonationRecord(); record.grant = grant()
        try store(dir).save(record)

        let stranger = store(dir)   // different random key
        #expect(throws: DonationConsentStore.StoreError.unreadable) { _ = try stranger.load() }
    }

    @Test func nothingIsWrittenInPlaintext() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        var record = DonationRecord(); record.grant = grant()
        let s = store(dir)
        try s.save(record)

        let files = (FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
        #expect(!files.isEmpty)
        for file in files {
            let bytes = try Data(contentsOf: file)
            let text = String(decoding: bytes, as: UTF8.self)
            #expect(!text.contains("DON-2026-01-TEST01"),
                    "\(file.lastPathComponent) — the grant reference must not be readable on disk")
            #expect(!text.contains("recipient_name"))
        }
    }

    @Test func anExpiredGrantIsNotActive() {
        var record = DonationRecord()
        record.grant = grant(expires: now.addingTimeInterval(-1))
        #expect(record.activeGrant(now: now) == nil)
        record.grant = grant(active: false)
        #expect(record.activeGrant(now: now) == nil)
        record.grant = grant()
        #expect(record.activeGrant(now: now) != nil)
    }

    // MARK: - 4. The consent model is reused, not forked

    /// The donation recipient exists as its own value (§2.6 / OD-D2) and is
    /// never offered to a citizen choosing who to share with.
    @Test func controllerInternalIsNotOfferedToCitizens() throws {
        #expect(RecipientType(rawValue: "controller_internal") == .controllerInternal)
        for file in SourceLint.swiftFiles(in: "Maude/Views") {
            #expect(!file.source.contains(".controllerInternal"),
                    "\(file.path) — the donation recipient must not be selectable on any citizen screen")
            #expect(!file.source.contains("RecipientType.allCases"),
                    "\(file.path) — a picker over every recipient type would offer the donation recipient")
        }
    }

    /// The grant and its events are the app's own types — no parallel register.
    @Test func theDonationUsesTheAppsOwnGrantAndEventTypes() throws {
        let src = try SourceLint.text("Maude/Donation/AppState+Donation.swift")
        #expect(src.contains("WalletGrant("), "the donation grant must be a WalletGrant")
        #expect(src.contains("WalletEvent(id: UUID()"), "state changes must write ordinary ledger events")
        #expect(src.contains(".consentGranted"))
        #expect(src.contains(".consentRevoked"))
        #expect(src.contains(".dataAccessed"), "every export must write a ledger event")
        for forked in ["struct DonationGrant", "enum DonationConsentState", "struct DonorConsent"] {
            #expect(!src.contains(forked), "a parallel consent model appeared: \(forked)")
        }
    }

    // MARK: - 5. The copy (§6.3 / OD-D11)

    /// THE non-donor guarantee: the sentence renders unchanged, verbatim.
    @Test func theUnconditionalPromiseRendersForEveryNonDonor() {
        #expect(DonationCopy.readingsClaim(donating: false)
                == "Your individual readings never leave this phone.")
        let state = AppState(supabase: MockSupabaseService())
        #expect(DonationCopy.readingsClaim(donating: state.hasActiveDonationGrant)
                == "Your individual readings never leave this phone.")
    }

    /// The donor's version names the exception rather than blurring the claim.
    @Test func theDonorVersionNamesTheExceptionSpecifically() {
        let donor = DonationCopy.readingsClaim(donating: true)
        #expect(donor != DonationCopy.standingClaim)
        #expect(donor.contains("Nothing in Maude sends your individual readings anywhere"),
                "the app's own behaviour is still stated plainly")
        #expect(donor.lowercased().contains("you export"), "the donor's own act must be named")
        #expect(donor.lowercased().contains("encrypted"))
        #expect(donor.lowercased().contains("withdraw"))
        for weasel in ["may be shared", "some data", "certain data", "from time to time"] {
            #expect(!donor.lowercased().contains(weasel), "the donor sentence must not blur into '\(weasel)'")
        }
    }

    /// A recipient row describes THAT recipient: a clinician still sees only
    /// summaries even when the person is also a donor.
    @Test func recipientRowsAreScopedPerGrantNotPerDonor() {
        #expect(DonationCopy.recipientRowClaim(recipientType: .clinical)
                == "Summaries only · your individual readings never leave this phone")
        #expect(DonationCopy.recipientRowClaim(recipientType: .research)
                == "Summaries only · your individual readings never leave this phone")
        let donation = DonationCopy.recipientRowClaim(recipientType: .controllerInternal)
        #expect(donation != DonationCopy.recipientRowClaim(recipientType: .clinical))
        #expect(donation.lowercased().contains("you export"))
    }

    /// No view may hard-code the claim again: every surface that makes it must
    /// go through `DonationCopy`, or the next donor programme change will leave
    /// one screen telling a donor something untrue.
    @Test func noSurfaceHardCodesTheReadingsClaim() {
        let claim = "individual readings never leave this phone"
        for file in SourceLint.swiftFiles(in: "Maude/Views") {
            for hit in SourceLint.matches(claim, in: file.source) {
                Issue.record("\(file.path):\(hit.n) — the readings claim must come from DonationCopy: \(hit.line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }

    /// …and the four surfaces that make the claim really do call the helper.
    @Test func theConsentSurfacesCallTheScopedClaim() throws {
        for path in ["Maude/Views/StudyConsentView.swift",
                     "Maude/Views/ResearchHubView.swift",
                     "Maude/Views/WalletView.swift"] {
            let src = try SourceLint.text(path)
            #expect(src.contains("DonationCopy.readingsClaim(donating: appState.hasActiveDonationGrant)"),
                    "\(path) — must render the scoped claim")
        }
        let privacy = try SourceLint.text("Maude/Views/InAppPrivacyView.swift")
        #expect(privacy.contains("DonationCopy.recipientRowClaim(recipientType: grant.recipientType)"),
                "InAppPrivacyView — the per-grant row must describe that recipient")
    }
}
