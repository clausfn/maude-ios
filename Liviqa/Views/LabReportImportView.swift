// LabReportImportView.swift — FR-REC-03 · "Import a lab report" (Bevel absorb ④).
// v01 · 2026-08-13 · Area ⑦ satellite, entered from Data sources and the
// health data space.
//
// ANATOMY: verdict band → how it works → pick a file/photo → REVIEW BEFORE
// SAVING (every read row, editable, rejectable, with the file named) → saved.
//
// THE FOUR PROMISES THIS SCREEN KEEPS, IN THIS ORDER:
//   1. Read on this device. PDF text layer, or Vision OCR with
//      requiresOnDeviceRecognition — no page ever leaves the phone.
//   2. Nothing is saved until you approve it. Every row is shown with what was
//      printed, what it was converted to, and a switch to drop it.
//   3. Nothing is guessed. Lines the parser couldn't read are listed as unread,
//      with the reason — they are never rounded into a plausible number.
//   4. Your own history is the yardstick. Each row is framed against YOUR
//      previous value for that analyte (LabPriorFraming) — never a lab's
//      printed band and never a verdict (FR-NDG-06 clinicalNormality).
//
// THE FILE ITSELF: discarded after parsing by default (the Sundhed Path B
// precedent). The citizen can opt in to keeping it, and only then is it handed
// to the existing encrypted document vault (HealthVaultStore) — which is what
// the "Keep the file" switch says, in those words.
import SwiftUI
import PhotosUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

struct LabReportImportView: View {

    @Environment(AppState.self) private var appState

    private enum Stage: Equatable { case idle, reading, review, done }

