// DfGOnboardingView.swift — 3-step consent governance intro · v04 2026-05-22
// v04: corrected DfG name (Data for Good Foundation), mission framing (answers to you),
//      URL (liviqa.app), DfG logo added to Page 1 icon + LearnMoreSheet.
//      Buttons remain pinned outside ScrollView (v03 fix retained).
import SwiftUI

// MARK: - Main view

struct DfGOnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage: Int = 0
    @State private var showLearnMore: Bool = false
    @State private var selectedBackup: BackupPreference = .onDevice

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? LiviqaTheme.moss : LiviqaTheme.line2)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 56)
                .padding(.bottom, 4)

                // Paged content
                TabView(selection: $currentPage) {
                    Page1View(showLearnMore: $showLearnMore) {
                        withAnimation { currentPage = 1 }
                    }
                    .tag(0)

                    Page2View {
                        withAnimation { currentPage = 2 }
                    }
                    .tag(1)

                    Page3View(selectedBackup: $selectedBackup, onComplete: onComplete)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
        .sheet(isPresented: $showLearnMore) {
            LearnMoreSheet(isPresented: $showLearnMore)
        }
    }
}

// MARK: - Page 1

private struct Page1View: View {
    @Binding var showLearnMore: Bool
    var onContinue: () -> Void

    // Optional research-contribution consents — opt-in, default OFF (freely-given).
    // Persisted app-wide; surfaced/revocable later in Privacy.
    @AppStorage("consentCohortDiscovery")      private var cohortDiscovery      = false
    @AppStorage("consentResearchDiscoverable") private var researchDiscoverable = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // DfG logo — colour mark, CENTERED. The page canvas is light
                    // (LiviqaTheme.paper), so the locked logo rule requires the
                    // colour/positive variant; the white/negative mark was invisible
                    // on cream (Brian beta feedback 2026-06-13, build 10.40).
                    HStack {
                        Spacer()
                        Image("dfg-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 92)
                        Spacer()
                    }
                    .padding(.top, 36)

                    // Kicker — centered, larger
                    Text("DATA FOR GOOD FOUNDATION")
                        .font(.liviqaKicker(13))
                        .tracking(2.4)
                        .foregroundStyle(LiviqaTheme.ink4)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 22)

