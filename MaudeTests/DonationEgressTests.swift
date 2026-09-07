import Testing
import Foundation
@testable import Maude

// T-DON-01 / T-DON-02 — the donor programme adds NO egress capability and NO
// way back in.
//
// The donation path is an EXPORT: the app assembles, seals and writes one file
// and hands it to the share sheet. The donor performs the transfer. That design
// is only worth anything if it is enforced, and the regression it must survive
// is the ADDITION of a transport call — which a passing runtime test can never
// disprove. So this is a source lint, in the same shape as `T-SUND-01` and
// `T-RSCH-05`, over the whole `Maude/Donation` directory plus the donor screen.
//
// It also pins the OTHER direction: nothing in the app can read a donation
// back. The payload types are Encodable-only, there is no decoder for them, and
// the provider enum has no `donated` case — so donated data has no route onto
// any screen, in any build (§6, the hard rule).
struct DonationEgressTests {

    /// Every file that makes up the donation path.
    private static let donationDirectory = "Maude/Donation"
    private static let donorScreen = "Maude/Views/DonorExportView.swift"

    /// Anything that would move bytes off the device, or the scaffolding for it.
    /// Same vocabulary as `SundhedSinkTests.egressMarkers`, plus the shapes a
    /// donation-specific upload would take.
    private static let egressMarkers = [
        "URLSession", "URLRequest", "httpMethod", "httpBody", "dataTask", "uploadTask",
        "URLProtocol", "NWConnection", "CFStream", "Socket",
        "ingestSundhed(", "pushDerivedShare(", "createGrant(", "ensureCoveringGrant",
        "https://", "http://", "s3.", "bucket", "presigned", "preSigned",
    ]

    private func donationFiles() -> [(path: String, source: String)] {
        SourceLint.swiftFiles(in: Self.donationDirectory)
            + [(Self.donorScreen, (try? SourceLint.text(Self.donorScreen)) ?? "")]
    }

    // MARK: - 1. No egress construct anywhere in the donation path

    @Test func theDonationPathContainsNoTransportConstruct() throws {
        let files = donationFiles()
        #expect(files.count >= 6, "the donation lint found almost nothing — is it stale? \(files.map(\.path))")
        for file in files {
            #expect(!file.source.isEmpty, "\(file.path) — unreadable (lint is stale)")
            for (n, line) in SourceLint.codeLines(file.source) {
                for marker in Self.egressMarkers {
                    #expect(!line.contains(marker),
                            "\(file.path):\(n) — the donation path must contain no transport construct ('\(marker)'): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }

    /// No networking framework is imported by any donation file. A donation
    /// cannot be uploaded by code that cannot speak to a socket.
    @Test func theDonationPathImportsNoNetworkingFramework() {
        let banned = ["import Network", "import CFNetwork", "import Alamofire", "import Combine"]
        for file in donationFiles() {
            for marker in banned {
                #expect(!file.source.contains(marker),
                        "\(file.path) — the donation path must not import a networking framework ('\(marker)')")
            }
        }
    }

    /// The only file write in the donation path is the SEALED file. Plaintext is
    /// a `Data` value between assembly and sealing and never reaches disk.
    @Test func theOnlyWriteIsTheSealedFile() throws {
        let src = try SourceLint.text("Maude/Donation/DonationExport.swift")
        let body = try #require(SourceLint.body(ofDeclarationContaining: "static func run(context:", in: src),
                                "DonationExport.run not found (lint is stale)")
        let writes = SourceLint.matches(#"\.write\(to:"#, in: body)
        #expect(writes.count == 1, "the export must write exactly once, found \(writes.map(\.n))")
        #expect(body.contains("try sealed.write(to: url"),
                "the single write must be of the SEALED bytes")
        // The plaintext value must never be handed to a writer.
        #expect(!body.contains("plaintext.write("), "plaintext must never be written to disk")
    }

    // MARK: - 2. Existing invariants are untouched

    /// The donation path never touches the research-contribution seam. If it
    /// did, T-RSCH-05's single-call-site count would move — this fails first and
    /// says why.
    @Test func theDonationPathNeverTouchesTheResearchContributionSeam() {
        for file in donationFiles() {
            for marker in ["contributeHealthResearch(", "researchPayload(", "SundhedIngesting"] {
                #expect(!file.source.contains(marker),
                        "\(file.path) — the donation path must not reach the consented research transport ('\(marker)')")
            }
        }
    }

    /// The provider enum stays closed. A `donated` case would be the first step
    /// towards a corpus rendering as somebody's own data (§6.1, control D-3).
    @Test func providerKindsRemainClosed() {
        #expect(Set(DataProviderKind.allCases.map(\.rawValue)) == ["healthKit", "mock", "lv001"],
                "DataProviderKind must stay {healthKit, mock, lv001} — found \(DataProviderKind.allCases.map(\.rawValue))")
    }

