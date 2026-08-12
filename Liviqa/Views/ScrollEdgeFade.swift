// ScrollEdgeFade.swift — the top edge of a reading surface, A7.2.
//
// The device sweep found scrolled content running straight under the status bar
// and the Dynamic Island on every scrolling reading surface: a serif headline or
// a chart bar would slide up and sit half-behind the clock with no treatment at
// all. `liviqaScrollEdgeSoft()` was meant to cover this, but it resolves to
// Apple's `scrollEdgeEffectStyle(.soft)` and is a NO-OP everywhere below iOS 26
// or with the Liquid Glass flag off — which is most of the install base.
//
// So this is the floor: a short paper-coloured fade pinned to the top of the
// window, over the scroll view. It is an OVERLAY, not a mask or a clip — the
// scroll view keeps its full content size, its content offsets are untouched,
// and the DEBUG `LIVIQA_SCROLL_TO=bottom` snapshot hook still scrolls exactly as
// far as it did. It is also `allowsHitTesting(false)`, so nothing under it
// becomes untappable.
//
// The fade is painted in the SAME token as the page canvas (`LiviqaTheme.paper`,
// which is marine in the evening edition), so it reads as the paper itself
// thinning out rather than as a grey scrim laid on top.
import SwiftUI

/// Height of the fade BELOW the safe-area inset — how far the dissolve reaches
/// into the content. Short on purpose: enough to separate the status bar from a
/// moving headline, not enough to hide a line of text.
private let liviqaScrollEdgeBleed: CGFloat = 14

struct LiviqaScrollEdgeFade: ViewModifier {
    /// Reduce Transparency users get a firmer, shorter edge rather than a long
    /// translucent ramp — same purpose, no haze.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            GeometryReader { proxy in
                // The overlay ignores the top safe area, so `safeAreaInsets.top`
                // reports exactly how much of it lies under the status bar /
                // Dynamic Island — the fade sizes itself per device instead of
                // guessing a notch height.
                let inset = proxy.safeAreaInsets.top
                LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
                    .frame(height: inset + (reduceTransparency ? 6 : liviqaScrollEdgeBleed))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Eased alpha ramp — a plain two-stop linear gradient bands visibly against
    /// a flat canvas, so the falloff is shaped by hand.
    private var stops: [Gradient.Stop] {
        if reduceTransparency {
            return [.init(color: LiviqaTheme.paper, location: 0),
                    .init(color: LiviqaTheme.paper, location: 0.82),
                    .init(color: LiviqaTheme.paper.opacity(0), location: 1)]
        }
        return [
            .init(color: LiviqaTheme.paper, location: 0),
            .init(color: LiviqaTheme.paper, location: 0.55),
            .init(color: LiviqaTheme.paper.opacity(0.86), location: 0.72),
            .init(color: LiviqaTheme.paper.opacity(0.52), location: 0.84),
            .init(color: LiviqaTheme.paper.opacity(0.22), location: 0.93),
            .init(color: LiviqaTheme.paper.opacity(0), location: 1)
        ]
    }
}

extension View {
    /// The A7.2 scroll-edge treatment for a scrolling reading surface: the paper
    /// thins out under the status bar / Dynamic Island instead of content
    /// running raw beneath it. Pairs with `liviqaScrollEdgeSoft()` — that one
    /// adds Apple's soft edge effect on iOS 26 with the glass flag on; this one
    /// is the treatment every device gets.
    ///
    /// Apply it to the ScrollView itself. It is safe inside a `ScrollViewReader`
    /// — an overlay changes neither the scroll content nor its anchors, so
    /// `scrollTo` (and the DEBUG snapshot hook that drives it) is untouched.
    func liviqaScrollEdge() -> some View { modifier(LiviqaScrollEdgeFade()) }
}
