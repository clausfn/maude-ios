import Testing
import Foundation
import CryptoKit
@testable import Maude

// T-DON-04 — the sealed envelope (`LVDN1`).
//
// The app has no `open`: the programme private key lives on two hardware tokens
// and never exists in the binary or the repository, so a donor build cannot
// read back what it sealed. These tests therefore re-implement the custodian
// side with a THROWAWAY key pair — which is the only way to prove the envelope
// is sound without ever putting a real private half anywhere near this code.
struct DonationSealTests {

    /// The custodian side, written here and nowhere in the app.
    private func open(_ envelope: Data,
                      with priv: Curve25519.KeyAgreement.PrivateKey) throws -> Data {
        let parts = try DonationSealer.parse(envelope)
        let epk = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: parts.epk)
        let shared = try priv.sharedSecretFromKeyAgreement(with: epk)
        var salt = parts.epk
        salt.append(priv.publicKey.rawRepresentation)
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                                 sharedInfo: DonationSealer.info,
                                                 outputByteCount: 32)
        let box = try AES.GCM.SealedBox(combined: parts.ciphertext)
        return try AES.GCM.open(box, using: key, authenticating: parts.header)
    }

    private let plaintext = Data("""
        {"manifest":{"programmeId":"DON-2026-01"},"glucose":[{"mmol":6.4}]}
        """.utf8)

    // MARK: - Round trip

    @Test func aSealedDonationOpensOnlyWithTheProgrammeKey() throws {
        let custodian = Curve25519.KeyAgreement.PrivateKey()
        let sealed = try DonationSealer.seal(plaintext, to: custodian.publicKey)
        #expect(try open(sealed, with: custodian) == plaintext)

        // A different key — the wrong custodian, or a substituted programme key.
        let stranger = Curve25519.KeyAgreement.PrivateKey()
        #expect(throws: (any Error).self) { try open(sealed, with: stranger) }
    }

    /// The plaintext must not be recognisable in the sealed bytes.
    @Test func theSealedBytesCarryNoPlaintext() throws {
        let custodian = Curve25519.KeyAgreement.PrivateKey()
        let sealed = try DonationSealer.seal(plaintext, to: custodian.publicKey)
        let text = String(decoding: sealed, as: UTF8.self)
        #expect(!text.contains("DON-2026-01"))
        #expect(!text.contains("mmol"))
        #expect(sealed.range(of: plaintext) == nil)
    }

    /// Two seals of the same bytes differ (fresh ephemeral key each time), so a
    /// stored file never reveals that two donations were identical.
    @Test func everySealUsesAFreshEphemeralKey() throws {
        let custodian = Curve25519.KeyAgreement.PrivateKey()
        let a = try DonationSealer.seal(plaintext, to: custodian.publicKey)
        let b = try DonationSealer.seal(plaintext, to: custodian.publicKey)
        #expect(a != b)
        #expect(try open(a, with: custodian) == plaintext)
        #expect(try open(b, with: custodian) == plaintext)
    }

    // MARK: - Integrity

    @Test func aFlippedByteAnywhereFailsToOpen() throws {
        let custodian = Curve25519.KeyAgreement.PrivateKey()
        let sealed = try DonationSealer.seal(plaintext, to: custodian.publicKey)

        for index in [0, 6, 10, sealed.count - 1, sealed.count / 2] {
            var tampered = sealed
            tampered[index] ^= 0x01
            #expect(throws: (any Error).self,
                    "a flipped byte at \(index) must be a failure, never different plaintext") {
                try open(tampered, with: custodian)
            }
        }
    }

    @Test func theEnvelopeHeaderIsWellFormed() throws {
        let custodian = Curve25519.KeyAgreement.PrivateKey()
        let sealed = try DonationSealer.seal(plaintext, to: custodian.publicKey)
        let parts = try DonationSealer.parse(sealed)
        #expect(String(decoding: parts.header.prefix(5), as: UTF8.self) == DonationProgramme.envelopeFormat)
        #expect(parts.epk.count == 32, "X25519 raw public key is 32 bytes")
        #expect(parts.header.count == 8 + 32)
        #expect(!parts.ciphertext.isEmpty)
    }

    @Test func garbageIsRejectedRatherThanGuessedAt() {
        #expect(throws: DonationSealError.malformedEnvelope) {
            try DonationSealer.parse(Data("not an envelope".utf8))
        }
        #expect(throws: DonationSealError.malformedEnvelope) {
            try DonationSealer.parse(Data())
        }
    }

    // MARK: - Digest

    @Test func theDigestIdentifiesTheExactBytes() throws {
        let custodian = Curve25519.KeyAgreement.PrivateKey()
        let sealed = try DonationSealer.seal(plaintext, to: custodian.publicKey)
        let digest = DonationSealer.digest(sealed)
        #expect(digest.count == 64)
        #expect(digest == DonationSealer.digest(sealed))
        var other = sealed
        other[other.count - 1] ^= 0xff
        #expect(digest != DonationSealer.digest(other))
    }

    // MARK: - The app cannot open a donation

    /// The app target contains no counterpart to `seal`. If an `open` ever
    /// appears here, a donor build could read a corpus — and the hard rule in §6
    /// stops being structural.
    @Test func theAppHasNoOpenSideForDonations() throws {
        let src = try SourceLint.text("Maude/Donation/DonationSealer.swift")
        #expect(!src.contains("func open("), "the app must have no way to open a sealed donation")
        #expect(SourceLint.matches(#"AES\.GCM\.open"#, in: src).isEmpty,
                "no decryption of a donation may exist in the app target")
        // The only private key the app mints is the per-file EPHEMERAL half,
        // which is discarded the moment the shared secret is derived. A private
        // key held for any other purpose would be a recipient key in the app.
        for file in SourceLint.swiftFiles(in: "Maude/Donation") {
            for hit in SourceLint.matches(#"Curve25519\.KeyAgreement\.PrivateKey\("#, in: file.source) {
                #expect(hit.line.contains("let ephemeral ="),
                        "\(file.path):\(hit.n) — the only private key here may be the ephemeral one: \(hit.line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }
}
