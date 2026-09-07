import Testing
import Foundation
import CryptoKit
@testable import Maude

// FR-ING-15 (T-ING-15) · NFR-SEC-02 — the encrypted document store behind the
// "Health data space": document bytes AND the metadata index are AES-256-GCM
// ciphertext at rest, metadata rows persist across store instances, and delete
// really deletes (blob gone from disk, not just from the list).
struct HealthVaultStoreTests {

    /// A fresh temp directory + a random AES-256 box per test (no Keychain needed).
    private func makeStore(box: CryptoBox? = nil,
                           scope: String = "local-user-A",
                           dir: URL) -> HealthVaultStore {
        HealthVaultStore(box: box ?? CryptoBox(key: SymmetricKey(size: .bits256)),
                         userScope: scope, directory: dir)
    }

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("vaulttest-" + UUID().uuidString)
    }

    private func scopeDir(_ base: URL, scope: String = "local-user-A") -> URL {
        base.appendingPathComponent("health-vault").appendingPathComponent(sha(scope))
    }

    /// Everything at rest is ciphertext: the blob round-trips through open(),
    /// the on-disk bytes are not the plaintext, and neither the blob nor the
    /// index file contains the document's name or content bytes in the clear.
    @Test func encryptsDocumentAndIndexAtRest() throws {
        let dir = tempDir()
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        let store = makeStore(box: box, dir: dir)
        let content = Data("HbA1c 51 mmol/mol — very private lab letter".utf8)

        #expect(try store.documents().isEmpty)              // empty before add
        let meta = try store.add(name: "Blood panel — Rigshospitalet.pdf",
                                 data: content, source: "Files")
        #expect(try store.open(meta.id) == content)          // round-trip

        // Inspect the raw files on disk: 2 files (blob + index), all ciphertext.
        let files = try FileManager.default.contentsOfDirectory(at: scopeDir(dir),
                                                                includingPropertiesForKeys: nil)
        #expect(files.count == 2)
        for url in files {
            let raw = try Data(contentsOf: url)
            #expect(raw != content)
            #expect(raw.range(of: content) == nil)                              // content never in clear
            #expect(raw.range(of: Data("Rigshospitalet".utf8)) == nil)          // name never in clear
        }
    }

    /// Metadata rows (name, kind, added date, source, byte size) survive a new
    /// store instance over the same directory + key — the persistence contract.
    @Test func metadataRowsPersistAcrossInstances() throws {
        let dir = tempDir()
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        let store = makeStore(box: box, dir: dir)
        let pdf = try store.add(name: "Cardiology letter.pdf",
                                data: Data(repeating: 0x11, count: 300), source: "Files")
        let photo = try store.add(name: "Wound photo.jpg",
                                  data: Data(repeating: 0x22, count: 500), source: "Photos")

        let reopened = makeStore(box: box, dir: dir)
        let docs = try reopened.documents()
        #expect(docs.count == 2)
        #expect(Set(docs.map(\.id)) == [pdf.id, photo.id])

        let letter = try #require(docs.first { $0.id == pdf.id })
        #expect(letter.name == "Cardiology letter.pdf")
        #expect(letter.kind == .pdf)
        #expect(letter.source == "Files")
        #expect(letter.byteSize == 300)

        let jpg = try #require(docs.first { $0.id == photo.id })
        #expect(jpg.kind == .image)
        #expect(jpg.source == "Photos")
        #expect(jpg.byteSize == 500)

        // Newest first (photo was added after the pdf).
        #expect(docs.first?.id == photo.id)
    }

    /// Delete really deletes: the row is gone, open() finds nothing, and the
    /// encrypted blob file itself no longer exists on disk.
    @Test func deleteReallyDeletes() throws {
        let dir = tempDir()
        let store = makeStore(dir: dir)
        let keep = try store.add(name: "HbA1c history.pdf",
                                 data: Data([0x01, 0x02]), source: "Files")
        let gone = try store.add(name: "Insurance card.pdf",
                                 data: Data([0x03, 0x04]), source: "Files")

        var blobs = try blobFiles(in: scopeDir(dir))
        #expect(blobs.count == 2)

        try store.delete(gone.id)
        #expect(try store.open(gone.id) == nil)
        #expect(try store.documents().map(\.id) == [keep.id])
        blobs = try blobFiles(in: scopeDir(dir))
        #expect(blobs.count == 1)                             // the blob file is really gone
        #expect(try store.open(keep.id) == Data([0x01, 0x02]))

        store.clear()
        #expect(try store.documents().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: scopeDir(dir).path))
    }

    /// A different DEK over the same files ⇒ GCM authentication fails loudly —
    /// never silent garbage (the property the integrity guarantee rests on).
    @Test func wrongDeviceKeyFailsAuthentication() throws {
        let dir = tempDir()
        let writer = makeStore(box: CryptoBox(key: SymmetricKey(size: .bits256)), dir: dir)
        let meta = try writer.add(name: "Note.txt", data: Data([0xAA]), source: "Files")

        let intruder = makeStore(box: CryptoBox(key: SymmetricKey(size: .bits256)), dir: dir)
        #expect(throws: (any Error).self) { try intruder.documents() }
        #expect(throws: (any Error).self) { try intruder.open(meta.id) }
    }

    /// Local-user scopes are isolated on disk — one scope never sees another's docs.
    @Test func userScopesAreIsolated() throws {
        let dir = tempDir()
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        let a = makeStore(box: box, scope: "local-user-A", dir: dir)
        let b = makeStore(box: box, scope: "local-user-B", dir: dir)
        let meta = try a.add(name: "Scan.pdf", data: Data([0x99]), source: "Files")
        #expect(try a.open(meta.id) == Data([0x99]))
        #expect(try b.documents().isEmpty)
        #expect(try b.open(meta.id) == nil)
    }

    // MARK: - The two failure classes (robustness, FR-ING-15)

    /// RECOVERABLE class. A scope with no key material yet is not an error at
    /// all: the space initialises empty, reports `.ready`, and accepts a
    /// document. This is the state that was wrongly rendering as "unreadable".
    @Test func freshSpaceIsReadyAndWritable() throws {
        let dir = tempDir()
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        let session = HealthVaultSession.open(userScope: "local-user-A", directory: dir) { box }

        #expect(session.access == .ready)
        #expect(session.access.canAddDocuments)
        #expect(session.documents.isEmpty)
        let store = try #require(session.store)
        #expect(store.canAddDocuments)
        _ = try store.add(name: "First letter.pdf", data: Data([0x01]), source: "Files")
        #expect(try store.documents().count == 1)
    }

    /// RECOVERABLE class. A key that cannot be provisioned right now is reported
    /// as `.keyUnavailable` / `.lockedUntilDeviceUnlock` — retryable states that
    /// never claim documents are unreadable, because none may even exist.
    @Test func unprovisionableKeyIsRecoverableNotUnreadable() throws {
        let dir = tempDir()

        let locked = HealthVaultSession.open(userScope: "local-user-A", directory: dir) {
            throw CryptoError.keychain(errSecInteractionNotAllowed)
        }
        #expect(locked.access == .lockedUntilDeviceUnlock)
        #expect(locked.access.isRetryable)
        #expect(!locked.access.canAddDocuments)

        let unavailable = HealthVaultSession.open(userScope: "local-user-A", directory: dir) {
            throw CryptoError.keyMaterialUnavailable
        }
        #expect(unavailable.access == .keyUnavailable)
        #expect(unavailable.access.isRetryable)

        // Sealed key material, but nothing sealed on disk ⇒ still not "unreadable
        // documents": there are none.
        let noData = HealthVaultSession.open(userScope: "local-user-A", directory: dir) {
            throw CryptoError.sealedKeyUnreadable
        }
        #expect(noData.access == .keyUnavailable)
        #expect(!HealthVaultStore.hasSealedData(userScope: "local-user-A", directory: dir))
    }

    /// UNREADABLE class. Documents sealed to key material this device no longer
    /// holds: the honest state, with adding refused so the index can't be
    /// replaced — and nothing on disk touched.
    @Test func sealedDataUnreadableIsReportedAndNonDestructive() throws {
        let dir = tempDir()
        let ownKey = CryptoBox(key: SymmetricKey(size: .bits256))
        let writer = makeStore(box: ownKey, dir: dir)
        let kept = try writer.add(name: "Cardiology letter.pdf",
                                  data: Data(repeating: 0x7A, count: 64), source: "Files")
        let indexBefore = try Data(contentsOf: scopeDir(dir).appendingPathComponent("index.vault"))
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: scopeDir(dir).path).sorted()

        // Same files, a different device key.
        let session = HealthVaultSession.open(userScope: "local-user-A", directory: dir) {
            CryptoBox(key: SymmetricKey(size: .bits256))
        }
        #expect(session.access == .sealedDataUnreadable)
        #expect(!session.access.canAddDocuments)
        #expect(!session.access.isRetryable)
        #expect(session.documents.isEmpty)

        let stranger = try #require(session.store)
        #expect(!stranger.canAddDocuments)
        #expect(throws: HealthVaultStore.VaultStoreError.unreadableIndex) {
            try stranger.add(name: "Intruder.pdf", data: Data([0xFF]), source: "Files")
        }
        #expect(throws: HealthVaultStore.VaultStoreError.unreadableIndex) {
            try stranger.delete(kept.id)
        }

        // NOTHING was deleted, re-keyed or overwritten.
        let indexAfter = try Data(contentsOf: scopeDir(dir).appendingPathComponent("index.vault"))
        #expect(indexAfter == indexBefore)
        #expect(try FileManager.default.contentsOfDirectory(atPath: scopeDir(dir).path).sorted() == filesBefore)

        // And the real key still opens everything it did before.
        let recovered = makeStore(box: ownKey, dir: dir)
        #expect(try recovered.documents().map(\.id) == [kept.id])
        #expect(try recovered.open(kept.id) == Data(repeating: 0x7A, count: 64))
        #expect(recovered.canAddDocuments)
    }

    /// A key that cannot read the index must not be able to erase it by adding —
    /// the specific data-loss path: `add` used to start a fresh index and write
    /// it over the old one.
    @Test func addNeverOverwritesAnUnreadableIndex() throws {
        let dir = tempDir()
        let realKey = CryptoBox(key: SymmetricKey(size: .bits256))
        let owner = makeStore(box: realKey, dir: dir)
        let a = try owner.add(name: "A.pdf", data: Data([0x0A]), source: "Files")
        let b = try owner.add(name: "B.pdf", data: Data([0x0B]), source: "Files")

        let stranger = makeStore(box: CryptoBox(key: SymmetricKey(size: .bits256)), dir: dir)
        for i in 0 ..< 3 {
            #expect(throws: (any Error).self) {
                try stranger.add(name: "junk\(i).pdf", data: Data([0xEE]), source: "Files")
            }
        }
        // No stray blob was left behind by the refused writes, and both original
        // documents are still listed and openable by the real key.
        let blobs = try blobFiles(in: scopeDir(dir))
        #expect(blobs.count == 2)
        let reopened = makeStore(box: realKey, dir: dir)
        #expect(Set(try reopened.documents().map(\.id)) == [a.id, b.id])
        #expect(try reopened.open(a.id) == Data([0x0A]))
        #expect(try reopened.open(b.id) == Data([0x0B]))
    }

    /// Kind inference drives the list icons — spot-check the mapping.
    @Test func kindIsInferredFromTheFileName() {
        #expect(VaultDocumentKind.infer(fromName: "labs.PDF") == .pdf)
        #expect(VaultDocumentKind.infer(fromName: "lunch.HEIC") == .image)
        #expect(VaultDocumentKind.infer(fromName: "notes.txt") == .text)
        #expect(VaultDocumentKind.infer(fromName: "cgm-export.csv") == .spreadsheet)
        #expect(VaultDocumentKind.infer(fromName: "export.zip") == .other)
    }

    // MARK: helpers

    private func blobFiles(in dir: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "vaultdoc" }
    }

    private func sha(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
