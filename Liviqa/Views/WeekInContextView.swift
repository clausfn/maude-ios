// WeekInContextView.swift — 7-day correlation grid · v01 2026-05-22
import SwiftUI

// MARK: - WeekInContextView

struct WeekInContextView: View {

    @Environment(AppState.self) private var appState
    /// PR-100 promotion #2 — graded deviation ramp instead of the 2-state moss/clay
    /// fill. SIGNED OFF by CN, now live by default (still a flag for instant revert).
    @AppStorage("gradedHeatmap") private var gradedHeatmap = true
    /// PR-100 — the 3 cross-source correlation cards (HbA1c·glucose, money·sleep,
    /// alcohol·recovery). SIMULATED pitch data (D5) → default OFF so real users never
    /// see fabricated data; Settings toggle turns it on for the pitch/demo.
    @AppStorage("crossSourceCards") private var crossSourceCards = false
    @State private var showShare = false
    /// Interactive grid selection: (dayIndex, metricIndex).
    @State private var selected: SelectedCell? = nil

    // MARK: - CALENDAR row (FR-CTX-CAL-01) — a real signal, read on this device
    //
    // The sixth row was an honest coming-soon placeholder. It now carries the
    // citizen's own calendar DENSITY: how full each day was, never what was in
    // it. Titles, people, places and notes have no representation anywhere in
    // this path — see `Liviqa/Context/CalendarLoad.swift`.
    //
    // Deliberately NOT wired into `clusterDay`, `hardDayCount`, the week
    // verdict or the pattern note: those sentences name a day that stood out
    // ACROSS SIGNALS, and letting a full diary help elect the week's hard day
    // would be the app implying a busy day moved a reading. It does not.

    /// Density days for the signed-in account, loaded from `CalendarLoadStore`.
    /// Empty until the citizen opts in — never seeded.
    @State private var calendarHistory: [CalendarDayLoad] = []
    /// Genuinely connected: the citizen opted in AND iOS granted read access.
    /// Read at appear from the store and EventKit — never a literal.
    @State private var calendarConnected = false

    private var calendarState: CalendarRowState {
        CorrelationDeriver.calendarRowState(connected: calendarConnected, history: calendarHistory)
    }

    /// One level per display column. `.noData` whenever the day was not read,
    /// the calendar is empty, or there isn't enough history for a usual yet —
    /// a zero is never drawn as a fact about the person.
    private var calendarLevels: [CorrelationLevel] {
        CorrelationDeriver
            .calendarCells(history: calendarHistory, over: weekDates, connected: calendarConnected)
            .map { CorrelationLevel(rawValue: $0.rawValue) ?? .noData }
    }

    /// The level for any cell. The four HealthKit rows come from the derived
    /// grid; CALENDAR is laid over column 5 from its own consented source.
    private func level(day dayIndex: Int, metric rowIndex: Int) -> CorrelationLevel {
        if rowIndex == CorrelationDeriver.calendarIndex {
            return dayIndex < calendarLevels.count ? calendarLevels[dayIndex] : .noData
        }
        guard dayIndex < week.days.count,
              rowIndex < week.days[dayIndex].values.count else { return .noData }
        return week.days[dayIndex].values[rowIndex]
    }

    /// Re-read the consented calendar numbers. Refuses to collect anything when
    /// the citizen has not opted in or iOS has not granted access — the refresh
    /// itself can never start collection (`CalendarLoadIngestor.refresh`).
    private func loadCalendarSignal() async {
        let account = appState.journalAccountID
        let connected = CalendarLoadStore.isOptedIn(forAccount: account)
            && CalendarLoadIngestor.accessState() == .fullAccess
        if connected {
            await Task.detached(priority: .utility) {
                _ = CalendarLoadIngestor.refresh(accountID: account)
            }.value
        }
        calendarConnected = connected
        calendarHistory = CalendarLoadStore.load(forAccount: account)?.days ?? []
    }

    /// Correlation heatmap — real on-device grid once Health is connected
    /// (AppState derives it in refreshFromHealth), the demo grid otherwise.
    private var week: CorrelationWeek { appState.correlationWeek }

