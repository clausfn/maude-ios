// TokenWalletView.swift — DfG token wallet v01 · 2026-05-22
// Earn: anonymous computation participation (MPC query results, never raw data).
// Spend: in-app features + charity donation only. No fiat ramp — by design.
import SwiftUI

// MARK: - Models

struct TokenSpendOption: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let cost: Int
    let icon: String
    let category: SpendCategory

    enum SpendCategory { case inApp, charity }
}

// MARK: - Demo Data

// Spend catalogue — demo builds only. On a shipped build the catalogue is
// empty and the spend section shows an honest "coming soon" state instead
// (launch-audit PR-102 line: no fabricated offers on real devices).
#if DEBUG
private let demoSpendOptions: [TokenSpendOption] = [
    // In-app
    TokenSpendOption(title: "Extended history", description: "Nudge patterns across 12 months instead of 3", cost: 8, icon: "chart.line.uptrend.xyaxis", category: .inApp),
    TokenSpendOption(title: "Weather correlation layer", description: "Correlate your metrics with local air quality and pollen", cost: 5, icon: "cloud.sun", category: .inApp),
    TokenSpendOption(title: "Custom nudge topics", description: "Add a focus area: stress, recovery, or fasting windows", cost: 6, icon: "wand.and.stars", category: .inApp),
    // Charity
    TokenSpendOption(title: "Diabetes Research Centre", description: "Donate to type 1 diabetes research in Denmark", cost: 10, icon: "heart.fill", category: .charity),
    TokenSpendOption(title: "Sleep Foundation NL", description: "Fund independent sleep disorder research", cost: 10, icon: "moon.stars.fill", category: .charity),
    TokenSpendOption(title: "Open Health Data Initiative", description: "Support public-domain health data infrastructure", cost: 5, icon: "globe.europe.africa.fill", category: .charity),
]
#else
private let demoSpendOptions: [TokenSpendOption] = []
#endif

// MARK: - Main View

