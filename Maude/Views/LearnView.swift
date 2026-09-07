// LearnView.swift — A7.2 Area ⑨: the two-tier knowledge base (b-learn.jsx
// KBSimple + KBAdvanced). First topic: HRV. Built REUSABLY: a `LearnArticle`
// model rendered by one `LearnArticleView`, so further topics are content, not
// new screens.
//
// TIERING (FR-LIT-01): the literacy preference picks the DEFAULT tier only —
// "clinical" opens on the numbers, everything else opens plain. The deeper
// layer is always one tap away ("Maude never hides your real data"), and the
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
/// MAUDE_OPEN_LEARN debug-hook values.
///
/// FR-XPL-01 · Bevel absorb ②: the four METHOD NOTES below are the published
/// half of "See why". A See-why disclosure shows the arithmetic for one surface;
/// the method note behind it publishes the rule that surface follows, in plain
/// language, once — so the answer to "how does this app decide that?" is a
/// readable page rather than a support ticket.
public nonisolated enum LearnTopic: String, CaseIterable, Identifiable, Sendable {
    case hrv
    /// How "your usual" is computed (mean ± 1σ over the days actually present).
    case usualBand = "usual-band"
    /// What the evening day score adds up — and which leg is not personal.
    case dayScore = "day-score"
    /// The evidence gate a correlation must clear before Maude asserts it.
    case evidenceGate = "evidence-gate"
    /// Why every verdict comes from a fixed vocabulary.
    case verdictWords = "verdict-words"

    public var id: String { rawValue }
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
        /// The day axis this series sits on, when the app has one. Present ⇒ the
        /// chart draws one column per calendar day (gaps stay gaps) — the same
        /// placement the Recovery pillar uses, so the two can't drift apart.
        var slots: [DaySlot]? = nil
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
    ///
    /// `detail` must already be reconciled against the app's canonical HRV week
    /// (`HRVLearnDeriver.reconciled`) — see the entry point at the foot of this
    /// file. `weekSlots` is that same canonical week, handed on so this chart
    /// places its days exactly as the Recovery pillar does.
    static func hrv(detail: HRVLearnDetail?, weekFallback: [Double] = [],
                    weekSlots: [DaySlot]? = nil) -> LearnArticle {
        let tint = MaudeTheme.accentRecovery
        // Day letters come from the axis when there is one, so a value can never
        // be printed under another day's letter.
        let slotTicks = weekSlots?.map { HRVLearnDeriver.dayInitial($0.date) }

        // Live "what it means for you" card (plain tier).
        let meaningHeadline: String
        let meaningBody: String
        if let d = detail {
            meaningHeadline = d.meaningHeadline
            meaningBody = d.meaningBody
        } else {
            meaningHeadline = String(localized: "Maude is still learning your usual.")
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
            weekChart = .init(series: d.weekSeries, ticks: slotTicks ?? d.weekTicks,
                              unit: " ms", annotation: d.weekLowAnnotation,
                              slots: weekSlots)
            weekHeadline = d.weekHeadline
        } else if weekFallback.count >= 2 {
            weekChart = .init(series: weekFallback, ticks: slotTicks ?? [],
                              unit: " ms", annotation: nil, slots: weekSlots)
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
            inPlainWords: String(localized: "The gap between heartbeats changes slightly, beat to beat. A bigger spread usually means your body is well rested. This page is the technical version of that — you never need it to use Maude."),
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
            clinicalFooter: String(localized: "Population reference ranges vary by age & device and are not shown — Maude compares you only to yourself. Not a diagnostic measure."))
    }

    // MARK: - Published method notes (FR-XPL-01)

    /// The shared shape of a method note: no live figures, no stat, no chart —
    /// a method note describes the RULE, and the See-why disclosure that links
    /// here carries the user's own numbers. That split is deliberate: it means a
    /// method note can never be caught claiming a figure the user doesn't have.
    private static func methodNote(
        topic: LearnTopic,
        title: String, verdict: String, body: String,
        meaningHeadline: String, meaningBody: String,
        clinicalTitle: String, clinicalVerdict: String,
        inPlainWords: String,
        methodHeadline: String,
        methodRows: [LearnArticle.KeyValueRow],
        // Most notes describe a purely baseline-relative rule, so the shared
        // footer's absolute is true of them. The day score is not one of them:
        // its own rows, printed a few hundred points above this footer, divide
        // by fixed references. A note whose method contradicts its own footer
        // teaches the citizen to discount both.
        comparesOnlyToYou: Bool = true
    ) -> LearnArticle {
        LearnArticle(
            topic: topic,
            tint: MaudeTheme.moss,
            plainBackLabel: String(localized: "See why"),
            plainTitle: title,
            plainKicker: String(localized: "How Maude works this out"),
            plainVerdict: verdict,
            plainBody: body,
            meaningKicker: String(localized: "Why it's done this way"),
            meaningHeadline: meaningHeadline,
            meaningBody: meaningBody,
            deeperLinkLabel: String(localized: "Show me the exact rule"),
            plainFooter: String(localized: "Educational — describes how your own data is read, not a diagnosis."),
            clinicalBackLabel: String(localized: "Plain view"),
            clinicalTitle: clinicalTitle,
            clinicalKicker: String(localized: "The exact rule"),
            clinicalVerdict: clinicalVerdict,
            stat: nil, statUnit: nil, statSub: nil,
            inPlainWords: inPlainWords,
            weekKicker: nil, weekHeadline: nil, weekChart: nil,
            methodKicker: String(localized: "The rule, line by line"),
            methodHeadline: methodHeadline,
            methodRows: methodRows,
            clinicalFooter: comparesOnlyToYou
                ? String(localized: "Maude compares you only to yourself. Not a diagnostic measure.")
                : String(localized: "Every comparison here is against your own days, except where a fixed reference is named above. Not a diagnostic measure."))
    }

    /// "Your usual" — the band every non-glucose verdict in the app is measured
    /// against. Published because a band the user cannot reconstruct is just
    /// another opaque score.
    static var usualBand: LearnArticle {
        methodNote(
            topic: .usualBand,
            title: String(localized: "What “your usual” means"),
            verdict: String(localized: "Your usual is the middle of your own recent days."),
            body: String(localized: "Maude takes the days it actually has for a signal, finds their middle, and adds the spread those days usually have. **That band is your usual.** Nothing in it comes from anyone else, and no day is invented to fill a gap — a day without a reading is simply not in the window."),
            meaningHeadline: String(localized: "A band, not a line."),
            meaningBody: String(localized: "Bodies move from day to day. A single number would make every ordinary day look like a change. The band is wide enough to hold your ordinary days, so when a reading sits outside it, that is worth a second look — and even then it is one day, not a story."),
            clinicalTitle: String(localized: "Your usual · rule"),
            clinicalVerdict: String(localized: "Mean ± 1 standard deviation, over the days actually present."),
            inPlainWords: String(localized: "Maude averages your own recent days and adds their usual spread. Inside that band is your ordinary; outside it is worth a glance. You never need this page to use the app."),
            methodHeadline: String(localized: "Computed on this phone, from your days only."),
            methodRows: [
                .init(label: String(localized: "Input"), value: String(localized: "Your own daily values")),
                .init(label: String(localized: "Window"), value: String(localized: "Every day present — gaps are never filled")),
                .init(label: String(localized: "Band"), value: String(localized: "mean − 1 SD … mean + 1 SD")),
                .init(label: String(localized: "Minimum"), value: String(localized: "About 5 days before a band is drawn")),
                .init(label: String(localized: "Re-learned"), value: String(localized: "Every time new days arrive")),
                .init(label: String(localized: "Never used"), value: String(localized: "Population or clinical reference ranges")),
            ])
    }

    /// The evening day score — the app's only composite figure, and therefore the
    /// one most at risk of reading as an opaque score. Its legs and its single
    /// non-personal reference are published here.
    static var dayScore: LearnArticle {
        methodNote(
            topic: .dayScore,
            title: String(localized: "What the evening score adds up"),
            verdict: String(localized: "Three fractions, added together. That's the whole score."),
            body: String(localized: "Sleep is worth up to 50, glucose up to 30, recovery up to 20 — 100 in total. **Each part is printed next to the ring**, so you can add it up yourself. If a part has no data today, the score is out of less than 100 and says so."),
            meaningHeadline: String(localized: "One leg isn't only about you."),
            meaningBody: String(localized: "The sleep leg is measured against a fixed 8-hour reference rather than your own average, because a night compared only against your own recent nights can't tell a short week from a short night. It is the one part of the score that isn't purely personal — which is exactly why it is written down here rather than hidden."),
            clinicalTitle: String(localized: "Day score · rule"),
            clinicalVerdict: String(localized: "A sum of three capped fractions — no model, no weighting you can't see."),
            inPlainWords: String(localized: "Each leg is a simple fraction of your day, capped so one very good part can't carry the whole score. They are added, and that sum is the number in the ring."),
            methodHeadline: String(localized: "Each leg, exactly as it is computed."),
            methodRows: [
                .init(label: String(localized: "Sleep · 50"), value: String(localized: "last night ÷ 8-hour reference, capped at 1, × 50")),
                .init(label: String(localized: "Glucose · 30"), value: String(localized: "today's time in range ÷ 100 × 30")),
                .init(label: String(localized: "Recovery · 20"), value: String(localized: "today ÷ your own week average, capped at 1, × 20")),
                .init(label: String(localized: "Shown when"), value: String(localized: "At least 2 of the 3 legs have your data")),
                .init(label: String(localized: "Sleep detail"), value: String(localized: "Same shape: rest 50 · depth 30 · rhythm 20")),
                .init(label: String(localized: "Never"), value: String(localized: "A hidden model, or a leg you can't see")),
            ],
            // The Sleep leg above divides by an 8-hour reference — this note
            // may not then claim the app compares you only to yourself.
            comparesOnlyToYou: false)
    }

    /// The evidence gate — why Maude stays quiet. Published because "we found
    /// nothing" is only trustworthy when the threshold is visible.
    static var evidenceGate: LearnArticle {
        methodNote(
            topic: .evidenceGate,
            title: String(localized: "When Maude says a pattern is real"),
            verdict: String(localized: "A pattern has to clear three tests before you're told about it."),
            body: String(localized: "It needs enough paired days, a strong enough relationship, and a low enough chance of coincidence. **If any one of the three falls short, Maude says it is still learning instead of guessing.** Most of the time, that is what it says."),
            meaningHeadline: String(localized: "Together isn't because."),
            meaningBody: String(localized: "Two things moving together is not proof that one causes the other. The gate exists so you are never handed a story your own data cannot carry — and so the times Maude does speak up are worth reading."),
            clinicalTitle: String(localized: "Evidence gate · rule"),
            clinicalVerdict: String(localized: "|r| ≥ 0.40, two-tailed p ≤ 0.05, N ≥ 10 paired days."),
            inPlainWords: String(localized: "r measures how tightly two of your signals move together, p is the chance of seeing that by luck, and N is how many of your days went into it. All three have to pass."),
            methodHeadline: String(localized: "The gate, as the app applies it."),
            methodRows: [
                .init(label: String(localized: "Paired days (N)"), value: "≥ 10"),
                .init(label: String(localized: "Strength (r)"), value: "|r| ≥ 0.40"),
                .init(label: String(localized: "Two-tailed p"), value: "≤ 0.05"),
                .init(label: String(localized: "Called strong at"), value: "|r| ≥ 0.60"),
                .init(label: String(localized: "Below the gate"), value: String(localized: "Still learning — nothing asserted")),
                .init(label: String(localized: "Pooled with others"), value: String(localized: "Never — your paired days only")),
            ])
    }

    /// Why the sentences never surprise you. Published because a fixed vocabulary
    /// is a safety property, and safety properties should be readable.
    static var verdictWords: LearnArticle {
        methodNote(
            topic: .verdictWords,
            title: String(localized: "Why the words never change"),
            verdict: String(localized: "Every verdict comes from a short, fixed list of sentences."),
            body: String(localized: "Steady. As usual. Worth a look. **Nothing on these screens is written fresh for you each day.** The figures change and pick the sentence; the sentences themselves were written once, reviewed, and frozen."),
            meaningHeadline: String(localized: "That's what makes it safe to read."),
            meaningBody: String(localized: "A fixed vocabulary means no invented reassurance and no invented alarm. Every sentence is checked against a safety list before it can ship: none of them may carry a dose, a treatment instruction, a diagnosis, or a clinical verdict about your readings. Maude describes your own data and routes you to a clinician — it does not practise medicine."),
            clinicalTitle: String(localized: "Verdict vocabulary · rule"),
            clinicalVerdict: String(localized: "Fixed templates, selected by derived figures, checked by an output allow-list."),
            inPlainWords: String(localized: "The app picks a sentence from a list using your numbers. It never composes one. Every sentence on the list has already been checked for the things a wellness app must not say."),
            methodHeadline: String(localized: "How a sentence gets onto a screen."),
            methodRows: [
                .init(label: String(localized: "Source"), value: String(localized: "Fixed templates, chosen by your figures")),
                .init(label: String(localized: "Checked by"), value: String(localized: "An output allow-list, before release")),
                .init(label: String(localized: "May never contain"), value: String(localized: "A dose, a treatment instruction, a diagnosis, a clinical verdict")),
                .init(label: String(localized: "Framing"), value: String(localized: "Descriptive, and relative to your own baseline")),
                .init(label: String(localized: "Marked days"), value: String(localized: "Can only remove a comparison, never add one")),
            ])
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
        .background(MaudeTheme.paper)
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
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }

        deeperLink(label: article.deeperLinkLabel) { tierOverride = .clinical }

        Text("The deeper layer is always one tap away — Maude never hides your real data.")
            .font(.lato(11)).lineSpacing(2)
            .foregroundStyle(MaudeTheme.ink4)
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
                .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                .foregroundStyle(MaudeTheme.moss)
            Text(article.inPlainWords)
                .font(.lato(13)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15).padding(.vertical, 13)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.moss3, lineWidth: 1))
        .padding(.horizontal, 16)

        if let kicker = article.weekKicker, let headline = article.weekHeadline,
           let chart = article.weekChart {
            MetricDCard(kicker: kicker, headline: headline) {
                VStack(alignment: .leading, spacing: 8) {
                    AreaTrendChart(values: chart.series, tint: article.tint,
                                   height: 120, xTicks: chart.ticks, unit: chart.unit,
                                   daySlots: chart.slots)
                    if let annotation = chart.annotation {
                        HStack(spacing: 6) {
                            Circle().fill(article.tint).frame(width: 6, height: 6)
                            Text(annotation)
                                .font(.maudeMono(11))
                                .foregroundStyle(MaudeTheme.ink3)
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
                            .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
                        Spacer()
                        Text(row.value)
                            .font(.lato(12.5, .semibold)).foregroundStyle(MaudeTheme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 6)
                    if i < article.methodRows.count - 1 {
                        Rectangle().fill(MaudeTheme.line).frame(height: 0.5)
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
                .foregroundStyle(MaudeTheme.ink2)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(MaudeTheme.paper2))
                .overlay(Capsule().stroke(MaudeTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to \(back)")
            Spacer()
            Text(title)
                .font(.maudeSerif(16)).kerning(-0.1)
                .foregroundStyle(MaudeTheme.ink)
        }
        .padding(.top, 14).padding(.horizontal, 20)
    }

    private func bodyCard(_ markdown: String) -> some View {
        Text((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown))
            .font(.lato(14)).lineSpacing(4)
            .foregroundStyle(MaudeTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 15)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card)
                .stroke(MaudeTheme.line, lineWidth: 0.5))
            .padding(.horizontal, 16)
    }

    private func deeperLink(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MaudeTheme.moss)
                Text(label)
                    .font(.lato(13, .bold))
                    .foregroundStyle(MaudeTheme.moss)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MaudeTheme.moss)
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .background(MaudeTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.lato(11)).lineSpacing(2)
            .foregroundStyle(MaudeTheme.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24).padding(.top, 4)
    }
}

