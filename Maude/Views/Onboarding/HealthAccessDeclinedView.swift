// HealthAccessDeclinedView.swift — UC-02 denied state · v03 2026-08-14
// Two ways in, and the copy tells them apart:
//   • `.skipped` — the citizen chose "Not now" on the Apple Health step.
//   • `.noReadings` — the inferred-denial cue: the read request completed and
//     every requested type came back empty.
//
// The second case deliberately does NOT say access was denied. HealthKit does
// not report read authorisation (`authorizationStatus` answers for writing
// only), so a refused read and a brand-new watch with nothing recorded yet look
// identical from inside the app. Accusing the system of denying access would be
// a claim we cannot make true — the calmer, accurate wording is used instead,
// and both remedies (open Health, or carry on) are offered either way.
//
// v03 (FR-SMP-05): this screen used to PROMISE sample data — "for now you'll
// explore with sample data" — while doing nothing to turn it on. Both halves
// were wrong: the app has no business deciding to show a person invented
// numbers, and the sentence was not true of the running app. Sample mode is now
// an OFFER with its own button, and carrying on without it is the other button.
// Whichever they choose, the app tells the truth about what they will see.
import SwiftUI

struct HealthAccessDeclinedView: View {
    enum Reason { case skipped, noReadings }

    var reason: Reason = .skipped
    /// Carry on with no sample: honest empty/calibrating screens until readings
    /// arrive. The default path — nothing is entered on the citizen's behalf.
    var onContinue: () -> Void
    /// The citizen explicitly asks to look at a sample (FR-SMP-05, the ONE
    /// onboarding door into sample mode).
    var onExploreSample: () -> Void = { }
    /// The synthetic record is being built (a moment, off the main actor).
    var isPreparingSample: Bool = false

    private var kicker: String {
        switch reason {
        case .skipped:    return String(localized: "No access — that's fine")
        case .noReadings: return String(localized: "Nothing came through — yet")
        }
    }
    private var title: String {
        switch reason {
        case .skipped:
            return String(localized: "You skipped Apple Health. Maude still works.")
        case .noReadings:
            return String(localized: "No readings came through from Apple Health.")
        }
    }
    private var lead: String {
        switch reason {
        case .skipped:
            return String(localized: "Maude will stay quiet until readings arrive — empty screens rather than numbers nobody measured. Your real edition begins the moment you connect.")
        case .noReadings:
            return String(localized: "That can mean two things, and we can't tell them apart from here: either Maude wasn't given permission to read, or there's simply nothing recorded on this phone yet. Until readings arrive the screens stay empty — we won't fill them with numbers nobody measured.")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: kicker,
                        title: title,
                        lead: "",
                        accent: MaudeTheme.accentGlucose, compact: true)

                    Text(lead)
                        .font(.lato(13))
                        .lineSpacing(4)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MaudeTheme.moss2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(MaudeTheme.moss3, lineWidth: 1))

                    // What you're missing without it
                    VStack(alignment: .leading, spacing: 0) {
                        Text((reason == .noReadings
                              ? String(localized: "What arrives once readings do")
                              : String(localized: "What you're missing without it")).uppercased())
                            .font(.maudeKicker(10))
                            .tracking(MaudeTheme.Tracking.kicker)
                            .foregroundStyle(MaudeTheme.ink3)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        OnbBenefitRow(icon: "waveform.path.ecg",
                                      title: String(localized: "Your own baseline"),
                                      sub: String(localized: "Maude compares you to your normal, not averages — it needs your readings to learn it."))
                        OnbBenefitRow(icon: "drop.fill",
                                      title: String(localized: "Live glucose & sleep"),
                                      sub: String(localized: "The daily edition fills in as real data arrives."),
                                      chipColor: MaudeTheme.accentGlucose,
                                      divider: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(MaudeTheme.line, lineWidth: 1))
                    .padding(.top, 14)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 10) {
                OnbPrimaryButton(label: reason == .noReadings
                                 ? String(localized: "Open Apple Health to check")
                                 : String(localized: "Open Health settings to allow"),
                                 icon: "heart.fill") {
                    // Deep link into the Health app, where read access is granted
                    // (Health → profile → Privacy → Apps → Maude).
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                }
                // The offer, stated as an offer. Made-up numbers, said out loud
                // in the label itself — never "continue", which reads as the
                // neutral way forward.
                OnbQuietButton(label: isPreparingSample
                               ? String(localized: "Preparing the sample…")
                               : String(localized: "Explore with sample data (made up)"),
                               action: onExploreSample)
                    .disabled(isPreparingSample)
                OnbQuietButton(label: String(localized: "Continue without it"),
                               action: onContinue)
                HStack(spacing: 7) {
                    Image(systemName: "lock")
                        .font(.system(size: 11, weight: .medium))
                    Text("Sample data is marked on every screen and can be left any time in Settings → My data.")
                        .font(.lato(11.5))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(MaudeTheme.ink3)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
}
