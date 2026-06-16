// _GlassLab.swift — Liquid Glass design gallery (DEBUG-only, not shipped).
// Reuses the production components in GlassComponents.swift / LiquidGlass.swift.
// Reach it with the launch argument `-glassLab` (wired in LiviqaApp).
#if DEBUG
import SwiftUI

struct GlassLabView: View {
    @Environment(\.dismiss) private var dismiss
    private static let day: [Double] = [5.1,4.8,5.4,6.2,7.1,8.4,7.2,6.1,5.6,6.8,9.1,7.7,
                                        6.4,5.9,5.2,4.7,5.0,6.3,7.0,6.6,5.8,5.3,5.1,4.9]
    private let availability: String = {
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
                    .foregroundStyle(LiviqaTheme.ink3).padding(.top, 4)

                section("Scrub your day", "A glass thumb on the control plane — drag it across your trace; the reading stays still and opaque, the handle floats and tints moss only when you're in range.") {
                    GlassDayScrubber(samples: Self.day)
                }
                section("Act on a moment", "One calm gesture instead of a modal — the pill morphs open into share-consent · note · why, and back. Tap it.") {
                    HStack { MorphActionCluster(); Spacer() }
                }
                section("Concentric cards", "Corners nest into the container (and the device). Body stays opaque for legibility.") {
                    ConcentricGlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sleep held steady").font(.lato(16, .semibold)).foregroundStyle(LiviqaTheme.ink)
                            Text("Seven nights within your usual window.").font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                        }
                    }
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
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        if #available(iOS 26, *) { content.scrollEdgeEffectStyle(.soft, for: .top) }
        else { content }
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

#Preview { GlassLabView() }
#endif
