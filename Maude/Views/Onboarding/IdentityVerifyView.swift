// IdentityVerifyView.swift — UC-20 (proposed) global identity & trial dedup · v01 2026-08-12
// Generic, extensible identification-method chooser for STUDY ENROLLMENT ONLY
// (GlobalIdentityVerify in b-extra.jsx). Methods are grouped by trust tier,
// not country; the DfG Private Uniqueness Check (Partisia MPC) is the
// preferred fallback and is pre-selected. Verification itself is stubbed —
// UI only; choosing a method hands the id back to the caller.
// Entry point: StudyConsentView's join flow. RTM row: UC-20 (qms/RTM.md).
import SwiftUI

// MARK: - Method table (local seed data — extensible, no country branching)

struct IDMethod: Identifiable, Equatable {
    let id: String
    let tier: String
    let label: String
    let trust: String
    let sub: String
    let icon: String      // SF Symbol
}

let ID_METHODS: [IDMethod] = [
    IDMethod(id: "eid_wallet", tier: "eID",
             label: String(localized: "National eID / digital-identity wallet"),
             trust: String(localized: "Government-verified"),
             sub: String(localized: "A government-issued digital-identity wallet (EUDI-wallet-compatible) — instant, strongest guarantee."),
             icon: "checkmark.seal"),
    IDMethod(id: "passport_bio", tier: "eID",
             label: String(localized: "Passport or government ID + face match"),
             trust: String(localized: "Government-verified"),
             sub: String(localized: "Scan a government-issued ID and match it to a live face check."),
             icon: "doc.text.viewfinder"),
    IDMethod(id: "bank_digital", tier: "eID",
             label: String(localized: "Bank-issued digital identity"),
             trust: String(localized: "Financially-verified"),
             sub: String(localized: "Many banks issue a reusable verified identity you already hold — works where a bank ID scheme exists."),
             icon: "building.columns"),
    IDMethod(id: "dfg_mpc", tier: "preferred fallback",
             label: String(localized: "Data for Good Private Uniqueness Check"),
             trust: String(localized: "Privacy-preserving · preferred"),
             sub: String(localized: "No eID or wallet needed. A one-time face scan becomes an encrypted fingerprint, split across independent computation nodes — no party ever holds a usable image."),
             icon: "clock.badge.checkmark"),
    IDMethod(id: "phone_device", tier: "floor",
             label: String(localized: "Phone number & device check"),
             trust: String(localized: "Basic"),
             sub: String(localized: "Confirms one enrollment per device and phone number. Used only when nothing above is available."),
             icon: "iphone"),
    IDMethod(id: "none", tier: "floor",
             label: String(localized: "None of these are available to me"),
             trust: "—",
             sub: String(localized: "You can still use Maude for yourself — only study/trial participation needs a uniqueness check."),
             icon: "xmark")
]

// MARK: - View

struct IdentityVerifyView: View {
    /// Called with the chosen method id, or nil for "Continue without verifying".
    var onContinue: (String?) -> Void
    var onBack: () -> Void

    @State private var open = false
    @State private var selected = "dfg_mpc"   // preferred fallback pre-selected

