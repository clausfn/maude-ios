// _GlassLab.swift — Liquid Glass design gallery (DEBUG-only, not shipped).
// Reuses the production components in GlassComponents.swift / LiquidGlass.swift.
// Reach it with the launch argument `-glassLab` (wired in LiviqaApp).
#if DEBUG
import SwiftUI

struct GlassLabView: View {
    @Environment(\.dismiss) private var dismiss
    private static let day: [Double] = [5.1,4.8,5.4,6.2,7.1,8.4,7.2,6.1,5.6,6.8,9.1,7.7,
                                        6.4,5.9,5.2,4.7,5.0,6.3,7.0,6.6,5.8,5.3,5.1,4.9]
    private let availability: String = {
        if #available(iOS 26, *) { return "iOS 26 — real Liquid Glass" }
        return "iOS 17–25 — Material fallback"
    }()

    var body: some View {
        NavigationStack {
            scroll
                .background(LiviqaTheme.paper.ignoresSafeArea())
                .navigationTitle("Glass Lab")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder private var scroll: some View {
        let content = ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(availability)
                    .font(.liviqaKicker(11)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3).padding(.top, 4)

                section("Colourful, calm", "More colour from depth + category, not saturation: the ambient field, a clear-glass summary, and per-domain accent chips (glucose amber · sleep indigo · recovery moss · money slate). Apple-level restraint, Liviqa warmth.") {
                    ColourfulCalmDemo()
                }
                section("Money ↔ sleep", "The “Apple can’t” card: tighter-money days from your bank feed overlaid on your sleep + HRV. Bidirectional, hedged, sample-sized.") {
                    CorrelationCard(icon: "creditcard.fill", accent: LiviqaTheme.accentFinance, kicker: "Money · sleep",
                        headline: "On tighter-money days, your sleep and HRV tend to run lower — and the two move together.",
                        footer: "14 days · these tend to move together (either can lead). A pattern in your own data, not a diagnosis.") {
                        FinanceSleepChart()
                    }
                }
                section("Alcohol ↔ recovery", "A self-test: nights after a bar or dining charge vs that night’s resting heart rate. The physiology is real; the charge is only a proxy — framed to verify, not to prove.") {
                    CorrelationCard(icon: "fork.knife", accent: LiviqaTheme.amber, kicker: "Dining out · recovery",
                        headline: "Nights after a bar or dining charge, your resting heart rate often ran a few beats higher — worth testing for yourself.",
                        footer: "7 nights · a self-test, not proof. A pattern in your own data, not a diagnosis.") {
                        AlcoholHRChart()
                    }
                }
                section("Visual nudge", "Keeps the locked evidence-then-meaning structure — now with a domain icon and an inline sparkline of the supporting signal, so the evidence is visible, not just described.") {
                    VisualNudgeDemo()
                }
                section("Lab vs lived · HbA1c", "A dated lab HbA1c anchored on your continuous mean-glucose curve. The value is the gap only continuous data shows — never a tight-fit claim.") {
                    CorrelationCard(icon: "drop.fill", accent: LiviqaTheme.amber, kicker: "Glucose · lab vs lived",
                        headline: "Your lab HbA1c sat above what your day-to-day glucose suggests — the kind of gap only continuous data shows.",
                        footer: "~1 in 5 people show a gap this size. A pattern in your own data, not a diagnosis.") {
                        HbA1cDriftChart()
                    }
                }
                section("Glucose · time in range", "Clinical AGP zones (red/yellow/green) behind the curve — the convention every patient reads. Soft bands, target labelled, TIR % vs the >70% goal. Red lives ONLY here.") {
                    TIRZoneChartDemo()
                }
                section("Deviation heatmap · graded", "The five levels the model already computes, now shown as a calm cool→warm ramp capped at deep amber (never red). The single strongest outlier carries a non-colour ring so the cluster pops — colour-blind-safe.") {
                    GradedHeatmapDemo()
                }
                section("Scrub your day", "A glass thumb on the control plane — drag it across your trace; the reading stays still and opaque, the handle floats and tints moss only when you're in range.") {
                    GlassDayScrubber(samples: Self.day)
                }
                section("Act on a moment", "One calm gesture instead of a modal — the pill morphs open into share-consent · note · why, and back. Tap it.") {
                    HStack { MorphActionCluster(); Spacer() }
                }
                section("Concentric cards", "Corners nest into the container (and the device). Body stays opaque for legibility.") {
                    ConcentricGlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sleep held steady").font(.lato(16, .semibold)).foregroundStyle(LiviqaTheme.ink)
                            Text("Seven nights within your usual window.").font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                        }
                    }
                }
                section("A calmer ground", "An ambient field keyed to your own rhythm, with one clear-glass card refracting it. Still under Reduce Motion; flat under Reduce Transparency.") {
                    ZStack {
                        TidelineField(phase: 0.45, calm: 0.72)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.hero))
                        DaySummaryGlass {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("A steady day").font(.lato(17, .semibold)).foregroundStyle(LiviqaTheme.ink)
                                Text("Glucose, sleep and recovery all tracked close to your normal.")
                                    .font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        if #available(iOS 26, *) { content.scrollEdgeEffectStyle(.soft, for: .top) }
        else { content }
    }

    @ViewBuilder private func section(_ title: String, _ blurb: String,
                                      @ViewBuilder _ demo: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.lato(20, .bold)).foregroundStyle(LiviqaTheme.ink)
            Text(blurb).font(.lato(13)).foregroundStyle(LiviqaTheme.ink2).fixedSize(horizontal: false, vertical: true)
            demo().padding(.top, 2)
        }
    }
}

