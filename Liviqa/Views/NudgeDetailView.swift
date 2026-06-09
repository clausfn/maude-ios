// NudgeDetailView.swift — The correlation moment (Design System v2 · Alternative C).
// The most behaviour-change-heavy screen in the app: comprehend → trust → name
// the lever. A plain declarative sentence is the hero, one quiet chart confirms
// it, N·baseline·r·p sit beneath, the lever is named, and the raw data is one tap
// away. Below the gate (r≥0.4, p≤0.05, N≥need) we REFUSE to assert — the
// still-learning state is the whole trust mechanism.
// Source: explorations/01-correlation-moment.html
import SwiftUI

struct NudgeDetailView: View {
    let nudge: Nudge
    @Environment(\.dismiss) private var dismiss
    @State private var showDepth = false

    private var ev: NudgeEvidence? { nudge.evidence }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                NavBackHeader(onBack: { dismiss() }) {
                    if let ev { ConfidenceChip(confidence: ev.confidence) }
                }
                .padding(.top, 6)

                if let ev, ev.confidence == .learning {
                    stillLearning(ev)
                } else {
                    asserted
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: — Asserted (gated / emerging)

    private var asserted: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Tag kicker
            Text(nudge.tag.uppercased())
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(nudge.accent.accentColor)
                .padding(.top, 6)

            // 01 — Comprehend: the plain declarative sentence
            Text(ev?.headline ?? nudge.body)
                .font(.lato(26, .black)).kerning(-0.6)
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            // 03 — the lever, named
            if let lever = ev?.lever {
                LeverCallout(text: lever)
            }

            // 02 — Confirm: one quiet chart
            if let ev, let pct = ev.chartPercent {
                SingleConfirmBar(
                    label: ev.chartLabel ?? "IN YOUR DATA",
                    percent: pct,
                    caption: ev.chartCaption
                )
            } else {
                trendFallback
            }

            // 03 — Trust: evidence metadata, always on
            if let ev { EvidenceMetadataRow(evidence: ev) }

            // 04 — Depth on tap
            Button { withAnimation(.easeInOut(duration: 0.2)) { showDepth.toggle() } } label: {
                HStack(spacing: 6) {
                    Text(showDepth ? "Hide the data" : "See the data behind this")
                        .font(.lato(14, .bold))
                    Image(systemName: showDepth ? "chevron.up" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if showDepth { depthTier }

            // Reasoning (why you're seeing this)
            if let reasoning = nudge.reasoning {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why you're seeing this".uppercased())
                        .font(.liviqaKicker(9.5)).tracking(1)
                        .foregroundStyle(LiviqaTheme.ink3)
                    Text(reasoning)
                        .font(.lato(13)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            // Primary action
            if !nudge.primaryAction.isEmpty {
                Button { } label: {
                    Text(nudge.primaryAction)
                        .font(.lato(15, .bold))
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LiviqaTheme.invertBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            shareCard
        }
    }

    // Depth tier — the threshold split (B). Shown on tap for whoever wants more.
    private var depthTier: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The split, before and after your lever".uppercased())
                .font(.liviqaKicker(9.5)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
            if let ev, let pct = ev.chartPercent {
                HStack(alignment: .bottom, spacing: 16) {
                    splitBar(title: "Before", value: 1 - pct, color: LiviqaTheme.moss, height: 56)
                    splitBar(title: "After", value: pct, color: LiviqaTheme.clay, height: 120)
                }
                .frame(maxWidth: .infinity)
            }
            Text("The continuous relationship (the overlay timeline and scatter) lives in your full history — this split is the part you can act on.")
                .font(.lato(12)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    private func splitBar(title: String, value: Double, color: Color, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text("\(Int((value * 100).rounded()))%")
                .font(.lato(22, .black)).foregroundStyle(color == LiviqaTheme.clay ? LiviqaTheme.clayText : LiviqaTheme.moss)
            RoundedRectangle(cornerRadius: 8).fill(color)
                .frame(height: height)
            Text(title).font(.lato(12, .bold)).foregroundStyle(LiviqaTheme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendFallback: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your trend".uppercased())
                .font(.liviqaKicker(10)).tracking(0.8)
                .foregroundStyle(LiviqaTheme.ink3)
            AreaTrendChart(values: [9.1, 8.2, 7.6, 6.9, 6.4, 6.0], tint: LiviqaTheme.moss)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: — Still learning (refuse to assert)

    private func stillLearning(_ ev: NudgeEvidence) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(nudge.tag.uppercased())
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 6)

            Text(ev.headline ?? "We're still learning your baseline.")
                .font(.lato(23, .black)).kerning(-0.5)
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Text(nudge.body)
                .font(.lato(14)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)

            BaselineProgressBar(
                label: "Baseline progress",
                have: ev.n,
                need: ev.baselineNeeded ?? max(ev.n, 30)
            )

            EvidenceMetadataRow(evidence: ev, dimmed: true)

            if let note = ev.learningNote {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("●").font(.system(size: 9)).foregroundStyle(LiviqaTheme.moss)
                    Text(note)
                        .font(.lato(12.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: — Share (genericised · FR-REG-03 — no condition/recipient hard-coding)

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share this pattern with someone you trust?")
                .font(.lato(15, .bold))
                .foregroundStyle(LiviqaTheme.moss)
            Text("Only this insight and its summary — never your raw data, which stays on your device. You choose the recipient and the window, and you can withdraw any time.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button { } label: {
                Text("Share via wallet")
                    .font(.lato(13.5, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(LiviqaTheme.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .padding(.top, 4)
    }
}
