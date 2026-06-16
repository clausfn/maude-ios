// CorrelationCards.swift — cross-source correlation cards, promoted from the Glass
// Lab to production (PR-100). The "Apple can't" differentiator: health × spending ×
// EMR. HONESTY: these run on SIMULATED data for the pitch (D5) — so on a real screen
// they appear only behind the `crossSourceCards` flag (default OFF; Settings toggle),
// never shown as the user's own real data by default. Headline grammar is observation,
// not causation; every card carries its sample size + "a pattern, not a diagnosis".
import SwiftUI

struct CorrelationCard<Chart: View>: View {
    let icon: String
    let accent: Color
    let kicker: String
    let headline: String
    let footer: String
    @ViewBuilder var chart: Chart
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(accent)
                Text(kicker.uppercased()).font(.liviqaKicker(10)).tracking(1.2).foregroundStyle(accent)
            }
            Text(headline).font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            chart.frame(height: 88)
            Text(footer).font(.lato(11)).foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }
}

// Lab vs lived: continuous mean-glucose curve + a dated lab HbA1c-equivalent line; show the gap.
struct HbA1cDriftChart: View {
    private let curve: [Double] = [7.6,7.9,7.4,8.1,7.8,8.3,7.7,8.0,7.5,7.9,8.2,7.6,7.8,8.1,7.7,
                                   7.9,7.5,8.0,7.8,8.2,7.6,7.9,8.1,7.7,7.8,8.0,7.6,7.9,7.7,8.0]
    private let labLevel = 9.4
    private let lo = 6.5, hi = 10.5
    private func y(_ v: Double, _ h: CGFloat) -> CGFloat { h * (1 - CGFloat((v - lo) / (hi - lo))) }
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: 0, y: y(labLevel, h))); p.addLine(to: CGPoint(x: w, y: y(labLevel, h))) }
                    .stroke(LiviqaTheme.tirHigh, style: .init(lineWidth: 1.5, dash: [4, 3]))
                Text("lab HbA1c").font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.tirHigh)
                    .position(x: 38, y: max(8, y(labLevel, h) - 8))
                Path { p in
                    for (i, v) in curve.enumerated() {
                        let pt = CGPoint(x: CGFloat(i) / CGFloat(curve.count - 1) * w, y: y(v, h))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(LiviqaTheme.amber, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                Text("your day-to-day").font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink3)
                    .position(x: 52, y: min(h - 8, y(7.8, h) + 10))
            }
        }
    }
}

// Money ↔ sleep: sleep-efficiency line with slate bands on tighter-money days.
struct FinanceSleepChart: View {
    private let sleep: [Double] = [86, 85, 84, 78, 76, 83, 85, 86, 84, 77, 75, 82, 85, 86]
    private let strainDays = [3, 4, 9, 10]
    private let lo = 72.0, hi = 90.0
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat { CGFloat(i) / CGFloat(sleep.count - 1) * w }
    private func y(_ v: Double, _ h: CGFloat) -> CGFloat { h * (1 - CGFloat((v - lo) / (hi - lo))) }
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                ForEach(strainDays, id: \.self) { d in
                    Rectangle().fill(LiviqaTheme.accentFinance.opacity(0.18))
                        .frame(width: 12, height: h).position(x: x(d, w), y: h / 2)
                }
                Path { p in
                    for (i, v) in sleep.enumerated() {
                        let pt = CGPoint(x: x(i, w), y: y(v, h))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(LiviqaTheme.accentSleep, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                Text("tighter-money days").font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.accentFinance)
                    .position(x: 64, y: 10)
            }
        }
    }
}

// Alcohol ↔ recovery: nightly resting-HR bars; dining-out nights tinted amber over a baseline.
struct AlcoholHRChart: View {
    private let rhr: [Double] = [58, 57, 66, 59, 58, 67, 60]
    private let drinkNights: Set<Int> = [2, 5]
    private let lo = 54.0, hi = 70.0
    private func barH(_ v: Double, _ h: CGFloat) -> CGFloat { h * CGFloat((v - lo) / (hi - lo)) }
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = rhr.count
            let gap: CGFloat = 8
            let bw = (w - gap * CGFloat(n - 1)) / CGFloat(n)
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<n, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(drinkNights.contains(i) ? LiviqaTheme.amber : LiviqaTheme.moss2)
                        .frame(width: bw, height: max(3, barH(rhr[i], h)))
                        .overlay(alignment: .top) {
                            if drinkNights.contains(i) {
                                Image(systemName: "fork.knife").font(.system(size: 8)).foregroundStyle(LiviqaTheme.clayText)
                                    .offset(y: -12)
                            }
                        }
                        .offset(x: (bw + gap) * CGFloat(i))
                }
            }
        }
    }
}

/// The three cross-source cards as one section (used on Insights behind the flag).
struct CrossSourcePatterns: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CorrelationCard(icon: "drop.fill", accent: LiviqaTheme.amber, kicker: "Glucose · lab vs lived",
                headline: "Your lab HbA1c sat above what your day-to-day glucose suggests — the kind of gap only continuous data shows.",
                footer: "~1 in 5 people show a gap this size. A pattern in your own data, not a diagnosis.") {
                HbA1cDriftChart()
            }
            CorrelationCard(icon: "creditcard.fill", accent: LiviqaTheme.accentFinance, kicker: "Money · sleep",
                headline: "On tighter-money days, your sleep and HRV tend to run lower — and the two move together.",
                footer: "14 days · these tend to move together (either can lead). A pattern in your own data, not a diagnosis.") {
                FinanceSleepChart()
            }
            CorrelationCard(icon: "fork.knife", accent: LiviqaTheme.amber, kicker: "Dining out · recovery",
                headline: "Nights after a bar or dining charge, your resting heart rate often ran a few beats higher — worth testing for yourself.",
                footer: "7 nights · a self-test, not proof. A pattern in your own data, not a diagnosis.") {
                AlcoholHRChart()
            }
        }
    }
}
