// KeyVault.swift — NFR-SEC-02 / OD-09: device-bound data-encryption key.
//
// On first use the vault mints a random AES-256 data-encryption key (DEK) and
// wraps it (ECIES) to a P-256 device key. The device key's PRIVATE half is held
// in the Secure Enclave and never exported — only its `.dataRepresentation`
// (an SE-encrypted blob, usable only by THIS device's enclave) is kept. The
// wrapped DEK is kept beside it. Result: the DEK at rest is protected by
// Secure-Enclave-bound key material; copying that material to another device
// yields nothing usable.
//
// TWO fallbacks, both recorded so the UI can only ever say what is true:
//   • KEY TYPE — Secure Enclave when the enclave can actually mint a key,
//     otherwise a software P-256 key. `protection` / `isHardwareBacked` record
//     which path is live; the "Secure Enclave" claim is rendered from it.
//   • KEY STORAGE — the Keychain, unless the Keychain cannot serve this process
//     at all. An UNSIGNED build (simulator, CODE_SIGNING_ALLOWED=NO) carries no
//     `application-identifier` entitlement, so every Keychain call returns
//     errSecMissingEntitlement (-34018); there the key material goes to a
//     device-local file with NSFileProtectionComplete, excluded from backup, so
//     "the key never leaves this device" stays literally true. `storage`
//     records which path is live.
//
// WHAT IS NEVER DONE: silently re-keying. If key material exists but this
// device cannot use it (`sealedKeyUnreadable`), the vault refuses rather than
// minting a replacement — a replacement would orphan data still on disk. And a
// locked device (`isDeviceLocked`) is reported as a wait, never as data loss.
import Foundation
import CryptoKit
import Security

public final class KeyVault {
    public static let shared = KeyVault()

    /// Which key the DEK is wrapped to. Rendered directly into UI copy — never
    /// claim `.secureEnclave` protection that isn't there, never claim less.
    public enum KeyProtection: Equatable, Sendable {
        /// Private half minted by and held in the Secure Enclave.
        case secureEnclave
        /// Software P-256 key (no usable enclave on this hardware/runtime).
        case softwareDeviceKey
        /// Nothing provisioned yet in this process — make no claim at all.
        case notProvisioned
    }

    /// Where the key material rests. Audit-only; both are device-local.
    public enum KeyStorage: Equatable, Sendable { case keychain, deviceFile }

    private let service: String
    private let deviceKeyAccount = "liviqa.device-key.v1"
    private let wrappedDEKAccount = "liviqa.wrapped-dek.v1"

    private var cachedDEK: SymmetricKey?
    private let fileStore: DeviceKeyFileStore

    public private(set) var protection: KeyProtection = .notProvisioned
    public private(set) var storage: KeyStorage = .keychain

    /// True only when the device key really is enclave-held. The Health data
    /// space's "Secure Enclave" sentence is rendered from this and nothing else.
    public var isHardwareBacked: Bool { protection == .secureEnclave }

    /// When true, the Secure-Enclave device key requires user presence (Face/
    /// Touch ID, with passcode fallback) at unwrap time. Off by default so dev/
    /// simulator flows aren't gated; opt in for a hardened build.
    private let requireUserPresence: Bool

    public init(service: String? = nil,
                requireUserPresence: Bool = false,
                fileStoreDirectory: URL? = nil) {
        let service = service ?? (Bundle.main.bundleIdentifier ?? "dev.liviqa.app") + ".keyvault"
        self.service = service
        self.requireUserPresence = requireUserPresence
        self.fileStore = DeviceKeyFileStore(service: service, directory: fileStoreDirectory)
    }

    // MARK: - Public API

    /// The on-device AES-256 data-encryption key, created + persisted on first use.
    ///
    /// Throws `CryptoError.keychain(errSecInteractionNotAllowed)` (classified by
    /// `KeyFailure.isDeviceLocked`) while the device is locked, and
    /// `CryptoError.sealedKeyUnreadable` when key material exists that this
    /// device cannot use. Callers must treat those two as different states.
    public func dataEncryptionKey() throws -> SymmetricKey {
        if let k = cachedDEK { return k }
        try resolveStorage()

        let existingDeviceKey = try readMaterial(account: deviceKeyAccount)
        let existingWrappedDEK = try readMaterial(account: wrappedDEKAccount)

        // A wrapped DEK with no device key left to unwrap it: the data on disk
        // is sealed to a key this device no longer holds. Refuse — do not mint.
        if existingWrappedDEK != nil, existingDeviceKey == nil {
            throw CryptoError.sealedKeyUnreadable
        }

        let deviceKey = try loadOrCreateDeviceKey(existing: existingDeviceKey)

        let dek: SymmetricKey
        if let blob = existingWrappedDEK {
            do {
                dek = try KeyWrap.unwrap(try WrappedKey(serialized: blob), with: deviceKey)
            } catch {
                // The device key loaded, but it is not the one this DEK was
                // wrapped to. Same rule: never re-key over sealed data.
                throw CryptoError.sealedKeyUnreadable
            }
        } else {
            let fresh = SymmetricKey(size: .bits256)
            let wrapped = try KeyWrap.wrap(fresh, to: deviceKey.agreementPublicKey)
            try writeMaterial(wrapped.serialized(), account: wrappedDEKAccount)
            dek = fresh
        }
        cachedDEK = dek
        return dek
    }

    /// Ready-to-use AES-256-GCM box bound to this device's DEK.
    public func cryptoBox() throws -> CryptoBox { CryptoBox(key: try dataEncryptionKey()) }

