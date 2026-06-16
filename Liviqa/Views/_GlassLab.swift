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

#Preview { GlassLabView() }
#endif