// MARK: - Sprint-2 demos (TIR clinical zones + graded deviation heatmap)

private struct TIRZoneChartDemo: View {
    private let samples: [Double] = [5.1,4.8,5.4,6.2,7.1,8.4,11.2,9.3,6.1,5.6,6.8,12.1,
                                     7.7,6.4,5.9,5.2,3.6,5.0,6.3,7.0,6.6,5.8,5.3,5.1]
    private let lo = 2.5, hi = 15.0
    private var tirPct: Int {
        let inR = samples.filter { $0 >= 3.9 && $0 <= 10.0 }.count
        return Int((Double(inR) / Double(samples.count) * 100).rounded())
    }
    private func y(_ v: Double, _ h: CGFloat) -> CGFloat { h * (1 - CGFloat((v - lo) / (hi - lo))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Time in range").font(.lato(13, .semibold)).foregroundStyle(LiviqaTheme.ink)
                Spacer()
                Text("\(tirPct)%").font(.liviqaMono(16)).foregroundStyle(LiviqaTheme.tirTarget)
                Text("in target").font(.lato(11)).foregroundStyle(LiviqaTheme.ink3)
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    band(3.9, 10.0, LiviqaTheme.tirTarget, h, w)
                    band(3.0, 3.9, LiviqaTheme.tirLow, h, w)
                    band(lo, 3.0, LiviqaTheme.tirVeryLow, h, w)
                    band(10.0, 13.9, LiviqaTheme.tirHigh, h, w)
                    band(13.9, hi, LiviqaTheme.tirVeryHigh, h, w)
                    Text("TARGET 3.9–10.0").font(.liviqaKicker(8)).tracking(1)
                        .foregroundStyle(LiviqaTheme.tirTarget)
                        .padding(.leading, 4)
                        .position(x: 64, y: (y(3.9, h) + y(10.0, h)) / 2)
                    Path { p in
                        for (i, v) in samples.enumerated() {
                            let pt = CGPoint(x: CGFloat(i) / CGFloat(samples.count - 1) * w, y: y(v, h))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                    }
                    .stroke(LiviqaTheme.clay, style: .init(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 156)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    @ViewBuilder private func band(_ a: Double, _ b: Double, _ c: Color, _ h: CGFloat, _ w: CGFloat) -> some View {
        let top = y(b, h), bot = y(a, h)
        Rectangle().fill(c.opacity(0.12)).frame(width: w, height: max(0, bot - top)).offset(y: top)
    }
}

private struct GradedHeatmapDemo: View {
    private let signals = ["Glucose", "Sleep", "HRV", "Steps"]
    private let grid: [[Int]] = [
        [1, 1, 2, 3, 1, 1, 1],
        [1, 2, 1, 1, 3, 4, 1],   // outlier
        [1, 1, 1, 2, 2, 1, 1],
        [2, 1, 1, 1, 1, 2, 1],
    ]
    private var outlier: (Int, Int)? {
        for (r, row) in grid.enumerated() { if let c = row.firstIndex(of: 4) { return (r, c) } }
        return nil
    }
    private func color(_ lvl: Int) -> Color {
        switch lvl {
        case 0: return LiviqaTheme.gridEmpty
        case 1: return LiviqaTheme.moss2
        case 2: return LiviqaTheme.devMed
        case 3: return LiviqaTheme.devHigh
        default: return LiviqaTheme.devOutlier
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(signals.enumerated()), id: \.offset) { r, name in
                HStack(spacing: 5) {
                    Text(name).font(.lato(11)).foregroundStyle(LiviqaTheme.ink3)
                        .frame(width: 54, alignment: .leading)
                    ForEach(0..<7, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color(grid[r][c]))
                            .frame(height: 26)
                            .overlay {
                                if outlier?.0 == r, outlier?.1 == c {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(LiviqaTheme.ink, lineWidth: 1.5)
                                }
                            }
                    }
                }
            }
            HStack(spacing: 12) {
                legend(LiviqaTheme.moss2, "like usual")
                legend(LiviqaTheme.devHigh, "off usual")
                legend(LiviqaTheme.devOutlier, "worth noticing")
            }
            .padding(.top, 6)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }
    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 12, height: 12)
            Text(t).font(.lato(10)).foregroundStyle(LiviqaTheme.ink3)
        }
    }
}

