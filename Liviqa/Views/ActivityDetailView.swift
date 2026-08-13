// ActivityDetailView.swift — A7.2 Area ④: the Activity metric detail, built to
// the DActivity editorial anatomy (design_handoff_liviqa_a7: d-insights.jsx
// DActivity + charts2.jsx DayBars).
//
// PERSONAL-BASELINE ONLY: the dashed line is the user's OWN prior-three-weeks
// mean — no step goals, no population targets, ever (FR-NDG-06 rail). All
// sentences are fixed descriptive templates.
//
// DATA HONESTY: steps and active energy are ingested daily; renders from
// ActivityDeriver output when it exists. The "% vs your usual" hero stat only
// appears when the usual comes from actual PRIOR weeks — a week can't be
// compared against itself. Design seeds render only in demo mode.
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// FR-XPL-01 — the hero verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: ActivityWeekDetail? { appState.activityDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    MetricHero(tint: LiviqaTheme.accentRecovery,
                               kicker: "Activity · this week",
                               verdict: model.verdict,
                               stat: model.stat,
                               unit: model.statUnit,
                               sub: model.sub)
                    SeeWhyHeroRow { seeWhy = activityWhy(model) }
                    if !model.stats.isEmpty { MetricStatRow(items: model.stats) }
                    if model.steps.count >= 2 { stepsCard(model) }
                    if model.kcal.count >= 2 { energyCard(model) }
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

    /// The hero verdict decomposed — and the honest note that the "usual line"
    /// only exists once there are PRIOR weeks to average.
    private func activityWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.activityHero(
            verdict: m.verdict,
            daysAboveUsual: detail?.daysAboveUsual ?? 0,
            usualSteps: m.usualSteps ?? 0,
            usualFromHistory: detail?.usualFromHistory ?? (detail == nil),
            pctVsUsual: detail?.pctVsUsual,
            weekStepsTotal: detail?.weekStepsTotal ?? Int(m.steps.reduce(0, +)),
            dayCount: m.steps.count,
            isSeed: detail == nil)
    }

    // MARK: - Screen model

    struct Model {
        var verdict: String
        var stat: String?
        var statUnit: String?
        var sub: String
        var stats: [(String, String)]
        var steps: [Double]
        var stepsLabels: [String]
        var usualSteps: Double?
        var stepsHeadline: String
        var kcal: [Double]
        var kcalLabels: [String]
        var usualKcal: Double?
        var kcalHeadline: String
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        return appState.isDemoData ? .designSeed : nil
    }

    // MARK: - Cards

    private func stepsCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Steps · this week", headline: m.stepsHeadline) {
            UsualDayBars(values: m.steps,
                         labels: m.stepsLabels,
                         usual: m.usualSteps,
                         color: LiviqaTheme.accentRecovery,
                         unit: "steps",
                         fmt: { v in
                             v >= 1000 ? String(format: "%.1fk", v / 1000)
                                       : String(Int(v.rounded()))
                         })
        }
    }

    private func energyCard(_ m: Model) -> some View {
        MetricDCard(kicker: "Active energy", headline: m.kcalHeadline) {
            UsualDayBars(values: m.kcal,
                         labels: m.kcalLabels,
                         usual: m.usualKcal,
                         color: LiviqaTheme.accentRecovery,
                         unit: "kcal")
        }
    }

    // MARK: - Honest empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk").font(.system(size: 12))
                    .foregroundStyle(LiviqaTheme.accentRecovery)
                Text("ACTIVITY")
                    .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text("No activity recorded yet.")
                .font(.liviqaSerif(21)).kerning(-0.2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 9)
            Text("When your phone or watch shares steps to Apple Health, this page fills with your own week — day by day, against your own usual line. No goals here, only your data.")
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

extension ActivityDetailView.Model {

    /// Derived figures → fixed descriptive templates (no generated language).
    init(derived d: ActivityWeekDetail) {
        let grouped = Self.thousands

        // Verdict: descriptive count of above-usual days (own line only).
        let verdict: String
        if d.usualFromHistory {
            switch d.daysAboveUsual {
            case 0: verdict = "A quieter week than your usual."
            case 1: verdict = "One day above your usual line this week."
            default: verdict = "\(d.daysAboveUsual) days above your usual line this week."
            }
        } else {
            verdict = "Your week on foot, day by day."
        }

        // Hero stat: % vs own usual — only with real prior-week history.
        //
        // The direction is said ONCE. It used to be in the sign AND in the words,
        // which read as "−2 % fewer steps than your usual" — a double negative
        // that literally claims the opposite of the data (sweep 2026-08-13). The
        // number now carries the size, the unit line carries the direction.
        var stat: String? = nil
        var statUnit: String? = nil
        if let pct = d.pctVsUsual {
            stat = "\(abs(pct))"
            if pct > 0 { statUnit = "% more steps than your usual" }
            else if pct < 0 { statUnit = "% fewer steps than your usual" }
            else { statUnit = "% — the same as your usual" }
        }

        var sub = ""
        if let name = d.longestDayName, let steps = d.longestDaySteps {
            sub = "\(name) was the longest at \(grouped(steps)) steps."
        }

        var stats: [(String, String)] = [(grouped(d.weekStepsTotal), "STEPS THIS WEEK")]
        if let kcal = d.weekKcalTotal { stats.append((grouped(kcal), "KCAL BURNED")) }
        if d.workoutsLogged > 0 { stats.append(("\(d.workoutsLogged)", "WORKOUTS LOGGED")) }

        let stepsHeadline: String
        if d.usualFromHistory {
            stepsHeadline = d.daysAboveUsual == 1
                ? "One day above your usual line."
                : "\(d.daysAboveUsual) days above your usual line."
        } else {
            stepsHeadline = "The dashed line is this week's own average — your usual appears once a few weeks of history build up."
        }

        self.init(
            verdict: verdict,
            stat: stat,
            statUnit: statUnit,
            sub: sub,
            stats: stats,
            steps: d.stepsWeek,
            stepsLabels: d.stepsLabels,
            usualSteps: d.usualSteps,
            stepsHeadline: stepsHeadline,
            kcal: d.kcalWeek,
            kcalLabels: d.kcalLabels,
            usualKcal: d.usualKcal,
            kcalHeadline: "Your burn, against your own usual.")
    }

    /// The design package's demo story (d-insights.jsx DActivity), verbatim —
    /// except the hero stat, which drops the package's leading "+". The package
    /// only ever drew the ABOVE-usual case, where "+12 % more" merely reads
    /// redundantly; the below-usual case it never drew came out as "−2 % fewer".
    /// One rule for both directions: the number is the size, the words are the
    /// direction.
    static var designSeed: Self {
        .init(
            verdict: "You were on your feet on six days out of seven.",
            stat: "12",
            statUnit: "% more steps than your usual",
            sub: "Walking to work, errands, an evening loop — Sunday was the longest at 12,600 steps.",
            stats: [("58,400", "STEPS THIS WEEK"), ("3,790", "KCAL BURNED"), ("4", "WORKOUTS LOGGED")],
            steps: [7400, 8100, 5600, 9200, 8800, 11400, 12600],
            stepsLabels: ["M", "T", "W", "T", "F", "S", "S"],
            usualSteps: 8300,
            stepsHeadline: "Four days above your usual line.",
            kcal: [420, 510, 300, 560, 540, 700, 760],
            kcalLabels: ["M", "T", "W", "T", "F", "S", "S"],
            usualKcal: 480,
            kcalHeadline: "Your burn tracked your steps — no crash days.")
    }

    private static func thousands(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
