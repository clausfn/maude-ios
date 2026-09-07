// AppState+Donation.swift — FR-DON-04/05 wiring · consent first, then export.
//
// The donation grant is an ordinary `WalletGrant` and every state change writes
// an ordinary `WalletEvent`, so the donor's consent record reads the same way
// every other consent on this phone reads. What this extension adds is:
//
//   • the grant and its events are also persisted on the DEVICE (sealed), so a
//     relaunch does not silently lose the record of what a donor agreed to;
//   • the grant is merged into `grants` / `walletEvents`, so the donation shows
//     up on the wallet and the consent ledger like everything else — a donor
//     never has to look in a second place;
//   • the export path cannot be reached without an active grant, and every
//     export appends a ledger row saying what left and when.
//
// In every shipped build `DonationProgramme.isDonorBuild` is a compile-time
// `false`, so `loadDonationConsent()` reads nothing, `hasActiveDonationGrant`
// is always false, and every consent surface renders exactly the copy it
// rendered before this programme existed.
import Foundation
import SwiftData

extension AppState {

    // MARK: - State

    /// The donor record for this device (grant + events + export log), or the
    /// empty record. Cached in the observable `donationRecordStorage`.
    var donationRecord: DonationRecord { donationRecordStorage }

    /// The active, unexpired donation grant — nil for everyone else.
    var donationGrant: WalletGrant? { donationRecordStorage.activeGrant() }

    /// Drives the scoped consent copy (`DonationCopy.readingsClaim`).
    var hasActiveDonationGrant: Bool { donationGrant != nil }

    /// Every export that has happened from this phone, newest first.
    var donationExports: [DonationExportRecord] {
        donationRecordStorage.exports.sorted { $0.occurredAt > $1.occurredAt }
    }

    // MARK: - Load

    /// Restore the donor record from the sealed device store and surface it on
    /// the ordinary consent surfaces. No-op unless this is a donor build.
    func loadDonationConsent() {
        guard DonationProgramme.isDonorBuild else { return }
        do {
            let store = try DonationConsentStore(userScope: LocalUserScope.current())
            donationRecordStorage = try store.load()
            donationConsentUnreadable = false
            mergeDonationIntoWallet()
        } catch DonationConsentStore.StoreError.unreadable {
            // A record EXISTS and this device's key will not open it. Say so;
            // never overwrite it, and never present "no donation" as the answer.
            donationConsentUnreadable = true
        } catch {
            // No key could be prepared this pass — a locked phone, or a build
            // that cannot reach the Keychain. That is a WAIT, not a loss: the
            // record is simply not loaded, nothing is claimed unreadable, and
            // nothing is written. (Same discipline as the vault's four states.)
            donationConsentUnreadable = false
        }
    }

    /// Show the donation grant and its events on the wallet / ledger surfaces
    /// alongside everything else, without duplicating a row already present.
    private func mergeDonationIntoWallet() {
        if let grant = donationRecordStorage.grant {
            if let idx = grants.firstIndex(where: { $0.id == grant.id }) { grants[idx] = grant }
            else { grants.append(grant) }
        }
        for event in donationRecordStorage.events where !walletEvents.contains(where: { $0.id == event.id }) {
            walletEvents.insert(event, at: 0)
        }
    }

    // MARK: - Consent

    /// Record the grant from the donor's SIGNED consent form.
    ///
    /// The paper form (and the consent-engine grant the programme owner files
    /// out of band) is the authoritative consent; this records it on the device
    /// so the app can (a) know a donation is permitted, (b) show the donor what
    /// they agreed to, and (c) refuse every export once it is withdrawn or has
    /// expired. Nothing is sent anywhere — the app contacts no server here, and
    /// says so on screen rather than implying a filing it never performed.
    @MainActor
    @discardableResult
    func recordDonationGrant(reference: String,
                             scopes: Set<String>,
                             now: Date = Date()) -> Bool {
        guard DonationProgramme.isDonorBuild else { return false }
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty, !scopes.isEmpty else { return false }

        let expiry = Calendar(identifier: .gregorian)
            .date(byAdding: .month, value: DonationProgramme.grantMonths, to: now) ?? now

        let grant = WalletGrant(
            id: UUID(),
            userId: profile?.id,
            recipientName: DonationProgramme.recipientName,
            recipientType: .controllerInternal,
            scopeKeys: scopes.sorted(),
            isActive: true,
            expiresAt: expiry,
            createdAt: now,
            ceGrantRef: ref)

        let event = WalletEvent(id: UUID(), userId: profile?.id,
                                eventType: .consentGranted,
                                actorName: DonationProgramme.recipientName,
                                scopeKeys: grant.scopeKeys,
                                decision: .approved, occurredAt: now)

        var record = donationRecordStorage
        record.grant = grant
        record.events.insert(event, at: 0)
        return persistDonation(record)
    }

