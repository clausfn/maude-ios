// _GlassLab.swift — Liquid Glass design gallery (DEBUG-only, not shipped).
// Reuses the production components in GlassComponents.swift / LiquidGlass.swift.
// Reach it with the launch argument `-glassLab` (wired in MaudeApp).
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
                .background(MaudeTheme.paper.ignoresSafeArea())
                .navigationTitle("Glass Lab")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder private var scroll: some View {
        let content = ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(availability)
                    .font(.maudeKicker(11)).tracking(MaudeTheme.Tracking.kicker)
                    .foregroundStyle(MaudeTheme.ink3).padding(.top, 4)

                section("Glucose · clinical zones (live component)", "The real GlucoseCurveView with showsClinicalZones on — AGP red/yellow/green bands behind the curve, target labelled green. The promoted component, not a mock; flag default OFF preserves today's single-band look.") {
                    GlucoseCurveView(values: [5.1,4.8,5.4,6.2,7.1,8.4,11.2,9.3,6.1,5.6,6.8,12.1,
                                              7.7,6.4,5.9,5.2,3.6,5.0,6.3,7.0,6.6,5.8,5.3,5.1],
                                     showsClinicalZones: true)
                }
                section("Colourful, calm", "More colour from depth + category, not saturation: the ambient field, a clear-glass summary, and per-domain accent chips (glucose amber · sleep indigo · recovery moss · money slate). Apple-level restraint, Maude warmth.") {
                    ColourfulCalmDemo()
                }
                section("Money ↔ sleep", "The “Apple can’t” card: tighter-money days from your bank feed overlaid on your sleep + HRV. Bidirectional, hedged, sample-sized.") {
                    CorrelationCard(icon: "creditcard.fill", accent: MaudeTheme.accentFinance, kicker: "Money · sleep",
                        headline: "On tighter-money days, your sleep and HRV tend to run lower — and the two move together.",
                        footer: "14 days · these tend to move together (either can lead). A pattern in your own data, not a diagnosis.") {
                        FinanceSleepChart()
                    }
                }
                section("Alcohol ↔ recovery", "A self-test: nights after a bar or dining charge vs that night’s resting heart rate. The physiology is real; the charge is only a proxy — framed to verify, not to prove.") {
                    CorrelationCard(icon: "fork.knife", accent: MaudeTheme.amber, kicker: "Dining out · recovery",
                        headline: "Nights after a bar or dining charge, your resting heart rate often ran a few beats higher — worth testing for yourself.",
                        footer: "7 nights · a self-test, not proof. A pattern in your own data, not a diagnosis.") {
                        AlcoholHRChart()
                    }
                }
                section("Visual nudge", "Keeps the locked evidence-then-meaning structure — now with a domain icon and an inline sparkline of the supporting signal, so the evidence is visible, not just described.") {
                    VisualNudgeDemo()
                }
                section("Lab vs lived · HbA1c", "A dated lab HbA1c anchored on your continuous mean-glucose curve. The value is the gap only continuous data shows — never a tight-fit claim.") {
                    CorrelationCard(icon: "drop.fill", accent: MaudeTheme.amber, kicker: "Glucose · lab vs lived",
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
                            Text("Sleep held steady").font(.lato(16, .semibold)).foregroundStyle(MaudeTheme.ink)
                            Text("Seven nights within your usual window.").font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                        }
                    }
                }
                section("A calmer ground", "An ambient field keyed to your own rhythm, with one clear-glass card refracting it. Still under Reduce Motion; flat under Reduce Transparency.") {
                    ZStack {
                        TidelineField(phase: 0.45, calm: 0.72)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.hero))
                        DaySummaryGlass {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("A steady day").font(.lato(17, .semibold)).foregroundStyle(MaudeTheme.ink)
                                Text("Glucose, sleep and recovery all tracked close to your normal.")
                                    .font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
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
            Text(title).font(.lato(20, .bold)).foregroundStyle(MaudeTheme.ink)
            Text(blurb).font(.lato(13)).foregroundStyle(MaudeTheme.ink2).fixedSize(horizontal: false, vertical: true)
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
                Text("Time in range").font(.lato(13, .semibold)).foregroundStyle(MaudeTheme.ink)
                Spacer()
                Text("\(tirPct)%").font(.maudeMono(16)).foregroundStyle(MaudeTheme.tirTargetText)
                Text("in target").font(.lato(11)).foregroundStyle(MaudeTheme.ink3)
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    band(3.9, 10.0, MaudeTheme.tirTarget, h, w)
                    band(3.0, 3.9, MaudeTheme.tirLow, h, w)
                    band(lo, 3.0, MaudeTheme.tirVeryLow, h, w)
                    band(10.0, 13.9, MaudeTheme.tirHigh, h, w)
                    band(13.9, hi, MaudeTheme.tirVeryHigh, h, w)
                    Text("TARGET 3.9–10.0").font(.maudeKicker(8)).tracking(1)
                        .foregroundStyle(MaudeTheme.tirTargetText)
                        .padding(.leading, 4)
                        .position(x: 64, y: (y(3.9, h) + y(10.0, h)) / 2)
                    Path { p in
                        for (i, v) in samples.enumerated() {
                            let pt = CGPoint(x: CGFloat(i) / CGFloat(samples.count - 1) * w, y: y(v, h))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                    }
                    .stroke(MaudeTheme.clay, style: .init(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 156)
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card).stroke(MaudeTheme.line, lineWidth: 0.5))
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
        case 0: return MaudeTheme.gridEmpty
        case 1: return MaudeTheme.moss2
        case 2: return MaudeTheme.devMed
        case 3: return MaudeTheme.devHigh
        default: return MaudeTheme.devOutlier
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(signals.enumerated()), id: \.offset) { r, name in
                HStack(spacing: 5) {
                    Text(name).font(.lato(11)).foregroundStyle(MaudeTheme.ink3)
                        .frame(width: 54, alignment: .leading)
                    ForEach(0..<7, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color(grid[r][c]))
                            .frame(height: 26)
                            .overlay {
                                if outlier?.0 == r, outlier?.1 == c {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(MaudeTheme.ink, lineWidth: 1.5)
                                }
                            }
                    }
                }
            }
            HStack(spacing: 12) {
                legend(MaudeTheme.moss2, "like usual")
                legend(MaudeTheme.devHigh, "off usual")
                legend(MaudeTheme.devOutlier, "worth noticing")
            }
            .padding(.top, 6)
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card).stroke(MaudeTheme.line, lineWidth: 0.5))
    }
    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 12, height: 12)
            Text(t).font(.lato(10)).foregroundStyle(MaudeTheme.ink3)
        }
    }
}

