// ScrollEdgeFade.swift — both edges of a reading surface, A7.2.
//
// The device sweep found scrolled content running straight under the status bar
// and the Dynamic Island on every scrolling reading surface: a serif headline or
// a card header would slide up and sit half-behind the clock with no treatment
// at all. `maudeScrollEdgeSoft()` was meant to cover this, but it resolves to
// Apple's `scrollEdgeEffectStyle(.soft)` and is a NO-OP everywhere below iOS 26
// or with the Liquid Glass flag off — which is most of the install base.
//
// The first floor attempt (13 Aug) still failed, and the reason is worth keeping
// written down: it sized the fade from `proxy.safeAreaInsets.top` inside a
// `GeometryReader` that had `.ignoresSafeArea(edges: .top)` applied to it.
// Ignoring an edge CONSUMES that inset for the subtree, so the proxy reported
// **0** and the fade rendered 14 pt tall at the very top of the window — present,
// measurable, and invisible. Nothing about the colour or the layer order was
// wrong; the height was.
//
// There is a second trap underneath that one, and the device run found it: an
// `.overlay` is laid out inside its host's SAFE AREA even when the host's own
// content is not. A band aligned to the top of the overlay therefore starts
// below the clock — the second attempt drew a correct-looking fade in the wrong
// place, hovering just under the status bar while the card kept printing through
// it. Both facts have to be handled at once:
//
//   • the band ignores the top safe area, so it reaches the strip the Island
//     sits on;
//   • its HEIGHT and its opaque-vs-ramp split come from `MaudeWindowInsets.top`
//     — the window's own inset — because the ignore has just zeroed every
//     `GeometryReader` reading of it inside that subtree.
//
// The strip is fully opaque for the whole inset and only then eases out across
// the bleed, so nothing shows through beside the clock.
//
// Both bands are OVERLAYS, not masks or clips — the scroll view keeps its full
// content size, its content offsets are untouched, and the DEBUG
// `MAUDE_SCROLL_TO=bottom` snapshot hook still scrolls exactly as far as it did.
// They are `allowsHitTesting(false)`, so nothing under them becomes untappable.
//
// The fade is painted in the SAME token as the page canvas (`MaudeTheme.paper`,
// which is marine in the evening edition), so a card or a chart passing beneath
// it reads as dissolving into the paper rather than as a grey scrim laid on top.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// How far the top dissolve reaches BELOW the status bar, into the content.
/// Short on purpose: enough to separate the clock from a moving headline, not
/// enough to hide a line of text.
private let maudeTopBleed: CGFloat = 22
/// The bottom counterpart — content thinning out before the floating tab bar
/// instead of being hard-cut by it.
private let maudeBottomBleed: CGFloat = 28
/// Reduce Transparency gets a firmer, shorter ramp — same purpose, no haze.
private let maudeTopBleedFirm: CGFloat = 8
private let maudeBottomBleedFirm: CGFloat = 12

/// Window-level safe area. Read from the active window rather than from a
/// `GeometryReader` proxy, because any `ignoresSafeArea` between the window and
/// the reader silently zeroes the proxy's copy (that is exactly what broke the
/// first attempt at this treatment).
enum MaudeWindowInsets {
    /// Top inset of the active window — the status-bar / Dynamic Island strip.
    /// Falls back to a modern notch height only if no window is up yet.
    static var top: CGFloat {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first { $0.activationState == .foregroundActive }?.keyWindow
            ?? scenes.first?.keyWindow
        if let inset = window?.safeAreaInsets.top, inset > 0 { return inset }
        #endif
        return 47
    }
}

