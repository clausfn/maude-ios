// DonationExport.swift — FR-DON-05 · assemble → seal → hand to the donor.
//
// THIS FILE PERFORMS NO NETWORK CALL, AND NEITHER DOES ANY OTHER FILE UNDER
// `Liviqa/Donation/`. There is no URLSession, no URLRequest, no upload task, no
// endpoint constant, no ingest client — `DonationEgressTests` reads the source
// of this whole directory and fails the test run if any transport construct
// appears, in the same shape as `T-SUND-01`'s source lint. That is what keeps
// the shipped binary free of raw-egress capability while a donor build can
// still produce a donation: the file is written locally, sealed, and handed to
// the iOS share sheet. THE DONOR performs the transfer, from their own device,
// to a one-time upload URL the programme gives them. The app never learns where
// the corpus lives.
//
// Order of operations (deliberate):
//   1. refuse early — no donor build, no active grant, no programme key, demo
//      data, or nothing in the window ⇒ nothing is read and nothing is written;
//   2. read the consented streams for the consented window from the on-device
//      store;
//   3. assemble in memory (real-provenance rows only, sources classified, dates
//      shifted, excluded categories structurally absent);
//   4. seal in memory to the programme public key;
//   5. write ONLY the sealed bytes, atomically, file-protection complete.
//
// Step 5 is the only write, and the plaintext JSON exists solely as a `Data`
// value between steps 3 and 4.
import Foundation
import SwiftData

@MainActor
enum DonationExport {

    // MARK: - Refusals

    /// Every reason the export can decline, each with copy the donor screen
    /// shows verbatim. A refusal is never silent and never a generic error.
    enum Refusal: Error, Equatable {
        case notADonorBuild
        case noActiveGrant
        case noProgrammeKey
        case demoData
        case nothingInWindow
        case storeUnavailable
        case sealFailed
        case writeFailed

        var message: String {
            switch self {
            case .notADonorBuild:
                return String(localized: "This build has no donation flow. Donation is only possible in a build made for the donor programme.")
            case .noActiveGrant:
                return String(localized: "No active donation agreement is recorded on this phone. Record the reference from your signed form first — and if you have withdrawn, nothing more can be exported.")
            case .noProgrammeKey:
                return String(localized: "The programme's encryption key has not been set in this build, so a donation could be sealed to nobody. Nothing was read from your phone.")
            case .demoData:
                return String(localized: "This phone is showing demo data, not your own readings. There is nothing real to donate, and invented readings must never enter the collection.")
            case .nothingInWindow:
                return String(localized: "There are no readings of your own in the agreed period, so there is nothing to put in a file.")
            case .storeUnavailable:
                return String(localized: "Your on-device store could not be opened, so nothing was read.")
            case .sealFailed:
                return String(localized: "The file could not be encrypted, so nothing was written.")
            case .writeFailed:
                return String(localized: "The encrypted file could not be written to this phone.")
            }
        }
    }

    // MARK: - Preflight (pure)

    /// The refusal that applies, or nil when an export may proceed. Pure, so the
    /// gate can be proven without a device, a key or a store.
    static func refusal(isDonorBuild: Bool,
                        grant: WalletGrant?,
                        hasProgrammeKey: Bool,
                        isDemoData: Bool,
                        rowCount: Int,
                        now: Date = Date()) -> Refusal? {
        guard isDonorBuild else { return .notADonorBuild }
        guard let grant,
              grant.recipientType == .controllerInternal,
              grant.isActive,
              (grant.expiresAt ?? .distantFuture) > now,
              !grant.scopeKeys.isEmpty
        else { return .noActiveGrant }
        guard hasProgrammeKey else { return .noProgrammeKey }
        guard !isDemoData else { return .demoData }
        guard rowCount > 0 else { return .nothingInWindow }
        return nil
    }

    // MARK: - Window

