// VitalsDetailView.swift — A7.2 Area ④: the Vitals screen (FR-VIT-01), assembled
// from the DotBandStrip primitive (design_handoff_liviqa_a7: charts2.jsx
// DotBandStrip — the Apple-Health-Vitals anatomy, re-framed to Liviqa's rails).
//
// PERSONAL-TYPICAL ONLY (designated rail): every band is the user's own
// mean ±1σ — NEVER a clinical reference range, and the foot copy says so. The
// verdict words come from the fixed allow-list vocabulary ("Typical" /
// "Worth a look"); the hero verdict is a fixed template routed through the
// FR-NDG-06 guard in unit tests.
//
// VO₂max's long trend deliberately lives on the Fitness screen (one canonical
// home); this screen carries the overnight vitals: SpO₂ + respiratory rate.
import SwiftUI

struct VitalsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the hero verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: VitalsDetail? { appState.vitalsDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    MetricHero(tint: LiviqaTheme.accentRecovery,
                               kicker: "Vitals · your recent nights",
                               verdict: model.verdict,
                               stat: model.stat,
                               unit: model.statUnit,
                               sub: model.sub)
                    SeeWhyHeroRow { seeWhy = vitalsWhy(model) }
                    ForEach(Array(model.vitals.enumerated()), id: \.offset) { _, v in
                        vitalCard(v)
                    }
                    MetricDiscussButton { appState.showAssistant = true }
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .seeWhySheet($seeWhy, appState: appState)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// The hero verdict decomposed — every band on this screen is the user's own
    /// typical range, and the disclosure states that none of them is clinical.
    private func vitalsWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.vitalsHero(
            verdict: m.verdict,
            vitals: (detail?.vitals ?? []).map {
                VitalFact(name: $0.name, unit: $0.unit, latest: $0.latest,
                          band: $0.band, decimals: $0.decimals,
                          typical: $0.latestIsTypical)
            },
            isSeed: detail == nil)
    }

    // MARK: - Screen model

    struct VitalRow {
        var kicker: String
        var headline: String
        var series: [Double]
        var band: ClosedRange<Double>
        var unit: String
        var verdictWord: String
        var decimals: Int
    }

    struct Model {
        var verdict: String
        var stat: String?
        var statUnit: String?
        var sub: String
        var vitals: [VitalRow]
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        return appState.isSampleMode ? .designSeed : nil
    }

    // MARK: - Cards

    private func vitalCard(_ v: VitalRow) -> some View {
        MetricDCard(kicker: v.kicker, headline: v.headline,
                    foot: "The band is your own typical range (the middle of your readings ± their usual spread) — not a clinical reference.") {
            DotBandStrip(values: v.series,
                         band: v.band,
                         unit: v.unit,
                         color: LiviqaTheme.accentRecovery,
                         verdict: v.verdictWord,
                         // The strip draws the readings it HAS, evenly spaced —
                         // so the caption counts readings rather than claiming a
                         // fortnight of nightly measurement that may not exist.
                         caption: v.series.count == 1
                             ? "1 reading" : "\(v.series.count) readings",
                         decimals: v.decimals)
        }
    }

    // MARK: - Honest empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "lungs.fill").font(.system(size: 12))
                    .foregroundStyle(LiviqaTheme.accentRecovery)
                Text("VITALS")
                    .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text("No overnight vitals yet.")
                .font(.liviqaSerif(21)).kerning(-0.2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 9)
            Text("When a watch records overnight oxygen saturation and breathing rate to Apple Health, this page fills with your own last 14 nights against your own typical band. Everything stays on this phone.")
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

extension VitalsDetailView.Model {

    /// Derived figures → fixed descriptive templates (no generated language).
    init(derived d: VitalsDetail) {
        let verdict = d.allTypical
            ? "Everything reads typical for you."
            : "One signal is a little off its usual — worth a look."

        var stat: String? = nil
        var statUnit: String? = nil
        if let spo2 = d.vitals.first(where: { $0.name == "Oxygen saturation" }) {
            stat = String(format: "%.0f", spo2.latest)
            statUnit = "% SpO₂ · latest night"
        }

        let rows: [VitalsDetailView.VitalRow] = d.vitals.map { v in
            let word = v.latestIsTypical ? "Typical" : "Worth a look"
            let headline: String
            switch (v.name, v.latestIsTypical) {
            case ("Oxygen saturation", true): headline = "Overnight oxygen right in your typical band."
            case ("Oxygen saturation", false): headline = "Overnight oxygen a little off your typical band."
            case ("Respiratory rate", true): headline = "Breathing rate steady, night after night."
            case ("Respiratory rate", false): headline = "Breathing rate a little off your typical band."
            default: headline = v.latestIsTypical ? "Right in your typical band." : "A little off your typical band."
            }
            return VitalsDetailView.VitalRow(
                kicker: v.name,
                headline: headline,
                series: v.series,
                band: v.band,
                unit: v.unit,
                verdictWord: word,
                decimals: v.decimals)
        }

        self.init(
            verdict: verdict,
            stat: stat,
            statUnit: statUnit,
            sub: "Bands are learned from your own readings on this phone.",
            vitals: rows)
    }

    /// Demo seeds (no designed hero copy exists in the package for vitals — the
    /// standard hero pattern applies; strips follow the DotBandStrip spec).
    static var designSeed: Self {
        .init(
            verdict: "Everything reads typical for you.",
            stat: "97",
            statUnit: "% SpO₂ · latest night",
            sub: "Bands are learned from your own readings on this phone.",
            vitals: [
                .init(kicker: "Oxygen saturation",
                      headline: "Overnight oxygen right in your typical band.",
                      series: [97, 96, 97, 98, 97, 96, 97, 97, 96, 98, 97, 97, 96, 97],
                      band: 95.5...98.0, unit: "%", verdictWord: "Typical", decimals: 0),
                .init(kicker: "Respiratory rate",
                      headline: "Breathing rate steady, night after night.",
                      series: [14.1, 13.8, 14.3, 14.0, 13.9, 14.2, 14.4, 13.7, 14.0,
                               14.1, 13.9, 14.2, 14.0, 13.9],
                      band: 13.4...14.7, unit: "breaths/min", verdictWord: "Typical",
                      decimals: 1),
            ])
    }
}
