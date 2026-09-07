// ShareWithClinicianView.swift — Share a pattern (UC-07) · v02 2026-08-12
// A7.2 rebuild from b-sharing.jsx ScrSharePattern: the 5-step wizard becomes
// ONE scroll form — Who sees it → What they can see (per-area toggles) → How
// long → How it reaches them → lock plate → "Preview & share" (a real preview
// phase, then send). The existing send path (createGrantAndShare → sovereign
// createGrant + DerivedShareBuilder + PUT /shares/{grantId}) is kept untouched.
//
// SAFETY RAILS (qms/RISK.md Area ⑥):
//  • SUMMARIES ONLY — the package's per-area "Every reading" detail level is
//    under an OPEN QMS ruling (DHF 2026-08-12 night) and is NOT built: it
//    contradicts the derived-only rail (FR-SHARE-02 / DerivedShareBuilder) and
//    ScrCreateGrant's own "Raw readings can never be added to a grant · Locked
//    on" plate. Area rows are on/off; the kicker + lock plate say summaries.
//  • Documents & letters — not packageable today (FR-ING-15 open): the row
//    renders SOON + disabled, never a live toggle (honest UI).
//  • "Until I stop it" — the backend has no open-ended expiry: the chip maps
//    to a 12-month grant and the note says honestly that the share pauses
//    after 12 months unless confirmed again (no fake reminder promise).
//  • Nothing pre-selected — consent-conservative default (nothing leaves the
//    phone that the citizen didn't switch on this visit).
//  • Provenance never enters the share payload (enforced in the deriver).
import SwiftUI

struct ShareWithClinicianView: View {
    @Environment(AppState.self) private var appState

    var nudge: Nudge? = nil
    var onDismiss: () -> Void
    /// UC-11 entry (CreateGrantView): restrict the directory to one role.
    var roleFilter: RecipientRole? = nil

    private enum Phase { case form, preview, done }
    @State private var phase: Phase = .form

    // What to share — consent-conservative: everything OFF until switched on.
    @State private var shareGlucose  = false
    @State private var shareSleep    = false
    @State private var shareHeart    = false   // recovery group (HRV, resting rate)
    @State private var shareActivity = false

    // How long — access duration AND data window ride the same chip.
    @State private var selectedDuration: Duration = .days30

    // Recipient (live directory when on the sovereign backend; free text on mock)
    @State private var recipients: [Recipient] = []
    @State private var selectedRecipient: Recipient? = nil
    @State private var recipientName = ""
    @State private var recipientRole = ""

    // Send
    @State private var isSending = false
    @State private var sendError: String? = nil

    enum Duration: String, CaseIterable {
        case days7    = "7 days"
        case days30   = "30 days"
        case months3  = "3 months"
        case openEnded = "Until I stop it"

        /// Data window pushed into the derived package (days back from today).
        var rangeDays: Int {
            switch self {
            case .days7: return 7
            case .days30: return 30
            case .months3: return 90
            case .openEnded: return 90   // full quarter — the widest window the deriver serves
            }
        }
        /// Grant expiry. "Until I stop it" = 12 months, then the share pauses
        /// until confirmed again (honest mapping — no open-ended backend expiry).
        var expiry: Date {
            let cal = Calendar.current
            switch self {
            case .days7:    return cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            case .days30:   return cal.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            case .months3:  return cal.date(byAdding: .month, value: 3, to: Date()) ?? Date()
            case .openEnded: return cal.date(byAdding: .month, value: 12, to: Date()) ?? Date()
            }
        }
        var summaryLabel: String {
            switch self {
            case .openEnded: return String(localized: "Until you stop it (confirm again in 12 months)")
            default: return rawValue
            }
        }
    }

    /// Live recipient directory + grant push is available only on the sovereign backend.
    private var liveSharing: Bool { appState.sovereign != nil }

    private var anySelected: Bool { shareGlucose || shareSleep || shareHeart || shareActivity }

    /// Toggles → consent GROUP keys (contract scope vocabulary).
    private var scopeGroups: Set<String> {
        var g = Set<String>()
        if shareGlucose  { g.insert("glucose") }
        if shareSleep    { g.insert("sleep") }
        if shareHeart    { g.insert("recovery") }   // hrv/rhr
        if shareActivity { g.insert("activity") }
        return g
    }

