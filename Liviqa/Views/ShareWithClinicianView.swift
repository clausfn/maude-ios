// ShareWithClinicianView.swift — Multi-step data sharing flow · v01 2026-05-22
import SwiftUI

struct ShareWithClinicianView: View {
    @Environment(AppState.self) private var appState

    var nudge: Nudge? = nil
    var onDismiss: () -> Void

    @State private var step = 1

    // Step 1 — what to share
    @State private var shareGlucose  = true
    @State private var shareSleep    = false
    @State private var shareHRV      = false
    @State private var shareActivity = false
    @State private var shareNudges   = true

    // Step 2 — time range
    @State private var selectedRange = "Last 7 days"

    // Step 3 — recipient (live directory when on the sovereign backend; free text on mock)
    @State private var recipients: [Recipient] = []
    @State private var selectedRecipient: Recipient? = nil
    @State private var recipientName = ""
    @State private var recipientRole = ""

    // Step 4 — send
    @State private var isSending = false
    @State private var sendError: String? = nil

    private let rangeOptions = ["Last 7 days", "Last 30 days", "Last 90 days"]

    /// Live recipient directory + grant push is available only on the sovereign backend.
    private var liveSharing: Bool { appState.sovereign != nil }

    private var anySelected: Bool {
        shareGlucose || shareSleep || shareHRV || shareActivity || shareNudges
    }

    /// Step-1 toggles → consent GROUP keys (NudgeS aren't a scope group — insights
    /// ride along inside the derived share). Maps to scope-vocab in the contract.
    private var scopeGroups: Set<String> {
        var g = Set<String>()
        if shareGlucose  { g.insert("glucose") }
        if shareSleep    { g.insert("sleep") }
        if shareHRV      { g.insert("recovery") }   // hrv/rhr
        if shareActivity { g.insert("activity") }
        return g
    }

    private var rangeDays: Int {
        switch selectedRange {
        case "Last 30 days": return 30
        case "Last 90 days": return 90
        default:             return 7
        }
    }

    /// Display name for the resolved recipient (picker selection or free text).
    private var resolvedRecipientName: String {
        selectedRecipient?.displayName ?? recipientName
    }

    private var selectedItems: [String] {
        var items: [String] = []
        if shareGlucose  { items.append("Glucose patterns") }
        if shareSleep    { items.append("Sleep data") }
        if shareHRV      { items.append("Heart rate variability") }
        if shareActivity { items.append("Training load & activity") }
        if shareNudges   { items.append("Nudge history") }
        return items
    }

    var body: some View {
        ZStack(alignment: .top) {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(LiviqaTheme.line)
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                // Progress dots (steps 1–4 only)
                if step < 5 {
                    HStack(spacing: 6) {
                        ForEach(1...4, id: \.self) { i in
                            Circle()
                                .fill(i == step ? LiviqaTheme.moss : LiviqaTheme.line2)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.bottom, 20)
                }

                // Page content
                ScrollView {
                    Group {
                        switch step {
                        case 1:  step1
                        case 2:  step2
                        case 3:  step3
                        case 4:  step4
                        default: step5
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            guard recipients.isEmpty, let sov = appState.sovereign else { return }
            if let directory = try? await sov.fetchRecipients() {
                recipients = directory
            }
        }
    }

    // MARK: — Step 1: What to share

    private var step1: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose what to share")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text("Select the patterns you want your care team to see. Nothing is sent until you confirm.")
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink3)
            }

            // Checkboxes card
            VStack(spacing: 1) {
                checkRow("Glucose patterns · last 7 days",  $shareGlucose)
                Divider().padding(.leading, 44)
                checkRow("Sleep data · last 7 days",        $shareSleep)
                Divider().padding(.leading, 44)
                checkRow("Heart rate variability",          $shareHRV)
                Divider().padding(.leading, 44)
                checkRow("Training load & activity",        $shareActivity)
                Divider().padding(.leading, 44)
                checkRow("Nudge history · this week",       $shareNudges)
            }
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LiviqaTheme.line2, lineWidth: 1)
            )

            // MDR note
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(LiviqaTheme.clay.opacity(0.5))
                    .frame(width: 1)
                    .padding(.vertical, 2)
                Text("These are personal patterns, not clinical reports. Your care team should use their own tools for clinical assessment.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink2)
            }
            .padding(12)
            .background(LiviqaTheme.clay2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(LiviqaTheme.clay.opacity(0.3), lineWidth: 0.5)
            )

