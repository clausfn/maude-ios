// DonorExportView.swift — FR-DON-05 (UI) · the donor's own screen.
//
// REACHABLE ONLY IN A DONOR BUILD. `SettingsView` renders the entry row behind
// `DonationProgramme.isDonorBuild`, which is a compile-time `false` in every
// shipped binary, and this screen refuses again on its own (`preflight`) rather
// than trusting the caller.
//
// The screen's job is to make the crossing VISIBLE: it names the file's exact
// contents before anything is written, states what is deliberately absent,
// explains the date shift, and refuses to describe the donation as anonymous.
// The donor performs the transfer themselves — the app hands them one sealed
// file through the share sheet and does not know, and cannot reach, where it
// goes next.
import SwiftUI

struct DonorExportView: View {
    @Environment(AppState.self) private var appState

    @State private var reference = ""
    @State private var selected: Set<String> = []          // consent default: everything OFF
    @State private var note: String?
    @State private var refusal: String?
    @State private var shareItem: DonationShareItem?
    @State private var confirmingWithdraw = false

    private var grant: WalletGrant? { appState.donationGrant }
    private var payload: DonationPayload? { appState.previewDonation() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !DonationProgramme.isDonorBuild {
                    refusalCard(DonationExport.Refusal.notADonorBuild.message)
                } else if appState.donationConsentUnreadable {
                    refusalCard(String(localized: "A donation record is stored on this phone but this device's key cannot open it. Nothing has been changed or deleted. Do not record a new agreement over it — contact the programme."))
                } else if let grant {
                    activeGrantSection(grant)
                } else {
                    recordGrantSection
                }

                if !appState.donationExports.isEmpty { exportLog }

                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
        .maudeScrollEdge()
        .navigationTitle("Donate to the engineers")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(items: [item.url])
        }
        #endif
        .task { appState.loadDonationConsent() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Donor programme · \(DonationProgramme.id)".uppercased())
                .font(.maudeKicker(10)).tracking(1.2)
                .foregroundStyle(MaudeTheme.ink3)
            Text("A copy of your readings, sealed on this phone.")
                .font(.maudeSerif(22)).kerning(-0.2).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("This is not part of using Maude, and nothing here happens on its own. The app sends nothing: it writes one encrypted file that only \(DonationProgramme.controller)'s two named custodians can open, and you hand that file over yourself.")
                .font(.lato(13)).lineSpacing(2.5)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - No grant yet

    private var recordGrantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your signed agreement")
                        .font(.lato(15, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text("Donation is agreed on paper, outside the app. Enter the reference printed on the form you signed, and tick only the kinds of reading that form covers. Nothing is sent anywhere by doing this — it is recorded on this phone so the app knows what you agreed to and can refuse anything else.")
                        .font(.lato(12.5)).lineSpacing(2.5)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Reference from your form", text: $reference)
                        .font(.maudeMono(13))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(MaudeTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MaudeTheme.line, lineWidth: 1))
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        #endif
                }
            }

