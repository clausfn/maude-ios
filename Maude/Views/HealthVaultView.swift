// HealthVaultView.swift — "Health data space" (FR-ING-12/13, realised by
// FR-ING-15) + the Open Banking & Screen Time connect sheets.
// v02 · 2026-08-12 · A7.2 Area ⑦: rebuilt to the ScrVault canvas
// (b-integrations.jsx) over a REAL encrypted document store.
//
// v03 · 2026-08-13 · robustness: four named states, two honest failure classes.
//
// THE SPACE: the citizen's own document store — labs, clinical letters, scans,
// photos. Every document is AES-256-GCM encrypted the moment it's added, with
// the data key wrapped to this device's Secure Enclave (HealthVaultStore /
// KeyVault). Add via Files or Photos; preview + delete inside. The old demo
// folder seed (VaultSeed) and the "previews locked until the live production
// test" alert are retired — storage is real now, so the claims can be too.
//
// FAILURE COPY IS A SAFETY SURFACE. `VaultAccess` gives this screen four states
// and each gets its own sentence:
//   • .ready                    — the list (or the empty invitation), add enabled
//   • .lockedUntilDeviceUnlock  — a WAIT: the phone hasn't been unlocked yet
//   • .keyUnavailable           — no key could be prepared; retryable
//   • .sealedDataUnreadable     — the ONLY place the "unreadable" sentence may
//                                 appear, and nothing is deleted or re-keyed
// Telling a citizen their health documents are unreadable when the truth is
// "wait a moment" invites a reinstall, which would actually destroy them.
// The encryption sentence follows `KeyVault.protection` exactly: the Secure
// Enclave is named only when the enclave really holds the key, and before any
// key exists no key claim is made at all.
//
// CONSENT RAIL: nothing in this space enters any share by default. Financial
// papers NEVER enter a clinician share — they live here, on this device, full
// stop. There is no upload path in this file and none may be added.
//
// OPEN BANKING: no bank brand on the source row; the citizen picks their bank
// from the PSD2 list. Before any connect, two things in plain language: WHY
// money patterns can explain health patterns, and the confidentiality promise.
import SwiftUI
import PhotosUI
#if os(iOS)
import PDFKit
import UniformTypeIdentifiers
#endif

// MARK: - Health data space (the vault, rebuilt on the encrypted store)

struct HealthVaultView: View {
    @State private var store: HealthVaultStore?
    @State private var docs: [VaultDocumentMeta] = []
    /// nil while the first open is still in flight; then always one of the four
    /// named states (see `VaultAccess`) — never a free-text error.
    @State private var access: VaultAccess?
    @State private var note: String?

