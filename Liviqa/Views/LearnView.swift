// LearnView.swift — A7.2 Area ⑨: the two-tier knowledge base (b-learn.jsx
// KBSimple + KBAdvanced). First topic: HRV. Built REUSABLY: a `LearnArticle`
// model rendered by one `LearnArticleView`, so further topics are content, not
// new screens.
//
// TIERING (FR-LIT-01): the literacy preference picks the DEFAULT tier only —
// "clinical" opens on the numbers, everything else opens plain. The deeper
// layer is always one tap away ("Liviqa never hides your real data"), and the
// clinical tier links back to the plain view the same way.
//
// HONESTY RAILS (T1):
//  · Live figures come from HRVLearnDeriver (the user's own daily SDNN stream);
//    window labels always carry the REAL day count, never a hardcoded "60-day"
//    claim over thinner data.
//  · The canvas's "measured 00:30–05:00" / "Nightly, ≥3h" clauses are NOT
//    derivable from Apple's spot HRV samples → replaced with the truthful
//    "daily average" method description (divergence noted for the canvas).
//  · No population ranges anywhere; footers kept verbatim from the canvas.
//  · Colour rails: recovery tint, no clinical red, no FR-NDG-06 verdict surface.
import SwiftUI

// MARK: - Model

enum LearnTier: String { case plain, clinical }

/// Topics the knowledge base can open. Raw values double as the
/// LIVIQA_OPEN_LEARN debug-hook values.
enum LearnTopic: String, CaseIterable, Identifiable {
    case hrv
    var id: String { rawValue }
}

/// One two-tier knowledge article. Static editorial content + live figures
/// resolved by the builder (LearnLibrary) before the view renders.
struct LearnArticle {
    struct KeyValueRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }
    struct WeekChart {
        let series: [Double]
        let ticks: [String]
        let unit: String
        let annotation: String?
    }

    let topic: LearnTopic
    let tint: Color

    // Plain tier ("In plain words")
    let plainBackLabel: String
    let plainTitle: String
    let plainKicker: String
    let plainVerdict: String
    let plainBody: String              // inline markdown (**bold**)
    let meaningKicker: String
    let meaningHeadline: String
    let meaningBody: String
    let deeperLinkLabel: String
    let plainFooter: String

    // Clinical tier ("Clinical detail")
    let clinicalBackLabel: String
    let clinicalTitle: String
    let clinicalKicker: String
    let clinicalVerdict: String
    let stat: String?
    let statUnit: String?
    let statSub: String?
    let inPlainWords: String
    let weekKicker: String?
    let weekHeadline: String?
    let weekChart: WeekChart?
    let methodKicker: String
    let methodHeadline: String
    let methodRows: [KeyValueRow]
    let clinicalFooter: String
}

// MARK: - Content library

enum LearnLibrary {

