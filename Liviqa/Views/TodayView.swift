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
    /// Switch to the Privacy tab (share flows + consent ledger live there).
    var onOpenPrivacy: (() -> Void)? = nil

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
        ScrollViewReader { proxy in
            scrollBody
                #if DEBUG
                // Snapshot hook: screenshot the below-the-fold Home content headlessly.
                .task {
                    if ProcessInfo.processInfo.environment["LIVIQA_SCROLL_TO"] == "bottom" {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        proxy.scrollTo("home-bottom", anchor: .bottom)
                    }
                }
                #endif
        }
    }

    private var scrollBody: some View {
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

                    // Degraded persistence is never silent: the on-disk store failed
                    // to open (schema migration or disk fault) and this session runs
                    // in memory — nothing recorded now survives a relaunch. Honest
                    // system-fault banner (rust = boundary/system, not health amber).
                    if appState.storeDegraded {
                        storeDegradedBanner
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

                    // Once anything is imported, a visible, discoverable entry to VIEW
                    // and screenshot the record (labs / diagnoses / medicine).
                    if hasImportedRecord {
                        healthRecordCard
                            .padding(.top, 10)
                    }

                    // A7.2 Home anatomy (screen-home.jsx): verdict hero + day-arc ·
                    // momentum · signals 2×2 · quiet/attention · week · share · colophon.
                    // Cold start keeps the honest calibrating card in the hero slot.
                    Group {
                        if coldStart {
                            baselineBuildingCard
                        } else {
                            heroBlock
                        }
                    }
                    .padding(.top, 16)

                    // Since last week — momentum vs the user's own baseline.
                    if let items = momentumItems {
                        momentumStrip(items)
                            .padding(.top, 14)
                    }

                    signalsGrid
                        .padding(.top, 14)

                    // ONE earned attention card — or the quiet all-clear line.
                    Group {
                        if coldStart {
                            EmptyView()
                        } else if !nudges.isEmpty {
                            attentionCard
                        } else {
                            quietLine
                        }
                    }
                    .padding(.top, 16)

                    // Zoom out from today → the full week (correlation view).
                    weekCard
                        .padding(.top, 16)

                    // Sharing status — the standing "who can see your week" card.
                    shareCard
                        .padding(.top, 14)

                    colophon
                        .padding(.top, 22)
                        .padding(.bottom, 28)
                        .id("home-bottom")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: title dissolves into the feed
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSundhedImport) {
            NavigationStack {
                SundhedWebSessionView(
                    ingest: appState.supabase as? SundhedIngesting,
                    citizenId: appState.profile?.alias ?? appState.session?.userId.uuidString
                )
            }
        }
        #endif
    }

    // MARK: — Degraded-store banner (in-memory fallback engaged)

    private var storeDegradedBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.lato(15)).foregroundStyle(LiviqaTheme.rust)
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage couldn't open — new data isn't being saved")
                    .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                Text("Anything already on this device is safe. Quit and reopen Liviqa to try again — if this keeps happening, tell us from Settings.")
                    .font(.lato(12.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.rust2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.rust.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: — Your health record (view/screenshot imported labs, diagnoses, medicine)

    private var hasImportedRecord: Bool {
        !appState.healthObservations.isEmpty
            || !appState.healthConditions.isEmpty
            || !appState.healthMedications.isEmpty
    }

    private var recordSummaryLine: String {
        let l = appState.healthObservations.count
        let d = appState.healthConditions.count
        let m = appState.healthMedications.count
        var parts: [String] = []
        if l > 0 { parts.append("\(l) lab result\(l == 1 ? "" : "s")") }
        if d > 0 { parts.append("\(d) diagnos\(d == 1 ? "is" : "es")") }
        if m > 0 { parts.append("\(m) medicine\(m == 1 ? "" : "s")") }
        return parts.isEmpty
            ? "Labs, diagnoses & medicine — kept on this device"
            : parts.joined(separator: " · ") + " — tap to view or share"
    }

    private var healthRecordCard: some View {
        Button { appState.showHealthRecord = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 17)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(LiviqaTheme.ink2)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your health record")
                        .font(.lato(14.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text(recordSummaryLine)
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
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                    Text("Sign in with MitID — pulled live to your device")
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

    // MARK: — Verdict hero (A7.2: on-canvas sentence + fjord underline + iris day-arc)

    private var heroBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "Today").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(affirmHeadline)
                    .font(.liviqaSerif(23)).kerning(-0.2).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(LiviqaTheme.moss)
                    .frame(width: 44, height: 3)
                    .padding(.vertical, 10)
                Text(affirmSub)
                    .font(.lato(13.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            IrisDayArc(progress: dayProgress, size: 76)
        }
    }

    /// Fraction of today elapsed — drives the day-arc fill.
    private var dayProgress: Double {
        let start = Calendar.current.startOfDay(for: Date())
        return min(1, Date().timeIntervalSince(start) / 86_400)
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
            HStack(spacing: 8) {
                IrisDayArc(progress: 0.12, size: 26)
                Text(String(localized: "Getting to know you").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.moss)
            }
            Text("Learning your normal.")
                .font(.liviqaSerif(20)).kerning(-0.2).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 10)
            // Quiet progress hint — indeterminate by design (no fake day counter).
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LiviqaTheme.line2)
                    Capsule().fill(LiviqaTheme.fjordBright)
                        .frame(width: geo.size.width * 0.18)
                }
            }
            .frame(height: 5)
            .padding(.top, 12)
            Text("Your readings are coming in. Until Liviqa has enough of your own days to compare against, nothing is shown as an insight — your first ones typically appear after about 3 days.")
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
    }

    // MARK: — Earned attention card / quiet all-clear (A7.2: at most ONE per day)

    private var attentionCard: some View {
        Button {
            if let n = nudges.first { onOpen(n) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    if visualNudge, let acc = nudges.first?.accent {
                        Image(systemName: acc.icon).font(.system(size: 11)).foregroundStyle(acc.accentColor)
                    }
                    Text(String(localized: "Worth a look").uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.clayText)
                }

                Text(heroHeadline)
                    .font(.liviqaSerif(17)).kerning(-0.2)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 9)

                // Inline sparkline of the matching domain's REAL weekly series
                // (from todaySignals) — the evidence made visible, not faked.
                if visualNudge, let spark = heroSparkline, let acc = nudges.first?.accent {
                    MiniSparkline(values: spark, tint: acc.accentColor, height: 26)
                        .padding(.top, 10)
                }

                HStack(spacing: 5) {
                    Text("See why").font(.lato(13.5, .bold))
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(LiviqaTheme.moss)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(LiviqaTheme.clay2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.clay, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var quietLine: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(LiviqaTheme.moss, lineWidth: 1.6).frame(width: 19, height: 19)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            Text("Nothing needs your attention today.")
                .font(.liviqaSerif(14, .regular))
                .italic()
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
    // A7.2 SignalsGrid — 2×2 verdict-first cards: domain left-rule + icon, a plain
    // verdict WORD before the number, the value big + tabular, and the 7-day line
    // over the "your usual" band. Verdicts reuse the locked two-state semantics
    // (moss = like your usual · clay = worth a look) as words instead of dots.
    private var signalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            NavigationLink(value: WellnessPillar.sleep) {
                SignalCardView(rule: LiviqaTheme.accentSleep, icon: "moon.fill",
                               domain: String(localized: "Sleep"),
                               verdict: sleepVerdict, value: sleepHeadline, unit: nil,
                               spark: spark(\.sleepWeek, .sleep))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.glucose) {
                SignalCardView(rule: LiviqaTheme.accentGlucose, icon: "drop.fill",
                               domain: String(localized: "Glucose"),
                               verdict: glucoseVerdict,
                               value: signals?.inRange ?? seedValue("61%"),
                               unit: String(localized: "in range"),
                               spark: spark(\.inRangeWeek, .glucose),
                               chip: String(localized: "Zones & TIR"))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.recovery) {
                SignalCardView(rule: LiviqaTheme.accentRecovery, icon: "waveform.path.ecg",
                               domain: String(localized: "Recovery"),
                               verdict: recoveryVerdict,
                               value: signals?.hrv ?? seedValue("48"), unit: nil,
                               spark: spark(\.hrvWeek, .recovery))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.heart) {
                SignalCardView(rule: LiviqaTheme.accentHeart, icon: "heart.fill",
                               domain: String(localized: "Heart"),
                               verdict: heartVerdict,
                               value: signals?.rhr ?? seedValue("58"),
                               unit: String(localized: "resting"),
                               spark: spark(\.rhrWeek, .heart))
            }.buttonStyle(.plain)
        }
        .navigationDestination(for: WellnessPillar.self) { MetricDetailView(pillar: $0) }
    }

    // Verdict words — plain, allow-listed, baseline-relative states (no clinical
    // claims; "—" while calibrating). The clay flag keeps its locked meaning.
    private var sleepVerdict: String {
        if coldStart || (signals == nil && !isDemoData) { return "—" }
        return sleepImproving ? String(localized: "A little longer") : String(localized: "As usual")
    }
    private var glucoseVerdict: String {
        if coldStart { return "—" }
        return (signals?.inRangeIsClay ?? false)
            ? String(localized: "Worth a look") : String(localized: "Steady")
    }
    private var recoveryVerdict: String {
        if coldStart { return "—" }
        guard let s = signals else { return String(localized: "Steady") }
        return trendingUp(s.hrvWeek, by: 2) ? String(localized: "On the way up")
                                            : String(localized: "Steady")
    }
    private var heartVerdict: String {
        coldStart ? "—" : String(localized: "Calm")
    }

    /// Sleep headline for Home — derived from the SAME source the pillar detail uses
    /// (real last-night sleep from HealthKit, `appState.sleepSummary`) so the front
    /// page can't disagree with the detail (the "front page doesn't match the actual
    /// data" report). Falls back to the signals value, then the honest seed.
    private var sleepHeadline: String {
        if let s = appState.sleepSummary {
            return "\(s.asleepMinutes / 60)h \(String(format: "%02d", s.asleepMinutes % 60))"
        }
        return signals?.sleep ?? seedValue("6h 52")
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

    // MARK: — Momentum strip (Since last week — vs the user's OWN baseline)

    struct MomentumItem: Identifiable {
        let id = UUID()
        let text: String
        let up: Bool?   // true ↑ · nil — flat/none
    }

    /// Honest derivation: today vs the mean of the week series. nil (no strip) on
    /// cold start or when nothing meaningful moved; seeds only in demo mode.
    private var momentumItems: [MomentumItem]? {
        if coldStart { return nil }
        guard let s = signals else {
            return isDemoData
                ? [MomentumItem(text: String(localized: "Recovery up 4 vs your usual"), up: true),
                   MomentumItem(text: String(localized: "Sleep unchanged"), up: nil)]
                : nil
        }
        var items: [MomentumItem] = []
        if let d = weekDelta(s.hrvWeek), abs(d) >= 2 {
            items.append(MomentumItem(
                text: d > 0 ? String(localized: "Recovery up \(Int(d.rounded())) vs your usual")
                            : String(localized: "Recovery down \(Int((-d).rounded())) vs your usual"),
                up: d > 0))
        }
        if let d = weekDelta(s.sleepWeek) {
            if abs(d) < 0.25 {
                items.append(MomentumItem(text: String(localized: "Sleep unchanged"), up: nil))
            } else {
                let mins = Int((abs(d) * 60).rounded())
                items.append(MomentumItem(
                    text: d > 0 ? String(localized: "Sleep +\(mins) min") : String(localized: "Sleep −\(mins) min"),
                    up: d > 0))
            }
        }
        if let d = weekDelta(s.inRangeWeek), abs(d) >= 3 {
            items.append(MomentumItem(
                text: d > 0 ? String(localized: "In range +\(Int(d.rounded()))")
                            : String(localized: "In range −\(Int((-d).rounded()))"),
                up: d > 0))
        }
        return items.isEmpty ? nil : items
    }

    /// Latest value minus the mean of the preceding days (nil when too sparse).
    private func weekDelta(_ series: [Double]) -> Double? {
        guard series.count >= 4, let last = series.last else { return nil }
        let prior = series.dropLast()
        return last - prior.reduce(0, +) / Double(prior.count)
    }

    private func momentumStrip(_ items: [MomentumItem]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(String(localized: "Since last week").uppercased())
                .font(.liviqaKicker(9)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            // Items keep natural width and wrap onto new rows — never truncated.
            FlowLayout(spacing: 14, rowSpacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 4) {
                        if let up = item.up {
                            Image(systemName: up ? "arrow.up" : "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(LiviqaTheme.moss)
                        } else {
                            Text("—").font(.lato(11)).foregroundStyle(LiviqaTheme.ink3)
                        }
                        Text(item.text)
                            .font(.lato(12.5, .medium))
                            .foregroundStyle(LiviqaTheme.ink2)
                    }
                    .fixedSize()
                }
            }
            NavigationLink(destination: WeekInContextView()) {
                Text("See the trend →")
                    .font(.lato(12.5, .semibold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: — Share card (the standing "who can see your week" affordance)

    private var activeGrants: [WalletGrant] { appState.grants.filter(\.isActive) }

    private var shareHeadline: String {
        if let clinical = activeGrants.first(where: { $0.recipientType == .clinical }) {
            // "Diabetes Nurse · University Hospital" → "Diabetes Nurse"
            let name = clinical.recipientName.components(separatedBy: " · ").first ?? clinical.recipientName
            return String(localized: "\(name) can see your week.")
        }
        return activeGrants.isEmpty
            ? String(localized: "Ready when your doctor is.")
            : String(localized: "Your week is ready to share.")
    }

    private var shareMeta: String {
        let n = activeGrants.count
        return n == 0
            ? String(localized: "No shares yet · nothing has left this device")
            : String(localized: "\(n) active share\(n == 1 ? "" : "s") · summaries only · 0 raw exports — ever")
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(shareHeadline)
                .font(.liviqaSerif(17)).kerning(-0.2).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
            Text(shareMeta)
                .font(.lato(12)).monospacedDigit()
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 5)
            HStack(spacing: 8) {
                Button { onOpenPrivacy?() } label: {
                    Text("Share with your doctor")
                        .font(.lato(13.5, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(LiviqaTheme.moss)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Button { onOpenPrivacy?() } label: {
                    Text("View receipts")
                        .font(.lato(13.5, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
    }

    // MARK: — Colophon (the daily privacy line — honest to what actually happened)

    private var colophon: some View {
        VStack(spacing: 3) {
            Text(appState.researchContributed
                 ? String(localized: "Printed on your device — you chose what to share.")
                 : String(localized: "Printed on your device — nothing left it today."))
            Text("Governed by the Data for Good Foundation.")
        }
        .font(.lato(11))
        .foregroundStyle(LiviqaTheme.ink3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - A7.2 signal card (verdict word first, number after, baseline sparkline)

private struct SignalCardView: View {
    let rule: Color
    let icon: String
    let domain: String
    let verdict: String
    let value: String
    let unit: String?
    var spark: [Double] = []
    var chip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(rule)
                Text(domain)
                    .font(.lato(11.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(verdict)
                .font(.liviqaSerif(15)).kerning(-0.1)
                .foregroundStyle(LiviqaTheme.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.top, 6)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.liviqaMono(19))
                    .foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.lato(10.5, .semibold))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(.top, 4)
            if spark.count > 1 {
                BaselineSpark(data: spark, color: rule, height: 26)
                    .padding(.top, 7)
            }
            if let chip {
                HStack(spacing: 3) {
                    Text(chip)
                    Text("→")
                }
                .font(.lato(10.5, .semibold))
                .foregroundStyle(LiviqaTheme.moss)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(LiviqaTheme.moss2))
                .padding(.top, 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.top, 12).padding(.bottom, 12)
        .padding(.leading, 15).padding(.trailing, 11)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(rule)
                .frame(width: 3)
                .padding(.vertical, 12)
        }
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 4)
    }
}
