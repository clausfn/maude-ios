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

// MARK: - Glass magnifier bubble (the Flighty drag-lens)

/// A LARGE glass bubble that appears under the finger on touch, tracks it across the
/// bar, magnifies the tab it's over, and vanishes on lift. NOT a selection pill — it is
/// a transient, interactive lens.
///
/// - `.liquidGlass` (iOS 26): a real CLEAR Liquid Glass lens (no tint) that refracts
///   the content behind it, with a chromatic rim glint — the Flighty look.
/// - `.material` (iOS 17–25): a `.ultraThinMaterial` bubble (no real refraction).
/// - `.opaque` (Reduce Transparency / Increase Contrast): a solid `paper2` bubble.
///
/// The magnified glyph is drawn over the bubble at the call site. The bubble never takes
/// touches — the bar's drag gesture drives it.
struct GlassMagnifierBubble: View {
    let tier: LiviqaBarTier
    private let shape = Circle()

    var body: some View {
        Group {
            switch tier {
            case .liquidGlass:
                if #available(iOS 26, *) {
                    shape
                        .glassEffect(.regular.interactive(), in: Circle())   // clear lens → it magnifies
                        .overlay(chromaticRim)
                }
            case .material:
                shape.fill(.ultraThinMaterial)
                    .overlay(shape.strokeBorder(LiviqaTheme.line, lineWidth: 0.5))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 3)
            case .opaque:
                shape.fill(LiviqaTheme.paper2)
                    .overlay(shape.strokeBorder(LiviqaTheme.ink3, lineWidth: 1))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
            }
        }
        .allowsHitTesting(false)
    }

    /// Thin angular-gradient glint on the rim (`.plusLighter` so it reads as specular
    /// dispersion, not paint) — brand moss + heroGlow through clear gaps, calm, no full
    /// RGB spectrum.
    private var chromaticRim: some View {
        shape
            .strokeBorder(
                AngularGradient(
                    colors: [LiviqaTheme.moss, .white.opacity(0.0), LiviqaTheme.heroGlow,
                             .white.opacity(0.0), LiviqaTheme.moss],
                    center: .center
                ),
                lineWidth: 1.0
            )
            .blendMode(.plusLighter)
            .opacity(0.55)
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