    /// Withdraw. The grant is deactivated (never deleted — the evidence that it
    /// existed is what proves the programme was lawful), a `consentRevoked`
    /// event is appended, and every future export refuses. Erasing the corpus
    /// itself is the custodians' operation, on the donor's request; the app
    /// cannot reach it and must not pretend otherwise.
    @MainActor
    @discardableResult
    func withdrawDonationGrant(now: Date = Date()) -> Bool {
        guard DonationProgramme.isDonorBuild, var grant = donationRecordStorage.grant else { return false }
        grant.isActive = false

        let event = WalletEvent(id: UUID(), userId: profile?.id,
                                eventType: .consentRevoked,
                                actorName: DonationProgramme.recipientName,
                                scopeKeys: grant.scopeKeys,
                                decision: .approved, occurredAt: now)

        var record = donationRecordStorage
        record.grant = grant
        record.events.insert(event, at: 0)
        let ok = persistDonation(record)
        // A withdrawn donor should not be left with a sealed file staged on the
        // phone from before the withdrawal.
        DonationExport.purgeStaged()
        return ok
    }

    // MARK: - Export

    /// Assemble, seal and stage a donation, then append the ledger row.
    /// - Returns: the sealed file's URL for the share sheet.
    /// - Throws: `DonationExport.Refusal` — each case carries copy the screen
    ///   shows verbatim.
    @MainActor
    func exportDonation(now: Date = Date()) throws -> URL {
        guard let container = donationModelContainer else { throw DonationExport.Refusal.storeUnavailable }
        guard let grant = donationGrant else { throw DonationExport.Refusal.noActiveGrant }

        let result = try DonationExport.run(context: container.mainContext,
                                            grant: grant,
                                            // Refuse on BOTH meanings of the old
                                            // flag: a sample on screen, and a
                                            // session with no real readings at
                                            // all. Nothing invented, and nothing
                                            // empty, may enter the collection.
                                            isDemoData: isSampleMode || hasNoRealReadings,
                                            now: now)

        // The ledger row: what left, when, how many rows of each stream, and the
        // digest of the exact bytes — never a value.
        let event = WalletEvent(id: UUID(), userId: profile?.id,
                                eventType: .dataAccessed,
                                actorName: DonationProgramme.recipientName,
                                scopeKeys: grant.scopeKeys,
                                decision: .approved, occurredAt: result.record.occurredAt)

        var record = donationRecordStorage
        record.exports.insert(result.record, at: 0)
        record.events.insert(event, at: 0)
        _ = persistDonation(record)

        return result.url
    }

    /// What WOULD be in a file right now — the same assembler the export runs,
    /// so the screen's list cannot drift from the artifact.
    @MainActor
    func previewDonation(now: Date = Date()) -> DonationPayload? {
        guard let container = donationModelContainer, let grant = donationGrant else { return nil }
        return DonationExport.preview(context: container.mainContext, grant: grant, now: now)
    }

    // MARK: - Persistence

    private func persistDonation(_ record: DonationRecord) -> Bool {
        guard let store = try? DonationConsentStore(userScope: LocalUserScope.current()) else { return false }
        // Never write over a record this key cannot open: it is the only
        // evidence of what a donor agreed to and what has already left. The
        // screen says so instead (the vault's `unreadableIndex` reasoning).
        do { _ = try store.load() } catch {
            donationConsentUnreadable = true
            return false
        }
        do {
            try store.save(record)
            donationRecordStorage = record
            donationConsentUnreadable = false
            mergeDonationIntoWallet()
            return true
        } catch {
            return false
        }
    }
}
