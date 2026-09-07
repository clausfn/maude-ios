// MetricBaselineView.swift — "Your usual" per-domain baseline detail, restyled to
// the A7 editorial anatomy (serif verdict → RangeBand with today's marker →
// 14-day BaselineSpark → "How it's learned" card). UC-08: your normal, never a
// percentile — the band is always the user's OWN learned range.
//
// A7.2 Area ④: the pre-A7 arc-gauge hero (EvidenceComponents.ApertureArcGauge —
// retired Aperture-era naming) is no longer used here. DATA: when a real
// `BaselineDeriver` baseline exists for this domain (appState.baselines), it
// REPLACES the caller's demo values — the demo BaselineMetric renders only in
// demo sessions. Sentences are fixed descriptive templates (FR-NDG-06 rail).
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
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the "your usual" verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil
    /// Area ⑨ entry point: the matching method note, straight from this screen.
    @State private var learnTopic: LearnTopic? = nil

    /// The real learned baseline for this domain, when the deriver has one.
    private var live: DomainBaseline? {
        switch metric.short {
        case "Sleep": return appState.baselines?.entry(.sleep)
        case "HRV":   return appState.baselines?.entry(.hrv)
        case "RHR":   return appState.baselines?.entry(.rhr)
        default:      return nil
        }
    }

    // Displayed figures: real when learned, else the caller's (demo) values —
    // and the demo values only in a demo session (never demo-over-real).
    private var value: Double { live?.latest ?? metric.value }
    private var band: ClosedRange<Double> {
        live?.band ?? (metric.normalLow...metric.normalHigh)
    }
    private var unit: String { live?.unit ?? metric.unit }
    private var hasFigures: Bool { live != nil || appState.isSampleMode }

    private var inRange: Bool { band.contains(value) }

    private func num(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                NavBackHeader(onBack: { dismiss() }) {
                    Text(metric.short)
                        .font(.lato(15, .black)).foregroundStyle(MaudeTheme.ink)
                }
                .padding(.top, 6)
                .padding(.horizontal, 20)

                if hasFigures {
                    header
                    bandCard
                    if let series = live?.series, series.count >= 2 {
                        sparkCard(series)
                    }
                    howCard
                    learnRow
                    stubs
                } else {
                    emptyState
                    learnRow
                }

                Spacer(minLength: 12)
            }
            .padding(.bottom, 28)
        }
        .background(MaudeTheme.paper)
        .seeWhySheet($seeWhy, appState: appState)
        .sheet(item: $learnTopic) { topic in
            LearnArticleView(topic: topic, appState: appState)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// The method note behind THIS band: HRV gets its own topic (Area ⑨), every
    /// other domain gets the published "your usual" note.
    private var learnLink: LearnTopic { metric.short == "HRV" ? .hrv : .usualBand }

    private var learnRow: some View {
        Button { learnTopic = learnLink } label: {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .font(.system(size: 12, weight: .semibold))
                Text(learnLink == .hrv ? "What is HRV?" : "How “your usual” is worked out")
                    .font(.lato(13.5, .bold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(MaudeTheme.moss)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    /// The verdict decomposed: today's figure, the days the band was learned
    /// from, the band itself, and the one-line arithmetic that produced it.
    private var baselineWhy: SeeWhyExplanation {
        SeeWhyExplainer.baseline(
            name: metric.short, verdict: verdictText, value: value, unit: unit,
            band: band, learnedFromDays: live?.learnedFromDays,
            seriesCount: live?.series.count ?? 0,
            isSeed: live == nil, method: learnLink)
    }

    // MARK: - Header (kicker → serif verdict → big number)

    private var verdictText: String {
        if inRange { return "Right in your usual range." }
        return value > band.upperBound
            ? "A little above your usual range."
            : "A little below your usual range."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metric.name.uppercased())
                .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                .foregroundStyle(MaudeTheme.ink3)
            Text(verdictText)
                .font(.maudeSerif(22)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink)
                .padding(.top, 8)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(num(value))
                    .font(.maudeSerif(40, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(MaudeTheme.ink)
                Text(unit)
                    .font(.lato(15, .semibold))
                    .foregroundStyle(MaudeTheme.ink3)
            }
            .padding(.top, 8)
            // The warm line: real sessions get a fixed descriptive template;
            // the canned copy renders only alongside the demo figures.
            Text(live != nil
                 ? (inRange ? "Steady inside the range Maude has learned from your own days."
                            : "Off your own learned range today — one day is a data point, not a story.")
                 : metric.warm)
                .font(.lato(14)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            // FR-XPL-01 — the band is a verdict too, so it opens like one.
            SeeWhyChip { seeWhy = baselineWhy }
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Cards

    private var bandCard: some View {
        MetricDCard(kicker: "Your usual", headline: nil) {
            VStack(alignment: .leading, spacing: 8) {
                RangeBandView(band: band, value: value, color: MaudeTheme.moss)
                Text("your usual \(num(band.lowerBound))–\(num(band.upperBound)) \(unit) · latest \(num(value))")
                    .font(.maudeMono(11))
                    .foregroundStyle(MaudeTheme.ink3)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func sparkCard(_ series: [Double]) -> some View {
        // The kicker counts what was RECORDED, not the calendar span: the
        // series holds only days with a reading, drawn evenly, so a "last 14
        // days" label over three scattered points would claim a fortnight of
        // measurement that never happened.
        MetricDCard(kicker: series.count == 1
                        ? "1 recorded day"
                        : "\(series.count) recorded days",
                    headline: nil,
                    foot: "The soft band is your own learned range; the dot is your latest reading. Days without a reading are not drawn.") {
            BaselineSpark(data: series, band: band, color: MaudeTheme.moss, height: 44)
        }
    }

    private var howCard: some View {
        MetricDCard(kicker: "How it's learned",
                    headline: "From your own days — no percentile, no chart of other people.") {
            Text(live != nil
                 ? "Maude takes your last \(live!.learnedFromDays) days of this signal on this phone, finds their middle, and adds their usual spread (one standard deviation each way). That's the band. It re-learns as new days arrive, and it never compares you to anyone else."
                 : "Maude takes your recent days of this signal on this phone, finds their middle, and adds their usual spread (one standard deviation each way). That's the band. It re-learns as new days arrive, and it never compares you to anyone else.")
                .font(.lato(12.5)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Honest empty state (real session, nothing learned yet)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metric.name.uppercased())
                .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                .foregroundStyle(MaudeTheme.ink3)
            Text("Still learning your usual.")
                .font(.maudeSerif(21)).kerning(-0.2)
                .foregroundStyle(MaudeTheme.ink)
                .padding(.top, 9)
            Text("A learned range needs at least five days of your own data. Keep wearing your tracker and this page will fill in by itself — from your days, nobody else's.")
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Follow-up wiring stubs (honest, disabled + SOON chips)

    private var stubs: some View {
        VStack(spacing: 4) {
            Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                HStack(spacing: 8) {
                    Text("Log what's working")
                        .font(.lato(15, .bold))
                        .foregroundStyle(MaudeTheme.ink)
                    Text("SOON").font(.maudeKicker(8.5)).tracking(1)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(MaudeTheme.moss2))
                        .foregroundStyle(MaudeTheme.moss)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(MaudeTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .buttonStyle(.plain)
            .disabled(true)
            Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                HStack(spacing: 8) {
                    Text("See your 90-day baseline ›")
                        .font(.lato(14, .bold))
                        .foregroundStyle(MaudeTheme.ink3)
                    Text("SOON").font(.maudeKicker(8.5)).tracking(1)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(MaudeTheme.moss2))
                        .foregroundStyle(MaudeTheme.moss)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
        .padding(.top, 2)
        .padding(.horizontal, 20)
    }
}
