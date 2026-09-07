// HealthKitPrimerView.swift — HealthKit permission primer · v03 2026-08-19
// A7.2 restyle to the designed anatomy (f-onboarding.jsx step 3): StepHead,
// six DOMAIN-COLOURED rows with fjord checkmarks, watch-glyph primary, quiet
// skip with sub-line, teal lock card. The REAL paths are unchanged: onConnect
// sets dataProviderKind=.healthKit + triggers the system read-authorization
// sheet (wired by the caller); skip routes to demo — never an error
// (FR-ING-02). Embedded as step 3 of OnboardingFlowView; skip surfaces
// HealthAccessDeclinedView there.
// Per-type purpose strings live on as the row sublabels (the design dropped
// them; the census asked to keep them reachable).
//
// v03 honesty fix (coverage-audit finding ①, closed under FR-ING-19): the lead
// claimed Maude reads "these — and only these" six domains while the app
// requests a wider set — untrue since PR-46's full capture, and impossible
// once the universal layer asks for the full public set. The lead now claims
// only what is true in every configuration: the six rows are the signals that
// power the daily surfaces, the CITIZEN chooses the exact read set on Apple's
// own sheet (which lists every requested type, honestly, by construction), and
// read-only + on-device + nothing-uploaded stay claimed because they stay true.
import SwiftUI

struct HealthKitPrimerView: View {
    /// First name captured upstream (nil → generic headline).
    var greetName: String? = nil
    /// True while the read authorization + first fetch are in flight. The flow
    /// waits for that answer before moving on, so it can tell "your data is
    /// here" from "nothing came through" (the inferred-denial cue) instead of
    /// dropping the citizen into a silently empty app.
    var isConnecting: Bool = false
    var onConnect: () -> Void
    var onSkip:    () -> Void

    // (SF symbol, domain colour, type label, purpose — kept as the sublabel)
    private var dataTypes: [(String, Color, String, String)] {
        [("bed.double.fill", MaudeTheme.accentSleep,
          String(localized: "Sleep"),
          String(localized: "To correlate sleep quality with meals, activity, and glucose.")),
         ("drop.fill", MaudeTheme.accentGlucose,
          String(localized: "Blood glucose"),
          String(localized: "To show your glucose trends and time-in-range patterns.")),
         ("waveform.path.ecg", MaudeTheme.accentRecovery,
          String(localized: "Heart-rate variability"),
          String(localized: "To read recovery against your own baseline.")),
         ("heart.fill", MaudeTheme.accentHeart,
          String(localized: "Resting heart rate"),
          String(localized: "To surface resting HR trends and flag unusual readings.")),
         ("figure.outdoor.cycle", MaudeTheme.accentRecovery,
          String(localized: "Workouts"),
          String(localized: "To detect movement patterns and correlate with other signals.")),
         ("figure.walk", MaudeTheme.accentRecovery,
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
                        lead: String(localized: "These six signals power your daily readout. You choose exactly what Maude may read on Apple's sheet — it's read-only, right here on your phone, and nothing is uploaded."),
                        accent: MaudeTheme.accentGlucose, compact: true)

                    // Six domain-coloured rows, each with a fjord checkmark
                    VStack(spacing: 0) {
                        ForEach(Array(dataTypes.enumerated()), id: \.offset) { idx, item in
                            let (symbol, color, label, purpose) = item
                            if idx > 0 { Divider().overlay(MaudeTheme.line) }
                            HStack(alignment: .center, spacing: 11) {
                                OnbIconChip(systemName: symbol, color: color, side: 26, corner: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(label)
                                        .font(.lato(14, .semibold))
                                        .foregroundStyle(MaudeTheme.ink)
                                    Text(purpose)
                                        .font(.lato(11))
                                        .lineSpacing(2)
                                        .foregroundStyle(MaudeTheme.ink3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(MaudeTheme.moss)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 9)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(MaudeTheme.line, lineWidth: 1))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                OnbPrimaryButton(
                    label: isConnecting
                        ? String(localized: "Reading Apple Health…")
                        : String(localized: "Connect Apple Health"),
                    icon: "applewatch",
                    action: { if !isConnecting { onConnect() } })
                    .opacity(isConnecting ? 0.6 : 1)
                    .allowsHitTesting(!isConnecting)
                    .accessibilityAddTraits(isConnecting ? [.updatesFrequently] : [])
                // The label used to promise sample data, which this button does
                // not (and must not) deliver on its own — the next screen makes
                // the offer explicitly, and entering is the citizen's act there.
                OnbQuietButton(label: String(localized: "Not now"),
                               sub: String(localized: "Connect any time in Settings — or look at a sample first"),
                               action: onSkip)
                    .disabled(isConnecting)
                // Teal lock card
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(MaudeTheme.moss.opacity(0.14))
                            .frame(width: 26, height: 26)
                        Image(systemName: "lock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MaudeTheme.moss)
                    }
                    .accessibilityHidden(true)
                    Text("Reading happens on-device. Nothing leaves without your permission.")
                        .font(.lato(12))
                        .lineSpacing(3)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MaudeTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(MaudeTheme.moss3, lineWidth: 1))
            }
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        // No own background — the onboarding flow provides the paper ground
        // and the per-step ambient glow behind this step.
    }
}