    /// The detail level this consent surface REQUESTS, stated explicitly here
    /// rather than inferred from a backend default two layers down. Every
    /// "summaries only" line on this screen is derived from this map, so screen
    /// and payload cannot drift apart (see ShareGranularity for the full note).
    private var requestedGranularity: [String: String] {
        ShareGranularity.summariesOnly(for: scopeGroups)
    }

    private var selectedAreas: [String] {
        var items: [String] = []
        if shareGlucose  { items.append(String(localized: "Glucose")) }
        if shareSleep    { items.append(String(localized: "Sleep")) }
        if shareHeart    { items.append(String(localized: "Heart")) }
        if shareActivity { items.append(String(localized: "Activity")) }
        return items
    }

    /// Display name for the resolved recipient (picker selection or free text).
    private var resolvedRecipientName: String {
        selectedRecipient?.displayName ?? recipientName
    }

    private var recipientFirstName: String {
        resolvedRecipientName.components(separatedBy: CharacterSet(charactersIn: " ·")).first ?? resolvedRecipientName
    }

    private var recipientReady: Bool {
        liveSharing
            ? selectedRecipient != nil
            : !recipientName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The share can be previewed once there is a recipient AND at least one
    /// area — the single source of truth for the primary button's state.
    private var canPreview: Bool { anySelected && recipientReady }

    var body: some View {
        ZStack(alignment: .top) {
            MaudeTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(MaudeTheme.line)
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Header — Cancel · Share
                HStack {
                    Button {
                        if phase == .preview { withAnimation { phase = .form } }
                        else { onDismiss() }
                    } label: {
                        Text(phase == .preview ? "Back" : "Cancel")
                            .font(.lato(15))
                            .foregroundStyle(MaudeTheme.ink3)
                    }
                    .opacity(phase == .done ? 0 : 1)
                    Spacer()
                    Text(phase == .done ? "Receipt" : "Share")
                        .font(.maudeSerif(16))
                        .foregroundStyle(MaudeTheme.ink)
                    Spacer()
                    Text("Cancel").font(.lato(15)).opacity(0)   // balance
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                ScrollView {
                    Group {
                        switch phase {
                        case .form:    form
                        case .preview: preview
                        case .done:    doneSlip
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            #if DEBUG
            // Headless screenshot hook: MAUDE_SHARE_PHASE=preview|done jumps the
            // sheet to a later phase with a representative selection. It runs
            // BEFORE the directory fetch on purpose — behind that await the hook
            // used to sit for the whole network timeout on a backend build, which
            // is why the sweep captured the plain form instead of the phase.
            // WalletView opens this sheet for the same variable (headless: set
            // MAUDE_TAB=privacy MAUDE_SHARE_PHASE=preview).
            if let jump = ProcessInfo.processInfo.environment["MAUDE_SHARE_PHASE"] {
                shareGlucose = true; shareSleep = true
                if recipientName.isEmpty {
                    // Free-text name also backs `resolvedRecipientName` on the
                    // live path, where no directory row is selected yet.
                    recipientName = "Mette Holm"; recipientRole = "Diabetes nurse"
                }
                if jump == "preview" { phase = .preview }
                if jump == "done"    { phase = .done }
            }
            #endif
            if recipients.isEmpty, let sov = appState.sovereign,
               let directory = try? await sov.fetchRecipients() {
                recipients = roleFilter.map { f in directory.filter { $0.role == f } } ?? directory
            }
        }
    }

    // MARK: — The form (single scroll)

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Verdict — kicker says SUMMARIES (the "your choice of detail" line
            // belongs to the unbuilt Every-reading mode; see header rails).
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.lato(13, .semibold))
                        .foregroundStyle(MaudeTheme.moss)
                    Text("One area · one time period · summaries only".uppercased())
                        .font(.maudeKicker(10)).tracking(1.2)
                        .foregroundStyle(MaudeTheme.ink3)
                }
                Text("You decide how much they see.")
                    .font(.maudeSerif(22)).kerning(-0.2)
                    .foregroundStyle(MaudeTheme.ink)
                RoundedRectangle(cornerRadius: 2)
                    .fill(MaudeTheme.moss)
                    .frame(width: 44, height: 3)
                    .padding(.top, 4)
            }
            .padding(.top, 4)

            // ── Who sees it ──
            VStack(alignment: .leading, spacing: 10) {
                Text("Who sees it".uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                recipientPicker
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.line, lineWidth: 1))

            // ── What they can see ──
            VStack(alignment: .leading, spacing: 9) {
                Text("What they can see".uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                Text("A summary is Maude's short read of the area — your individual readings stay on this phone.")
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink3)

                areaRow(icon: "drop.fill", color: MaudeTheme.accentGlucose,
                        label: "Glucose", sub: "Time in range, GMI, daily pattern",
                        isOn: $shareGlucose)
                areaRow(icon: "moon.fill", color: MaudeTheme.accentSleep,
                        label: "Sleep", sub: "Duration & consistency",
                        isOn: $shareSleep)
                areaRow(icon: "heart.fill", color: MaudeTheme.accentHeart,
                        label: "Heart", sub: "Resting rate, variability",
                        isOn: $shareHeart)
                areaRow(icon: "figure.walk", color: MaudeTheme.accentRecovery,
                        label: "Activity", sub: "Training load & movement",
                        isOn: $shareActivity)
                documentsRow   // SOON — files aren't packageable yet (FR-ING-15)
            }

            // ── How long ──
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.lato(12, .semibold))
                        .foregroundStyle(MaudeTheme.moss)
                    Text("How long".uppercased())
                        .font(.maudeKicker(10)).tracking(1.2)
                        .foregroundStyle(MaudeTheme.ink3)
                }

                HStack(spacing: 6) {
                    durationChip(.days7)
                    durationChip(.days30)
                    durationChip(.months3)
                }
                durationChip(.openEnded, fullWidth: true)

                Text("An open-ended share saves re-doing this at every visit. You can stop it in one tap, and it pauses after 12 months unless you confirm it again.")
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink3)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.line, lineWidth: 1))

            // ── How it reaches them ──
            VStack(alignment: .leading, spacing: 7) {
                Text("How it reaches them".uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                Text("Most clinicians work in their own system, so \(recipientReady ? recipientFirstName : "your recipient") gets a secure link they open in a browser — nothing to install. They can print it or save it into their record. If their clinic is connected to Maude PRO, it appears there instead.")
                    .font(.lato(12.5)).lineSpacing(2.5)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.line, lineWidth: 1))

            // ── What leaves the phone (lock plate — the summaries-only rail) ──
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock")
                    .font(.lato(13, .semibold))
                    .foregroundStyle(MaudeTheme.moss)
                Text("Only the areas you switch on leave this phone — always as summaries, never your individual readings. This is governed by the Data for Good Foundation and written to your consent record.")
                    .font(.lato(12)).lineSpacing(2.5)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.moss3, lineWidth: 1))

            // ── Preview & share ──
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { phase = .preview }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up").font(.lato(14, .semibold))
                    Text("Preview & share").font(.lato(15, .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // Available vs unavailable is a change of TREATMENT, never a
                // dimmed primary: a 40 %-alpha fill was the same colour family
                // as the live button (design-QA 2026-08-13).
                .background(canPreview ? MaudeTheme.primaryFill : MaudeTheme.primaryOffFill)
                .foregroundStyle(canPreview ? MaudeTheme.primaryLabel : MaudeTheme.primaryOffLabel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canPreview)
        }
    }

    private func areaRow(icon: String, color: Color, label: String, sub: String,
                         isOn: Binding<Bool>) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.lato(14, .semibold))
                    .foregroundStyle(MaudeTheme.ink)
                Text(sub)
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink3)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(MaudeTheme.moss)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13)
            .stroke(isOn.wrappedValue ? MaudeTheme.moss3 : MaudeTheme.line, lineWidth: 1))
    }

    /// Documents & letters — not packageable today (FR-ING-15 open). SOON +
    /// disabled: the honest-UI rule forbids a live-looking toggle here.
    private var documentsRow: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(MaudeTheme.line)
                    .frame(width: 28, height: 28)
                Image(systemName: "doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MaudeTheme.ink3)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Documents & letters")
                        .font(.lato(14, .semibold))
                        .foregroundStyle(MaudeTheme.ink3)
                    Text("SOON")
                        .font(.maudeKicker(8.5)).tracking(1)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(MaudeTheme.moss2))
                        .foregroundStyle(MaudeTheme.moss)
                }
                Text("Sharing files from your health data space is on the way")
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink4)
            }
            Spacer()
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(MaudeTheme.paper2.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13)
            .stroke(MaudeTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func durationChip(_ d: Duration, fullWidth: Bool = false) -> some View {
        Button { selectedDuration = d } label: {
            Text(d.rawValue)
                .font(.lato(12.5, .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selectedDuration == d ? MaudeTheme.moss : MaudeTheme.line2)
                .foregroundStyle(selectedDuration == d ? .white : MaudeTheme.ink2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: — Recipient picker

    @ViewBuilder
    private var recipientPicker: some View {
        if liveSharing {
            if recipients.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading your care directory…")
                        .font(.lato(12.5))
                        .foregroundStyle(MaudeTheme.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 1) {
                    ForEach(recipients) { recipient in
                        Button { selectedRecipient = recipient } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Text(initials(recipient.displayName))
                                    .font(.lato(12, .bold))
                                    .foregroundStyle(MaudeTheme.moss)
                                    .frame(width: 36, height: 36)
                                    .background(MaudeTheme.moss2)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(recipient.displayName) — \(recipientRoleLabel(recipient.role).lowercased())")
                                        .font(.lato(13.5, .semibold))
                                        .foregroundStyle(MaudeTheme.ink)
                                    Text((recipient.org ?? "Care team") + " · verified recipient")
                                        .font(.lato(11.5))
                                        .foregroundStyle(MaudeTheme.ink3)
                                }
                                Spacer()
                                Image(systemName: selectedRecipient?.id == recipient.id ? "checkmark.circle.fill" : "circle")
                                    .font(.lato(18))
                                    .foregroundStyle(selectedRecipient?.id == recipient.id ? MaudeTheme.moss : MaudeTheme.ink4)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if recipient.id != recipients.last?.id {
                            Divider().background(MaudeTheme.line2)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 0) {
                TextField("Name — e.g. Mette Holm", text: $recipientName)
                    .font(.lato(13.5))
                    .foregroundStyle(MaudeTheme.ink)
                    .padding(.vertical, 11)
                Divider().background(MaudeTheme.line2)
                TextField("Role — e.g. diabetes nurse, GP, coach", text: $recipientRole)
                    .font(.lato(13.5))
                    .foregroundStyle(MaudeTheme.ink)
                    .padding(.vertical, 11)
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    private func recipientRoleLabel(_ role: RecipientRole) -> String {
        switch role {
        case .clinicalNurse: return String(localized: "Clinical nurse")
        case .healthCoach:   return String(localized: "Health coach")
        }
    }

    // MARK: — Preview (the promised look-before-it-goes)

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing has been sent yet".uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                Text("Check it before it goes.")
                    .font(.maudeSerif(22)).kerning(-0.2)
                    .foregroundStyle(MaudeTheme.ink)
            }
            .padding(.top, 4)

            VStack(spacing: 0) {
                previewRow("Recipient", resolvedRecipientName +
                           (selectedRecipient == nil && !recipientRole.isEmpty ? " — \(recipientRole)" : ""))
                Divider().background(MaudeTheme.line2)
                previewRow("Areas", selectedAreas.joined(separator: " · ")
                           + ShareGranularity.areaSuffix(requestedGranularity))
                Divider().background(MaudeTheme.line2)
                previewRow("Detail level", ShareGranularity.label(requestedGranularity))
                Divider().background(MaudeTheme.line2)
                previewRow("Data window", "Last \(selectedDuration.rangeDays) days")
                Divider().background(MaudeTheme.line2)
                previewRow("Access", selectedDuration.summaryLabel)
                Divider().background(MaudeTheme.line2)
                previewRow("Your individual readings", "0 shared — ever")
            }
            .padding(.horizontal, 15).padding(.vertical, 4)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.line, lineWidth: 1))

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.lato(13))
                    .foregroundStyle(MaudeTheme.ink3)
                    .padding(.top, 1)
                Text("These are personal patterns, not clinical reports. Your care team should use their own tools for clinical assessment.")
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink3)
            }

            if let sendError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.lato(14))
                        .foregroundStyle(MaudeTheme.rust)
                        .padding(.top, 1)
                    Text(sendError)
                        .font(.lato(12))
                        .foregroundStyle(MaudeTheme.rust)
                }
            }

            Button {
                Task { await send() }
            } label: {
                Text(isSending ? "Sharing…" : "Share now")
                    .font(.lato(15, .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    // In flight = not available: the quiet treatment, not a
                    // half-alpha copy of the live one.
                    .background(isSending ? MaudeTheme.primaryOffFill : MaudeTheme.primaryFill)
                    .foregroundStyle(isSending ? MaudeTheme.primaryOffLabel : MaudeTheme.primaryLabel)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isSending)
        }
    }

    private func previewRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.lato(12))
                .foregroundStyle(MaudeTheme.ink3)
            Spacer(minLength: 8)
            Text(value)
                .font(.lato(12.5, .semibold))
                .foregroundStyle(MaudeTheme.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }

    /// Perform the share. On the sovereign backend this creates a real consent
    /// grant (group scope) and pushes the derived, scoped package
    /// (PUT /shares/{grantId}); on mock/demo it advances to the confirmation.
    ///
    /// OPEN — the last link in the explicit-consent chain (owned by AppState):
    /// `AppState.createGrantAndShare` still passes `granularity: nil`, so what
    /// actually goes on the wire relies on `MaudeBackendService.createGrant`'s
    /// `?? summary` default rather than on what this screen promised. The screen
    /// now names the map (`requestedGranularity`); the wire should carry the same
    /// one. One line, AppState.swift:1056:
    ///     granularity: ShareGranularity.summariesOnly(for: scopeGroups),
    /// (`scopeGroups` is already a parameter of that function.) Then
    /// MaudeTests/ConsultShareTests.swift:135 flips from expecting `nil` to
    /// expecting the explicit summaries map.
    @MainActor
    private func send() async {
        sendError = nil
        guard liveSharing, let recipient = selectedRecipient else {
            withAnimation { phase = .done }   // mock/demo path — simulated success
            return
        }
        isSending = true
        defer { isSending = false }
        let grantId = await appState.createGrantAndShare(
            recipientId: recipient.id,
            role: recipient.role,
            scopeGroups: scopeGroups,
            rangeDays: selectedDuration.rangeDays,
            expiry: selectedDuration.expiry,
            purpose: nil
        )
        if grantId != nil {
            withAnimation { phase = .done }
        } else {
            sendError = appState.lastError ?? String(localized: "Couldn't share right now. Please try again.")
        }
    }

    // MARK: — Done: the on-the-record slip

    /// The confirmation is a receipt slip, not a spinner. NO proof number here:
    /// that renders only from real CE evidence (FR-WAL-09) — the full receipt
    /// with evidence lives in Privacy → your shares → "Add receipt".
    private var doneSlip: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(MaudeTheme.moss2).frame(width: 60, height: 60)
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MaudeTheme.moss)
            }
            .padding(.top, 10)

            VStack(spacing: 7) {
                Text("Your share is on the record.")
                    .font(.maudeSerif(21)).kerning(-0.2)
                    .foregroundStyle(MaudeTheme.ink)
                Text("This slip names exactly what you agreed to. It is kept in your consent record — you can stop the share any time in Privacy.")
                    .font(.lato(13)).lineSpacing(2.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MaudeTheme.ink2)
                    .frame(maxWidth: 310)
            }

            VStack(spacing: 0) {
                previewRow("Recipient", resolvedRecipientName)
                Divider().background(MaudeTheme.line2)
                previewRow("Areas", selectedAreas.joined(separator: " · ")
                           + ShareGranularity.areaSuffix(requestedGranularity))
                Divider().background(MaudeTheme.line2)
                previewRow("Access", selectedDuration.summaryLabel)
                Divider().background(MaudeTheme.line2)
                previewRow("Your individual readings", "0 shared — ever")
            }
            .padding(.horizontal, 15).padding(.vertical, 4)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.brass.opacity(0.5), lineWidth: 1))

            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.lato(12, .semibold))
                    .foregroundStyle(MaudeTheme.moss)
                Text("Governed by the Data for Good Foundation.")
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink2)
            }

            Button { onDismiss() } label: {
                Text("Done")
                    .font(.lato(15, .semibold))
                    .foregroundStyle(MaudeTheme.invertFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(MaudeTheme.invertBG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: — Preview

#Preview {
    ShareWithClinicianView(nudge: nil, onDismiss: {})
        .environment(AppState())
}