    /// Destroy all key material (e.g. on sign-out / wipe). DEK becomes unrecoverable.
    /// Only ever reached from an explicit user action — never from a failure path.
    public func reset() throws {
        try? keychainDelete(account: wrappedDEKAccount)
        try? keychainDelete(account: deviceKeyAccount)
        try? fileStore.delete(account: wrappedDEKAccount)
        try? fileStore.delete(account: deviceKeyAccount)
        cachedDEK = nil
        protection = .notProvisioned
        storage = .keychain
    }

    // MARK: - Device key (Secure Enclave preferred, software fallback)

    private func loadOrCreateDeviceKey(existing: Data?) throws -> AgreementPrivateKey {
        if let data = existing {
            // Load whichever kind of key this blob actually is — the recorded
            // protection follows the key we ended up with, not our hopes.
            if SecureEnclave.isAvailable,
               let se = try? SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: data) {
                protection = .secureEnclave
                return se
            }
            if let soft = try? P256.KeyAgreement.PrivateKey(rawRepresentation: data) {
                protection = .softwareDeviceKey
                return soft
            }
            // Key material present, unusable here (e.g. an enclave blob on a
            // device whose enclave is gone). Never replace it silently.
            throw CryptoError.sealedKeyUnreadable
        }

        // Mint. The enclave is preferred but never required: if the enclave is
        // absent OR refuses (access-control creation, key generation), the
        // software key takes over silently and `protection` says so.
        if SecureEnclave.isAvailable,
           let accessControl = try? deviceKeyAccessControl(),
           let se = try? SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: accessControl) {
            try writeMaterial(se.dataRepresentation, account: deviceKeyAccount)
            protection = .secureEnclave
            return se
        }
        let soft = P256.KeyAgreement.PrivateKey()
        try writeMaterial(soft.rawRepresentation, account: deviceKeyAccount)
        protection = .softwareDeviceKey
        return soft
    }

    /// Access control for the SE private key: always device-bound + private-key
    /// usage; optionally gated on user presence (biometry or passcode).
    private func deviceKeyAccessControl() throws -> SecAccessControl {
        var flags: SecAccessControlCreateFlags = [.privateKeyUsage]
        if requireUserPresence { flags.insert(.userPresence) }
        var error: Unmanaged<CFError>?
        guard let ac = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, flags, &error
        ) else {
            throw CryptoError.keychain(errSecParam)
        }
        return ac
    }

    // MARK: - Storage selection (Keychain, else device file)

    /// Decide ONCE per provisioning which store holds this vault's key material,
    /// so the device key and the wrapped DEK can never come from different ones.
    private func resolveStorage() throws {
        let keychainKey: Data?
        do {
            keychainKey = try keychainRead(account: deviceKeyAccount)
        } catch {
            // A locked device is a wait — surface it, don't route around it.
            guard KeyFailure.isStorageUnusable(error) else { throw error }
            storage = .deviceFile
            return
        }
        // The Keychain works. Only prefer the file store if an earlier
        // Keychain-less run left a device key there — adopting it keeps the data
        // that key sealed readable instead of orphaning it.
        if keychainKey == nil, ((try? fileStore.read(account: deviceKeyAccount)) ?? nil) != nil {
            storage = .deviceFile
        } else {
            storage = .keychain
        }
    }

    private func readMaterial(account: String) throws -> Data? {
        switch storage {
        case .keychain:   return try keychainRead(account: account)
        case .deviceFile: return try fileStore.read(account: account)
        }
    }

    private func writeMaterial(_ data: Data, account: String) throws {
        switch storage {
        case .keychain:
            do { try keychainWrite(data, account: account) }
            catch {
                guard KeyFailure.isStorageUnusable(error) else { throw error }
                storage = .deviceFile
                try fileStore.write(data, account: account)
            }
        case .deviceFile:
            try fileStore.write(data, account: account)
        }
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
        case errSecSuccess:      return item as? Data
        case errSecItemNotFound: return nil
        default:                 throw CryptoError.keychain(status)
        }
    }

    private func keychainDelete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CryptoError.keychain(status)
        }
    }
}

// MARK: - Device-file key storage (used only when the Keychain cannot serve us)

/// Device-local key-material storage for the case where the Keychain returns
/// errSecMissingEntitlement / errSecNotAvailable for every call — i.e. an
/// unsigned build. Files are written atomically with NSFileProtectionComplete
/// (unreadable while the device is locked) and the containing directory is
/// excluded from backup, so key material still never leaves this device.
public struct DeviceKeyFileStore {
    private let service: String
    private let directory: URL

    public init(service: String, directory: URL? = nil) {
        self.service = service
        let base = directory
            ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        self.directory = base.appendingPathComponent("liviqa-keystore", isDirectory: true)
    }

    public func read(account: String) throws -> Data? {
        let url = fileURL(for: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)   // throws (locked) before first unlock
        return data.isEmpty ? nil : data
    }

    public func write(_ data: Data, account: String) throws {
        var dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)      // best-effort; the file protection is the guarantee
        try data.write(to: fileURL(for: account), options: [.atomic, .completeFileProtection])
    }

    public func delete(account: String) throws {
        let url = fileURL(for: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// The account name never appears on disk in the clear.
    private func fileURL(for account: String) -> URL {
        let digest = SHA256.hash(data: Data((service + "|" + account).utf8))
            .map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".key")
    }
}
