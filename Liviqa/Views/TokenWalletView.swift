// TokenWalletView.swift — DfG token wallet v01 · 2026-05-22
// Earn: anonymous computation participation (MPC query results, never raw data).
// Spend: in-app features + charity donation only. No fiat ramp — by design.
import SwiftUI

// MARK: - Models

struct TokenEarnEvent: Identifiable {
    let id = UUID()
    let tokens: Int
    let purpose: String        // researcher-facing label, anonymised
    let category: String       // "Diabetes research", "Sleep science", etc.
    let date: Date
}

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

private let demoEvents: [TokenEarnEvent] = [
    TokenEarnEvent(tokens: 4, purpose: "CGM variability cohort query answered", category: "Diabetes research", date: Date().addingTimeInterval(-3600)),
    TokenEarnEvent(tokens: 2, purpose: "Sleep fragmentation pattern contributed", category: "Sleep science", date: Date().addingTimeInterval(-86400)),
    TokenEarnEvent(tokens: 3, purpose: "HRV + activity correlation computed", category: "Cardiovascular research", date: Date().addingTimeInterval(-172800)),
    TokenEarnEvent(tokens: 2, purpose: "Glucose post-meal response pattern", category: "Diabetes research", date: Date().addingTimeInterval(-259200)),
    TokenEarnEvent(tokens: 1, purpose: "Resting HR seasonal trend", category: "Public health", date: Date().addingTimeInterval(-432000)),
]

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

// MARK: - Main View

struct TokenWalletView: View {
    @State private var balance: Int = 12
    @State private var selectedTab: SpendTab = .inApp
    @State private var redeemingId: UUID? = nil
    @State private var confirmedId: UUID? = nil

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
    }

    // MARK: Balance Card

    private var balanceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LiviqaTheme.ink)

            VStack(spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOKEN BALANCE")
                            .font(.liviqaKicker(10))
                            .foregroundStyle(LiviqaTheme.ink4)
                            .kerning(1)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(balance)")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("DfG")
                                .font(.liviqaKicker(13))
                                .foregroundStyle(LiviqaTheme.mossRev)
                                .padding(.bottom, 8)
                        }
                    }
                    Spacer()
                    apertureMini
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                HStack(spacing: 0) {
                    statCell(label: "EARNED", value: "14", sublabel: "last 30 days")
                    Divider().frame(width: 1, height: 36).background(Color.white.opacity(0.1))
                    statCell(label: "DONATED", value: "2", sublabel: "all time")
                    Divider().frame(width: 1, height: 36).background(Color.white.opacity(0.1))
                    statCell(label: "REDEEMED", value: "0", sublabel: "in-app")
                }
                .padding(.bottom, 16)
            }
        }
    }

    private func statCell(label: String, value: String, sublabel: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.liviqaKicker(9))
                .foregroundStyle(LiviqaTheme.ink4)
                .kerning(1)
            Text(value)
                .font(.liviqaMono(20))
                .foregroundStyle(.white)
            Text(sublabel)
                .font(.liviqaKicker(9))
                .foregroundStyle(LiviqaTheme.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var apertureMini: some View {
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2, r: CGFloat = size.width * 0.38
            // Ink arc (275°)
            var ink = Path(); ink.addArc(center: .init(x: cx, y: cy), radius: r,
                startAngle: .degrees(90), endAngle: .degrees(5), clockwise: false)
            ctx.stroke(ink, with: .color(Color(hex: 0x0E1A2B).opacity(0.6)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            // Moss arc (85°)
            var moss = Path(); moss.addArc(center: .init(x: cx, y: cy), radius: r,
                startAngle: .degrees(5), endAngle: .degrees(90), clockwise: false)
            ctx.stroke(moss, with: .color(LiviqaTheme.mossRev),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            // Dot
            ctx.fill(Path(ellipseIn: .init(x: cx-2.2, y: cy-2.2, width: 4.4, height: 4.4)),
                     with: .color(.white.opacity(0.7)))
        }
        .frame(width: 36, height: 36)
    }

    // MARK: Principle Note

    private var principleNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(LiviqaTheme.moss)
                .font(.system(size: 14))
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

    // MARK: Earn History

    private var earnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "RECENT EARNINGS", icon: "arrow.down.circle.fill", color: LiviqaTheme.moss)

            VStack(spacing: 1) {
                ForEach(demoEvents) { event in
                    earnRow(event)
                }
            }
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
        }
        .padding(.horizontal, 20)
    }

    private func earnRow(_ event: TokenEarnEvent) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.purpose)
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink)
                Text(event.category)
                    .font(.liviqaKicker(9))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .kerning(0.5)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(event.tokens)")
                    .font(.liviqaMono(14))
                    .foregroundStyle(LiviqaTheme.moss)
                Text(event.date, style: .relative)
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
            sectionHeader(title: "SPEND", icon: "arrow.up.circle.fill", color: LiviqaTheme.amber)

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
            .background(selectedTab == tab ? LiviqaTheme.ink : Color.clear)
            .foregroundStyle(selectedTab == tab ? Color.white : LiviqaTheme.ink3)
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
                    .font(.system(size: 16))
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
                .font(.system(size: 22))
        } else {
            Button {
                guard canAfford else { return }
                withAnimation(.spring(response: 0.3)) {
                    balance -= option.cost
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
                .background(canAfford ? LiviqaTheme.ink : LiviqaTheme.line)
                .foregroundStyle(canAfford ? Color.white : LiviqaTheme.ink4)
                .cornerRadius(8)
            }
            .disabled(!canAfford)
        }
    }

    // MARK: Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
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
    }
}
