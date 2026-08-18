// SleepDetailView.swift — A7.2 Area ④: the Sleep metric detail, rebuilt on the
// ONE-TRUTH night model (sleep visualisation wave 2026-08, DHF 2026-08-19).
//
// THE PRIME RULE — "don't mess up the data": every figure on this screen is a
// STORED PROPERTY of one `Model`, computed exactly once in its init from one
// `SleepWeekDetail` (whose own figures are copies of one `SleepNight`,
// deriver-asserted). View code below the fold renders those properties and
// never formats or recomputes a number — enforced structurally by a source
// lint (SleepScreenModelTests.viewCodeFormatsNoFigures) and behaviourally by
// the agreement walk (every number in every displayed string traces back to
// the model's canonical figures). The same-screen contradiction CN
// photographed (tiles "Core 7h21m" vs chart "16h20m") has no code path left:
// there is no second arithmetic to disagree with.
//
// ANATOMY (benchmark: Apple Health sleep, done in Liviqa's own language):
//   · hero — serif verdict + TIME ASLEEP (the verdict figure), decomposed score
//   · TIME IN BED as a separate mono figure — never conflated with asleep;
//     "—" with a why when the source recorded none (never estimated)
//   · D — stage tiles · BLOCK HYPNOGRAM (four lanes, rounded blocks, risers,
//     hour gridlines, in-bed underlay, wake annotation; draw-time merge is
//     disclosed and never touches data) · stage-share card · Highlights
//   · W — nights as stage-striped columns at their OWN clock time on the
//     22:00→14:00 axis, the citizen's own usual-bedtime band behind them;
//     bedtime + week-vs-week cards
//   · M / 6M — nightly duration on the day axis; gaps stay gaps
//
// RAILS: all sentences are fixed descriptive templates (FR-NDG-06, guard-
// tested); every comparison is to the citizen's OWN usual (never a target);
// awake renders in the theme's rust brick, never clinRed (RK-ALARM-01);
// provenance never renders; demo figures exist only behind isSampleMode.
import SwiftUI

struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the hero verdict and the three score legs, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil
    @State private var range: SleepRange = .day

    private var detail: SleepWeekDetail? { appState.sleepDetail }

    enum SleepRange: String, CaseIterable, Identifiable {
        case day = "D", week = "W", month = "M", sixMonths = "6M"
        var id: String { rawValue }
        var a11yName: String {
            switch self {
            case .day: return "Last night"
            case .week: return "Week"
            case .month: return "Month"
            case .sixMonths: return "Six months"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    hero(model)
                    SeeWhyHeroRow { seeWhy = sleepWhy(model) }
                    figuresRow(model)
                    rangePicker
                    switch range {
                    case .day:
                        if !model.stats.isEmpty { MetricStatRow(items: model.stats) }
                        if !model.hypnoSegments.isEmpty { hypnogramCard(model) }
                        if !model.stageRows.isEmpty { stageCard(model) }
                        if !model.highlights.isEmpty { highlightsCard(model) }
                    case .week:
                        if let wk = model.weekClock { clockWeekCard(model, wk) }
                        else if model.nights.count >= 2 { weekCard(model) }
                        else { rangeEmptyCard(kicker: "Sleep · this week") }
                        if model.bedtimeHeadline != nil { bedtimeCard(model) }
                        if let sentence = model.compareSentence, !model.compareRows.isEmpty {
                            compareCard(model, sentence: sentence)
                        }
                    case .month:
                        if let t = model.monthTrend { trendCard(t, kicker: "Sleep · past month") }
                        else { rangeEmptyCard(kicker: "Sleep · past month") }
                    case .sixMonths:
                        if let t = model.sixMonthTrend { trendCard(t, kicker: "Sleep · six months") }
                        else { rangeEmptyCard(kicker: "Sleep · six months") }
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

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        // Design seed — demo sessions only, never over a real-data session, and
        // built THROUGH the real deriver so even the demo cannot self-contradict.
        return appState.isSampleMode ? .designSeed : nil
    }

    /// The hero verdict decomposed: last night, the real nights behind the week
    /// average, the difference, and — where the ring renders — each score leg's
    /// arithmetic with its fixed references named out loud.
    private func sleepWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.sleepHero(
            verdict: m.verdict,
            asleepMin: m.asleepMin,
            weekMeanMin: m.weekMeanMin,
            nightCount: m.nights.count,
            rest: m.score?.rest, depth: m.score?.depth, rhythm: m.score?.rhythm,
            deepMin: m.deepMin,
            remMin: m.remMin,
            source: detail?.source,
            isSeed: detail == nil)
    }

    // MARK: - Hero

    private func hero(_ m: Model) -> some View {
        MetricHero(tint: LiviqaTheme.accentSleep,
                   kicker: "Sleep · last night",
                   verdict: m.verdict,
                   stat: m.statText,
                   unit: "asleep",
                   sub: m.heroSub) {
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

    /// TIME IN BED — the second honest headline figure, mono, never conflated
    /// with TIME ASLEEP. "—" with its why when the source recorded none.
    private func figuresRow(_ m: Model) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("TIME IN BED")
                    .font(.liviqaKicker(9.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(m.inBedText)
                    .font(.liviqaMono(14)).foregroundStyle(LiviqaTheme.ink)
                Spacer()
                if let span = m.nightSpanText {
                    Text(span).font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
                }
            }
            if let foot = m.inBedFoot {
                Text(foot).font(.lato(11)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            if let note = m.scoreNote {
                Text(note).font(.lato(11)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Range selector (A7.2 segmented style, as Trends)

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(SleepRange.allCases) { chip in
                Button(chip.rawValue) { range = chip }
                    .font(.liviqaKicker(11))
                    .tracking(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(range == chip ? LiviqaTheme.paper2 : Color.clear)
                    .foregroundStyle(range == chip ? LiviqaTheme.ink : LiviqaTheme.ink3)
                    .fontWeight(range == chip ? .medium : .regular)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .shadow(color: range == chip ? LiviqaTheme.cardShadow : .clear,
                            radius: 2, y: 1)
                    .accessibilityLabel(chip.a11yName)
            }
        }
        .padding(3)
        .background(LiviqaTheme.line2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    // MARK: - D · the block hypnogram

    private func hypnogramCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Last night, by the clock",
                    headline: m.hypnogramHeadline) {
            SleepBlockHypnogram(
                segments: m.hypnoSegments,
                hourMarks: m.hourMarks,
                inBedSpan: m.inBedSpanT,
                wakeT: m.wakeT,
                wakeLabel: m.wakeLabel,
                edgeStart: m.edgeStart,
                edgeEnd: m.edgeEnd,
                a11ySummary: m.hypnogramA11y)
        }
    }

    private func stageCard(_ m: Model) -> some View {
        MetricDCard(kicker: "The night, by stage",
                    headline: m.stageShareHeadline) {
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(m.stageRows.enumerated()), id: \.offset) { _, s in
                            RoundedRectangle(cornerRadius: 4).fill(s.color)
                                .frame(width: max(2, geo.size.width * CGFloat(s.minutes) / CGFloat(m.stageTotalMin)))
                        }
                    }
                }
                .frame(height: 18)
                VStack(spacing: 5) {
                    ForEach(Array(m.stageRows.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(s.color).frame(width: 9, height: 9)
                            Text(s.name).font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink2)
                            Spacer()
                            Text(m.stageRowTexts[i])
                                .font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
                        }
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Sleep stages")
            .accessibilityValue(m.stageA11y)
        }
    }

    private func highlightsCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Highlights") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(m.highlights.enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: h.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(LiviqaTheme.accentSleep)
                            .frame(width: 18)
                            .padding(.top, 1)
                        Text(h.text)
                            .font(.lato(13)).lineSpacing(2.5)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - W · nights at their own clock time

    private func clockWeekCard(_ m: Model, _ wk: Model.ClockWeekRender) -> some View {
        MetricDCard(kicker: "This week · each night at its own hour",
                    headline: m.weekHeadline.isEmpty ? nil : m.weekHeadline,
                    foot: wk.foot) {
            SleepClockWeekChart(
                nights: wk.nights,
                axisMarks: wk.axisMarks,
                usualBand: wk.usualBand,
                usualLabel: wk.usualLabel,
                a11ySummary: wk.a11y)
        }
    }

    /// Duration fallback when no night this week carries clock times — the
    /// honest reduced anatomy, never an invented column.
    private func weekCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Sleep · this week", headline: m.weekHeadline) {
            UsualDayBars(values: m.nights.map(\.hours),
                         labels: m.nights.map(\.label),
                         usual: m.weekMeanHours,
                         color: LiviqaTheme.accentSleep,
                         unit: "hours asleep",
                         fmt: Model.hoursText)
        }
    }

    /// Bedtime against the citizen's own usual — never a recommended hour.
    private func bedtimeCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Bedtime · this week",
                    headline: m.bedtimeHeadline,
                    foot: m.bedtimeFoot) {
            MetricCompareBars(rows: m.bedtimeRows, color: LiviqaTheme.accentSleep)
        }
    }

    private func compareCard(_ m: Model, sentence: String) -> some View {
        MetricDCard(kicker: "Sleep · vs last week", headline: sentence) {
            MetricCompareBars(rows: m.compareRows, color: LiviqaTheme.accentSleep)
        }
    }

    // MARK: - M / 6M · duration on the day axis

    private func trendCard(_ t: Model.TrendRender, kicker: String) -> some View {
        MetricDCard(kicker: kicker, headline: t.headline) {
            SleepDurationTrendChart(
                values: t.values,
                usual: t.usual,
                usualLabel: t.usualLabel,
                edgeStart: t.edgeStart,
                edgeEnd: t.edgeEnd,
                a11ySummary: t.a11y)
        }
    }

    private func rangeEmptyCard(kicker: String) -> some View {
        MetricDCard(kicker: kicker, headline: Model.rangeEmptyHeadline) {
            EmptyView()
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

    /// Fixed descriptive templates over derived facts (FR-NDG-06 rail): where
    /// the deep stretches actually sat, and whether the night was unbroken.
    static func depthHeadline(_ shape: SleepNightShape) -> String {
        if let wake = shape.wake {
            return "One wake-up at \(wake.clock) — then back down."
        }
        let deep = shape.segments.filter { $0.stage == 3 }
        guard !deep.isEmpty else { return "The night, start to finish." }
        let centre = deep.reduce(0.0) { $0 + ($1.t0 + $1.t1) / 2 } / Double(deep.count)
        if centre < 0.45 { return "A calm descent — the deep stretches came early." }
        if centre > 0.6 { return "The deep stretches came late in the night." }
        return "The deep stretches sat in the middle of the night."
    }
}

// MARK: - Screen model building
//
// EVERYTHING below computes; everything above renders. The source lint in
// SleepScreenModelTests holds that line: no `String(format:`/`minText(`/
// `.rounded()` may appear above this marker.

extension SleepDetailView {

    /// ONE render model per screen. Every displayed figure is a stored
    /// property assigned here, from one `SleepWeekDetail` (itself copies of one
    /// `SleepNight`, deriver-asserted) — so no two surfaces can disagree.
    struct Model {

        struct ClockWeekRender {
            var nights: [SleepClockNight]
            var axisMarks: [(f: Double, label: String)]
            var usualBand: (f0: Double, f1: Double)?
            var usualLabel: String
            var foot: String?
            var a11y: String
        }

        struct TrendRender {
            var values: [Double?]
            var usual: ClosedRange<Double>?
            var usualLabel: String
            var edgeStart: String
            var edgeEnd: String
            var headline: String
            var a11y: String
        }

        struct StageRow {
            var name: String
            var minutes: Int
            var color: Color
        }

        // — Canonical night figures (the single set every string below formats from)
        var asleepMin: Int
        var deepMin: Int
        var remMin: Int
        var coreMin: Int
        var awakeMin: Int
        var inBedMin: Int?
        var weekMeanMin: Int

        // — Hero
        var verdict: String
        var statText: String            // TIME ASLEEP, the verdict figure
        var sub: String
        var heroSub: String             // scoreLine when a score renders, else sub
        var score: SleepDetailDeriver.Score?
        var scoreNote: String?          // rhythm-zero clarity / not-yet note
        var inBedText: String           // TIME IN BED or "—"
        var inBedFoot: String?
        var nightSpanText: String?      // "23:04 → 06:14"

        // — Tiles
        var stats: [(String, String)]

        // — Hypnogram (D)
        var hypnoSegments: [SleepHypnoSegment]
        var hypnogramHeadline: String?
        var hourMarks: [(t: Double, label: String)]
        var inBedSpanT: (t0: Double, t1: Double)?
        var wakeT: Double?
        var wakeLabel: String?
        var edgeStart: String
        var edgeEnd: String
        var hypnogramA11y: String
        /// Demo-seed marker (legacy name, test-pinned): true only for the
        /// design seed, which exists only behind isSampleMode.
        var showDemoDepthChart: Bool

        // — Stage share (D)
        var stageRows: [StageRow]
        var stageRowTexts: [String]
        var stageTotalMin: Int
        var stageShareHeadline: String?
        var stageA11y: String

        // — Highlights (D)
        var highlights: [(icon: String, text: String)]

        // — Week (W)
        var nights: [SleepWeekDetail.Night]
        var weekMeanHours: Double
        var weekHeadline: String
        var weekClock: ClockWeekRender?
        var bedtimeHeadline: String?
        var bedtimeRows: [MetricCompareRow]
        var bedtimeFoot: String?
        var compareSentence: String?
        var compareRows: [MetricCompareRow]

        // — Month / 6M
        var monthTrend: TrendRender?
        var sixMonthTrend: TrendRender?

        static let rangeEmptyHeadline =
            "Not enough recorded nights in this window yet — it fills as nights arrive on this phone, and gaps stay gaps."

        /// Every string the screen can render, in one list — the agreement test
        /// walks this and asserts each figure traces back to the canonical set.
        func allDisplayedStrings() -> [String] {
            var out: [String] = [verdict, statText, sub, heroSub, inBedText]
            if let inBedFoot { out.append(inBedFoot) }
            if let scoreNote { out.append(scoreNote) }
            if let nightSpanText { out.append(nightSpanText) }
            out += stats.flatMap { [$0.0, $0.1] }
            if let hypnogramHeadline { out.append(hypnogramHeadline) }
            out += hourMarks.map(\.label)
            out += [edgeStart, edgeEnd]
            if let wakeLabel { out.append(wakeLabel) }
            out.append(hypnogramA11y)
            if let stageShareHeadline { out.append(stageShareHeadline) }
            out += stageRows.map(\.name)
            out += stageRowTexts
            out.append(stageA11y)
            out += highlights.map(\.text)
            out.append(weekHeadline)
            if let weekClock {
                out += weekClock.axisMarks.map(\.label)
                out += [weekClock.usualLabel, weekClock.a11y]
                if let foot = weekClock.foot { out.append(foot) }
            }
            if let bedtimeHeadline { out.append(bedtimeHeadline) }
            if let bedtimeFoot { out.append(bedtimeFoot) }
            out += bedtimeRows.flatMap { [$0.value, $0.label] }
            if let compareSentence { out.append(compareSentence) }
            out += compareRows.flatMap { [$0.value, $0.label] }
            for t in [monthTrend, sixMonthTrend].compactMap({ $0 }) {
                out += [t.headline, t.usualLabel, t.edgeStart, t.edgeEnd, t.a11y]
            }
            out.append(Self.rangeEmptyHeadline)
            return out
        }

        // MARK: Shared formatters (defined ONCE; the view passes them by name)

        nonisolated static func minText(_ mins: Int) -> String {
            "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
        }

        nonisolated static func hoursText(_ v: Double) -> String {
            String(format: "%.1fh", v)
        }

        /// "23:04" → minutes of day (1384); nil for a malformed clock.
        nonisolated static func minutesOfDay(_ clock: String) -> Int? {
            let parts = clock.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
                  (0..<24).contains(h), (0..<60).contains(m) else { return nil }
            return h * 60 + m
        }

        /// Hour gridline positions between two wall clocks on the 0…1 night
        /// axis. Labels are the real hours ("00", "02"); positions come from
        /// the night's own clocks — a mark at "02" really is 02:00.
        nonisolated static func hourMarks(startClock: String, endClock: String)
            -> [(t: Double, label: String)] {
            guard let s = minutesOfDay(startClock), let eRaw = minutesOfDay(endClock)
            else { return [] }
            var e = eRaw
            if e <= s { e += 1440 }
            let span = e - s
            guard span >= 60 else { return [] }
            let step = span > 9 * 60 ? 120 : 60
            var marks: [(Double, String)] = []
            var h = ((s + 59) / 60) * 60                 // first whole hour ≥ start
            if step == 120, (h / 60) % 2 == 1 { h += 60 }  // even hours on the 2h grid
            while h < e {
                let t = Double(h - s) / Double(span)
                if t > 0.045, t < 0.955 {                // edge clocks own the ends
                    marks.append((t, String(format: "%02d", (h / 60) % 24)))
                }
                h += step
            }
            return marks
        }

        /// The longest unbroken asleep stretch: consecutive asleep segments with
        /// no recorded wake and no gap over a minute. Returns exact minutes and
        /// the stretch's end.
        nonisolated static func longestUnbrokenStretch(_ segments: [SleepNight.Segment])
            -> (minutes: Int, end: Date)? {
            var best: (minutes: Int, end: Date)? = nil
            var runStart: Date? = nil
            var runEnd: Date? = nil
            for s in segments {
                if s.stage == .awake { runStart = nil; runEnd = nil; continue }
                if let e = runEnd, s.start.timeIntervalSince(e) <= 60 {
                    runEnd = max(e, s.end)
                } else {
                    runStart = s.start
                    runEnd = s.end
                }
                if let st = runStart, let e = runEnd {
                    let m = Int((e.timeIntervalSince(st) / 60).rounded())
                    if m > (best?.minutes ?? 0) { best = (m, e) }
                }
            }
            return best
        }

        /// SleepStage → chart lane (0 awake · 1 REM · 2 core · 3 deep) — the
        /// same scale `SleepNightShape` uses.
        nonisolated static func chartStage(_ stage: SleepStage) -> Int {
            switch stage {
            case .awake: return 0
            case .rem:   return 1
            case .deep:  return 3
            default:     return 2
            }
        }

        // MARK: The one init — derived figures → fixed descriptive templates

        /// `isDemoSeed` marks the design seed (demo sessions only); everything
        /// else is identical to the real path — the seed goes THROUGH the
        /// deriver, so even demo figures cannot self-contradict.
        init(derived d: SleepWeekDetail, isDemoSeed: Bool = false) {
            let night = d.night
            let nightHours = Double(d.asleepMin) / 60
            let mean = Double(d.weekMeanMin) / 60

            // — canonical figures
            asleepMin = d.asleepMin
            deepMin = d.deepMin
            remMin = d.remMin
            coreMin = d.coreMin
            awakeMin = d.awakeMin
            inBedMin = night.inBedMin
            weekMeanMin = d.weekMeanMin
            showDemoDepthChart = isDemoSeed

            // — verdict: last night vs the citizen's OWN week mean (±30 min = usual)
            if d.nights.count >= 3 {
                if abs(nightHours - mean) <= 0.5 { verdict = "You slept like your usual self." }
                else if nightHours > mean { verdict = "A longer night than your usual." }
                else { verdict = "A shorter night than your usual." }
            } else {
                verdict = "Last night, as your watch recorded it."
            }
            statText = Self.minText(d.asleepMin)

            // — sub line (wake moment · stage figures · source, fit for prose)
            var subParts: [String] = []
            if let wake = d.shape?.wake {
                subParts.append("One wake-up at \(wake.clock) — then straight back down.")
            }
            if d.hasStageDetail {
                subParts.append("Deep \(Self.minText(d.deepMin)) · REM \(Self.minText(d.remMin)) · Core \(Self.minText(d.coreMin))")
            }
            if let src = MetricSourceLabel.inProse(d.source) { subParts.append(src) }
            sub = subParts.joined(separator: " · ")

            // — decomposed score; a missing leg reads "—", never a false zero
            score = SleepDetailDeriver.score(of: d)
            if let s = score {
                let rest = Int(s.rest.rounded())
                let depth = Int(s.depth.rounded())
                let rhythm = Int(s.rhythm.rounded())
                heroSub = "Rest \(rest)/50 · Depth \(depth)/30 · Rhythm \(rhythm)/20 — \(sub)"
                scoreNote = rhythm == 0
                    ? "Rhythm 0 is a measurement, not a fault — last night sat two hours or more from your own week average."
                    : nil
            } else {
                heroSub = sub
                scoreNote = d.hasStageDetail && d.nights.count < 4
                    ? "The score waits for four recorded nights — until then its legs read “—” rather than a false zero."
                    : nil
            }

            // — TIME IN BED: separate figure, never estimated, never conflated
            if let bed = night.inBedMin {
                inBedText = Self.minText(bed)
                inBedFoot = night.inBedIsFromSource ? nil
                    : "In bed here is the night's own span, first sleep to final wake — this source writes no separate in-bed record."
            } else {
                inBedText = "—"
                inBedFoot = "This source didn't record time in bed — the figure appears only when recorded, never estimated."
            }
            if let fell = night.fellAsleepClock, let woke = night.wokeUpClock {
                nightSpanText = "\(fell) → \(woke)"
            } else {
                nightSpanText = nil
            }

            // — tiles (AWAKE only when the source recorded time awake in the night)
            var tiles: [(String, String)] = d.hasStageDetail
                ? [(Self.minText(d.deepMin), "DEEP"),
                   (Self.minText(d.remMin), "REM"),
                   (Self.minText(d.coreMin), "CORE")]
                : []
            if d.awakeMin > 0, !tiles.isEmpty {
                tiles.append(("\(d.awakeMin)m", "AWAKE"))
            }
            stats = tiles

            // — hypnogram: the shape IS the night's segments (deriver-asserted)
            let shape = d.shape
            hypnoSegments = shape?.segments.map {
                SleepHypnoSegment(stage: $0.stage, t0: $0.t0, t1: $0.t1)
            } ?? []
            hypnogramHeadline = shape.map { SleepDetailView.depthHeadline($0) }
            hourMarks = shape.map { Self.hourMarks(startClock: $0.startClock, endClock: $0.endClock) } ?? []
            edgeStart = shape?.startClock ?? ""
            edgeEnd = shape?.endClock ?? ""
            wakeT = shape?.wake?.t
            wakeLabel = shape?.wake.map { "\($0.clock) — awake \($0.minutes)m" }
            // in-bed underlay on the night axis — only when the SOURCE wrote an
            // in-bed record (the envelope fallback would just repaint the plot)
            if night.inBedIsFromSource,
               let segs = night.segments, let lo = segs.first?.start,
               let hi = segs.map(\.end).max(),
               let bedLo = night.inBedStart, let bedHi = night.inBedEnd {
                let span = hi.timeIntervalSince(lo)
                if span > 0 {
                    let t0 = max(0, min(1, bedLo.timeIntervalSince(lo) / span))
                    let t1 = max(0, min(1, bedHi.timeIntervalSince(lo) / span))
                    inBedSpanT = t1 > t0 ? (t0, t1) : nil
                } else { inBedSpanT = nil }
            } else {
                inBedSpanT = nil
            }
            let stageBits = [
                "Deep \(Self.minText(d.deepMin))", "REM \(Self.minText(d.remMin))",
                "Core \(Self.minText(d.coreMin))",
                d.awakeMin > 0 ? "awake \(d.awakeMin)m inside the night" : nil,
            ].compactMap { $0 }
            hypnogramA11y = stageBits.joined(separator: ", ")
                + (shape.map { ". From \($0.startClock) to \($0.endClock)." } ?? ".")

            // — stage share
            let rows: [StageRow] = d.hasStageDetail
                ? [StageRow(name: "Deep", minutes: d.deepMin, color: LiviqaTheme.accentSleep),
                   StageRow(name: "REM", minutes: d.remMin, color: LiviqaTheme.accentSleep.opacity(0.62)),
                   StageRow(name: "Core", minutes: d.coreMin, color: LiviqaTheme.accentSleep.opacity(0.34))]
                : []
            stageRows = rows
            let total = max(1, rows.reduce(0) { $0 + $1.minutes })
            stageTotalMin = total
            stageRowTexts = rows.map {
                "\(Self.minText($0.minutes))  ·  \(Int((Double($0.minutes) / Double(total) * 100).rounded()))%"
            }
            if d.hasStageDetail {
                let deepRemPct = Int((Double(d.deepMin + d.remMin) / Double(total) * 100).rounded())
                stageShareHeadline = "About \(deepRemPct)% of the night in Deep and REM."
            } else {
                stageShareHeadline = nil
            }
            stageA11y = zip(rows, stageRowTexts).map { "\($0.name) \($1)" }
                .joined(separator: ", ")

            // — highlights: descriptive observation rows from the night model
            var hl: [(icon: String, text: String)] = []
            if let segs = night.segments,
               let run = Self.longestUnbrokenStretch(segs), run.minutes >= 45 {
                hl.append(("moon.stars.fill",
                           "Longest unbroken stretch \(Self.minText(run.minutes)) — ending \(SleepNight.clock(run.end))."))
            }
            if let b = d.bedtime {
                hl.append(("clock",
                           "Bedtime within half an hour of your own usual on \(b.nightsNearUsual) of \(b.nightCount) nights."))
            }
            if !night.naps.isEmpty {
                let napMin = night.naps.reduce(0) { $0 + $1.asleepMin }
                if let first = night.naps.first?.start {
                    hl.append(("zzz",
                               "A nap of \(napMin)m at \(SleepNight.clock(first)) — counted separately, never inside the night."))
                } else {
                    hl.append(("zzz",
                               "A nap of \(napMin)m — counted separately, never inside the night."))
                }
            }
            if !night.excludedSources.isEmpty {
                let chosen = MetricSourceLabel.inProse(night.source)
                let others = night.excludedSources.compactMap { MetricSourceLabel.inProse($0) }
                if let chosen, !others.isEmpty {
                    hl.append(("arrow.triangle.branch",
                               "\(others.joined(separator: ", ")) also recorded last night — the figures use \(chosen) alone, so no minute counts twice."))
                } else {
                    hl.append(("arrow.triangle.branch",
                               "A second app also recorded last night — one source's night was used alone, so no minute counts twice."))
                }
            }
            if let resp = night.respiratoryRateMean, let base = night.respiratoryRateBaseline {
                hl.append(("lungs.fill",
                           "Sleeping breathing rate \(Self.oneDecimal(resp)) breaths a minute — your own recent mean is \(Self.oneDecimal(base))."))
            }
            highlights = hl

            // — week (duration fallback figures)
            nights = d.nights
            weekMeanHours = mean
            let closeNights = d.nights.filter { abs($0.hours - mean) <= 0.5 }.count
            weekHeadline = d.nights.count >= 2
                ? "\(closeNights) of \(d.nights.count) nights within about half an hour of your usual."
                : ""

            // — week (clock-positioned columns on the fixed 22:00→14:00 axis)
            weekClock = Self.clockWeek(week: d.week, bedtime: d.bedtime)

            // — bedtime vs own usual
            if let b = d.bedtime {
                bedtimeHeadline = "Within half an hour of your own usual, \(b.nightsNearUsual) of \(b.nightCount) nights."
                bedtimeFoot = "\"Usual\" here is the average of your own bedtimes this week. There is no recommended hour on this page."
                let top = Double(max(b.thisWeekMinutes, b.prevWeekMinutes ?? 0)) * 1.08
                var rows: [MetricCompareRow] = [
                    MetricCompareRow(value: "\(b.thisWeekClock) avg", label: "THIS WEEK",
                                     frac: top > 0 ? Double(b.thisWeekMinutes) / top : 1,
                                     on: true),
                ]
                if let prev = b.prevWeekClock, let prevMin = b.prevWeekMinutes {
                    rows.append(MetricCompareRow(value: "\(prev) avg", label: "LAST WEEK",
                                                 frac: top > 0 ? Double(prevMin) / top : 1,
                                                 on: false))
                }
                bedtimeRows = rows
            } else {
                bedtimeHeadline = nil
                bedtimeRows = []
                bedtimeFoot = nil
            }

            // — vs last week
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
            } else {
                compareSentence = nil
                compareRows = []
            }

            // — month / six months (day axis; gaps stay gaps)
            monthTrend = Self.trend(d.month)
            sixMonthTrend = Self.trend(d.sixMonths)
        }

        /// "14.2" — one-decimal plain number (breathing-rate row).
        nonisolated static func oneDecimal(_ v: Double) -> String {
            String(format: "%.1f", v)
        }

        /// The W range → render fractions. The 22:00→14:00 axis is the
        /// deriver's (`SleepClockAxis`); marks every 4 clock hours.
        private static func clockWeek(week: SleepWeekRange,
                                      bedtime: SleepBedtimeWeek?) -> ClockWeekRender? {
            guard !week.columns.isEmpty, !week.days.isEmpty else { return nil }
            let cal = Calendar(identifier: .gregorian)
            let symbols = cal.veryShortWeekdaySymbols
            let colsByDay = Dictionary(uniqueKeysWithValues: week.columns.map { ($0.date, $0) })
            var anyClipped = false
            let nights: [SleepClockNight] = week.days.map { day in
                let label = symbols[(cal.component(.weekday, from: day) - 1) % symbols.count]
                let isLast = day == week.nights.last?.date
                guard let col = colsByDay[day] else {
                    return SleepClockNight(label: label, isLastNight: isLast,
                                           f0: nil, f1: nil, stripes: [])
                }
                if col.clippedTop || col.clippedBottom { anyClipped = true }
                return SleepClockNight(
                    label: label, isLastNight: isLast,
                    f0: max(0, min(1, col.bedFraction)),
                    f1: max(0, min(1, col.wakeFraction)),
                    stripes: col.bands.map { (chartStage($0.stage), $0.y0, $0.y1) })
            }
            // marks at 22 · 02 · 06 · 10 · 14 on the 16h axis
            let marks: [(Double, String)] = [(0, "22"), (0.25, "02"), (0.5, "06"),
                                             (0.75, "10"), (1, "14")]
            var band: (Double, Double)? = nil
            var bandLabel = ""
            if let b = bedtime {
                let sinceTen = Double(b.thisWeekMinutes + 18 * 60 - 22 * 60)  // min since 22:00
                let f = sinceTen / (16 * 60)
                let half = 30.0 / (16 * 60)
                if f > -half, f < 1 + half {
                    band = (max(0, f - half), min(1, f + half))
                    bandLabel = "your usual bedtime \(b.thisWeekClock)"
                }
            }
            return ClockWeekRender(
                nights: nights,
                axisMarks: marks,
                usualBand: band,
                usualLabel: bandLabel,
                foot: anyClipped
                    ? "A night reaching past the 22:00–14:00 axis is drawn cut at the edge — its figures are unaffected."
                    : nil,
                a11y: "Each column is one night placed at its own clock time, bedtime to wake. "
                    + "\(week.nightsWithData) of \(week.days.count) nights recorded."
                    + (bedtime.map { " Your usual bedtime this week is \($0.thisWeekClock)." } ?? ""))
        }

        /// A long range → render values. Nothing renders below 2 recorded
        /// nights; nil slots stay nil (gaps are data).
        private static func trend(_ r: SleepLongRange) -> TrendRender? {
            guard r.nightsWithData >= 2, let meanMin = r.meanAsleepMin,
                  !r.slots.isEmpty else { return nil }
            let mean = Double(meanMin) / 60
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_GB")
            fmt.dateFormat = "d MMM"
            return TrendRender(
                values: r.slots.map(\.value),
                usual: (mean - 0.5)...(mean + 0.5),
                usualLabel: "your usual \(Self.minText(meanMin))",
                edgeStart: fmt.string(from: r.slots.first!.date),
                edgeEnd: fmt.string(from: r.slots.last!.date),
                headline: "\(r.nightsWithData) recorded nights in the last \(r.slots.count) days — the gaps are unrecorded, not zero.",
                a11y: "\(r.nightsWithData) recorded nights over \(r.slots.count) days. "
                    + "Your own average is \(Self.minText(meanMin)) a night.")
        }
    }
}

// MARK: - Design seed (demo sessions ONLY, behind isSampleMode)
//
// The FIXTURE (which constructs HealthSamples with the provenance data field)
// lives in Liviqa/Intelligence/SleepSampleFixture.swift — view files must never
// touch that field (T-PROV-01). This shim only maps the derived detail into the
// screen model, exactly as a real session does.
extension SleepDetailView.Model {
    static var designSeed: Self {
        .init(derived: SleepSampleFixture.demoDetail, isDemoSeed: true)
    }
}
