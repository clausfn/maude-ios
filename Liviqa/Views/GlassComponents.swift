// GlassComponents.swift — reusable Liquid Glass building blocks promoted from the
// Glass Lab to production (2026-06-16). Used by real screens (DayTimelineView,
// NudgeDetailView) and the DEBUG Glass Lab. All carry the three-tier ladder:
//   iOS 26 real glass → iOS 17–25 `.ultraThinMaterial` → opaque `paper2`
//   (Reduce Transparency / Increase Contrast). Motion resolves to rest under
//   `LiviqaMotion.reduced(_:)`. Honour the `liquidGlass` flag at the call site.
import SwiftUI

// MARK: - Container compat (group glass on 26; passthrough below)

struct GlassEffectContainerCompat<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(iOS 26, *) { GlassEffectContainer { content } }
        else { content }
    }
}

// MARK: - Scrubber thumb + still readout

struct GlassScrubberThumb: View {
    var inRange: Bool
    var label: String
    var pressing: Bool
    var namespace: Namespace.ID

    @AppStorage(LiviqaGlass.defaultsKey) private var glassOn = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotionSystem

    private var solid: Bool { reduceTransparency || contrast == .increased }
    private var reduceMotion: Bool { LiviqaMotion.reduced(reduceMotionSystem) }
    private var pressScale: CGFloat { (pressing && !reduceMotion) ? 1.12 : 1 }

    var body: some View {
        let shape = Capsule()
        // Attention tone = Amber Flame (clay), per CN's accepted RK-ALARM-01 decision
        // (RISK.md, 2026-06-16). Kept CALM: a small dot, never a large fill, with the
        // navy "worth noticing" label carrying the meaning — colour is never the only
        // signal. In-range = moss.
        let content = HStack(spacing: 7) {
            Circle().fill(inRange ? LiviqaTheme.moss : LiviqaTheme.clay).frame(width: 7, height: 7)
            Text(label).font(.liviqaMono(12)).foregroundStyle(LiviqaTheme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)

        return Group {
            if solid {
                content
                    .background(shape.fill(LiviqaTheme.paper2))
                    .overlay(shape.strokeBorder(inRange ? LiviqaTheme.moss : LiviqaTheme.ink3, lineWidth: 1))
            } else if glassOn, #available(iOS 26, *) {
                content
                    .glassEffect(inRange
                        ? .regular.tint(LiviqaTheme.moss.opacity(0.5)).interactive()
                        : .regular.interactive(), in: shape)
                    .glassEffectID("scrubber", in: namespace)
            } else {
                content
                    .background(shape.fill(.ultraThinMaterial))
                    .overlay(shape.strokeBorder(LiviqaTheme.line, lineWidth: 0.5))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 3)
            }
        }
        .scaleEffect(pressScale)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.7), value: pressScale)
        .sensoryFeedback(.selection, trigger: inRange)
    }
}

struct ScrubReadout: View {
    var value: String, unit: String, time: String, inRange: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value).font(.liviqaMono(22)).foregroundStyle(LiviqaTheme.ink)
            Text(unit).font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
            Spacer()
            HStack(spacing: 6) {
                // Attention tone = Amber Flame (clay), accepted RK-ALARM-01 decision; kept
                // calm via a small dot + the navy label (colour never the only signal).
                Circle().fill(inRange ? LiviqaTheme.moss : LiviqaTheme.clay).frame(width: 6, height: 6)
                Text(inRange ? "in your range" : "worth noticing")
                    .font(.lato(11, .semibold))
                    .foregroundStyle(inRange ? LiviqaTheme.moss : LiviqaTheme.clayText)
                Text("· \(time)").font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(unit) at \(time), \(inRange ? "in your range" : "worth noticing")")
    }
}

/// Draggable glass scrubber over a day series + its still readout. Reusable.
struct GlassDayScrubber: View {
    let samples: [Double]
    var unit: String = "mmol/L"
    var inRangeLo: Double = 3.9
    var inRangeHi: Double = 10
    var chartLo: Double = 3.5
    var chartHi: Double = 9.5

    @State private var progress: Double = 0.46
    @State private var pressing = false
    @Namespace private var glassNS

