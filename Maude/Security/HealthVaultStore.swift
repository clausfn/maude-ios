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
//     in the Secure Enclave (KeyVault; software-key fallback where no enclave
//     can mint, recorded in `KeyVault.protection`/`isHardwareBacked` — the UI
//     copy follows it honestly and never claims enclave protection it lacks);
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

    public enum VaultStoreError: Error, Equatable {
        case unwritable
        case missingDocument
        /// An index file exists but does not open with this device's key — the
        /// documents it describes are sealed and cannot be listed. Writing is
        /// refused in this state: a new index would overwrite the old one and
        /// destroy the only record of what is on disk.
        case unreadableIndex
    }

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
        self.directory = Self.scopeDirectory(userScope: userScope, directory: directory,
                                             fileManager: fileManager)
    }

    private static func scopeDirectory(userScope: String, directory: URL?,
                                       fileManager: FileManager) -> URL {
        (directory ?? defaultDirectory(fileManager: fileManager))
            .appendingPathComponent("health-vault", isDirectory: true)
            .appendingPathComponent(hex(userScope), isDirectory: true)
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

    /// Can a document be added right now? True for an empty space and for a
    /// readable one; false only when an index exists that this key can't open,
    /// because adding would overwrite it. The "Add a document" affordance is
    /// enabled from exactly this answer.
    public var canAddDocuments: Bool {
        do { _ = try loadIndex(); return true } catch { return false }
    }

    /// Is there anything sealed in this scope at all? Answered from the file
    /// system alone (no key needed), so a caller that could not even provision a
    /// key can still tell "nothing has been stored yet" from "documents exist".
    public static func hasSealedData(userScope: String,
                                     directory: URL? = nil,
                                     fileManager: FileManager = .default) -> Bool {
        let dir = scopeDirectory(userScope: userScope, directory: directory, fileManager: fileManager)
        let files = (try? fileManager.contentsOfDirectory(atPath: dir.path)) ?? []
        return !files.isEmpty
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
    ///
    /// Throws `.unreadableIndex` (before writing anything) when an index exists
    /// that this key can't open: adding on top of it would replace the record of
    /// documents that are still on disk. `canAddDocuments` answers the same
    /// question ahead of time, so the UI can disable the affordance honestly.
    @discardableResult
    public func add(name: String, data: Data, source: String,
                    addedAt: Date = Date()) throws -> VaultDocumentMeta {
        var index = try loadIndex()           // refuses on an unreadable index
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
        index.append(meta)
        do {
            try saveIndex(index)
        } catch {
            // The blob is on disk but unlisted — remove it rather than leave an
            // orphan the citizen can never see or delete.
            try? fileManager.removeItem(at: documentURL(for: meta.id))
            throw error
        }
        return meta
    }

    /// Delete one document: the encrypted blob is removed from disk and the
    /// metadata row dropped. There is no trash — deletion is immediate and final.
    /// Refuses on an unreadable index for the same reason `add` does.
    public func delete(_ id: UUID) throws {
        var index = try loadIndex()
        try? fileManager.removeItem(at: documentURL(for: id))
        index.removeAll { $0.id == id }
        try saveIndex(index)
    }

    /// Wipe the whole space for this scope (GDPR erase / sign-out).
    public func clear() {
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Encrypted index

    private var indexURL: URL { directory.appendingPathComponent("index.vault") }

    /// No index file ⇒ an empty space (a normal, writable first-run state).
    /// An index file that won't open or decode ⇒ `.unreadableIndex` — the two
    /// must never be conflated: the first invites the citizen to add a document,
    /// the second must not be written over.
    private func loadIndex() throws -> [VaultDocumentMeta] {
        guard fileManager.fileExists(atPath: indexURL.path) else { return [] }
        let sealed = try Data(contentsOf: indexURL)
        do {
            let plain = try box.open(sealed)
            return try JSONDecoder().decode([VaultDocumentMeta].self, from: plain)
        } catch {
            throw VaultStoreError.unreadableIndex
        }
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

// MARK: - Opening the space: the four states a screen may be in

/// What the encrypted space can do right now. The two FAILURE classes are the
/// point of this type and must never be collapsed into one message:
///
///   • `.lockedUntilDeviceUnlock` / `.keyUnavailable` — RECOVERABLE. Either the
///     phone hasn't been unlocked since boot, or no key could be prepared yet.
///     Nothing is lost, nothing is claimed lost, and a retry (or a first unlock)
///     fixes it. Where a key CAN be prepared this state never appears at all:
///     the space simply initialises empty and accepts documents.
///   • `.sealedDataUnreadable` — the genuinely unreadable case: documents are on
///     disk sealed to key material this device no longer has. The honest message
///     stays, adding is refused (it would overwrite the index), and NOTHING is
///     deleted or re-keyed. Recovery is a deliberate user decision, not ours.
public enum VaultAccess: Equatable, Sendable {
    case ready
    case lockedUntilDeviceUnlock
    case sealedDataUnreadable
    case keyUnavailable

    /// True only when adding a document is actually possible.
    public var canAddDocuments: Bool { self == .ready }

    /// True when simply trying again later is the right advice.
    public var isRetryable: Bool { self == .lockedUntilDeviceUnlock || self == .keyUnavailable }
}

/// One attempt to open the space: the store (when there is one), the state the
/// screen must render, and the documents already read. Never throws — the whole
/// point is that every failure lands in a named, honest state.
public struct HealthVaultSession {
    public let store: HealthVaultStore?
    public let access: VaultAccess
    public let documents: [VaultDocumentMeta]

    public init(store: HealthVaultStore?, access: VaultAccess, documents: [VaultDocumentMeta]) {
        self.store = store; self.access = access; self.documents = documents
    }

    public static func open(keyVault: KeyVault = .shared,
                            userScope: String,
                            directory: URL? = nil) -> HealthVaultSession {
        open(userScope: userScope, directory: directory) { try keyVault.cryptoBox() }
    }

    /// Same, over any key provider — the seam the failure-class tests drive, so
    /// each state can be proven without a locked phone or a wiped Keychain.
    public static func open(userScope: String,
                            directory: URL? = nil,
                            boxProvider: () throws -> CryptoBox) -> HealthVaultSession {
        let box: CryptoBox
        do {
            box = try boxProvider()
        } catch {
            return HealthVaultSession(store: nil,
                                      access: classifyKeyFailure(error, userScope: userScope,
                                                                 directory: directory),
                                      documents: [])
        }
        let store = HealthVaultStore(box: box, userScope: userScope, directory: directory)
        do {
            return HealthVaultSession(store: store, access: .ready,
                                      documents: try store.documents())
        } catch {
            // A locked file is a wait; anything else means the index itself is
            // sealed beyond this key.
            let access: VaultAccess = KeyFailure.isDeviceLocked(error)
                ? .lockedUntilDeviceUnlock : .sealedDataUnreadable
            return HealthVaultSession(store: store, access: access, documents: [])
        }
    }

    private static func classifyKeyFailure(_ error: any Error, userScope: String,
                                           directory: URL?) -> VaultAccess {
        if KeyFailure.isDeviceLocked(error) { return .lockedUntilDeviceUnlock }
        if let c = error as? CryptoError, c == .sealedKeyUnreadable {
            // Only call the data unreadable when there IS data.
            return HealthVaultStore.hasSealedData(userScope: userScope, directory: directory)
                ? .sealedDataUnreadable : .keyUnavailable
        }
        return .keyUnavailable
    }
}
