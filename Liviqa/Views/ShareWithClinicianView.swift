// ShareWithClinicianView.swift — Multi-step data sharing flow · v01 2026-05-22
import SwiftUI

struct ShareWithClinicianView: View {
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

    // Step 3 — recipient
    @State private var recipientName = ""
    @State private var recipientRole = ""

    private let rangeOptions = ["Last 7 days", "Last 30 days", "Last 90 days"]

    private var anySelected: Bool {
        shareGlucose || shareSleep || shareHRV || shareActivity || shareNudges
    }

    private var selectedItems: [String] {
        var items: [String] = []
        if shareGlucose  { items.append("Glucose patterns · last 7 days") }
        if shareSleep    { items.append("Sleep data · last 7 days") }
        if shareHRV      { items.append("Heart rate variability") }
        if shareActivity { items.append("Training load & activity") }
        if shareNudges   { items.append("Nudge history · this week") }
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
                    .fill(LiviqaTheme.amber.opacity(0.5))
                    .frame(width: 1)
                    .padding(.vertical, 2)
                Text("These are personal patterns, not clinical reports. Your care team should use their own tools for clinical assessment.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink2)
            }
            .padding(12)
            .background(LiviqaTheme.amber2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(LiviqaTheme.amber.opacity(0.3), lineWidth: 0.5)
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
                    .font(.system(size: 18))
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
                                .font(.system(size: 18))
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

            Text("The link will work for 48 hours. Your care team doesn't need a Liviqa account.")
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink3)

            navButtons(backAction: { step = 2 }, nextAction: { step = 4 }, nextDisabled: recipientName.trimmingCharacters(in: .whitespaces).isEmpty)
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
                summaryRow(label: "Recipient", value: recipientName)
                Divider().padding(.leading, 14)
                summaryRow(label: "Role", value: recipientRole.isEmpty ? "Not specified" : recipientRole)
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
                    .font(.system(size: 14))
                    .foregroundStyle(LiviqaTheme.amber)
                    .padding(.top, 1)
                Text("Once sent, you can revoke access in your consent record at any time.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
            }

            navButtons(
                backAction: { step = 3 },
                nextLabel: "Send secure link",
                nextAction: { step = 5 },
                nextDisabled: false
            )
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
                .font(.system(size: 56))
                .foregroundStyle(LiviqaTheme.moss)

            VStack(spacing: 8) {
                Text("Link sent to \(recipientName)")
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
}
