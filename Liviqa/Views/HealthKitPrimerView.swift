// HealthKitPrimerView.swift — HealthKit permission primer · v02 2026-08-12
// A7.2 restyle to the designed anatomy (f-onboarding.jsx step 3): StepHead,
// six DOMAIN-COLOURED rows with fjord checkmarks, watch-glyph primary, quiet
// skip with sub-line, teal lock card. The REAL paths are unchanged: onConnect
// sets dataProviderKind=.healthKit + triggers the system read-authorization
// sheet (wired by the caller); skip routes to demo — never an error
// (FR-ING-02). Embedded as step 3 of OnboardingFlowView; skip surfaces
// HealthAccessDeclinedView there.
// Per-type purpose strings live on as the row sublabels (the design dropped
// them; the census asked to keep them reachable).
import SwiftUI

struct HealthKitPrimerView: View {
    /// First name captured upstream (nil → generic headline).
    var greetName: String? = nil
    var onConnect: () -> Void
    var onSkip:    () -> Void

    // (SF symbol, domain colour, type label, purpose — kept as the sublabel)
    private var dataTypes: [(String, Color, String, String)] {
        [("bed.double.fill", LiviqaTheme.accentSleep,
          String(localized: "Sleep"),
          String(localized: "To correlate sleep quality with meals, activity, and glucose.")),
         ("drop.fill", LiviqaTheme.accentGlucose,
          String(localized: "Blood glucose"),
          String(localized: "To show your glucose trends and time-in-range patterns.")),
         ("waveform.path.ecg", LiviqaTheme.accentRecovery,
          String(localized: "Heart-rate variability"),
          String(localized: "To read recovery against your own baseline.")),
         ("heart.fill", LiviqaTheme.accentHeart,
          String(localized: "Resting heart rate"),
          String(localized: "To surface resting HR trends and flag unusual readings.")),
         ("figure.outdoor.cycle", LiviqaTheme.accentRecovery,
          String(localized: "Workouts"),
          String(localized: "To detect movement patterns and correlate with other signals.")),
         ("figure.walk", LiviqaTheme.accentRecovery,
          String(localized: "Steps & active energy"),
          String(localized: "To see daily activity next to sleep and glucose."))]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "Step 3 of 9"),
                        title: greetName.map { String(localized: "Connect Apple Health, \($0).") }
                            ?? String(localized: "Connect Apple Health."),
                        lead: String(localized: "Liviqa reads these — and only these — right here on your phone. It's read-only, and nothing is uploaded."),
                        accent: LiviqaTheme.accentGlucose, compact: true)

                    // Six domain-coloured rows, each with a fjord checkmark
                    VStack(spacing: 0) {
                        ForEach(Array(dataTypes.enumerated()), id: \.offset) { idx, item in
                            let (symbol, color, label, purpose) = item
                            if idx > 0 { Divider().overlay(LiviqaTheme.line) }
                            HStack(alignment: .center, spacing: 11) {
                                OnbIconChip(systemName: symbol, color: color, side: 26, corner: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(label)
                                        .font(.lato(14, .semibold))
                                        .foregroundStyle(LiviqaTheme.ink)
                                    Text(purpose)
                                        .font(.lato(11))
                                        .lineSpacing(2)
                                        .foregroundStyle(LiviqaTheme.ink3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LiviqaTheme.moss)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 9)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(LiviqaTheme.line, lineWidth: 1))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                OnbPrimaryButton(label: String(localized: "Connect Apple Health"),
                                 icon: "applewatch", action: onConnect)
                OnbQuietButton(label: String(localized: "Skip — explore with sample data"),
                               sub: String(localized: "You can connect real data any time in Settings"),
                               action: onSkip)
                // Teal lock card
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LiviqaTheme.moss.opacity(0.14))
                            .frame(width: 26, height: 26)
                        Image(systemName: "lock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LiviqaTheme.moss)
                    }
                    .accessibilityHidden(true)
                    Text("Reading happens on-device. Nothing leaves without your permission.")
                        .font(.lato(12))
                        .lineSpacing(3)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(LiviqaTheme.moss3, lineWidth: 1))
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        // No own background — the onboarding flow provides the paper ground
        // and the per-step ambient glow behind this step.
    }
}
