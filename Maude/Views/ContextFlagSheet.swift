// ContextFlagSheet.swift — FR-CTX-04 entry + review surface (Bevel absorb ③).
//
// Two states in one sheet:
//   • nothing marked  → pick travelling / unwell / off-routine, optional note
//   • something open  → the open stretch, with "End this" and "Remove"
// Below both, the user's own history of marked stretches (their record, their
// words) so the review path in Settings and the entry path on Today are the
// same screen.
//
// Honest by construction: the copy states exactly what marking does (stop
// reading these days as a drift from your usual) and what it does not (change,
// hide or invent any reading). Slate/context tint — never amber, never red.
import SwiftUI

struct ContextFlagSheet: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    /// Nil until the user picks a kind (the "mark" button stays inert until then).
    @State private var picked: ContextFlagKind? = nil
    @State private var confirmRemove: UUID? = nil

    private var open: ContextFlag? { appState.openContextFlags.first }

    private static let dayFormat: Date.FormatStyle =
        .dateTime.day().month(.abbreviated)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    intro
                    if let open {
                        openCard(open)
                    } else {
                        picker
                        noteField
                        markButton
                    }
                    if !past.isEmpty {
                        MaudeSectionHeader(label: "Days you've marked")
                        ForEach(past) { flag in
                            historyRow(flag)
                        }
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(MaudeTheme.paper)
            .navigationTitle(String(localized: "Context"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                        .font(.lato(15))
                        .foregroundStyle(MaudeTheme.ink2)
                }
            }
        }
    }

    /// Every stretch, newest first — the open one is already shown above.
    private var past: [ContextFlag] {
        appState.contextFlags
            .filter { $0.id != open?.id }
            .sorted { $0.startedOn > $1.startedOn }
    }

    // MARK: - Intro

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(MaudeTheme.accentFinance)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text("When life explains it")
                    .font(.maudeSerif(20)).kerning(-0.2)
                    .foregroundStyle(MaudeTheme.ink)
                Text("Mark the days you're away, ill or off your routine. Maude keeps recording them exactly as they happen — it just stops reading them as a drift from your usual.")
                    .font(.lato(13)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Open stretch

    private func openCard(_ flag: ContextFlag) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: flag.kind.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(MaudeTheme.accentFinance)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(flag.kind.label)
                        .font(.lato(15, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text("Marked since \(flag.startedOn.formatted(Self.dayFormat))")
                        .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                }
                Spacer(minLength: 6)
            }
            if let n = flag.note, !n.isEmpty {
                Text(n)
                    .font(.lato(13)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(flag.kind.todayDetail)
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                appState.endContextFlag(flag.id)
            } label: {
                Text("I'm back to my routine")
                    .font(.lato(14, .bold))
                    .foregroundStyle(MaudeTheme.invertFG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MaudeTheme.invertBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Text("Today stays marked — you lived it. Tomorrow reads as usual again.")
                .font(.lato(11)).foregroundStyle(MaudeTheme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(MaudeTheme.accentFinance.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Picker

    private var picker: some View {
        VStack(spacing: 8) {
            ForEach(ContextFlagKind.allCases) { kind in
                Button {
                    picked = (picked == kind) ? nil : kind
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(picked == kind ? .white : MaudeTheme.accentFinance)
                            .frame(width: 32, height: 32)
                            .background(picked == kind ? MaudeTheme.accentFinance
                                                       : MaudeTheme.accentFinance.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.label)
                                .font(.lato(14.5, .bold)).foregroundStyle(MaudeTheme.ink)
                            Text(kind.explainer)
                                .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 6)
                        Image(systemName: picked == kind ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(picked == kind ? MaudeTheme.accentFinance : MaudeTheme.line)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(picked == kind ? MaudeTheme.accentFinance.opacity(0.5)
                                               : MaudeTheme.line2, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked == kind ? [.isSelected] : [])
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "A note, if you want").uppercased())
                .font(.maudeKicker(9)).tracking(1)
                .foregroundStyle(MaudeTheme.ink3)
            TextField(String(localized: "Conference in Berlin"), text: $note, axis: .vertical)
                .font(.lato(13.5))
                .foregroundStyle(MaudeTheme.ink)
                .lineLimit(2...4)
                .padding(12)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            Text("Your words, kept on this phone for you. Maude never reads them.")
                .font(.lato(11)).foregroundStyle(MaudeTheme.ink3)
        }
    }

    private var markButton: some View {
        Button {
            guard let kind = picked else { return }
            appState.markContext(kind, note: note)
            note = ""
            picked = nil
            dismiss()
        } label: {
            Text("Mark from today")
                .font(.lato(14.5, .bold))
                .foregroundStyle(picked == nil ? MaudeTheme.ink4 : MaudeTheme.invertFG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(picked == nil ? MaudeTheme.line2 : MaudeTheme.invertBG)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(picked == nil)
    }

    // MARK: - History

    private func historyRow(_ flag: ContextFlag) -> some View {
        HStack(spacing: 12) {
            Image(systemName: flag.kind.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(MaudeTheme.accentFinance)
                .frame(width: 28, height: 28)
                .background(MaudeTheme.accentFinance.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(flag.kind.label)
                    .font(.lato(13.5, .semibold)).foregroundStyle(MaudeTheme.ink)
                Text(rangeText(flag))
                    .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                if let n = flag.note, !n.isEmpty {
                    Text(n)
                        .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            Button {
                if confirmRemove == flag.id {
                    appState.removeContextFlag(flag.id)
                    confirmRemove = nil
                } else {
                    confirmRemove = flag.id
                }
            } label: {
                Text(confirmRemove == flag.id ? String(localized: "Remove?")
                                              : String(localized: "Remove"))
                    .font(.lato(12, .semibold))
                    .foregroundStyle(confirmRemove == flag.id ? MaudeTheme.rust : MaudeTheme.ink3)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func rangeText(_ flag: ContextFlag) -> String {
        let from = flag.startedOn.formatted(Self.dayFormat)
        guard let end = flag.endedOn else {
            return String(localized: "Since \(from) · still marked")
        }
        let to = end.formatted(Self.dayFormat)
        return from == to ? from : String(localized: "\(from) – \(to)")
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Marking never changes a reading, and it never raises an alert on its own — it can only quiet the comparison to your usual. Anything your devices flag for a doctor's eyes still reaches you.")
                .font(.lato(11)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }
}

#Preview {
    ContextFlagSheet()
        .environment(AppState())
}
