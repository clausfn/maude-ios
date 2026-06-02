// KeyVault.swift — NFR-SEC-02 / OD-09: device-bound data-encryption key.
//
// On first use the vault mints a random AES-256 data-encryption key (DEK) and
// wraps it (ECIES) to a P-256 device key. The device key's PRIVATE half is held
// in the Secure Enclave and never exported — only its `.dataRepresentation`
// (an SE-encrypted blob, usable only by THIS device's enclave) is kept in the
// Keychain. The wrapped DEK is stored in the Keychain too. Result: the DEK at
// rest is protected by Secure-Enclave-bound key material; copying the Keychain
// to another device yields nothing usable.
//
// Secure Enclave is absent on some simulators. There we fall back to a software
// P-256 key (still AES-256, still Keychain-resident) so dev builds work; the
// `isHardwareBacked` flag records which path is live (surfaced for audit only).
import Foundation
import CryptoKit
import Security

public final class KeyVault {
    public static let shared = KeyVault()

    private let service: String
    private let deviceKeyAccount = "liviqa.device-key.v1"
    private let wrappedDEKAccount = "liviqa.wrapped-dek.v1"

    private var cachedDEK: SymmetricKey?
    public private(set) var isHardwareBacked = false

    public init(service: String? = nil) {
        self.service = service ?? (Bundle.main.bundleIdentifier ?? "dev.liviqa.app") + ".keyvault"
    }

    // MARK: - Public API

    /// The on-device AES-256 data-encryption key, created + persisted on first use.
    public func dataEncryptionKey() throws -> SymmetricKey {
        if let k = cachedDEK { return k }
        let deviceKey = try loadOrCreateDeviceKey()
        let dek: SymmetricKey
        if let blob = try keychainRead(account: wrappedDEKAccount) {
            dek = try KeyWrap.unwrap(try WrappedKey(serialized: blob), with: deviceKey)
        } else {
            let fresh = SymmetricKey(size: .bits256)
            let wrapped = try KeyWrap.wrap(fresh, to: deviceKey.agreementPublicKey)
            try keychainWrite(wrapped.serialized(), account: wrappedDEKAccount)
            dek = fresh
        }
        cachedDEK = dek
        return dek
    }

    /// Ready-to-use AES-256-GCM box bound to this device's DEK.
    public func cryptoBox() throws -> CryptoBox { CryptoBox(key: try dataEncryptionKey()) }

    /// Destroy all key material (e.g. on sign-out / wipe). DEK becomes unrecoverable.
    public func reset() throws {
        try keychainDelete(account: wrappedDEKAccount)
        try keychainDelete(account: deviceKeyAccount)
        cachedDEK = nil
    }

    // MARK: - Device key (Secure Enclave preferred)

    private func loadOrCreateDeviceKey() throws -> AgreementPrivateKey {
        if SecureEnclave.isAvailable {
            isHardwareBacked = true
            if let data = try keychainRead(account: deviceKeyAccount) {
                return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: data)
            }
            let key = try SecureEnclave.P256.KeyAgreement.PrivateKey()
            try keychainWrite(key.dataRepresentation, account: deviceKeyAccount)
            return key
        }
        // Software fallback (simulator / unsupported hardware).
        isHardwareBacked = false
        if let data = try keychainRead(account: deviceKeyAccount) {
            return try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
        }
        let key = P256.KeyAgreement.PrivateKey()
        try keychainWrite(key.rawRepresentation, account: deviceKeyAccount)
        return key
    }

    // MARK: - Keychain (generic password, this-device-only, after first unlock)

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func keychainWrite(_ data: Data, account: String) throws {
        try keychainDelete(account: account)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CryptoError.keychain(status) }
    }

    private func keychainRead(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:    return item as? Data
        case errSecItemNotFound: return nil
        default:               throw CryptoError.keychain(status)
        }
    }

    private func keychainDelete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CryptoError.keychain(status)
        }
    }
}
