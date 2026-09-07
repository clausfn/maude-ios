// FitnessDetailView.swift — A7.2 Area ④: the Fitness & exercise screen (FR-FIT-01),
// built to the DFitness editorial anatomy (design_handoff_maude_a7: d-insights.jsx
// DFitness + ZoneBar + charts2.jsx DayBars/LongTrend).
//
// NO TARGETS EVER (designated line, printed verbatim in the load card's foot):
// "Load points add up how long and how hard you moved. Only your own
// week-to-week change matters — there is no target."
//
// DATA HONESTY (checked against ingestion): workouts (start/end/type/dur/kcal/km),
// daily VO₂max AND the beats inside each recent workout interval are ingested
// (T-FIT-01 closed 2026-08-13) — so avg-HR and the zone card now render from the
// citizen's own recordings, and are still honestly absent when a session carries
// no heart rate. The zone scale is the citizen's OWN highest recorded rate, named
// in the card's foot: no age formula, no population scale, no target.
// Hero verdicts are fixed descriptive templates (FR-NDG-06 rail — the package's
// advice-adjacent "your legs are asking for an easy day" is demo-seed-only and
// guard-checked; real templates describe, never advise).
import SwiftUI

struct FitnessDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the hero verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: FitnessDetail? { appState.fitnessDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    MetricHero(tint: MaudeTheme.accentRecovery,
                               kicker: "Training · this week",
                               verdict: model.verdict,
                               stat: model.stat,
                               unit: "training-load points this week",
                               sub: model.sub)
                    SeeWhyHeroRow { seeWhy = fitnessWhy(model) }
                    if !model.stats.isEmpty { MetricStatRow(items: model.stats) }
                    if model.loadWeeks.compactMap(\.1).count >= 2 { loadCard(model) }
                    if !model.workouts.isEmpty { workoutsCard(model) }
                    if !model.zones.isEmpty { zonesCard(model) }
                    if model.vo2Series.count >= 2 { vo2Card(model) }
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

    /// The hero verdict decomposed — this week's load against the user's OWN
    /// previous weeks. There is no target here, and the disclosure repeats it.
    private func fitnessWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.fitnessHero(
            verdict: m.verdict,
            weekCount: detail?.weekCount ?? m.workouts.count,
            loadPoints: Int(m.stat) ?? 0,
            loadUsual: m.loadUsual,
            weeksCompared: m.loadWeeks.compactMap(\.1).count,
            isSeed: detail == nil)
    }

    // MARK: - Screen model

    struct Model {
        var verdict: String
        var stat: String
        var sub: String
        var stats: [(String, String)]
        var loadWeeks: [(String, Double?)]
        var loadUsual: Double?
        var loadHeadline: String
        var workouts: [FitnessDetail.WorkoutRow]
        var workoutsHeadline: String
        var zonesKicker: String
        var zonesHeadline: String
        var zonesFoot: String?
        var zones: [ZoneShareItem]
        var vo2Series: [Double]
        var vo2Band: ClosedRange<Double>?
        var vo2Headline: String
        var vo2Annotation: (i: Int, label: String)?
        var vo2XLabels: [String]
        var vo2Foot: String?
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        return appState.isSampleMode ? .designSeed : nil
    }

    // MARK: - Cards

    private func loadCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Training load · 4 weeks", headline: m.loadHeadline,
                    foot: "Load points add up how long and how hard you moved. Only your own week-to-week change matters — there is no target.") {
            UsualDayBars(values: m.loadWeeks.map(\.1),
                         labels: m.loadWeeks.map(\.0),
                         usual: m.loadUsual,
                         color: MaudeTheme.accentRecovery,
                         unit: "load points",
                         height: 110)
        }
    }

    private func workoutsCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Your workouts", headline: m.workoutsHeadline) {
            VStack(spacing: 0) {
                ForEach(Array(m.workouts.enumerated()), id: \.offset) { i, w in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(MaudeTheme.accentRecovery)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: Self.icon(for: w.type))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(w.title)
                                .font(.lato(14, .semibold)).foregroundStyle(MaudeTheme.ink)
                            Text(w.meta)
                                .font(.maudeMono(11.5)).foregroundStyle(MaudeTheme.ink3)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(w.load)")
                                .font(.lato(13, .bold)).monospacedDigit()
                                .foregroundStyle(MaudeTheme.ink)
                            Text("load")
                                .font(.lato(10)).foregroundStyle(MaudeTheme.ink3)
                        }
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) {
                        if i > 0 { Divider().background(MaudeTheme.line2) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func zonesCard(_ m: Model) -> some View {
        MetricDCard(kicker: m.zonesKicker, headline: m.zonesHeadline, foot: m.zonesFoot) {
            ZoneBarView(zones: m.zones)
        }
    }

    private func vo2Card(_ m: Model) -> some View {
        MetricDCard(kicker: "Fitness · VO₂max", headline: m.vo2Headline, foot: m.vo2Foot) {
            LongTrendChart(data: m.vo2Series,
                           corridor: m.vo2Band,
                           unit: "mL/kg·min",
                           color: MaudeTheme.accentRecovery,
                           xLabels: m.vo2XLabels,
                           annotation: m.vo2Annotation,
                           height: 138)
        }
    }

    // MARK: - Honest empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "figure.outdoor.cycle").font(.system(size: 12))
                    .foregroundStyle(MaudeTheme.accentRecovery)
                Text("FITNESS & EXERCISE")
                    .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                    .foregroundStyle(MaudeTheme.ink3)
            }
            Text("No workouts recorded yet.")
                .font(.maudeSerif(21)).kerning(-0.2)
                .foregroundStyle(MaudeTheme.ink)
                .padding(.top, 9)
            Text("When workouts land in Apple Health, this page fills with your own training — load week by week, every session, and your fitness over the long run. There is no target here, only your own change.")
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    static func icon(for type: String) -> String {
        switch type {
        case "Cycling": "figure.outdoor.cycle"
        case "Running": "figure.run"
        case "Walking": "figure.walk"
        case "Swimming": "figure.pool.swim"
        case "Strength": "dumbbell.fill"
        case "HIIT": "flame.fill"
        case "Yoga": "figure.mind.and.body"
        default: "figure.mixed.cardio"
        }
    }
}