// MARK: - Topic entry point (resolves live data from AppState)

extension LearnArticleView {
    /// Open a topic with the user's live derived figures. The chat "Show me the
    /// numbers" chip and the MAUDE_OPEN_LEARN debug hook enter here.
    init(topic: LearnTopic, appState: AppState, startTier: LearnTier? = nil) {
        switch topic {
        case .hrv:
            // ONE "this week" (NFR-VIZ-DAY-02). The deriver owns the up-to-60-day
            // figures; the seven days are always the app's canonical HRV week —
            // the same series the Recovery pillar and the Insights week plot — so
            // this page can never name a different day as the week's extreme.
            let signals = appState.todaySignals
            self.init(article: LearnLibrary.hrv(
                detail: HRVLearnDeriver.reconciled(appState.hrvLearn, with: signals),
                weekFallback: signals?.hrvWeek ?? [],
                weekSlots: HRVLearnDeriver.canonicalWeek(signals)),
                startTier: startTier)
        // Method notes (FR-XPL-01) carry no live figures by design — see
        // LearnLibrary.methodNote — so they need nothing from AppState.
        case .usualBand:    self.init(article: LearnLibrary.usualBand, startTier: startTier)
        case .dayScore:     self.init(article: LearnLibrary.dayScore, startTier: startTier)
        case .evidenceGate: self.init(article: LearnLibrary.evidenceGate, startTier: startTier)
        case .verdictWords: self.init(article: LearnLibrary.verdictWords, startTier: startTier)
        }
    }
}
