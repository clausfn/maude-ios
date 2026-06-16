// _GlassLab.swift — Liquid Glass DESIGN EXPLORATION (DEBUG-only, not shipped).
//
// A self-contained lab for the iOS 26 Liquid Glass concepts (curator winning set,
// 2026-06-16). Compiled ONLY in Debug (#if DEBUG) so it can never affect a
// TestFlight/Release build and touches no locked screen. Reach it with the launch
// argument `-glassLab` (wired in LiviqaApp).
//
// THREE-TIER LADDER on every effect (CN: "no exclusive phones" — iOS 17 floor stays):
//   (1) iOS 26+            → real Liquid Glass
//   (2) iOS 17–25          → the current `.ultraThinMaterial` look (graceful fallback)
//   (3) Reduce Transparency / Increase Contrast → opaque `LiviqaTheme.paper2`, no shadow
// Motion resolves to its RESTING state under `LiviqaMotion.reduced(_:)`.
// Nothing here is promoted to a real screen until CN signs off a specific concept.
#if DEBUG
import SwiftUI

// MARK: - Shared accessibility gate

private struct GlassEnv {
    var reduceTransparency: Bool
    var increaseContrast: Bool
    var reduceMotionSystem: Bool
    /// Matches the shipped `MainTabView.useSolidBar` boolean exactly.
    var solid: Bool { reduceTransparency || increaseContrast }
}

// MARK: - 1 · GlassScrubber (the "slider over the menu bar") + ScrubReadout

/// Pure visual thumb; the demo cell owns position, drag and the a11y action so the
/// thumb stays reusable. Tint = moss ONLY when in range (meaning-only tint).
struct GlassScrubberThumb: View {
    var inRange: Bool
    var label: String
    var pressing: Bool
    var namespace: Namespace.ID

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotionSystem

    private var solid: Bool { reduceTransparency || contrast == .increased }
    private var reduceMotion: Bool { LiviqaMotion.reduced(reduceMotionSystem) }
    private var pressScale: CGFloat { (pressing && !reduceMotion) ? 1.12 : 1 }

