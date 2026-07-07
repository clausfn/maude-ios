// MetricBaselineView.swift — Personal-baseline metric detail (Design v2 · the
// Aperture arc hero). "Your normal, never a percentile": the moss arc IS your
// range, today's dot sits on it, and the all-clear state gets some warmth.
// Source: explorations/04-baseline.html (Alternative B).
import SwiftUI

struct BaselineMetric: Identifiable {
    let id = UUID()
    let name: String        // "Heart-rate variability"
    let short: String       // "HRV"
    let value: Double
    let unit: String        // "ms", "h"…
    let normalLow: Double
    let normalHigh: Double
    let warm: String        // affirming line for the in-range state
}

struct MetricBaselineView: View {
    let metric: BaselineMetric
    @Environment(\.dismiss) private var dismiss

    private var inRange: Bool { metric.value >= metric.normalLow && metric.value <= metric.normalHigh }

    private func num(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                NavBackHeader(onBack: { dismiss() }) {
                    Text(metric.short)
                        .font(.lato(15, .black)).foregroundStyle(LiviqaTheme.ink)
                }
                .padding(.top, 6)

                Text(metric.name.uppercased())
                    .font(.liviqaMono(11)).tracking(1.4)
                    .foregroundStyle(LiviqaTheme.ink3)

                ApertureArcGauge(
                    value: metric.value, unit: metric.unit,
                    normalLow: metric.normalLow, normalHigh: metric.normalHigh
                )
                .frame(height: 240)
                .frame(maxWidth: .infinity)

                Text("your normal \(num(metric.normalLow))–\(num(metric.normalHigh)) \(metric.unit)")
                    .font(.liviqaMono(11))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(metric.warm)
                    .font(.lato(15)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                VStack(spacing: 4) {
                    // Metric quick-log and the 90-day baseline history are
                    // follow-up wiring — honest, disabled stubs until they exist.
                    Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                        HStack(spacing: 8) {
                            Text("Log what's working")
                                .font(.lato(15, .bold))
                                .foregroundStyle(LiviqaTheme.ink)
                            Text("SOON").font(.liviqaKicker(8.5)).tracking(1)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(LiviqaTheme.moss2))
                                .foregroundStyle(LiviqaTheme.moss)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13)
                            .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                        HStack(spacing: 8) {
                            Text("See your 90-day baseline ›")
                                .font(.lato(14, .bold))
                                .foregroundStyle(LiviqaTheme.ink3)
                            Text("SOON").font(.liviqaKicker(8.5)).tracking(1)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(LiviqaTheme.moss2))
                                .foregroundStyle(LiviqaTheme.moss)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
                .padding(.top, 6)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}
