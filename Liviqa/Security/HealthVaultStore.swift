// HealthVaultStore.swift — FR-ING-15 (realises FR-ING-12/13) · NFR-SEC-02
//
// The encrypted, on-device DOCUMENT store behind the "Health data space"
// (HealthVaultView): the citizen's own lab letters, clinical PDFs, scans and
// photos. DISTINCT from HealthRecordStore (the coded-observation store) — this
// one holds opaque file bytes, not coded rows.
//
// Crypto (the same local-store rail as EncryptedAnchorStore):
//   • every document is sealed with AES-256-GCM (KeyVault DEK → CryptoBox);
//   • the DEK at rest is ECIES-wrapped to a P-256 key whose private half lives
//     in the Secure Enclave (KeyVault; software fallback on SE-less simulators,
//     recorded in `KeyVault.isHardwareBacked` — the UI copy follows it honestly);
//   • the metadata INDEX is sealed too — document names ("HIV test result.pdf")
//     are as sensitive as their contents, so no plaintext name ever hits disk;
//   • files are written atomic + NSFileProtectionComplete (unreadable while the
//     device is locked), under Application Support, namespaced to the LOCAL user.
//
// There is NO upload path in this file and none may be added: documents leave
// the store only as decrypted bytes handed to an explicit user action, and they
// stay OUT of clinician shares by default (finance/insurance docs always).
//
// Pure Foundation + CryptoKit so the whole store unit-tests on any platform.
import Foundation
import CryptoKit

// MARK: - Document kind (for list icons; inferred from the file name)

public enum VaultDocumentKind: String, Codable, Sendable {
    case pdf, image, text, spreadsheet, other

    public static func infer(fromName name: String) -> VaultDocumentKind {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf":                                          return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif",
             "tiff", "bmp", "webp":                          return .image
        case "txt", "md", "rtf":                             return .text
        case "csv", "xls", "xlsx", "numbers":                return .spreadsheet
        default:                                             return .other
        }
    }

    /// SF Symbol for the 38pt list tile.
    public var symbol: String {
        switch self {
        case .pdf:         return "doc.text.fill"
        case .image:       return "photo.fill"
        case .text:        return "doc.plaintext.fill"
        case .spreadsheet: return "tablecells.fill"
        case .other:       return "doc.fill"
        }
    }
}

// MARK: - Per-document metadata row

public struct VaultDocumentMeta: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String            // original file name, shown in the list
    public var kind: VaultDocumentKind
    public var addedAt: Date
    public var source: String          // where it came in from ("Files", "Photos", "Data sources")
    public var byteSize: Int           // plaintext size (display metadata)

    public init(id: UUID = UUID(), name: String, kind: VaultDocumentKind,
                addedAt: Date = Date(), source: String, byteSize: Int) {
        self.id = id; self.name = name; self.kind = kind
        self.addedAt = addedAt; self.source = source; self.byteSize = byteSize
    }
}

// MARK: - The store

public final class HealthVaultStore {

    public enum VaultStoreError: Error, Equatable { case unwritable, missingDocument }

    private let box: CryptoBox
    private let directory: URL
    private let fileManager: FileManager

    /// - box:       AES-256-GCM box bound to the device DEK (KeyVault.cryptoBox()).
    /// - userScope: a stable LOCAL user identifier (`LocalUserScope`) — NEVER a
    ///   backend/account id. Hashed into the on-disk folder name.
    /// - directory: base dir (defaults to Application Support); the store writes to
    ///   `<base>/health-vault/<sha(userScope)>/`.
    public init(box: CryptoBox,
                userScope: String,
                directory: URL? = nil,
                fileManager: FileManager = .default) {
        self.box = box
        self.fileManager = fileManager
        let base = directory ?? Self.defaultDirectory(fileManager: fileManager)
        self.directory = base
            .appendingPathComponent("health-vault", isDirectory: true)
            .appendingPathComponent(Self.hex(userScope), isDirectory: true)
    }

    /// Build from the shared KeyVault DEK (device-bound, Secure-Enclave wrapped).
    public convenience init(keyVault: KeyVault = .shared,
                            userScope: String,
                            directory: URL? = nil) throws {
        self.init(box: try keyVault.cryptoBox(), userScope: userScope, directory: directory)
    }

    // MARK: Read

    /// All metadata rows, newest first. Empty when nothing has been added yet.
    /// Throws if the index fails GCM authentication (tampered / wrong device key).
    public func documents() throws -> [VaultDocumentMeta] {
        try loadIndex().sorted { $0.addedAt > $1.addedAt }
    }

    /// Decrypt one document's bytes, or nil when the id is unknown. Throws if the
    /// blob fails GCM authentication — a tampered byte is an error, never garbage.
    public func open(_ id: UUID) throws -> Data? {
        let url = documentURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let sealed = try Data(contentsOf: url)
        return try box.open(sealed)
    }

    // MARK: Write

    /// Seal `data` and persist it, appending a metadata row. The plaintext never
    /// touches disk — it is encrypted the moment it's added.
    @discardableResult
    public func add(name: String, data: Data, source: String,
                    addedAt: Date = Date()) throws -> VaultDocumentMeta {
        let meta = VaultDocumentMeta(name: name,
                                     kind: .infer(fromName: name),
                                     addedAt: addedAt,
                                     source: source,
                                     byteSize: data.count)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let sealed = try box.seal(data)
        do {
            try sealed.write(to: documentURL(for: meta.id),
                             options: [.atomic, .completeFileProtection])
        } catch {
            throw VaultStoreError.unwritable
        }
        var index = (try? loadIndex()) ?? []
        index.append(meta)
        try saveIndex(index)
        return meta
    }

    /// Delete one document: the encrypted blob is removed from disk and the
    /// metadata row dropped. There is no trash — deletion is immediate and final.
    public func delete(_ id: UUID) throws {
        try? fileManager.removeItem(at: documentURL(for: id))
        var index = (try? loadIndex()) ?? []
        index.removeAll { $0.id == id }
        try saveIndex(index)
    }

    /// Wipe the whole space for this scope (GDPR erase / sign-out).
    public func clear() {
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Encrypted index

    private var indexURL: URL { directory.appendingPathComponent("index.vault") }

    private func loadIndex() throws -> [VaultDocumentMeta] {
        guard fileManager.fileExists(atPath: indexURL.path) else { return [] }
        let sealed = try Data(contentsOf: indexURL)
        let plain = try box.open(sealed)
        return try JSONDecoder().decode([VaultDocumentMeta].self, from: plain)
    }

    private func saveIndex(_ index: [VaultDocumentMeta]) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let plain = try JSONEncoder().encode(index)
        let sealed = try box.seal(plain)
        do {
            try sealed.write(to: indexURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw VaultStoreError.unwritable
        }
    }

    // MARK: - Paths

    /// Blob filenames are the sha of the id — like the index, nothing on disk
    /// leaks what a document is.
    private func documentURL(for id: UUID) -> URL {
        directory.appendingPathComponent(Self.hex(id.uuidString) + ".vaultdoc")
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
    }

    private static func hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