    // A7.2 delta (DWeek is a 6-row grid): WEATHER — permanently noData with no
    // source on the roadmap-visible horizon — is hidden rather than rendered as
    // an eternal empty row. SPENDING is still an honest coming-soon row the
    // design keeps. CALENDAR is no longer a placeholder: it carries the real
    // consented density signal (FR-CTX-CAL-01), laid over column 5 above.
    // The deriver still emits all 7 columns; display trims the last.
    private let metricLabels = [
        "GLUCOSE", "SLEEP", "HRV", "EXERCISE",
        "SPENDING", "CALENDAR"
    ]

    // Real derived series only — no presentation seeds. A fresh user must never
    // see a fabricated trend presented as their own; the cards fall back to
    // honest empty states instead (launch-audit PR-102 line).
    private var sig: TodaySignals? { appState.todaySignals }
    private var tirValues: [Double] { sig?.inRangeWeek ?? [] }
    private var hrvValues: [Double] { sig?.hrvWeek ?? [] }
    private var hasRealTIR: Bool { tirValues.count >= 2 }
    private var hasRealHRV: Bool { hrvValues.count >= 2 }

    // MARK: - The week's day axis (one column per day, labelled from its date)

    /// The 7 calendar days the grid shows, ascending. `CorrelationDay.dateOffset`
    /// gives each column a real date, so this is the same axis the heatmap uses.
    private var weekDates: [Date] {
        week.days.map(\.dayDate).sorted()
    }

    private var dayLetters: [String] {
        weekDates.map { $0.formatted(.dateTime.weekday(.narrow)) }
    }

    /// Place a week series on that axis. A series holds one value per day WITH
    /// data, so its length is not a day count — before this, 4 values were drawn
    /// against 7 day letters and every value read under the wrong day. `nil`
    /// means the series can't be placed (values only, and short), and the caller
    /// drops the day labels rather than guessing.
    private func weekSlots(_ series: TodaySignals.WeekSeries) -> [DaySlot]? {
        guard let sig, !weekDates.isEmpty else { return nil }
        return sig.slots(for: series, over: weekDates)
    }
    private var tirHeadline: String { sig?.inRange ?? "—" }
    private var hrvHeadline: String { (sig?.hrv).map { $0 + " ms" } ?? "—" }

    struct SelectedCell: Equatable { let day: Int; let metric: Int }

    /// Two-state heatmap fill (Design v2): moss = in your range, clay = worth
    /// noticing. Not a saturated ramp — the patient surface has exactly two
    /// meanings, and a column that lights up clay IS a cluster (pre-attentive).
    private func fill(_ level: CorrelationLevel) -> Color {
        if gradedHeatmap {
            // Graded magnitude ramp — cool→warm, capped at deep amber (never red).
            switch level {
            case .noData:  return LiviqaTheme.gridEmpty
            case .low:     return LiviqaTheme.moss2      // just like your usual
            case .medium:  return LiviqaTheme.devMed     // a little off
            case .high:    return LiviqaTheme.devHigh    // clearly off your usual
            case .outlier: return LiviqaTheme.devOutlier // worth noticing (+ ring)
            }
        }
        switch level {
        case .noData:  return LiviqaTheme.gridEmpty
        case .low:     return LiviqaTheme.moss2     // in range
        case .medium:  return LiviqaTheme.moss3     // in range (firmer)
        case .high:    return LiviqaTheme.clay2     // mild
        case .outlier: return LiviqaTheme.clay      // worth noticing
        }
    }

    /// FR-CTX-04 fill for a day the user marked: one flat slate tint whatever
    /// the level, so magnitude can't leak back in through colour. "No data"
    /// still reads as empty — marking a day never invents a reading for it.
    private func neutralFill(_ level: CorrelationLevel) -> Color {
        level == .noData ? LiviqaTheme.gridEmpty : LiviqaTheme.accentFinance.opacity(0.16)
    }

    // MARK: - Context flags (FR-CTX-04) — marked days read NEUTRAL

    /// Column indices the user has marked (travelling / unwell / off-routine).
    /// `CorrelationDay.dateOffset` gives each column a real date, so this
    /// mapping is exact — no day is guessed.
    private var markedDays: Set<Int> {
        let windows = appState.contextWindows
        guard !windows.isEmpty else { return [] }
        return Set(week.days.enumerated().compactMap { i, day in
            ContextFlagDeriver.isMarked(day.dayDate, in: windows) ? i : nil
        })
    }

