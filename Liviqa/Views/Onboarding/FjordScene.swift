// FjordScene.swift — A7.2 onboarding cover art · v01 2026-08-12
// SwiftUI translation of the handoff FjordScene ('dawn') + Cover chrome
// (design_handoff_liviqa_a7/components/f-onboarding.jsx). Calm dawn-fjord:
// layered misty ridgelines, low sun + water reflection, søkort still-water
// hairlines, bottom legibility scrim — drawn, on-brand, no stock people.
//
// COLOURS: scene-specific hex literals are the design spec for this art only
// (CLAUDE.md exception); everything outside the cover uses LiviqaTheme tokens.
// The art is decorative → .accessibilityHidden(true); static (Reduce Motion
// safe by construction). Only the Ready iris + ring backdrop animate, and both
// collapse to a static frame under Reduce Motion.
import SwiftUI

// MARK: - Iris arc geometry (shared by cover rings, ambient rings, Ready iris)

/// One arc of the iris mark, in the mark's 100×100 viewBox (center 50,50).
/// Angles are y-down degrees; the sweep runs visually clockwise, matching the
/// handoff SVG paths exactly (r 40 / 29 / 18 with ~310° sweeps).
struct IrisArc: Shape {
    /// Radius in viewBox units (out of 100; center 50,50).
    var radius: CGFloat
    var startDeg: Double
    var sweepDeg: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 100 * radius
        var p = Path()
        // In SwiftUI's flipped (y-down) space, clockwise:false draws in the
        // direction of increasing angle — visually clockwise, as designed.
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(startDeg),
                 endAngle: .degrees(startDeg + sweepDeg),
                 clockwise: false)
        return p
    }
}

/// The three arcs of the iris. Derived from the locked SVG:
///  outer  r40  M 18.48 25.37 A 40 40 → 10.39 55.57   (218° + 314°)
///  middle r29  M 43.48 78.26 A 29 29 → 69.78 71.21   (103° + 304°)
///  inner  r18  M 67.73 46.87 A 18 18 → 53.13 32.27   (−10° + 290°)
enum IrisGeometry {
    static let outer  = (radius: CGFloat(40), start: 218.0, sweep: 314.0)
    static let middle = (radius: CGFloat(29), start: 103.0, sweep: 304.0)
    static let inner  = (radius: CGFloat(18), start: -10.0, sweep: 290.0)
}

/// Solid-stroke iris mark used on the cover (66pt) and the Ready finale
/// (110pt, stroke-drawn with a staggered trim animation).
struct OnboardingIrisMark: View {
    var size: CGFloat
    /// 0…1 draw progress per ring (inner, middle, outer). 1 = fully drawn.
    var draw: (inner: CGFloat, middle: CGFloat, outer: CGFloat) = (1, 1, 1)