                    // Headline
                    Text("An independent body that works for you — not for institutions.")
                        .font(.lato(26, .black))
                        .kerning(-0.4)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Body — paragraph 1
                    Text("Every time anyone requests your health data, a neutral record is created. Not by Liviqa. Not by the requester. By a foundation that answers to you — and represents your interests in the data economy.")
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)

                    // Body — paragraph 2 as progressive disclosure (FB-AGtO8N6h #3:
                    // heavy onboarding copy → a short line + tap-to-expand detail).
                    ExpandableNote(
                        summary: "You can't be quietly overridden",
                        detail: "Every access request is logged. Every refusal is logged. You can inspect the full record at any time."
                    )
                    .padding(.top, 18)

                    // Optional research-contribution consent — opt-in, default OFF.
                    // Brian beta feedback 2026-06-13 (FB-AIJMHfz6 / FB-AGtO8N6h #2):
                    // two anonymous-discovery consent boxes, each with a one-line explanation.
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONTRIBUTE TO RESEARCH — OPTIONAL")
                            .font(.liviqaKicker(10))
                            .tracking(2)
                            .foregroundStyle(LiviqaTheme.moss)

                        ConsentCheckRow(
                            isOn: $cohortDiscovery,
                            title: "Allow me to be included in anonymous cohort discovery",
                            detail: "Approved research can be told an anonymous person like you exists in a cohort — never your name, never raw data."
                        )
                        ConsentCheckRow(
                            isOn: $researchDiscoverable,
                            title: "Allow me and my data to be discovered for anonymous research",
                            detail: "A researcher can ask you — anonymously — to join a study. You still approve every share, and can withdraw any time."
                        )

                        Text("Off by default. You can change these any time in Privacy.")
                            .font(.lato(11.5))
                            .foregroundStyle(LiviqaTheme.ink4)
                            .padding(.top, 2)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 28)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Continue button — pinned outside ScrollView
            Button(action: onContinue) {
                Text("Continue")
                    .font(.lato(15, .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LiviqaTheme.moss)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            // Learn more link
            HStack {
                Spacer()
                Button {
                    showLearnMore = true
                } label: {
                    Text("What is the Data for Good Foundation?")
                        .font(.lato(12))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .underline()
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Page 2

private struct Page2View: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Icon
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LiviqaTheme.moss2)
                                .frame(width: 80, height: 80)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.lato(36))
                                .foregroundStyle(LiviqaTheme.moss)
                        }
                        Spacer()
                    }
                    .padding(.top, 32)

                    // Kicker
                    Text("YOUR PRIVACY RECORD")
                        .font(.liviqaKicker(10))
                        .tracking(2)
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(.top, 24)

                    // Headline
                    Text("Every decision.\nPermanently recorded.")
                        .font(.lato(26, .black))
                        .kerning(-0.4)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Body — paragraph 1
                    Text("Each time you grant or withdraw access, that decision is written to an independent record. It cannot be edited, deleted, or backdated — by anyone, including Liviqa.")
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)

                    // Body — paragraph 2 as progressive disclosure (FB-AGtO8N6h #3).
                    ExpandableNote(
                        summary: "What if someone disputes it?",
                        detail: "If a requester claims they were given access you never approved, the record will show otherwise. If you change your mind and withdraw consent, that withdrawal is also on record."
                    )
                    .padding(.top, 16)

                    // Faux ledger card
                    VStack(spacing: 0) {
                        LedgerRow(
                            icon: "checkmark.circle",
                            iconColor: LiviqaTheme.moss,
                            label: "Diabetes Nurse · University Hospital · glucose, activity",
                            meta: "Approved · 5 days ago"
                        )
                        Divider().background(LiviqaTheme.line2)
                        LedgerRow(
                            icon: "xmark.circle",
                            iconColor: LiviqaTheme.rust,
                            label: "Insurer A · requested access",
                            meta: "Denied · 3 days ago"
                        )
                        Divider().background(LiviqaTheme.line2)
                        LedgerRow(
                            icon: "lock.circle",
                            iconColor: LiviqaTheme.ink3,
                            label: "Stress & absence study · DK/NO",
                            meta: "Active · 21 days ago"
                        )
                    }
                    .background(LiviqaTheme.moss2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LiviqaTheme.moss3, lineWidth: 1)
                    )
                    .padding(.top, 24)

                    // Caption
                    Text("No one, including Liviqa, can alter this record.")
                        .font(.lato(11.5))
                        .italic()
                        .foregroundStyle(LiviqaTheme.ink4)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 28)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Continue button — pinned outside ScrollView
            Button(action: onContinue) {
                Text("Continue")
                    .font(.lato(15, .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LiviqaTheme.moss)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Page 3

private struct Page3View: View {
    @Binding var selectedBackup: BackupPreference
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Icon
                    HStack {
                        ZStack {
                            Circle()
                                .fill(LiviqaTheme.line2)
                                .frame(width: 80, height: 80)
                            Image(systemName: "iphone")
                                .font(.lato(36))
                                .foregroundStyle(LiviqaTheme.ink3)
                        }
                        Spacer()
                    }
                    .padding(.top, 32)

                    // Kicker
                    Text("BACKUP & STORAGE")
                        .font(.liviqaKicker(10))
                        .tracking(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.top, 24)

                    // Headline
                    Text("Your data lives where you choose.")
                        .font(.lato(26, .black))
                        .kerning(-0.4)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Body
                    Text("All processing happens on this device. You decide whether and where to back up your Liviqa data. The default is on-device only — nothing leaves unless you choose it.")
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)

                    // Backup option cards
                    VStack(spacing: 10) {
                        ForEach(BackupPreference.allCases, id: \.self) { option in
                            BackupOptionCard(
                                option: option,
                                isSelected: selectedBackup == option
                            ) {
                                selectedBackup = option
                            }
                        }
                    }
                    .padding(.top, 24)

                    // GDPR footnote
                    Text("Your rights under GDPR Articles 15–22 apply in full. Full legal text at liviqa.app/privacy")
                        .font(.lato(11))
                        .foregroundStyle(LiviqaTheme.ink4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 28)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Get started button — pinned outside ScrollView
            Button(action: onComplete) {
                Text("Get started")
                    .font(.lato(15, .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LiviqaTheme.moss)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Ledger row

private struct LedgerRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let meta: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.lato(16))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.lato(13, .medium))
                    .foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.ink4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - Expandable note (progressive disclosure for heavy copy)
// Brian beta feedback 2026-06-13 (FB-AGtO8N6h #3): "most explanation text needs
// rework (tooltip box?)". A short summary line + an ⓘ that taps to reveal detail,
// so the onboarding leads with one idea and tucks the depth a tap away.

private struct ExpandableNote: View {
    let summary: String
    let detail: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(spacing: 9) {
                    Image(systemName: "info.circle")
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text(summary)
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.lato(11, .bold))
                        .foregroundStyle(LiviqaTheme.ink4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expanded {
                Text(detail)
                    .font(.lato(14))
                    .foregroundStyle(LiviqaTheme.ink2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 13)
            }
        }
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LiviqaTheme.moss3, lineWidth: 0.5)
        )
    }
}

