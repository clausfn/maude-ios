// TokenWalletView.swift — DfG token wallet · v02 2026-08-12 (FR-DFG-07)
// A7.2 rebuild from b-extra.jsx TokenWallet: brass→marine hero (iris watermark,
// serif balance), donate-first buttons, icon activity rows, no-health-data
// footer. HONEST-DATA machinery kept (launch-audit PR-102): balance + activity
// are the real ledger sums; Release seeds 0 and shows honest empty states; the
// donation catalogue is DEBUG-only — a shipped build shows an honest "no causes
// connected yet" state, never a fabricated catalogue.
//
// CONSENT-RECORD CLAIM GATING (FR-DFG-07 rail): token events do NOT yet log as
// wallet events, so the designed "written to your consent record" sentence is
// deliberately NOT shipped — the footer claims only what is true (tokens carry
// no health data; TokenTransaction descriptions never embed a reading).
import SwiftUI

// MARK: - Models

struct TokenCause: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let cost: Int
    let icon: String
}

// Donation catalogue — demo builds only. On a shipped build the catalogue is
// empty and the donate sheet shows an honest "coming soon" state instead
// (launch-audit PR-102 line: no fabricated offers on real devices).
#if DEBUG
private let demoCauses: [TokenCause] = [
    TokenCause(title: "Diabetes Research Centre", description: "Donate to type 1 diabetes research in Denmark", cost: 10, icon: "heart.fill"),
    TokenCause(title: "Sleep Foundation NL", description: "Fund independent sleep disorder research", cost: 10, icon: "moon.stars.fill"),
    TokenCause(title: "Open Health Data Initiative", description: "Support public-domain health data infrastructure", cost: 5, icon: "globe.europe.africa.fill"),
]
#else
private let demoCauses: [TokenCause] = []
#endif

// MARK: - Main View

struct TokenWalletView: View {
    @Environment(AppState.self) private var appState

    @State private var showDonate = false
    @State private var showHow = false

    /// Single source of truth — the same balance the Privacy screen shows.
    private var balance: Int { appState.tokenBalance }