    // MARK: - 3. No way back in (the hard rule, §6)

    /// The payload types are Encodable-only. The app can WRITE a donation and
    /// has no type that can read one, so donated bytes cannot become values in
    /// this app — not in Release, not in TestFlight, not in Debug.
    @Test func donationPayloadTypesAreNotDecodable() {
        #expect(!(DonationPayload.self is any Decodable.Type),
                "DonationPayload must never gain a decoder — that is what makes a corpus unrenderable here")
        #expect(!(DonationManifest.self is any Decodable.Type))
        #expect(!(DonatedGlucoseRow.self is any Decodable.Type))
        #expect(!(DonatedHeartDayRow.self is any Decodable.Type))
        #expect(!(DonatedSleepRow.self is any Decodable.Type))
        #expect(!(DonatedWorkoutRow.self is any Decodable.Type))
    }

    /// And no decoder is constructed over them: the only `JSONDecoder` in the
    /// directory belongs to the sealed CONSENT store (grant + counts, no
    /// readings), never to the payload.
    @Test func noDecoderExistsForTheDonationPayload() {
        for file in SourceLint.swiftFiles(in: Self.donationDirectory) {
            let decoders = SourceLint.matches("JSONDecoder", in: file.source)
            if file.path.hasSuffix("DonationConsentStore.swift") {
                #expect(decoders.count == 1, "the consent store decodes its own sealed record and nothing else")
            } else {
                #expect(decoders.isEmpty,
                        "\(file.path) — nothing in the donation path may decode: \(decoders.map(\.n))")
            }
        }
        // No importer, not even for debugging (§6.1, control D-4).
        for file in donationFiles() {
            #expect(!file.source.contains("DonationPayload(from:"), "\(file.path) — no payload decoder")
            #expect(!file.source.contains("fileImporter"), "\(file.path) — no corpus importer may exist")
        }
    }

    // MARK: - 4. The donor gate

    /// The donor surfaces exist behind a COMPILE-TIME flag, and this test build
    /// (like every shipped build) is compiled without it.
    @Test func donorBuildFlagIsCompileTimeGated() throws {
        let src = try SourceLint.text("Maude/Donation/DonationProgramme.swift")
        #expect(src.contains("#if MAUDE_DONOR"), "the donor gate must be a compile-time condition")
        #expect(src.contains("static let isDonorBuild = false"),
                "the non-donor branch must be a compile-time false")
        #expect(DonationProgramme.isDonorBuild == false,
                "a build without -D MAUDE_DONOR must have no donor flow")
    }

    /// No programme private key, and no pinned public key, is in this repository.
    /// Sealing refuses while no key is configured — which is the correct state
    /// until the custodian key ceremony has run (§7.3 item 7).
    @Test func noProgrammeKeyMaterialIsCommitted() throws {
        #expect(DonationProgramme.publicKeyBase64 == nil,
                "no programme key may be pinned before the custodian ceremony")
        for file in SourceLint.swiftFiles(in: Self.donationDirectory) {
            for marker in ["PRIVATE KEY", "privateKeyBase64", "AGE-SECRET-KEY"] {
                #expect(!file.source.contains(marker),
                        "\(file.path) — private key material must never exist in the app or the repo")
            }
        }
        let src = try SourceLint.text("Maude/Donation/DonationProgramme.swift")
        let env = SourceLint.matches("MAUDE_DONATION_PUBKEY", in: src)
        #expect(env.count == 1, "the QA key override must appear exactly once")
        #expect(src.contains("#if DEBUG"), "the QA key override must be DEBUG-gated")
    }

    // MARK: - 5. The guard is WIRED, not merely written

    /// §5.3's own warning: the provenance guard existed as a script for months
    /// before anything ran it. This lint's shell twin must be a blocking step in
    /// `build-ios.sh` on the day it lands.
    @Test func theDonationEgressGuardIsWiredIntoTheBuild() throws {
        let script = try SourceLint.text("build-ios.sh")
        #expect(script.contains("guard_donation_egress.sh"),
                "the donation-egress guard must be a blocking build step, not a script that exists")
        let guardSource = try SourceLint.text("scripts/guard_donation_egress.sh")
        #expect(guardSource.contains("URLSession"), "the guard must hunt transport constructs")
        #expect(guardSource.contains("exit 1"), "the guard must fail the build, not warn")
    }
}
