import Testing
import Foundation
import CryptoKit
@testable import Liviqa

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
