// EncryptedAnchorStore.swift — FR-ING-03/04 · NFR-SEC-02
//
// Encrypted, on-device persistence for opaque sync cursors (HealthKit query
// anchors). The caller archives an anchor to `Data`; this store SEALS it with
// the device data-encryption key (KeyVault → AES-256-GCM via CryptoBox) and
// writes the sealed blob to a file under Application Support, namespaced to the
// LOCAL user.
//
// Hard rules (per the task contract):
//   • never UserDefaults — anchors are secrets-adjacent sync state;
//   • never keyed to a server / account id — the scope is a device-LOCAL id;
//   • the bytes at rest are ciphertext only (GCM-authenticated).
//
// Pure Foundation + CryptoKit so the codec round-trip unit-tests on any
// platform (no HealthKit, no SwiftUI). The HealthKit↔Data adapter lives in the
// HealthKit-gated `HealthKitService+Anchored.swift`.
import Foundation
import CryptoKit
import Security

public final class EncryptedAnchorStore {

    public enum AnchorStoreError: Error, Equatable { case unwritable }

    private let box: CryptoBox
    private let directory: URL
    private let fileManager: FileManager

    /// - box:       AES-256-GCM box bound to the device DEK (KeyVault.cryptoBox()).
    /// - userScope: a stable LOCAL user identifier (see `LocalUserScope`) — NEVER
    ///   a backend/account id. Hashed into the on-disk folder name.
    /// - directory: base dir (defaults to Application Support); the store writes to
    ///   `<base>/health-anchors/<sha(userScope)>/`.
    public init(box: CryptoBox,
                userScope: String,
                directory: URL? = nil,
                fileManager: FileManager = .default) {
        self.box = box
        self.fileManager = fileManager
        let base = directory ?? Self.defaultDirectory(fileManager: fileManager)
        self.directory = base
            .appendingPathComponent("health-anchors", isDirectory: true)
            .appendingPathComponent(Self.hex(userScope), isDirectory: true)
    }

    /// Build from the shared KeyVault DEK (device-bound, Secure-Enclave wrapped).
    public convenience init(keyVault: KeyVault = .shared,
                            userScope: String,
                            directory: URL? = nil) throws {
        self.init(box: try keyVault.cryptoBox(), userScope: userScope, directory: directory)
    }

    /// Seal `anchor` and persist it under `key` (e.g. a HealthKit type id).
    public func save(_ anchor: Data, for key: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let sealed = try box.seal(anchor)
        do {
            try sealed.write(to: fileURL(for: key), options: [.atomic, .completeFileProtection])
        } catch {
            throw AnchorStoreError.unwritable
        }
    }

    /// Load + decrypt the anchor for `key`, or nil if none stored. Throws if the
    /// blob fails GCM authentication (tampered, or wrong device key).
    public func load(for key: String) throws -> Data? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let sealed = try Data(contentsOf: url)
        return try box.open(sealed)
    }

    /// Forget the anchor for one key (e.g. to force a full re-sync of that type).
    public func remove(for key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    /// Wipe every anchor for this scope (e.g. on sign-out / erase).
    public func clear() {
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Paths

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(Self.hex(key) + ".anchor")
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
    }

    /// SHA-256 hex — a key/scope never appears raw on disk and can't traverse paths.
    private static func hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// A device-LOCAL, stable user identifier for namespacing on-device state
/// (anchor files). Minted once and kept in the Keychain (device-only, after
/// first unlock) — NOT in UserDefaults, and explicitly NOT a backend/account id
/// (FR-ING-04). If the Keychain is unavailable, falls back to an ephemeral id so
/// callers still get isolation within the process.
public enum LocalUserScope {
    private static let service = "io.liviqa.local-scope"
    private static let account = "health.anchor.scope"

    public static func current() -> String {
        if let existing = read() { return existing }
        let fresh = UUID().uuidString
        write(fresh)
        return read() ?? fresh
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read() -> String? {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var q = baseQuery
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