// MARK: - Visual nudge anatomy (icon + inline sparkline added to the locked card shape)

private struct VisualNudgeDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill").font(.system(size: 12)).foregroundStyle(MaudeTheme.accentSleep)
                Text("SLEEP").font(.maudeKicker(10)).tracking(1.2).foregroundStyle(MaudeTheme.accentSleep)
            }
            Text("Your deep sleep has been climbing back toward your usual this week.")
                .font(.lato(16, .semibold)).foregroundStyle(MaudeTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            MiniSparkline(values: [4.9, 5.2, 5.0, 5.6, 6.1, 6.4, 6.8], tint: MaudeTheme.accentSleep, height: 30)
            HStack(spacing: 4) {
                Text("Why this?").font(.lato(12, .semibold)).foregroundStyle(MaudeTheme.accentSleep)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(MaudeTheme.accentSleep)
            }
        }
        .padding(16)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .overlay(alignment: .leading) { Rectangle().fill(MaudeTheme.accentSleep).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card).stroke(MaudeTheme.line, lineWidth: 0.5))
    }
}


// MARK: - Colourful-but-calm composition (ambient field + glass summary + per-domain accents)

private struct ColourfulCalmDemo: View {
    var body: some View {
        ZStack {
            TidelineField(phase: 0.40, calm: 0.70)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.hero))
            VStack(alignment: .leading, spacing: 14) {
                DaySummaryGlass {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tuesday, in balance").font(.lato(18, .semibold)).foregroundStyle(MaudeTheme.ink)
                        Text("Your day held close to your own normal across glucose, sleep and recovery.")
                            .font(.lato(13)).foregroundStyle(MaudeTheme.ink2)
                    }
                }
                HStack(spacing: 8) {
                    domainChip("drop.fill", "88%", "TIR", MaudeTheme.amber)
                    domainChip("moon.zzz.fill", "7h10", "Sleep", MaudeTheme.accentSleep)
                    domainChip("waveform.path.ecg", "48", "HRV", MaudeTheme.moss)
                    domainChip("creditcard.fill", "calm", "Money", MaudeTheme.accentFinance)
                }
            }
            .padding(16)
        }
    }
    private func domainChip(_ icon: String, _ value: String, _ label: String, _ accent: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(accent)
            Text(value).font(.maudeMono(13)).foregroundStyle(MaudeTheme.ink)
            Text(label).font(.lato(9)).foregroundStyle(MaudeTheme.ink3)
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