    var body: some View {
        let shape = Capsule()
        let content = HStack(spacing: 7) {
            Circle().fill(inRange ? LiviqaTheme.moss : LiviqaTheme.clay)
                .frame(width: 7, height: 7)
            Text(label).font(.liviqaMono(12)).foregroundStyle(LiviqaTheme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)

        return Group {
            if solid {
                content
                    .background(shape.fill(LiviqaTheme.paper2))
                    .overlay(shape.strokeBorder(inRange ? LiviqaTheme.moss : LiviqaTheme.ink3, lineWidth: 1))
            } else if #available(iOS 26, *) {
                content
                    .glassEffect(inRange
                        ? .regular.tint(LiviqaTheme.moss.opacity(0.5)).interactive()
                        : .regular.interactive(),
                        in: shape)
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

/// The calm, OPAQUE partner — the number you read is still while the thumb moves.
struct ScrubReadout: View {
    var value: String, unit: String, time: String, inRange: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value).font(.liviqaMono(22)).foregroundStyle(LiviqaTheme.ink)
            Text(unit).font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
            Spacer()
            HStack(spacing: 6) {
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

private struct ScrubberDemo: View {
    // A day of readings (mmol/L) — a representative glucose trace for the lab.
    private let samples: [Double] = [5.1,4.8,5.4,6.2,7.1,8.4,7.2,6.1,5.6,6.8,9.1,7.7,
                                     6.4,5.9,5.2,4.7,5.0,6.3,7.0,6.6,5.8,5.3,5.1,4.9]
    @State private var progress: Double = 0.46
    @State private var pressing = false
    @Namespace private var glassNS

    private var value: Double {
        let x = progress * Double(samples.count - 1)
        let i = min(samples.count - 2, max(0, Int(x)))
        let f = x - Double(i)
        return samples[i] + (samples[i+1] - samples[i]) * f
    }
    private var inRange: Bool { value >= 3.9 && value <= 10 }
    private var timeLabel: String {
        let mins = Int(progress * 24 * 60)
        return String(format: "%02d:%02d", mins / 60, mins % 60)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrubReadout(value: String(format: "%.1f", value), unit: "mmol/L",
                         time: timeLabel, inRange: inRange)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack(alignment: .topLeading) {
                    trace(in: CGSize(width: w, height: h))
                    Rectangle().fill(LiviqaTheme.line)
                        .frame(width: 1, height: h)
                        .offset(x: progress * w)
                    GlassEffectContainerCompat {
                        GlassScrubberThumb(inRange: inRange, label: "\(String(format: "%.1f", value)) · \(timeLabel)",
                                           pressing: pressing, namespace: glassNS)
                    }
                    .alignmentGuide(.top) { $0[.top] }
                    .position(x: min(max(54, progress * w), w - 54), y: h + 26)
                    .accessibilityElement()
                    .accessibilityLabel("Scrub the day")
                    .accessibilityValue("\(String(format: "%.1f", value)) mmol per litre at \(timeLabel)")
                    .accessibilityAdjustableAction { dir in
                        let step = 1.0 / 24.0
                        progress = min(1, max(0, progress + (dir == .increment ? step : -step)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            pressing = true
                            progress = min(1, max(0, v.location.x / w))
                        }
                        .onEnded { _ in pressing = false }
                )
            }
            .frame(height: 96)
            .padding(.bottom, 30)   // room for the thumb that floats below the trace
        }
    }

    private func trace(in size: CGSize) -> some View {
        let lo = 3.5, hi = 9.5
        func pt(_ i: Int) -> CGPoint {
            let x = CGFloat(i) / CGFloat(samples.count - 1) * size.width
            let n = (samples[i] - lo) / (hi - lo)
            return CGPoint(x: x, y: size.height * (1 - CGFloat(n)))
        }
        return ZStack {
            Path { p in
                p.move(to: pt(0)); for i in 1..<samples.count { p.addLine(to: pt(i)) }
            }
            .stroke(LiviqaTheme.moss.opacity(0.85), style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            Path { p in
                p.move(to: CGPoint(x: 0, y: size.height)); p.addLine(to: pt(0))
                for i in 1..<samples.count { p.addLine(to: pt(i)) }
                p.addLine(to: CGPoint(x: size.width, y: size.height)); p.closeSubpath()
            }
            .fill(LinearGradient(colors: [LiviqaTheme.moss.opacity(0.18), .clear],
                                 startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - 2 · MorphActionCluster (one pill morphs into 3 actions)

struct MorphActionCluster: View {
    var onShareConsent: () -> Void = {}
    var onJournal: () -> Void = {}
    var onEvidence: () -> Void = {}

    @State private var expanded = false
    @Namespace private var glass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var solid: Bool { reduceTransparency || contrast == .increased }
    private var reduceMotion: Bool { LiviqaMotion.reduced(systemReduceMotion) }
    private var anim: Animation? { reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82) }

    var body: some View {
        Group {
            if #available(iOS 26, *), !solid {
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
            .modifier(GlassPill(id: "a", ns: glass, solid: solid, prominent: false))
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
        .modifier(GlassPill(id: id, ns: glass, solid: solid, prominent: prominent))
    }
}

private struct GlassPill: ViewModifier {
    let id: String, ns: Namespace.ID, solid: Bool, prominent: Bool
    func body(content: Content) -> some View {
        let shape = Capsule()
        return Group {
            if solid {
                content
                    .background(shape.fill(prominent ? LiviqaTheme.moss : LiviqaTheme.paper2))
                    .overlay(shape.strokeBorder(prominent ? LiviqaTheme.moss : LiviqaTheme.ink3, lineWidth: 1))
            } else if #available(iOS 26, *) {
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

// MARK: - 3 · Concentric corner card (nests in the device corners)

struct ConcentricGlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var solid: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        let body = content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)   // content surface stays opaque (legibility)
        return Group {
            if #available(iOS 26, *) {
                body
                    .clipShape(ConcentricRectangle(corners: .concentric))
                    .overlay(ConcentricRectangle(corners: .concentric).stroke(LiviqaTheme.line, lineWidth: 0.5))
            } else {
                body
                    .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).strokeBorder(LiviqaTheme.line, lineWidth: 0.5))
            }
        }
        .shadow(color: solid ? .clear : LiviqaTheme.cardShadow, radius: solid ? 0 : 8, y: solid ? 0 : 2)
    }
}

// MARK: - 4 · Tideline ambient field + clear-glass day summary

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
                let t = still ? phase
                    : phase + 0.5 * (1 + sin(tl.date.timeIntervalSinceReferenceDate * (2 * .pi / breathPeriod))) * 0.04
                Canvas { ctx, size in
                    let tideY = size.height * (0.62 - 0.18 * t)
                    let a = 0.10 + 0.06 * (1 - calm)
                    let top = LiviqaTheme.heroGlow.opacity(a)
                    let bot = LiviqaTheme.moss.opacity(a * 0.6)
                    let rect = Path(CGRect(origin: .zero, size: size))
                    ctx.fill(rect, with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: top, location: max(0, tideY / size.height - 0.15)),
                            .init(color: bot, location: 1),
                        ]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                }
                .blur(radius: 36)
                .accessibilityHidden(true)
            }
        }
    }
}

struct DaySummaryGlass<Content: View>: View {
    @ViewBuilder var content: Content
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
            } else if #available(iOS 26, *) {
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

// MARK: - 5 · Hero continuation (backgroundExtensionEffect)

struct HeroExtension<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var opaqueFallback: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        if opaqueFallback {
            content.background(LiviqaTheme.paper2)
        } else if #available(iOS 26, *) {
            content.backgroundExtensionEffect()
        } else {
            content.background(LiviqaTheme.heroGlow.blur(radius: 28))
        }
    }
}