    var body: some View {
        ZStack {
            IrisArc(radius: IrisGeometry.inner.radius,
                    startDeg: IrisGeometry.inner.start,
                    sweepDeg: IrisGeometry.inner.sweep)
                .trim(from: 0, to: draw.inner)
                .stroke(Color(hex: 0xC9A96A),
                        style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
            IrisArc(radius: IrisGeometry.middle.radius,
                    startDeg: IrisGeometry.middle.start,
                    sweepDeg: IrisGeometry.middle.sweep)
                .trim(from: 0, to: draw.middle)
                .stroke(Color(hex: 0x8FE0D6),
                        style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
            IrisArc(radius: IrisGeometry.outer.radius,
                    startDeg: IrisGeometry.outer.start,
                    sweepDeg: IrisGeometry.outer.sweep)
                .trim(from: 0, to: draw.outer)
                .stroke(Color.white.opacity(0.9),
                        style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Oversized glowing iris rings that hang off the cover's top-right corner
/// (and, spinning, behind the Ready iris).
struct IrisRingsBackdrop: View {
    var tealOpacity: Double = 0.5

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: s * 0.0035)
                    .frame(width: s * 0.94, height: s * 0.94)
                IrisArc(radius: IrisGeometry.outer.radius,
                        startDeg: IrisGeometry.outer.start,
                        sweepDeg: IrisGeometry.outer.sweep)
                    .stroke(Color.white.opacity(0.22),
                            style: StrokeStyle(lineWidth: s * 0.006, lineCap: .round))
                IrisArc(radius: IrisGeometry.middle.radius,
                        startDeg: IrisGeometry.middle.start,
                        sweepDeg: IrisGeometry.middle.sweep)
                    .stroke(Color(hex: 0x8FE0D6).opacity(tealOpacity),
                            style: StrokeStyle(lineWidth: s * 0.008, lineCap: .round))
                IrisArc(radius: IrisGeometry.inner.radius,
                        startDeg: IrisGeometry.inner.start,
                        sweepDeg: IrisGeometry.inner.sweep)
                    .stroke(Color(hex: 0xC9A96A).opacity(0.65),
                            style: StrokeStyle(lineWidth: s * 0.01, lineCap: .round))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - FjordScene

/// The drawn dawn-fjord landscape (viewBox 390×500, bottom-anchored slice).
struct FjordScene: View {
    enum Variant { case dawn, dusk }
    var variant: Variant = .dawn

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                // preserveAspectRatio="xMidYMax slice" — fill, anchored bottom-center.
                let scale = max(size.width / 390, size.height / 500)
                ctx.translateBy(x: (size.width - 390 * scale) / 2,
                                y: size.height - 500 * scale)
                ctx.scaleBy(x: scale, y: scale)

                let dawn = variant == .dawn

                // Sky
                let sky = Gradient(stops: [
                    .init(color: Color(hex: dawn ? 0x0E5F5A : 0x0B1B26), location: 0),
                    .init(color: Color(hex: dawn ? 0x0B3F4E : 0x0B1B26), location: 0.55),
                    .init(color: Color(hex: 0x122C46), location: 1)
                ])
                ctx.fill(Path(CGRect(x: 0, y: 0, width: 390, height: 500)),
                         with: .linearGradient(sky,
                                               startPoint: CGPoint(x: 195, y: 0),
                                               endPoint: CGPoint(x: 195, y: 500)))

                // Low sun / moon glow near the horizon
                let glow = Gradient(stops: [
                    .init(color: Color(hex: 0xE9C77E).opacity(0.9), location: 0),
                    .init(color: Color(hex: 0xC9A96A).opacity(0.4), location: 0.4),
                    .init(color: Color(hex: 0xC9A96A).opacity(0), location: 1)
                ])
                let sunCenter = CGPoint(x: 268, y: 250)
                ctx.fill(Path(ellipseIn: CGRect(x: sunCenter.x - 150, y: sunCenter.y - 150,
                                                width: 300, height: 300)),
                         with: .radialGradient(glow, center: sunCenter,
                                               startRadius: 0, endRadius: 150))
                ctx.fill(Path(ellipseIn: CGRect(x: 268 - 26, y: 252 - 26, width: 52, height: 52)),
                         with: .color(Color(hex: dawn ? 0xF0D69A : 0xDCE6EC)
                            .opacity(dawn ? 0.85 : 0.5)))

                // Far ridgeline
                var far = Path()
                far.move(to: CGPoint(x: 0, y: 262))
                far.addCurve(to: CGPoint(x: 190, y: 246),
                             control1: CGPoint(x: 70, y: 244), control2: CGPoint(x: 130, y: 256))
                far.addCurve(to: CGPoint(x: 390, y: 240),
                             control1: CGPoint(x: 250, y: 236), control2: CGPoint(x: 320, y: 250))
                far.addLine(to: CGPoint(x: 390, y: 500))
                far.addLine(to: CGPoint(x: 0, y: 500))
                far.closeSubpath()
                ctx.fill(far, with: .color(Color(hex: 0x0E4152).opacity(0.55)))

                // Mid ridgeline
                var mid = Path()
                mid.move(to: CGPoint(x: 0, y: 288))
                mid.addCurve(to: CGPoint(x: 200, y: 280),
                             control1: CGPoint(x: 60, y: 272), control2: CGPoint(x: 120, y: 292))
                mid.addCurve(to: CGPoint(x: 390, y: 282),
                             control1: CGPoint(x: 280, y: 268), control2: CGPoint(x: 340, y: 292))
                mid.addLine(to: CGPoint(x: 390, y: 500))
                mid.addLine(to: CGPoint(x: 0, y: 500))
                mid.closeSubpath()
                ctx.fill(mid, with: .color(Color(hex: 0x0B3646).opacity(0.8)))

                // Water
                let water = Gradient(stops: [
                    .init(color: Color(hex: 0x0C3140), location: 0),
                    .init(color: Color(hex: 0x08222E), location: 1)
                ])
                ctx.fill(Path(CGRect(x: 0, y: 300, width: 390, height: 200)),
                         with: .linearGradient(water,
                                               startPoint: CGPoint(x: 195, y: 300),
                                               endPoint: CGPoint(x: 195, y: 500)))

                // Sun reflection on the water
                ctx.fill(Path(CGRect(x: 254, y: 300, width: 28, height: 150)),
                         with: .color(Color(hex: dawn ? 0xE9C77E : 0xDCE6EC).opacity(0.12)))

                // Still-water hairlines (søkort)
                for (i, y) in [318, 336, 356, 380, 408].enumerated() {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: CGFloat(y)))
                    line.addLine(to: CGPoint(x: 390, y: CGFloat(y)))
                    ctx.stroke(line,
                               with: .color(Color(hex: 0x8FD8CE)
                                   .opacity(0.12 - Double(i) * 0.015)),
                               lineWidth: 1)
                }
            }

            // Legibility scrim toward the bottom, where the text sits
            LinearGradient(stops: [
                .init(color: Color(hex: 0x0B1B26).opacity(0.30), location: 0),
                .init(color: Color(hex: 0x0B1B26).opacity(0.18), location: 0.30),
                .init(color: Color(hex: 0x0B1B26).opacity(0.50), location: 0.52),
                .init(color: Color(hex: 0x0B1B26).opacity(0.78), location: 0.78),
                .init(color: Color(hex: 0x122C46), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Cover

/// Full-bleed gradient cover — the onboarding's own identity, distinct from
/// the paper app. Gradient 158° #0E5F5A → #0B3F4E → #122C46, fjord scene,
/// aurora glows, oversized iris rings, fine dot texture.
struct OnboardingCover<Content: View>: View {
    var spin = false
    var showScene = true
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("liviqaReduceMotion") private var appReduceMotion = false
    @State private var spinning = false

    private var reduceMotion: Bool { systemReduceMotion || appReduceMotion }

    var body: some View {
        ZStack {
            // 158° base gradient
            LinearGradient(stops: [
                .init(color: Color(hex: 0x0E5F5A), location: 0),
                .init(color: Color(hex: 0x0B3F4E), location: 0.52),
                .init(color: Color(hex: 0x122C46), location: 1)
            ], startPoint: UnitPoint(x: 0.31, y: 0.04),
               endPoint: UnitPoint(x: 0.69, y: 0.96))
            .ignoresSafeArea()

            if showScene {
                FjordScene(variant: .dawn).ignoresSafeArea()
            }

            // Aurora glows
            GeometryReader { geo in
                ZStack {
                    RadialGradient(colors: [Color(hex: 0x0E5F5A).opacity(0.8), .clear],
                                   center: .center, startRadius: 0,
                                   endRadius: geo.size.width * 0.45)
                        .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.55)
                        .blur(radius: 30)
                        .position(x: geo.size.width * 1.0, y: geo.size.height * 0.05)
                    RadialGradient(colors: [Color(hex: 0xC9A96A).opacity(0.28), .clear],
                                   center: .center, startRadius: 0,
                                   endRadius: geo.size.width * 0.38)
                        .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.45)
                        .blur(radius: 34)
                        .position(x: geo.size.width * 0.05, y: geo.size.height * 0.98)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            // Oversized glowing iris rings off the top-right corner
            GeometryReader { geo in
                IrisRingsBackdrop()
                    .frame(width: geo.size.width * 1.5, height: geo.size.width * 1.5)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .position(x: geo.size.width * 1.23,
                              y: geo.size.width * 0.33 - geo.size.height * 0.0)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            // Fine dot texture
            Canvas { ctx, size in
                let step: CGFloat = 22
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                 with: .color(.white.opacity(0.05)))
                        x += step
                    }
                    y += step
                }
            }
            .opacity(0.5)
            .ignoresSafeArea()
            .accessibilityHidden(true)

            content
        }
        .environment(\.colorScheme, .dark)   // white status-bar-adjacent chrome + dark art
        .onAppear {
            guard spin, !reduceMotion else { return }
            withAnimation(.linear(duration: 46).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
    }
}