    @State private var showAddDialog = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var selected: VaultDocumentMeta?
    @State private var showLabImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                verdictBand
                explainerCard
                switch access {
                case .sealedDataUnreadable?:
                    unreadableCard
                case .lockedUntilDeviceUnlock?:
                    retryCard(String(localized: "This space opens once you've unlocked this phone. Nothing is lost — anything you've saved is still here, just out of reach until then."))
                case .keyUnavailable?:
                    retryCard(String(localized: "The encrypted space couldn't be prepared on this device just now. Nothing has been lost, and nothing was stored unencrypted."))
                default:
                    if docs.isEmpty { emptyCard } else { documentList }
                }
                addAffordance
                readLabReportRow
                if let note { noteRow(note) }
                consentStrip
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(MaudeTheme.paper)
        .navigationTitle("Health data space")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { openStore() }
        .confirmationDialog("Add a document", isPresented: $showAddDialog, titleVisibility: .visible) {
            Button("Choose a file") { showFileImporter = true }
            Button("From your photos") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's encrypted the moment it's added, and stays on this phone.")
        }
        #if os(iOS)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.pdf, .image, .plainText, .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                importFile(at: url)
            }
        }
        #endif
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .sheet(item: $selected) { meta in
            VaultDocumentSheet(meta: meta, store: store) {
                selected = nil
                reload()
                note = String(localized: "Deleted from this phone.")
            }
        }
        .sheet(isPresented: $showLabImport) {
            NavigationStack {
                LabReportImportView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showLabImport = false; reload() }
                        }
                    }
            }
        }
    }

    // MARK: Store plumbing

    /// One attempt to open the space. Every outcome — including "no key could be
    /// prepared" and "the phone hasn't been unlocked yet" — lands in a named
    /// state; only genuinely unreadable documents get the unreadable message.
    private func openStore() {
        guard access == nil else { return }
        let session = HealthVaultSession.open(keyVault: .shared, userScope: LocalUserScope.current())
        store = session.store
        docs = session.documents
        access = session.access
    }

    /// Re-open from scratch — used by the retry affordance, and after a change.
    private func retry() {
        access = nil
        store = nil
        note = nil
        openStore()
    }

    private func reload() {
        guard let store else { return }
        do {
            docs = try store.documents()
            access = .ready
        } catch {
            docs = []
            access = KeyFailure.isDeviceLocked(error) ? .lockedUntilDeviceUnlock : .sealedDataUnreadable
        }
    }

    private func importFile(at url: URL) {
        guard let store else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            note = String(localized: "That file couldn't be read.")
            return
        }
        do {
            let meta = try store.add(name: url.lastPathComponent, data: data,
                                     source: String(localized: "Files"))
            reload()
            note = String(localized: "“\(meta.name)” encrypted and added — it stays on this phone.")
        } catch {
            note = String(localized: "The document couldn't be saved. Nothing was stored.")
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        guard let store else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run { note = String(localized: "That photo couldn't be read.") }
            return
        }
        let df = DateFormatter(); df.dateFormat = "d MMM yyyy HH.mm"
        let name = "Photo \(df.string(from: Date())).jpg"
        await MainActor.run {
            do {
                _ = try store.add(name: name, data: data, source: String(localized: "Photos"))
                reload()
                note = String(localized: "Photo encrypted and added — it stays on this phone.")
            } catch {
                note = String(localized: "The photo couldn't be saved. Nothing was stored.")
            }
            photoItem = nil
        }
    }

    // MARK: Sections (ScrVault anatomy)

    private var verdictBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MaudeTheme.accentSleep)
                Text(String(localized: "Encrypted on this device").uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
            }
            Text("Your documents, locked to this phone.")
                .font(.maudeSerif(22)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            RoundedRectangle(cornerRadius: 2)
                .fill(MaudeTheme.accentSleep)
                .frame(width: 44, height: 3)
        }
        .padding(.top, 4)
    }

    private var explainerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16))
                .foregroundStyle(MaudeTheme.accentSleep)
            Text(explainerText)
                .font(.lato(12.5)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
    }

    /// The canvas line, with the key-protection clause kept honest: name the
    /// Secure Enclave only when the key really is enclave-held, say "never
    /// leaves this device" when it is a software device key, and — before any
    /// key has been provisioned — make no key claim at all.
    private var explainerText: AttributedString {
        let opening = String(localized: "Lab results, letters, scans — stored with AES-256 encryption, readable only on your unlocked device.")
        let sentence: String
        switch KeyVault.shared.protection {
        case .secureEnclave:
            sentence = opening + " " + String(localized: "Nothing is uploaded, and the key is held by this device's Secure Enclave.")
        case .softwareDeviceKey:
            sentence = opening + " " + String(localized: "Nothing is uploaded, and the key never leaves this device.")
        case .notProvisioned:
            sentence = opening + " " + String(localized: "Nothing is uploaded.")
        }
        var s = AttributedString(sentence)
        if let r = s.range(of: "AES-256") {
            s[r].font = .lato(12.5, .bold)
        }
        return s
    }

    private var documentList: some View {
        VStack(spacing: 0) {
            ForEach(Array(docs.enumerated()), id: \.element.id) { idx, doc in
                if idx > 0 {
                    Divider().padding(.leading, 62).background(MaudeTheme.line2)
                }
                Button { selected = doc } label: { documentRow(doc) }
                    .buttonStyle(.plain)
            }
        }
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func documentRow(_ doc: VaultDocumentMeta) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(MaudeTheme.invertBG)
                    .frame(width: 38, height: 38)
                Image(systemName: doc.kind.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(MaudeTheme.invertFG)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(.lato(13.5, .semibold))
                    .foregroundStyle(MaudeTheme.ink)
                    .lineLimit(1)
                Text("\(Self.dayFormatter.string(from: doc.addedAt)) · \(Self.size(doc.byteSize))")
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink3)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "lock.fill").font(.system(size: 9))
                Text("Encrypted").font(.lato(10, .bold))
            }
            .foregroundStyle(MaudeTheme.moss)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing here yet")
                .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
            Text("Add your first document below — a lab letter, a scan, a photo of a paper result. It's encrypted the moment it's added.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private var addAffordance: some View {
        Button { showAddDialog = true } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MaudeTheme.moss2)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MaudeTheme.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Add a document")
                        .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text("Encrypted the moment it's added")
                        .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                }
                Spacer()
            }
            .padding(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(MaudeTheme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Enabled whenever adding is actually possible: a prepared key AND an
        // index this key can open (adding on top of an unreadable index would
        // overwrite the only record of the documents already on disk).
        .disabled(!canAdd)
        .opacity(canAdd ? 1 : 0.45)
    }

    private var canAdd: Bool {
        guard access?.canAddDocuments == true, let store else { return false }
        return store.canAddDocuments
    }

    /// Entry point to the any-lab importer (FR-REC-03). A document in this space
    /// is opaque bytes; this is the way to turn the RESULTS printed on it into
    /// coded rows in the health record — reviewed first, saved only on approval.
    private var readLabReportRow: some View {
        Button { showLabImport = true } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MaudeTheme.moss2)
                        .frame(width: 34, height: 34)
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MaudeTheme.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Read the results off a lab report")
                        .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text("Any lab · read here, reviewed by you before saving")
                        .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(MaudeTheme.ink4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var consentStrip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 13)).foregroundStyle(MaudeTheme.moss)
            Text("Documents stay out of every share by default. Money and insurance papers never enter a clinician share — they live here, on this phone, full stop.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// The genuinely unreadable case, and the only place this sentence may
    /// appear: documents ARE on this phone, sealed to key material this device
    /// no longer holds. Nothing is deleted and nothing is re-keyed — which is
    /// also why adding is refused here rather than quietly replacing the index.
    private var unreadableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            errorCard(String(localized: "The encrypted space couldn't be opened on this device. Your documents are unreadable without this device's key — nothing was lost, and nothing has been deleted or re-encrypted."))
            Text("This happens when the key that sealed them is gone from this phone — after a restore onto new hardware, for instance. The documents stay exactly as they are.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The recoverable classes: a wait or a retry, never a claim of lost data.
    private func retryCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            errorCard(message)
            Button { retry() } label: {
                Text("Try again")
                    .font(.lato(13, .bold))
                    .foregroundStyle(MaudeTheme.moss)
                    .padding(.vertical, 9).padding(.horizontal, 16)
                    .background(MaudeTheme.moss2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13)).foregroundStyle(MaudeTheme.clay)
            Text(message).font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.clay2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func noteRow(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12)).foregroundStyle(MaudeTheme.moss)
            Text(text).font(.lato(12)).foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Formatting

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "d MMM yyyy"; return df
    }()

    private static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - Document detail sheet (preview + metadata + delete)

