// HealthAccessDeclinedView.swift — UC-02 denied state · v02 2026-08-13
// Two ways in, and the copy tells them apart:
//   • `.skipped` — the citizen chose "Skip, explore with sample data".
//   • `.noReadings` — the inferred-denial cue: the read request completed and
//     every requested type came back empty.
//
// The second case deliberately does NOT say access was denied. HealthKit does
// not report read authorisation (`authorizationStatus` answers for writing
// only), so a refused read and a brand-new watch with nothing recorded yet look
// identical from inside the app. Accusing the system of denying access would be
// a claim we cannot make true — the calmer, accurate wording is used instead,
// and both remedies (open Health, or carry on) are offered either way.
import SwiftUI

struct HealthAccessDeclinedView: View {
    enum Reason { case skipped, noReadings }

    var reason: Reason = .skipped
    var onContinue: () -> Void

    private var kicker: String {
        switch reason {
        case .skipped:    return String(localized: "No access — that's fine")
        case .noReadings: return String(localized: "Nothing came through — yet")
        }
    }
    private var title: String {
        switch reason {
        case .skipped:
            return String(localized: "You skipped Apple Health. Liviqa still works.")
        case .noReadings:
            return String(localized: "No readings came through from Apple Health.")
        }
    }
    private var lead: String {
        switch reason {
        case .skipped:
            return String(localized: "For now you'll explore with sample data, clearly marked so you never mistake it for your own. Your real edition begins the moment you connect.")
        case .noReadings:
            return String(localized: "That can mean two things, and we can't tell them apart from here: either Liviqa wasn't given permission to read, or there's simply nothing recorded on this phone yet. Until readings arrive you'll see sample data, clearly marked so you never mistake it for your own.")
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
                        accent: LiviqaTheme.accentGlucose, compact: true)

                    Text(lead)
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
                        Text((reason == .noReadings
                              ? String(localized: "What arrives once readings do")
                              : String(localized: "What you're missing without it")).uppercased())
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
                OnbPrimaryButton(label: reason == .noReadings
                                 ? String(localized: "Open Apple Health to check")
                                 : String(localized: "Open Health settings to allow"),
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