    /// The HRV article, filled with the user's own figures where the deriver
    /// has them and honest still-learning framing where it doesn't.
    static func hrv(detail: HRVLearnDetail?, weekFallback: [Double] = []) -> LearnArticle {
        let tint = LiviqaTheme.accentRecovery

        // Live "what it means for you" card (plain tier).
        let meaningHeadline: String
        let meaningBody: String
        if let d = detail {
            meaningHeadline = d.meaningHeadline
            meaningBody = d.meaningBody
        } else {
            meaningHeadline = String(localized: "Liviqa is still learning your usual.")
            meaningBody = String(localized: "Once it has about a week of your own readings, this card describes your own trend — measured against you, not averages.")
        }

        // Clinical stats — real window labels only.
        var stat: String? = nil
        var statSub: String? = nil
        if let d = detail {
            stat = "\(d.latestMs)"
            statSub = "Your \(d.windowDays)-day range \(d.rangeLoMs)–\(d.rangeHiMs) ms · median \(d.medianMs) ms"
        }

        // Week chart — the user's own series (deriver first, Home series as a
        // real fallback); nothing rendered below 2 points.
        var weekChart: LearnArticle.WeekChart? = nil
        var weekHeadline: String? = nil
        if let d = detail, d.weekSeries.count >= 2 {
            weekChart = .init(series: d.weekSeries, ticks: d.weekTicks,
                              unit: " ms", annotation: d.weekLowAnnotation)
            weekHeadline = d.weekHeadline
        } else if weekFallback.count >= 2 {
            weekChart = .init(series: weekFallback, ticks: [], unit: " ms", annotation: nil)
            weekHeadline = String(localized: "Your last days, against your own spread.")
        }

        let baselineRow = detail.map { "\($0.medianMs) ms (\($0.windowDays)-day median)" }
            ?? String(localized: "Still learning — about 5 days of readings are required")

        return LearnArticle(
            topic: .hrv,
            tint: tint,
            plainBackLabel: String(localized: "Recovery"),
            plainTitle: String(localized: "What is HRV?"),
            plainKicker: String(localized: "In plain words"),
            plainVerdict: String(localized: "HRV is a quiet sign of how rested you are."),
            plainBody: String(localized: "Your heart doesn't tick like a clock — the tiny gaps between beats shift a little. **More shift usually means you're well-rested**; less can mean you're tired, stressed, or coming down with something."),
            meaningKicker: String(localized: "What it means for you"),
            meaningHeadline: meaningHeadline,
            meaningBody: meaningBody,
            deeperLinkLabel: String(localized: "Show me the numbers"),
            plainFooter: String(localized: "Educational — describes patterns in your own data, not a diagnosis."),
            clinicalBackLabel: String(localized: "Plain view"),
            clinicalTitle: String(localized: "HRV · detail"),
            clinicalKicker: String(localized: "Clinical detail"),
            clinicalVerdict: String(localized: "Heart-rate variability (SDNN), daily average."),
            stat: stat,
            statUnit: "ms",
            statSub: statSub,
            inPlainWords: String(localized: "The gap between heartbeats changes slightly, beat to beat. A bigger spread usually means your body is well rested. This page is the technical version of that — you never need it to use Liviqa."),
            weekKicker: String(localized: "This week · ms"),
            weekHeadline: weekHeadline,
            weekChart: weekChart,
            methodKicker: String(localized: "How it's measured"),
            methodHeadline: String(localized: "Time-domain SDNN, averaged per day from your readings."),
            methodRows: [
                .init(label: String(localized: "Metric"), value: "SDNN (ms)"),
                .init(label: String(localized: "Time period"), value: String(localized: "Daily average · Apple Health")),
                .init(label: String(localized: "Your baseline"), value: baselineRow),
            ],
            clinicalFooter: String(localized: "Population reference ranges vary by age & device and are not shown — Liviqa compares you only to yourself. Not a diagnostic measure."))
    }
}

// MARK: - View

struct LearnArticleView: View {
    let article: LearnArticle
    /// Explicit entry tier (e.g. a "Show me the numbers" chip lands on clinical).
    /// nil ⇒ the literacy preference picks the default.
    var startTier: LearnTier? = nil

    @AppStorage("literacyLevel") private var literacyLevel = "both"
    @Environment(\.dismiss) private var dismiss
    @State private var tierOverride: LearnTier? = nil

    /// FR-LIT-01: "clinical" opens on the numbers; plain/both open plain.
    /// One tap moves between tiers either way — data is never hidden.
    private var tier: LearnTier {
        tierOverride ?? startTier
            ?? (LiteracyLevel(storage: literacyLevel) == .clinical ? .clinical : .plain)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch tier {
                case .plain:    plainTier
                case .clinical: clinicalTier
                }
            }
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .animation(.easeInOut(duration: 0.2), value: tier)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: Plain tier (KBSimple)

    @ViewBuilder private var plainTier: some View {
        header(back: article.plainBackLabel, title: article.plainTitle) { dismiss() }

        MetricHero(tint: article.tint, kicker: article.plainKicker,
                   verdict: article.plainVerdict)

        bodyCard(article.plainBody)

        MetricDCard(kicker: article.meaningKicker, headline: article.meaningHeadline) {
            Text(article.meaningBody)
                .font(.lato(13)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }

        deeperLink(label: article.deeperLinkLabel) { tierOverride = .clinical }

        Text("The deeper layer is always one tap away — Liviqa never hides your real data.")
            .font(.lato(11)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink4)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)

        footer(article.plainFooter)
    }