// MARK: - Model building

extension FitnessDetailView.Model {

    /// Derived figures → fixed descriptive templates (descriptive, never advice).
    init(derived d: FitnessDetail) {
        let noun: String = {
            switch d.dominantType {
            case "Cycling": return d.weekCount == 1 ? "ride" : "rides"
            case "Running": return d.weekCount == 1 ? "run" : "runs"
            default: return d.weekCount == 1 ? "workout" : "workouts"
            }
        }()

        let verdict: String
        if d.weekCount == 0 {
            verdict = "A quiet training week so far."
        } else if let usual = d.loadUsual, usual > 0 {
            let ratio = Double(d.weekLoadPoints) / usual
            if ratio >= 1.15 { verdict = "\(d.weekCount) \(noun) in — your biggest block this month." }
            else if ratio <= 0.85 { verdict = "\(d.weekCount) \(noun) in — a lighter week than your usual." }
            else { verdict = "\(d.weekCount) \(noun) in — right around your usual load." }
        } else {
            verdict = "\(d.weekCount) \(noun) logged this week."
        }

        var subParts: [String] = []
        if let km = d.weekDistanceKm { subParts.append(String(format: "%.0f km", km)) }
        if d.weekMovingMin > 0 { subParts.append("\(FitnessDeriver.durText(d.weekMovingMin)) moving") }
        if let hr = d.weekAvgHR { subParts.append("avg \(hr) bpm") }

        var stats: [(String, String)] = []
        if let km = d.weekDistanceKm {
            stats.append((String(format: "%.0f km", km), "DISTANCE"))
        }
        if d.weekMovingMin > 0 {
            stats.append((FitnessDeriver.durText(d.weekMovingMin), "TIME MOVING"))
        }
        stats.append(("\(d.weekCount)", noun == "rides" || noun == "ride" ? "RIDES LOGGED" : "WORKOUTS"))

        let loadHeadline: String
        if let usual = d.loadUsual, Double(d.weekLoadPoints) > usual * 1.15 {
            loadHeadline = "This week is your biggest block of the four."
        } else if let usual = d.loadUsual, Double(d.weekLoadPoints) < usual * 0.85 {
            loadHeadline = "A lighter week than the three before it."
        } else {
            loadHeadline = "Week by week, against your own usual."
        }

        let workoutsHeadline = d.weekCount > 1
            ? "\(d.weekCount) sessions this week, newest first."
            : "This week's session."

        var vo2Annotation: (i: Int, label: String)? = nil
        if d.vo2IsNewHigh, let latest = d.vo2Latest, !d.vo2Series.isEmpty {
            vo2Annotation = (d.vo2Series.count - 1,
                             String(format: "%.1f — highest in this window", latest))
        }
        // NOTE (FR-NDG-06): "2.1 mL" would trip the guard's dose-quantity rule
        // ("ml" is a dose unit) — so the sentence carries the bare figure and
        // the chart's axis label carries the mL/kg·min unit.
        let vo2Headline: String
        if let first = d.vo2Series.first, let last = d.vo2Series.last, d.vo2Series.count >= 5 {
            let delta = last - first
            if delta >= 0.5 { vo2Headline = String(format: "VO₂max up %.1f across this window.", delta) }
            else if delta <= -0.5 { vo2Headline = String(format: "VO₂max down %.1f across this window.", -delta) }
            else { vo2Headline = "VO₂max holding steady across this window." }
        } else {
            vo2Headline = "Your fitness, reading by reading."
        }

        self.init(
            verdict: verdict,
            stat: "\(d.weekLoadPoints)",
            sub: subParts.joined(separator: " · "),
            stats: Array(stats.prefix(3)),
            loadWeeks: d.loadWeeks.map { ($0.label, $0.points) },
            loadUsual: d.loadUsual,
            loadHeadline: loadHeadline,
            workouts: d.workouts,
            workoutsHeadline: workoutsHeadline,
            zonesKicker: d.zoneWorkoutTitle ?? "Heart-rate zones",
            zonesHeadline: "Where the time went, zone by zone.",
            // The scale is the citizen's own recorded maximum — said out loud so
            // it can never be read as an age formula or a population zone chart.
            zonesFoot: d.zoneOwnMaxHR.map {
                "Zones are shares of \($0) bpm — the highest your own workouts recorded in these weeks. Not a population scale, and not a target."
            } ?? "Zones are shares of the highest heart rate your own workouts recorded. Not a population scale, and not a target.",
            zones: Self.zoneItems(d.zones),
            vo2Series: d.vo2Series,
            vo2Band: d.vo2Band,
            vo2Headline: vo2Headline,
            vo2Annotation: vo2Annotation,
            vo2XLabels: d.vo2XLabels,
            vo2Foot: nil)
    }