    /// The consented retrospective window (§3.2): the last 90 days, ending now.
    static func window(now: Date = Date(), days: Int = DonationProgramme.windowDays) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(-Double(days) * 86_400), end: now)
    }

    // MARK: - Read the consented streams

    /// Fetch exactly the four donatable streams for the window. Nothing else in
    /// the store is even queried: labs, diagnoses, medication, journal entries,
    /// documents, blood pressure, AFib, insulin and body composition are never
    /// read by this path.
    static func gather(context: ModelContext,
                       window: DateInterval,
                       scopes: Set<String>) -> DonationAssembler.Inputs {
        let lo = window.start, hi = window.end
        var inputs = DonationAssembler.Inputs()

        if scopes.contains(DonationAssembler.Scope.glucose.rawValue) {
            inputs.glucose = (try? context.fetch(FetchDescriptor<GlucoseSample>(
                predicate: #Predicate { $0.ts >= lo && $0.ts <= hi }))) ?? []
        }
        if scopes.contains(DonationAssembler.Scope.heartDaily.rawValue) {
            inputs.heart = (try? context.fetch(FetchDescriptor<HeartDaily>(
                predicate: #Predicate { $0.date >= lo && $0.date <= hi }))) ?? []
        }
        if scopes.contains(DonationAssembler.Scope.sleep.rawValue) {
            inputs.sleep = (try? context.fetch(FetchDescriptor<SleepSegment>(
                predicate: #Predicate { $0.date >= lo && $0.date <= hi }))) ?? []
        }
        if scopes.contains(DonationAssembler.Scope.workouts.rawValue) {
            inputs.workouts = (try? context.fetch(FetchDescriptor<Workout>(
                predicate: #Predicate { $0.start >= lo && $0.start <= hi }))) ?? []
        }
        return inputs
    }

    /// Build the payload the donor is shown BEFORE anything is sealed, so the
    /// screen can state precisely what would be in the file. Same function the
    /// export uses — the preview cannot drift from the artifact.
    static func preview(context: ModelContext,
                        grant: WalletGrant,
                        now: Date = Date()) -> DonationPayload {
        let window = self.window(now: now)
        let scopes = Set(grant.scopeKeys)
        let inputs = gather(context: context, window: window, scopes: scopes)
        return DonationAssembler.build(inputs: inputs,
                                       grantReference: reference(for: grant),
                                       scopes: scopes,
                                       window: window,
                                       appVersion: appVersion,
                                       appBuild: appBuild,
                                       sealedAt: now)
    }

    // MARK: - Export

    struct Result: Equatable {
        let url: URL
        let record: DonationExportRecord
    }

    /// Assemble, seal and write. Returns the sealed file's URL for the share
    /// sheet plus the ledger row the caller must persist.
    static func run(context: ModelContext,
                    grant: WalletGrant,
                    isDemoData: Bool,
                    now: Date = Date(),
                    stagingDirectory: URL? = nil) throws -> Result {

        let window = self.window(now: now)
        let scopes = Set(grant.scopeKeys)
        let key = DonationProgramme.programmePublicKey()

        // Refuse on everything that does not depend on reading the store first.
        if let early = refusal(isDonorBuild: DonationProgramme.isDonorBuild,
                               grant: grant,
                               hasProgrammeKey: key != nil,
                               isDemoData: isDemoData,
                               rowCount: 1,          // not yet known; checked below
                               now: now) {
            throw early
        }
        guard let key else { throw Refusal.noProgrammeKey }

        let payload = DonationAssembler.build(
            inputs: gather(context: context, window: window, scopes: scopes),
            grantReference: reference(for: grant),
            scopes: scopes,
            window: window,
            appVersion: appVersion,
            appBuild: appBuild,
            sealedAt: now)

        guard payload.rowCount > 0 else { throw Refusal.nothingInWindow }

        // Plaintext lives here and nowhere else — a `Data` value, never a file.
        let plaintext: Data
        do { plaintext = try DonationAssembler.encode(payload) } catch { throw Refusal.sealFailed }

        let sealed: Data
        do { sealed = try DonationSealer.seal(plaintext, to: key) } catch { throw Refusal.sealFailed }

        let dir = stagingDirectory ?? defaultStagingDirectory()
        purgeStaged(directory: dir)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch { throw Refusal.writeFailed }

        let name = fileName(grantReference: reference(for: grant), sealedAt: now)
        let url = dir.appendingPathComponent(name)
        do {
            try sealed.write(to: url, options: [.atomic, .completeFileProtection])
        } catch { throw Refusal.writeFailed }

        let record = DonationExportRecord(
            id: UUID(), occurredAt: now,
            grantReference: reference(for: grant),
            windowStart: window.start, windowEnd: window.end,
            dateShiftDays: payload.manifest.dateShiftDays,
            counts: payload.countsByStream,
            fileName: name,
            byteCount: sealed.count,
            sealedDigest: DonationSealer.digest(sealed))

        return Result(url: url, record: record)
    }

    // MARK: - Staging area

    /// Sealed files are staged in the app's own temporary area, never in a
    /// shared container. They are already sealed, so a file left behind is not a
    /// plaintext exposure — but a previous donation is purged on every export
    /// and can be removed on demand from the donor screen.
    static func defaultStagingDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("liviqa-donations", isDirectory: true)
    }

    @discardableResult
    static func purgeStaged(directory: URL? = nil) -> Int {
        let dir = directory ?? defaultStagingDirectory()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir,
                                                                  includingPropertiesForKeys: nil)) ?? []
        var removed = 0
        for file in files where file.pathExtension == DonationProgramme.fileExtension {
            if (try? FileManager.default.removeItem(at: file)) != nil { removed += 1 }
        }
        return removed
    }

    // MARK: - Naming

    /// `liviqa-donation-<grant reference>-<yyyyMMdd>.lvdn`. The reference is the
    /// donor code: pseudonymous, resolvable only through the donor register.
    static func fileName(grantReference: String, sealedAt: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyyMMdd"
        return "liviqa-donation-\(safe(grantReference))-\(fmt.string(from: sealedAt)).\(DonationProgramme.fileExtension)"
    }

    private static func safe(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = s.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(cleaned).isEmpty ? "unreferenced" : String(cleaned)
    }

    /// The grant reference from the signed form, carried on the grant's consent
    /// chain reference. Falls back to the grant id so a file is never unlabelled.
    static func reference(for grant: WalletGrant) -> String {
        let ref = (grant.ceGrantRef ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ref.isEmpty ? grant.id.uuidString : ref
    }

    // MARK: - Build identity (recorded in the manifest)

    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown"
    }
    static var appBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "unknown"
    }
}
