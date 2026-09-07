import Testing
import Foundation
import CryptoKit
import Security
@testable import Maude

// FR-ING-15 · NFR-SEC-02 — key provisioning has to survive the environments the
// Health data space actually meets: an unsigned build where the Keychain answers
// errSecMissingEntitlement (-34018) for every call, hardware with no usable
// Secure Enclave, a phone not yet unlocked since boot, and key material that
// this device can no longer use. Each has a DIFFERENT correct outcome, and the
// UI claim ("Secure Enclave" vs "never leaves this device" vs no claim at all)
// must follow the path that is actually live.
struct KeyVaultFallbackTests {

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kvtest-" + UUID().uuidString)
    }

    private func freshVault(_ dir: URL, service: String = UUID().uuidString) -> KeyVault {
        KeyVault(service: "test." + service, fileStoreDirectory: dir)
    }

    // MARK: - Provisioning survives whatever this machine offers

    /// A DEK is always obtainable, it is AES-256, and it is the SAME key on the
    /// next launch — whichever storage the environment forced us onto. This is
    /// the regression test for the dead "Health data space" screen: on an
    /// unsigned simulator build every Keychain call returns -34018, and that
    /// used to abort the whole vault.
    @Test func dekIsProvisionedAndStableWhateverTheEnvironment() throws {
        let dir = tempDir()
        let service = UUID().uuidString
        let vault = freshVault(dir, service: service)

        let dek = try vault.dataEncryptionKey()
        #expect(dek.bitCount == 256)
        #expect(vault.protection != .notProvisioned)

        // A second, cold instance over the same service + directory must unwrap
        // the same DEK — not mint a new one (which would orphan documents).
        let relaunched = freshVault(dir, service: service)
        #expect(try relaunched.dataEncryptionKey() == dek)
        #expect(relaunched.protection == vault.protection)

        // And the box it hands out really is the 256-bit one.
        #expect(try vault.cryptoBox().keyBitCount == 256)
    }

    /// The claim rendered on screen is derived from the path that is live, not
    /// assumed: `isHardwareBacked` is true only for an enclave-held key, and no
    /// claim at all is available before provisioning.
    @Test func hardwareClaimFollowsTheLiveKeyPath() throws {
        let vault = freshVault(tempDir())
        #expect(vault.protection == .notProvisioned)
        #expect(!vault.isHardwareBacked)         // nothing provisioned ⇒ claim nothing

        _ = try vault.dataEncryptionKey()
        #expect(vault.protection == .secureEnclave || vault.protection == .softwareDeviceKey)
        #expect(vault.isHardwareBacked == (vault.protection == .secureEnclave))
        if !SecureEnclave.isAvailable {
            #expect(vault.protection == .softwareDeviceKey)   // no enclave ⇒ never claim one
        }
    }

    /// Key material this device cannot use is reported as `sealedKeyUnreadable`
    /// — NOT quietly replaced. Replacing it would leave the documents it sealed
    /// permanently unopenable while the UI cheerfully showed an empty space.
    @Test func unusableKeyMaterialIsNeverSilentlyReplaced() throws {
        let dir = tempDir()
        let service = UUID().uuidString
        let vault = freshVault(dir, service: service)
        let original = try vault.dataEncryptionKey()

        // Corrupt the stored device key the way a restore-onto-new-hardware does.
        let store = DeviceKeyFileStore(service: "test." + service, directory: dir)
        if ((try? store.read(account: "maude.device-key.v1")) ?? nil) != nil {
            try store.write(Data(repeating: 0x5A, count: 40), account: "maude.device-key.v1")
            let reopened = freshVault(dir, service: service)
            #expect(throws: CryptoError.sealedKeyUnreadable) { _ = try reopened.dataEncryptionKey() }
            // The wrapped DEK is still on disk, untouched.
            #expect(((try? store.read(account: "maude.wrapped-dek.v1")) ?? nil) != nil)
            #expect(original.bitCount == 256)
        }
    }

    /// A wrapped DEK whose device key is gone is the same refusal: the sealed
    /// documents belong to a key that no longer exists, and minting a fresh one
    /// would be a silent re-key over the citizen's data.
    @Test func wrappedKeyWithoutItsDeviceKeyIsRefused() throws {
        let dir = tempDir()
        let service = UUID().uuidString
        _ = try freshVault(dir, service: service).dataEncryptionKey()

        let store = DeviceKeyFileStore(service: "test." + service, directory: dir)
        guard ((try? store.read(account: "maude.wrapped-dek.v1")) ?? nil) != nil else { return }
        try store.delete(account: "maude.device-key.v1")

        let reopened = freshVault(dir, service: service)
        #expect(throws: CryptoError.sealedKeyUnreadable) { _ = try reopened.dataEncryptionKey() }
    }

    // MARK: - Failure classification (the two classes the UI must separate)

    @Test func keychainFailuresAreClassifiedIntoTheTwoClasses() {
        // Temporarily out of reach — a wait, never data loss, never a re-key.
        #expect(KeyFailure.isDeviceLocked(CryptoError.keychain(errSecInteractionNotAllowed)))
        #expect(KeyFailure.isDeviceLocked(CryptoError.keychain(errSecAuthFailed)))
        #expect(!KeyFailure.isStorageUnusable(CryptoError.keychain(errSecInteractionNotAllowed)))

        // Keychain cannot serve this process at all — the device-file fallback
        // is legitimate here and only here.
        #expect(KeyFailure.isStorageUnusable(CryptoError.keychain(errSecMissingEntitlement)))
        #expect(KeyFailure.isStorageUnusable(CryptoError.keychain(errSecNotAvailable)))
        #expect(!KeyFailure.isDeviceLocked(CryptoError.keychain(errSecMissingEntitlement)))

        // Ordinary absence is neither: it just means "provision one".
        #expect(!KeyFailure.isDeviceLocked(CryptoError.keychain(errSecItemNotFound)))
        #expect(!KeyFailure.isStorageUnusable(CryptoError.keychain(errSecItemNotFound)))

        // Reading a complete-protection file before first unlock reads as locked.
        let locked = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        #expect(KeyFailure.isDeviceLocked(locked))
        #expect(!KeyFailure.isDeviceLocked(CryptoError.malformedWrappedKey))
    }

    // MARK: - The device-file store the fallback rests on

    /// Round-trip, delete, and — the part that keeps "the key never leaves this
    /// device" honest — nothing readable about the account on disk.
    @Test func deviceFileStoreRoundTripsAndHidesItsAccountNames() throws {
        let dir = tempDir()
        let store = DeviceKeyFileStore(service: "xyz.ppcn.maude.keyvault", directory: dir)
        #expect(try store.read(account: "maude.device-key.v1") == nil)

        let material = Data((0 ..< 32).map { UInt8($0) })
        try store.write(material, account: "maude.device-key.v1")
        #expect(try store.read(account: "maude.device-key.v1") == material)

        let files = try FileManager.default
            .contentsOfDirectory(atPath: dir.appendingPathComponent("maude-keystore").path)
        #expect(files.count == 1)
        let name = try #require(files.first)
        #expect(!name.contains("device-key"))
        #expect(!name.contains("maude.device"))
        #expect(name.hasSuffix(".key"))

        try store.delete(account: "maude.device-key.v1")
        #expect(try store.read(account: "maude.device-key.v1") == nil)
        try store.delete(account: "maude.device-key.v1")   // deleting nothing is not an error
    }

    /// Two accounts never collide, and two services never see each other's
    /// material (the scope-isolation property, one layer down).
    @Test func deviceFileStoreIsolatesAccountsAndServices() throws {
        let dir = tempDir()
        let a = DeviceKeyFileStore(service: "service.A", directory: dir)
        let b = DeviceKeyFileStore(service: "service.B", directory: dir)
        try a.write(Data([0xAA]), account: "one")
        try a.write(Data([0xBB]), account: "two")
        try b.write(Data([0xCC]), account: "one")

        #expect(try a.read(account: "one") == Data([0xAA]))
        #expect(try a.read(account: "two") == Data([0xBB]))
        #expect(try b.read(account: "one") == Data([0xCC]))
        #expect(try b.read(account: "two") == nil)
    }

    // MARK: - Scope stability (the folder the documents live in)

    /// The local scope picks the on-disk folder. If it changed between calls the
    /// citizen's own documents would vanish from view, so it must be stable even
    /// where the Keychain cannot hold it.
    @Test func localUserScopeIsStableAcrossCalls() {
        let first = LocalUserScope.current()
        #expect(!first.isEmpty)
        #expect(LocalUserScope.current() == first)
        #expect(LocalUserScope.current() == first)
    }

    // MARK: - End to end: the space opens on this machine

    /// The whole path the screen takes, on whatever this machine is: open the
    /// space with the shared vault, add a document, read it back.
    @Test func sharedVaultOpensTheSpaceAndAcceptsADocument() throws {
        let dir = tempDir()
        let session = HealthVaultSession.open(keyVault: .shared,
                                              userScope: LocalUserScope.current(),
                                              directory: dir)
        #expect(session.access == .ready)
        let store = try #require(session.store)
        let meta = try store.add(name: "Lab letter.pdf", data: Data("private".utf8), source: "Files")
        #expect(try store.open(meta.id) == Data("private".utf8))
        #expect(try store.documents().count == 1)
        store.clear()
    }
}
