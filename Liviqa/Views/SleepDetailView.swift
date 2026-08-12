// SleepDetailView.swift — A7.2 Area ④: the Sleep metric detail, rebuilt to the
// DSleep editorial anatomy (design_handoff_liviqa_a7: d-insights.jsx DSleep +
// charts.jsx SleepDepthChart/CompareBars).
//
// DATA HONESTY (checked against ingestion, 2026-08-13): sleep segments carry
// their wall-clock start and the awake stage, so the søkort depth chart, the
// wake-up moment, the AWAKE tile and the bedtime card now render from the
// citizen's OWN night whenever the source recorded one. When it didn't (an
// aggregated import, a hand-logged night) the deriver returns nil for those
// pieces and the screen falls back to exactly the reduced anatomy it had
// before — stage totals + share, nightly week vs own mean, duration vs last
// week. The clearly-demo seeds still exist, and still only for a demo session
// with no derivation at all.
//
// Bedtime is compared to the citizen's OWN mean bedtime — never to a
// recommended one. There is no correct hour on this screen.
//
// The hero score ring is the SAME transparent, decomposed arithmetic stance as
// the evening day score (FR-TOD-05 / anti-score-opacity): three visible
// fractions (rest / depth / rhythm), printed under the hero — never an opaque
// composite. All sentences are fixed descriptive templates (FR-NDG-06 rail).
import SwiftUI

struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the hero verdict and the three score legs, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: SleepWeekDetail? { appState.sleepDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    hero(model)
                    SeeWhyHeroRow { seeWhy = sleepWhy(model) }
                    if !model.stats.isEmpty { MetricStatRow(items: model.stats) }
                    if let shape = model.shape { depthCard(shape) }
                    else if model.showDemoDepthChart { demoDepthCard }
                    if !model.stageRows.isEmpty { stageCard(model) }
                    if model.nights.count >= 2 { weekCard(model) }
                    if let sentence = model.compareSentence, !model.compareRows.isEmpty {
                        compareCard(model, sentence: sentence)
                    }
                    if let bedtime = model.bedtime { bedtimeCard(bedtime) }
                    else if model.showDemoDepthChart { demoBedtimeCard }
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

    /// The hero verdict decomposed: last night, the real nights behind the week
    /// average, the difference, and — where the ring renders — each score leg's
    /// arithmetic with its fixed references named out loud.
    private func sleepWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.sleepHero(
            verdict: m.verdict,
            asleepMin: m.asleepMin,
            weekMeanMin: Int((m.weekMeanHours * 60).rounded()),
            nightCount: m.nights.count,
            rest: m.score?.rest, depth: m.score?.depth, rhythm: m.score?.rhythm,
            deepMin: m.stageRows.first(where: { $0.0 == "Deep" })?.1 ?? 0,
            remMin: m.stageRows.first(where: { $0.0 == "REM" })?.1 ?? 0,
            source: detail?.source,
            isSeed: detail == nil)
    }

    // MARK: - Screen model (derived figures → fixed descriptive templates)

    struct Model {
        var verdict: String
        var statText: String
        var sub: String
        var score: SleepDetailDeriver.Score?
        var stats: [(String, String)]
        var stageRows: [(String, Int, Color)]      // name, minutes, colour
        var asleepMin: Int
        var nights: [SleepWeekDetail.Night]
        var weekMeanHours: Double
        var weekHeadline: String
        var compareSentence: String?
        var compareRows: [MetricCompareRow]
        /// Last night as a real shape — nil when the source kept no times.
        var shape: SleepNightShape? = nil
        /// Bedtime vs the citizen's own usual — nil below 3 timed nights.
        var bedtime: SleepBedtimeWeek? = nil
        var showDemoDepthChart: Bool
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        // Design-package seeds — demo builds only, never over a real-data session.
        return appState.isDemoData ? .designSeed : nil
    }

    // MARK: - Hero

    private func hero(_ m: Model) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MetricHero(tint: LiviqaTheme.accentSleep,
                       kicker: "Sleep · last night",
                       verdict: m.verdict,
                       stat: m.statText,
                       sub: scoreLine(m) ?? m.sub) {
                if let score = m.score {
                    ScoreRing(score: score.total,
                              segments: [
                                ScoreSegment(name: "Rest", val: score.rest, max: 50, color: .white),
                                ScoreSegment(name: "Depth", val: score.depth, max: 30, color: .white.opacity(0.7)),
                                ScoreSegment(name: "Rhythm", val: score.rhythm, max: 20, color: .white.opacity(0.45)),
                              ],
                              size: 78, textColor: .white)
                }
            }
        }
    }

    /// The visible arithmetic under the score ring (anti-score-opacity) —
    /// replaces the sub line whenever a score renders.
    private func scoreLine(_ m: Model) -> String? {
        guard let s = m.score else { return nil }
        return "Rest \(Int(s.rest.rounded()))/50 · Depth \(Int(s.depth.rounded()))/30 · Rhythm \(Int(s.rhythm.rounded()))/20 — \(m.sub)"
    }

    // MARK: - Cards

    /// The citizen's OWN night, drawn as depth. Every figure printed here is a
    /// real total from their segments; only the label positions are chosen.
    private func depthCard(_ shape: SleepNightShape) -> some View {
        let names = ["AWAKE", "REM", "CORE", "DEEP"]
        return MetricDCard(kicker: "The night, as depth",
                           headline: Self.depthHeadline(shape)) {
            SleepDepthChart(
                segments: shape.segments.map {
                    SleepDepthSegment(stage: $0.stage, t0: $0.t0, t1: $0.t1)
                },
                soundings: shape.soundings.map {
                    ($0.t, SleepDepthChart.stageDepth[$0.stage],
                     minText($0.minutes), names[$0.stage])
                },
                wakeT: shape.wake?.t,
                wakeLabel: shape.wake.map { "\($0.clock) — up for a moment" },
                edgeStart: shape.startClock, edgeEnd: shape.endClock)
        }
    }

    /// Fixed descriptive templates over derived facts (FR-NDG-06 rail): where
    /// the deep stretches actually sat, and whether the night was unbroken.
    static func depthHeadline(_ shape: SleepNightShape) -> String {
        if let wake = shape.wake {
            return "One wake-up at \(wake.clock) — then back down."
        }
        let deep = shape.segments.filter { $0.stage == 3 }
        guard !deep.isEmpty else { return "The night, start to finish." }
        let centre = deep.reduce(0.0) { $0 + ($1.t0 + $1.t1) / 2 } / Double(deep.count)
        if centre < 0.45 { return "A calm descent — the deepest water came early." }
        if centre > 0.6 { return "The deepest water came late in the night." }
        return "The deep stretches sat in the middle of the night."
    }

    /// Bedtime against the citizen's own usual — never a recommended hour.
    private func bedtimeCard(_ b: SleepBedtimeWeek) -> some View {
        // Bar length = how late each mean bedtime was, on one shared scale, so
        // the two rows can only differ by a difference that is actually there.
        let top = Double(max(b.thisWeekMinutes, b.prevWeekMinutes ?? 0)) * 1.08
        var rows: [MetricCompareRow] = []
        rows.append(MetricCompareRow(value: "\(b.thisWeekClock) avg", label: "THIS WEEK",
                                     frac: top > 0 ? Double(b.thisWeekMinutes) / top : 1,
                                     on: true))
        if let prev = b.prevWeekClock, let prevMin = b.prevWeekMinutes {
            rows.append(MetricCompareRow(value: "\(prev) avg", label: "LAST WEEK",
                                         frac: top > 0 ? Double(prevMin) / top : 1,
                                         on: false))
        }
        return MetricDCard(
            kicker: "Bedtime · this week",
            headline: "Within half an hour of your own usual, \(b.nightsNearUsual) of \(b.nightCount) nights.",
            foot: "\"Usual\" here is the average of your own bedtimes this week. There is no recommended hour on this page.") {
            MetricCompareBars(rows: rows, color: LiviqaTheme.accentSleep)
        }
    }

    /// Demo-only signature chart — used when there is no derivation at all and
    /// the session is demo-tagged.
    private var demoDepthCard: some View {
        MetricDCard(kicker: "The night, as depth",
                    headline: "A calm descent — deepest before 2 am.") {
            SleepDepthChart(
                segments: Self.demoNight,
                soundings: [(0.17, 0.86, "1h 20m", "DEEP"),
                            (0.795, 0.2, "1h 44m", "REM"),
                            (0.44, 0.5, "4h 06m", "CORE")],
                wakeT: 0.632,
                wakeLabel: "02:10 — up for a moment",
                edgeStart: "23:04", edgeEnd: "06:14")
        }
    }

    private var demoBedtimeCard: some View {
        MetricDCard(kicker: "Bedtime · this week",
                    headline: "Within 20 min of your usual, 6 nights of 7.") {
            MetricCompareBars(rows: [
                MetricCompareRow(value: "23:04 avg", label: "THIS WEEK", frac: 0.92, on: true),
                MetricCompareRow(value: "23:26 avg", label: "LAST WEEK", frac: 0.86, on: false),
            ], color: LiviqaTheme.accentSleep)
        }
    }

    private func stageCard(_ m: Model) -> some View {
        let total = max(1, m.stageRows.reduce(0) { $0 + $1.1 })
        let deepRemPct = Int((Double(m.stageRows.filter { $0.0 != "Core" }
            .reduce(0) { $0 + $1.1 }) / Double(total) * 100).rounded())
        return MetricDCard(kicker: "The night, by stage",
                           headline: "About \(deepRemPct)% of the night in Deep and REM.") {
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(m.stageRows.enumerated()), id: \.offset) { _, s in
                            RoundedRectangle(cornerRadius: 4).fill(s.2)
                                .frame(width: max(2, geo.size.width * CGFloat(s.1) / CGFloat(total)))
                        }
                    }
                }
                .frame(height: 18)
                VStack(spacing: 5) {
                    ForEach(Array(m.stageRows.enumerated()), id: \.offset) { _, s in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(s.2).frame(width: 9, height: 9)
                            Text(s.0).font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink2)
                            Spacer()
                            Text("\(minText(s.1))  ·  \(Int((Double(s.1) / Double(total) * 100).rounded()))%")
                                .font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
                        }
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Sleep stages")
            .accessibilityValue(m.stageRows.map { "\($0.0) \(minText($0.1))" }.joined(separator: ", "))
        }
    }

    private func weekCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Sleep · this week", headline: m.weekHeadline) {
            UsualDayBars(values: m.nights.map(\.hours),
                         labels: m.nights.map(\.label),
                         usual: m.weekMeanHours,
                         color: LiviqaTheme.accentSleep,
                         unit: "hours asleep",
                         fmt: { String(format: "%.1fh", $0) })
        }
    }

    private func compareCard(_ m: Model, sentence: String) -> some View {
        MetricDCard(kicker: "Sleep · vs last week", headline: sentence) {
            MetricCompareBars(rows: m.compareRows, color: LiviqaTheme.accentSleep)
        }
    }

    // MARK: - Honest empty state (real device, no sleep)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "moon.fill").font(.system(size: 12))
                    .foregroundStyle(LiviqaTheme.accentSleep)
                Text("SLEEP")
                    .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text("No sleep recorded yet.")
                .font(.liviqaSerif(21)).kerning(-0.2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 9)
            Text("When a watch or sleep app shares to Apple Health, this page fills with your own nights — stages, your week, and how it compares to your usual. Everything stays on this phone.")
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func minText(_ mins: Int) -> String {
        "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
    }

    /// The design package's demo night (charts.jsx SleepDepthChart), verbatim.
    static let demoNight: [SleepDepthSegment] = [
        .init(stage: 0, t0: 0, t1: 0.03), .init(stage: 2, t0: 0.03, t1: 0.12),
        .init(stage: 3, t0: 0.12, t1: 0.22), .init(stage: 2, t0: 0.22, t1: 0.30),
        .init(stage: 1, t0: 0.30, t1: 0.38), .init(stage: 2, t0: 0.38, t1: 0.50),
        .init(stage: 3, t0: 0.50, t1: 0.56), .init(stage: 2, t0: 0.56, t1: 0.62),
        .init(stage: 0, t0: 0.62, t1: 0.645), .init(stage: 2, t0: 0.645, t1: 0.74),
        .init(stage: 1, t0: 0.74, t1: 0.85), .init(stage: 2, t0: 0.85, t1: 0.95),
        .init(stage: 1, t0: 0.95, t1: 1),
    ]
}

