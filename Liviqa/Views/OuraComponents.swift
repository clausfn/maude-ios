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
    /// PR-99: show the clinical AGP Time-in-Range zones (red/yellow/green) instead of
    /// the single personal target band. Default off ⇒ existing look unchanged.
    var showsClinicalZones: Bool = false
    // A7.2 Area ③ (GlucoseDayCurve anatomy) — all defaulted off so existing call
    // sites render exactly as before.
    /// x-positions as hour-of-day (0…24) per value, so real CGM points sit at
    /// their true wall-clock time. nil keeps the even index spacing.
    var hours: [Double]? = nil
    /// Re-stroke the out-of-range curve segments in the clinical red mark
    /// (RK-ALARM-01: red lives ONLY inside the clinical glucose charts). Gate on
    /// the same `clinicalTIRZones` flag as the zones at the call site.
    var redOutOfRange: Bool = false
    /// In-chart target label ("target 3.9–10.0 mmol/L"), drawn at the top edge of
    /// the in-range band — the chart carries its own labels (never colour-alone).
    var targetLabel: String? = nil
    /// Peak annotation ("11.2 · 13:40"): leader + dot + right-aligned label at the
    /// day's highest point, rendered only when that point is above target.
    var peakLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var shown = false
    private var t: Double { LiviqaMotion.reduced(systemReduceMotion) ? 1 : (shown ? 1 : 0) }

    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let frac = (v - yMin) / (yMax - yMin)
        return h - CGFloat(min(1, max(0, frac))) * h
    }
    // PR-99: AGP clinical zones — soft horizontal bands; curve stays readable on top.
    // PR-105 (A7.2 frozen colour-safety ramp): bands are NEVER colour-alone — very-low
    // carries a HATCH overlay, very-high carries DOTS, and every band that has room
    // renders a small in-band text label. Deuteranopia-safe by construction.
    @ViewBuilder private func clinicalZones(_ h: CGFloat) -> some View {
        zoneBand(yMin, 3.0, LiviqaTheme.tirVeryLow, h, pattern: .hatch, label: "VERY LOW")
        zoneBand(3.0, low, LiviqaTheme.tirLow, h, label: "LOW")
        zoneBand(low, high, LiviqaTheme.tirTarget, h, label: "IN RANGE")
        zoneBand(high, 13.9, LiviqaTheme.tirHigh, h, label: "HIGH")
        zoneBand(13.9, yMax, LiviqaTheme.tirVeryHigh, h, pattern: .dots, label: "VERY HIGH")
    }
    private enum ZonePattern { case none, hatch, dots }
    @ViewBuilder private func zoneBand(_ a: Double, _ b: Double, _ c: Color, _ h: CGFloat,
                                       pattern: ZonePattern = .none, label: String? = nil) -> some View {
        let top = y(b, h), bot = y(a, h)
        let bandH = max(0, bot - top)
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(c.opacity(0.12))
            if pattern == .hatch { ZoneHatch(color: c.opacity(0.30)) }
            if pattern == .dots  { ZoneDots(color: c.opacity(0.30)) }
            if let label, bandH >= 13 {
                Text(label)
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(c)
                    .padding(.trailing, 3).padding(.top, 1.5)
            }
        }
        .frame(height: bandH).offset(y: top).clipped()
        .accessibilityHidden(true)   // the y-axis labels + headline carry the values
    }
    /// Mask covering the regions above the target-high and below the target-low
    /// lines — the clinical re-stroke shows only there.
    private func outOfRangeMask(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle().frame(height: max(0, y(high, h)))
            Spacer(minLength: 0)
            Rectangle().frame(height: max(0, h - y(low, h)))
        }
        .frame(width: w, height: h)
    }
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat {
        if let hours, hours.count == values.count {
            return CGFloat(min(24, max(0, hours[i])) / 24) * w
        }
        return values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * w
    }
    private func points(_ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        values.enumerated().map { CGPoint(x: x($0.offset, w), y: y($0.element, h)) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // y-axis: top, target high, target low, bottom.
            // The column takes the width its WIDEST REAL LABEL needs (never less
            // than 26) instead of a fixed 26 — at accessibility text sizes a
            // hard 26 pt clipped "100%" down to "1…" and wrapped "92%" onto two
            // lines (design-QA sweep, 13 Aug).
            VStack(alignment: .trailing) {
                Text(fmt(yMax))
                Spacer()
                Text(fmt(high)).foregroundStyle(showsClinicalZones ? LiviqaTheme.tirTarget : LiviqaTheme.moss)
                Spacer()
                Text(fmt(low)).foregroundStyle(showsClinicalZones ? LiviqaTheme.tirTarget : LiviqaTheme.moss)
                Spacer()
                Text(fmt(yMin))
            }
            .lineLimit(1)
            .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
            .frame(minWidth: 26, alignment: .trailing)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: height)

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
                if showsClinicalZones {
                    clinicalZones(h)
                } else {
                    // personal target band (default — existing look)
                    Rectangle()
                        .fill(LiviqaTheme.moss.opacity(0.14))
                        .frame(height: max(0, y(low, h) - y(high, h)))
                        .offset(y: y(high, h))
                        .overlay(alignment: .top) {
                            Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: w, y: 0)) }
                                .stroke(LiviqaTheme.moss.opacity(0.30), lineWidth: 0.5)
                                .offset(y: y(high, h))
                        }
                }
                if let targetLabel {
                    Text(targetLabel)
                        .font(.liviqaKicker(8)).tracking(0.4)
                        .foregroundStyle(LiviqaTheme.tirTarget)
                        .offset(x: 4, y: y(high, h) + 2)
                }
                if values.count > 1 {
                    let pts = points(w, h)
                    smoothedArea(pts, h).fill(LinearGradient(
                        colors: [LiviqaTheme.clay.opacity(0.26), LiviqaTheme.clay.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom))
                    smoothedLine(pts).trim(from: 0, to: max(0.0001, t))
                        .stroke(LiviqaTheme.clay, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .animation(.easeOut(duration: 1.0), value: t)
                    // Clinical re-stroke: the SAME curve, masked to the out-of-range
                    // regions, in the clinical red mark (glucose-only, RK-ALARM-01).
                    if redOutOfRange {
                        smoothedLine(pts).trim(from: 0, to: max(0.0001, t))
                            .stroke(LiviqaTheme.clinRed, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .animation(.easeOut(duration: 1.0), value: t)
                            .mask { outOfRangeMask(w: w, h: h) }
                    }
                    // Peak annotation — only when the day's highest point is above target.
                    if let peakLabel,
                       let maxIdx = values.indices.max(by: { values[$0] < values[$1] }),
                       values[maxIdx] > high {
                        let peak = pts[maxIdx]
                        Path { p in
                            p.move(to: CGPoint(x: peak.x, y: peak.y - 7))
                            p.addLine(to: CGPoint(x: peak.x, y: 14))
                        }
                        .stroke(LiviqaTheme.clinRed.opacity(0.5), lineWidth: 1)
                        .opacity(t)
                        Circle().fill(LiviqaTheme.clinRed).frame(width: 7, height: 7)
                            .position(peak).opacity(t)
                        Text(peakLabel)
                            .font(.liviqaMono(10))
                            .foregroundStyle(LiviqaTheme.clinRed)
                            .frame(width: w, alignment: .trailing)
                            .padding(.trailing, 2)
                            .offset(y: 1)
                            .opacity(t)
                    }
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
                        colors: [tint.opacity(0.40), tint.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom))
                    sparkLine(pts).stroke(tint, style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
                    Circle().fill(tint).frame(width: 5, height: 5).position(pts[pts.count - 1])
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
    /// OPTIONAL day axis (same contract as `AreaTrendChart.daySlots`, 2026-08-13):
    /// one COLUMN PER DAY, each value on its own date, and a day with no reading
    /// draws NO bar — never a zero-height bar (which would assert a real 0) and
    /// never a shifted neighbour (which would read as the wrong day).
    var daySlots: [DaySlot]? = nil

    /// Columns actually drawn: the day axis when supplied, else the bare values.
    private var columns: [Double?] { daySlots.map { $0.map(\.value) } ?? values.map { $0 } }

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
                let cols = columns
                let n = max(cols.count, 1)
                let slot = W / CGFloat(n)
                let bw = min(slot * 0.55, 26)
                // The most recent day that actually HAS a reading carries the
                // emphasis — not the last column, which may be an empty day.
                let lastFilled = cols.lastIndex(where: { $0 != nil })
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cols.enumerated()), id: \.offset) { i, v in
                        if let v {
                            let h = H * CGFloat((v - floorV) / (ceilV - floorV))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(tint.opacity(i == lastFilled ? 0.95 : 0.55))
                                .frame(width: bw, height: max(h, 3))
                                .position(x: slot * (CGFloat(i) + 0.5), y: H - max(h, 3) / 2)
                        }
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
    /// OPTIONAL day axis. When set, the chart plots one COLUMN PER DAY and each
    /// value sits on its own date — days with no reading leave a gap and the
    /// curve breaks there rather than being drawn through absent data. `values`
    /// is then ignored for positioning (it stays the source of the y-scale and
    /// the personal band). Without it the chart falls back to evenly spaced
    /// points, which is only correct when the caller has no day axis to honour.
    var daySlots: [DaySlot]? = nil

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var shown = false

    private var t: Double { LiviqaMotion.reduced(systemReduceMotion) ? 1 : (shown ? 1 : 0) }

    /// The plotted values — from the day axis when there is one, so the y-scale
    /// and the drawn points can never disagree.
    private var plotted: [Double] { daySlots.map { $0.compactMap(\.value) } ?? values }
    /// Number of x columns: calendar days when placed on a day axis.
    private var columns: Int { daySlots?.count ?? values.count }
    /// (columnIndex, value) for every recorded point.
    private var placed: [(i: Int, v: Double)] {
        if let slots = daySlots {
            return slots.enumerated().compactMap { i, s in s.value.map { (i, $0) } }
        }
        return values.enumerated().map { ($0.offset, $0.element) }
    }

    // Display range padded ~8% beyond the data so the curve and band breathe.
    private var dataLo: Double { plotted.min() ?? 0 }
    private var dataHi: Double { plotted.max() ?? 1 }
    private var lo: Double { let p = (dataHi - dataLo) * 0.08; return dataLo - max(p, 0.0001) }
    private var hi: Double { let p = (dataHi - dataLo) * 0.08; return dataHi + max(p, 0.0001) }

    private var mean: Double { plotted.isEmpty ? 0 : plotted.reduce(0, +) / Double(plotted.count) }
    private var sd: Double {
        guard plotted.count >= 2 else { return 0 }
        let m = mean
        return (plotted.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(plotted.count)).squareRoot()
    }
    private var hasBand: Bool { showBaselineBand && plotted.count >= 3 && sd > 0.0001 }

    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let span = max(0.0001, hi - lo)
        let norm = (v - lo) / span
        return h - CGFloat(min(1.05, max(-0.05, norm))) * (h * 0.84) - h * 0.08
    }
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat {
        columns <= 1 ? 0 : CGFloat(i) / CGFloat(columns - 1) * w
    }
    /// Contiguous stretches of recorded days. One path per stretch, so a missing
    /// day breaks the curve instead of being interpolated across.
    private func segments(_ w: CGFloat, _ h: CGFloat) -> [[CGPoint]] {
        var out: [[CGPoint]] = []
        var cur: [CGPoint] = []
        var prevIndex: Int? = nil
        for p in placed {
            if let prev = prevIndex, p.i != prev + 1, !cur.isEmpty {
                out.append(cur); cur = []
            }
            cur.append(CGPoint(x: x(p.i, w), y: y(p.v, h)))
            prevIndex = p.i
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
    private func points(_ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        placed.map { CGPoint(x: x($0.i, w), y: y($0.v, h)) }
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

    /// The axis column sizes to its WIDEST REAL LABEL (never below 30 pt) rather
    /// than to a fixed 30 — at accessibility text sizes a hard 30 truncated the
    /// Insights TIR axis "100%" to "1…" and wrapped "92%" onto two lines
    /// (design-QA sweep, 13 Aug). The plot simply takes the remaining width.
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
        .lineLimit(1)
        .font(.liviqaMono(9))
        .foregroundStyle(LiviqaTheme.ink4)
        .frame(minWidth: 30, alignment: .trailing)
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: height)
    }

    private var plotAndLabels: some View {
        VStack(spacing: 0) {
            plot.frame(height: height)
            if !xTicks.isEmpty { tickRow.padding(.top, 6) }
        }
    }

    /// Ticks are positioned with the SAME x-map as the data points. Laying them
    /// out with an HStack + spacers (as this did) only lines up when the tick
    /// count happens to equal the point count — the exact assumption that broke
    /// the day axis on a gapped week.
    private var tickRow: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let n = max(xTicks.count, 1)
            ForEach(Array(xTicks.enumerated()), id: \.offset) { idx, tck in
                let xi = n <= 1 ? w / 2 : CGFloat(idx) / CGFloat(n - 1) * w
                Text(tck)
                    .font(.liviqaKicker(9))
                    .foregroundStyle(LiviqaTheme.ink4)
                    .fixedSize()
                    .position(x: min(max(xi, 8), max(8, w - 8)), y: 6)
            }
        }
        .frame(height: 12)
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

                if plotted.count > 1 {
                    let pts = points(w, h)
                    // One smoothed area + line PER contiguous stretch: a day
                    // with no reading is a break in the curve, not a straight
                    // line drawn through data nobody recorded.
                    ForEach(Array(segments(w, h).enumerated()), id: \.offset) { _, seg in
                        if seg.count > 1 {
                            smoothedArea(seg, h).fill(LinearGradient(
                                colors: [tint.opacity(0.45), tint.opacity(0.06)],
                                startPoint: .top, endPoint: .bottom))
                            smoothedLine(seg).trimmedStroke(t: t, color: tint)
                        }
                    }

                    // subtle data-point dots (reads as measured data) — an
                    // isolated day is drawn as exactly that: one dot.
                    ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(tint.opacity(0.9)).frame(width: 3.5, height: 3.5)
                            .position(pt).opacity(t)
                    }
                    // emphasised latest point
                    if let lastPt = pts.last {
                        Circle().fill(tint).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(LiviqaTheme.paper2, lineWidth: 2))
                            .position(lastPt).opacity(t)
                    }
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
        guard let first = plotted.first, let last = plotted.last, plotted.count > 1 else {
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
        // On a day axis, say how many days actually carry a reading — a curve
        // with holes should never be spoken as an unbroken run.
        let gaps = daySlots.map { $0.count - plotted.count } ?? 0
        let coverage = gaps > 0
            ? " \(gaps) day\(gaps == 1 ? "" : "s") in this span have no reading."
            : ""
        return "\(direction), from \(fmt(first)) to \(fmt(last))\(unit) over \(plotted.count) points.\(band)\(coverage)"
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

// MARK: - TIR zone pattern overlays (PR-105 colour-safety: never colour-alone)

/// Diagonal hatch — overlays the VERY-LOW clinical band. Internal so the glucose
/// detail's TIR proportion bar (GlucoseDetailView) reuses the SAME pattern — the
/// deuteranopia closure stays one implementation.
struct ZoneHatch: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let step: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width {
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += step
            }
            ctx.stroke(p, with: .color(color), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Dot grid — overlays the VERY-HIGH clinical band. Internal: shared with the
/// glucose detail's TIR proportion bar (see ZoneHatch note).
struct ZoneDots: View {
    var color: Color
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 7
            var y: CGFloat = 2.5
            while y < size.height {
                var x: CGFloat = 2.5
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                             with: .color(color))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - A7.2 Home anatomy (PR-106) — iris day-arc + baseline sparkline

/// Three concentric arcs echoing the iris mark, quietly filling as the day's
/// data accrues. Pure presentation — progress 0…1 (fraction of the day).
struct IrisDayArc: View {
    var progress: Double
    var size: CGFloat = 76

    private var p: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle().stroke(LiviqaTheme.fjordBright.opacity(0.18), lineWidth: 4)
            Circle().trim(from: 0, to: max(0.001, p))
                .stroke(LiviqaTheme.fjordBright, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().inset(by: 8).stroke(LiviqaTheme.ink.opacity(0.10), lineWidth: 3.5)
            Circle().inset(by: 8).trim(from: 0, to: max(0.001, p * 0.8))
                .stroke(LiviqaTheme.ink.opacity(0.85), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().inset(by: 16).trim(from: 0, to: 0.16)
                .stroke(LiviqaTheme.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-70))
            Circle().fill(LiviqaTheme.ink).frame(width: 6, height: 6)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)   // decorative; the verdict sentence carries the meaning
    }
}

/// The signal-card sparkline: a 7–14-day line drawn over the "your usual" band.
struct BaselineSpark: View {
    var data: [Double]
    var band: ClosedRange<Double>? = nil
    var color: Color
    var height: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if data.count > 1 {
                let dLo = data.min() ?? 0, dHi = data.max() ?? 1
                let lo = min(dLo, band?.lowerBound ?? dLo)
                let hi = max(dHi, band?.upperBound ?? dHi)
                let span = max(0.0001, hi - lo)
                let y: (Double) -> CGFloat = { v in
                    h - CGFloat((v - lo) / span) * (h * 0.82) - h * 0.09
                }
                let x: (Int) -> CGFloat = { i in CGFloat(i) / CGFloat(data.count - 1) * w }
                ZStack(alignment: .topLeading) {
                    if let band {
                        let top = y(band.upperBound), bot = y(band.lowerBound)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.10))
                            .frame(height: max(2, bot - top))
                            .offset(y: top)
                    }
                    Path { path in
                        path.move(to: CGPoint(x: x(0), y: y(data[0])))
                        for i in 1..<data.count { path.addLine(to: CGPoint(x: x(i), y: y(data[i]))) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    Circle().fill(color).frame(width: 4.5, height: 4.5)
                        .position(x: x(data.count - 1), y: y(data[data.count - 1]))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - A7.2 Evening edition (PR-106) — day-score ring + month trend line

/// One transparent slice of the evening day score: the arithmetic IS the UI.
struct ScoreSegment: Identifiable {
    let id = UUID()
    let name: String
    let val: Double
    let max: Double
    let color: Color
}

/// Segmented breakdown ring (charts.jsx ScoreRing): each domain owns an arc
/// sized by its weight (max/total); the fill inside it is val/max. The score
/// is never opaque — the legend next to it shows the exact addition.
struct ScoreRing: View {
    var score: Int
    var segments: [ScoreSegment]
    var size: CGFloat = 96
    /// FR-TOD-08: an adaptive composition can be out of 90/80, not always 100 —
    /// the spoken label must say the real denominator. Default keeps every
    /// existing /100 call site.
    var outOf: Int = 100
    /// A7.2 Area ④: the sleep hero draws the ring on a tinted band — the centre
    /// number needs white there. Default keeps every existing call site.
    var textColor: Color = LiviqaTheme.ink

    private let gapDeg = 14.0

    var body: some View {
        let total = segments.reduce(0) { $0 + $1.max }
        let sweep = 360.0 - gapDeg * Double(segments.count)
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.element.id) { i, seg in
                let priorMax = segments.prefix(i).reduce(0) { $0 + $1.max }
                let start = -90 + gapDeg / 2 + (priorMax / total) * sweep + gapDeg * Double(i)
                let span = (seg.max / total) * sweep
                let fill = Swift.max(4, span * (seg.val / seg.max))
                arc(start, start + span).stroke(seg.color.opacity(0.20),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
                arc(start, start + fill).stroke(seg.color,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
            Text("\(score)")
                .font(.liviqaSerif(26))
                .foregroundStyle(textColor)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Day score \(score) of \(outOf)"))
    }

    private func arc(_ a0: Double, _ a1: Double) -> Path {
        Path { p in
            let c = CGPoint(x: size / 2, y: size / 2)
            p.addArc(center: c, radius: size / 2 - 7,
                     startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
        }
    }
}

/// Trend line with a dashed "your usual" reference (charts.jsx TrendLine):
/// gradient stroke, average line, edge date labels, end-dot.
struct MonthTrendLine: View {
    var data: [Double]
    var avg: Double
    var color: Color
    var color2: Color? = nil
    var height: CGFloat = 92
    var labels: [String] = []
    /// OPTIONAL day axis: one entry per calendar day of the labelled span, nil
    /// where nothing was recorded. The edge labels on this card name real dates
    /// ("29 days ago → today"), so without this the line stretches whatever
    /// readings exist across the full width and every point lands on the wrong
    /// day. With it, each reading sits on its date and gaps break the line.
    var slots: [Double?]? = nil

    /// (columnIndex, value) pairs actually drawn.
    private var placed: [(i: Int, v: Double)] {
        if let slots {
            return slots.enumerated().compactMap { i, v in v.map { (i, $0) } }
        }
        return data.enumerated().map { ($0.offset, $0.element) }
    }
    private var plotted: [Double] { placed.map(\.v) }
    private var columns: Int { slots?.count ?? data.count }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                if plotted.count > 1 {
                    let lo = min(plotted.min() ?? 0, avg) - 3
                    let hi = max(plotted.max() ?? 1, avg) + 3
                    let span = max(0.0001, hi - lo)
                    let y: (Double) -> CGFloat = { v in 4 + (1 - CGFloat((v - lo) / span)) * (h - 8) }
                    let x: (Int) -> CGFloat = { i in
                        columns <= 1 ? 3 : 3 + CGFloat(i) / CGFloat(columns - 1) * (w - 6)
                    }
                    let pts = placed
                    ZStack(alignment: .topLeading) {
                        // "your usual" — dashed reference at the period average
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y(avg)))
                            p.addLine(to: CGPoint(x: w, y: y(avg)))
                        }
                        .stroke(LiviqaTheme.ink3.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        Path { p in
                            var prev: Int? = nil
                            for pt in pts {
                                let point = CGPoint(x: x(pt.i), y: y(pt.v))
                                // Break the stroke across a missing day.
                                if let prevIdx = prev, pt.i == prevIdx + 1 {
                                    p.addLine(to: point)
                                } else {
                                    p.move(to: point)
                                }
                                prev = pt.i
                            }
                        }
                        .stroke(
                            LinearGradient(colors: [color, color2 ?? color],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        if let last = pts.last {
                            Circle().fill(color2 ?? color).frame(width: 5, height: 5)
                                .position(x: x(last.i), y: y(last.v))
                        }
                    }
                }
            }
            .frame(height: height)
            if !labels.isEmpty {
                HStack {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                        if i > 0 { Spacer() }
                        Text(l).font(.lato(10)).foregroundStyle(LiviqaTheme.ink3)
                    }
                }
            }
        }
        .accessibilityHidden(true)   // the card headline carries the meaning
    }
}