    private var value: Double {
        guard samples.count > 1 else { return samples.first ?? 0 }
        let x = progress * Double(samples.count - 1)
        let i = min(samples.count - 2, max(0, Int(x)))
        return samples[i] + (samples[i+1] - samples[i]) * (x - Double(i))
    }
    private var inRange: Bool { value >= inRangeLo && value <= inRangeHi }
    private var timeLabel: String {
        let mins = Int(progress * 24 * 60)
        return String(format: "%02d:%02d", mins / 60, mins % 60)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrubReadout(value: String(format: "%.1f", value), unit: unit, time: timeLabel, inRange: inRange)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    trace(in: CGSize(width: w, height: h))
                    Rectangle().fill(LiviqaTheme.line).frame(width: 1, height: h).offset(x: progress * w)
                    GlassEffectContainerCompat {
                        GlassScrubberThumb(inRange: inRange,
                                           label: "\(String(format: "%.1f", value)) · \(timeLabel)",
                                           pressing: pressing, namespace: glassNS)
                    }
                    .position(x: min(max(54, progress * w), w - 54), y: h + 26)
                    .accessibilityElement()
                    .accessibilityLabel("Scrub the day")
                    .accessibilityValue("\(String(format: "%.1f", value)) \(unit) at \(timeLabel)")
                    .accessibilityAdjustableAction { dir in
                        let step = 1.0 / 24.0
                        progress = min(1, max(0, progress + (dir == .increment ? step : -step)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in pressing = true; progress = min(1, max(0, v.location.x / w)) }
                    .onEnded { _ in pressing = false })
            }
            .frame(height: 96)
            .padding(.bottom, 30)
        }
    }

    private func trace(in size: CGSize) -> some View {
        func pt(_ i: Int) -> CGPoint {
            let x = CGFloat(i) / CGFloat(max(1, samples.count - 1)) * size.width
            let n = (samples[i] - chartLo) / (chartHi - chartLo)
            return CGPoint(x: x, y: size.height * (1 - CGFloat(min(1, max(0, n)))))
        }
        return ZStack {
            Path { p in p.move(to: pt(0)); for i in 1..<samples.count { p.addLine(to: pt(i)) } }
                .stroke(LiviqaTheme.moss.opacity(0.85), style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            Path { p in
                p.move(to: CGPoint(x: 0, y: size.height)); p.addLine(to: pt(0))
                for i in 1..<samples.count { p.addLine(to: pt(i)) }
                p.addLine(to: CGPoint(x: size.width, y: size.height)); p.closeSubpath()
            }
            .fill(LinearGradient(colors: [LiviqaTheme.moss.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - Morph action cluster (one pill → three actions)

struct MorphActionCluster: View {
    var onShareConsent: () -> Void = {}
    var onJournal: () -> Void = {}
    var onEvidence: () -> Void = {}

    @State private var expanded = false
    @Namespace private var glass
    @AppStorage(LiviqaGlass.defaultsKey) private var glassOn = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var solid: Bool { reduceTransparency || contrast == .increased }
    private var reduceMotion: Bool { LiviqaMotion.reduced(systemReduceMotion) }
    private var anim: Animation? { reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82) }

    var body: some View {
        Group {
            if glassOn, #available(iOS 26, *), !solid {
                GlassEffectContainer(spacing: 10) { morphBody }
            } else {
                morphBody
            }
        }
        .animation(anim, value: expanded)
    }

    @ViewBuilder private var morphBody: some View {
        if expanded {
            HStack(spacing: 10) {
                action("Share", "checkmark.shield", id: "a", prominent: true, run: onShareConsent)
                action("Note", "square.and.pencil", id: "b", prominent: false, run: onJournal)
                action("Why", "text.magnifyingglass", id: "c", prominent: false, run: onEvidence)
            }
        } else {
            Button { expanded = true } label: {
                Label("Act on this moment", systemImage: "plus")
                    .font(.lato(13, .semibold)).foregroundStyle(LiviqaTheme.ink)
                    .padding(.horizontal, 16).padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .modifier(GlassPill(id: "a", ns: glass, solid: solid, glassOn: glassOn, prominent: false))
            .accessibilityLabel("Act on this moment")
        }
    }

    @ViewBuilder private func action(_ title: String, _ icon: String, id: String,
                                     prominent: Bool, run: @escaping () -> Void) -> some View {
        Button { run(); withAnimation(anim) { expanded = false } } label: {
            Label(title, systemImage: icon)
                .font(.lato(13, prominent ? .semibold : .regular))
                .foregroundStyle(prominent ? LiviqaTheme.invertFG : LiviqaTheme.ink)
                .padding(.horizontal, 15).padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .modifier(GlassPill(id: id, ns: glass, solid: solid, glassOn: glassOn, prominent: prominent))
    }
}

private struct GlassPill: ViewModifier {
    let id: String, ns: Namespace.ID, solid: Bool, glassOn: Bool, prominent: Bool
    func body(content: Content) -> some View {
        let shape = Capsule()
        return Group {
            if solid {
                content
                    .background(shape.fill(prominent ? LiviqaTheme.moss : LiviqaTheme.paper2))
                    .overlay(shape.strokeBorder(prominent ? LiviqaTheme.moss : LiviqaTheme.ink3, lineWidth: 1))
            } else if glassOn, #available(iOS 26, *) {
                content
                    .glassEffect(prominent ? .regular.tint(LiviqaTheme.moss) : .regular, in: shape)
                    .glassEffectID(id, in: ns)
                    .glassEffectTransition(.matchedGeometry)
            } else {
                content
                    .background(shape.fill(prominent ? AnyShapeStyle(LiviqaTheme.moss) : AnyShapeStyle(.ultraThinMaterial)))
                    .overlay(shape.strokeBorder(LiviqaTheme.line, lineWidth: 0.5))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
            }
        }
    }
}

// MARK: - Ambient tide field + clear-glass day summary

struct TidelineField: View {
    var phase: Double = 0.5
    var breathPeriod: Double = 11
    var calm: Double = 0.7

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var opaqueFallback: Bool { reduceTransparency || contrast == .increased }
    private var still: Bool { LiviqaMotion.reduced(systemReduceMotion) }

    var body: some View {
        if opaqueFallback {
            LiviqaTheme.paper2
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { tl in
                // Slow clock; frozen at a phase-derived instant under Reduce Motion.
                let clock = still ? phase * 240 : tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let w = size.width, h = size.height
                    // 1. Base tide — soft vertical wash; height set by the circadian phase.
                    let a = 0.14 + 0.06 * (1 - calm)
                    let tideY = h * (0.70 - 0.22 * phase)
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: LiviqaTheme.heroGlow.opacity(a), location: max(0, tideY / h - 0.2)),
                            .init(color: LiviqaTheme.moss.opacity(a * 0.7), location: 1),
                        ]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                    // 2. Floating orbs — slow drifting soft shapes (the calm "pictures").
                    //    Drift SPEED scales with the breathing period (resting HR); each
                    //    orb has its own phase so they never line up. Visible but gentle.
                    let tones = [LiviqaTheme.heroGlow, LiviqaTheme.moss, LiviqaTheme.amber, LiviqaTheme.heroGlow]
                    for i in 0..<4 {
                        let sp = (2 * Double.pi) / (breathPeriod * Double(6 + i * 2))   // slow
                        let ph = phase * 6.28 + Double(i) * 1.7
                        let cx = w * (0.5 + 0.34 * sin(clock * sp + ph))
                        let cy = h * (0.42 + 0.30 * cos(clock * sp * 1.3 + ph))
                        let r = min(w, h) * (0.24 + 0.06 * sin(clock * sp * 0.7 + ph))
                        let oa = (0.18 + 0.05 * (1 - calm)) * (i == 2 ? 0.55 : 1)        // amber kept fainter
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)),
                                 with: .color(tones[i].opacity(oa)))
                    }
                }
                .blur(radius: 34)               // soft, glowing edges
                .accessibilityHidden(true)
            }
        }
    }
}