            card {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Everything is off until you switch it on.")
                        .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                        .padding(.bottom, 6)
                    ForEach(DonationAssembler.Scope.allCases, id: \.rawValue) { scope in
                        Toggle(isOn: Binding(
                            get: { selected.contains(scope.rawValue) },
                            set: { on in
                                if on { selected.insert(scope.rawValue) } else { selected.remove(scope.rawValue) }
                            })) {
                            Text(scope.label).font(.lato(14.5, .semibold)).foregroundStyle(MaudeTheme.ink)
                        }
                        .tint(MaudeTheme.moss)
                        .padding(.vertical, 9)
                    }
                }
            }

            Button {
                let ok = appState.recordDonationGrant(reference: reference, scopes: selected)
                note = ok
                    ? String(localized: "Recorded on this phone. Nothing has been exported yet.")
                    : String(localized: "That could not be recorded. Check the reference and that at least one kind of reading is ticked.")
            } label: {
                Text("Record this agreement")
                    .font(.lato(16, .bold)).foregroundStyle(MaudeTheme.invertFG)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(MaudeTheme.invertBG.opacity(canRecord ? 1 : 0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canRecord)

            if let note { noteCard(note) }
            honestyCard
        }
    }

    private var canRecord: Bool {
        !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selected.isEmpty
    }

    // MARK: - Active grant

    @ViewBuilder
    private func activeGrantSection(_ grant: WalletGrant) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Agreement \(DonationExport.reference(for: grant))")
                    .font(.maudeMono(12)).foregroundStyle(MaudeTheme.ink2)
                Text("Active" + (grant.expiresAt.map { " until " + Self.dayFormatter.string(from: $0) } ?? ""))
                    .font(.lato(13, .semibold)).foregroundStyle(MaudeTheme.ink)
                Text("Covers: " + grant.scopeKeys.compactMap { DonationAssembler.Scope(rawValue: $0)?.label }
                        .joined(separator: ", "))
                    .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        // What would actually be in the file — same assembler the export runs.
        if let payload {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What this file would contain".uppercased())
                        .font(.maudeKicker(10)).tracking(1.2).foregroundStyle(MaudeTheme.ink3)
                    ForEach(countRows(payload), id: \.label) { row in
                        HStack {
                            Text(row.label).font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                            Spacer()
                            Text(row.value).font(.maudeMono(12)).foregroundStyle(MaudeTheme.ink)
                        }
                    }
                    Divider().background(MaudeTheme.line2).padding(.vertical, 2)
                    ForEach(DonationProgramme.includedItems, id: \.self) { item in
                        bullet(item, symbol: "checkmark", tint: MaudeTheme.moss)
                    }
                }
            }

            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What is not in it".uppercased())
                        .font(.maudeKicker(10)).tracking(1.2).foregroundStyle(MaudeTheme.ink3)
                    ForEach(DonationProgramme.excludedItems, id: \.self) { item in
                        bullet(item, symbol: "xmark", tint: MaudeTheme.ink4)
                    }
                }
            }
        }

        Button {
            do {
                let url = try appState.exportDonation()
                shareItem = DonationShareItem(url: url)
                refusal = nil
                note = String(localized: "The encrypted file is ready. Send it the way the programme told you to — the app has not sent anything.")
            } catch let r as DonationExport.Refusal {
                refusal = r.message
                note = nil
            } catch {
                refusal = DonationExport.Refusal.writeFailed.message
                note = nil
            }
        } label: {
            Text("Create the encrypted file")
                .font(.lato(16, .bold)).foregroundStyle(MaudeTheme.invertFG)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(MaudeTheme.invertBG)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)

        if let refusal { refusalCard(refusal) }
        if let note { noteCard(note) }

        Button {
            DonationExport.purgeStaged()
            note = String(localized: "Any file still waiting on this phone has been deleted. Copies you already sent are held by the programme, not by the app.")
        } label: {
            Text("Delete the file from this phone")
                .font(.lato(13.5, .semibold)).foregroundStyle(MaudeTheme.ink2)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)

        honestyCard

        Button { confirmingWithdraw = true } label: {
            Text("Withdraw from the programme")
                .font(.lato(13.5, .semibold)).foregroundStyle(MaudeTheme.clayText)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Withdraw from the donor programme?",
                            isPresented: $confirmingWithdraw, titleVisibility: .visible) {
            Button("Withdraw", role: .destructive) {
                _ = appState.withdrawDonationGrant()
                note = String(localized: "Withdrawn. This phone will not create another donation file. Ask the programme to delete what you have already sent — that erasure happens where the data is held, and this app cannot do it for you.")
            }
            Button("Keep donating", role: .cancel) { confirmingWithdraw = false }
        } message: {
            Text("Nothing else changes — your app, your standing and everything else stay exactly as they are.")
        }
    }

    // MARK: - Export log

    private var exportLog: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("What has left this phone".uppercased())
                    .font(.maudeKicker(10)).tracking(1.2).foregroundStyle(MaudeTheme.ink3)
                ForEach(appState.donationExports) { record in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Self.stampFormatter.string(from: record.occurredAt))
                            .font(.lato(13, .semibold)).foregroundStyle(MaudeTheme.ink)
                        Text("\(record.rowCount) rows · \(record.byteCount / 1024) KB")
                            .font(.lato(12)).foregroundStyle(MaudeTheme.ink2)
                        Text(record.sealedDigest.prefix(16) + "…")
                            .font(.maudeMono(10)).foregroundStyle(MaudeTheme.ink4)
                    }
                    if record.id != appState.donationExports.last?.id {
                        Divider().background(MaudeTheme.line2)
                    }
                }
            }
        }
    }

    // MARK: - Standing honesty card

    private var honestyCard: some View {
        card(background: MaudeTheme.brass2, stroke: MaudeTheme.brass.opacity(0.5)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(DonationProgramme.pseudonymityNotice)
                    .font(.lato(12)).lineSpacing(2.5).foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(DonationProgramme.dateShiftNotice)
                    .font(.lato(12)).lineSpacing(2.5).foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        Text(DonationCopy.readingsClaim(donating: appState.hasActiveDonationGrant))
            .font(.lato(11.5)).lineSpacing(2)
            .foregroundStyle(MaudeTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    // MARK: - Pieces

    private func countRows(_ payload: DonationPayload) -> [(label: String, value: String)] {
        DonationAssembler.Scope.allCases.compactMap { scope in
            guard let n = payload.countsByStream[scope.rawValue] else { return nil }
            return (scope.label, "\(n)")
        }
    }

    private func bullet(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.lato(11, .semibold)).foregroundStyle(tint)
                .padding(.top, 2)
            Text(text).font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refusalCard(_ text: String) -> some View {
        card(background: MaudeTheme.paper2, stroke: MaudeTheme.clayText.opacity(0.4)) {
            Text(text).font(.lato(12.5)).lineSpacing(2.5)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func noteCard(_ text: String) -> some View {
        card {
            Text(text).font(.lato(12.5)).lineSpacing(2.5)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func card<Content: View>(background: Color = MaudeTheme.paper2,
                                     stroke: Color = MaudeTheme.line,
                                     @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(stroke, lineWidth: 1))
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()
}

/// Share-sheet item for the sealed file. A URL, nothing more — the app never
/// reads the bytes back.
struct DonationShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
