// OuraComponents.swift — shared "Oura pass" UI: gradient rings, glucose curve,
// toast, deltas, pills, chips. Pure presentation; reads LiviqaTheme tokens only.
// Motion is gated on Reduce-Motion (system OR the in-app switch) and the resting
// state is always the FULL value (so snapshots / reduced-motion are correct).
import SwiftUI

// MARK: - Motion gate

enum LiviqaMotion {
    /// True when any draw-in / spin animation should be SUPPRESSED.
    @MainActor static func reduced(_ system: Bool) -> Bool {
        system || UserDefaults.standard.bool(forKey: "liviqaReduceMotion")
    }
}

// MARK: - Ring (big gradient/glow/draw-in arc)

struct RingView: View {
    var progress: Double                 // 0...1 (resting = this value)
    var size: CGFloat = 212
    var lineWidth: CGFloat = 16
    var colors: [Color] = [LiviqaTheme.moss, LiviqaTheme.clay]
    var glow: Color = LiviqaTheme.heroGlow
    var a11yLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var shown = false

    private var clamped: Double { min(1, max(0, progress)) }
    private var shownValue: Double {
        LiviqaMotion.reduced(systemReduceMotion) ? clamped : (shown ? clamped : 0)
    }

    var body: some View {
        ZStack {
            Circle().stroke(LiviqaTheme.line2, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, shownValue))
                .stroke(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glow, radius: lineWidth * 0.8)
                .animation(.easeOut(duration: 1.0), value: shownValue)
        }
        .frame(width: size, height: size)
        .onAppear { shown = true }
        .accessibilityElement()
        .accessibilityLabel(a11yLabel ?? "")
    }
}

// MARK: - Mini ring (vitals)

struct MiniRing: View {
    var progress: Double
    var value: String
    var label: String
    var delta: String? = nil
    var deltaTone: DeltaTone = .neutral
    var warn: Bool = false
    var size: CGFloat = 74