    // MARK: Clinical tier (KBAdvanced)

    @ViewBuilder private var clinicalTier: some View {
        header(back: article.clinicalBackLabel, title: article.clinicalTitle) {
            tierOverride = .plain
        }

        MetricHero(tint: article.tint, kicker: article.clinicalKicker,
                   verdict: article.clinicalVerdict,
                   stat: article.stat, unit: article.statUnit, sub: article.statSub)

        // Reciprocal "IN PLAIN WORDS" tinted card.
        VStack(alignment: .leading, spacing: 4) {
            Text("IN PLAIN WORDS")
                .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                .foregroundStyle(LiviqaTheme.moss)
            Text(article.inPlainWords)
                .font(.lato(13)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15).padding(.vertical, 13)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .padding(.horizontal, 16)

        if let kicker = article.weekKicker, let headline = article.weekHeadline,
           let chart = article.weekChart {
            MetricDCard(kicker: kicker, headline: headline) {
                VStack(alignment: .leading, spacing: 8) {
                    AreaTrendChart(values: chart.series, tint: article.tint,
                                   height: 120, xTicks: chart.ticks, unit: chart.unit)
                    if let annotation = chart.annotation {
                        HStack(spacing: 6) {
                            Circle().fill(article.tint).frame(width: 6, height: 6)
                            Text(annotation)
                                .font(.liviqaMono(11))
                                .foregroundStyle(LiviqaTheme.ink3)
                        }
                    }
                }
            }
        }

        MetricDCard(kicker: article.methodKicker, headline: article.methodHeadline) {
            VStack(spacing: 0) {
                ForEach(Array(article.methodRows.enumerated()), id: \.element.id) { i, row in
                    HStack {
                        Text(row.label)
                            .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                        Spacer()
                        Text(row.value)
                            .font(.lato(12.5, .semibold)).foregroundStyle(LiviqaTheme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 6)
                    if i < article.methodRows.count - 1 {
                        Rectangle().fill(LiviqaTheme.line).frame(height: 0.5)
                    }
                }
            }
        }

        footer(article.clinicalFooter)
    }

    // MARK: Shared pieces

    private func header(back: String, title: String, onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(back).font(.lato(13, .semibold))
                }
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(LiviqaTheme.paper2))
                .overlay(Capsule().stroke(LiviqaTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to \(back)")
            Spacer()
            Text(title)
                .font(.liviqaSerif(16)).kerning(-0.1)
                .foregroundStyle(LiviqaTheme.ink)
        }
        .padding(.top, 14).padding(.horizontal, 20)
    }

    private func bodyCard(_ markdown: String) -> some View {
        Text((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown))
            .font(.lato(14)).lineSpacing(4)
            .foregroundStyle(LiviqaTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 15)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card)
                .stroke(LiviqaTheme.line, lineWidth: 0.5))
            .padding(.horizontal, 16)
    }

    private func deeperLink(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LiviqaTheme.moss)
                Text(label)
                    .font(.lato(13, .bold))
                    .foregroundStyle(LiviqaTheme.moss)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.lato(11)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24).padding(.top, 4)
    }
}

// MARK: - Topic entry point (resolves live data from AppState)

extension LearnArticleView {
    /// Open a topic with the user's live derived figures. The chat "Show me the
    /// numbers" chip and the LIVIQA_OPEN_LEARN debug hook enter here.
    init(topic: LearnTopic, appState: AppState, startTier: LearnTier? = nil) {
        switch topic {
        case .hrv:
            self.init(article: LearnLibrary.hrv(
                detail: appState.hrvLearn,
                weekFallback: appState.todaySignals?.hrvWeek ?? []),
                startTier: startTier)
        }
    }
}
