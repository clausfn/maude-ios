// LiquidGlass.swift — production Liquid Glass chrome, promoted from the Glass Lab
// (2026-06-16). Applied to real screens behind ONE feature flag, as reversible
// progressive enhancement.
//
// FLAG: @AppStorage("liquidGlass") — default ON. Off → today's app, byte-for-byte.
// FLOOR: deployment target stays iOS 17 (CN: "no exclusive phones"). Real Liquid
// Glass renders ONLY on iOS 26 when the flag is on; iOS 17–25 keep the current
// `.ultraThinMaterial` look; Reduce Transparency / Increase Contrast force the
// opaque fallback. So every device keeps the full app — glass is additive only.
import SwiftUI

enum LiviqaGlass {
    static let defaultsKey = "liquidGlass"
    /// Default ON when unset.
    static var isOn: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }
}

// MARK: - Bar tier resolver (single source of truth)

/// The three render paths the floating tab bar can take. Resolved once at the call
/// site so the bar surface, the travelling pill, and the "flag off = prior app"
/// guarantee all agree.
enum LiviqaBarTier { case liquidGlass, material, opaque }

@MainActor
func liviqaBarTier(glassOn: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> LiviqaBarTier {
    guard glassOn else { return .opaque }                       // flag off → prior app
    if reduceTransparency || increasedContrast { return .opaque }
    if #available(iOS 26, *) { return .liquidGlass }
    return .material                                            // iOS 17–25, flag on
}

/// One travel spring shared by every tier so the motion identity is constant whether
/// the pill is real glass, material, or solid. (Same 0.34/0.82 the bar already used.)
enum LiviqaBarMotion {
    static let travel: Animation = .spring(response: 0.34, dampingFraction: 0.82)
}

// MARK: - Floating tab-bar surface (three-tier ladder)

/// Tab-bar capsule treatment: real glass (iOS 26 + flag) → `.ultraThinMaterial`
/// (iOS 17–25) → opaque `paper2` (Reduce Transparency / Increase Contrast).
struct LiviqaBarGlass: ViewModifier {
    let solid: Bool
    @AppStorage(LiviqaGlass.defaultsKey) private var glassOn = true

    func body(content: Content) -> some View {
        if solid {
            content
                .background(Capsule().fill(LiviqaTheme.paper2))
                .overlay(Capsule().strokeBorder(LiviqaTheme.ink3, lineWidth: 1))
        } else if glassOn, #available(iOS 26, *) {
            content.glassEffect(.regular, in: Capsule())   // real Liquid Glass
        } else {
            content
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(LiviqaTheme.line, lineWidth: 0.5))
                .shadow(color: LiviqaTheme.cardShadow, radius: 12, y: 4)
        }
    }
}

// MARK: - Soft scroll-edge dissolve (title melts into the feed)

struct LiviqaScrollEdgeSoft: ViewModifier {
    @AppStorage(LiviqaGlass.defaultsKey) private var glassOn = true
    func body(content: Content) -> some View {
        if glassOn, #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content   // no-op on iOS 17–25 / flag off
        }
    }
}

// MARK: - Hero continuation under the chrome

struct LiviqaHeroContinuation: ViewModifier {
    @AppStorage(LiviqaGlass.defaultsKey) private var glassOn = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        if glassOn, !(reduceTransparency || contrast == .increased), #available(iOS 26, *) {
            content.backgroundExtensionEffect()
        } else {
            content
        }
    }
}

// MARK: - Travelling glass magnifier (the gliding active-tab lens, Flighty-style)

/// The selected-tab pill that travels to the active tab.
///
/// - `.liquidGlass` (iOS 26): a REAL Liquid Glass lens — `.glassEffect` + `.glassEffectID`
///   inside the bar's `GlassEffectContainer`, so the pill MERGES with the bar's glass
///   into one continuous lens (the fix for the old "glass-on-glass is muddy" problem)
///   and morphs fluidly as it travels. Near-clear tint so it reads as a lens that
///   refracts the bar content behind it, not a frosted chip. A thin chromatic rim adds
///   the Flighty edge glint, flaring only while travelling.
/// - `.material` (iOS 17–25): a `.ultraThinMaterial` pill that still travels/springs.
/// - `.opaque` (Reduce Transparency / Increase Contrast): the solid moss pill (no blur).
///
/// The pill never takes touches — taps fall through to the tab buttons underneath.
struct TravellingTabPill: View {
    let tier: LiviqaBarTier
    let travelling: Bool               // true while the spring is in flight → ramp the rim
    let reduceMotion: Bool

    private let shape = Capsule()

    var body: some View {
        switch tier {
        case .liquidGlass:
            if #available(iOS 26, *) {
                shape
                    .glassEffect(.regular.tint(LiviqaTheme.moss.opacity(0.06)).interactive(),
                                 in: Capsule())
                    .overlay(chromaticRim)
                    .allowsHitTesting(false)
            }
        case .material:
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.strokeBorder(LiviqaTheme.line, lineWidth: 0.5))
                .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
                .allowsHitTesting(false)
        case .opaque:
            shape.fill(LiviqaTheme.moss2)
                .overlay(shape.strokeBorder(LiviqaTheme.moss3, lineWidth: 1))
                .allowsHitTesting(false)
        }
    }

    /// Thin angular-gradient glint on the RIM only (never a fill), `.plusLighter` so it
    /// reads as specular dispersion, not paint. Brand moss (the bar's own selection hue)
    /// drifting through clear gaps — calm, no full RGB spectrum. Rest 0.20; flares to
    /// ~0.45 only while travelling, and never under Reduce Motion.
    @ViewBuilder private var chromaticRim: some View {
        let strength = (travelling && !reduceMotion) ? 0.45 : 0.20
        shape
            .strokeBorder(
                AngularGradient(
                    colors: [
                        LiviqaTheme.moss,
                        .white.opacity(0.0),
                        LiviqaTheme.heroGlow,
                        .white.opacity(0.0),
                        LiviqaTheme.moss
                    ],
                    center: .center
                ),
                lineWidth: 1.0
            )
            .blendMode(.plusLighter)
            .opacity(strength)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: travelling)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Real Liquid Glass on the tab-bar capsule (iOS 26 + flag); Material / opaque otherwise.
    func liviqaBarGlass(solid: Bool) -> some View { modifier(LiviqaBarGlass(solid: solid)) }
    /// Dissolve the top edge of a ScrollView into the content (iOS 26 + flag); else no-op.
    func liviqaScrollEdgeSoft() -> some View { modifier(LiviqaScrollEdgeSoft()) }
    /// Let a top hero continue beneath the chrome (iOS 26 + flag, not under reduced transparency).
    func liviqaHeroContinuation() -> some View { modifier(LiviqaHeroContinuation()) }
}
