// HealthAccessDeclinedView.swift — UC-02 denied state · v01 2026-08-12
// Surfaced when the Apple Health primer's skip is chosen (or the inferred-
// denial cue fires): "No access — that's fine". Sample data stays clearly
// marked; the real edition begins when the user connects.
import SwiftUI

struct HealthAccessDeclinedView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "No access — that's fine"),
                        title: String(localized: "You skipped Apple Health. Liviqa still works."),
                        lead: "",
                        accent: LiviqaTheme.accentGlucose, compact: true)

                    Text("For now you'll explore with sample data, clearly marked so you never mistake it for your own. Your real edition begins the moment you connect.")
                        .font(.lato(13))
                        .lineSpacing(4)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LiviqaTheme.moss2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(LiviqaTheme.moss3, lineWidth: 1))

                    // What you're missing without it
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(localized: "What you're missing without it").uppercased())
                            .font(.liviqaKicker(10))
                            .tracking(LiviqaTheme.Tracking.kicker)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        OnbBenefitRow(icon: "waveform.path.ecg",
                                      title: String(localized: "Your own baseline"),
                                      sub: String(localized: "Liviqa compares you to your normal, not averages — it needs your readings to learn it."))
                        OnbBenefitRow(icon: "drop.fill",
                                      title: String(localized: "Live glucose & sleep"),
                                      sub: String(localized: "The daily edition fills in as real data arrives."),
                                      chipColor: LiviqaTheme.accentGlucose,
                                      divider: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(LiviqaTheme.line, lineWidth: 1))
                    .padding(.top, 14)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                OnbPrimaryButton(label: String(localized: "Open Health settings to allow"),
                                 icon: "heart.fill") {
                    // Deep link into the Health app, where read access is granted
                    // (Health → profile → Privacy → Apps → Liviqa).
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                }
                OnbQuietButton(label: String(localized: "Continue with sample data"),
                               action: onContinue)
                HStack(spacing: 7) {
                    Image(systemName: "lock")
                        .font(.system(size: 11, weight: .medium))
                    Text("You can change this any time in Settings → My data.")
                        .font(.lato(11.5))
                }
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
}
