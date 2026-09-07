// SundhedImport.swift — "Connect Sundhed.dk" · PATH B (file/PDF upload).
//
// The citizen picks a Sundhed.dk PDF (or text export), Maude parses it ON-DEVICE
// into codes + derived numbers, shows a review sheet, and — on Approve — POSTs the
// derived summary to the EXISTING backend endpoint POST /ingest/sundhed.
//
// CARDINAL (rule 3): file bytes and extracted text are transient locals here; they
// are parsed and discarded. Only the derived, coded SundhedIngestBody is uploaded.
//
// Reuse: mirrors DocumentPickerView (JournalView) but ACTUALLY reads the bytes,
// and mirrors the MaudeBackendService networking style (Bearer from the Keychain
// SessionTokenStore, friendly error mapping). See INTEGRATION.md for the preferred
// production wiring (route through MaudeBackendService to reuse token refresh).
import SwiftUI
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif

// MARK: - Feature flag (rule 5: new flags default OFF in Release)

/// Gates the Sundhed.dk import UI. DEBUG-on for development; Release-OFF until the
/// POST /ingest/sundhed route parity is verified on api.maude.app. This path is
/// NOT simulated/insecure (it reads real files, uploads real derived codes to the
/// prod backend), so it needs no ReleasePosture precondition — but it stays dark
/// in shipped builds until deliberately flipped. Local QA: `MAUDE_SUNDHED_IMPORT=1`.
public enum SundhedFeature {
    /// Single source of truth for the Path B import gate — follows Config so the
    /// DataSourcesView row and the import view agree in every configuration.
    public static var importEnabled: Bool { Config.sundhedConnectEnabled }
}

// MARK: - Ingest client

// The `SundhedIngesting` seam is defined once in SundhedPayload.swift; both Path A
// and Path B call it. This file provides the concrete conformer.

public enum SundhedIngestError: Error, LocalizedError {
    case notAvailable       // not on the sovereign backend (mock/sandbox)
    case notSignedIn
    case offline
    case timedOut
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable: return String(localized: "Importing Sundhed.dk data needs the live Maude backend.")
        case .notSignedIn:  return String(localized: "Please sign in again, then retry the import.")
        case .offline:      return String(localized: "You appear to be offline. Check your connection and try again.")
        case .timedOut:     return String(localized: "The server is taking too long to respond. Try again in a moment.")
        case .server(let m): return m
        }
    }
}

/// Self-contained ingest client. Resolves the sovereign base URL + Bearer the same
/// way MaudeBackendService does (Keychain access token, falling back to the local
/// dev seed token), and maps transport errors to the same friendly copy.
public final class MaudeSundhedIngestClient: SundhedIngesting, @unchecked Sendable {

    private let session: URLSession

