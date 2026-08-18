// HeartDetailView.swift — A7.2 Area ④: the Heart metric detail, rebuilt to the
// DHeart editorial anatomy (design_handoff_liviqa_a7: d-insights.jsx DHeart +
// charts2.jsx BPChart + charts.jsx BaselineSpark).
//
// SAFETY LANES (all held):
// · Tint is accentHeart rose-punch 0xD9486B (approved substitute, RK-ALARM-01) —
//   NEVER the package's saturated red; clinical red stays glucose-charts-only.
// · Every band/corridor is the user's OWN mean ±1σ — never a clinical range.
// · AFib lane (OD-11 / D9): DISPLAY-ONLY, route-to-cardiologist. The figure is
//   re-presented exactly as recorded — no score, no trend, no advice. The
//   "Talk to your cardiologist" chip is a plain routing affordance (opens the
//   share-with-clinician flow), not an alert. FR-NDG-06 untouched.
//
// DATA HONESTY: renders from HeartDetailDeriver output when it exists; the
// design-package seeds render ONLY with no derivation AND in demo mode; a real
// device without heart data shows an honest empty state.
import SwiftUI

struct HeartDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showShare = false
    /// FR-XPL-01 — the hero verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: HeartWeekDetail? { appState.heartDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    // HERO WEIGHT (RK-ALARM-01 audit, 2026-08-13). The token is
                    // unchanged — accentHeart rose-punch, exactly as approved.
                    // What changed is how much of the screen it fills: the
                    // full-bleed plate is now reserved for the one verdict that
                    // asks the reader to look ("Resting above your usual band"),
                    // and every calm or descriptive verdict gets the quiet plate
                    // — rose kicker, rose edge, rose wash, ink type. A reassuring
                    // sentence no longer arrives on the loudest surface in the
                    // app, and the two themes carry the same weight because the
                    // wash and the edge are alpha over each theme's own card.
                    MetricHero(tint: LiviqaTheme.accentHeart,
                               kicker: "Heart · this week",
                               verdict: model.verdict,
                               stat: model.stat,
                               unit: "bpm resting",
                               sub: model.sub,
                               weight: model.needsAttention ? .solid : .quiet)
                    SeeWhyHeroRow { seeWhy = heartWhy(model) }
                    if model.bp.count >= 2 { bpCard(model) }
                    if model.rhrSeries.count >= 2 { rhrCard(model) }
                    if let afib = model.afibLine { afibCard(model, line: afib) }
                    MetricDiscussButton { appState.showAssistant = true }
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .sheet(isPresented: $showShare) {
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
        .seeWhySheet($seeWhy, appState: appState)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// The hero verdict decomposed. The AFib lane is deliberately NOT part of
    /// this: it is display-only, so there is no derivation to disclose (OD-11).
    private func heartWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.heartHero(
            verdict: m.verdict,
            rhrLatest: detail?.rhrLatest ?? Int(m.stat),
            band: m.rhrBand,
            windowDays: detail?.rhrWindowDays ?? m.rhrSeries.count,
            seriesCount: m.rhrSeries.count,
            isSeed: detail == nil)
    }

    // MARK: - Screen model (derived figures → fixed descriptive templates)

    struct Model {
        var verdict: String
        /// True only for the one verdict that asks the reader to look. Drives the
        /// hero's WEIGHT (see the note at the call site) — never its colour.
        var needsAttention: Bool = false
        var stat: String
        var sub: String
        var bp: [(sys: Int, dia: Int)]
        var sysBand: ClosedRange<Double>?
        var diaBand: ClosedRange<Double>?
        var bpHeadline: String
        var bpPeakIndex: Int?
        var bpPeakLabel: String?
        var bpEdges: [String]
        var rhrSeries: [Double]
        var rhrBand: ClosedRange<Double>?
        var rhrHeadline: String
        var rhrFoot: String
        var afibLine: String?
        var afibHeadline: String
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        return appState.isSampleMode ? .designSeed : nil
    }

    // MARK: - Cards

    private func bpCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Blood pressure · 2 weeks", headline: m.bpHeadline) {
            BPDotRangeChart(points: m.bp,
                            sysBand: m.sysBand,
                            diaBand: m.diaBand,
                            peakIndex: m.bpPeakIndex,
                            peakLabel: m.bpPeakLabel,
                            edgeLabels: m.bpEdges)
        }
    }

    private func rhrCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Resting heart rate", headline: m.rhrHeadline,
                    foot: m.rhrFoot) {
            BaselineSpark(data: m.rhrSeries,
                          band: m.rhrBand,
                          color: LiviqaTheme.accentHeart,
                          height: 58)
        }
    }

    /// The display-only AFib lane (OD-11 / D9). Rose accent, never red; the chip
    /// routes to the clinician-share flow — no interpretation anywhere.
    private func afibCard(_ m: Model, line: String) -> some View {
        MetricDCard(kicker: "Heart rhythm · AFib history",
                    headline: m.afibHeadline,
                    foot: "Rhythm findings are display-only — no score, no trend, no advice.") {
            HStack(alignment: .center, spacing: 12) {
                Text(line)
                    .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { showShare = true } label: {
                    Text("Talk to your cardiologist")
                        .font(.lato(12.5, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(LiviqaTheme.ink.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Honest empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").font(.system(size: 12))
                    .foregroundStyle(LiviqaTheme.accentHeart)
                Text("HEART")
                    .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text("No heart readings yet.")
                .font(.liviqaSerif(21)).kerning(-0.2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 9)
            Text("When a watch or home cuff shares to Apple Health, this page fills with your own resting heart rate, blood pressure and rhythm history — framed against your own usual, never a chart of someone else's. Everything stays on this phone.")
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Model building

extension HeartDetailView.Model {

    /// Derived figures → fixed descriptive templates (no generated language).
    init(derived d: HeartWeekDetail) {
        // Verdict from the OWN band only ("Calm" family — allow-list vocabulary).
        // `attention` is set on the SAME branch that picks the sentence, so the
        // hero's weight can never drift away from what the sentence says.
        let verdict: String
        var attention = false
        if let latest = d.rhrLatest, let band = d.rhrBand {
            if band.contains(Double(latest)) { verdict = "Your heart is running calm." }
            else if Double(latest) < band.lowerBound { verdict = "Resting lower than your usual band." }
            else {
                verdict = "Resting above your usual band — worth a look."
                attention = true
            }
        } else {
            verdict = "Your heart, as recorded this week."
        }

        var subParts: [String] = []
        if let bp = d.bpLatestText { subParts.append("\(bp) latest") }
        if let src = d.bpSource { subParts.append(src) }

        // BP headline from the corridor position of the window's readings.
        let bpHeadline: String
        if let peak = d.bpPeakIndex, peak < d.bp.count {
            bpHeadline = "Steady inside your usual — one higher reading."
        } else if d.sysBand != nil {
            bpHeadline = "Steady inside your usual."
        } else {
            bpHeadline = "Your readings, as recorded."
        }
        let peakLabel: String? = d.bpPeakIndex.flatMap { i in
            i < d.bp.count ? "\(d.bp[i].sys)/\(d.bp[i].dia) — highest this fortnight" : nil
        }

        let rhrHeadline: String
        if let latest = d.rhrLatest, let band = d.rhrBand, band.contains(Double(latest)) {
            rhrHeadline = "\(latest) — right in your usual band."
        } else if let latest = d.rhrLatest {
            rhrHeadline = "\(latest) — outside your usual band."
        } else {
            rhrHeadline = "Your resting heart rate, day by day."
        }
        let rhrFoot = d.rhrBand != nil
            ? "The soft band is your own \(d.rhrWindowDays)-day usual; the dot is today."
            : "The line is your own last fortnight; the dot is today."

        // AFib — display-only re-presentation of the recorded figure (OD-11).
        var afibLine: String? = nil
        var afibHeadline = ""
        if let pct = d.afibLatestPct {
            afibHeadline = "Your watch's own irregular-rhythm figure, shown as recorded."
            var line = String(format: "AFib burden %.1f%%", pct)
            if let when = d.afibLatestDateText { line += " · recorded \(when)" }
            line += " · \(d.afibDaysObserved) day\(d.afibDaysObserved == 1 ? "" : "s") observed"
            afibLine = line
        }

        self.init(
            verdict: verdict,
            needsAttention: attention,
            stat: d.rhrLatest.map(String.init) ?? "—",
            sub: subParts.joined(separator: " · "),
            bp: d.bp.map { ($0.sys, $0.dia) },
            sysBand: d.sysBand,
            diaBand: d.diaBand,
            bpHeadline: bpHeadline,
            bpPeakIndex: d.bpPeakIndex,
            bpPeakLabel: peakLabel,
            bpEdges: d.bpEdgeLabels,
            rhrSeries: d.rhrSeries,
            rhrBand: d.rhrBand,
            rhrHeadline: rhrHeadline,
            rhrFoot: rhrFoot,
            afibLine: afibLine,
            afibHeadline: afibHeadline)
    }

    /// The design package's demo story (d-insights.jsx DHeart), verbatim.
    /// Rendered ONLY when no derivation exists AND the session is demo-tagged.
    static var designSeed: Self {
        .init(
            verdict: "Your heart is running calm.",
            needsAttention: false,
            stat: "58",
            sub: "121/78 latest · home cuff + Apple Watch",
            bp: [(122, 79), (126, 82), (119, 77), (124, 80), (131, 86), (121, 78),
                 (118, 76), (125, 81), (128, 83), (120, 78), (123, 80), (117, 75),
                 (121, 78), (119, 77)],
            sysBand: 115...130,
            diaBand: 74...84,
            bpHeadline: "Steady inside your usual — one rise after Tuesday's run.",
            bpPeakIndex: 4,
            bpPeakLabel: "131/86 — after the Tuesday run",
            bpEdges: ["24 Jun", "7 Jul"],
            rhrSeries: [59, 60, 58, 61, 59, 58, 57, 59, 58, 60, 58, 57, 58, 58],
            rhrBand: 56...61,
            rhrHeadline: "58 — right in your usual band.",
            rhrFoot: "The soft band is your own 60-day usual; the dot is today.",
            afibLine: "0 notifications · 428 days observed",
            afibHeadline: "No irregular-rhythm notifications this month.")
    }
}
