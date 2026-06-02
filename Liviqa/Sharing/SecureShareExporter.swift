// SecureShareExporter.swift — the encryption boundary for outbound data.
//
// A ShareBundle is JSON-encoded and sealed with AES-256-GCM (CryptoBox, keyed
// by the device DEK from KeyVault) before it can be written to disk, attached,
// or synced. Plaintext bundle JSON never persists. This is where the verified
// PR-8 crypto primitive becomes an enforced control (NFR-SEC-02).
import Foundation

/// An encrypted, ready-to-share envelope. Opaque ciphertext only.
public struct EncryptedBundle: Sendable, Equatable, Codable {
    public static let schemaID = "liviqa.share.enc.v1"
    public let schema: String
    public let ciphertext: Data        // AES-256-GCM combined box over the JSON

    public init(ciphertext: Data) {
        self.schema = Self.schemaID
        self.ciphertext = ciphertext
    }
}

public struct SecureShareExporter {
    private let box: CryptoBox

    public init(box: CryptoBox) { self.box = box }

    /// Convenience: pull the device DEK from the vault.
    public init(vault: KeyVault = .shared) throws {
        self.box = try vault.cryptoBox()
    }

    public func encrypt(_ bundle: ShareBundle) throws -> EncryptedBundle {
        let json = try Self.encoder.encode(bundle)
        return EncryptedBundle(ciphertext: try box.seal(json))
    }

    public func decrypt(_ envelope: EncryptedBundle) throws -> ShareBundle {
        let json = try box.open(envelope.ciphertext)
        return try Self.decoder.decode(ShareBundle.self, from: json)
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