    private var colors: [Color] {
        warn ? [LiviqaTheme.clay, LiviqaTheme.moss] : [LiviqaTheme.moss, LiviqaTheme.mossRev]
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RingView(progress: progress, size: size, lineWidth: 7, colors: colors,
                         a11yLabel: "\(label): \(value)" + (delta.map { ", \($0)" } ?? ""))
                Text(value)
                    .font(.liviqaMono(15))
                    .foregroundStyle(LiviqaTheme.ink)
            }
            Text(label.uppercased())
                .font(.liviqaKicker(9)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            if let delta {
                Text(delta)
                    .font(.liviqaMono(10))
                    .foregroundStyle(deltaTone.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Delta / pill / chip

enum DeltaTone { case good, bad, neutral
    var color: Color { switch self { case .good: LiviqaTheme.moss; case .bad: LiviqaTheme.rust; case .neutral: LiviqaTheme.ink4 } }
}

struct StatusPill: View {
    var text: String
    var dot: Color? = nil
    var bg: Color = LiviqaTheme.moss2
    var fg: Color = LiviqaTheme.moss
    var body: some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 6, height: 6) }
            Text(text).font(.lato(11, .bold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(bg).foregroundStyle(fg).clipShape(Capsule())
    }
}

struct SourceChip: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.liviqaKicker(9)).tracking(0.6)
            .foregroundStyle(LiviqaTheme.moss)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(LiviqaTheme.moss2)
            .overlay(Capsule().stroke(LiviqaTheme.moss3, lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - Glucose curve (personal target band + smoothed curve + y-axis + NOW)
//
// Descriptive-only: the moss band is the user's OWN time-in-range target window
// (default 3.9–10.0 mmol/L), shown so the curve reads against "your range" — not a
// clinical verdict. Clay line = the attention tone for glucose. Smoothed like the
// trend chart for a premium, CGM-style read.

struct GlucoseCurveView: View {
    var values: [Double]            // mmol/L across the day (any count ≥ 2)
    var low: Double = 3.9
    var high: Double = 10.0
    var yMin: Double = 2.0
    var yMax: Double = 14.0
    var height: CGFloat = 150
    var xTicks: [String] = ["00", "06", "12", "18"]

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var shown = false
    private var t: Double { LiviqaMotion.reduced(systemReduceMotion) ? 1 : (shown ? 1 : 0) }

    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let frac = (v - yMin) / (yMax - yMin)
        return h - CGFloat(min(1, max(0, frac))) * h
    }
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat {
        values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * w
    }
    private func points(_ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        values.enumerated().map { CGPoint(x: x($0.offset, w), y: y($0.element, h)) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // y-axis: top, target high, target low, bottom
            VStack(alignment: .trailing) {
                Text(fmt(yMax))
                Spacer()
                Text(fmt(high)).foregroundStyle(LiviqaTheme.moss)
                Spacer()
                Text(fmt(low)).foregroundStyle(LiviqaTheme.moss)
                Spacer()
                Text(fmt(yMin))
            }
            .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
            .frame(width: 26, height: height, alignment: .trailing)

            VStack(spacing: 6) {
                plot.frame(height: height)
                HStack {
                    ForEach(Array(xTicks.enumerated()), id: \.offset) { idx, lab in
                        Text(lab).font(.liviqaKicker(9)).foregroundStyle(LiviqaTheme.ink4)
                        if idx != xTicks.count - 1 { Spacer() }
                    }
                }
            }
        }
        .frame(height: height + 16)
        .onAppear { shown = true }
        .accessibilityElement()
        .accessibilityLabel("Glucose over the day, in millimoles per litre")
        .accessibilityValue(a11y)
    }

    private var plot: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                // personal target band
                Rectangle()
                    .fill(LiviqaTheme.moss.opacity(0.14))
                    .frame(height: max(0, y(low, h) - y(high, h)))
                    .offset(y: y(high, h))
                    .overlay(alignment: .top) {
                        Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: w, y: 0)) }
                            .stroke(LiviqaTheme.moss.opacity(0.30), lineWidth: 0.5)
                            .offset(y: y(high, h))
                    }
                if values.count > 1 {
                    let pts = points(w, h)
                    smoothedArea(pts, h).fill(LinearGradient(
                        colors: [LiviqaTheme.clay.opacity(0.26), LiviqaTheme.clay.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom))
                    smoothedLine(pts).trim(from: 0, to: max(0.0001, t))
                        .stroke(LiviqaTheme.clay, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .animation(.easeOut(duration: 1.0), value: t)
                    Circle().fill(LiviqaTheme.clay).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(LiviqaTheme.paper2, lineWidth: 2))
                        .position(pts[pts.count - 1]).opacity(t)
                }
            }
        }
    }

    private func fmt(_ v: Double) -> String { String(format: "%.0f", v.rounded()) }
    private var a11y: String {
        guard let last = values.last else { return "No readings today." }
        let inRange = values.filter { $0 >= low && $0 <= high }.count
        let pct = values.isEmpty ? 0 : Int((Double(inRange) / Double(values.count) * 100).rounded())
        return "Latest \(String(format: "%.1f", last)). About \(pct)% of today within your range."
    }

    private func smoothedLine(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        guard pts.count > 2 else { pts.dropFirst().forEach { p.addLine(to: $0) }; return p }
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        return p
    }
    private func smoothedArea(_ pts: [CGPoint], _ h: CGFloat) -> Path {
        var p = smoothedLine(pts)
        guard let last = pts.last, let first = pts.first else { return p }
        p.addLine(to: CGPoint(x: last.x, y: h))
        p.addLine(to: CGPoint(x: first.x, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Mini sparkline (tiny inline micro-trend for the Home chips)

struct MiniSparkline: View {
    var values: [Double]
    var tint: Color = LiviqaTheme.moss
    var height: CGFloat = 22

    private var lo: Double { values.min() ?? 0 }
    private var hi: Double { values.max() ?? 1 }
    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let span = max(0.0001, hi - lo)
        return h - CGFloat((v - lo) / span) * (h * 0.78) - h * 0.11
    }
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat {
        values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * w
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if values.count > 1 {
                let pts = values.enumerated().map { CGPoint(x: x($0.offset, w), y: y($0.element, h)) }
                ZStack {
                    sparkPath(pts).fill(LinearGradient(
                        colors: [tint.opacity(0.28), tint.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom))
                    sparkLine(pts).stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    Circle().fill(tint).frame(width: 4, height: 4).position(pts[pts.count - 1])
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)   // the chip's value already conveys this to VoiceOver
    }

    private func sparkLine(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        if pts.count <= 2 { pts.dropFirst().forEach { p.addLine(to: $0) }; return p }
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        return p
    }
    private func sparkPath(_ pts: [CGPoint]) -> Path {
        var p = sparkLine(pts)
        guard let last = pts.last, let first = pts.first else { return p }
        p.addLine(to: CGPoint(x: last.x, y: height))
        p.addLine(to: CGPoint(x: first.x, y: height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Area trend chart (smoothed curve + personal-normal band + y-axis)
//
// Descriptive-only (non-MDSW): the shaded band is the user's OWN typical range
// (mean ±1σ of the data shown) — "your normal", never a clinical reference range.
// On-brand: moss band, caller-chosen line tint (moss in-range / clay worth-noticing),
// IBM Plex Mono for numbers. Existing call sites get the upgrade for free.

/// Daily BARS for discrete-day series (sleep hours, TIR %, steps): clinical
/// convention — days are discrete observations, so bars, never an interpolated
/// line (which invents data between days). Optional goal line (e.g. 70% TIR
/// consensus target) drawn as a dashed rule with a right-edge label.
struct DailyBarsChart: View {
    var values: [Double]
    var tint: Color = LiviqaTheme.moss
    var height: CGFloat = 120
    var xTicks: [String] = []
    var unit: String = ""
    var goal: Double? = nil
    var goalLabel: String? = nil

    private var lo: Double { min(values.min() ?? 0, goal ?? .infinity) }
    private var hi: Double { max(values.max() ?? 1, goal ?? 0) }
    private var span: Double { max(hi - lo, 0.0001) }
    // Pad 12% above, and floor bars at a tight (not zero) baseline so the
    // differences between days stay readable (deviation is the signal).
    private var floorV: Double { lo - span * 0.25 }
    private var ceilV: Double { hi + span * 0.12 }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let W = geo.size.width, H = geo.size.height
                let n = max(values.count, 1)
                let slot = W / CGFloat(n)
                let bw = min(slot * 0.55, 26)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        let h = H * CGFloat((v - floorV) / (ceilV - floorV))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tint.opacity(i == values.count - 1 ? 0.95 : 0.55))
                            .frame(width: bw, height: max(h, 3))
                            .position(x: slot * (CGFloat(i) + 0.5), y: H - max(h, 3) / 2)
                    }
                    if let g = goal {
                        let gy = H * (1 - CGFloat((g - floorV) / (ceilV - floorV)))
                        Path { p in p.move(to: CGPoint(x: 0, y: gy)); p.addLine(to: CGPoint(x: W, y: gy)) }
                            .stroke(LiviqaTheme.ink4, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        if let lbl = goalLabel {
                            Text(lbl)
                                .font(.liviqaKicker(8)).tracking(0.4)
                                .foregroundStyle(LiviqaTheme.ink4)
                                .position(x: W - 34, y: max(gy - 9, 7))
                        }
                    }
                }
            }
            .frame(height: height)
            if !xTicks.isEmpty {
                HStack {
                    ForEach(Array(xTicks.enumerated()), id: \.offset) { _, t in
                        Text(t).font(.liviqaKicker(8.5)).tracking(0.4)
                            .foregroundStyle(LiviqaTheme.ink4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct AreaTrendChart: View {
    var values: [Double]
    var tint: Color = LiviqaTheme.moss
    var height: CGFloat = 120
    var xTicks: [String] = []
    /// Unit appended to the y-axis value labels (e.g. "%", " ms", " bpm"). Empty = bare numbers.
    var unit: String = ""
    /// Shade the personal mean ±1σ "your normal" band (needs ≥3 points).
    var showBaselineBand: Bool = true
    /// Show the left y-axis scale (max / min value labels).
    var showAxis: Bool = true

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var shown = false

    private var t: Double { LiviqaMotion.reduced(systemReduceMotion) ? 1 : (shown ? 1 : 0) }

    // Display range padded ~8% beyond the data so the curve and band breathe.
    private var dataLo: Double { values.min() ?? 0 }
    private var dataHi: Double { values.max() ?? 1 }
    private var lo: Double { let p = (dataHi - dataLo) * 0.08; return dataLo - max(p, 0.0001) }
    private var hi: Double { let p = (dataHi - dataLo) * 0.08; return dataHi + max(p, 0.0001) }

    private var mean: Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    private var sd: Double {
        guard values.count >= 2 else { return 0 }
        let m = mean
        return (values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)).squareRoot()
    }
    private var hasBand: Bool { showBaselineBand && values.count >= 3 && sd > 0.0001 }

    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let span = max(0.0001, hi - lo)
        let norm = (v - lo) / span
        return h - CGFloat(min(1.05, max(-0.05, norm))) * (h * 0.84) - h * 0.08
    }
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat {
        values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * w
    }
    private func points(_ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        values.enumerated().map { CGPoint(x: x($0.offset, w), y: y($0.element, h)) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if showAxis { yAxis }
            plotAndLabels
        }
        .frame(height: height + (xTicks.isEmpty ? 0 : 18))
        .onAppear { shown = true }
        .accessibilityElement()
        .accessibilityLabel("Trend chart")
        .accessibilityValue(a11ySummary)
    }

    private var yAxis: some View {
        VStack(alignment: .trailing) {
            Text(axisLabel(dataHi))
            Spacer()
            if hasBand {
                Text(axisLabel(mean)).foregroundStyle(LiviqaTheme.moss).opacity(0.9)
                Spacer()
            }
            Text(axisLabel(dataLo))
        }
        .font(.liviqaMono(9))
        .foregroundStyle(LiviqaTheme.ink4)
        .frame(width: 30, height: height, alignment: .trailing)
    }

    private var plotAndLabels: some View {
        VStack(spacing: 0) {
            plot.frame(height: height)
            if !xTicks.isEmpty {
                HStack {
                    ForEach(Array(xTicks.enumerated()), id: \.offset) { idx, tck in
                        Text(tck).font(.liviqaKicker(9)).foregroundStyle(LiviqaTheme.ink4)
                        if idx != xTicks.count - 1 { Spacer() }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var plot: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .bottomLeading) {
                // gridlines
                ForEach(0..<3, id: \.self) { i in
                    let gy = h * (0.18 + 0.32 * CGFloat(i))
                    Path { p in p.move(to: CGPoint(x: 0, y: gy)); p.addLine(to: CGPoint(x: w, y: gy)) }
                        .stroke(LiviqaTheme.gridEmpty, lineWidth: 1)
                }

                // personal "your normal" band (mean ±1σ) — moss, descriptive.
                if hasBand {
                    let top = y(min(hi, mean + sd), h)
                    let bot = y(max(lo, mean - sd), h)
                    Rectangle()
                        .fill(LiviqaTheme.moss.opacity(0.10))
                        .frame(height: max(2, bot - top))
                        .offset(y: top)
                    // dashed mean line
                    Path { p in let my = y(mean, h); p.move(to: CGPoint(x: 0, y: my)); p.addLine(to: CGPoint(x: w, y: my)) }
                        .stroke(LiviqaTheme.moss.opacity(0.45),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                if values.count > 1 {
                    let pts = points(w, h)
                    // smoothed area + line
                    smoothedArea(pts, h).fill(LinearGradient(
                        colors: [tint.opacity(0.45), tint.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom))
                    smoothedLine(pts).trimmedStroke(t: t, color: tint)

                    // subtle data-point dots (reads as measured data)
                    ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(tint.opacity(0.9)).frame(width: 3.5, height: 3.5)
                            .position(pt).opacity(t)
                    }
                    // emphasised latest point
                    Circle().fill(tint).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(LiviqaTheme.paper2, lineWidth: 2))
                        .position(pts[pts.count - 1]).opacity(t)
                }
            }
        }
    }

    private func axisLabel(_ v: Double) -> String {
        let num = abs(v) >= 100 ? String(Int(v.rounded())) : String(format: "%.0f", v.rounded())
        return num + unit
    }

    /// Spoken summary for VoiceOver — direction + endpoints + own-range, no clinical verdict.
    private var a11ySummary: String {
        guard let first = values.first, let last = values.last, values.count > 1 else {
            return "Not enough data yet."
        }
        let fmt: (Double) -> String = { v in
            abs(v) >= 100 ? String(Int(v.rounded())) : String(format: "%.1f", v)
        }
        let direction: String
        if last > first * 1.02 { direction = "trending up" }
        else if last < first * 0.98 { direction = "trending down" }
        else { direction = "steady" }
        let band = hasBand ? " Your typical range is about \(fmt(mean - sd)) to \(fmt(mean + sd))\(unit)." : ""
        return "\(direction), from \(fmt(first)) to \(fmt(last))\(unit) over \(values.count) points.\(band)"
    }

    // MARK: smoothing (uniform Catmull-Rom → cubic Bézier)

    private func smoothedLine(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        guard pts.count > 2 else { pts.dropFirst().forEach { p.addLine(to: $0) }; return p }
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(pts.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        return p
    }
    private func smoothedArea(_ pts: [CGPoint], _ h: CGFloat) -> Path {
        var p = smoothedLine(pts)
        guard let last = pts.last, let first = pts.first else { return p }
        p.addLine(to: CGPoint(x: last.x, y: h))
        p.addLine(to: CGPoint(x: first.x, y: h))
        p.closeSubpath()
        return p
    }
}

private extension Path {
    /// Animated draw-in stroke (gated by caller's reduce-motion `t`).
    func trimmedStroke(t: Double, color: Color) -> some View {
        self.trim(from: 0, to: max(0.0001, t))
            .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .animation(.easeOut(duration: 1.0), value: t)
    }
}

// MARK: - Toast (CE-ledger confirmation pattern)

struct LiviqaToastData: Equatable {
    var title: String
    var detail: String
    var tone: DeltaTone = .good          // good = grant (moss dot), bad = withdraw (rust dot)
}

private struct LiviqaToastView: View {
    let data: LiviqaToastData
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(data.tone == .bad ? LiviqaTheme.rust : LiviqaTheme.moss)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(data.title).font(.lato(13, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                Text(data.detail).font(.liviqaMono(10)).foregroundStyle(LiviqaTheme.invertSub)
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                .foregroundStyle(data.tone == .bad ? LiviqaTheme.rust : LiviqaTheme.moss)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(LiviqaTheme.invertBG)
        .overlay(Capsule().stroke(LiviqaTheme.invertLine, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: LiviqaTheme.cardShadow, radius: 14, y: 6)
        .padding(.horizontal, 20)
    }
}

extension View {
    /// Bottom toast; slides up (transform only → visible under reduced-motion);
    /// auto-dismiss ~2.8s.
    func liviqaToast(_ item: Binding<LiviqaToastData?>) -> some View {
        overlay(alignment: .bottom) {
            if let data = item.wrappedValue {
                LiviqaToastView(data: data)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 90)
                    .task {
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        withAnimation(.easeInOut(duration: 0.25)) { item.wrappedValue = nil }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: item.wrappedValue)
    }
}
