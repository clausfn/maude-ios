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
    @Environment(AppState.self) private var appState
    @AppStorage("liquidGlass") private var glassOn = true
    @State private var showDepth = false
    @State private var showShare = false
    /// UC-19 / FR-PMS-01 — the report-a-wrong-nudge sheet.
    @State private var showReport = false
    /// FR-XPL-01 — the same "See why" disclosure the rest of the app uses. The
    /// N·r·p row below stays exactly where it was; this adds the plain-language
    /// reading of it, and the deep link to the published evidence gate.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var ev: NudgeEvidence? { nudge.evidence }

    /// The evidence row, said in words rather than chips.
    private func evidenceWhy(_ verdict: String) -> SeeWhyExplanation {
        guard let ev else {
            return SeeWhyExplanation(
                id: "nudge.evidence", surface: String(localized: "Insight · the evidence"),
                verdict: verdict,
                unexplained: String(localized: "This insight carries no evidence record, so there are no figures to take apart. If it reads like a claim about your health, report it — that route is at the bottom of this screen."),
                method: .evidenceGate)
        }
        return SeeWhyExplainer.nudge(
            verdict: verdict, n: ev.n, nUnit: ev.nUnit,
            baselineDays: ev.baselineDays, r: ev.r, pText: ev.p,
            isGated: ev.confidence != .learning,
            baselineNeeded: ev.baselineNeeded)
    }

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

                discussInAssistant

                reportAffordance
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .sheet(isPresented: $showShare) {
            ShareWithClinicianView(nudge: nudge, onDismiss: { showShare = false })
        }
        .sheet(isPresented: $showReport) {
            ReportNudgeView(nudge: nudge)
        }
        .seeWhySheet($seeWhy, appState: appState)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: — Discuss in the assistant (Oura "Advisor" hand-off, descriptive-only)

    private var discussInAssistant: some View {
        Button {
            appState.showAssistant = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.lato(13, .bold))
                Text("Discuss in the assistant").font(.lato(14, .bold))
            }
            .foregroundStyle(LiviqaTheme.moss)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    // MARK: — Report this insight (UC-19 / FR-PMS-01 — the PMS entry point)

    /// Quiet, always-present affordance: if an insight felt wrong or unsafe,
    /// reporting it must never be hard to find — and never look like an alarm.
    private var reportAffordance: some View {
        Button { showReport = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 11, weight: .semibold))
                Text("Report this insight")
                    .font(.lato(12.5, .semibold))
            }
            .foregroundStyle(LiviqaTheme.ink3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Tell Liviqa's safety monitoring this insight felt wrong or unsafe"))
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
                .font(.liviqaSerif(26)).kerning(-0.2)
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            // FR-XPL-01 — the universal affordance, in the same place it sits on
            // every other verdict: directly under the sentence it explains.
            SeeWhyChip { seeWhy = evidenceWhy(ev?.headline ?? nudge.body) }

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

            // Primary action — per-nudge handlers (reminders, journal hand-off…)
            // are follow-up wiring, so this must not look live (honest "soon" stub).
            if !nudge.primaryAction.isEmpty {
                Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                    HStack(spacing: 8) {
                        Text(nudge.primaryAction)
                            .font(.lato(15, .bold))
                            .foregroundStyle(LiviqaTheme.ink)
                        Spacer(minLength: 6)
                        Text("SOON").font(.liviqaKicker(8.5)).tracking(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(LiviqaTheme.moss2))
                            .foregroundStyle(LiviqaTheme.moss)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .disabled(true)
            }

            // Liquid Glass "act on this moment" affordance (flagged exploration).
            // "Why" reveals the evidence depth; share/note are follow-up wiring.
            if glassOn {
                MorphActionCluster(
                    onShareConsent: { showShare = true },
                    onJournal: {},
                    onEvidence: { withAnimation(.easeInOut(duration: 0.2)) { showDepth = true } }
                )
                .padding(.top, 2)
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
                .font(.liviqaSerif(23)).kerning(-0.2)
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Text(nudge.body)
                .font(.lato(14)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)

            // Refusing to assert is itself a decision, so it explains itself too.
            SeeWhyChip { seeWhy = evidenceWhy(ev.headline ?? nudge.body) }

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
            Button { showShare = true } label: {
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
