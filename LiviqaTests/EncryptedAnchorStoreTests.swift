import Testing
import Foundation
import CryptoKit
@testable import Liviqa

// FR-ING-03/04 · NFR-SEC-02 — the encrypted anchor store (the "anchor codec"):
// HKQueryAnchor bytes are sealed with the device DEK and persisted on disk,
// per-key and per-local-user, never in plaintext.
struct EncryptedAnchorStoreTests {

    /// A fresh temp directory + a random AES-256 box per test (no Keychain needed).
    private func makeStore(box: CryptoBox? = nil,
                           scope: String = "local-user-A",
                           dir: URL) -> EncryptedAnchorStore {
        EncryptedAnchorStore(box: box ?? CryptoBox(key: SymmetricKey(size: .bits256)),
                             userScope: scope, directory: dir)
    }

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("anchortest-" + UUID().uuidString)
    }

    @Test func roundTripsAnEncryptedAnchorBlob() throws {
        let dir = tempDir()
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        let store = makeStore(box: box, dir: dir)
        let anchor = Data([0x01, 0x02, 0xFF, 0x00, 0x42])

        #expect(try store.load(for: "glucose") == nil)   // empty before save
        try store.save(anchor, for: "glucose")
        #expect(try store.load(for: "glucose") == anchor)

        // On-disk bytes are ciphertext, never the plaintext anchor.
        let onDisk = try Data(contentsOf: dir
            .appendingPathComponent("health-anchors")
            .appendingPathComponent(sha("local-user-A"))
            .appendingPathComponent(sha("glucose") + ".anchor"))
        #expect(onDisk != anchor)
        #expect(onDisk.count > anchor.count)             // nonce+tag overhead
    }

    @Test func keysAreIsolated() throws {
        let dir = tempDir()
        let store = makeStore(dir: dir)
        try store.save(Data([0xAA]), for: "glucose")
        try store.save(Data([0xBB]), for: "sleep")
        #expect(try store.load(for: "glucose") == Data([0xAA]))
        #expect(try store.load(for: "sleep") == Data([0xBB]))
        #expect(try store.load(for: "hrv") == nil)
    }

    @Test func wrongDeviceKeyFailsAuthentication() throws {
        let dir = tempDir()
        let scope = "local-user-A"
        let saver = makeStore(box: CryptoBox(key: SymmetricKey(size: .bits256)), scope: scope, dir: dir)
        try saver.save(Data([0x10, 0x20, 0x30]), for: "glucose")

        // A different DEK over the SAME file → GCM auth fails (never silent garbage).
        let other = makeStore(box: CryptoBox(key: SymmetricKey(size: .bits256)), scope: scope, dir: dir)
        #expect(throws: (any Error).self) { try other.load(for: "glucose") }
    }

    @Test func userScopesAreIsolated() throws {
        let dir = tempDir()
        let box = CryptoBox(key: SymmetricKey(size: .bits256))
        let a = makeStore(box: box, scope: "local-user-A", dir: dir)
        let b = makeStore(box: box, scope: "local-user-B", dir: dir)
        try a.save(Data([0x99]), for: "glucose")
        #expect(try a.load(for: "glucose") == Data([0x99]))
        #expect(try b.load(for: "glucose") == nil)   // other local user sees nothing
    }

    @Test func removeAndClearForgetAnchors() throws {
        let dir = tempDir()
        let store = makeStore(dir: dir)
        try store.save(Data([0x01]), for: "glucose")
        try store.save(Data([0x02]), for: "sleep")
        store.remove(for: "glucose")
        #expect(try store.load(for: "glucose") == nil)
        #expect(try store.load(for: "sleep") == Data([0x02]))
        store.clear()
        #expect(try store.load(for: "sleep") == nil)
    }

    @Test func anchorAdvancesOnEachSync() async throws {
        // Fake "provider": each sync sees the prior anchor and returns an advanced
        // one. Proves AnchorSync resumes from the persisted cursor and moves it
        // forward (the FR-ING-03/04 incremental contract), with no HealthKit.
        let store = makeStore(scope: "sync-user", dir: tempDir())
        var seen: [Data?] = []
        var counter = 0
        func sync() async throws -> Int {
            try await AnchorSync.advance(store: store, key: "steps") { current in
                seen.append(current)                      // resumes from here
                counter += 1
                return (added: counter, anchor: Data([UInt8(counter)]))
            }
        }

        let a1 = try await sync()
        let a2 = try await sync()
        let a3 = try await sync()

        #expect(a1 == 1)
        #expect(a2 == 2)
        #expect(a3 == 3)
        #expect(seen[0] == nil)                            // first sync: no prior anchor
        #expect(seen[1] == Data([1]))                      // second resumes from anchor #1
        #expect(seen[2] == Data([2]))                      // third resumes from anchor #2
        #expect(try store.load(for: "steps") == Data([3])) // persisted cursor advanced

        // A sync that returns no new anchor leaves the cursor where it was.
        let a4 = try await AnchorSync.advance(store: store, key: "steps") { _ in (added: 0, anchor: nil) }
        #expect(a4 == 0)
        #expect(try store.load(for: "steps") == Data([3]))
    }

    private func sha(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

#if canImport(HealthKit)
import HealthKit

// The HKQueryAnchor ⇆ Data adapter that feeds the encrypted store. Runs in the
// iOS simulator test bundle (HealthKit present).
struct AnchorCodecTests {
    @Test func encodesAndDecodesAQueryAnchor() throws {
        let anchor = HKQueryAnchor(fromValue: 4242)
        let data = try AnchorCodec.encode(anchor)
        #expect(!data.isEmpty)
        let back = try AnchorCodec.decode(data)
        #expect(back == anchor)
    }
}
#endif