    /// The flag kind covering a column, for the readout wording.
    private func markedKind(_ dayIndex: Int) -> ContextFlagKind? {
        guard dayIndex < week.days.count else { return nil }
        return ContextFlagDeriver
            .window(covering: week.days[dayIndex].dayDate, in: appState.contextWindows)?.kind
    }

    /// The cluster column — the day with the most "worth noticing" signals.
    /// A lit column is the whole point of the heatmap; we ring it and name it.
    /// Marked days are excluded: the user already told us their life explains
    /// that day, so it must not be crowned the week's hard day.
    private var clusterDay: Int? {
        let marked = markedDays
        var best: (idx: Int, score: Int)? = nil
        for (i, day) in week.days.enumerated() where !marked.contains(i) {
            let score = day.values.reduce(0) { $0 + ($1 == .outlier ? 2 : $1 == .high ? 1 : 0) }
            if score > 0, best == nil || score > best!.score { best = (i, score) }
        }
        return best?.idx
    }

    var body: some View {
        ScrollViewReader { proxy in
            weekScroll
                #if DEBUG
                // Snapshot hook (same family as Home): screenshot below the fold.
                .task {
                    if ProcessInfo.processInfo.environment["LIVIQA_SCROLL_TO"] == "bottom" {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        proxy.scrollTo("week-bottom", anchor: .bottom)
                    }
                }
                #endif
        }
    }

    private var weekScroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // 1. App bar (tab name — the week verdict hero below carries "Your week")
                LiviqaAppBar(title: "Insights", showMark: false)