    static func zoneItems(_ zones: [FitnessDetail.ZoneShare]) -> [ZoneShareItem] {
        let colors: [String: Color] = [
            "Z1 · easy": Color(hex: 0xA8DCF0),
            "Z2 · endurance": MaudeTheme.accentRecovery,
            "Z3 · tempo": MaudeTheme.amber,
            "Z4 · threshold": MaudeTheme.accentHeart,
        ]
        return zones.map {
            ZoneShareItem(name: $0.name,
                          minText: FitnessDeriver.durText($0.minutes),
                          frac: $0.minutes,
                          color: colors[$0.name] ?? MaudeTheme.accentRecovery)
        }
    }

    /// The design package's demo story (d-insights.jsx DFitness), verbatim.
    /// Rendered ONLY when no derivation exists AND the session is demo-tagged.
    static var designSeed: Self {
        .init(
            verdict: "Three rides in — your legs are asking for an easy day.",
            stat: "312",
            sub: "128 km · 5h 40m moving · avg 142 bpm",
            stats: [("128 km", "DISTANCE RIDDEN"), ("5h 40m", "TIME MOVING"), ("3", "RIDES LOGGED")],
            loadWeeks: [("W1", 210), ("W2", 260), ("W3", 240), ("now", 312)],
            loadUsual: 255,
            loadHeadline: "This week is your biggest block — recovery earns its place next.",
            workouts: [
                .init(title: "Sunday long ride", meta: "62 km · 2h 18m · avg 138 bpm",
                      type: "Cycling", load: 142),
                .init(title: "Thursday intervals", meta: "34 km · 1h 22m · avg 156 bpm",
                      type: "Cycling", load: 108),
                .init(title: "Tuesday recovery spin", meta: "32 km · 1h 00m · avg 118 bpm",
                      type: "Cycling", load: 62),
            ],
            workoutsHeadline: "Steady base miles, one hard interval day.",
            zonesKicker: "Sunday ride · heart-rate zones",
            zonesHeadline: "Mostly endurance — you held Zone 2 for two hours.",
            zonesFoot: "Zones are shares of 168 bpm — the highest your own workouts recorded in these weeks. Not a population scale, and not a target.",
            zones: zoneItems([
                .init(name: "Z1 · easy", minutes: 18),
                .init(name: "Z2 · endurance", minutes: 118),
                .init(name: "Z3 · tempo", minutes: 14),
                .init(name: "Z4 · threshold", minutes: 6),
            ]),
            vo2Series: [33.8, 34.0, 33.9, 34.3, 34.6, 34.5, 34.9, 35.2, 35.4, 35.6, 35.9],
            vo2Band: 33.5...35,
            // Package copy adapted: "up 2.1 mL/kg·min" trips the FR-NDG-06 dose
            // rule ("ml") — the chart's axis carries the unit instead.
            vo2Headline: "VO₂max up 2.1 since January — your longest climb yet.",
            vo2Annotation: (10, "35.9 — new high"),
            vo2XLabels: ["Jan", "Apr", "Jul"],
            vo2Foot: "A slow, durable gain — the kind that sticks.")
    }
}
