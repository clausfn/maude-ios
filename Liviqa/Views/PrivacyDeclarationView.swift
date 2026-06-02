// PrivacyDeclarationView.swift — One-time privacy statement · v01 2026-05-22
// Shown once at first launch, before AuthView.
// Design ref: Privacy_Onboarding_DesignBrief_v01_20260522.md (Screen 1 — Declaration)
import SwiftUI

struct PrivacyDeclarationView: View {
    var onDone: () -> Void

    // Declarations: (icon, statement, detail)
    private let declarations: [(String, String, String)] = [
        ("nosign",
         "No Facebook. No Google. No ad tracking.",
         "None of their code is in this app."),
        ("lock.fill",
         "No account required to use the app.",
         "Demo mode is always available, no sign-up needed."),
        ("iphone",
         "Processing happens on your device.",
         "Your health data does not leave your phone by default."),
        ("hand.raised.fill",
         "You decide what — if anything — you share.",
         "Every data connection is opt-in, per type, per recipient, revocable any time.")
    ]

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {

                // Mark
                LiviqaApertureMark(size: 44, reversed: false)
                    .padding(.top, 64)

                // Heading
                VStack(spacing: 6) {
                    Text("Before we begin")
                        .font(.system(size: 26, weight: .black))
                        .kerning(-0.5)
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("A few things you should know")
                        .font(.system(size: 14))
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 32)

                // Declaration rows
                VStack(spacing: 12) {
                    ForEach(declarations, id: \.1) { icon, statement, detail in
                        declarationRow(icon: icon, statement: statement, detail: detail)
                    }
                }
                .padding(.top, 36)
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                VStack(spacing: 16) {
                    Button(action: onDone) {
                        Text("Understood")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LiviqaTheme.ink)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("These principles apply to the entire app, always.")
                        .font(.system(size: 11))
                        .foregroundStyle(LiviqaTheme.ink4)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private func declarationRow(icon: String, statement: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {

            // Icon badge
            ZStack {
                Circle()
                    .fill(LiviqaTheme.moss2)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .frame(width: 38)

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(statement)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 4, y: 1)
    }
}
