// TodayView.swift — Home (Design System v2 · C-hybrid) · 2026-06-09
// Recreated from the locked design prototype (liviqa-design-system · Home C):
// AppBar → date kicker → greeting → ONE "we noticed something" insight hero
// (clay-bordered) → a four-chip signal row vs the user's OWN normal → the
// "Not averages. Yours." line. Home leads with a single insight by design;
// the full nudge feed belongs in Insights (5-tab IA, pending).
//
// NOTE: hero copy + signal values are presentation seeds for now (as the prior
// hero was) — wiring them to live nudges/HealthSamples is the next step.
import SwiftUI

struct TodayView: View {
    let nudges: [Nudge]
    var displayName: String?
    /// FR-ARCH-05: true when the feed is built from synthetic demo data.
    var isDemoData: Bool = false
    /// Live Home signal values (real HealthKit). nil ⇒ show the demo seeds.
    var signals: TodaySignals? = nil
    /// T1 cold-start honesty (Release): nothing real to show yet — render the
    /// honest "baseline building" state instead of demo placeholder values.
    var coldStart: Bool = false
    var onOpen: (Nudge) -> Void
    var onCalibrate: ((ProfileSheet.Section?) -> Void)? = nil
    /// Real device that tried HealthKit but has no readings → show the connect hint.
    var showConnectHint: Bool = false
    /// Switch to the Settings tab (where Apple Health is connected).
    var onOpenSettings: (() -> Void)? = nil

    @State private var connectHintDismissed = false
    @State private var showSundhedImport = false
    /// PR-100 promotion #3: domain icon on the nudge hero (sparkline half deferred —
    /// needs a numeric series on Nudge). On by default; toggle in Settings.
    @AppStorage("visualNudge") private var visualNudge = true
    // UC-RSCH — a matched study invitation surfaces here on Home.
    @Environment(AppState.self) private var appState

