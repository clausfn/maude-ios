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

extension View {
    /// Real Liquid Glass on the tab-bar capsule (iOS 26 + flag); Material / opaque otherwise.
    func liviqaBarGlass(solid: Bool) -> some View { modifier(LiviqaBarGlass(solid: solid)) }
    /// Dissolve the top edge of a ScrollView into the content (iOS 26 + flag); else no-op.
    func liviqaScrollEdgeSoft() -> some View { modifier(LiviqaScrollEdgeSoft()) }
    /// Let a top hero continue beneath the chrome (iOS 26 + flag, not under reduced transparency).
    func liviqaHeroContinuation() -> some View { modifier(LiviqaHeroContinuation()) }
}