    public static let defaultSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        return URLSession(configuration: c)
    }()

    public init(session: URLSession = MaudeSundhedIngestClient.defaultSession) {
        self.session = session
    }

    public func ingestSundhed(_ body: SundhedIngestBody) async throws {
        guard let (baseURL, bearer) = Self.endpoint() else {
            // Distinguish "wrong backend" from "no token" for accurate copy.
            if case .sovereign = Config.backend { throw SundhedIngestError.notSignedIn }
            throw SundhedIngestError.notAvailable
        }
        guard let url = URL(string: "/ingest/sundhed", relativeTo: baseURL) else {
            throw SundhedIngestError.server(String(localized: "Couldn't reach the import endpoint."))
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let e as URLError where e.code == .notConnectedToInternet
                                     || e.code == .networkConnectionLost
                                     || e.code == .dataNotAllowed {
            throw SundhedIngestError.offline
        } catch let e as URLError where e.code == .timedOut {
            throw SundhedIngestError.timedOut
        } catch {
            throw SundhedIngestError.server(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SundhedIngestError.server(String(localized: "No HTTP response"))
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw SundhedIngestError.notSignedIn
        case 500...599:
            throw SundhedIngestError.server(String(localized: "Maude's servers are having trouble right now. Please try again in a few minutes."))
        default:
            let o = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let msg = (o["message"] as? String) ?? (o["error"] as? String) ?? (o["msg"] as? String)
            throw SundhedIngestError.server(msg ?? String(localized: "That didn't go through (error \(http.statusCode)). Try again."))
        }
    }

    /// (baseURL, bearer) when the sovereign backend is active and a token exists.
    static func endpoint() -> (URL, String)? {
        guard case .sovereign(let baseURL, let devToken, _) = Config.backend else { return nil }
        let bearer = SessionTokenStore().load() ?? devToken
        guard let bearer, !bearer.isEmpty else { return nil }
        return (baseURL, bearer)
    }
}

// MARK: - File picker (reads BYTES — fixes the filename-only import gap)

#if os(iOS)
/// One picked file, already read into memory (with security-scoped access) so the
/// SwiftUI layer never has to juggle bookmark scope. Bytes are transient.
public struct SundhedPickedFile: Equatable {
    public let name: String
    public let data: Data
}

/// Multi-select picker for Sundhed.dk exports ([.pdf, .plainText]). Unlike the
/// legacy DocumentPickerView (which read only the filename), this reads the file
/// contents so the on-device parser has something to work with.
public struct SundhedFilePicker: UIViewControllerRepresentable {
    public let onPick: ([SundhedPickedFile]) -> Void
    public init(onPick: @escaping ([SundhedPickedFile]) -> Void) { self.onPick = onPick }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .plainText])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([SundhedPickedFile]) -> Void
        init(onPick: @escaping ([SundhedPickedFile]) -> Void) { self.onPick = onPick }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var files: [SundhedPickedFile] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    files.append(SundhedPickedFile(name: url.lastPathComponent, data: data))
                }
            }
            onPick(files)
        }
    }
}
#endif

// MARK: - Import view

public struct SundhedImportView: View {
    @Environment(AppState.self) private var appState

    private enum Stage: Equatable {
        case idle, parsing, review, saving, done
    }

    @State private var stage: Stage = .idle
    @State private var summary: SundhedDerivedSummary?
    @State private var errorMessage: String?
    @State private var showPicker = false

    // Full-fidelity parse results kept for the upload (the display `summary` is a
    // lossy projection). Transient in-memory only — never persisted.
    @State private var parsedLabs: [SundhedLabMeasurement] = []
    @State private var parsedMeds: [SundhedMedItem] = []
    @State private var parsedDiagnoses: [String] = []

    /// Prefer the app service if it adopts the seam (INTEGRATION.md), else the
    /// self-contained client.
    private var ingestClient: SundhedIngesting {
        (appState.supabase as? SundhedIngesting) ?? MaudeSundhedIngestClient()
    }