                VStack(alignment: .leading, spacing: 0) {

                    // 1b. Week verdict hero (d-insights.jsx DWeek) — the week's ONE
                    // sentence, derived from the same grid the card below shows.
                    if !week.days.isEmpty {
                        weekHero
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                            .padding(.bottom, 14)
                    }

                    // 2a. Weekly time-in-range trend (gradient area + draw-in)
                    tirTrendCard
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    // "Replay your day" — the editorial scrub-your-day detail
                    // (Area ② rebuild). No longer gated behind the liquidGlass
                    // flag: the screen is editorial anatomy now, not a glass
                    // exploration.
                    NavigationLink {
                        DayTimelineView()
                    } label: { dayScrubEntry }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // 2b. Recovery & stress (HRV) — descriptive, no stress score/verdict
                    recoveryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // 2. Section header
                    LiviqaSectionHeader(label: "7 days in context")
                        .padding(.horizontal, 20)

                    // 3. Correlation grid card (honest empty card until the
                    // on-device deriver has a real week to show)
                    if week.days.isEmpty {
                        emptyTrendState("Your week is still filling in",
                                        detail: "The 7-day grid builds from your own data as it arrives.")
                            .background(LiviqaTheme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
                            .padding(.horizontal, 16)
                    } else {
                        correlationGridCard
                            .padding(.horizontal, 16)
                    }

                    // 4. Pattern callout — only when a real pattern was derived
                    if !week.patternNote.isEmpty {
                        patternCard
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    // 5. MDR/AI Act note
                    regulatoryNoteCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .id("week-bottom")

                    // 6. Section header — weekly metrics
                    LiviqaSectionHeader(label: "This week")
                        .padding(.horizontal, 20)

                    // 7. Three metric cards
                    weeklyMetricsRow
                        .padding(.horizontal, 16)

                    // 7b. YOUR DATA, IN DEPTH — first-class entries for the
                    // Activity / Fitness / Body / Vitals detail screens (CN
                    // directive 2026-08-19: "Why don't I see activities, steps,
                    // exercise?"). These screens existed with real ingestion but
                    // their only entry was buried in the Passport; the defect was
                    // exclusivity, so the Passport keeps its rows and the
                    // Insights root gains these. Recorded as an A7.2-canvas
                    // deviation in qms/DHF.md (2026-08-19).
                    LiviqaSectionHeader(label: "Your data, in depth")
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    VStack(spacing: 0) {
                        depthRow(pillar: .activity)
                        Divider().background(LiviqaTheme.line2).padding(.leading, 44)
                        depthRow(pillar: .fitness)
                        Divider().background(LiviqaTheme.line2).padding(.leading, 44)
                        depthRow(pillar: .body)
                        Divider().background(LiviqaTheme.line2).padding(.leading, 44)
                        depthRow(pillar: .vitals)
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
                    .padding(.horizontal, 16)

                    // 8. Cross-source patterns (flag-gated; pitch data → default off)
                    if crossSourceCards {
                        LiviqaSectionHeader(label: "Cross-source patterns")
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        CrossSourcePatterns()
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .task { await loadCalendarSignal() }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: chrome dissolves into the trend feed
        .liviqaScrollEdge()       // every device: paper fades under the status bar
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .sheet(isPresented: $showShare) {
            // The real multi-step share flow (same presentation as Settings).
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
    }

    // MARK: - Week verdict hero (A7.2 DWeek)

    /// Days with at least one clearly-off or worth-noticing signal. Marked days
    /// don't count — a day the user flagged is not "a hard day" to explain.
    private var hardDayCount: Int {
        let marked = markedDays
        return week.days.enumerated()
            .filter { i, d in !marked.contains(i) && d.values.contains { $0 == .outlier || $0 == .high } }
            .count
    }

    /// Honest verdict grammar: "everything else held" is only claimed when
    /// exactly ONE day carried the deviations the grid shows.
    private var weekVerdict: String {
        if let c = clusterDay, c < week.days.count {
            let day = week.days[c].localizedDayName
            return hardDayCount == 1
                ? String(localized: "\(day) was the hard day — everything else held.")
                : String(localized: "\(day) stood out most this week.")
        }
        // "Steady, day after day" would overclaim across days the user told us
        // were atypical — say what is actually true of the rest of the week.
        return markedDays.isEmpty
            ? String(localized: "A steady week, day after day.")
            : String(localized: "Steady around the days you marked.")
    }

    private var weekHeroSub: String {
        let marked = markedDays.count
        if marked > 0 {
            let days = marked == 1
                ? String(localized: "One day you marked is")
                : String(localized: "\(marked) days you marked are")
            return String(localized: "\(days) drawn plain below — still recorded, just not read as a drift from your usual.")
        }
        return clusterDay != nil
            ? String(localized: "One day shows up across several of your signals — the grid below shows where.")
            : String(localized: "Nothing stood out across your signals this week.")
    }

    private var weekHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Your week").uppercased())
                .font(.liviqaKicker(11)).tracking(1.4)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(weekVerdict)
                .font(.liviqaSerif(23)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.moss)
                .frame(width: 44, height: 3)
                .padding(.vertical, 10)
            Text(weekHeroSub)
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - "Your day" glass-timeline entry (flagged)

    private var dayScrubEntry: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw").font(.system(size: 18)).foregroundStyle(LiviqaTheme.moss)
            VStack(alignment: .leading, spacing: 2) {
                Text("Replay your day").font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
                Text("Drag the line to relive any moment of today")
                    .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(LiviqaTheme.ink4)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    // MARK: - TIR trend card (gradient area hero)

    private var tirTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GLUCOSE · TIME IN RANGE")
                    .font(.liviqaKicker(10.5)).tracking(0.8)
                    .foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                if hasRealTIR {
                    Text(tirHeadline).font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
                }
            }
            if hasRealTIR {
                let slots = weekSlots(.inRange)
                AreaTrendChart(values: tirValues, tint: LiviqaTheme.moss,
                               xTicks: slots == nil ? [] : dayLetters, unit: "%",
                               daySlots: slots)
            } else {
                emptyTrendState("No glucose data yet",
                                detail: "Connect a data source and your week in range appears here.")
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Recovery & stress card (HRV) — descriptive only

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 11)).foregroundStyle(LiviqaTheme.moss)
                    Text("RECOVERY · STRESS (HRV)")
                        .font(.liviqaKicker(10.5)).tracking(0.8)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
                if hasRealHRV {
                    Text(hrvHeadline).font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
                }
            }
            if hasRealHRV {
                let slots = weekSlots(.hrv)
                AreaTrendChart(values: hrvValues, tint: LiviqaTheme.moss,
                               xTicks: slots == nil ? [] : dayLetters, unit: " ms",
                               daySlots: slots)
                Text(hrvNarrative)
                    .font(.lato(12.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                Button { appState.showAssistant = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                        Text("Ask the assistant about this").font(.lato(12.5, .bold))
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(LiviqaTheme.moss)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            } else {
                emptyTrendState("No recovery data yet",
                                detail: "HRV from your watch or ring appears here once it syncs.")
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    /// Descriptive sentence computed from the user's own series — never a
    /// canned story about meetings or meals the app knows nothing about.
    private var hrvNarrative: String {
        guard let lo = hrvValues.min(), let hi = hrvValues.max() else { return "" }
        return "In your data, your HRV ranged from \(Int(lo.rounded())) to \(Int(hi.rounded())) ms this week. A pattern in your own data, not a medical finding."
    }

    /// Honest in-card empty state for the trend heroes (calm, no fake curve).
    private func emptyTrendState(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.lato(14, .bold))
                .foregroundStyle(LiviqaTheme.ink)
            Text(detail)
                .font(.lato(12.5))
                .foregroundStyle(LiviqaTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    // MARK: - Grid card

    private var correlationGridCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // How to read it (A7.2 DWeek header)
            VStack(alignment: .leading, spacing: 5) {
                Text(String(localized: "\(metricLabels.count) signals · 7 days").uppercased())
                    .font(.liviqaKicker(9)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text("Read down a column to see a day; across a row to see a signal.")
                    .font(.liviqaSerif(15)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
            }
            .padding(.bottom, 2)

            // Day column headers
            HStack(spacing: 0) {
                // Y-axis label gutter
                Spacer()
                    .frame(width: 74)

                ForEach(Array(week.days.enumerated()), id: \.offset) { dayIndex, day in
                    Text(day.localizedDayLetter)
                        .font(.liviqaKicker(9))
                        .tracking(0.5)
                        .foregroundStyle(markedDays.contains(dayIndex) ? LiviqaTheme.accentFinance
                                         : (dayIndex == clusterDay ? LiviqaTheme.clayText
                                            : (selected?.day == dayIndex ? LiviqaTheme.ink : LiviqaTheme.ink3)))
                        .frame(maxWidth: .infinity)
                }
            }

            // Metric rows
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(metricLabels.enumerated()), id: \.offset) { rowIndex, label in
                    HStack(spacing: 0) {
                        // Row label
                        Text(label)
                            .font(.liviqaKicker(8))
                            .tracking(0.4)
                            .foregroundStyle(selected?.metric == rowIndex ? LiviqaTheme.ink2 : LiviqaTheme.ink4)
                            .frame(width: 74, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        // Row cells
                        ForEach(Array(week.days.enumerated()), id: \.offset) { dayIndex, day in
                            let level = self.level(day: dayIndex, metric: rowIndex)
                            let isSel = selected == SelectedCell(day: dayIndex, metric: rowIndex)
                            let isMarked = markedDays.contains(dayIndex)
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selected = SelectedCell(day: dayIndex, metric: rowIndex)
                                }
                            } label: {
                                // FR-CTX-04: a marked day never takes the
                                // deviation ramp — neutral fill + hatch, even
                                // when the underlying level is `.outlier`.
                                GridCell(color: isMarked ? neutralFill(level) : fill(level),
                                         selected: isSel,
                                         cluster: !isMarked && dayIndex == clusterDay,
                                         marked: isMarked)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isMarked
                                ? "\(label), \(day.localizedDayName): \(String(localized: "marked day, not read as a deviation"))"
                                : "\(label), \(day.localizedDayName): \(level.accessibilityLabel)")
                        }
                    }
                }
            }

            // Legend
            gridLegend
                .padding(.top, 6)

            // The CALENDAR row's honest state, said once where it can be read
            // without tapping a grey square. Present only when the row is NOT
            // carrying readings — a connected, calibrated row explains itself.
            if calendarState != .ready {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10)).foregroundStyle(LiviqaTheme.ink4)
                    Text(CalendarLoadCopy.stateLine(calendarState))
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            // Tap readout (day-readout)
            Divider().overlay(LiviqaTheme.line).padding(.top, 4)
            gridReadout
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LiviqaTheme.line2, lineWidth: 1)
        )
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Grid readout

    
    @ViewBuilder
    private var gridReadout: some View {
        if let sel = selected,
           sel.day < week.days.count,
           sel.metric < metricLabels.count {
            let level = self.level(day: sel.day, metric: sel.metric)
            let dayName = week.days[sel.day].localizedDayName
            let kind = markedKind(sel.day)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(dayName) · \(metricLabels[sel.metric].capitalized)")
                        .font(.lato(13, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Spacer()
                    if let kind {
                        StatusPill(text: kind.label,
                                   dot: LiviqaTheme.accentFinance,
                                   bg: LiviqaTheme.accentFinance.opacity(0.12),
                                   fg: LiviqaTheme.accentFinance)
                    } else {
                        StatusPill(text: level.accessibilityLabel.capitalized,
                                   dot: fill(level),
                                   bg: level == .outlier ? LiviqaTheme.clay2 : LiviqaTheme.moss2,
                                   fg: level == .outlier ? LiviqaTheme.clay : LiviqaTheme.moss)
                    }
                }
                Text(readoutText(sel: sel, level: level, dayName: dayName, kind: kind))
                    .font(.lato(13)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
            }
            .transition(.opacity)
        } else {
            Text("Tap any square to read that day's signal.")
                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 2)
        }
    }

    /// Which sentence a tapped cell gets. CALENDAR has its own copy because it
    /// is not a body signal: it says how full the day was against this person's
    /// own usual, and never that a full day caused anything.
    private func readoutText(sel: SelectedCell, level: CorrelationLevel,
                             dayName: String, kind: ContextFlagKind?) -> String {
        if sel.metric == CorrelationDeriver.calendarIndex {
            let base = calendarReadout(dayIndex: sel.day, dayName: dayName, level: level)
            guard kind != nil else { return base }
            return base + " " + String(localized: "You marked that day, so Liviqa isn't reading it as a drift from your usual.")
        }
        return kind == nil
            ? readout(metric: sel.metric, level: level, day: dayName)
            : markedReadout(metric: sel.metric, level: level, day: dayName)
    }

    /// Built entirely from `CalendarLoadCopy`, so every sentence has passed
    /// `NudgeGuard` before it can reach the screen (FR-NDG-06).
    private func calendarReadout(dayIndex: Int, dayName: String, level: CorrelationLevel) -> String {
        let state = calendarState
        guard dayIndex < weekDates.count else { return CalendarLoadCopy.stateLine(state) }
        let load = CorrelationDeriver.calendarLoad(for: weekDates[dayIndex], in: calendarHistory)
        let usual = CorrelationDeriver.calendarUsual(calendarHistory)
        return CalendarLoadCopy.dayReadout(
            day: dayName,
            state: state,
            load: load,
            usualScheduledHours: usual?.mean,
            direction: load.flatMap { CorrelationDeriver.calendarDirection($0, usual: usual) },
            notable: level == .outlier)
    }

    private func readout(metric: Int, level: CorrelationLevel, day: String) -> String {
        let m = metricLabels[metric].lowercased()
        if gradedHeatmap {
            // Magnitude language to match the graded ramp (the deriver keeps |deviation|).
            switch level {
            case .noData:  return "No \(m) recorded on \(day)."
            case .low:     return "\(day)'s \(m) was just like your usual."
            case .medium:  return "\(day)'s \(m) was a little off your usual."
            case .high:    return "\(day)'s \(m) was clearly off your usual."
            case .outlier: return "\(day)'s \(m) was worth noticing — a pattern in your own data, not a medical finding."
            }
        }
        switch level {
        case .noData:  return "No \(m) recorded on \(day)."
        case .low:     return "\(day)'s \(m) sat below your typical range."
        case .medium:  return "\(day)'s \(m) was around your usual baseline."
        case .high:    return "\(day)'s \(m) ran above your typical range."
        case .outlier: return "\(day)'s \(m) was a notable deviation from your baseline — a pattern in your own data, not a medical finding."
        }
    }

    /// FR-CTX-04 readout for a marked day: name what IS there (no data stays no
    /// data), then say plainly why it isn't being called a deviation.
    private func markedReadout(metric: Int, level: CorrelationLevel, day: String) -> String {
        let m = metricLabels[metric].lowercased()
        if level == .noData {
            return String(localized: "No \(m) recorded on \(day). You marked that day, so it isn't read as a drift from your usual either way.")
        }
        return String(localized: "\(day)'s \(m) was recorded and kept. You marked that day, so Liviqa isn't reading it as a drift from your usual.")
    }

    // MARK: - Legend

    private var gridLegend: some View {
        HStack(spacing: 12) {
            if gradedHeatmap {
                LegendSwatch(color: fill(.low),     label: "Like usual")
                LegendSwatch(color: fill(.medium),  label: "A little off")
                LegendSwatch(color: fill(.high),    label: "Off your usual")
                LegendSwatch(color: fill(.outlier), label: "Worth noticing")
            } else {
                LegendSwatch(color: fill(.low),     label: "In range")
                LegendSwatch(color: fill(.high),    label: "Mild")
                LegendSwatch(color: fill(.outlier), label: "Worth noticing")
                LegendSwatch(color: fill(.noData),  label: "No data")
            }
            // Only present when the week actually contains a marked day —
            // never a legend entry for a state that isn't on screen.
            if !markedDays.isEmpty {
                LegendSwatch(color: LiviqaTheme.accentFinance.opacity(0.16),
                             label: "Marked", hatched: true)
            }
            Spacer()
        }
    }

    // MARK: - Pattern callout card

    private var patternCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack(alignment: .center) {
                Text("PATTERN DETECTED")
                    .font(.liviqaKicker(9))
                    .tracking(1)
                    .foregroundStyle(LiviqaTheme.moss)

                Spacer()

                Text(week.patternStrength)
                    .font(.liviqaKicker(9))
                    .tracking(0.5)
                    .foregroundStyle(LiviqaTheme.clay)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LiviqaTheme.clay2)
                    .clipShape(Capsule())
            }

            // Serif pattern headline (A7.2 DWeek) — named from the grid itself.
            if let c = clusterDay, c < week.days.count {
                Text(String(localized: "A harder \(week.days[c].localizedDayName), felt across your signals."))
                    .font(.liviqaSerif(16.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
            }

            // Pattern note
            Text(week.patternNote)
                .font(.lato(13))
                .foregroundStyle(LiviqaTheme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Source chips
            if !week.patternSources.isEmpty {
                HStack(spacing: 6) {
                    ForEach(week.patternSources, id: \.self) { source in
                        Text(source.uppercased())
                            .font(.liviqaKicker(9))
                            .tracking(0.5)
                            .foregroundStyle(LiviqaTheme.moss)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LiviqaTheme.moss3)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LiviqaTheme.moss3, lineWidth: 1)
        )
    }

    // MARK: - Regulatory note card

    private var regulatoryNoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.clay)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                // A7.2 delta: aligned to the canvas's exact disclaimer wording.
                Text("Liviqa describes patterns in your own data. It does not diagnose or treat.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showShare = true
                } label: {
                    Text("Share with care team →")
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.moss)
                }
            }
        }
        .padding(12)
        .background(LiviqaTheme.clay2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(LiviqaTheme.clay.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Weekly metrics row

    // Real weekly derivations from todaySignals (TodaySignalsDeriver series) —
    // never literal numbers. Each card falls back to an honest "No data yet".
    private var weeklyMetricsRow: some View {
        HStack(spacing: 8) {
            weeklyCard(series: tirValues, unit: "%", label: "TIME IN RANGE",
                       value: { "\(Int($0.rounded()))" },
                       delta: { "\($0 >= 0 ? "▲" : "▼") \(abs(Int($0.rounded()))) pts this week" })
            weeklyCard(series: sig?.sleepWeek ?? [], unit: "", label: "SLEEP",
                       value: { Self.hoursMinutes($0) },
                       delta: { "\($0 >= 0 ? "▲" : "▼") \(abs(Int(($0 * 60).rounded()))) min this week" })
            weeklyCard(series: hrvValues, unit: "", label: "HRV",
                       value: { "\(Int($0.rounded())) ms" },
                       delta: { "\($0 >= 0 ? "▲" : "▼") \(abs(Int($0.rounded()))) ms this week" })
        }
    }

    /// Week average + first→last trend computed from the user's own series.
    @ViewBuilder
    private func weeklyCard(series: [Double], unit: String, label: String,
                            value: (Double) -> String,
                            delta: (Double) -> String) -> some View {
        if series.count >= 2, let first = series.first, let last = series.last {
            let avg = series.reduce(0, +) / Double(series.count)
            let d = last - first
            // Down-weeks are information, not alarms: no red/rust off the
            // clinical glucose surface (red = clinical TIR only).
            WeeklyMetricCard(value: value(avg), unit: unit, label: label,
                             deltaLabel: delta(d),
                             deltaColor: d >= 0 ? LiviqaTheme.moss : LiviqaTheme.ink2)
        } else {
            WeeklyMetricCard(value: "—", unit: "", label: label,
                             deltaLabel: "No data yet",
                             deltaColor: LiviqaTheme.ink2)
        }
    }

    // MARK: - In-depth detail row (same anatomy as the Passport's entry rows —
    // the row is duplicated rather than shared because Components.swift belongs
    // to other concurrent work; the pattern is 20 lines of locked A7.2 anatomy).

    private func depthRow(pillar: WellnessPillar) -> some View {
        NavigationLink(destination: MetricDetailView(pillar: pillar)) {
            HStack(spacing: 12) {
                Image(systemName: pillar.icon)
                    .font(.lato(13))
                    .foregroundStyle(LiviqaTheme.moss)
                    .frame(width: 20)
                Text(pillar.title)
                    .font(.lato(13.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func hoursMinutes(_ hours: Double) -> String {
        var h = Int(hours)
        var m = Int(((hours - Double(h)) * 60).rounded())
        if m == 60 { h += 1; m = 0 }
        return String(format: "%dh %02d", h, m)
    }

}

// MARK: - GridCell

private struct GridCell: View {
    let color: Color
    var selected: Bool = false
    var cluster: Bool = false   // part of the lit cluster column
    /// FR-CTX-04 — the user marked this day (travelling / unwell / off-routine).
    /// The cell renders NEUTRAL: no deviation ramp, no alarm tint, plus the
    /// shared diagonal hatch so the state survives colour-blindness and
    /// greyscale (same helper the TIR zones use — one hatch in the app).
    var marked: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay {
                if marked {
                    ZoneHatch(color: LiviqaTheme.accentFinance.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .inset(by: -2)
                    .stroke(selected ? LiviqaTheme.ink
                            : (cluster ? LiviqaTheme.clay.opacity(0.55) : .clear),
                            lineWidth: selected ? 2 : 1.5)
            )
    }
}

// MARK: - LegendSwatch

private struct LegendSwatch: View {
    let color: Color
    let label: String
    /// FR-CTX-04 "marked" swatch — carries the same hatch as the grid cell.
    var hatched: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay {
                    if hatched {
                        ZoneHatch(color: LiviqaTheme.accentFinance.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            Text(label)
                .font(.liviqaKicker(8))
                .foregroundStyle(LiviqaTheme.ink4)
        }
    }
}

// MARK: - WeeklyMetricCard

private struct WeeklyMetricCard: View {
    let value: String
    let unit: String
    let label: String
    let deltaLabel: String
    let deltaColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.liviqaMono(17))
                    .monospacedDigit()
                    .foregroundStyle(LiviqaTheme.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.liviqaKicker(9))
                        .foregroundStyle(LiviqaTheme.ink4)
                }
            }

            Text(label)
                .font(.liviqaKicker(9))
                .tracking(0.6)
                .foregroundStyle(LiviqaTheme.ink4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(deltaLabel)
                .font(.lato(11, .bold))
                .foregroundStyle(deltaColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(LiviqaTheme.line, lineWidth: 0.5)
        )
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
    }
}

// MARK: - Preview

#Preview {
    WeekInContextView()
        .environment(AppState())
}

// Locale-correct weekday labels derived from the day's actual date (dateOffset
// back from today) — static English letters can't map across languages.
private extension CorrelationDay {
    var dayDate: Date { Calendar.current.date(byAdding: .day, value: -dateOffset, to: Date()) ?? Date() }
    var localizedDayLetter: String { dayDate.formatted(.dateTime.weekday(.narrow)) }
    var localizedDayName: String { dayDate.formatted(.dateTime.weekday(.wide)) }
}
