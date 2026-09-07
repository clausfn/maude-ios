// CreateGrantView.swift — UC-11 create a consent grant · v01 2026-08-12
// A7.2 anatomy verbatim from b-sharing.jsx ScrCreateGrant: verdict ("You decide
// who, what, how long" / "Who should this share go to?") → recipient-type radio
// list → "Summaries only · Locked on" plate → "Choose what to share" → governed
// footer. Presented as a sheet from WalletView ("Share with someone new").
//
// SAFETY RAILS:
//  • The "Summaries only / Raw readings can never be added to a grant" plate is
//    the FR-SHARE-02 derived-only rail rendered as UI — NON-INTERACTIVE and
//    always on. (The package's ScrSharePattern "Every reading" mode contradicts
//    this plate; that mode is under an OPEN QMS ruling and is NOT built —
//    qms/RISK.md Area ⑥.)
//  • "An employer or insurer" stays SOON + disabled — no live grant path exists
//    for that recipient type, so the row must not look actionable.
// Step 2 reuses the Share-a-pattern form (ShareWithClinicianView) for
// clinician/coach; a research choice routes to the Research hub instead.
import SwiftUI

struct CreateGrantView: View {
    var onDismiss: () -> Void

    private enum GrantRecipientChoice: String, CaseIterable, Identifiable {
        case clinician, coach, research, employerInsurer
        var id: String { rawValue }

        var title: String {
            switch self {
            case .clinician:       return String(localized: "A clinician or nurse")
            case .coach:           return String(localized: "A coach or trainer")
            case .research:        return String(localized: "A research study")
            case .employerInsurer: return String(localized: "An employer or insurer")
            }
        }
        var subtitle: String {
            switch self {
            case .clinician:       return String(localized: "A named person on your care team sees a summary.")
            case .coach:           return String(localized: "Share activity & recovery patterns with a coach.")
            case .research:        return String(localized: "Grouped, anonymous — you never appear alone.")
            case .employerInsurer: return String(localized: "Only via a verified, time-boxed request.")
            }
        }
        /// No live grant path — must stay visibly not-yet (honest UI).
        var soon: Bool { self == .employerInsurer }
        /// Backend recipient-role filter for the share form (step 2).
        var roleFilter: RecipientRole? {
            switch self {
            case .clinician: return .clinicalNurse
            case .coach:     return .healthCoach
            default:         return nil
            }
        }
    }

    private enum Phase { case chooser, share, research }
    @State private var phase: Phase = .chooser
    @State private var choice: GrantRecipientChoice = .clinician

    var body: some View {
        switch phase {
        case .chooser:
            chooser
        case .share:
            // Step 2 — the Share-a-pattern form, filtered to the chosen role.
            ShareWithClinicianView(nudge: nil, onDismiss: onDismiss,
                                   roleFilter: choice.roleFilter)
        case .research:
            NavigationStack {
                ResearchHubView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { onDismiss() }
                                .font(.lato(15))
                                .foregroundStyle(MaudeTheme.ink2)
                        }
                    }
            }
        }
    }

    // MARK: - Phase 1: who should this share go to?

    private var chooser: some View {
        VStack(spacing: 0) {
            // Header — Cancel · New grant
            HStack {
                Button { onDismiss() } label: {
                    Text("Cancel").font(.lato(15)).foregroundStyle(MaudeTheme.ink3)
                }
                Spacer()
                Text("New grant")
                    .font(.maudeSerif(16))
                    .foregroundStyle(MaudeTheme.ink)
                Spacer()
                // Balance the header
                Text("Cancel").font(.lato(15)).opacity(0)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Verdict
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Image(systemName: "key")
                                .font(.lato(13, .semibold))
                                .foregroundStyle(MaudeTheme.accentRecovery)
                            Text("You decide who, what, how long".uppercased())
                                .font(.maudeKicker(10)).tracking(1.2)
                                .foregroundStyle(MaudeTheme.ink3)
                        }
                        Text("Who should this share go to?")
                            .font(.maudeSerif(22)).kerning(-0.2)
                            .foregroundStyle(MaudeTheme.ink)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MaudeTheme.accentRecovery)
                            .frame(width: 44, height: 3)
                            .padding(.top, 4)
                    }
                    .padding(.top, 6)

                    Text("Recipient type".uppercased())
                        .font(.maudeKicker(10)).tracking(1.2)
                        .foregroundStyle(MaudeTheme.ink3)

                    VStack(spacing: 8) {
                        ForEach(GrantRecipientChoice.allCases) { c in
                            typeRow(c)
                        }
                    }

                    // The summaries-only rail as UI — non-interactive, always on.
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Summaries only")
                                .font(.lato(13.5, .bold))
                                .foregroundStyle(MaudeTheme.ink)
                            Text("Raw readings can never be added to a grant")
                                .font(.lato(11.5))
                                .foregroundStyle(MaudeTheme.ink3)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill").font(.lato(11, .semibold))
                            Text("Locked on").font(.lato(11, .bold))
                        }
                        .foregroundStyle(MaudeTheme.moss)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(MaudeTheme.line, lineWidth: 1))

                    // CTA
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = choice == .research ? .research : .share
                        }
                    } label: {
                        Text("Choose what to share")
                            .font(.lato(15, .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MaudeTheme.moss)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(choice.soon)
                    .opacity(choice.soon ? 0.5 : 1)
                    .padding(.top, 4)

                    Text("You'll choose the area and the time period next, then get a receipt you can keep. Every grant is governed by the Data for Good Foundation.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
    }

    private func typeRow(_ c: GrantRecipientChoice) -> some View {
        let on = choice == c
        return Button {
            guard !c.soon else { return }
            choice = c
        } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle()
                        .stroke(on ? MaudeTheme.moss : MaudeTheme.ink4, lineWidth: 1.5)
                        .background(Circle().fill(on ? MaudeTheme.moss : Color.clear))
                        .frame(width: 20, height: 20)
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(c.title)
                            .font(.lato(14, .bold))
                            .foregroundStyle(MaudeTheme.ink)
                        if c.soon {
                            Text("SOON")
                                .font(.maudeKicker(9)).tracking(0.6)
                                .foregroundStyle(MaudeTheme.brass)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(MaudeTheme.brass2)
                                .clipShape(Capsule())
                        }
                    }
                    Text(c.subtitle)
                        .font(.lato(12)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(on ? MaudeTheme.moss2.opacity(0.5) : MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .stroke(on ? MaudeTheme.moss : MaudeTheme.line, lineWidth: on ? 1.5 : 1))
            .opacity(c.soon ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(c.soon)
        .accessibilityLabel(c.soon ? Text("\(c.title) — coming soon") : Text(c.title))
    }
}

#Preview {
    CreateGrantView(onDismiss: {})
        .environment(AppState())
}