// MARK: - Model building

extension SleepDetailView.Model {

    /// Derived figures → fixed descriptive templates (no generated language).
    init(derived d: SleepWeekDetail) {
        let night = Double(d.asleepMin) / 60
        let mean = Double(d.weekMeanMin) / 60

        // Verdict: last night vs the user's OWN week mean (±30 min = usual).
        let verdict: String
        if d.nights.count >= 3 {
            if abs(night - mean) <= 0.5 { verdict = "You slept like your usual self." }
            else if night > mean { verdict = "A longer night than your usual." }
            else { verdict = "A shorter night than your usual." }
        } else {
            verdict = "Last night, as your watch recorded it."
        }

        var subParts: [String] = []
        if let wake = d.shape?.wake {
            subParts.append("One wake-up at \(wake.clock) — then straight back down.")
        }
        if d.hasStageDetail {
            subParts.append("Deep \(Self.minText(d.deepMin)) · REM \(Self.minText(d.remMin)) · Core \(Self.minText(d.coreMin))")
        }
        // The mock provider's internal name must never read as a device name —
        // in demo the honest label is the same one the chip uses.
        if let src = d.source {
            subParts.append(src.caseInsensitiveCompare("Mock") == .orderedSame
                            ? String(localized: "Sample data") : src)
        }

        var stats: [(String, String)] = d.hasStageDetail
            ? [(Self.minText(d.deepMin), "DEEP"),
               (Self.minText(d.remMin), "REM"),
               (Self.minText(d.coreMin), "CORE")]
            : []
        // AWAKE only when the source actually recorded time awake in the night.
        if d.awakeMin > 0, !stats.isEmpty {
            stats.append(("\(d.awakeMin)m", "AWAKE"))
        }

        let stageRows: [(String, Int, Color)] = d.hasStageDetail
            ? [("Deep", d.deepMin, LiviqaTheme.accentSleep),
               ("REM", d.remMin, LiviqaTheme.accentSleep.opacity(0.65)),
               ("Core", d.coreMin, LiviqaTheme.accentSleep.opacity(0.35))]
            : []

        let closeNights = d.nights.filter { abs($0.hours - mean) <= 0.5 }.count
        let weekHeadline = d.nights.count >= 2
            ? "\(closeNights) of \(d.nights.count) nights within about half an hour of your usual."
            : ""

        var compareSentence: String? = nil
        var compareRows: [MetricCompareRow] = []
        if let prev = d.prevWeekMeanMin, d.nights.count >= 3 {
            let diff = d.weekMeanMin - prev
            if diff >= 15 { compareSentence = "More sleep a night than last week." }
            else if diff <= -15 { compareSentence = "Less sleep a night than last week." }
            else { compareSentence = "About the same nightly sleep as last week." }
            let top = Double(max(d.weekMeanMin, prev)) * 1.08
            compareRows = [
                MetricCompareRow(value: "\(Self.minText(d.weekMeanMin)) avg", label: "THIS WEEK",
                                 frac: Double(d.weekMeanMin) / top, on: true),
                MetricCompareRow(value: "\(Self.minText(prev)) avg", label: "LAST WEEK",
                                 frac: Double(prev) / top, on: false),
            ]
        }

        self.init(
            verdict: verdict,
            statText: Self.minText(d.asleepMin),
            sub: subParts.joined(separator: " · "),
            score: SleepDetailDeriver.score(of: d),
            stats: stats,
            stageRows: stageRows,
            asleepMin: d.asleepMin,
            nights: d.nights,
            weekMeanHours: mean,
            weekHeadline: weekHeadline,
            compareSentence: compareSentence,
            compareRows: compareRows,
            shape: d.shape,
            bedtime: d.bedtime,
            showDemoDepthChart: false)
    }

