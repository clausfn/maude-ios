// BodyDetailView.swift — A7.2 Area ④: the Body / composition screen, built to
// the DBody editorial anatomy (design_handoff_maude_a7: d-insights.jsx DBody +
// charts2.jsx LongTrend). Entry point is the You/passport area (design back
// label "You"), tint is the design's own body indigo (`MaudeTheme.accentBody`,
// 0x5B5FC7 — deliberately NOT accentSleep).
//
// PERSONAL CORRIDOR ONLY: the shaded corridor is the user's own mean ±1σ —
// never a BMI class or goal weight. Milestone annotations are DERIVED (window
// low/high), never invented. Sentences are fixed descriptive templates
// (FR-NDG-06 rail — "drifting", never "dieting advice").
//
// DATA HONESTY: renders from BodyTrendDeriver over the live window (30–90 days);
// the kicker names the window's true start month, so the screen never claims
// more history than it has. Design seeds render only in demo mode.
import SwiftUI

struct BodyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the hero verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: BodyTrendDetail? { appState.bodyDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    MetricHero(tint: MaudeTheme.accentBody,
                               kicker: model.kicker,
                               verdict: model.verdict,
                               stat: model.stat,
                               unit: "kg",
                               sub: model.sub)
                    SeeWhyHeroRow { seeWhy = bodyWhy(model) }
                    if model.weight.count >= 2 { weightCard(model) }
                    if model.fat.count >= 2 { fatCard(model) }
                    MetricDiscussButton { appState.showAssistant = true }
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 28)
        }
        .background(MaudeTheme.paper)
        .seeWhySheet($seeWhy, appState: appState)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// The hero verdict decomposed — a difference across the window, inside the
    /// user's OWN corridor. No goal weight and no body-mass class, said plainly.
    private func bodyWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.bodyHero(
            verdict: m.verdict,
            deltaKg: detail?.weightDeltaKg,
            sinceMonth: detail?.sinceMonthName ?? m.kicker,
            corridor: m.weightCorridor,
            pointCount: m.weight.count,
            source: detail?.source,
            isSeed: detail == nil)
    }

    // MARK: - Screen model

    struct Model {
        var kicker: String
        var verdict: String
        var stat: String
        var sub: String
        var weight: [Double]
        var weightCorridor: ClosedRange<Double>?
        var weightHeadline: String
        var weightAnnotation: (i: Int, label: String)?
        var xLabels: [String]
        var fat: [Double]
        var fatCorridor: ClosedRange<Double>?
        var fatHeadline: String
        var fatFoot: String?
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        return appState.isSampleMode ? .designSeed : nil
    }

    // MARK: - Cards

    private func weightCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Weight", headline: m.weightHeadline) {
            LongTrendChart(data: m.weight,
                           corridor: m.weightCorridor,
                           unit: "kg",
                           color: MaudeTheme.accentBody,
                           xLabels: m.xLabels,
                           annotation: m.weightAnnotation,
                           height: 148)
        }
    }

    private func fatCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Body composition", headline: m.fatHeadline, foot: m.fatFoot) {
            LongTrendChart(data: m.fat,
                           corridor: m.fatCorridor,
                           unit: "body fat %",
                           color: MaudeTheme.accentBody,
                           xLabels: m.xLabels,
                           height: 126)
        }
    }

    // MARK: - Honest empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "figure.arms.open").font(.system(size: 12))
                    .foregroundStyle(MaudeTheme.accentBody)
                Text("BODY")
                    .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                    .foregroundStyle(MaudeTheme.ink3)
            }
            Text("No body measurements yet.")
                .font(.maudeSerif(21)).kerning(-0.2)
                .foregroundStyle(MaudeTheme.ink)
                .padding(.top, 9)
            Text("When a scale or an InBody import shares to Apple Health, this page fills with your own long trends — weight and composition inside your own corridor. No goal weights here, and everything stays on this phone.")
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Model building

extension BodyDetailView.Model {