struct MaudeScrollEdgeFade: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var topBleed: CGFloat { reduceTransparency ? maudeTopBleedFirm : maudeTopBleed }
    private var bottomBleed: CGFloat { reduceTransparency ? maudeBottomBleedFirm : maudeBottomBleed }

    func body(content: Content) -> some View {
        content
            // TOP — pinned to the WINDOW's top edge, not the scroll view's. An
            // `.overlay` is laid out inside the host's safe area even when the
            // host's own content is not, so the band must ignore the top edge
            // to reach the strip the Island sits on; its HEIGHT then has to
            // come from the window, because ignoring an edge zeroes the proxy's
            // copy of that inset.
            .overlay(alignment: .top) {
                LinearGradient(stops: topStops(), startPoint: .top, endPoint: .bottom)
                    .frame(height: MaudeWindowInsets.top + topBleed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // BOTTOM — the mirror. The scroll view already stops above the
            // floating tab bar, so this one stays inside the host's frame.
            .overlay(alignment: .bottom) {
                LinearGradient(stops: bottomStops(), startPoint: .top, endPoint: .bottom)
                    .frame(height: bottomBleed)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    /// Opaque paper for the whole strip the chrome sits on, then an eased ramp
    /// across the bleed. The stops are computed from real point heights, not
    /// from fixed fractions — a fraction-based ramp starts dissolving while
    /// still under the clock, which is where cover matters most.
    private func topStops() -> [Gradient.Stop] {
        let solid = MaudeWindowInsets.top
        let total = solid + topBleed
        guard total > 0 else { return [.init(color: MaudeTheme.paper.opacity(0), location: 0)] }
        let s = min(0.999, max(0, solid / total))
        let ramp = 1 - s
        if reduceTransparency {
            return [.init(color: MaudeTheme.paper, location: 0),
                    .init(color: MaudeTheme.paper, location: s + ramp * 0.7),
                    .init(color: MaudeTheme.paper.opacity(0), location: 1)]
        }
        return [
            .init(color: MaudeTheme.paper, location: 0),
            .init(color: MaudeTheme.paper, location: s),
            .init(color: MaudeTheme.paper.opacity(0.82), location: s + ramp * 0.30),
            .init(color: MaudeTheme.paper.opacity(0.48), location: s + ramp * 0.55),
            .init(color: MaudeTheme.paper.opacity(0.18), location: s + ramp * 0.78),
            .init(color: MaudeTheme.paper.opacity(0), location: 1)
        ]
    }

    /// The mirror ramp: transparent where the content still reads, paper where
    /// the tab bar is about to take over.
    private func bottomStops() -> [Gradient.Stop] {
        if reduceTransparency {
            return [.init(color: MaudeTheme.paper.opacity(0), location: 0),
                    .init(color: MaudeTheme.paper, location: 0.35),
                    .init(color: MaudeTheme.paper, location: 1)]
        }
        // Weighted late: a line of text sitting just above the cut stays fully
        // legible, and only the last few points feather out. A symmetric ramp
        // here veils the bottom-most row of a card, which is worse than the
        // hard cut it replaces.
        return [
            .init(color: MaudeTheme.paper.opacity(0), location: 0),
            .init(color: MaudeTheme.paper.opacity(0.08), location: 0.45),
            .init(color: MaudeTheme.paper.opacity(0.30), location: 0.68),
            .init(color: MaudeTheme.paper.opacity(0.68), location: 0.86),
            .init(color: MaudeTheme.paper, location: 1)
        ]
    }
}

extension View {
    /// The A7.2 scroll-edge treatment for a scrolling reading surface: the paper
    /// thins out under the status bar / Dynamic Island at the top and into the
    /// floating tab bar at the bottom, instead of content running raw beneath
    /// either. Pairs with `maudeScrollEdgeSoft()` — that one adds Apple's soft
    /// edge effect on iOS 26 with the glass flag on; this one is the treatment
    /// every device gets.
    ///
    /// Apply it to the ScrollView itself. It is safe inside a `ScrollViewReader`
    /// — an overlay changes neither the scroll content nor its anchors, so
    /// `scrollTo` (and the DEBUG snapshot hook that drives it) is untouched.
    func maudeScrollEdge() -> some View { modifier(MaudeScrollEdgeFade()) }
}