    /// The design package's demo story (d-insights.jsx DSleep), verbatim.
    /// Rendered ONLY when no derivation exists AND the session is demo-tagged.
    static var designSeed: Self {
        .init(
            verdict: "You slept like your usual self.",
            statText: "7h 10m",
            sub: "One brief wake-up at 02:10 — then straight back down.",
            score: .init(rest: 45, depth: 26, rhythm: 16),
            stats: [("1h 20m", "DEEP"), ("1h 44m", "REM"),
                    ("4h 06m", "CORE"), ("12m", "AWAKE")],
            stageRows: [],
            asleepMin: 430,
            nights: [
                .init(label: "M", hours: 7.2, isLastNight: false),
                .init(label: "T", hours: 6.8, isLastNight: false),
                .init(label: "W", hours: 7.4, isLastNight: false),
                .init(label: "T", hours: 6.9, isLastNight: false),
                .init(label: "F", hours: 7.1, isLastNight: false),
                .init(label: "S", hours: 7.6, isLastNight: false),
                .init(label: "S", hours: 7.2, isLastNight: true),
            ],
            weekMeanHours: 7.17,
            weekHeadline: "6 of 7 nights within about half an hour of your usual.",
            compareSentence: "About the same nightly sleep as last week.",
            compareRows: [
                MetricCompareRow(value: "7h 10m avg", label: "THIS WEEK", frac: 0.92, on: true),
                MetricCompareRow(value: "7h 02m avg", label: "LAST WEEK", frac: 0.90, on: false),
            ],
            showDemoDepthChart: true)
    }

    private static func minText(_ mins: Int) -> String {
        "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
    }
}
