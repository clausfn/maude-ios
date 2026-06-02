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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // DfG logo
                    HStack {
                        Image("dfg-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 72)
                        Spacer()
                    }
                    .padding(.top, 32)

                    // Kicker
                    Text("DATA FOR GOOD FOUNDATION")
                        .font(.liviqaKicker(10))
                        .tracking(2)
                        .foregroundStyle(LiviqaTheme.ink4)
                        .padding(.top, 24)

                    // Headline
                    Text("An independent body that works for you — not for institutions.")
                        .font(.system(size: 26, weight: .black))
                        .kerning(-0.4)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Body — paragraph 1
                    Text("Every time anyone requests your health data, a neutral record is created. Not by Liviqa. Not by the requester. By a foundation that answers to you — and represents your interests in the data economy.")
                        .font(.system(size: 15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)

                    // Body — paragraph 2
                    Text("You can't be quietly overridden. Every access request is logged. Every refusal is logged. You can inspect the full record at any time.")
                        .font(.system(size: 15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 28)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Continue button — pinned outside ScrollView
            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 15, weight: .bold))
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
                        .font(.system(size: 12))
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
                                .font(.system(size: 36))
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
                        .font(.system(size: 26, weight: .black))
                        .kerning(-0.4)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Body — paragraph 1
                    Text("Each time you grant or withdraw access, that decision is written to an independent record. It cannot be edited, deleted, or backdated — by anyone, including Liviqa.")
                        .font(.system(size: 15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)

                    // Body — paragraph 2
                    Text("If a requester claims they were given access you never approved, the record will show otherwise. If you change your mind and withdraw consent, that withdrawal is also on record.")
                        .font(.system(size: 15))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
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
                        .font(.system(size: 11.5))
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
                    .font(.system(size: 15, weight: .bold))
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
                                .font(.system(size: 36))
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
                        .font(.system(size: 26, weight: .black))
                        .kerning(-0.4)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Body
                    Text("All processing happens on this device. You decide whether and where to back up your Liviqa data. The default is on-device only — nothing leaves unless you choose it.")
                        .font(.system(size: 15))
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
                        .font(.system(size: 11))
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
                    .font(.system(size: 15, weight: .bold))
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
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(.system(size: 11.5))
                    .foregroundStyle(LiviqaTheme.ink4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? LiviqaTheme.moss : LiviqaTheme.ink3)
                    .frame(width: 24)
                    .padding(.top, 2)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text(option.description)
                        .font(.system(size: 12.5))
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
                    .font(.system(size: 20, weight: .black))
                    .kerning(-0.3)
                    .foregroundStyle(LiviqaTheme.ink)

                // Body
                Text("Data for Good Foundation is a non-commercial, purpose-locked body that represents you in the data economy. It does not hold your health data — it holds the verified record of who requested it, what you decided, and when. That record answers to you, not to institutions or requesters.")
                    .font(.system(size: 15))
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
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LiviqaTheme.ink)
                        .foregroundStyle(.white)
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
