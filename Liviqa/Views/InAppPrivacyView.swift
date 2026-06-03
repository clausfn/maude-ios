// InAppPrivacyView.swift — Plain-language privacy information · v01 2026-05-22
import SwiftUI

struct InAppPrivacyView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("Last updated: May 2026")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink4)
                    Text("Plain language below. Full legal text at liviqa.com/privacy")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink3)
                }

                // Prose sections
                proseParagraph(
                    kicker: "WHAT WE COLLECT",
                    body: "Liviqa reads health data from Apple Health — glucose readings, heart rate, sleep, steps, and workouts. If you connect a calendar, only the total count of meetings per day is read, never titles or attendees. If you connect financial data, only daily totals and broad categories (dining, transport) are used — never individual merchants or amounts."
                )

                proseParagraph(
                    kicker: "WHERE IT LIVES",
                    body: "Everything stays on your device unless you choose to back up. Backups can go to your personal iCloud (end-to-end encrypted by Apple) or a sovereign European cloud (your choice). Nothing is sent to Liviqa's servers by default."
                )

                proseParagraph(
                    kicker: "WHO CAN SEE IT",
                    body: "Liviqa cannot see your data. There is no account that holds your health records on our servers. If you share a pattern summary with a care team member, that summary is generated on your device and sent directly — it passes through our infrastructure for delivery only, and is deleted after 48 hours. Every consent decision you make is recorded in an independent privacy log that you can inspect at any time."
                )

                proseParagraph(
                    kicker: "YOUR RIGHTS",
                    body: "You have the right to export all your Liviqa data at any time from Settings → My Data → Export. You have the right to delete all local data from Settings → Delete all my data. You have the right to withdraw any sharing grant from Settings → Consent & Sharing. These rights exist regardless of what you have previously agreed to."
                )

                // MDR disclaimer card
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMPORTANT")
                        .font(.liviqaKicker(10))
                        .tracking(1.2)
                        .foregroundStyle(LiviqaTheme.amber)

                    Text("Liviqa is a personal wellness application, not a medical device. It does not diagnose, treat, monitor, or manage any medical condition. Patterns are generated from your own data for your own awareness. Always consult a qualified healthcare professional before changing your care, medication, or treatment.")
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.amber2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LiviqaTheme.amber.opacity(0.4), lineWidth: 0.5)
                )

                // Links
                VStack(alignment: .leading, spacing: 12) {
                    linkRow(label: "Full legal privacy policy")
                    linkRow(label: "Open Source Licences")
                }

                // Footer
                Text("Questions? privacy@liviqa.com")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Privacy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: — Helpers

    private func proseParagraph(kicker: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker)
                .font(.liviqaKicker(10))
                .tracking(1.0)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(body)
                .font(.lato(14))
                .foregroundStyle(LiviqaTheme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func linkRow(label: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.moss)
            Image(systemName: "arrow.up.right")
                .font(.lato(11, .medium))
                .foregroundStyle(LiviqaTheme.moss)
        }
    }
}

// MARK: — Preview

#Preview {
    NavigationStack {
        InAppPrivacyView()
    }
}
