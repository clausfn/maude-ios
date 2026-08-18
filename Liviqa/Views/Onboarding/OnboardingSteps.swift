// OnboardingSteps.swift — A7.2 onboarding step content · v01 2026-08-12
// Steps 1, 4–9 of the designed flow (f-onboarding.jsx + census notes), plus
// the health-literacy step. Sign-in (AuthView), Apple Health primer
// (HealthKitPrimerView), declined (HealthAccessDeclinedView) and app lock
// (AppLockSetupView) live in their own files.
import SwiftUI

// MARK: - Shared building blocks

/// Kicker + serif title + accent rule + lead (the handoff StepHead).
struct OnbStepHead: View {
    let kicker: String
    let title: String
    let lead: String
    var accent: Color = LiviqaTheme.moss
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker.uppercased())
                .font(.liviqaKicker(10.5))
                .tracking(LiviqaTheme.Tracking.kicker)
                .foregroundStyle(accent)
            Text(title)
                .font(.liviqaSerif(compact ? 24 : 27, .bold, relativeTo: .title2))
                .kerning(LiviqaTheme.Tracking.h1)
                .foregroundStyle(LiviqaTheme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 44, height: 3)
                .padding(.top, compact ? 10 : 12)
                .padding(.bottom, compact ? 8 : 10)
                .accessibilityHidden(true)
            Text(lead)
                .font(.lato(14))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, compact ? 4 : 18)
        .padding(.bottom, compact ? 8 : 12)
    }
}

