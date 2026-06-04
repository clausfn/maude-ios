// NudgeDetailView.swift — Expanded nudge with share affordance.
// Phase 1: Hashable conformance moved to MockData; share button fix; toolbar fix.
import SwiftUI

struct NudgeDetailView: View {
    let nudge: Nudge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Label("Today", systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text(nudge.tag)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(LiviqaTheme.amber2)
                        .foregroundStyle(LiviqaTheme.amber)
                        .clipShape(Capsule())

                    Text(nudge.body)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let reasoning = nudge.reasoning {
                        Text("Why you're seeing this")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LiviqaTheme.ink3)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .padding(.top, 4)
                        Text(reasoning)
                            .font(.footnote)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Data points
                    if !nudge.dataPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(nudge.dataPoints, id: \.self) { point in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(nudge.accent.borderColor)
                                        .frame(width: 5, height: 5)
                                    Text(point)
                                        .font(.caption)
                                        .foregroundStyle(LiviqaTheme.ink2)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(16)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line))

                // CGM trend (gradient area chart)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CGM · LAST SIX RIDES")
                            .font(.liviqaKicker(10.5)).tracking(0.8)
                            .foregroundStyle(LiviqaTheme.ink3)
                        Spacer()
                        Text("−35%").font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
                    }
                    AreaTrendChart(values: [9.1, 8.2, 7.6, 6.9, 6.4, 6.0], tint: LiviqaTheme.moss)
                }
                .padding(14)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Share this pattern with your diabetes nurse?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Only this week's glucose and activity summary — no raw data. Your nurse sees the pattern, not your records. Reversible at any time.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink2)
                    Button("Share via wallet · 7 days") {}
                        .buttonStyle(NudgePrimaryButtonStyle(color: LiviqaTheme.moss))
                }
                .padding(14)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3))

                Text("Related, on your phone")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .textCase(.uppercase)
                    .tracking(0.6)

                NudgeCard(
                    nudge: Nudge(
                        time: "last week",
                        tag: "Hydration",
                        body: "Lower fluid intake on long-ride days correlates with steeper glucose drops in your own trace.",
                        accent: .cardiac,
                        primaryAction: "",
                        secondaryActions: [],
                        reasoning: nil
                    ),
                    compact: true
                )
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .background(LiviqaTheme.paper)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}