    /// Donation ledger description — the cause name only, BY CONSTRUCTION no
    /// health value can enter a token transaction (FR-DFG-07 rail; testable).
    static func donationDescription(cause: String) -> String {
        String(localized: "Donated to \(cause)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Donate-first actions (design drops the old stat strip + spend tabs)
                HStack(spacing: 8) {
                    Button { showDonate = true } label: {
                        Text("Donate for good")
                            .font(.lato(13.5, .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LiviqaTheme.moss)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button { showHow = true } label: {
                        Text("How tokens work")
                            .font(.lato(13.5, .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LiviqaTheme.paper2)
                            .foregroundStyle(LiviqaTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                activitySection
                    .padding(.top, 24)

                // Footer — claims only what is true today (see header note).
                HStack(spacing: 9) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.lato(13))
                        .foregroundStyle(LiviqaTheme.ink3)
                    Text("Tokens carry no health data — earning and donating never include a single reading. Governed by the Data for Good Foundation.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.paper2.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("DfG wallet")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .liviqaDetail()
        .sheet(isPresented: $showDonate) {
            DonateSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHow) {
            HowTokensWorkSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            #if DEBUG
            // Headless screenshot hooks for the new sheets.
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_DONATE"] == "1" { showDonate = true }
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_TOKENHOW"] == "1" { showHow = true }
            #endif
        }
    }

    // MARK: Hero card — brass→marine gradient, iris watermark (both modes)

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(hex: 0x3A3320), Color(hex: 0x1D3557)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            LiviqaApertureMark(size: 150, reversed: true)
                .opacity(0.18)
                .offset(x: 40, y: -50)

            VStack(alignment: .leading, spacing: 0) {
                Text("Your DfG tokens".uppercased())
                    .font(.liviqaKicker(10)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.6))

                Text("\(balance)")
                    .font(.liviqaSerif(46))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                Text("Earned by contributing to research — yours to keep, spend, or donate.")
                    .font(.lato(12.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: LiviqaTheme.cardShadow, radius: 14, y: 6)
    }

    // MARK: Recent activity — real ledger rows, honest empty state

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity".uppercased())
                .font(.liviqaKicker(10))
                .foregroundStyle(LiviqaTheme.ink3)
                .kerning(1)

            if appState.tokenTransactions.isEmpty {
                // Honest empty state — a fresh user has earned nothing yet.
                VStack(spacing: 10) {
                    Image(systemName: "circle.hexagongrid")
                        .font(.lato(28))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("You haven't earned tokens yet")
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("When your device answers an anonymised research query, your first tokens appear here.")
                        .font(.lato(12.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.tokenTransactions.enumerated()), id: \.element.id) { idx, tx in
                        if idx > 0 { Divider().background(LiviqaTheme.line2).padding(.leading, 56) }
                        transactionRow(tx)
                    }
                }
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private func transactionRow(_ tx: TokenTransaction) -> some View {
        let positive = tx.type == .earned
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(positive ? LiviqaTheme.moss2 : LiviqaTheme.brass2)
                    .frame(width: 30, height: 30)
                Image(systemName: positive ? "plus" : "globe.europe.africa")
                    .font(.lato(13, .semibold))
                    .foregroundStyle(positive ? LiviqaTheme.moss : LiviqaTheme.brass)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.description)
                    .font(.lato(13.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(tx.date, style: .relative)
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.ink4)
            }

            Spacer()

            Text(positive ? "+\(tx.amount)" : "−\(tx.amount)")
                .font(.liviqaMono(14))
                .foregroundStyle(positive ? LiviqaTheme.moss : LiviqaTheme.ink2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - Donate sheet (design reduces spend to donation)

private struct DonateSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var confirmedId: UUID? = nil

    private var balance: Int { appState.tokenBalance }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Donate for good".uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 18)

                Text("Give your tokens to a charitable cause.")
                    .font(.liviqaSerif(21)).kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)

                if demoCauses.isEmpty {
                    // Honest "not yet" state — no fabricated causes on real devices.
                    VStack(spacing: 10) {
                        Image(systemName: "heart")
                            .font(.lato(28))
                            .foregroundStyle(LiviqaTheme.moss)
                        Text("No causes are connected yet")
                            .font(.lato(14, .bold))
                            .foregroundStyle(LiviqaTheme.ink)
                        Text("Donation partners are on the way. Your tokens keep their value until then.")
                            .font(.lato(12.5))
                            .foregroundStyle(LiviqaTheme.ink3)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 20)
                    .background(LiviqaTheme.paper2)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
                } else {
                    VStack(spacing: 8) {
                        ForEach(demoCauses) { cause in
                            causeCard(cause)
                        }
                    }
                }

                Text("Tokens carry no health data. Donating never includes a single reading.")
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.ink4)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    private func causeCard(_ cause: TokenCause) -> some View {
        let canAfford = balance >= cause.cost
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LiviqaTheme.brass2)
                    .frame(width: 40, height: 40)
                Image(systemName: cause.icon)
                    .font(.lato(16))
                    .foregroundStyle(LiviqaTheme.brass)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cause.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(cause.description)
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if confirmedId == cause.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LiviqaTheme.moss)
                    .font(.lato(22))
            } else {
                Button {
                    guard canAfford else { return }
                    withAnimation(.spring(response: 0.3)) {
                        appState.tokenBalance -= cause.cost
                        appState.tokenTransactions.insert(
                            TokenTransaction(date: Date(),
                                             description: TokenWalletView.donationDescription(cause: cause.title),
                                             amount: cause.cost,
                                             type: .donated),
                            at: 0)
                        confirmedId = cause.id
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { confirmedId = nil }
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text("\(cause.cost)")
                            .font(.liviqaMono(13))
                        Text("tokens")
                            .font(.liviqaKicker(8))
                            .kerning(0.5)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(canAfford ? LiviqaTheme.invertBG : LiviqaTheme.line)
                    .foregroundStyle(canAfford ? LiviqaTheme.invertFG : LiviqaTheme.ink4)
                    .cornerRadius(8)
                }
                .disabled(!canAfford)
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            confirmedId == cause.id ? LiviqaTheme.moss3 : LiviqaTheme.line2, lineWidth: 1))
    }
}

// MARK: - "How tokens work" — minimal explainer (no designed canvas; kept quiet)

private struct HowTokensWorkSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("How tokens work".uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 18)

                Text("Your device earns them. You decide what they do.")
                    .font(.liviqaSerif(21)).kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                point(icon: "iphone",
                      text: "When your device answers an anonymised research query, you earn tokens. The answer is computed on this phone — your health data never moves.")
                point(icon: "person.3",
                      text: "Answers only count inside a group: your numbers are always grouped with at least 4 other people, never shown alone.")
                point(icon: "heart",
                      text: "Tokens are yours to keep or donate to a charitable cause for the public good. There is no cash-out — by design.")
                point(icon: "shield.lefthalf.filled",
                      text: "Tokens carry no health data — a token is a thank-you, never a reading.")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    private func point(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.lato(14, .semibold))
                .foregroundStyle(LiviqaTheme.moss)
                .frame(width: 30, height: 30)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(.lato(13)).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        TokenWalletView()
            .environment(AppState())
    }
}