    /// Derived figures → fixed descriptive templates (no generated language).
    init(derived d: BodyTrendDetail) {
        let verdict: String
        if let delta = d.weightDeltaKg {
            if delta <= -0.5 {
                verdict = String(format: "Down %.1f kg — a slow drift, nothing sudden.", -delta)
            } else if delta >= 0.5 {
                verdict = String(format: "Up %.1f kg since %@.", delta, d.sinceMonthName)
            } else {
                verdict = "Holding steady since \(d.sinceMonthName)."
            }
        } else {
            verdict = "Your measurements, as recorded."
        }

        var subParts: [String] = []
        if let fat = d.latestFatPct { subParts.append(String(format: "Body fat %.1f%%", fat)) }
        if let lean = d.latestLeanKg { subParts.append(String(format: "lean mass %.1f kg", lean)) }
        if let bmi = d.latestBMI { subParts.append(String(format: "BMI %.1f", bmi)) }
        if let src = d.source {
            subParts.append(src.caseInsensitiveCompare("Mock") == .orderedSame
                            ? String(localized: "Sample data") : src)
        }

        // Milestone: only the derived window low/high, on the latest reading.
        var annotation: (i: Int, label: String)? = nil
        if let latest = d.latestWeightKg, !d.weightSeries.isEmpty {
            if d.latestIsWindowLow {
                annotation = (d.weightSeries.count - 1,
                              String(format: "%.1f — lowest since %@", latest, d.sinceMonthName))
            } else if d.latestIsWindowHigh {
                annotation = (d.weightSeries.count - 1,
                              String(format: "%.1f — highest since %@", latest, d.sinceMonthName))
            }
        }

        let weightHeadline = d.weightCorridor != nil
            ? "A slow drift inside your usual corridor."
            : "Your weight, reading by reading."

        let fatHeadline: String
        if let first = d.fatSeries.first, let last = d.fatSeries.last, d.fatSeries.count >= 3 {
            if last <= first - 0.3 { fatHeadline = "Fat share down across the window." }
            else if last >= first + 0.3 { fatHeadline = "Fat share up a little across the window." }
            else { fatHeadline = "Fat share holding steady." }
        } else {
            fatHeadline = "Your composition, reading by reading."
        }

        var fatFoot: String? = nil
        if let leanDelta = d.leanDeltaKg {
            if abs(leanDelta) < 0.3 {
                fatFoot = "Lean mass unchanged since \(d.sinceMonthName)."
            } else if leanDelta > 0 {
                fatFoot = String(format: "Lean mass up %.1f kg since %@.", leanDelta, d.sinceMonthName)
            } else {
                fatFoot = String(format: "Lean mass down %.1f kg since %@.", -leanDelta, d.sinceMonthName)
            }
        }

        self.init(
            kicker: "Body · since \(d.sinceMonthName)",
            verdict: verdict,
            stat: d.latestWeightKg.map { String(format: "%.1f", $0) } ?? "—",
            sub: subParts.joined(separator: " · "),
            weight: d.weightSeries,
            weightCorridor: d.weightCorridor,
            weightHeadline: weightHeadline,
            weightAnnotation: annotation,
            xLabels: d.xLabels,
            fat: d.fatSeries,
            fatCorridor: d.fatCorridor,
            fatHeadline: fatHeadline,
            fatFoot: fatFoot)
    }

    /// The design package's demo story (d-insights.jsx DBody), verbatim.
    static var designSeed: Self {
        .init(
            kicker: "Body · since March",
            verdict: "Down 1.4 kg — drifting gently, not dieting.",
            stat: "70.4",
            sub: "Body fat 24.1% · lean mass 53.4 kg · BMI 23.0 · InBody",
            weight: [71.8, 71.6, 71.9, 71.4, 71.2, 71.3, 70.9, 70.8, 70.6, 70.7, 70.4],
            weightCorridor: 70.5...72,
            weightHeadline: "A slow drift inside your usual corridor.",
            weightAnnotation: (4, "71.2 — new walking habit"),
            xLabels: ["Mar", "May", "Jul"],
            fat: [25.6, 25.4, 25.5, 25.1, 24.9, 24.8, 24.6, 24.5, 24.3, 24.2, 24.1],
            fatCorridor: 24...25.5,
            fatHeadline: "Fat down, lean mass held — the good kind of lighter.",
            fatFoot: "Lean mass unchanged since March.")
    }
}