// MARK: - Compatibility container (real container on 26, passthrough below)

/// Groups glass into ONE sampling region on iOS 26 (HIG: never stack glass);
/// a plain passthrough on iOS 17–25 where there is no real glass to group.
struct GlassEffectContainerCompat<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if #available(iOS 26, *) { GlassEffectContainer { content } }
        else { content }
    }
}

// MARK: - The Glass Lab gallery

struct GlassLabView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var availability: String = {
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
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 4)

                section("Scrub your day", "A glass thumb on the control plane — drag it across your trace; the reading stays still and opaque, the handle floats and tints moss only when you're in range.") {
                    ScrubberDemo()
                }
                section("Act on a moment", "One calm gesture instead of a modal — the pill morphs open into share-consent · note · why, and back. Tap it.") {
                    HStack { MorphActionCluster(); Spacer() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                section("Concentric cards", "Corners nest into the container (and the device), so the card reads as poured into the hardware, not stamped on top. Body stays opaque for legibility.") {
                    ConcentricGlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sleep held steady").font(.lato(16, .semibold)).foregroundStyle(LiviqaTheme.ink)
                            Text("Seven nights within your usual window.").font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                        }
                    }
                    .containerShapeCompat()
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
                section("Hero continuation", "The hero softly continues beneath the chrome, so controls rest over a continuation of your own data, not a hard edge.") {
                    HeroExtension {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.fill").font(.system(size: 26)).foregroundStyle(LiviqaTheme.moss)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Resting heart rate").font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                                Text("58 bpm").font(.liviqaMono(24)).foregroundStyle(LiviqaTheme.ink)
                            }
                            Spacer()
                        }
                        .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        // RECEDE: the title dissolves into the feed instead of a hard bar.
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
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

private extension View {
    /// Sets a concentric container shape on iOS 26 so child ConcentricRectangles nest.
    @ViewBuilder func containerShapeCompat() -> some View {
        if #available(iOS 26, *) {
            self.containerShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.hero))
        } else { self }
    }
}

#Preview { GlassLabView() }
#endif