struct DaySummaryGlass<Content: View>: View {
    @ViewBuilder var content: Content
    @AppStorage(LiviqaGlass.defaultsKey) private var glassOn = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var opaqueFallback: Bool { reduceTransparency || contrast == .increased }
    private let radius = LiviqaTheme.Radius.hero

    var body: some View {
        let inner = content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if opaqueFallback {
                inner
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(LiviqaTheme.line, lineWidth: 0.5))
            } else if glassOn, #available(iOS 26, *) {
                GlassEffectContainer {
                    inner.glassEffect(.clear, in: .rect(cornerRadius: radius))
                }
            } else {
                inner
                    .background(RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(LiviqaTheme.line, lineWidth: 0.5))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
            }
        }
    }
}

// MARK: - Concentric card

struct ConcentricGlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        let inner = content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)
        return Group {
            if #available(iOS 26, *) {
                inner
                    .clipShape(ConcentricRectangle(corners: .concentric))
                    .overlay(ConcentricRectangle(corners: .concentric).stroke(LiviqaTheme.line, lineWidth: 0.5))
            } else {
                inner
                    .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }
        }
        .shadow(color: solid ? .clear : LiviqaTheme.cardShadow, radius: solid ? 0 : 8, y: solid ? 0 : 2)
    }
}
