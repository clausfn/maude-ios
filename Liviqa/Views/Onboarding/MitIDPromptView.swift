// MitIDPromptView.swift — FR-ING-11 · single calm MitID prompt · v01 2026-08-12
// The A7.2 design replaces the 4-step simulated flow with ONE calm prompt
// ahead of the real linking use case (SundhedWebSessionView). The richer
// simulated AltID / e-Boks / iGrant / DfG wallet flows are untouched behind
// their Config flags. FR-ING-11 is being generalised (MitID = one eid_wallet
// instance) — no new country-specific branching lives here: this is a plain
// hand-off prompt whose copy names the provider it fronts.
import SwiftUI

/// Calm identity-confirmation prompt shown before handing the citizen to the
/// official provider. `content` is what "Continue to MitID" reveals (e.g.
/// `SundhedWebSessionView`); `onCancel` (optional) backs out.
struct MitIDPromptView<Content: View>: View {
    var onCancel: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @State private var proceeded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if proceeded {
            content()
        } else {
            prompt
        }
    }

    private var prompt: some View {
        VStack(spacing: 0) {
            // Header — back + title
            HStack(spacing: 8) {
                Button {
                    if let onCancel { onCancel() } else { dismiss() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back").font(.lato(13))
                    }
                    .foregroundStyle(LiviqaTheme.ink3)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .overlay {
                Text("Verify with MitID")
                    .font(.liviqaSerif(17, .bold, relativeTo: .headline))
                    .foregroundStyle(LiviqaTheme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            Spacer()

            VStack(spacing: 0) {
                // 72pt MitID-blue tile (provider colour, part of the mark)
                Text("ID")
                    .font(.liviqaSerif(22, .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color(hex: 0x0A5CB8))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)

                Text("Confirm it's really you.")
                    .font(.liviqaSerif(23, .bold, relativeTo: .title2))
                    .kerning(LiviqaTheme.Tracking.h1)
                    .foregroundStyle(LiviqaTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)

                Text("To link a national health service, Denmark's MitID confirms your identity. Liviqa never sees your MitID credentials — the check happens with the official provider, on this device.")
                    .font(.lato(14))
                    .lineSpacing(4)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 6)

                VStack(spacing: 8) {
                    checkRow(String(localized: "Your name is confirmed to the service"))
                    checkRow(String(localized: "Liviqa receives only a yes/no result"))
                    checkRow(String(localized: "You can unlink any time"))
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 26)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { proceeded = true }
                } label: {
                    Text("Continue to MitID")
                        .font(.lato(15, .bold))
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(LiviqaTheme.invertBG)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                Text("You'll return to Liviqa when you're done.")
                    .font(.lato(11))
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 20)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    private func checkRow(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LiviqaTheme.moss)
            Text(text)
                .font(.lato(12.5))
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