/// Solid icon chip (A7.2 pattern 1 — adjacent label carries the meaning).
struct OnbIconChip: View {
    let systemName: String
    var color: Color = LiviqaTheme.moss
    var side: CGFloat = 30
    var corner: CGFloat = 9

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(color)
            Image(systemName: systemName)
                .font(.system(size: side * 0.5, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// Icon + bold title + sub, for stacked benefit rows inside a white card.
struct OnbBenefitRow: View {
    let icon: String
    let title: String
    let sub: String
    var chipColor: Color = LiviqaTheme.moss
    var divider = false

    var body: some View {
        VStack(spacing: 0) {
            if divider { Divider().overlay(LiviqaTheme.line) }
            HStack(alignment: .top, spacing: 12) {
                OnbIconChip(systemName: icon, color: chipColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.lato(13.5, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(sub)
                        .font(.lato(12))
                        .lineSpacing(3)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
        }
    }
}

/// The primary CTA. ONE filled treatment per edition (`primaryFill`): fjord
/// teal + white in Morning, warm off-white + marine at night — a mid-teal slab
/// on marine reads as disabled (design-QA 2026-08-13).
struct OnbPrimaryButton: View {
    let label: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .medium))
                }
                Text(label).font(.lato(15, .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LiviqaTheme.primaryFill)
            .foregroundStyle(LiviqaTheme.primaryLabel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: LiviqaTheme.primaryGlow, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }
}

/// Quiet secondary CTA, with an optional sub-line.
struct OnbQuietButton: View {
    let label: String
    var sub: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label).font(.lato(14.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                if let sub {
                    Text(sub).font(.lato(11.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, sub == nil ? 13 : 11)
            .background(LiviqaTheme.ink.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// White card wrapper for stacked rows.
struct OnbCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))
    }
}

// MARK: - Step 1 · Why Liviqa (2 sub-pages)
//
// Page 2 is the EXPECTATION page (FR-SMP-06, CN directive 2026-08-13: "make it
// clear in the opening instructions that Liviqa is targeted for people
// measuring their health and lifestyle relevant data").
//
// It exists because of a specific failure: a tester installs the app on a fresh
// phone, sees empty screens, and concludes it is broken — when it is simply new
// and has nothing of theirs to read yet. The honest fix is to say, before the
// first screen, who the app is for and what the first fortnight actually looks
// like. Every claim on that page is checked against the running code:
//
//   • "three days" — the engine's personal baseline needs ≥3 days of a metric
//     before it will compare anything (`Baseline.from`, NudgeModel.swift).
//   • "about two weeks" — the learned "your usual" band needs ≥5 days
//     (BaselineDeriver) and the app's steady-state window is 30 days, so two
//     weeks is when the band stops moving much. It is stated as "settles", not
//     as a finish line, because it never finishes.
//   • "nothing happens on day one" — literally true: with no readings the app
//     shows its calibrating state and no insight.
//
// No promise here that the app cannot keep, and no hype.

struct WhyLiviqaStep: View {
    var accent: Color
    var onContinue: () -> Void

    @State private var sub = 0

    var body: some View {
        VStack(spacing: 0) {
            // 2-dot sub-pager
            HStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { d in
                    Circle()
                        .fill(d == sub ? LiviqaTheme.moss : LiviqaTheme.ink.opacity(0.22))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Page \(sub + 1) of 2"))

            ScrollView {
                if sub == 0 { pageOne } else { pageTwo }
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: sub == 0
                             ? String(localized: "Show me")
                             : String(localized: "That's fair — carry on")) {
                if sub == 0 {
                    withAnimation(.easeInOut(duration: 0.25)) { sub = 1 }
                } else {
                    onContinue()
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private var pageOne: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnbStepHead(
                kicker: String(localized: "Step 1 of 9"),
                title: String(localized: "Apple Health keeps your numbers. Liviqa tells you what they mean."),
                lead: String(localized: "Your phone already collects the readings. Liviqa reads them here on the device and gives you one plain answer a day — measured against your own normal, not a population average."),
                accent: accent, compact: true)

            OnbCard {
                OnbBenefitRow(icon: "doc.plaintext",
                              title: String(localized: "One answer, not forty charts"),
                              sub: String(localized: "“You're having a steady week.” Then the numbers, if you want them."))
                OnbBenefitRow(icon: "waveform.path.ecg",
                              title: String(localized: "Compared to your own normal"),
                              sub: String(localized: "Apple Health shows the value. Liviqa learns what is usual for you, and tells you when it moves."),
                              divider: true)
                OnbBenefitRow(icon: "drop.fill",
                              title: String(localized: "Real depth, one tap down"),
                              sub: String(localized: "Glucose in mmol/L, time in range, GMI — the clinical detail your nurse asks about."),
                              divider: true)
                OnbBenefitRow(icon: "lock.shield",
                              title: String(localized: "It stays on this phone"),
                              sub: String(localized: "The analysis runs on the device. Nothing is sent anywhere unless you choose to share it."),
                              divider: true)
            }

            Text("Free to use, just for yourself. You don't need an account to start — the next steps are only setup.")
                .font(.lato(12))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .padding(.horizontal, 26)
    }

    /// Who it is for, and what the first two weeks really look like.
    private var pageTwo: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnbStepHead(
                kicker: String(localized: "Before you start"),
                title: String(localized: "Liviqa is for people who already measure something."),
                lead: String(localized: "A watch, a ring, a continuous glucose sensor, a scale — anything that records you day after day. Liviqa has no sensors of its own: it reads what your devices already write into Apple Health. Without at least one of them there is nothing for it to read, and it will say so rather than make something up."),
                accent: accent, compact: true)

            OnbCard {
                OnbBenefitRow(icon: "applewatch",
                              title: String(localized: "A watch or a ring"),
                              sub: String(localized: "Sleep, resting heart rate, heart-rate variability, steps."))
                OnbBenefitRow(icon: "drop.fill",
                              title: String(localized: "A glucose sensor, if you use one"),
                              sub: String(localized: "Time in range and GMI in mmol/L — the depth this app was built for."),
                              chipColor: LiviqaTheme.accentGlucose,
                              divider: true)
                OnbBenefitRow(icon: "scalemass",
                              title: String(localized: "A scale, a blood-pressure cuff, a lab result"),
                              sub: String(localized: "Anything that lands in Apple Health, plus letters and results you import yourself."),
                              chipColor: LiviqaTheme.accentBody,
                              divider: true)
            }

            // What the first two weeks look like — the screen that stops a new
            // tester concluding the app is broken when it is simply new.
            VStack(alignment: .leading, spacing: 0) {
                Text("THE FIRST TWO WEEKS")
                    .font(.liviqaKicker(10))
                    .tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.moss)
                    .padding(.bottom, 8)

                expectationRow(day: String(localized: "Day 1"),
                               text: String(localized: "Almost nothing happens. Liviqa reads what is already on your phone and starts learning your normal. Empty is the honest answer, so empty is what you get."))
                expectationRow(day: String(localized: "~Day 3"),
                               text: String(localized: "Enough of your own days to compare against — the first insight can appear. It may still be quiet: a calm week has nothing worth saying."))
                expectationRow(day: String(localized: "~2 weeks"),
                               text: String(localized: "Your usual settles down and stops shifting under every new reading. From here the app is comparing today with a you it actually knows."),
                               last: true)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(LiviqaTheme.moss3, lineWidth: 1))

            Text("Liviqa will never fill a quiet week with numbers nobody measured. If you want to see what it looks like with data in it before yours arrives, you can turn on clearly-marked sample data at the Apple Health step.")
                .font(.lato(12))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 26)
    }

    private func expectationRow(day: String, text: String, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                Circle()
                    .fill(LiviqaTheme.moss)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)
                if !last {
                    Rectangle()
                        .fill(LiviqaTheme.moss.opacity(0.3))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(day)
                    .font(.liviqaMono(11.5))
                    .fontWeight(.bold)
                    .foregroundStyle(LiviqaTheme.moss)
                Text(text)
                    .font(.lato(12.5))
                    .lineSpacing(3.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, last ? 0 : 12)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Step 4 · Data for Good governance (2 sub-pages)

struct DfGGovernanceStep: View {
    var accent: Color
    var onContinue: () -> Void

    @State private var sub = 0
    @State private var showLearnMore = false
    // Opt-in research consents — same persisted keys as the legacy screen.
    @AppStorage("consentCohortDiscovery")      private var cohortDiscovery      = false
    @AppStorage("consentResearchDiscoverable") private var researchDiscoverable = false

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "Step 4 of 9").uppercased())
                .font(.liviqaKicker(10.5))
                .tracking(LiviqaTheme.Tracking.kicker)
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 26)
                .padding(.top, 4)

            // 2-dot sub-pager
            HStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { d in
                    Circle()
                        .fill(d == sub ? LiviqaTheme.moss : LiviqaTheme.ink.opacity(0.22))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Page \(sub + 1) of 2"))

            ScrollView {
                if sub == 0 { pageOne } else { pageTwo }
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: String(localized: "Continue")) {
                if sub == 0 {
                    withAnimation(.easeInOut(duration: 0.25)) { sub = 1 }
                } else {
                    onContinue()
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showLearnMore) {
            DfGLearnMoreSheet(isPresented: $showLearnMore)
        }
    }

    private var pageOne: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Centered DfG logo card
            HStack {
                Spacer()
                Image("dfg-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 46)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))
                    .accessibilityLabel(String(localized: "Data for Good Foundation"))
                Spacer()
            }
            .padding(.bottom, 14)

            Text("DATA FOR GOOD FOUNDATION")
                .font(.liviqaKicker(10.5))
                .tracking(2.2)
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("An independent body that works for you — not for institutions.")
                .font(.liviqaSerif(21, .bold, relativeTo: .title3))
                .kerning(LiviqaTheme.Tracking.h1)
                .foregroundStyle(LiviqaTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Every time anyone requests your health data, a neutral record is created. Not by Liviqa. Not by the requester. By a foundation that answers to you — and represents your interests in the data economy.")
                .font(.lato(13.5))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            ExpandableNote(
                summary: "You can't be quietly overridden",
                detail: "Every access request is logged. Every refusal is logged. You can inspect the full record at any time."
            )
            .padding(.top, 14)

            Text("CONTRIBUTE TO RESEARCH — OPTIONAL")
                .font(.liviqaKicker(10))
                .tracking(2)
                .foregroundStyle(LiviqaTheme.moss)
                .padding(.top, 18)
                .padding(.bottom, 9)

            ConsentCheckRow(
                isOn: $cohortDiscovery,
                title: "Allow me to be included in anonymous cohort discovery",
                detail: "Approved research can be told an anonymous person like you exists in a cohort — never your name, never raw data."
            )
            .padding(.bottom, 8)
            ConsentCheckRow(
                isOn: $researchDiscoverable,
                title: "Allow me and my data to be discovered for anonymous research",
                detail: "A researcher can ask you — anonymously — to join a study. You still approve every share, and can withdraw any time."
            )

            Text("Off by default. You can change these any time in Privacy.")
                .font(.lato(11))
                .foregroundStyle(LiviqaTheme.ink4)
                .padding(.top, 6)
                .padding(.bottom, 14)

            // What's kept, anonymously — data-minimisation card
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("What's kept, anonymously")
                        .font(.lato(13, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                }
                .padding(.bottom, 9)

                ForEach(Array(keptBullets.enumerated()), id: \.offset) { _, t in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(LiviqaTheme.moss)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                            .accessibilityHidden(true)
                        Text(t)
                            .font(.lato(12))
                            .lineSpacing(3.5)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 5)
                }

                Divider().overlay(LiviqaTheme.moss3).padding(.top, 8)

                Text("Before any researcher can see it, your data is always grouped with at least 4 other people — you never show up alone.")
                    .font(.lato(11.5))
                    .lineSpacing(3.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))

            Button { showLearnMore = true } label: {
                Text("What is the Data for Good Foundation?")
                    .font(.lato(12))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .underline()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 26)
    }

    private var keptBullets: [String] {
        [String(localized: "An anonymous cohort tag — never your name, email, or device ID"),
         String(localized: "Weekly averages per signal — e.g. % time in glucose range, average HRV, sleep duration — never your raw minute-by-minute readings"),
         String(localized: "A broad age band and region (e.g. ‘30–39, Denmark’) — never your birthdate or address"),
         String(localized: "A condition category, if relevant to the study (e.g. ‘type 1 diabetes’) — never your notes or diagnosis details")]
    }

    private var pageTwo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { sub = 0 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text("Back").font(.lato(13, .semibold))
                }
                .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            HStack {
                Spacer()
                ZStack {
                    Circle().fill(LiviqaTheme.moss2).frame(width: 60, height: 60)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                .accessibilityHidden(true)
                Spacer()
            }
            .padding(.bottom, 14)

            Text("YOUR PRIVACY RECORD")
                .font(.liviqaKicker(10.5))
                .tracking(2.2)
                .foregroundStyle(LiviqaTheme.moss)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Text("Every decision. Permanently recorded.")
                .font(.liviqaSerif(21, .bold, relativeTo: .title3))
                .kerning(LiviqaTheme.Tracking.h1)
                .foregroundStyle(LiviqaTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Each time you grant or withdraw access, that decision is written to an independent record. It cannot be edited, deleted, or backdated — by anyone, including Liviqa.")
                .font(.lato(13.5))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            ExpandableNote(
                summary: "What if someone disputes it?",
                detail: "If a requester claims they were given access you never approved, the record will show otherwise. If you change your mind and withdraw consent, that withdrawal is also on record."
            )
            .padding(.top, 14)

            VStack(spacing: 9) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(LiviqaTheme.moss)
                    .accessibilityHidden(true)
                Text("Your record starts empty.")
                    .font(.lato(14, .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text("Each grant or refusal you make appears here — permanently, and in order.")
                    .font(.lato(12))
                    .lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
            .padding(.top, 18)

            Text("No one, including Liviqa, can alter this record.")
                .font(.lato(11.5))
                .italic()
                .foregroundStyle(LiviqaTheme.ink4)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 26)
    }
}

// MARK: - Step 5 · Name capture

struct NameCaptureStep: View {
    var accent: Color
    @Binding var firstName: String
    @Binding var lastName: String
    var onContinue: () -> Void

    private var previewName: String? {
        let n = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? nil : n
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "Step 5 of 9"),
                        title: String(localized: "What should Liviqa call you?"),
                        lead: String(localized: "Just a first name is enough. It's how your daily edition greets you — and it stays on this device."),
                        accent: accent)

                    HStack(spacing: 10) {
                        Image(systemName: "person")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(accent)
                            .accessibilityHidden(true)
                        TextField(String(localized: "First name"), text: $firstName)
                            .font(.lato(17, .semibold))
                            .foregroundStyle(LiviqaTheme.ink)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent, lineWidth: 2))
                    .padding(.top, 4)

                    HStack(spacing: 10) {
                        Image(systemName: "person")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(LiviqaTheme.ink4)
                            .accessibilityHidden(true)
                        TextField(String(localized: "Last name"), text: $lastName)
                            .font(.lato(17, .semibold))
                            .foregroundStyle(LiviqaTheme.ink)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                        Text("Optional")
                            .font(.lato(11, .semibold))
                            .foregroundStyle(LiviqaTheme.ink4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
                    .padding(.top, 10)

                    // Live preview card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PREVIEW")
                            .font(.liviqaKicker(10))
                            .tracking(LiviqaTheme.Tracking.kicker)
                            .foregroundStyle(LiviqaTheme.moss)
                        Text(previewName.map { "Good morning, \($0)." } ?? "Good morning.")
                            .font(.liviqaSerif(22, .bold, relativeTo: .title3))
                            .foregroundStyle(LiviqaTheme.ink)
                            .padding(.top, 6)
                        Text("You're having a steady week.")
                            .font(.lato(13))
                            .foregroundStyle(LiviqaTheme.ink2)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(LiviqaTheme.moss2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.moss3, lineWidth: 1))
                    .padding(.top, 18)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: String(localized: "Continue"), action: onContinue)
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 6 · Health Passport

struct PassportStep: View {
    var accent: Color
    var onContinue: () -> Void

    @Environment(AppState.self) private var appState
    @State private var openSection: ProfileSheet.Section? = nil

    private struct Tile: Identifiable {
        let id: ProfileSheet.Section
        let icon: String
        let title: String
        let filledSub: String?
    }

    private var tiles: [Tile] {
        let hc = appState.healthContext
        let targets: String? = {
            var bits: [String] = []
            if let lo = hc.targets.glucoseRangeLow, let hi = hc.targets.glucoseRangeHigh {
                bits.append("Glucose \(trim(lo))–\(trim(hi))")
            }
            if let tir = hc.targets.tirTarget { bits.append("TIR \(tir)%") }
            if let hba = hc.targets.hbA1cTarget { bits.append("HbA1c \(trim(hba))") }
            return bits.isEmpty ? nil : bits.joined(separator: " · ")
        }()
        let lifestyle: String? = {
            let bits = [hc.dietApproach, hc.trainingPattern].filter { !$0.isEmpty }
            return bits.isEmpty ? nil : bits.joined(separator: " · ")
        }()
        return [
            Tile(id: .conditions, icon: "cross.case.fill",
                 title: String(localized: "Conditions"),
                 filledSub: hc.conditions.isEmpty ? nil
                    : hc.conditions.map(\.name).joined(separator: " · ")),
            Tile(id: .targets, icon: "target",
                 title: String(localized: "Clinical targets"), filledSub: targets),
            Tile(id: .goals, icon: "flag.fill",
                 title: String(localized: "Goals"),
                 filledSub: hc.goals.filter { !$0.text.isEmpty }.isEmpty ? nil
                    : hc.goals.map(\.text).filter { !$0.isEmpty }.joined(separator: " · ")),
            Tile(id: .medications, icon: "pill.fill",
                 title: String(localized: "Medications"),
                 filledSub: hc.medications.isEmpty ? nil
                    : hc.medications.map(\.name).joined(separator: " · ")),
            Tile(id: .careTeam, icon: "person.2.fill",
                 title: String(localized: "Care team"),
                 filledSub: hc.careTeam.isEmpty ? nil
                    : hc.careTeam.map(\.role).filter { !$0.isEmpty }.joined(separator: " · ")),
            Tile(id: .lifestyle, icon: "figure.run",
                 title: String(localized: "Diet & training"), filledSub: lifestyle)
        ]
    }

    private func trim(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private var anyFilled: Bool { tiles.contains { $0.filledSub != nil } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "Step 6 of 9"),
                        title: String(localized: "Your Health Passport"),
                        lead: String(localized: "A few things only you know. It sharpens every insight to your body — and it never leaves this phone."),
                        accent: accent, compact: true)

                    // Stays-on-device pill
                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Stays on device")
                            .font(.lato(11.5, .bold))
                    }
                    .foregroundStyle(LiviqaTheme.moss)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(LiviqaTheme.moss2)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)

                    ForEach(tiles) { tile in
                        let filled = tile.filledSub != nil
                        Button { openSection = tile.id } label: {
                            HStack(spacing: 12) {
                                OnbIconChip(systemName: tile.icon,
                                            color: filled ? LiviqaTheme.moss
                                                          : LiviqaTheme.ink.opacity(0.10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tile.title)
                                        .font(.lato(14, .semibold))
                                        .foregroundStyle(LiviqaTheme.ink)
                                    Text(tile.filledSub ?? String(localized: "Tap to add"))
                                        .font(.lato(11.5))
                                        .foregroundStyle(LiviqaTheme.ink3)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                ZStack {
                                    Circle()
                                        .stroke(filled ? LiviqaTheme.moss : LiviqaTheme.ink.opacity(0.2),
                                                lineWidth: 1.5)
                                    if filled {
                                        Circle().fill(LiviqaTheme.moss)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(LiviqaTheme.ink.opacity(0.4))
                                    }
                                }
                                .frame(width: 22, height: 22)
                                .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(filled ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(filled ? LiviqaTheme.moss3 : LiviqaTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                        .accessibilityHint(filled
                            ? String(localized: "Edit this Passport section")
                            : String(localized: "Add this Passport section"))
                    }
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 8) {
                OnbPrimaryButton(label: anyFilled ? String(localized: "Continue")
                                                  : String(localized: "Add these later"),
                                 action: onContinue)
                Text("You can complete your Passport any time — it's never a wall.")
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .sheet(item: $openSection) { section in
            ProfileSheet(openSection: section)
                .environment(appState)
        }
    }
}

extension ProfileSheet.Section: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Step 7 · Sharing / data connections explainer

struct SharingStep: View {
    var accent: Color
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "Step 7 of 9"),
                        title: String(localized: "Your data, your call."),
                        lead: String(localized: "Liviqa is free to use just for yourself. If you ever want to share, it's always a summary — never your raw readings."),
                        accent: accent, compact: true)

                    kickerLabel(String(localized: "Available now"))
                        .padding(.bottom, 8)
                    connRow(icon: "doc.text", color: LiviqaTheme.moss,
                            title: String(localized: "Export a summary"),
                            body: String(localized: "Make a one-page PDF of your week and share it yourself, with whoever you choose."),
                            now: true)
                    connRow(icon: "person", color: LiviqaTheme.moss,
                            title: String(localized: "Share a weekly pattern"),
                            body: String(localized: "Send a summary to your nurse or coach — they see the pattern, not the records."),
                            now: true)

                    kickerLabel(String(localized: "Coming later — always off until you choose"))
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    connRow(icon: "globe.europe.africa", color: LiviqaTheme.accentRecovery,
                            title: String(localized: "Public & private providers"),
                            body: String(localized: "Connect clinics, insurers or employers on your terms, with an expiry you set."),
                            now: false)
                    connRow(icon: "sparkles", color: LiviqaTheme.accentRecovery,
                            title: String(localized: "Contribute to research, anonymously"),
                            body: String(localized: "Help studies using grouped, anonymous patterns. Your individual readings never leave."),
                            now: false)

                    // Brass shield card
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(LiviqaTheme.brass)
                            .padding(.top, 1)
                        Text("Every share is governed by the independent **Data for Good Foundation**, and logged in your receipts. 0 raw exports — ever.")
                            .font(.lato(12))
                            .lineSpacing(4)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LiviqaTheme.brass2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(LiviqaTheme.brass.opacity(0.4), lineWidth: 1))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: String(localized: "Got it"), action: onContinue)
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
    }

    private func kickerLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.liviqaKicker(10))
            .tracking(LiviqaTheme.Tracking.kicker)
            .foregroundStyle(LiviqaTheme.ink3)
    }

    private func connRow(icon: String, color: Color, title: String, body: String, now: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            OnbIconChip(systemName: icon, color: color, side: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    if !now {
                        Text("LATER")
                            .font(.liviqaKicker(9))
                            .tracking(0.8)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LiviqaTheme.ink.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                Text(body)
                    .font(.lato(12))
                    .lineSpacing(3.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        .opacity(now ? 1 : 0.92)
        .padding(.bottom, 8)
    }
}

// MARK: - Step 8 · Backup posture (sovereign gated)

struct BackupStep: View {
    var accent: Color
    var onContinue: () -> Void

    @Environment(AppState.self) private var appState
    @AppStorage("backupPreference") private var storedBackup = BackupPreference.onDevice.rawValue
    @State private var selected: BackupPreference = .onDevice

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "Step 8 of 9 · where your data lives"),
                        title: String(localized: "Your readings stay on this phone."),
                        lead: String(localized: "A backup is a locked copy kept somewhere else, so a lost or replaced phone doesn't mean losing your history. Only you hold the key — a backup is never readable by Liviqa, the Foundation, or a cloud operator."),
                        accent: accent, compact: true)

                    optionCard(.onDevice,
                               icon: "iphone",
                               title: String(localized: "On this iPhone only"),
                               body: String(localized: "Nothing is backed up. If you lose the phone, the data is gone. Most private."),
                               chip: String(localized: "Default"), chipAmber: false,
                               selectable: true)
                    optionCard(.iCloud,
                               icon: "lock.icloud",
                               title: String(localized: "Encrypted iCloud"),
                               body: String(localized: "End-to-end encrypted — only you can unlock it. Survives a lost phone."),
                               chip: nil, chipAmber: false,
                               selectable: true)
                    optionCard(.sovereign,
                               icon: "globe.europe.africa",
                               title: String(localized: "Sovereign EU cloud"),
                               body: String(localized: "A GDPR data space in a European region you pick. Rolling out — we'll notify you when it opens."),
                               chip: String(localized: "Coming soon"), chipAmber: true,
                               selectable: false)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: String(localized: "Continue")) {
                storedBackup = selected.rawValue
                appState.backupPreference = selected
                onContinue()
            }
            .padding(.horizontal, 26)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .onAppear {
            selected = BackupPreference(rawValue: storedBackup) ?? .onDevice
        }
    }

    @ViewBuilder
    private func optionCard(_ option: BackupPreference, icon: String, title: String,
                            body: String, chip: String?, chipAmber: Bool,
                            selectable: Bool) -> some View {
        let on = selected == option
        Button {
            guard selectable else { return }
            selected = option
        } label: {
            HStack(alignment: .top, spacing: 12) {
                OnbIconChip(systemName: icon,
                            color: on ? LiviqaTheme.moss : LiviqaTheme.ink.opacity(0.10),
                            side: 34, corner: 10)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(.lato(14.5, .bold))
                            .foregroundStyle(LiviqaTheme.ink)
                        if let chip {
                            Text(chip.uppercased())
                                .font(.liviqaKicker(9))
                                .tracking(0.6)
                                .foregroundStyle(chipAmber ? LiviqaTheme.clayText : LiviqaTheme.moss)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(chipAmber ? LiviqaTheme.clay2 : LiviqaTheme.moss2)
                                .clipShape(Capsule())
                        }
                    }
                    Text(body)
                        .font(.lato(12))
                        .lineSpacing(3.5)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(on ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(on ? LiviqaTheme.moss : LiviqaTheme.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .opacity(selectable ? 1 : 0.72)
        .padding(.bottom, 10)
        .accessibilityHint(selectable ? "" : String(localized: "Coming soon — not yet available"))
    }
}

// MARK: - Health-literacy step (3 levels)

struct LiteracyStep: View {
    var accent: Color
    var onContinue: () -> Void

    @AppStorage("literacyLevel") private var literacyLevel = "both"

    private struct Level: Identifiable {
        let id: String          // "plain" | "both" | "clinical"
        let letter: String
        let title: String
        let sub: String
        let persona: String
    }

    private let levels: [Level] = [
        Level(id: "plain", letter: "A",
              title: String(localized: "In plain words"),
              sub: String(localized: "Tell me what it means for me — skip the jargon."),
              persona: String(localized: "→ the plain-language newcomer")),
        Level(id: "both", letter: "B",
              title: String(localized: "A bit of both"),
              sub: String(localized: "Plain first, with the real numbers alongside."),
              persona: String(localized: "→ the curious tracker")),
        Level(id: "clinical", letter: "C",
              title: String(localized: "Full clinical detail"),
              sub: String(localized: "Give me mmol/L, GMI, HRV in ms, zones and ranges."),
              persona: String(localized: "→ the expert (T1D · cardiac · athlete)"))
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "A little about you"),
                        title: String(localized: "How do you like health numbers explained?"),
                        lead: String(localized: "This sets how much detail Liviqa shows by default — you can change it any time, or go deeper on any screen."),
                        accent: accent, compact: true)

                    ForEach(levels) { level in
                        levelCard(level)
                    }

                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LiviqaTheme.moss)
                            .padding(.top, 1)
                        Text("Whatever you pick, the deeper layer is always one tap away — Liviqa never hides your real data.")
                            .font(.lato(12))
                            .lineSpacing(3.5)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LiviqaTheme.moss2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(LiviqaTheme.moss3, lineWidth: 1))
                    .padding(.top, 2)
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: String(localized: "Continue"), action: onContinue)
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func levelCard(_ level: Level) -> some View {
        let on = literacyLevel == level.id
        Button { literacyLevel = level.id } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(level.letter)
                        .font(.liviqaSerif(17, .bold, relativeTo: .headline))
                        .foregroundStyle(on ? .white : LiviqaTheme.ink)
                        .frame(width: 32, height: 32)
                        .background(on ? LiviqaTheme.moss : LiviqaTheme.ink.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.title)
                            .font(.lato(14.5, .bold))
                            .foregroundStyle(LiviqaTheme.ink)
                        Text(level.sub)
                            .font(.lato(12))
                            .lineSpacing(3)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(level.persona)
                            .font(.lato(11))
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.top, 1)
                    }
                    Spacer(minLength: 0)
                }
                LiteracyPreviewFig(level: level.id)
                    .padding(.top, 10)
            }
            .padding(14)
            .background(on ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(on ? LiviqaTheme.moss : LiviqaTheme.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The LevelFig — the SAME night of sleep, rendered at three depths.
struct LiteracyPreviewFig: View {
    let level: String   // "plain" | "both" | "clinical"

    /// One illustrative night (hours asleep across the week) — a preview
    /// figure, not the user's data.
    private let series: [CGFloat] = [7.4, 6.9, 7.1, 6.6, 7.6, 7.0, 7.2]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR SLEEP WOULD LOOK LIKE THIS")
                .font(.liviqaKicker(8.5))
                .tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink4)

            switch level {
            case "plain":
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(LiviqaTheme.moss2).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LiviqaTheme.moss)
                    }
                    .accessibilityHidden(true)
                    Text("You slept as usual.")
                        .font(.lato(13, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                }
            case "both":
                HStack(spacing: 10) {
                    Text("As usual · 7h 10m")
                        .font(.lato(13, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                    sparkline(height: 20)
                        .frame(maxWidth: 90)
                }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .topLeading) {
                        // Personal-usual band 6.6–7.6 h
                        GeometryReader { geo in
                            let (yLo, yHi) = bandY(in: geo.size.height)
                            Rectangle()
                                .fill(LiviqaTheme.moss.opacity(0.12))
                                .frame(height: max(0, yLo - yHi))
                                .offset(y: yHi)
                        }
                        sparkline(height: 40)
                    }
                    .frame(height: 40)
                    HStack {
                        Text("7.2 h · deep 12% · REM 20%")
                            .font(.liviqaMono(11))
                            .foregroundStyle(LiviqaTheme.ink)
                        Spacer()
                        Text("your usual 6.6–7.6 h")
                            .font(.lato(10))
                            .foregroundStyle(LiviqaTheme.ink3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(LiviqaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Preview: one night of sleep shown at this level of detail"))
    }

    private func bandY(in height: CGFloat) -> (lo: CGFloat, hi: CGFloat) {
        // Chart maps 6.0…8.0 h onto the height.
        func y(_ v: CGFloat) -> CGFloat { height - (v - 6.0) / 2.0 * height }
        return (y(6.6), y(7.6))
    }

    private func sparkline(height: CGFloat) -> some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width
                let h = geo.size.height
                func pt(_ i: Int) -> CGPoint {
                    CGPoint(x: w * CGFloat(i) / CGFloat(series.count - 1),
                            y: h - (series[i] - 6.0) / 2.0 * h)
                }
                p.move(to: pt(0))
                for i in 1..<series.count { p.addLine(to: pt(i)) }
            }
            .stroke(LiviqaTheme.accentSleep,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Step 9 · How Liviqa learns you

struct HowLearnsStep: View {
    var accent: Color
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnbStepHead(
                        kicker: String(localized: "Step 9 of 9"),
                        title: String(localized: "How Liviqa learns you"),
                        lead: String(localized: "A quick word on what happens next — and why the first couple of weeks look a little quiet."),
                        accent: accent, compact: true)

                    infoCard(icon: "waveform.path.ecg", color: LiviqaTheme.accentRecovery,
                             title: String(localized: "It learns your normal first"),
                             body: String(localized: "For about two weeks, Liviqa mostly watches — building your personal baseline. Early numbers may look bare; that's calibration, not a problem."))
                    infoCard(icon: "bell.badge", color: LiviqaTheme.brass,
                             title: String(localized: "Then it nudges — gently, rarely"),
                             body: String(localized: "Once it knows your usual, it surfaces at most one quiet nudge a day, and only when something drifts from your own pattern. Good days stay calm."))
                    infoCard(icon: "sparkles", color: LiviqaTheme.moss,
                             title: String(localized: "Ask Liviqa, on device"),
                             body: String(localized: "A private assistant answers questions about your own data — “why was Wednesday hard?” — running right on your iPhone. Nothing is sent away."))

                    // Calibration progress hint
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CALIBRATING YOUR BASELINE")
                                .font(.liviqaKicker(10))
                                .tracking(1.4)
                                .foregroundStyle(LiviqaTheme.moss)
                            Spacer()
                            Text("Day 1 of ~14")
                                .font(.liviqaMono(11.5))
                                .fontWeight(.bold)
                                .foregroundStyle(LiviqaTheme.moss)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(LiviqaTheme.moss.opacity(0.14))
                                Capsule().fill(LiviqaTheme.moss)
                                    .frame(width: geo.size.width * 0.08)
                            }
                        }
                        .frame(height: 6)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "Baseline calibration, day 1 of about 14"))
                        Text("Your first full edition arrives once Liviqa has enough of your own days to compare against. It only gets sharper from there.")
                            .font(.lato(11.5))
                            .lineSpacing(3.5)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .background(LiviqaTheme.moss2)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(LiviqaTheme.moss3, lineWidth: 1))
                }
                .padding(.horizontal, 26)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnbPrimaryButton(label: String(localized: "Finish setup"), action: onContinue)
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 20)
        }
    }

    private func infoCard(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            OnbIconChip(systemName: icon, color: color, side: 34, corner: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lato(14, .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(body)
                    .font(.lato(12.5))
                    .lineSpacing(3.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))
        .padding(.bottom, 10)
    }
}
