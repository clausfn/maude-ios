// CryptoCore.swift — NFR-SEC-02 / OD-09 primitives (portable CryptoKit).
//
// Two pieces, both framework-free of UIKit/SwiftData so they unit-test on any
// platform with CryptoKit:
//   • CryptoBox  — AES-256-GCM authenticated encryption with a data key (DEK).
//   • KeyWrap    — ECIES wrap of the DEK to a device key (ECDH → HKDF → AES-GCM).
//
// The DEK is 256-bit. Its plaintext only ever lives in memory; at rest it is
// wrapped to a P-256 key whose private half is held in the Secure Enclave
// (see KeyVault). Nothing here logs key material.
import Foundation
import CryptoKit

public enum CryptoError: Error, Equatable {
    case sealProducedNoCombinedBox
    case enclaveUnavailable
    case keychain(OSStatus)
    case malformedWrappedKey
}

// MARK: - AES-256-GCM box

/// Authenticated encryption with a 256-bit key. `combined` output is
/// nonce ‖ ciphertext ‖ tag, so a single `Data` round-trips losslessly.
public struct CryptoBox: Sendable {
    private let key: SymmetricKey

    public init(key: SymmetricKey) { self.key = key }

    /// AES-256 ⇔ 256-bit key. Exposed so tests can assert the algorithm strength.
    public var keyBitCount: Int { key.bitCount }

    public func seal(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.sealProducedNoCombinedBox }
        return combined
    }

    /// Decrypts and verifies the GCM tag. A tampered byte ⇒ thrown error (never
    /// silent garbage) — the property the integrity guarantee rests on.
    public func open(_ combined: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }
}

// MARK: - ECIES key wrap (device-bound)

/// A symmetric key sealed to a device key. Persisted at rest; useless off-device.
public struct WrappedKey: Sendable, Equatable {
    public let ephemeralPublicKey: Data   // P-256 raw (uncompressed point)
    public let ciphertext: Data           // AES-GCM combined box over the DEK

    public init(ephemeralPublicKey: Data, ciphertext: Data) {
        self.ephemeralPublicKey = ephemeralPublicKey
        self.ciphertext = ciphertext
    }

    /// length-prefixed serialization for Keychain storage (little-endian, byte-wise).
    public func serialized() -> Data {
        let len = UInt16(ephemeralPublicKey.count)
        var out = Data([UInt8(len & 0xff), UInt8(len >> 8)])
        out.append(ephemeralPublicKey)
        out.append(ciphertext)
        return out
    }

    public init(serialized data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { throw CryptoError.malformedWrappedKey }
        let len = Int(bytes[0]) | (Int(bytes[1]) << 8)
        guard bytes.count >= 2 + len else { throw CryptoError.malformedWrappedKey }
        self.ephemeralPublicKey = Data(bytes[2 ..< 2 + len])
        self.ciphertext = Data(bytes[(2 + len)...])
    }
}

/// P-256 private keys able to do key agreement — software or Secure Enclave.
/// Lets KeyWrap.unwrap stay identical whether or not the SE is present.
public protocol AgreementPrivateKey {
    var agreementPublicKey: P256.KeyAgreement.PublicKey { get }
    func sharedSecret(with peer: P256.KeyAgreement.PublicKey) throws -> SharedSecret
}

extension P256.KeyAgreement.PrivateKey: AgreementPrivateKey {
    public var agreementPublicKey: P256.KeyAgreement.PublicKey { publicKey }
    public func sharedSecret(with peer: P256.KeyAgreement.PublicKey) throws -> SharedSecret {
        try sharedSecretFromKeyAgreement(with: peer)
    }
}

extension SecureEnclave.P256.KeyAgreement.PrivateKey: AgreementPrivateKey {
    public var agreementPublicKey: P256.KeyAgreement.PublicKey { publicKey }
    public func sharedSecret(with peer: P256.KeyAgreement.PublicKey) throws -> SharedSecret {
        try sharedSecretFromKeyAgreement(with: peer)
    }
}

public enum KeyWrap {
    /// HKDF context binding — version it so a future scheme can't be confused.
    private static let info = Data("liviqa.kek.v1".utf8)

    /// Wrap `dek` to `recipient` (a device key's public half) with a fresh
    /// ephemeral key. Forward-secret per wrap; only the device key can unwrap.
    public static func wrap(_ dek: SymmetricKey, to recipient: P256.KeyAgreement.PublicKey) throws -> WrappedKey {
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)
        let salt = ephemeral.publicKey.rawRepresentation
        let kek = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                                 sharedInfo: info, outputByteCount: 32)
        let dekBytes = dek.withUnsafeBytes { Data($0) }
        let sealed = try AES.GCM.seal(dekBytes, using: kek)
        guard let combined = sealed.combined else { throw CryptoError.sealProducedNoCombinedBox }
        return WrappedKey(ephemeralPublicKey: salt, ciphertext: combined)
    }

    /// Reverse of `wrap`, using the device private key (software or Secure Enclave).
    public static func unwrap(_ wrapped: WrappedKey, with privateKey: AgreementPrivateKey) throws -> SymmetricKey {
        let ephemeralPub = try P256.KeyAgreement.PublicKey(rawRepresentation: wrapped.ephemeralPublicKey)
        let shared = try privateKey.sharedSecret(with: ephemeralPub)
        let kek = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: wrapped.ephemeralPublicKey,
                                                 sharedInfo: info, outputByteCount: 32)
        let box = try AES.GCM.SealedBox(combined: wrapped.ciphertext)
        let dekBytes = try AES.GCM.open(box, using: kek)
        return SymmetricKey(data: dekBytes)
    }
}
