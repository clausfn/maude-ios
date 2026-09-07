// DonationSealer.swift — FR-DON-03 · seal-on-device, one-way.
//
// The same ECIES discipline the vault already uses (`KeyWrap` in CryptoCore:
// ephemeral agreement → HKDF → AES-256-GCM), with two deliberate differences:
//
//   • **Curve25519, not P-256.** The programme's key custody is two hardware
//     tokens holding an X25519 private half (§4.2, `age`-compatible curve). The
//     vault's P-256 half lives in the Secure Enclave, which is why that path
//     uses P-256; this one must interoperate with a key that is not on a phone.
//   • **One-way by construction.** `KeyWrap` wraps TO a device key the device
//     can also unwrap with. Here the recipient private half does not exist in
//     the app, in this repository, or on any laptop — so `seal` has no `open`
//     counterpart in the app target at all. `DonationSealTests` re-implements
//     the open side with a test-generated key to prove the envelope is sound;
//     the app itself can never read back what it wrote.
//
// Envelope `LVDN1` (all little-endian):
//
//     "LVDN1"        5 bytes   format id
//     version        1 byte    0x01
//     epkLen         2 bytes   32
//     epk            32 bytes  ephemeral X25519 public key (raw)
//     ciphertext     n bytes   AES-GCM combined (nonce ‖ ct ‖ tag)
//
// The header (everything before the ciphertext) is passed to AES-GCM as
// additional authenticated data, so a flipped byte anywhere in the file is a
// decryption failure rather than a silently different plaintext. The recipient's
// public key is mixed into the HKDF salt, which binds a sealed file to the
// programme key it was sealed to — a substituted key cannot produce a file that
// opens.
//
// PLAINTEXT NEVER TOUCHES DISK: `seal` takes bytes in memory and returns sealed
// bytes; the only `write` in this directory (`DonationExport`) writes the value
// this function returned.
import Foundation
import CryptoKit

enum DonationSealError: Error, Equatable {
    case noProgrammeKey
    case sealProducedNoCombinedBox
    case malformedEnvelope
}

enum DonationSealer {

    /// HKDF context binding — versioned so a future scheme cannot be confused
    /// with this one.
    static let info = Data("maude.donation.seal.v1".utf8)
    private static let magic = Data("LVDN1".utf8)
    private static let version: UInt8 = 0x01

    /// Seal `plaintext` to the programme's public key.
    /// - Returns: the complete envelope, ready to be written and handed to the
    ///   share sheet. Nothing else in the app can open it.
    static func seal(_ plaintext: Data,
                     to recipient: Curve25519.KeyAgreement.PublicKey) throws -> Data {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)
        var salt = ephemeral.publicKey.rawRepresentation
        salt.append(recipient.rawRepresentation)
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                                 sharedInfo: info, outputByteCount: 32)

        let header = self.header(ephemeralPublicKey: ephemeral.publicKey.rawRepresentation)
        let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: header)
        guard let combined = sealed.combined else { throw DonationSealError.sealProducedNoCombinedBox }

        var out = header
        out.append(combined)
        return out
    }

    /// Envelope header: magic ‖ version ‖ epkLen ‖ epk. Authenticated, not
    /// encrypted — it carries no information about the donor.
    static func header(ephemeralPublicKey epk: Data) -> Data {
        var out = magic
        out.append(version)
        let len = UInt16(epk.count)
        out.append(UInt8(len & 0xff))
        out.append(UInt8(len >> 8))
        out.append(epk)
        return out
    }

    /// Split an envelope into (header, ephemeral public key, ciphertext) without
    /// decrypting anything. Used by the tests that prove the envelope round-trips
    /// under a test key, and by nothing in the app's own flow.
    static func parse(_ envelope: Data) throws -> (header: Data, epk: Data, ciphertext: Data) {
        let bytes = [UInt8](envelope)
        guard bytes.count > 8, Data(bytes[0..<5]) == magic, bytes[5] == version
        else { throw DonationSealError.malformedEnvelope }
        let len = Int(bytes[6]) | (Int(bytes[7]) << 8)
        guard bytes.count > 8 + len else { throw DonationSealError.malformedEnvelope }
        let epk = Data(bytes[8 ..< 8 + len])
        return (Data(bytes[0 ..< 8 + len]), epk, Data(bytes[(8 + len)...]))
    }

    /// SHA-256 of the sealed bytes, hex. Recorded in the export ledger so a
    /// donor (and a custodian) can identify exactly which file left, without the
    /// app retaining any of its contents.
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
