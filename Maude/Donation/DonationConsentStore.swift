// DonationConsentStore.swift — FR-DON-04 · the donor's grant and the record of
// every export, sealed on the device.
//
// ONE CONSENT MODEL, NOT TWO. The donation grant is a `WalletGrant` — the same
// type the wallet, the ledger and every share already use — with the new
// `RecipientType.controllerInternal` recipient (§2.6, OD-D2). Granting and
// withdrawing write ordinary `WalletEvent` rows (`consentGranted` /
// `consentRevoked`), so a donor has exactly one place to look and one way to
// revoke. This file adds no consent vocabulary of its own; it only makes those
// same records SURVIVE A RELAUNCH on the device, which the wallet's own
// backend-fed copies do not (the donation grant is deliberately device-local:
// the authoritative consent is the signed paper form plus the consent-engine
// grant the programme owner records out of band, and the app must not claim to
// have filed anything with a server it never contacted).
//
// The export log is not a second consent register — it is the evidence trail
// §4.6/§5.1 require: one row per export, saying what left and when, carrying
// COUNTS and a digest and never a value.
//
// Sealed with the KeyVault DEK through `CryptoBox`, written atomically with
// `.completeFileProtection` — the same idiom as `HealthVaultStore`. Nothing is
// written in plaintext: a grant reference plus a window is itself a statement
// about a named person's participation.
import Foundation
import CryptoKit

/// One export that actually happened. Counts and a digest — never a reading.
struct DonationExportRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let grantReference: String
    /// Real (unshifted) window this donation covered, on this device's clock.
    let windowStart: Date
    let windowEnd: Date
    let dateShiftDays: Int
    let counts: [String: Int]
    let fileName: String
    let byteCount: Int
    /// SHA-256 of the sealed bytes — identifies the file without retaining it.
    let sealedDigest: String

    var rowCount: Int { counts.values.reduce(0, +) }
}

/// Everything the device keeps about this donor's participation. Not
/// `Equatable`: `WalletEvent` is the app's ledger row type and is deliberately
/// reused here rather than re-declared, and it carries no equality.
struct DonationRecord: Codable {
    var grant: WalletGrant?
    var events: [WalletEvent]
    var exports: [DonationExportRecord]

    init(grant: WalletGrant? = nil, events: [WalletEvent] = [], exports: [DonationExportRecord] = []) {
        self.grant = grant; self.events = events; self.exports = exports
    }

    static let empty = DonationRecord()

    /// The grant is usable only while it is active and unexpired (§2.6: 12
    /// months, no auto-renew). An expired grant is not a donation licence.
    func activeGrant(now: Date = Date()) -> WalletGrant? {
        guard let grant, grant.isActive else { return nil }
        if let expiry = grant.expiresAt, expiry <= now { return nil }
        return grant
    }
}

struct DonationConsentStore {

    enum StoreError: Error, Equatable {
        case unwritable
        /// A record exists but will not open with this device's key. Writing is
        /// refused rather than silently replacing the only evidence that a grant
        /// and its exports ever existed (same reasoning as the vault's index).
        case unreadable
    }

    private let box: CryptoBox
    private let directory: URL
    private let fileManager: FileManager

    init(box: CryptoBox, userScope: String, directory: URL? = nil,
         fileManager: FileManager = .default) {
        self.box = box
        self.fileManager = fileManager
        self.directory = Self.scopeDirectory(userScope: userScope, directory: directory,
                                             fileManager: fileManager)
    }

    init(keyVault: KeyVault = .shared, userScope: String, directory: URL? = nil) throws {
        self.init(box: try keyVault.cryptoBox(), userScope: userScope, directory: directory)
    }

    // MARK: Read / write

    /// The stored record, or an empty one when nothing has been recorded yet.
    /// Throws `.unreadable` when a file exists that this key cannot open.
    func load() throws -> DonationRecord {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty }
        let sealed = try Data(contentsOf: fileURL)
        do {
            let plain = try box.open(sealed)
            return try JSONDecoder().decode(DonationRecord.self, from: plain)
        } catch {
            throw StoreError.unreadable
        }
    }

    func save(_ record: DonationRecord) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let plain = try JSONEncoder().encode(record)
        let sealed = try box.seal(plain)
        do {
            try sealed.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw StoreError.unwritable
        }
    }

    /// Wipe the donor record for this scope (GDPR erase / withdrawal follow-up
    /// on the device side). The corpus itself is erased by the custodians.
    func clear() {
        try? fileManager.removeItem(at: directory)
    }

    // MARK: Paths

    private var fileURL: URL { directory.appendingPathComponent("donation.v1.sealed") }

    private static func scopeDirectory(userScope: String, directory: URL?,
                                       fileManager: FileManager) -> URL {
        (directory ?? defaultDirectory(fileManager: fileManager))
            .appendingPathComponent("donation-programme", isDirectory: true)
            .appendingPathComponent(hex(userScope), isDirectory: true)
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                              appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
    }

    private static func hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Remove the whole donor-programme tree regardless of scope — used by the
    /// erase-everything path, which must not depend on a key being available.
    static func deleteAll(fileManager: FileManager = .default) {
        let base = defaultDirectory(fileManager: fileManager)
            .appendingPathComponent("donation-programme", isDirectory: true)
        try? fileManager.removeItem(at: base)
    }
}