    @State private var stage: Stage = .idle
    @State private var fileName = ""
    /// The picked bytes. Held ONLY between picking and approve/cancel, and only
    /// so the "keep the file" option can hand them to the encrypted vault.
    @State private var fileData: Data?
    @State private var rows: [ReviewRow] = []
    @State private var unread: [UnreadLabLine] = []
    @State private var usedOCR = false
    @State private var printedDate: Date?      // nil ⇒ the file carried no date
    @State private var sampleDate = Date()
    @State private var keepFile = false
    @State private var errorMessage: String?
    @State private var savedCount = 0
    @State private var fileOutcome = ""

    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                verdictBand
                switch stage {
                case .idle, .reading:
                    howCard
                    pickCard
                    onDeviceStrip
                case .review:
                    reviewHeaderCard
                    if rows.isEmpty { nothingReadCard } else { rowsCard }
                    if !unread.isEmpty { unreadCard }
                    fileChoiceCard
                    actionRow
                case .done:
                    doneCard
                }
                if let errorMessage { errorBanner(errorMessage) }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper)
        .navigationTitle("Import a lab report")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { pick(url) }
        }
        #endif
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await pickPhoto(item) }
        }
    }

    // MARK: - Idle

    private var verdictBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.accentRecovery)
                Text(String(localized: "Any lab, read on this phone").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text(stage == .review
                 ? "Check what Liviqa read, then decide."
                 : "A photo or a PDF of your results, in your own record.")
                .font(.liviqaSerif(22)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.accentRecovery)
                .frame(width: 44, height: 3)
        }
        .padding(.top, 4)
    }

    private var howCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("HOW IT WORKS")
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            step(1, "Pick the PDF your lab or hospital sent you, or take a photo of the printed page.")
            step(2, "Liviqa reads it here on this phone and lists what it recognised — with what it could not read, and why.")
            step(3, "You edit or drop any row. Nothing enters your record until you tap Save.")
            Text("Liviqa reads 15 common results: HbA1c, glucose, cholesterol (total, LDL, HDL), triglycerides, creatinine, eGFR, ALAT, TSH, haemoglobin, ferritin, CRP, vitamin D and B12. Anything else is listed, not guessed.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.lato(12, .bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(LiviqaTheme.moss).clipShape(Circle())
            Text(LocalizedStringKey(text))
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pickCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { errorMessage = nil; showFileImporter = true } label: {
                HStack(spacing: 8) {
                    if stage == .reading { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.up.doc.fill").font(.system(size: 14)) }
                    Text(stage == .reading ? "Reading…" : "Choose a PDF or image")
                        .font(.lato(14, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(stage == .reading)

            Button { errorMessage = nil; showPhotoPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill").font(.system(size: 13))
                    Text("Use a photo of the page").font(.lato(14, .bold))
                }
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(LiviqaTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(stage == .reading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private var onDeviceStrip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.moss)
            Text("The page is read on this device — text recognition runs here, not on a server. Nothing is uploaded.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Review

    private var reviewHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REVIEW BEFORE SAVING")
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14)).foregroundStyle(LiviqaTheme.ink3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.lato(13.5, .semibold)).foregroundStyle(LiviqaTheme.ink)
                        .lineLimit(2)
                    Text(usedOCR
                         ? String(localized: "Read with on-device text recognition")
                         : String(localized: "Read from the file's own text"))
                        .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer(minLength: 0)
            }
            Divider().background(LiviqaTheme.line2)
            VStack(alignment: .leading, spacing: 4) {
                DatePicker(selection: $sampleDate, in: ...Date(), displayedComponents: .date) {
                    Text("Sample date").font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                }
                Text(printedDate == nil
                     ? String(localized: "No date was printed on the file that Liviqa could read — today's date is filled in. Change it if you know the day the sample was taken.")
                     : String(localized: "Read from the file. Change it if it's wrong."))
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private var nothingReadCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing recognised")
                .font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
            Text("Liviqa didn't find any of the 15 results it can read in this file, so there is nothing to save. A straight-on photo of the results table, or the lab's own PDF, usually works better.")
                .font(.lato(12.5)).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private var rowsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "Read from this file").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                Text("\(includedCount) of \(rows.count) will be saved")
                    .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
            }
            .padding(.top, 10).padding(.bottom, 4)

            ForEach($rows) { $row in
                if row.id != rows.first?.id {
                    Divider().background(LiviqaTheme.line2)
                }
                reviewRow($row)
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func reviewRow(_ row: Binding<ReviewRow>) -> some View {
        let r = row.wrappedValue
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(r.parsed.analyte.displayName)
                    .font(.lato(14, .semibold)).foregroundStyle(LiviqaTheme.ink)
                Spacer(minLength: 8)
                TextField("", text: row.text)
                    .font(.liviqaMono(17))
                    .foregroundStyle(r.value == nil ? LiviqaTheme.ink4 : LiviqaTheme.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 92)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(r.parsed.unit)
                    .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                Toggle("", isOn: row.include)
                    .labelsHidden()
                    .tint(LiviqaTheme.moss)
            }

            if r.parsed.wasConverted {
                Text("Printed as \(LabPriorFraming.number(r.parsed.reportedValue, decimals: 2)) \(r.parsed.reportedUnit) — converted to \(r.parsed.unit) so it lines up with the rest of your record.")
                    .font(.lato(11)).lineSpacing(1.5)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let v = r.value {
                Text(LabPriorFraming.text(for: r.parsed.analyte, newValue: v, prior: r.prior))
                    .font(.lato(12)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Type a number to save this row.")
                    .font(.lato(11.5)).foregroundStyle(LiviqaTheme.brass)
            }

            if r.isLowConfidence {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .font(.system(size: 11)).foregroundStyle(LiviqaTheme.brass)
                    Text("The page was hard to read here. Check this one against the paper before you keep it — it's switched off until you do.")
                        .font(.lato(11)).lineSpacing(1.5)
                        .foregroundStyle(LiviqaTheme.brass)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(r.parsed.sourceLine)
                .font(.liviqaMono(10))
                .foregroundStyle(LiviqaTheme.ink4)
                .lineLimit(2)
        }
        .padding(.vertical, 11)
    }

    private var unreadCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Not read (\(unread.count))").uppercased())
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            Text("Liviqa leaves these alone rather than guessing at them. They are not saved.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(unread.prefix(12)) { line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.text)
                        .font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink2)
                        .lineLimit(2)
                    Text(reason(line.reason))
                        .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4)
                }
            }
            if unread.count > 12 {
                Text("…and \(unread.count - 12) more lines.")
                    .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func reason(_ r: UnreadLabLine.Reason) -> String {
        switch r {
        case .unknownAnalyte:       return String(localized: "Not one of the results Liviqa reads yet.")
        case .unknownUnit:          return String(localized: "The unit on this line isn't one Liviqa can convert exactly.")
        case .ambiguousNumber:      return String(localized: "The number could be read two ways, so it wasn't read at all.")
        case .censoredValue:        return String(localized: "The report gives a limit rather than a measured value.")
        case .outsideReadableBound: return String(localized: "The digits didn't come through cleanly enough to trust.")
        }
    }

    private var fileChoiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $keepFile) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep the file too")
                        .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("Puts the original in your encrypted health data space, on this phone.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(LiviqaTheme.moss)
            Text(keepFile
                 ? String(localized: "The file will be encrypted into your health data space, where you can open or delete it any time.")
                 : String(localized: "The file is dropped as soon as you save or cancel — only the results you keep stay in your record."))
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { reset() } label: {
                Text("Cancel").font(.lato(14, .bold))
                    .foregroundStyle(LiviqaTheme.ink2)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button { save() } label: {
                Text(includedCount == 0 ? "Nothing selected" : "Save \(includedCount) to my record")
                    .font(.lato(14, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(includedCount == 0 ? LiviqaTheme.ink4 : LiviqaTheme.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(includedCount == 0)
        }
    }

    private var doneCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44)).foregroundStyle(LiviqaTheme.moss)
            Text("Saved").font(.liviqaH2).foregroundStyle(LiviqaTheme.ink)
            Text("\(savedCount) result(s) are now in your health record on this phone, marked as a lab report you imported. \(fileOutcome)")
                .font(.lato(13)).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { reset() } label: {
                Text("Import another report").font(.lato(14, .bold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.brass)
            Text(message).font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.brass2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Picking + reading

    private var includedCount: Int { rows.filter { $0.include && $0.value != nil }.count }

    #if os(iOS)
    private func pick(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = String(localized: "That file couldn't be opened. Nothing was read.")
            return
        }
        Task { await read(data: data, name: url.lastPathComponent) }
    }
    #endif

    private func pickPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run {
                errorMessage = String(localized: "That photo couldn't be opened. Nothing was read.")
                photoItem = nil
            }
            return
        }
        let df = DateFormatter(); df.dateFormat = "d MMM yyyy HH.mm"
        await read(data: data, name: String(localized: "Photo \(df.string(from: Date()))"))
        await MainActor.run { photoItem = nil }
    }

    /// Read + parse off the main actor, then build the review rows.
    @MainActor
    private func read(data: Data, name: String) async {
        stage = .reading
        errorMessage = nil
        fileName = name
        fileData = data

        let outcome = await Task.detached(priority: .userInitiated) { () -> ReadOutcome in
            do {
                let read = try LabReportOCR.read(data: data, filename: name)
                return ReadOutcome(read: read,
                                   parsed: LabReportParser.parse(lines: read.lines),
                                   failure: nil)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                return ReadOutcome(read: nil, parsed: nil, failure: message)
            }
        }.value

        guard let read = outcome.read, let parsed = outcome.parsed else {
            fileData = nil
            stage = .idle
            errorMessage = outcome.failure
                ?? String(localized: "That file couldn't be read on this device.")
            return
        }
        usedOCR = read.usedOCR
        printedDate = parsed.documentDate
        sampleDate = parsed.documentDate ?? Date()
        unread = parsed.unread
        rows = parsed.values.map { value in
            ReviewRow(
                parsed: value,
                include: value.confidence >= Self.lowConfidenceFloor,
                text: LabPriorFraming.number(value.value, decimals: value.analyte.decimals),
                prior: prior(for: value, on: value.date ?? parsed.documentDate ?? Date())
            )
        }
        stage = .review
    }

    /// The citizen's own previous stored reading for this analyte — and only
    /// when it is in the SAME canonical unit, so a comparison is never made
    /// across two different scales.
    private func prior(for value: ParsedLabValue, on date: Date) -> LabPriorFraming.Prior? {
        guard let store = appState.healthStore,
              let row = store.priorObservation(scopeKey: value.analyte.scopeKey, before: date),
              LabReportParser.normalizeUnit(row.unit) == LabReportParser.normalizeUnit(value.unit)
        else { return nil }
        return LabPriorFraming.Prior(value: row.value, date: row.effectiveDate)
    }

    private static let lowConfidenceFloor = 0.5

    // MARK: - Save (the only write path on this screen)

    private func save() {
        guard let store = appState.healthStore else {
            errorMessage = String(localized: "Your record couldn't be opened on this device, so nothing was saved.")
            return
        }
        let keepers = rows.filter { $0.include }
        let observations: [HealthObservation] = keepers.compactMap { row in
            guard let v = row.value else { return nil }
            let key = row.parsed.analyte.scopeKey
            let date = row.parsed.date ?? sampleDate
            let scaled = (v * SundhedParsers.scaleFactor(for: key)).rounded()
            return HealthObservation(
                scopeKey: key,
                value: v,
                unit: row.parsed.unit,
                effectiveDate: date,
                source: HealthDataSource.paperScan.rawValue,
                sourceDetail: fileName,
                mpcScaled: Int(scaled)
            )
        }
        guard !observations.isEmpty else { return }

        do {
            try store.ingest(observations: observations, conditions: [], medications: [],
                             source: .paperScan)
            appState.reloadHealthRecord()
        } catch {
            errorMessage = String(localized: "Those results couldn't be saved to this device. Nothing was stored — please try again.")
            return
        }

        savedCount = observations.count
        fileOutcome = storeFileIfAsked()
        fileData = nil          // the bytes go, either way
        rows = []; unread = []
        stage = .done
    }

    /// Honour the "keep the file" switch. Returns the sentence the done card
    /// uses, which states what ACTUALLY happened to the file.
    private func storeFileIfAsked() -> String {
        guard keepFile, let data = fileData else {
            return String(localized: "The file itself was not kept — it was dropped after reading.")
        }
        guard let vault = try? HealthVaultStore(keyVault: .shared, userScope: LocalUserScope.current()),
              (try? vault.add(name: fileName, data: data,
                              source: String(localized: "Lab report import"))) != nil else {
            return String(localized: "The file itself couldn't be added to your health data space, so it was dropped after reading.")
        }
        return String(localized: "The file is encrypted in your health data space.")
    }

    private func reset() {
        stage = .idle
        rows = []
        unread = []
        fileData = nil
        fileName = ""
        keepFile = false
        printedDate = nil
        errorMessage = nil
        photoItem = nil
    }
}

/// What one background read produced — a Sendable box so the read and the parse
/// can happen off the main actor and cross back in one hop.
private struct ReadOutcome: Sendable {
    let read: LabReportOCR.Read?
    let parsed: LabReportParseResult?
    let failure: String?
}

// MARK: - One editable review row

/// A parsed value plus the citizen's decisions about it. `text` is the editable
/// canonical value: an unparseable edit yields `value == nil`, and the row then
/// cannot be saved (rather than falling back to the machine's reading).
struct ReviewRow: Identifiable {
    let parsed: ParsedLabValue
    var include: Bool
    var text: String
    var prior: LabPriorFraming.Prior?

    var id: Int { parsed.lineIndex }

    var isLowConfidence: Bool { parsed.confidence < 0.5 }

    var value: Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v > 0 else { return nil }
        return v
    }
}

#Preview {
    NavigationStack {
        LabReportImportView()
            .environment(AppState())
    }
}