    // "Thu · 22 May"
    private var dateKicker: String {
        let df = DateFormatter(); df.dateFormat = "EEE · d MMM"
        return df.string(from: Date())
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return String(localized: "Morning")
        case 12..<17: return String(localized: "Afternoon")
        case 17..<21: return String(localized: "Evening")
        default:      return String(localized: "Late")
        }
    }

    private var greetingLine: String {
        if let n = displayName, !n.isEmpty { return "\(greeting), \(n)" }
        return greeting
    }

    var body: some View {
        #if DEBUG
        if let p = ProcessInfo.processInfo.environment["LIVIQA_OPEN_PILLAR"],
           let pillar = WellnessPillar(rawValue: p) {
            MetricDetailView(pillar: pillar)
        } else { mainBody }
        #else
        mainBody
        #endif
    }

    private var mainBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                LiviqaAppBar(
                    title: "Liviqa",
                    showMark: true,
                    chipLabel: isDemoData ? "Demo data" : nil
                )

                VStack(alignment: .leading, spacing: 0) {

                    Text(dateKicker.uppercased())
                        .font(.liviqaKicker(11)).tracking(1.4)
                        .foregroundStyle(LiviqaTheme.ink3)

                    Text(greetingLine)
                        .font(.liviqaSerif(26)).kerning(-0.2)
                        .foregroundStyle(LiviqaTheme.ink)
                        .padding(.top, 4)

                    // Real device, no Health data yet → gentle, dismissible cue.
                    if showConnectHint, !connectHintDismissed {
                        connectHealthHint
                            .padding(.top, 14)
                    }

                    // UC-RSCH-1 — matched research opportunity (s09).
                    if let study = appState.researchOpportunity {
                        ResearchOpportunityCard(
                            study: study,
                            onReview: { appState.showStudyConsent = true },
                            onLater:  { appState.researchOpportunity = nil }
                        )
                        .padding(.top, 14)
                    }

                    // Bring in Sundhed.dk records (Path B import) — visible entry.
                    if Config.sundhedConnectEnabled {
                        sundhedConnectCard
                            .padding(.top, 14)
                    }

                    // Calm, affirming lead (not an alert) — the everyday day-good
                    // state. On a genuinely empty cold start (Release, no Health
                    // readings yet) the honest baseline card replaces it.
                    Group {
                        if coldStart {
                            baselineBuildingCard
                        } else {
                            calmHero
                        }
                    }
                    .padding(.top, 14)

                    Text(String(localized: "Your signals · vs your normal").uppercased())
                        .font(.liviqaKicker(9)).tracking(1)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.top, 18)
                        .padding(.bottom, 9)

                    signalRow

                    // Deviations are demoted below the calm state (not the hero).
                    if !nudges.isEmpty {
                        Text(String(localized: "Worth a look").uppercased())
                            .font(.liviqaKicker(9)).tracking(1)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.top, 20)
                            .padding(.bottom, 9)
                        insightHero
                    }

                    // Zoom out from today → the full week (correlation view).
                    weekCard
                        .padding(.top, 20)

                    Text(String(localized: "Not averages. Yours.").uppercased())
                        .font(.liviqaKicker(11)).tracking(0.6)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: title dissolves into the feed
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSundhedImport) {
            NavigationStack { SundhedImportView() }
        }
        #endif
    }

    // MARK: — Connect Sundhed.dk (prominent, health-records import)

    private var sundhedConnectCard: some View {
        Button { showSundhedImport = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 17)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(LiviqaTheme.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bring in your Sundhed.dk records")
                        .font(.lato(14.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("Labs, medicine & diagnoses — read on your device")
                        .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: — Connect-Apple-Health hint (real device, no data yet)

    private var connectHealthHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.lato(15)).foregroundStyle(LiviqaTheme.moss)
            VStack(alignment: .leading, spacing: 2) {
                // Cold start shows the honest empty state, not sample data —
                // the hint header must not claim otherwise (T1).
                Text(coldStart ? "Waiting for your Health data" : "Showing sample data")
                    .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                Button { onOpenSettings?() } label: {
                    // The silent failure mode is granting access with every category
                    // toggled OFF — say it, or the user is stuck with an empty app.
                    Text("Connect Apple Health in Settings — and make sure the data categories are turned ON →")
                        .font(.lato(12.5)).foregroundStyle(LiviqaTheme.moss)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Button { connectHintDismissed = true } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LiviqaTheme.ink4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
    }

    // MARK: — Calm affirming lead (the all-clear day must feel good, not empty)

    private var calmHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(LiviqaTheme.moss).frame(width: 7, height: 7)
                Text(String(localized: "Today").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.moss)
            }
            Text(affirmHeadline)
                .font(.liviqaSerif(20)).kerning(-0.2).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 10)
            Text(affirmSub)
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
    }

    // Calm affirmation derived from the user's OWN week (simple descriptive
    // heuristics on the real 7-day series — never a verdict, never medical).
    // No signals yet (demo seeds) keeps the original steady copy; the genuine
    // cold start is covered by the honest baseline card above.
    private enum WeekTone { case steady, improving, uneven }

    private var weekTone: WeekTone {
        guard let s = signals else { return .steady }          // seeds → original copy
        if s.inRangeIsClay { return .uneven }                  // the one flagged deviation
        if tirImproving || sleepImproving { return .improving }
        return .steady
    }

    /// Second-half average vs first-half average of a real 7-day series.
    private func trendingUp(_ series: [Double], by delta: Double) -> Bool {
        guard series.count >= 4 else { return false }
        let half = series.count / 2
        let early = series.prefix(half), late = series.suffix(series.count - half)
        return late.reduce(0, +) / Double(late.count)
             - early.reduce(0, +) / Double(early.count) >= delta
    }

    private var tirImproving: Bool {
        guard let s = signals else { return false }
        return trendingUp(s.inRangeWeek, by: 5)                // ≥5 points more in range
    }
    private var sleepImproving: Bool {
        guard let s = signals else { return false }
        return trendingUp(s.sleepWeek, by: 0.4)                // ≥ ~25 min longer nights
    }

    private var affirmHeadline: String {
        switch weekTone {
        case .steady:    return String(localized: "You're having a steady week.")
        case .improving: return String(localized: "This week is trending gently up.")
        case .uneven:    return String(localized: "A more uneven week — that happens.")
        }
    }
    private var affirmSub: String {
        switch weekTone {
        case .steady:
            return String(localized: "Sleep, glucose and recovery are all tracking close to your own normal.")
        case .improving:
            return tirImproving
                ? String(localized: "Recent days show a little more time in range than earlier in the week.")
                : String(localized: "Recent nights have been a touch longer than earlier in the week.")
        case .uneven:
            return String(localized: "Glucose spent a bit less time in range this week — the day-to-day picture is just below.")
        }
    }

    // MARK: — Honest cold start (no readings yet — nothing is faked)

    private var baselineBuildingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(LiviqaTheme.moss).frame(width: 7, height: 7)
                Text(String(localized: "Building your baseline").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.moss)
            }
            Text("No insights yet — and that's honest.")
                .font(.liviqaSerif(20)).kerning(-0.2).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 10)
            Text("Liviqa reads your history from Apple Health and learns what's normal for you. Your first insights typically appear after about 3 days of readings.")
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
    }

    // MARK: — Deviation insight (demoted under the calm state)

    private var insightHero: some View {
        Button {
            if let n = nudges.first { onOpen(n) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    if visualNudge, let acc = nudges.first?.accent {
                        Image(systemName: acc.icon).font(.system(size: 11)).foregroundStyle(acc.accentColor)
                    } else {
                        Circle().fill(LiviqaTheme.clay).frame(width: 7, height: 7)
                    }
                    Text(String(localized: "In your data").uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.clayText)
                }

                Text(heroHeadline)
                    .font(.liviqaSerif(19)).kerning(-0.2)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 10)

                Text(heroSub)
                    .font(.lato(13)).lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(LiviqaTheme.clayText)
                    .padding(.top, 7)

                // PR-100 #3: inline sparkline of the matching domain's REAL weekly
                // series (from todaySignals) — the evidence made visible, not faked.
                if visualNudge, let spark = heroSparkline, let acc = nudges.first?.accent {
                    MiniSparkline(values: spark, tint: acc.accentColor, height: 28)
                        .padding(.top, 11)
                }

                HStack(spacing: 6) {
                    Text("See the evidence").font(.lato(13, .bold))
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.clay3, lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    // Live when real data is connected (drive from the user's own top nudge);
    // the polished demo seeds otherwise.
    /// The matching domain's REAL weekly series for the hero sparkline (nil ⇒ none).
    private var heroSparkline: [Double]? {
        guard let acc = nudges.first?.accent, let s = signals else { return nil }
        let series: [Double]
        switch acc {
        case .glucose: series = s.inRangeWeek
        case .sleep:   series = s.sleepWeek
        case .cardiac: series = s.hrvWeek
        default:       series = []
        }
        return series.count > 1 ? series : nil
    }

    private var heroHeadline: String {
        if !isDemoData, let n = nudges.first { return n.evidence?.headline ?? n.body }
        return "Late dinners are costing you sleep."
    }
    private var heroSub: String {
        if !isDemoData, let n = nudges.first { return n.evidence?.lever ?? String(localized: "Tap to see the evidence.") }
        return "Calmest when dinner's before 20:30."
    }

    // MARK: — This week (zoom-out teaser → the full week / correlation view)

    // Restores the "This week" card that was dropped from Home in the PR-51 reframe
    // (FB 86exz218r). Calm, real-data-aware, and a doorway to WeekInContextView —
    // not a second alert. Honest values when Health is connected; calm seeds otherwise.
    private var weekCard: some View {
        NavigationLink(destination: WeekInContextView()) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11)).foregroundStyle(LiviqaTheme.moss)
                    Text(String(localized: "This week").uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.moss)
                    Spacer(minLength: 8)
                    Text(String(localized: "View full week"))
                        .font(.lato(12, .bold)).foregroundStyle(LiviqaTheme.ink3)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(LiviqaTheme.ink3)
                }
                Text(weekHeadline)
                    .font(.liviqaSerif(17)).kerning(-0.3).lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 9)
                if let spark = weekSparkline {
                    MiniSparkline(values: spark, tint: LiviqaTheme.moss, height: 30)
                        .padding(.top, 11)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    /// REAL weekly in-range series (oldest→today) when connected; a calm seed otherwise
    /// (matches the seed used by WeekInContextView so the teaser and full view agree).
    /// Cold start: no seed sparkline — nothing real to draw yet (T1).
    private var weekSparkline: [Double]? {
        if let s = signals, s.inRangeWeek.count > 1 { return s.inRangeWeek }
        return coldStart ? nil : [71, 74, 69, 78, 80, 76, 84]
    }

    private var weekHeadline: String {
        if !isDemoData, let s = signals, !s.inRange.isEmpty, s.inRange != "—" {
            return String(localized: "Glucose held in range \(s.inRange) of the week.")
        }
        return String(localized: "See how this week's days connect.")
    }

    // MARK: — Signal row (your value vs your own normal)

    // Wellness pillars (Sleep · Glucose · Recovery · Heart) — topic by icon+label,
    // state by the single moss/clay dot (locked two-state). "Recovery" carries the
    // stress axis (HRV) descriptively — no stress score/verdict.
    private var signalRow: some View {
        HStack(spacing: 8) {
            NavigationLink(value: WellnessPillar.sleep) {
                signalChip(String(localized: "Sleep"), "moon.fill", signals?.sleep ?? seedValue("6h52"), clay: false, spark: spark(\.sleepWeek, .sleep))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.glucose) {
                signalChip(String(localized: "Glucose"), "drop.fill", signals?.inRange ?? seedValue("61%"), clay: signals?.inRangeIsClay ?? !coldStart, spark: spark(\.inRangeWeek, .glucose))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.recovery) {
                signalChip(String(localized: "Recovery"), "waveform.path.ecg", signals?.hrv ?? seedValue("48"), clay: false, spark: spark(\.hrvWeek, .recovery))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.heart) {
                signalChip(String(localized: "Heart"), "heart.fill", signals?.rhr ?? seedValue("58"), clay: false, spark: spark(\.rhrWeek, .heart))
            }.buttonStyle(.plain)
        }
        .navigationDestination(for: WellnessPillar.self) { MetricDetailView(pillar: $0) }
    }

    /// Demo seed values render only outside the honest cold start; a genuinely
    /// empty Release start shows "—" until real readings arrive (T1).
    private func seedValue(_ demo: String) -> String {
        coldStart ? "—" : demo
    }

    /// Sparkline source: real per-day week when connected (empty ⇒ no spark, honest),
    /// the pillar's demo week when showing seeds — never a seed on cold start.
    private func spark(_ keyPath: KeyPath<TodaySignals, [Double]>, _ pillar: WellnessPillar) -> [Double] {
        if let s = signals { return s[keyPath: keyPath] }
        return coldStart ? [] : pillar.week
    }

    private func signalChip(_ label: String, _ icon: String, _ value: String, clay: Bool,
                            spark: [Double] = []) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(clay ? LiviqaTheme.clay : LiviqaTheme.moss)
                Text(label.uppercased())
                    .font(.liviqaKicker(8)).tracking(0.4)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 5) {
                Circle().fill(clay ? LiviqaTheme.clay : LiviqaTheme.moss).frame(width: 6, height: 6)
                Text(value)
                    .font(.lato(15, .heavy))
                    .foregroundStyle(clay ? LiviqaTheme.clayText : LiviqaTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            // 7-day micro-trend (only when there's real/seed data to show).
            if spark.count > 1 {
                MiniSparkline(values: spark, tint: clay ? LiviqaTheme.clay : LiviqaTheme.moss, height: 18)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The four chips share a fixed row; cap their growth so labels/values stay
        // on one line at large text sizes (content elsewhere scales freely).
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }
}