// MARK: - Consent check row (opt-in research consents)

private struct ConsentCheckRow: View {
    @Binding var isOn: Bool
    let title: String
    let detail: String

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? LiviqaTheme.moss : Color.clear)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isOn ? LiviqaTheme.moss : LiviqaTheme.line, lineWidth: 1.5)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.lato(12, .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .padding(.top, 1)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.lato(12.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(isOn ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? LiviqaTheme.moss3 : LiviqaTheme.line, lineWidth: isOn ? 1 : 0.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Backup option card

private struct BackupOptionCard: View {
    let option: BackupPreference
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Icon
                Image(systemName: option.icon)
                    .font(.lato(18))
                    .foregroundStyle(isSelected ? LiviqaTheme.moss : LiviqaTheme.ink3)
                    .frame(width: 24)
                    .padding(.top, 2)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text(option.description)
                        .font(.lato(12.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? LiviqaTheme.moss : LiviqaTheme.line, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(LiviqaTheme.moss)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 2)
            }
            .padding(14)
            .background(isSelected ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? LiviqaTheme.moss : LiviqaTheme.line,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Learn more sheet

private struct LearnMoreSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Handle
                HStack {
                    Spacer()
                    Capsule()
                        .fill(LiviqaTheme.line)
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 24)

                // DfG logo
                Image("dfg-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .padding(.bottom, 20)

                // Heading
                Text("About Data for Good Foundation")
                    .font(.lato(20, .black))
                    .kerning(-0.3)
                    .foregroundStyle(LiviqaTheme.ink)

                // Body
                Text("Data for Good Foundation is a non-commercial, purpose-locked body that represents you in the data economy. It does not hold your health data — it holds the verified record of who requested it, what you decided, and when. That record answers to you, not to institutions or requesters.")
                    .font(.lato(15))
                    .foregroundStyle(LiviqaTheme.ink2)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                Spacer()

                // Dismiss
                Button {
                    isPresented = false
                } label: {
                    Text("Got it")
                        .font(.lato(15, .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LiviqaTheme.invertBG)
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 28)
        }
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        #endif
    }
}

// MARK: - Preview

#Preview {
    DfGOnboardingView {
        print("DfGOnboardingView completed")
    }
}
