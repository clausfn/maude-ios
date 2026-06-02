import Testing
import Foundation
import CryptoKit
@testable import Liviqa

// NFR-SEC-02 / OD-09 — AES-256-GCM + ECIES device key-wrap.
// Uses a SOFTWARE P-256 key so the crypto contract is verifiable without Secure
// Enclave hardware or Keychain entitlements (KeyVault's SE/Keychain path is
// exercised on-device). RTM: T-SEC-01..06.
struct CryptoTests {

    private func sampleData() -> Data {
        Data("Liviqa — glucose 5.8 mmol/L · resting HR 58 · provenance:REAL".utf8)
    }

    // T-SEC-01 — AES-256 round-trips losslessly; the key really is 256-bit.
    @Test func aes256RoundTrips() throws {
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        #expect(box.keyBitCount == 256)

        let plaintext = sampleData()
        let combined = try box.seal(plaintext)
        #expect(combined != plaintext)                 // actually encrypted
        #expect(try box.open(combined) == plaintext)   // and recoverable
    }

    // T-SEC-02 — a single flipped byte fails the GCM tag (no silent corruption).
    @Test func tamperIsRejected() throws {
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        var combined = try box.seal(sampleData())
        combined[combined.count - 1] ^= 0x01           // flip a tag byte
        #expect(throws: (any Error).self) { try box.open(combined) }
    }

    // T-SEC-03 — wrapping to a device key and unwrapping recovers the exact DEK.
    @Test func keyWrapRoundTrips() throws {
        let device = P256.KeyAgreement.PrivateKey()
        let dek = SymmetricKey(size: .bits256)

        let wrapped = try KeyWrap.wrap(dek, to: device.agreementPublicKey)
        let recovered = try KeyWrap.unwrap(wrapped, with: device)

        let a = dek.withUnsafeBytes { Data($0) }
        let b = recovered.withUnsafeBytes { Data($0) }
        #expect(a == b)

        // Functional check: data sealed under the original opens under recovered.
        let combined = try CryptoBox(key: dek).seal(sampleData())
        #expect(try CryptoBox(key: recovered).open(combined) == sampleData())
    }

    // T-SEC-04 — the wrapped key is bound to its device key; a different key fails.
    @Test func wrongDeviceKeyCannotUnwrap() throws {
        let device = P256.KeyAgreement.PrivateKey()
        let attacker = P256.KeyAgreement.PrivateKey()
        let wrapped = try KeyWrap.wrap(SymmetricKey(size: .bits256), to: device.agreementPublicKey)
        #expect(throws: (any Error).self) { try KeyWrap.unwrap(wrapped, with: attacker) }
    }

    // T-SEC-05 — each wrap uses a fresh ephemeral key (no deterministic reuse).
    @Test func eachWrapIsUnique() throws {
        let device = P256.KeyAgreement.PrivateKey()
        let dek = SymmetricKey(size: .bits256)
        let w1 = try KeyWrap.wrap(dek, to: device.agreementPublicKey)
        let w2 = try KeyWrap.wrap(dek, to: device.agreementPublicKey)
        #expect(w1.ephemeralPublicKey != w2.ephemeralPublicKey)
        #expect(w1.ciphertext != w2.ciphertext)
    }

    // T-SEC-06 — WrappedKey serialization round-trips for Keychain storage.
    @Test func wrappedKeySerializationRoundTrips() throws {
        let device = P256.KeyAgreement.PrivateKey()
        let wrapped = try KeyWrap.wrap(SymmetricKey(size: .bits256), to: device.agreementPublicKey)

        let restored = try WrappedKey(serialized: wrapped.serialized())
        #expect(restored == wrapped)

        // And it still unwraps after a serialize/deserialize cycle.
        #expect(throws: Never.self) { _ = try KeyWrap.unwrap(restored, with: device) }
    }
}