    /// Pseudonymous citizen id echoed in the body (backend still authorises via
    /// the Bearer). Alias keeps real names out of calls, matching the app pattern.
    private var citizenID: String {
        appState.profile?.alias ?? appState.session?.userId.uuidString ?? ""
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !SundhedFeature.importEnabled {
                    unavailableCard
                } else {
                    switch stage {
                    case .idle, .parsing:
                        howToCard
                        pickCard
                        onDeviceRow   // canvas B1: standing chip + plain promise
                    case .review, .saving: reviewCard
                    case .done: doneCard
                    }
                }
                if let errorMessage {
                    errorBanner(errorMessage)
                }
                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(MaudeTheme.paper)
        .navigationTitle("Connect Sundhed.dk")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            SundhedFilePicker { files in
                Task { await parse(files) }
            }
        }
        #endif
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BRING YOUR SUNDHED.DK DATA")
                .font(.maudeKicker(10)).tracking(1.2)
                .foregroundStyle(MaudeTheme.ink3)
            Text("Export your labs, medication and diagnoses from Sundhed.dk as a PDF (or text), then import the file here. Maude reads it on this device and only shares the coded summary.")
                .font(.lato(13)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// In-app step-by-step: how to export from sundhed.dk and bring it in.
    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("HOW TO EXPORT")
                .font(.maudeKicker(10)).tracking(1.2)
                .foregroundStyle(MaudeTheme.ink3)
            stepRow(1, "In **Safari or Chrome**, sign in to **sundhed.dk** with MitID.")
            stepRow(2, "Open **Min Side → Sundhedsjournalen**. For each of **Laboratoriesvar**, **Medicinkortet** and **Diagnoser**: tap **Share → Print**, pinch the preview outward, then **Save to Files**.")
            stepRow(3, "Come back here, tap **Choose PDF or text file**, review what Maude found, and tap **Approve**.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.lato(12, .bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(MaudeTheme.moss).clipShape(Circle())
            Text(LocalizedStringKey(text))
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pickCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                errorMessage = nil
                showPicker = true
            } label: {
                HStack(spacing: 8) {
                    if stage == .parsing { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.up.doc.fill").font(.system(size: 14)) }
                    Text(stage == .parsing ? "Reading file…" : "Choose PDF or text file")
                        .font(.lato(14, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(MaudeTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(stage == .parsing)

            Text("Labs, medication (ATC) and diagnoses (ICD-10) are parsed automatically. Free-text hospital notes aren't read yet.")
                .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    @ViewBuilder
    private var reviewCard: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: 14) {
                Text("REVIEW BEFORE SAVING")
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)

                if s.isEmpty {
                    Text("No lab values, medication or diagnoses were recognised in that file. Try a different Sundhed.dk export.")
                        .font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                } else {
                    if !s.labs.isEmpty { labsSection(s.labs) }
                    if !s.meds.isEmpty { medsSection(s.meds) }
                    if !s.unmappedMeds.isEmpty { unmappedNote(s.unmappedMeds) }
                    if !s.conditions.isEmpty { conditionsSection(s.conditions) }
                    scopeNote(s.requiredScope)
                }

                HStack(spacing: 10) {
                    Button {
                        resetParse()
                    } label: {
                        Text("Cancel").font(.lato(14, .bold))
                            .foregroundStyle(MaudeTheme.ink2)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(MaudeTheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await save(s) }
                    } label: {
                        HStack(spacing: 8) {
                            if stage == .saving { ProgressView().tint(.white) }
                            Text(stage == .saving ? "Saving…" : "Approve & save")
                                .font(.lato(14, .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(s.isEmpty ? MaudeTheme.ink4 : MaudeTheme.moss)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(s.isEmpty || stage == .saving)
                }
            }
            .padding(14)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
        }
    }

    private func labsSection(_ rows: [SundhedDerivedSummary.LabRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lab results (\(rows.count))").font(.lato(13, .bold)).foregroundStyle(MaudeTheme.ink)
            ForEach(rows) { r in
                HStack {
                    Text(LabNomenclature.displayName(forRawAnalyte: r.component))
                        .font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                    Spacer()
                    // Qualitative screens show their WORDS ("Not detected") —
                    // never a numeric 0 + unit (defect B).
                    if let newest = r.readings.first, newest.kind == .qualitative {
                        Text(SundhedParsers.qualitativeDisplayWord(newest.text ?? ""))
                            .font(.lato(13, .bold)).foregroundStyle(MaudeTheme.ink)
                    } else {
                        Text("\(fmt(r.latest)) \(r.unit)")
                            .font(.lato(13, .bold)).foregroundStyle(MaudeTheme.ink)
                    }
                    Text("· n=\(r.n)").font(.lato(11)).foregroundStyle(MaudeTheme.ink4)
                }
            }
        }
    }

    private func medsSection(_ rows: [SundhedDerivedSummary.MedRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Medication (\(rows.count))").font(.lato(13, .bold)).foregroundStyle(MaudeTheme.ink)
            ForEach(rows) { r in
                HStack {
                    Text(r.brand).font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                    Spacer()
                    Text(r.atc).font(.lato(12, .bold)).foregroundStyle(MaudeTheme.moss)
                }
            }
        }
    }

    private func unmappedNote(_ substances: [String]) -> some View {
        Text("Not yet coded (skipped): \(substances.joined(separator: ", "))")
            .font(.lato(11)).foregroundStyle(MaudeTheme.ink4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func conditionsSection(_ rows: [SundhedDerivedSummary.ConditionRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Diagnoses (\(rows.count))").font(.lato(13, .bold)).foregroundStyle(MaudeTheme.ink)
            HStack {
                ForEach(rows) { r in
                    Text(r.code)
                        .font(.lato(12, .bold)).foregroundStyle(MaudeTheme.ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(MaudeTheme.clay2)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func scopeNote(_ scope: [String]) -> some View {
        Text("Saving will file this under your consent scope: \(scope.joined(separator: ", ")). Diagnoses need a grant that includes “conditions”.")
            .font(.lato(11)).foregroundStyle(MaudeTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var doneCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44)).foregroundStyle(MaudeTheme.moss)
            Text("Saved").font(.maudeH2).foregroundStyle(MaudeTheme.ink)
            Text("Saved to your device — nothing was uploaded. Your Sundhed.dk labs, medicine and diagnoses are now in your Maude health record, and the file stayed on this phone.")
                .font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                resetParse()
            } label: {
                Text("Import another file").font(.lato(14, .bold))
                    .foregroundStyle(MaudeTheme.moss)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    /// Canvas B1 delta: the standing on-device chip (tappable proof surface)
    /// beside the plain one-line promise.
    private var onDeviceRow: some View {
        HStack(spacing: 8) {
            OnDeviceChip()
            Text("The file is read on this device.")
                .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    private var unavailableCard: some View {
        Text("Sundhed.dk import isn't available in this build yet.")
            .font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13)).foregroundStyle(MaudeTheme.clay)
            Text(message).font(.lato(12.5)).foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(MaudeTheme.clay2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Stage-aware privacy footer. The review/saving stages carry the canvas B2
    /// line — the stronger on-device promise, and the accurate one now that the
    /// automatic upload is removed: approving SAVES to this device, full stop.
    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield").font(.system(size: 14)).foregroundStyle(MaudeTheme.moss)
            Text(stage == .review || stage == .saving
                 ? "Only this coded summary is saved. The file itself, and anything Maude couldn't recognise, is discarded."
                 : "Your file is read on this device. Raw notes and document text never leave your phone — only coded results (catalog variables, ATC and ICD-10 codes) and derived numbers are kept.")
                .font(.caption).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Actions

    /// Parse every picked file on-device. Text is a transient local — parsed and
    /// dropped; never stored or uploaded (rule 3).
    @MainActor
    private func parse(_ files: [SundhedPickedFile]) async {
        guard !files.isEmpty else { return }
        stage = .parsing
        errorMessage = nil

        var labs: [SundhedLabMeasurement] = []
        var meds: [SundhedMedItem] = []
        var diagnoses: [String] = []
        var failures = 0

        for file in files {
            do {
                let text = try SundhedPDFText.text(fromData: file.data, filename: file.name)
                labs += SundhedParsers.parseLabs(text)
                meds += SundhedParsers.parseMeds(text)
                // Structured "Aktuelle diagnoser" (ICD 10: …) AND the explicit
                // ICD-10/SKS codes harvested from a "Journal fra sygehus" export —
                // so a journal.pdf contributes conditions and a labs.pdf its labs.
                // De-duplicated together below (presence semantics).
                diagnoses += SundhedParsers.parseDiagnoses(text)
                diagnoses += SundhedParsers.parseJournal(text)
                // `text` goes out of scope here — nothing retains it.
            } catch {
                failures += 1
            }
        }

        // De-duplicate diagnoses across files (presence semantics).
        diagnoses = Array(NSOrderedSet(array: diagnoses)) as? [String] ?? diagnoses

        parsedLabs = labs
        parsedMeds = meds
        parsedDiagnoses = diagnoses
        summary = SundhedPayloadBuilder.summarise(labs: labs, meds: meds, diagnoses: diagnoses)
        if failures == files.count {
            errorMessage = String(localized: "None of the selected files could be read. Export a PDF or text file from Sundhed.dk and try again.")
        } else if failures > 0 {
            errorMessage = String(localized: "\(failures) file(s) couldn't be read and were skipped.")
        }
        stage = .review
    }

    /// Save the parsed record to the on-device canonical store. NOTHING is uploaded:
    /// the automatic ensureCoveringGrant + POST /ingest/sundhed calls were removed
    /// (both functions stay in this file for the EXPLICIT share/research path).
    @MainActor
    private func save(_ s: SundhedDerivedSummary) async {
        guard !s.isEmpty else { return }
        stage = .saving
        errorMessage = nil

        // Source-agnostic ingest: same single API every source uses. The full-fidelity
        // parse (parsedLabs/Meds/Diagnoses) is what the review summary reflects, so the
        // summary carries the same rows; store it tagged as the PDF source.
        appState.ingestHealthRecord(s, source: .sundhedPdf)
        // Also surface into the self-declared HealthContext (local display) as before.
        mergeForDisplay()
        stage = .done
    }

    /// Ensure an active consent grant covers the Sundhed metric groups (labs / meds /
    /// conditions) so the ingest can land. Created ONCE per citizen (a `UserDefaults`
    /// marker keeps re-imports from piling up grants); re-runs land under it and the
    /// backend supersedes the prior share. Best-effort — never blocks the ingest.
    private func ensureCoveringGrant() async {
        guard let sov = appState.sovereign, !citizenID.isEmpty else { return }
        let marker = "sundhed.coveringGrant.\(citizenID)"
        if UserDefaults.standard.bool(forKey: marker) { return }
        guard let recipients = try? await sov.fetchRecipients(),
              let recipient = recipients.first(where: { $0.role == .clinicalNurse }) ?? recipients.first
        else { return }
        do {
            _ = try await sov.createGrant(
                recipientId: recipient.id,
                role: .clinicalNurse,
                scopeGroups: ["labs", "meds", "conditions"],   // cover all Sundhed groups once
                purpose: "Import from Sundhed.dk",
                granularity: nil,
                expiry: Calendar.current.date(byAdding: .day, value: 365, to: Date()),
                delivery: "snapshot"
            )
            UserDefaults.standard.set(true, forKey: marker)
        } catch {
            // Leave the marker unset so a later import retries; the ingest below still
            // runs and surfaces any "no covering grant" message verbatim.
        }
    }

    /// Surface the parsed Sundhed.dk data into the app so HealthPassportView
    /// renders it. LOCAL, on-device DISPLAY mapping only — it does NOT change the
    /// codes-only ingest wire body, so brand/form names are fine here. Merges into
    /// the citizen's existing self-declared HealthContext by NAME: appends only
    /// entries not already present, never wiping the user's own self-declared data.
    @MainActor
    private func mergeForDisplay() {
        // Complete any pending profile restore FIRST (locked-background-launch
        // case, 10.103) so the merge lands on the stored profile, not a seed.
        appState.retryHealthContextRestoreIfNeeded()
        // Medications — display brand (falling back to active substance) + the
        // strength/form as the "dose" line; tag the frequency as the source.
        var existingMedNames = Set(appState.healthContext.medications.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        })
        for m in parsedMeds {
            let name = (m.brand.isEmpty ? m.activeSubstance : m.brand)
                .trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            guard !existingMedNames.contains(key) else { continue }
            existingMedNames.insert(key)
            let dose = (m.form ?? m.dosage ?? "").trimmingCharacters(in: .whitespaces)
            appState.healthContext.medications.append(
                MedicationEntry(name: name, dose: dose, frequency: "Sundhed.dk")
            )
        }
        // Conditions — one entry per coded ICD-10 diagnosis (codes only).
        var existingCondNames = Set(appState.healthContext.conditions.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        })
        for code in parsedDiagnoses {
            let name = code.trimmingCharacters(in: .whitespaces).uppercased()
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            guard !existingCondNames.contains(key) else { continue }
            existingCondNames.insert(key)
            appState.healthContext.conditions.append(
                ConditionEntry(name: name, diagnosedYear: nil, notes: "Sundhed.dk (ICD-10)")
            )
        }
        // Persist the merged profile — the appends above were memory-only, so
        // imported meds/conditions silently vanished on relaunch (the same
        // class as the original "edits died on relaunch" defect).
        appState.saveHealthContext(appState.healthContext)
        // TODO: surface imported labs (parsedLabs) via the passport-stats (derived)
        // layer — labs are derived metrics, not self-declared HealthContext.
    }

    /// Return to idle and drop all transient parse buffers from memory.
    @MainActor
    private func resetParse() {
        stage = .idle
        summary = nil
        errorMessage = nil
        parsedLabs = []
        parsedMeds = []
        parsedDiagnoses = []
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
