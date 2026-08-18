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
    /// FR-SMP-01/03: true when the citizen has turned SAMPLE MODE on. It means
    /// "you asked to see a sample", never "we have no real data yet" — the
    /// second is `coldStart`, and it renders an honest empty state, never a
    /// stand-in figure. See SampleMode.swift for why those were ever one flag.
    var isSampleMode: Bool = false
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
    /// FR-CTX-04 — the set/clear sheet for the user's own context flag.
    @State private var showContextFlag = false
    /// FR-XPL-01 — the open "See why" disclosure (one sheet, every verdict here).
    @State private var seeWhy: SeeWhyExplanation? = nil
    /// Signal-card navigation. The cards used to BE NavigationLinks; they now
    /// carry two tap targets (open the pillar · see why), so the push is driven
    /// from state instead of a link wrapped round the whole card.
    @State private var pushedPillar: WellnessPillar? = nil
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

    // A7.2 delta (screen-home.jsx): the design greets in full — "Good morning,
    // Clara." — not the clipped "Morning, N".
    private var greeting: String { greeting(forHour: greetingHour) }

    private func greeting(forHour hour: Int) -> String {
        switch hour {
        case 5..<12:  return String(localized: "Good morning")
        case 12..<17: return String(localized: "Good afternoon")
        default:      return String(localized: "Good evening")
        }
    }

    /// The hour the greeting should speak from. Release: the real clock, always.
    ///
    /// DEBUG only: when `LIVIQA_EDITION` forces an edition for snapshot QA, the
    /// greeting follows the FORCED edition instead of the wall clock, so a frame
    /// captured at 22:00 with `LIVIQA_EDITION=day` doesn't open with "Good
    /// evening" above a day-edition layout. Forcing `day` at an actual daytime
    /// hour keeps the true hour (morning stays morning, afternoon stays
    /// afternoon) — only an hour that contradicts the forced edition is moved.
    private var greetingHour: Int {
        let real = Calendar.current.component(.hour, from: Date())
        #if DEBUG
        if let e = ProcessInfo.processInfo.environment["LIVIQA_EDITION"] {
            if e == "evening" { return 21 }
            if e == "day" { return (real >= 21 || real < 5) ? 9 : real }
        }
        #endif
        return real
    }

    private var greetingLine: String {
        if let n = displayName, !n.isEmpty { return "\(greeting), \(n)." }
        return "\(greeting)."
    }

    var body: some View {
        #if DEBUG
        if let p = ProcessInfo.processInfo.environment["LIVIQA_OPEN_PILLAR"],
           let pillar = WellnessPillar(rawValue: p) {
            MetricDetailView(pillar: pillar)
        } else if ProcessInfo.processInfo.environment["LIVIQA_OPEN_TRENDS"] == "1" {
            // Snapshot hook (FR-TOD-06): open the Trends surface headlessly.
            TrendsView()
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

                // A7.2 calibrating delta (ScrTodayCalibrating): the honesty chip
                // reads "Sample data" — the design's term for the marked seeds.
                LiviqaAppBar(
                    title: "Liviqa",
                    showMark: true,
                    chipLabel: SampleModePolicy.labelIsVisible(sampleModeOn: isSampleMode)
                        ? String(localized: "Sample data") : nil
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

                    // A7.2 Home anatomy (screen-home.jsx). Day edition: verdict hero +
                    // day-arc · momentum · signals grid (adaptive, FR-TOD-07 — the
                    // canvas's fixed 2×2 is superseded by CN's 2026-08-19 directive;
                    // deviation in qms/DHF.md) · quiet/attention · week · share.
                    // Evening edition (post-21:00 — "a designed ending, not an inversion"):
                    // closing note · momentum · day-score ring · month trend · signals ·
                    // quiet/attention · tomorrow hook. Cold start always keeps the honest
                    // calibrating card in the hero slot.
                    if isEveningEdition && !coldStart {
                        // FR-CTX-04: a marked day closes on the calibrating
                        // register, not on a verdict about a day the user
                        // already told us was atypical.
                        Group {
                            if let flag = contextFlag { contextHero(flag) } else { closingNote }
                        }
                        .padding(.top, 16)

                        contextEntryRow
                            .padding(.top, 12)

                        if let items = momentumItems {
                            momentumStrip(items)
                                .padding(.top, 14)
                        }

                        // How today scored — transparent, decomposed arithmetic.
                        if let score = dayScore {
                            scoreCard(score)
                                .padding(.top, 14)
                        }

                        if let trend = recoveryTrend {
                            monthTrendCard(trend)
                                .padding(.top, 14)
                        }

                        signalsGrid
                            .padding(.top, 14)

                        Group {
                            if let flag = contextFlag, !hasClinicianRoute {
                                contextQuietNote(flag)
                            } else if !nudges.isEmpty {
                                attentionCard
                            } else {
                                quietLine
                            }
                        }
                        .padding(.top, 16)

                        tomorrowHook
                            .padding(.top, 16)
                    } else {
                        Group {
                            if coldStart {
                                baselineBuildingCard
                            } else if let flag = contextFlag {
                                contextHero(flag)
                            } else {
                                heroBlock
                            }
                        }
                        .padding(.top, 16)

                        // FR-CTX-04 entry affordance — a quiet row, never a
                        // second attention card (the ONE-card rule holds).
                        if !coldStart {
                            contextEntryRow
                                .padding(.top, 12)
                        }

                        // Since last week — momentum vs the user's own baseline.
                        if let items = momentumItems {
                            momentumStrip(items)
                                .padding(.top, 14)
                        }

                        signalsGrid
                            .padding(.top, 14)

                        // ONE earned attention card — or the quiet all-clear line.
                        // Calibrating keeps the design's lock note ("…just keep
                        // wearing your devices.") instead of silence.
                        Group {
                            if coldStart {
                                calibratingQuietNote
                            } else if let flag = contextFlag, !hasClinicianRoute {
                                // Marked day: the calm stand-in replaces the
                                // attention slot — it never sits beside it.
                                contextQuietNote(flag)
                            } else if !nudges.isEmpty {
                                attentionCard
                            } else {
                                quietLine
                            }
                        }
                        .padding(.top, 16)

                        // InsightCompare (screen-home.jsx) — this month's sleep vs
                        // last, derived; renders only when the change is real.
                        if !coldStart, let cmp = appState.trends?.compare {
                            insightCompareCard(cmp)
                                .padding(.top, 16)
                        }

                        // Zoom out from today → the full week (correlation view).
                        weekCard
                            .padding(.top, 16)

                        // Sharing status — the standing "who can see your week" card.
                        shareCard
                            .padding(.top, 14)
                    }

                    // Colophon + (per the canvas) the quiet research one-liner
                    // beneath it — the invitation's designed low-key placement.
                    VStack(spacing: 12) {
                        colophon
                        if appState.researchOpportunity != nil {
                            researchFootnote
                        }
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                    .id("home-bottom")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: title dissolves into the feed
        .liviqaScrollEdge()       // every device: paper fades under the status bar
        .seeWhySheet($seeWhy, appState: appState)
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
        .sheet(isPresented: $showContextFlag) { ContextFlagSheet() }
        #endif
    }

    // MARK: — Context flag (FR-CTX-04 · Bevel absorb ③)

    /// The flag the user has put on today, if any.
    private var contextFlag: ContextFlag? { appState.activeContextFlag }

    /// A surviving route-to-clinician nudge (D9 cardiac lane). Suppression never
    /// touches that lane, so when one is present the attention card still wins
    /// over the calm context note — safety outranks calm.
    private var hasClinicianRoute: Bool { nudges.contains { $0.accent == .cardiac } }

    /// Verdict surface while a day is marked: the calibrating register instead
    /// of deviation language. Same anatomy as the day/evening hero so the page
    /// keeps its shape — kicker, serif line, rule, sentence, arc.
    private func contextHero(_ flag: ContextFlag) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: flag.kind.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(localized: "Marked · \(flag.kind.label)").uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                }
                .foregroundStyle(LiviqaTheme.accentFinance)

                Text(flag.kind.todayHeadline)
                    .font(.liviqaSerif(23)).kerning(-0.2).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(LiviqaTheme.accentFinance)
                    .frame(width: 44, height: 3)
                    .padding(.vertical, 10)
                Text(flag.kind.todayDetail)
                    .font(.lato(13.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                // FR-XPL-01: even a declared verdict shows its work — here that
                // work is "you told us", plus what marking does and doesn't do.
                SeeWhyChip { seeWhy = contextWhy(flag) }
                    .padding(.top, 12)
            }
            Spacer(minLength: 0)
            IrisDayArc(progress: dayProgress, size: 76)
        }
    }

    private func contextWhy(_ flag: ContextFlag) -> SeeWhyExplanation {
        let df = DateFormatter(); df.dateFormat = "d MMM"
        return SeeWhyExplainer.markedDay(
            verdict: flag.kind.todayHeadline,
            kindLabel: flag.kind.label,
            startedText: df.string(from: flag.startedOn),
            isOpen: flag.isOpen)
    }

    /// The set/clear affordance. Quiet by design — a row, not a card, so the
    /// page still has exactly one card that asks for attention.
    private var contextEntryRow: some View {
        Button { showContextFlag = true } label: {
            HStack(spacing: 10) {
                Image(systemName: contextFlag?.kind.systemImage
                      ?? "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.accentFinance)
                    .frame(width: 22)
                Text(contextEntryLabel)
                    .font(.lato(12.5))
                    .foregroundStyle(LiviqaTheme.ink2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Mark days as travelling, unwell or off routine"))
    }

    private var contextEntryLabel: String {
        if let flag = contextFlag {
            return String(localized: "Marked as \(flag.kind.label.lowercased()) — tap when you're back to your routine")
        }
        return String(localized: "Travelling, unwell or off routine? Mark these days.")
    }

    /// Stands in for the attention slot on a marked day — calm, honest, and
    /// explicit that nothing is being hidden.
    private func contextQuietNote(_ flag: ContextFlag) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LiviqaTheme.accentFinance)
                .padding(.top, 1)
            Text(flag.kind.quietNote)
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.accentFinance.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(LiviqaTheme.accentFinance.opacity(0.28), lineWidth: 1))
        .accessibilityElement(children: .combine)
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
                // FR-XPL-01 — the front-page verdict opens to its own arithmetic.
                SeeWhyChip { seeWhy = heroWhy(affirmHeadline) }
                    .padding(.top, 12)
            }
            Spacer(minLength: 0)
            IrisDayArc(progress: dayProgress, size: 76)
        }
    }

    /// The decomposition behind the front-page verdict — same tone decision, same
    /// thresholds (`SeeWhyExplainer` owns both), so the two cannot drift apart.
    private func heroWhy(_ verdict: String) -> SeeWhyExplanation {
        SeeWhyExplainer.todayHero(
            tone: weekTone, verdict: verdict,
            tirWeek: signals?.inRangeWeek ?? [],
            sleepWeek: signals?.sleepWeek ?? [],
            hasRealSignals: signals != nil,
            coldStart: coldStart)
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
    /// FR-XPL-01: the register AND its thresholds now live in
    /// `SeeWhyExplainer` (pure, tested), so the sentence Home prints and the
    /// arithmetic the "See why" sheet prints are chosen by one function.
    private var weekTone: TodayTone {
        guard let s = signals else { return .steady }          // seeds → original copy
        return SeeWhyExplainer.todayTone(tirIsClay: s.inRangeIsClay,
                                         tirWeek: s.inRangeWeek,
                                         sleepWeek: s.sleepWeek)
    }

    /// Second-half average vs first-half average of a real 7-day series.
    private func trendingUp(_ series: [Double], by delta: Double) -> Bool {
        SeeWhyExplainer.trendingUp(series, by: delta)
    }

    private var tirImproving: Bool {
        guard let s = signals else { return false }
        return trendingUp(s.inRangeWeek, by: SeeWhyExplainer.tirTrendPoints)
    }
    private var sleepImproving: Bool {
        guard let s = signals else { return false }
        return trendingUp(s.sleepWeek, by: SeeWhyExplainer.sleepTrendHours)
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

    /// Calibrating lock note (ScrTodayCalibrating): the quiet all-clear with the
    /// design's "just keep wearing your devices" tail — shown instead of silence
    /// while the baseline builds.
    private var calibratingQuietNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LiviqaTheme.moss)
                .padding(.top, 1)
            Text("Nothing needs your attention today. Just keep wearing your devices.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .accessibilityElement(children: .combine)
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

    /// The attention card only renders when there IS a nudge, and every nudge in
    /// the app — real session or sample mode — is authored by the engine and has
    /// passed `NudgeGuard` (FR-NDG-06). The canned strings that used to override
    /// it in "demo" mode are gone: they were hand-written causal claims
    /// ("Late dinners are costing you sleep.") that no guard had ever seen.
    private var heroHeadline: String {
        guard let n = nudges.first else { return "" }
        return n.evidence?.headline ?? n.body
    }

    // MARK: — InsightCompare (this month's sleep vs last — derived, quiet)

    /// screen-home.jsx InsightCompare: one sentence over two labelled bars.
    /// Figures come from TrendsDeriver's period comparison — the card simply
    /// doesn't render when either window is thin or the change is noise.
    private func insightCompareCard(_ cmp: TrendsPeriodCompare) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Sleep · month to month").uppercased())
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(cmp.sentence)
                .font(.liviqaSerif(17)).kerning(-0.2).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            InsightCompareBars(
                currentLabel: cmp.currentLabel, currentText: cmp.currentText,
                currentValue: cmp.currentHours,
                previousLabel: cmp.previousLabel, previousText: cmp.previousText,
                previousValue: cmp.previousHours)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
        .accessibilityElement(children: .combine)
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
        return maySeed ? [71, 74, 69, 78, 80, 76, 84] : nil
    }

    private var weekHeadline: String {
        if !isSampleMode, let s = signals, !s.inRange.isEmpty, s.inRange != "—" {
            return String(localized: "Glucose held in range \(s.inRange) of the week.")
        }
        return String(localized: "See how this week's days connect.")
    }

    // MARK: — Signal row (your value vs your own normal)

    // A7.2 SignalsGrid — verdict-first cards: domain left-rule + icon, a plain
    // verdict WORD before the number, the value big + tabular, and the 7-day line
    // over the "your usual" band. Verdicts reuse the locked two-state semantics
    // (moss = like your usual · clay = worth a look) as words instead of dots.
    //
    // FR-TOD-07 (CN directive 2026-08-19, supersedes the canvas's fixed 2×2 —
    // deviation recorded in qms/DHF.md): the grid renders the domains this
    // person actually measures — `TodaySignalsDeriver.homeCards` decides from
    // the real samples (min 2, max 6). A gym person with no CGM sees
    // Sleep · Activity · Workouts · Heart and NO glucose card; glucose keeps
    // its clinical treatment (TIR, clay flag, Zones chip) whenever present.
    /// The card list: adaptive when derived; the classic four only for the
    /// sample-seed fallback; the honest calibrating set otherwise (no glucose —
    /// it appears with the first real reading).
    private var gridCards: [HomeCard] {
        if let s = signals { return s.cards }
        if maySeed { return HomeCard.classicFour }
        return TodaySignalsDeriver.calibratingCards
    }

    private var signalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            ForEach(gridCards, id: \.domain) { card in
                signalCard(card)
            }
        }
        .navigationDestination(item: $pushedPillar) { MetricDetailView(pillar: $0) }
    }

    /// One grid slot. A card padded in by the min-2 rule (`present == false`)
    /// renders as the calibrating skeleton — it claims nothing.
    @ViewBuilder
    private func signalCard(_ card: HomeCard) -> some View {
        let calibrating = coldStart || !card.present
        switch card.domain {
        case .sleep:
            SignalCardView(rule: LiviqaTheme.accentSleep, icon: "moon.fill",
                           domain: String(localized: "Sleep"),
                           verdict: sleepVerdict, value: sleepHeadline, unit: nil,
                           spark: spark(\.sleepWeek, .sleep),
                           band: usualBand(\.sleepWeek),
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .sleep },
                           onWhy: { seeWhy = signalWhy(.sleep, verdict: sleepVerdict,
                                                       value: sleepHeadline,
                                                       series: \.sleepWeek) })
        case .glucose:
            SignalCardView(rule: LiviqaTheme.accentGlucose, icon: "drop.fill",
                           domain: String(localized: "Glucose"),
                           verdict: glucoseVerdict,
                           value: signals?.inRange ?? seedValue("61%"),
                           unit: String(localized: "in range"),
                           spark: spark(\.inRangeWeek, .glucose),
                           band: usualBand(\.inRangeWeek),
                           chip: String(localized: "Zones & TIR"),
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .glucose },
                           onWhy: { seeWhy = signalWhy(.glucose, verdict: glucoseVerdict,
                                                       value: signals?.inRange ?? seedValue("61%"),
                                                       series: \.inRangeWeek) })
        case .activity:
            SignalCardView(rule: LiviqaTheme.fjordBright, icon: "figure.walk",
                           domain: String(localized: "Activity"),
                           verdict: activityVerdict,
                           value: signals?.steps ?? "—",
                           unit: String(localized: "steps"),
                           spark: signals?.stepsWeek ?? [],
                           band: usualBand(\.stepsWeek),
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .activity },
                           onWhy: { seeWhy = SeeWhyExplainer.activityCard(
                               verdict: activityVerdict,
                               value: signals?.steps ?? "—",
                               series: signals?.stepsWeek ?? [],
                               band: usualBand(\.stepsWeek),
                               hasRealSignals: signals != nil,
                               coldStart: coldStart) })
        case .fitness:
            SignalCardView(rule: LiviqaTheme.accentRecovery, icon: "figure.outdoor.cycle",
                           domain: String(localized: "Workouts"),
                           verdict: fitnessVerdict,
                           value: signals.map { String($0.workoutsWeek) } ?? "—",
                           unit: String(localized: "this week"),
                           spark: signals?.workoutLoadWeeks ?? [],
                           band: nil,
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .fitness },
                           onWhy: { seeWhy = SeeWhyExplainer.fitnessCard(
                               verdict: fitnessVerdict,
                               sessions: signals?.workoutsWeek ?? 0,
                               loadWeeks: signals?.workoutLoadWeeks ?? [],
                               loadUsual: signals?.workoutLoadUsual,
                               hasRealSignals: signals != nil,
                               coldStart: coldStart) })
        case .recovery:
            SignalCardView(rule: LiviqaTheme.accentRecovery, icon: "waveform.path.ecg",
                           domain: String(localized: "Recovery"),
                           verdict: recoveryVerdict,
                           value: signals?.hrv ?? seedValue("48"), unit: nil,
                           spark: spark(\.hrvWeek, .recovery),
                           band: usualBand(\.hrvWeek),
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .recovery },
                           onWhy: { seeWhy = signalWhy(.recovery, verdict: recoveryVerdict,
                                                       value: (signals?.hrv ?? seedValue("48")) + " ms",
                                                       series: \.hrvWeek) })
        case .heart:
            SignalCardView(rule: LiviqaTheme.accentHeart, icon: "heart.fill",
                           domain: String(localized: "Heart"),
                           verdict: heartVerdict,
                           value: signals?.rhr ?? seedValue("58"),
                           unit: String(localized: "resting"),
                           spark: spark(\.rhrWeek, .heart),
                           band: usualBand(\.rhrWeek),
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .heart },
                           onWhy: { seeWhy = signalWhy(.heart, verdict: heartVerdict,
                                                       value: (signals?.rhr ?? seedValue("58")) + " bpm",
                                                       series: \.rhrWeek) })
        case .body:
            SignalCardView(rule: LiviqaTheme.accentBody, icon: "figure.arms.open",
                           domain: String(localized: "Body"),
                           verdict: bodyVerdict,
                           value: signals?.weightLatest ?? "—",
                           unit: "kg",
                           spark: signals?.weightSeries ?? [],
                           band: usualBand(\.weightSeries),
                           skeleton: calibrating,
                           onOpen: { pushedPillar = .body },
                           onWhy: { seeWhy = SeeWhyExplainer.bodyCard(
                               verdict: bodyVerdict,
                               value: signals?.weightLatest ?? "—",
                               series: signals?.weightSeries ?? [],
                               band: usualBand(\.weightSeries),
                               hasRealSignals: signals != nil,
                               coldStart: coldStart) })
        }
    }

    /// FR-XPL-01 — one signal card's decomposition: its number, the real days
    /// behind it, the own-usual band the sparkline already draws, and the rule
    /// that picked the verdict word.
    private func signalWhy(_ domain: SeeWhyExplainer.SignalDomain,
                           verdict: String, value: String,
                           series keyPath: KeyPath<TodaySignals, [Double]>) -> SeeWhyExplanation {
        SeeWhyExplainer.signalCard(
            domain: domain, verdict: verdict, value: value,
            series: signals?[keyPath: keyPath] ?? [],
            band: usualBand(keyPath),
            hasRealSignals: signals != nil,
            coldStart: coldStart)
    }

    /// "Your usual" band for a signal sparkline — mean ± 1σ of the user's OWN
    /// real week series (never a clinical range). nil on seeds/thin/flat data,
    /// so the band only ever appears over genuine readings.
    private func usualBand(_ keyPath: KeyPath<TodaySignals, [Double]>) -> ClosedRange<Double>? {
        guard let s = signals else { return nil }
        let series = s[keyPath: keyPath]
        guard series.count >= 4 else { return nil }
        let mean = series.reduce(0, +) / Double(series.count)
        let sd = (series.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
                  / Double(series.count)).squareRoot()
        guard sd > 0 else { return nil }
        return (mean - sd)...(mean + sd)
    }

    // Verdict words — plain, allow-listed, baseline-relative states (no clinical
    // claims; "—" while calibrating). The clay flag keeps its locked meaning.
    private var sleepVerdict: String {
        if coldStart || (signals == nil && !isSampleMode) { return "—" }
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
        return trendingUp(s.hrvWeek, by: SeeWhyExplainer.hrvTrendMs)
            ? String(localized: "On the way up") : String(localized: "Steady")
    }
    /// FR-XPL-01 honesty fix: this word used to be the constant "Calm" whatever
    /// the reading said — a verdict that cannot be explained because it was never
    /// computed. It now reads off the SAME own-usual band the card already draws
    /// under the sparkline (mean ±1σ of the user's real week — no new
    /// derivation), and falls back to "Calm" only while no band exists, matching
    /// the pre-existing behaviour for anyone without four days of readings.
    private var heartVerdict: String {
        if coldStart { return "—" }
        guard let s = signals, let band = usualBand(\.rhrWeek), let latest = s.rhrWeek.last else {
            return String(localized: "Calm")
        }
        if band.contains(latest) { return String(localized: "Calm") }
        return latest > band.upperBound
            ? String(localized: "Above your usual") : String(localized: "Below your usual")
    }

    // FR-TOD-07 — the whole-person card verdicts. Same register as the four
    // above: allow-listed words only, chosen against the person's OWN band
    // (mean ±1σ of their real recent series), never a target or population
    // figure. Guard-checked in TodayGridAvailabilityTests.
    private var activityVerdict: String {
        if coldStart { return "—" }
        guard let s = signals, let band = usualBand(\.stepsWeek), let latest = s.stepsWeek.last else {
            return String(localized: "As usual")
        }
        if band.contains(latest) { return String(localized: "As usual") }
        return latest > band.upperBound
            ? String(localized: "Above your usual") : String(localized: "Below your usual")
    }

    /// Workouts: this week's load vs the mean of the person's own prior weeks
    /// (FitnessDeriver's published arithmetic). The ±fraction is named once in
    /// `SeeWhyExplainer.loadUsualFraction`, so the word and its "See why" copy
    /// cannot disagree. No usual week yet → the in-band word, claiming nothing.
    private var fitnessVerdict: String {
        if coldStart { return "—" }
        guard let s = signals, let usual = s.workoutLoadUsual, usual > 0,
              let current = s.workoutLoadWeeks.last else {
            return String(localized: "As usual")
        }
        let f = SeeWhyExplainer.loadUsualFraction
        if current > usual * (1 + f) { return String(localized: "Above your usual") }
        if current < usual * (1 - f) { return String(localized: "Below your usual") }
        return String(localized: "As usual")
    }

    private var bodyVerdict: String {
        if coldStart { return "—" }
        guard let s = signals, let band = usualBand(\.weightSeries), let latest = s.weightSeries.last else {
            return String(localized: "Steady")
        }
        if band.contains(latest) { return String(localized: "Steady") }
        return latest > band.upperBound
            ? String(localized: "Above your usual") : String(localized: "Below your usual")
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

    /// FR-SMP-01, the whole rule in one place: a fabricated stand-in figure may
    /// render ONLY when the citizen asked for a sample. Having nothing of their
    /// own yet is not permission to invent something — that shows "—".
    ///
    /// This used to read `coldStart ? "—" : demo`, which let a session that was
    /// merely mid-derivation (nudges present, signals not yet in) print 61% in
    /// range as if someone had measured it.
    private var maySeed: Bool {
        SampleModePolicy.mayRenderSampleValues(sampleModeOn: isSampleMode,
                                               hasRealReadings: signals != nil)
    }

    private func seedValue(_ sample: String) -> String {
        maySeed ? sample : "—"
    }

    /// Sparkline source: real per-day week when connected (empty ⇒ no spark, honest),
    /// the pillar's demo week when showing seeds — never a seed on cold start.
    private func spark(_ keyPath: KeyPath<TodaySignals, [Double]>, _ pillar: WellnessPillar) -> [Double] {
        if let s = signals { return s[keyPath: keyPath] }
        return maySeed ? pillar.week : []
    }

    // MARK: — Evening edition (post-21:00 — closing note, day score, month trend)

    /// The evening edition begins at 21:00 and runs until the small hours.
    /// DEBUG env `LIVIQA_EDITION=evening|day` forces either for snapshot QA.
    private var isEveningEdition: Bool {
        #if DEBUG
        if let e = ProcessInfo.processInfo.environment["LIVIQA_EDITION"] {
            return e == "evening"
        }
        #endif
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 21 || h < 4
    }

    private var closingNote: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "Closing note").uppercased())
                    .font(.liviqaKicker(11)).tracking(1.4)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(closingHeadline)
                    .font(.liviqaSerif(23)).kerning(-0.2).lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(LiviqaTheme.clay)
                    .frame(width: 44, height: 3)
                    .opacity(0.85)
                    .padding(.vertical, 10)
                Text("Sleep well — tomorrow's edition arrives with your morning readings.")
                    .font(.lato(13.5)).lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink2)
                // The evening verdict is the same register as the morning one, so
                // it opens the same way (FR-XPL-01).
                SeeWhyChip { seeWhy = heroWhy(closingHeadline) }
                    .padding(.top, 12)
            }
            Spacer(minLength: 8)
            IrisDayArc(progress: dayProgress, size: 76)
        }
    }

    /// Allow-listed closing verdicts, derived from the same week helpers as
    /// the morning hero — never medical, never a surprise at bedtime.
    private var closingHeadline: String {
        switch weekTone {
        case .uneven:    return String(localized: "An uneven day — it happens.")
        case .improving: return String(localized: "Today added to a good week.")
        case .steady:    return String(localized: "Today held steady.")
        }
    }

    /// The evening day score: visible fractions, added up — no model, no
    /// opacity (the anti-score-opacity stance). FR-TOD-08 (CN whole-person
    /// directive): composed by `DayScoreComposer` from the domains this person
    /// ACTUALLY tracks — movement takes the slot the A7.2 design gave it, and
    /// the score stops assuming a CGM. Fixed weights, shrinking denominator,
    /// verdict thresholded on earned/possible; the composer also writes the
    /// "See why" sheet, so the ring and its arithmetic cannot drift apart.
    /// nil ⇒ seeds/absent/fewer than two domains.
    private var dayScore: DayScoreComposer.Score? {
        if coldStart { return nil }
        // No derived signals ⇒ no score. The three canned segments that used to
        // stand in here were a fabricated day (42/50 sleep, 24/30 glucose…)
        // presented as the reader's own; sample mode derives real segments from
        // the synthetic record instead, so nothing needs inventing (FR-SMP-01).
        guard let s = signals else { return nil }
        return DayScoreComposer.compose(
            sleepHours: s.sleepWeek.last,
            tirPct: s.inRangeWeek.last,
            stepsWeek: s.stepsWeek,
            hrvWeek: s.hrvWeek)
    }

    private func partColor(_ domain: DayScoreComposer.Domain) -> Color {
        switch domain {
        case .sleep:    return LiviqaTheme.accentSleep
        case .glucose:  return LiviqaTheme.accentGlucose
        case .movement: return LiviqaTheme.fjordBright
        case .recovery: return LiviqaTheme.accentRecovery
        }
    }

    private func scoreCard(_ score: DayScoreComposer.Score) -> some View {
        let segs = score.parts.map {
            ScoreSegment(name: $0.name, val: $0.points, max: $0.max, color: partColor($0.domain))
        }
        return HStack(spacing: 16) {
            ScoreRing(score: score.total, segments: segs, size: 96, outOf: score.outOf)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "How today scored").uppercased())
                    .font(.liviqaKicker(9)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(score.verdict)
                    .font(.liviqaSerif(16.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 5).padding(.bottom, 8)
                ForEach(segs) { seg in
                    HStack(spacing: 7) {
                        Circle().fill(seg.color).frame(width: 7, height: 7)
                        Text(seg.name)
                            .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink2)
                        Spacer()
                        Text("\(Int(seg.val.rounded()))/\(Int(seg.max))")
                            .font(.lato(12.5)).monospacedDigit()
                            .foregroundStyle(LiviqaTheme.ink3)
                    }
                    .padding(.top, 3)
                }
                // The legend already showed the fractions; FR-XPL-01 unifies the
                // treatment — the same chip as every other verdict, opening the
                // full arithmetic (with any shared reference NAMED out loud).
                SeeWhyChip {
                    seeWhy = DayScoreComposer.seeWhy(score, fromRealSignals: signals != nil)
                }
                .padding(.top, 9)
            }
        }
        .padding(.horizontal, 17).padding(.vertical, 16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    struct RecoveryTrend {
        let data: [Double]
        let avg: Double
        let kicker: String
        let labels: [String]
        /// One entry per calendar day of the labelled span, nil where nothing
        /// was recorded. The card's edge labels are real dates, so the line has
        /// to be placed by date — `data` alone only says how many readings
        /// exist, not which days they belong to.
        var slots: [Double?]? = nil
    }

    /// Real 30-day HRV series via TrendsDeriver (the FR-TOD-05 deriver
    /// extension, landed with Area ②) — the designed month trend for real
    /// users. Falls back to the honest 7-day series when the month is thin,
    /// and to the demo seed only in demo mode.
    private var recoveryTrend: RecoveryTrend? {
        if coldStart { return nil }
        if let month = appState.trends?.month, month.hrvDaily.count >= 8 {
            let data = month.hrvDaily
            let avg = data.reduce(0, +) / Double(data.count)
            let df = DateFormatter(); df.dateFormat = "d MMM"
            // Edge labels come from the window the slots actually span, so the
            // dates under the line are the line's own first and last columns.
            let slots = month.hrvSlots
            let labelDates = [slots.first?.date,
                              slots.count > 1 ? slots[slots.count / 2].date : nil,
                              slots.last?.date]
            let labels = labelDates.compactMap { $0.map(df.string(from:)) }
            return RecoveryTrend(data: data, avg: avg,
                                 kicker: String(localized: "Recovery · Last 30 days"),
                                 labels: labels,
                                 slots: slots.map(\.value))
        }
        if let s = signals, s.hrvWeek.count >= 5 {
            let avg = s.hrvWeek.reduce(0, +) / Double(s.hrvWeek.count)
            // No dated axis is drawn on the 7-day fallback (no edge labels), so
            // the compacted series is placed as-is.
            return RecoveryTrend(data: s.hrvWeek, avg: avg,
                                 kicker: String(localized: "Recovery · Last 7 days"), labels: [])
        }
        // Nothing derived, nothing drawn — the hardcoded 14-point "month" that
        // used to fill this slot was a month nobody lived (FR-SMP-01).
        return nil
    }

    private func monthTrendCard(_ trend: RecoveryTrend) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(trend.kicker.uppercased())
                .font(.liviqaKicker(9)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(trendingUp(trend.data, by: 2)
                 ? String(localized: "Your month, quietly on the way up.")
                 : String(localized: "Holding close to your own line."))
                .font(.liviqaSerif(16.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 5).padding(.bottom, 10)
            MonthTrendLine(data: trend.data, avg: trend.avg,
                           color: LiviqaTheme.clay, color2: LiviqaTheme.accentSleep,
                           height: 92, labels: trend.labels, slots: trend.slots)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17).padding(.top, 15).padding(.bottom, 12)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    private var tomorrowHook: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Tomorrow").uppercased())
                .font(.liviqaKicker(9)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(tomorrowLine)
                .font(.liviqaSerif(14.5)).italic().lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17).padding(.vertical, 14)
        .background(LiviqaTheme.paper2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    /// Honest hook only: a real open question from the user's own series, or
    /// the plain promise of tomorrow's edition. Never an invented experiment.
    private var tomorrowLine: String {
        if let s = signals, let d = weekDelta(s.sleepWeek), d < -0.25 {
            return String(localized: "We'll see if tonight turns the sleep dip around.")
        }
        return String(localized: "Your morning readings write tomorrow's front page.")
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
        // "Recovery up 4 vs your usual" with no readings behind it is a
        // sentence about a week that did not happen — removed (FR-SMP-01).
        guard let s = signals else { return nil }
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
        // FR-TOD-07 — the A7.2 canvas's own "Steps +12%" item, dropped only
        // because steps weren't in TodaySignals when the strip landed. The %
        // is ActivityDeriver's pctVsUsual: this week's daily mean vs the
        // person's OWN prior three weeks (nil until real history exists).
        if let pct = s.stepsPctVsUsual, abs(pct) >= 5 {
            items.append(MomentumItem(
                text: pct > 0 ? String(localized: "Steps +\(pct)%")
                              : String(localized: "Steps −\(-pct)%"),
                up: pct > 0))
        }
        // Sessions this week vs the week before — only when either week had any.
        let dw = s.workoutsWeek - s.workoutsPrevWeek
        if dw != 0, s.workoutsWeek + s.workoutsPrevWeek > 0 {
            items.append(MomentumItem(
                text: dw > 0 ? String(localized: "Workouts +\(dw)")
                             : String(localized: "Workouts −\(-dw)"),
                up: dw > 0))
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
            // FR-TOD-06: Trends is its own surface, pushed from Today (the
            // design's back-link reads "Today"). The full week keeps its own
            // doorway via the week card below.
            NavigationLink(destination: TrendsView()) {
                Text("See the trend →")
                    .font(.lato(12.5, .semibold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(LiviqaTheme.paper2.opacity(0.55))   // half-plate in BOTH modes
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

    /// The canvas's quiet research one-liner under the colophon (b-insights):
    /// "One study is inviting people like you." — a whisper, not a banner. The
    /// actionable card above remains the deliberate primary entry.
    private var researchFootnote: some View {
        Button { appState.showStudyConsent = true } label: {
            (Text("One study is inviting people like you. ")
                .foregroundStyle(LiviqaTheme.ink3)
             + Text("Read the invitation →")
                .foregroundStyle(LiviqaTheme.moss))
                .font(.lato(11.5))
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
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
    /// The user's own usual band drawn under the sparkline (A7.2 delta —
    /// BaselineSpark always supported it; the card now passes it).
    var band: ClosedRange<Double>? = nil
    var chip: String? = nil
    /// Calibrating state (ScrTodayCalibrating): quiet skeleton rows instead of
    /// values — nothing is faked, the shape just says "filling in".
    var skeleton: Bool = false
    /// Open the pillar detail. The card body is the tap target; the "See why"
    /// row below it is a SIBLING button, never nested inside this one — nesting
    /// a control inside a NavigationLink label is exactly how the second target
    /// stops being reachable.
    var onOpen: () -> Void = {}
    /// FR-XPL-01 — open this card's decomposition.
    var onWhy: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) { cardBody }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens the \(domain) detail"))
            // No verdict on a calibrating card ⇒ nothing to explain, so the
            // affordance stays off rather than opening an empty panel.
            if !skeleton {
                SeeWhyChip(action: onWhy)
                    .padding(.top, 9)
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

    private var cardBody: some View {
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
            if skeleton {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LiviqaTheme.line2)
                    .frame(width: 64, height: 20)
                    .padding(.top, 9)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LiviqaTheme.line2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)
                    .padding(.top, 9)
                    .accessibilityHidden(true)
            } else {
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
                BaselineSpark(data: spark, band: band, color: rule, height: 26)
                    .padding(.top, 7)
            }
            }
            if let chip, !skeleton {
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
        .contentShape(Rectangle())
    }
}