    private var method: IDMethod { ID_METHODS.first { $0.id == selected } ?? ID_METHODS[3] }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back").font(.lato(13))
                    }
                    .foregroundStyle(MaudeTheme.ink3)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .overlay {
                Text("Verify you're you")
                    .font(.maudeSerif(17, .bold, relativeTo: .headline))
                    .foregroundStyle(MaudeTheme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Verdict
                    HStack(alignment: .top, spacing: 12) {
                        OnbIconChip(systemName: "globe.europe.africa",
                                    color: MaudeTheme.accentRecovery, side: 34, corner: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "For study enrollment only").uppercased())
                                .font(.maudeKicker(10))
                                .tracking(MaudeTheme.Tracking.kicker)
                                .foregroundStyle(MaudeTheme.ink3)
                            Text("Choose how you'd like to verify.")
                                .font(.maudeSerif(20, .bold, relativeTo: .title3))
                                .foregroundStyle(MaudeTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    Text(String(localized: "Identification method").uppercased())
                        .font(.maudeKicker(10))
                        .tracking(MaudeTheme.Tracking.kicker)
                        .foregroundStyle(MaudeTheme.ink3)
                        .padding(.bottom, 8)

                    // Dropdown
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
                        } label: {
                            HStack(spacing: 12) {
                                OnbIconChip(systemName: method.icon,
                                            color: MaudeTheme.moss, side: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(method.label)
                                        .font(.lato(14, .bold))
                                        .foregroundStyle(MaudeTheme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(method.trust)
                                        .font(.lato(11, .semibold))
                                        .foregroundStyle(method.id == "dfg_mpc"
                                                         ? MaudeTheme.moss : MaudeTheme.ink3)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: open ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(MaudeTheme.ink3)
                            }
                            .padding(14)
                            .background(MaudeTheme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(MaudeTheme.moss, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(String(localized: "Opens the list of identification methods"))

                        if open {
                            VStack(spacing: 0) {
                                ForEach(Array(ID_METHODS.enumerated()), id: \.element.id) { i, m in
                                    if i > 0 { Divider().overlay(MaudeTheme.line) }
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selected = m.id
                                            open = false
                                        }
                                    } label: {
                                        HStack(alignment: .top, spacing: 11) {
                                            OnbIconChip(systemName: m.icon,
                                                        color: MaudeTheme.ink, side: 26, corner: 8)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 7) {
                                                    Text(m.label)
                                                        .font(.lato(13, .bold))
                                                        .foregroundStyle(MaudeTheme.ink)
                                                        .multilineTextAlignment(.leading)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    if m.id == "dfg_mpc" {
                                                        Text("PREFERRED")
                                                            .font(.maudeKicker(8.5))
                                                            .tracking(0.5)
                                                            .foregroundStyle(MaudeTheme.moss)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(MaudeTheme.moss2)
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                Text(m.sub)
                                                    .font(.lato(11))
                                                    .lineSpacing(3)
                                                    .foregroundStyle(MaudeTheme.ink2)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(m.id == "dfg_mpc"
                                                    ? MaudeTheme.moss2 : MaudeTheme.paper2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(MaudeTheme.line, lineWidth: 1))
                            .shadow(color: MaudeTheme.cardShadow, radius: 10, y: 6)
                            .padding(.top, 6)
                        }
                    }

                    Text("Methods are grouped by trust tier, not by country — pick whichever you actually have. If you have no eID or wallet, the Private Uniqueness Check is the strongest option and is pre-selected for you.")
                        .font(.lato(11))
                        .lineSpacing(3.5)
                        .foregroundStyle(MaudeTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    if selected == "dfg_mpc" {
                        mpcExplainer
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 8) {
                OnbPrimaryButton(label: selected == "none"
                                 ? String(localized: "Continue without verifying")
                                 : String(localized: "Continue with \(method.label)")) {
                    onContinue(selected == "none" ? nil : selected)
                }
                Button { onContinue(nil) } label: {
                    Text("Continue without verifying")
                        .font(.lato(13, .semibold))
                        .foregroundStyle(MaudeTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .opacity(selected == "none" ? 0 : 1)
                .disabled(selected == "none")
                Text("Used only to prevent duplicate entries in a study. It never becomes part of your health record.")
                    .font(.lato(11))
                    .lineSpacing(3)
                    .foregroundStyle(MaudeTheme.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
    }

    // "How the private check works" — 4 numbered steps + governance footer.
    private var mpcExplainer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MaudeTheme.moss2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "lock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MaudeTheme.moss)
                }
                .accessibilityHidden(true)
                Text("How the private check works")
                    .font(.lato(13.5, .bold))
                    .foregroundStyle(MaudeTheme.ink)
            }
            .padding(.bottom, 9)

            ForEach(Array(mpcSteps.enumerated()), id: \.offset) { i, t in
                HStack(alignment: .top, spacing: 9) {
                    Text("\(i + 1)")
                        .font(.lato(10, .bold))
                        .foregroundStyle(MaudeTheme.moss)
                        .frame(width: 18, height: 18)
                        .background(MaudeTheme.moss2)
                        .clipShape(Circle())
                    Text(t)
                        .font(.lato(12))
                        .lineSpacing(3.5)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            }

            Divider().overlay(MaudeTheme.line).padding(.top, 9)

            Text("Runs on a self-hosted multi-party-computation network — governed by the Data for Good Foundation, with no third-party server in the data path. Used only to prevent duplicate trial entries, never for identification elsewhere in Maude.")
                .font(.lato(11))
                .lineSpacing(3.5)
                .foregroundStyle(MaudeTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
        }
        .padding(15)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(MaudeTheme.moss3, lineWidth: 1))
    }

    private var mpcSteps: [String] {
        [String(localized: "Your device takes a brief face scan — the image never leaves your phone."),
         String(localized: "It's converted to an encrypted fingerprint and split into shares across independent computation nodes (secure multi-party computation)."),
         String(localized: "The nodes jointly answer “has this fingerprint enrolled before?” using zero-knowledge proofs — no single node, including Maude or Data for Good, ever sees a usable face."),
         String(localized: "Maude receives one signed result — unique or duplicate — issued and verified through a credential service run independently of any single party.")]
    }
}