// MARK: - Visual nudge anatomy (icon + inline sparkline added to the locked card shape)

private struct VisualNudgeDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill").font(.system(size: 12)).foregroundStyle(LiviqaTheme.accentSleep)
                Text("SLEEP").font(.liviqaKicker(10)).tracking(1.2).foregroundStyle(LiviqaTheme.accentSleep)
            }
            Text("Your deep sleep has been climbing back toward your usual this week.")
                .font(.lato(16, .semibold)).foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            MiniSparkline(values: [4.9, 5.2, 5.0, 5.6, 6.1, 6.4, 6.8], tint: LiviqaTheme.accentSleep, height: 30)
            HStack(spacing: 4) {
                Text("Why this?").font(.lato(12, .semibold)).foregroundStyle(LiviqaTheme.accentSleep)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(LiviqaTheme.accentSleep)
            }
        }
        .padding(16)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .overlay(alignment: .leading) { Rectangle().fill(LiviqaTheme.accentSleep).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }
}

// MARK: - Cross-source correlation card (honest grammar + sample-size footer)

private struct CorrelationCard<Chart: View>: View {
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
private struct HbA1cDriftChart: View {
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
private struct FinanceSleepChart: View {
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
private struct AlcoholHRChart: View {
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

// MARK: - Colourful-but-calm composition (ambient field + glass summary + per-domain accents)

private struct ColourfulCalmDemo: View {
    var body: some View {
        ZStack {
            TidelineField(phase: 0.40, calm: 0.70)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.hero))
            VStack(alignment: .leading, spacing: 14) {
                DaySummaryGlass {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tuesday, in balance").font(.lato(18, .semibold)).foregroundStyle(LiviqaTheme.ink)
                        Text("Your day held close to your own normal across glucose, sleep and recovery.")
                            .font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                    }
                }
                HStack(spacing: 8) {
                    domainChip("drop.fill", "88%", "TIR", LiviqaTheme.amber)
                    domainChip("moon.zzz.fill", "7h10", "Sleep", LiviqaTheme.accentSleep)
                    domainChip("waveform.path.ecg", "48", "HRV", LiviqaTheme.moss)
                    domainChip("creditcard.fill", "calm", "Money", LiviqaTheme.accentFinance)
                }
            }
            .padding(16)
        }
    }
    private func domainChip(_ icon: String, _ value: String, _ label: String, _ accent: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(accent)
            Text(value).font(.liviqaMono(13)).foregroundStyle(LiviqaTheme.ink)
            Text(label).font(.lato(9)).foregroundStyle(LiviqaTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.25), lineWidth: 0.5))
    }
}

#Preview { GlassLabView() }
#endif