private struct VaultDocumentSheet: View {
    let meta: VaultDocumentMeta
    let store: HealthVaultStore?
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var loadError = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    preview
                    metadataCard
                    deleteButton
                }
                .padding(20)
            }
            .background(MaudeTheme.paper)
            .navigationTitle(meta.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { load() }
            .confirmationDialog("Delete this document?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete from this phone", role: .destructive) {
                    try? store?.delete(meta.id)
                    dismiss()
                    onDelete()
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("It's removed from this phone immediately. This can't be undone.")
            }
        }
    }

    private func load() {
        guard data == nil, let store else { return }
        do { data = try store.open(meta.id); loadError = (data == nil) }
        catch { loadError = true }
    }

    @ViewBuilder
    private var preview: some View {
        if let data {
            switch meta.kind {
            #if os(iOS)
            case .pdf:
                VaultPDFView(data: data)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
            case .image:
                if let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else { noPreview }
            #endif
            case .text:
                Text(String(decoding: data, as: UTF8.self))
                    .font(.maudeMono(12)).foregroundStyle(MaudeTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            default:
                noPreview
            }
        } else if loadError {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13)).foregroundStyle(MaudeTheme.clay)
                Text("This document couldn't be decrypted. A failed integrity check is shown as an error — never as altered content.")
                    .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.clay2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        }
    }

    private var noPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: meta.kind.symbol)
                .font(.system(size: 34)).foregroundStyle(MaudeTheme.ink4)
            Text("No preview for this file type — the document itself is stored encrypted on this phone.")
                .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 20)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            metaRow(String(localized: "Added"), Self.dayFormatter.string(from: meta.addedAt))
            Divider().background(MaudeTheme.line2)
            metaRow(String(localized: "Came in from"), meta.source)
            Divider().background(MaudeTheme.line2)
            metaRow(String(localized: "Size"),
                    ByteCountFormatter.string(fromByteCount: Int64(meta.byteSize), countStyle: .file))
            Divider().background(MaudeTheme.line2)
            metaRow(String(localized: "Protection"), Self.protectionLine)
        }
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
            Spacer()
            Text(value).font(.lato(12.5, .semibold)).foregroundStyle(MaudeTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var deleteButton: some View {
        Button { confirmDelete = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash").font(.system(size: 13))
                Text("Delete this document").font(.lato(14, .bold))
            }
            .foregroundStyle(MaudeTheme.rust)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(MaudeTheme.rust2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Follows the live key path exactly — the enclave is named only when the
    /// enclave really holds the key. This document is open, so a key exists.
    private static var protectionLine: String {
        switch KeyVault.shared.protection {
        case .secureEnclave:     return String(localized: "AES-256 · key held by the Secure Enclave")
        case .softwareDeviceKey: return String(localized: "AES-256 · key held by this device")
        case .notProvisioned:    return String(localized: "AES-256 · on this device")
        }
    }

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short; return df
    }()
}

#if os(iOS)
/// Minimal PDFKit wrapper for the encrypted-document preview. Display only.
private struct VaultPDFView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = PDFDocument(data: data)
        v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#endif

// MARK: - Open Banking connect sheet

struct OpenBankingSheet: View {
    var onConnect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let banks = ["Danske Bank", "Nordea", "Jyske Bank", "Sydbank", "Nykredit",
                         "Arbejdernes Landsbank", "Lunar", "Revolut", "N26", "Wise"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Money and health move together. Stress often shows in spending before it shows in symptoms — late-evening purchases track short sleep; quiet grocery weeks track low-energy weeks. Maude reads daily totals and category patterns only — never single transactions, never merchant names.")
                        .font(.lato(13.5)).lineSpacing(3)
                        .foregroundStyle(MaudeTheme.ink2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(MaudeTheme.clay)
                            Text("More private than health data — treated that way")
                                .font(.lato(13, .bold))
                                .foregroundStyle(MaudeTheme.ink)
                        }
                        Text("Your financial patterns stay in your health data space on this phone, beside your other documents. Encrypted, never part of any clinician share, never sent anywhere. Disconnect and erase them in one tap, any time.")
                            .font(.lato(12.5)).lineSpacing(2.5)
                            .foregroundStyle(MaudeTheme.ink2)
                    }
                    .padding(12)
                    .background(MaudeTheme.clay2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("CHOOSE YOUR BANK")
                        .font(.maudeKicker(10)).tracking(1.2)
                        .foregroundStyle(MaudeTheme.ink3)

                    VStack(spacing: 0) {
                        ForEach(banks, id: \.self) { bank in
                            if bank != banks.first { Divider().padding(.leading, 14) }
                            Button { onConnect(bank); dismiss() } label: {
                                HStack {
                                    Image(systemName: "building.columns.fill")
                                        .font(.lato(13))
                                        .foregroundStyle(MaudeTheme.ink3)
                                    Text(bank)
                                        .font(.lato(14))
                                        .foregroundStyle(MaudeTheme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(MaudeTheme.ink4)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

                    Text("Open Banking (PSD2): read-only access through your bank's official API, authorised with MitID, revocable at your bank at any time.")
                        .font(.caption)
                        .foregroundStyle(MaudeTheme.ink4)
                }
                .padding(20)
            }
            .background(MaudeTheme.paper)
            .navigationTitle("Connect a bank")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { HealthVaultView() }
}
