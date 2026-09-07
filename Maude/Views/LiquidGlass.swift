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

enum MaudeGlass {
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
enum MaudeBarTier { case liquidGlass, material, opaque }

@MainActor
func maudeBarTier(glassOn: Bool, reduceTransparency: Bool, increasedContrast: Bool) -> MaudeBarTier {
    guard glassOn else { return .opaque }                       // flag off → prior app
    if reduceTransparency || increasedContrast { return .opaque }
    if #available(iOS 26, *) { return .liquidGlass }
    return .material                                            // iOS 17–25, flag on
}

// MARK: - Floating tab-bar surface (three-tier ladder)

/// Tab-bar capsule treatment: real glass (iOS 26 + flag) → `.ultraThinMaterial`
/// (iOS 17–25) → opaque `paper2` (Reduce Transparency / Increase Contrast).
struct MaudeBarGlass: ViewModifier {
    let solid: Bool
    @AppStorage(MaudeGlass.defaultsKey) private var glassOn = true

    func body(content: Content) -> some View {
        if solid {
            content
                .background(Capsule().fill(MaudeTheme.paper2))
                .overlay(Capsule().strokeBorder(MaudeTheme.ink3, lineWidth: 1))
        } else if glassOn, #available(iOS 26, *) {
            content.glassEffect(.regular, in: Capsule())   // real Liquid Glass
        } else {
            content
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(MaudeTheme.line, lineWidth: 0.5))
                .shadow(color: MaudeTheme.cardShadow, radius: 12, y: 4)
        }
    }
}

// MARK: - Soft scroll-edge dissolve (title melts into the feed)

struct MaudeScrollEdgeSoft: ViewModifier {
    @AppStorage(MaudeGlass.defaultsKey) private var glassOn = true
    func body(content: Content) -> some View {
        if glassOn, #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content   // no-op on iOS 17–25 / flag off
        }
    }
}

// MARK: - Hero continuation under the chrome

struct MaudeHeroContinuation: ViewModifier {
    @AppStorage(MaudeGlass.defaultsKey) private var glassOn = true
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

// The Flighty drag-lens is now a real Metal magnification shader (`Magnifier.metal`,
// applied via `.layerEffect` in MainTabView) — it samples and enlarges the actual tab
// icons with chromatic aberration, instead of a frosted `.glassEffect` that can't
// magnify. The chromatic rim is a thin SwiftUI capsule stroke drawn over the shader.

extension View {
    /// Real Liquid Glass on the tab-bar capsule (iOS 26 + flag); Material / opaque otherwise.
    func maudeBarGlass(solid: Bool) -> some View { modifier(MaudeBarGlass(solid: solid)) }
    /// Dissolve the top edge of a ScrollView into the content (iOS 26 + flag); else no-op.
    func maudeScrollEdgeSoft() -> some View { modifier(MaudeScrollEdgeSoft()) }
    /// Let a top hero continue beneath the chrome (iOS 26 + flag, not under reduced transparency).
    func maudeHeroContinuation() -> some View { modifier(MaudeHeroContinuation()) }
}