struct TokenWalletView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: SpendTab = .inApp
    @State private var redeemingId: UUID? = nil
    @State private var confirmedId: UUID? = nil

    /// Single source of truth — the same balance the Privacy screen shows.
    private var balance: Int { appState.tokenBalance }

    enum SpendTab { case inApp, charity }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                balanceCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                principleNote
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                earnSection
                    .padding(.top, 24)

                spendSection
                    .padding(.top, 28)
                    .padding(.bottom, 32)
            }
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("DfG Tokens")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .liviqaDetail()
    }

    // MARK: Balance Card

    private var balanceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LiviqaTheme.invertBG)

            VStack(spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOKEN BALANCE")
                            .font(.liviqaKicker(10))
                            .foregroundStyle(LiviqaTheme.invertSub)
                            .kerning(1)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(balance)")
                                .font(.liviqaMono(48))
                                .foregroundStyle(LiviqaTheme.invertFG)
                            Text("DfG")
                                .font(.liviqaKicker(13))
                                .foregroundStyle(LiviqaTheme.moss)
                                .padding(.bottom, 8)
                        }
                    }
                    Spacer()
                    // DfG logo (these are DfG tokens) — negative (light) on the dark
                    // invert card in Paper, primary (dark) on the cream card in Midnight.
                    Image(colorScheme == .light ? "dfg-logo-negative" : "dfg-logo")
                        .resizable().scaledToFit()
                        .frame(height: 26)
                        .opacity(0.95)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Divider()
                    .overlay(LiviqaTheme.invertLine)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                HStack(spacing: 0) {
                    statCell(label: "EARNED", value: "\(earnedLast30Days)", sublabel: "last 30 days")
                    Divider().frame(width: 1, height: 36).overlay(LiviqaTheme.invertLine)
                    statCell(label: "DONATED", value: "\(donatedAllTime)", sublabel: "all time")
                    Divider().frame(width: 1, height: 36).overlay(LiviqaTheme.invertLine)
                    statCell(label: "REDEEMED", value: "\(redeemedInApp)", sublabel: "in-app")
                }
                .padding(.bottom, 16)
            }
        }
    }

    // Real ledger sums — never hard-coded stats (honest-data principle).
    private var earnedLast30Days: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return appState.tokenTransactions
            .filter { $0.type == .earned && $0.date >= cutoff }
            .reduce(0) { $0 + $1.amount }
    }
    private var donatedAllTime: Int {
        appState.tokenTransactions.filter { $0.type == .donated }.reduce(0) { $0 + $1.amount }
    }
    private var redeemedInApp: Int {
        appState.tokenTransactions.filter { $0.type == .spent }.reduce(0) { $0 + $1.amount }
    }

    private func statCell(label: String, value: String, sublabel: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.liviqaKicker(9))
                .foregroundStyle(LiviqaTheme.invertSub)
                .kerning(1)
            Text(value)
                .font(.liviqaMono(20))
                .foregroundStyle(LiviqaTheme.invertFG)
            Text(sublabel)
                .font(.liviqaKicker(9))
                .foregroundStyle(LiviqaTheme.invertSub)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Principle Note

    private var principleNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(LiviqaTheme.moss)
                .font(.lato(14))
            Text("You earn tokens when your device contributes to anonymised research queries. Your health data never leaves this phone.")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(LiviqaTheme.moss2)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .cornerRadius(10)
    }

    // MARK: Token History

    private var earnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "RECENT ACTIVITY", icon: "arrow.down.circle.fill", color: LiviqaTheme.moss)

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
                VStack(spacing: 1) {
                    ForEach(appState.tokenTransactions) { tx in
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.description)
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink)
                Text(tx.type.label.uppercased())
                    .font(.liviqaKicker(9))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .kerning(0.5)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(tx.type == .earned ? "+\(tx.amount)" : "−\(tx.amount)")
                    .font(.liviqaMono(14))
                    .foregroundStyle(tx.type == .earned ? LiviqaTheme.moss : LiviqaTheme.ink2)
                Text(tx.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(LiviqaTheme.ink4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(LiviqaTheme.paper2)
    }

    // MARK: Spend Section

    private var spendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "SPEND", icon: "arrow.up.circle.fill", color: LiviqaTheme.clay)

            if demoSpendOptions.isEmpty {
                // Honest "not yet" state — no fabricated rewards catalogue.
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.lato(28))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Nothing to spend on yet")
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("In-app features and charity donations are on the way. Your tokens keep their value until then.")
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
                // Tab picker
                HStack(spacing: 0) {
                    tabButton(label: "In-app features", tab: .inApp, icon: "sparkles")
                    tabButton(label: "Charity donation", tab: .charity, icon: "heart.fill")
                }
                .background(LiviqaTheme.paper2)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 1))
                .padding(.bottom, 4)

                VStack(spacing: 8) {
                    ForEach(demoSpendOptions.filter { opt in
                        selectedTab == .inApp ? opt.category == .inApp : opt.category == .charity
                    }) { option in
                        spendCard(option)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func tabButton(label: String, tab: SpendTab, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.footnote.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == tab ? LiviqaTheme.invertBG : Color.clear)
            .foregroundStyle(selectedTab == tab ? LiviqaTheme.invertFG : LiviqaTheme.ink3)
        }
        .cornerRadius(9)
        .padding(2)
    }

    private func spendCard(_ option: TokenSpendOption) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(option.category == .charity ? LiviqaTheme.rust2 : LiviqaTheme.moss2)
                    .frame(width: 40, height: 40)
                Image(systemName: option.icon)
                    .font(.lato(16))
                    .foregroundStyle(option.category == .charity ? LiviqaTheme.rust : LiviqaTheme.moss)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            redeemButton(option)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            confirmedId == option.id ? LiviqaTheme.moss3 : LiviqaTheme.line2, lineWidth: 1))
    }

    @ViewBuilder
    private func redeemButton(_ option: TokenSpendOption) -> some View {
        let canAfford = balance >= option.cost

        if confirmedId == option.id {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LiviqaTheme.moss)
                .font(.lato(22))
        } else {
            Button {
                guard canAfford else { return }
                withAnimation(.spring(response: 0.3)) {
                    appState.tokenBalance -= option.cost
                    confirmedId = option.id
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { confirmedId = nil }
                }
            } label: {
                VStack(spacing: 1) {
                    Text("\(option.cost)")
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

    // MARK: Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.lato(11))
                .foregroundStyle(color)
            Text(title)
                .font(.liviqaKicker(10))
                .foregroundStyle(LiviqaTheme.ink3)
                .kerning(1)
        }
    }
}

#Preview {
    NavigationStack {
        TokenWalletView()
            .environment(AppState())
    }
}
