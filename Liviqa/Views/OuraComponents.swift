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
    var colors: [Color] = [LiviqaTheme.moss, LiviqaTheme.amber]
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
        warn ? [LiviqaTheme.amber, LiviqaTheme.moss] : [LiviqaTheme.moss, LiviqaTheme.mossRev]
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

// MARK: - Glucose curve (target band + amber gradient area + NOW dot)

struct GlucoseCurveView: View {
    var values: [Double]            // mmol/L across the day (any count ≥ 2)
    var low: Double = 3.9
    var high: Double = 10.0
    var yMin: Double = 2.0
    var yMax: Double = 14.0
    var height: CGFloat = 150

    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let t = (v - yMin) / (yMax - yMin)
        return h - CGFloat(min(1, max(0, t))) * h
    }
    private func x(_ i: Int, _ w: CGFloat) -> CGFloat {
        values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * w
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                // target band
                Rectangle()
                    .fill(LiviqaTheme.moss.opacity(0.14))
                    .frame(height: max(0, y(low, h) - y(high, h)))
                    .offset(y: y(high, h))
                // gradient area under the line
                if values.count > 1 {
                    areaPath(w, h).fill(LinearGradient(
                        colors: [LiviqaTheme.amber.opacity(0.28), LiviqaTheme.amber.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom))
                    linePath(w, h).stroke(LiviqaTheme.amber, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    // NOW dot
                    Circle().fill(LiviqaTheme.amber)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(LiviqaTheme.paper2, lineWidth: 2))
                        .position(x: x(values.count - 1, w), y: y(values.last!, h))
                }
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottom) {
            HStack {
                ForEach(["00","06","12","18"], id: \.self) { t in
                    Text(t).font(.liviqaKicker(9)).foregroundStyle(LiviqaTheme.ink4)
                    if t != "18" { Spacer() }
                }
            }
            .offset(y: 16)
        }
        .padding(.bottom, 18)
        .accessibilityElement()
        .accessibilityLabel("Glucose over the day, in millimoles per litre")
    }

    private func linePath(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        for (i, v) in values.enumerated() {
            let pt = CGPoint(x: x(i, w), y: y(v, h))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
    private func areaPath(_ w: CGFloat, _ h: CGFloat) -> Path {
        var p = linePath(w, h)
        p.addLine(to: CGPoint(x: x(values.count - 1, w), y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
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