            nextButton(label: "Next", disabled: !anySelected) { step = 2 }
        }
    }

    private func checkRow(_ label: String, _ binding: Binding<Bool>) -> some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: binding.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.lato(18))
                    .foregroundStyle(binding.wrappedValue ? LiviqaTheme.moss : LiviqaTheme.line)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Step 2: Time range

    private var step2: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How far back?")
                .font(.title2.weight(.bold))
                .foregroundStyle(LiviqaTheme.ink)

            VStack(spacing: 1) {
                ForEach(rangeOptions, id: \.self) { option in
                    Button {
                        selectedRange = option
                    } label: {
                        HStack {
                            Text(option)
                                .font(.footnote)
                                .foregroundStyle(option == selectedRange ? LiviqaTheme.moss : LiviqaTheme.ink)
                            Spacer()
                            Image(systemName: option == selectedRange ? "checkmark.circle.fill" : "circle")
                                .font(.lato(18))
                                .foregroundStyle(option == selectedRange ? LiviqaTheme.moss : LiviqaTheme.ink4)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    if option != rangeOptions.last {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LiviqaTheme.line2, lineWidth: 1)
            )

            navButtons(backAction: { step = 1 }, nextAction: { step = 3 }, nextDisabled: false)
        }
    }

    // MARK: — Step 3: Recipient

    private var step3: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your recipient")
                .font(.title2.weight(.bold))
                .foregroundStyle(LiviqaTheme.ink)

            if liveSharing {
                recipientPicker
            } else {
                VStack(spacing: 0) {
                    inputRow(placeholder: "e.g. L. · Diabetes Centre", text: $recipientName)
                    Divider().padding(.horizontal, 14)
                    inputRow(placeholder: "e.g. Diabetes nurse, GP, Sports coach", text: $recipientRole)
                }
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LiviqaTheme.line, lineWidth: 1)
                )
            }

            Text("Sharing runs for 48 hours, then access ends automatically. You can withdraw sooner in your Wallet.")
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink3)

            navButtons(backAction: { step = 2 }, nextAction: { step = 4 }, nextDisabled: !recipientReady)
        }
    }

    /// Step-3 readiness: a real selection on the sovereign backend, or non-empty
    /// free text on mock/demo.
    private var recipientReady: Bool {
        liveSharing
            ? selectedRecipient != nil
            : !recipientName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var recipientPicker: some View {
        if recipients.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading your care directory…")
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 1) {
                ForEach(recipients) { recipient in
                    Button {
                        selectedRecipient = recipient
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipient.displayName)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(LiviqaTheme.ink)
                                Text(recipientRoleLabel(recipient.role) + (recipient.org.map { " · \($0)" } ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(LiviqaTheme.ink3)
                            }
                            Spacer()
                            Image(systemName: selectedRecipient?.id == recipient.id ? "checkmark.circle.fill" : "circle")
                                .font(.lato(18))
                                .foregroundStyle(selectedRecipient?.id == recipient.id ? LiviqaTheme.moss : LiviqaTheme.ink4)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if recipient.id != recipients.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(LiviqaTheme.line, lineWidth: 1)
            )
        }
    }

    private func recipientRoleLabel(_ role: RecipientRole) -> String {
        switch role {
        case .clinicalNurse: return "Clinical nurse"
        case .healthCoach:   return "Health coach"
        }
    }

    private func inputRow(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.footnote)
            .foregroundStyle(LiviqaTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
    }

    // MARK: — Step 4: Review & send

    private var step4: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ready to share")
                .font(.title2.weight(.bold))
                .foregroundStyle(LiviqaTheme.ink)

            VStack(spacing: 0) {
                summaryRow(label: "Recipient", value: resolvedRecipientName)
                Divider().padding(.leading, 14)
                summaryRow(label: "Role", value: step4RoleLabel)
                Divider().padding(.leading, 14)
                summaryRow(label: "Data", value: selectedItems.joined(separator: ", "))
                Divider().padding(.leading, 14)
                summaryRow(label: "Period", value: selectedRange)
                Divider().padding(.leading, 14)
                summaryRow(label: "Expires", value: "In 48 hours")
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LiviqaTheme.line2, lineWidth: 1)
            )

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .font(.lato(14))
                    .foregroundStyle(LiviqaTheme.clay)
                    .padding(.top, 1)
                Text("Derived summaries only — no raw samples leave your device. You can revoke access in your Wallet at any time.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
            }

            if let sendError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.rust)
                        .padding(.top, 1)
                    Text(sendError)
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.rust)
                }
            }

            navButtons(
                backAction: { step = 3 },
                nextLabel: isSending ? "Sending…" : "Send secure link",
                nextAction: { Task { await send() } },
                nextDisabled: isSending
            )
        }
    }

    private var step4RoleLabel: String {
        if let role = selectedRecipient?.role { return recipientRoleLabel(role) }
        return recipientRole.isEmpty ? "Not specified" : recipientRole
    }

    /// Perform the share. On the sovereign backend this creates a real consent
    /// grant (group scope) and pushes the derived, scoped package
    /// (PUT /shares/{grantId}); on mock/demo it simply advances to the confirmation.
    @MainActor
    private func send() async {
        sendError = nil
        guard liveSharing, let recipient = selectedRecipient else {
            step = 5   // mock/demo path — keep the simulated success
            return
        }
        isSending = true
        defer { isSending = false }
        let expiry = Calendar.current.date(byAdding: .hour, value: 48, to: Date()) ?? Date()
        let grantId = await appState.createGrantAndShare(
            recipientId: recipient.id,
            role: recipient.role,
            scopeGroups: scopeGroups,
            rangeDays: rangeDays,
            expiry: expiry,
            purpose: nil
        )
        if grantId != nil {
            step = 5
        } else {
            sendError = appState.lastError ?? "Couldn't share right now. Please try again."
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink4)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: — Step 5: Confirmation

    private var step5: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 32)

            Image(systemName: "checkmark.circle.fill")
                .font(.lato(56))
                .foregroundStyle(LiviqaTheme.moss)

            VStack(spacing: 8) {
                Text("Shared with \(resolvedRecipientName)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LiviqaTheme.ink)
                    .multilineTextAlignment(.center)

                Text("Your care team can view your patterns for 48 hours. This sharing is logged in your privacy record.")
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 32)

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LiviqaTheme.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 20)
    }

    // MARK: — Shared button helpers

    private func nextButton(label: String = "Next", disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(disabled ? LiviqaTheme.moss.opacity(0.4) : LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled)
    }

    private func navButtons(
        backAction: @escaping () -> Void,
        nextLabel: String = "Next",
        nextAction: @escaping () -> Void,
        nextDisabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Text("Back")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LiviqaTheme.line2, lineWidth: 1)
                    )
            }
            .frame(maxWidth: 100)

            nextButton(label: nextLabel, disabled: nextDisabled, action: nextAction)
        }
    }
}

// MARK: — Preview

#Preview {
    ShareWithClinicianView(nudge: nil, onDismiss: {})
        .environment(AppState())
}
