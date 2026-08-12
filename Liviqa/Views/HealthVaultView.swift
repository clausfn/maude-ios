// HealthVaultView.swift — "Health data space" (FR-ING-12/13, realised by
// FR-ING-15) + the Open Banking & Screen Time connect sheets.
// v02 · 2026-08-12 · A7.2 Area ⑦: rebuilt to the ScrVault canvas
// (b-integrations.jsx) over a REAL encrypted document store.
//
// THE SPACE: the citizen's own document store — labs, clinical letters, scans,
// photos. Every document is AES-256-GCM encrypted the moment it's added, with
// the data key wrapped to this device's Secure Enclave (HealthVaultStore /
// KeyVault). Add via Files or Photos; preview + delete inside. The old demo
// folder seed (VaultSeed) and the "previews locked until the live production
// test" alert are retired — storage is real now, so the claims can be too.
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
    @State private var storeError: String?
    @State private var note: String?

    @State private var showAddDialog = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var selected: VaultDocumentMeta?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                verdictBand
                explainerCard
                if let storeError {
                    errorCard(storeError)
                } else if docs.isEmpty {
                    emptyCard
                } else {
                    documentList
                }
                addAffordance
                if let note { noteRow(note) }
                consentStrip
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper)
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
    }

    // MARK: Store plumbing

    private func openStore() {
        guard store == nil else { return }
        do {
            store = try HealthVaultStore(keyVault: .shared, userScope: LocalUserScope.current())
            reload()
        } catch {
            storeError = String(localized: "The encrypted space couldn't be opened on this device. Your documents are unreadable without this device's key — nothing was lost, but nothing can be shown right now.")
        }
    }

    private func reload() {
        guard let store else { return }
        do { docs = try store.documents() }
        catch {
            storeError = String(localized: "The document list couldn't be read. It is stored encrypted — a failed integrity check is shown as an error, never as wrong content.")
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
                    .foregroundStyle(LiviqaTheme.accentSleep)
                Text(String(localized: "Encrypted on this device").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text("Your documents, locked to this phone.")
                .font(.liviqaSerif(22)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.accentSleep)
                .frame(width: 44, height: 3)
        }
        .padding(.top, 4)
    }

    private var explainerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16))
                .foregroundStyle(LiviqaTheme.accentSleep)
            Text(explainerText)
                .font(.lato(12.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    /// The canvas line, with the key-protection clause kept honest: name the
    /// Secure Enclave only when the key really is hardware-backed (simulators
    /// fall back to a software device key — KeyVault records which path is live).
    private var explainerText: AttributedString {
        let enclave = KeyVault.shared.isHardwareBacked
            ? String(localized: "the key is held by this device's Secure Enclave.")
            : String(localized: "the key never leaves this device.")
        var s = AttributedString(String(localized: "Lab results, letters, scans — stored with AES-256 encryption, readable only on your unlocked device. Nothing is uploaded, and \(enclave)"))
        if let r = s.range(of: "AES-256") {
            s[r].font = .lato(12.5, .bold)
        }
        return s
    }

    private var documentList: some View {
        VStack(spacing: 0) {
            ForEach(Array(docs.enumerated()), id: \.element.id) { idx, doc in
                if idx > 0 {
                    Divider().padding(.leading, 62).background(LiviqaTheme.line2)
                }
                Button { selected = doc } label: { documentRow(doc) }
                    .buttonStyle(.plain)
            }
        }
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func documentRow(_ doc: VaultDocumentMeta) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LiviqaTheme.invertBG)
                    .frame(width: 38, height: 38)
                Image(systemName: doc.kind.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(LiviqaTheme.invertFG)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(.lato(13.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1)
                Text("\(Self.dayFormatter.string(from: doc.addedAt)) · \(Self.size(doc.byteSize))")
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "lock.fill").font(.system(size: 9))
                Text("Encrypted").font(.lato(10, .bold))
            }
            .foregroundStyle(LiviqaTheme.moss)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing here yet")
                .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
            Text("Add your first document below — a lab letter, a scan, a photo of a paper result. It's encrypted the moment it's added.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private var addAffordance: some View {
        Button { showAddDialog = true } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LiviqaTheme.moss2)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Add a document")
                        .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("Encrypted the moment it's added")
                        .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
            }
            .padding(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(LiviqaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store == nil)
    }

    private var consentStrip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.moss)
            Text("Documents stay out of every share by default. Money and insurance papers never enter a clinician share — they live here, on this phone, full stop.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.clay)
            Text(message).font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.clay2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func noteRow(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12)).foregroundStyle(LiviqaTheme.moss)
            Text(text).font(.lato(12)).foregroundStyle(LiviqaTheme.ink2)
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
            .background(LiviqaTheme.paper)
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
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
            case .image:
                if let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else { noPreview }
            #endif
            case .text:
                Text(String(decoding: data, as: UTF8.self))
                    .font(.liviqaMono(12)).foregroundStyle(LiviqaTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            default:
                noPreview
            }
        } else if loadError {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13)).foregroundStyle(LiviqaTheme.clay)
                Text("This document couldn't be decrypted. A failed integrity check is shown as an error — never as altered content.")
                    .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.clay2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        }
    }

    private var noPreview: some View {
        VStack(spacing: 8) {
            Image(systemName: meta.kind.symbol)
                .font(.system(size: 34)).foregroundStyle(LiviqaTheme.ink4)
            Text("No preview for this file type — the document itself is stored encrypted on this phone.")
                .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 20)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            metaRow(String(localized: "Added"), Self.dayFormatter.string(from: meta.addedAt))
            Divider().background(LiviqaTheme.line2)
            metaRow(String(localized: "Came in from"), meta.source)
            Divider().background(LiviqaTheme.line2)
            metaRow(String(localized: "Size"),
                    ByteCountFormatter.string(fromByteCount: Int64(meta.byteSize), countStyle: .file))
            Divider().background(LiviqaTheme.line2)
            metaRow(String(localized: "Protection"),
                    KeyVault.shared.isHardwareBacked
                        ? String(localized: "AES-256 · key held by the Secure Enclave")
                        : String(localized: "AES-256 · key held by this device"))
        }
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
            Spacer()
            Text(value).font(.lato(12.5, .semibold)).foregroundStyle(LiviqaTheme.ink)
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
            .foregroundStyle(LiviqaTheme.rust)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(LiviqaTheme.rust2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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
                    Text("Money and health move together. Stress often shows in spending before it shows in symptoms — late-evening purchases track short sleep; quiet grocery weeks track low-energy weeks. Liviqa reads daily totals and category patterns only — never single transactions, never merchant names.")
                        .font(.lato(13.5)).lineSpacing(3)
                        .foregroundStyle(LiviqaTheme.ink2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(LiviqaTheme.clay)
                            Text("More private than health data — treated that way")
                                .font(.lato(13, .bold))
                                .foregroundStyle(LiviqaTheme.ink)
                        }
                        Text("Your financial patterns stay in your health data space on this phone, beside your other documents. Encrypted, never part of any clinician share, never sent anywhere. Disconnect and erase them in one tap, any time.")
                            .font(.lato(12.5)).lineSpacing(2.5)
                            .foregroundStyle(LiviqaTheme.ink2)
                    }
                    .padding(12)
                    .background(LiviqaTheme.clay2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("CHOOSE YOUR BANK")
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.ink3)

                    VStack(spacing: 0) {
                        ForEach(banks, id: \.self) { bank in
                            if bank != banks.first { Divider().padding(.leading, 14) }
                            Button { onConnect(bank); dismiss() } label: {
                                HStack {
                                    Image(systemName: "building.columns.fill")
                                        .font(.lato(13))
                                        .foregroundStyle(LiviqaTheme.ink3)
                                    Text(bank)
                                        .font(.lato(14))
                                        .foregroundStyle(LiviqaTheme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(LiviqaTheme.ink4)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

                    Text("Open Banking (PSD2): read-only access through your bank's official API, authorised with MitID, revocable at your bank at any time.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink4)
                }
                .padding(20)
            }
            .background(LiviqaTheme.paper)
            .navigationTitle("Connect a bank")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Screen Time connect sheet

struct ScreenTimeSheet: View {
    var onConnect: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("One number per day — total screen time. Long evenings on the phone often pair with later nights and shorter sleep; the pattern helps explain your mornings.")
                    .font(.lato(13.5)).lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink2)
                Text("App names, websites and content are never accessed. The daily total stays on this device.")
                    .font(.lato(12.5)).lineSpacing(2.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LiviqaTheme.clay2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button { onConnect(); dismiss() } label: {
                    Text("Connect Screen Time")
                        .font(.lato(15, .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LiviqaTheme.moss)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .padding(20)
            .background(LiviqaTheme.paper)
            .navigationTitle("Screen Time")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { HealthVaultView() }
}
