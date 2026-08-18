// TrendsView.swift · v03 2026-08-12 — A7.2 rebuild (FR-TOD-06, Area ②).
// Design ref: f-missing.jsx ScrTrends ("Liviqa Missing Screens (A7).html").
// Pushed from Today (momentum strip "See the trend →"; DEBUG: LIVIQA_OPEN_TRENDS=1).
//
// Honest-data rail: every figure comes from TrendsDeriver over the device's own
// samples (demo mode runs the same deriver over the labelled demo provider's
// samples) — the old canned correlation/month copy is gone and can never render.
// Correlation cards appear ONLY past the evidence gate (|r| ≥ 0.4, p ≤ 0.05,
// N ≥ 10 paired days) with their N·r·p always on (FR-XPL-01). The TIR chart is
// personal-band framed (moss/fjord, "Your usual · lo–hi%") — clinical red stays
// exclusive to the glucose detail. Glucose mmol/L (OD-07).
import SwiftUI

struct TrendsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum Range: String, CaseIterable {
        case week = "Week", month = "Month", quarter = "Quarter"

        var periodWord: String {
            switch self {
            case .week:    return String(localized: "week")
            case .month:   return String(localized: "month")
            case .quarter: return String(localized: "quarter")
            }
        }
        var sectionLabel: String {
            switch self {
            case .week:    return String(localized: "This week")
            case .month:   return String(localized: "This month")
            case .quarter: return String(localized: "This quarter")
            }
        }
    }

    @State private var range: Range = .month

    private var summary: TrendsSummary? { appState.trends }

    private var current: TrendsRange? {
        guard let s = summary else { return nil }
        switch range {
        case .week:    return s.week
        case .month:   return s.month
        case .quarter: return s.quarter
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                header
                    .padding(.top, 6)

                segmentedControl
                    .padding(.top, 14)

                if let r = current {
                    tirHero(r)
                        .padding(.top, 16)

                    LiviqaSectionHeader(label: "What's connected")

                    if r.correlations.isEmpty {
                        connectionsLearningCard(r)
                    } else {
                        ForEach(Array(r.correlations.enumerated()), id: \.offset) { _, c in
                            correlationCard(c)
                        }
                    }

                    LiviqaSectionHeader(label: range.sectionLabel)

                    HStack(spacing: 10) {
                        monthMetric(value: r.sleepAvgHours.map { Self.sleepText($0) },
                                    label: String(localized: "Sleep avg"),
                                    delta: sleepDeltaText(r), good: (r.sleepDeltaMin ?? 0) > 0)
                        monthMetric(value: r.rhrAvg.map { "\($0)" },
                                    label: String(localized: "Resting HR"),
                                    delta: rhrDeltaText(r), good: (r.rhrDeltaBpm ?? 0) < 0)
                        monthMetric(value: r.activeMinPerDay.map { "\($0)" },
                                    label: String(localized: "Active min/day"),
                                    delta: activeDeltaText(r), good: (r.activeDeltaMin ?? 0) > 0)
                    }

                    // The honesty line — especially for Quarter before 90 days exist.
                    Text("Derived on this device from \(r.daysCovered) day\(r.daysCovered == 1 ? "" : "s") of your own readings in this window.")
                        .font(.lato(11)).foregroundStyle(LiviqaTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                } else {
                    emptyState
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 20)
        }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: chrome dissolves into the feed
        .liviqaScrollEdge()       // every device: paper fades under the status bar
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .liviqaDetail()   // hide the floating tab bar while this detail is on top
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: - Header (back to Today · centred title · sample-data honesty chip)

    private var header: some View {
        ZStack {
            NavBackHeader(onBack: { dismiss() }) {
                if appState.isSampleMode {
                    Text(String(localized: "Sample data").uppercased())
                        .font(.liviqaKicker(9)).tracking(0.8)
                        .foregroundStyle(LiviqaTheme.clayText)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(LiviqaTheme.clay2))
                }
            }
            Text("Trends")
                .font(.lato(15, .bold))
                .foregroundStyle(LiviqaTheme.ink)
        }
    }

    // MARK: - Range segmented control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(Range.allCases, id: \.self) { chip in
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
            }
        }
        .padding(3)
        .background(LiviqaTheme.line2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - TIR hero — daily bars vs the user's own usual band

    @ViewBuilder
    private func tirHero(_ r: TrendsRange) -> some View {
        if r.tirDaily.count >= 2 {
            VStack(alignment: .leading, spacing: 0) {
                // "N days" counts days WITH a reading — the chart below spans
                // the calendar days between the first and today, so the two
                // figures differ exactly when the window has gaps, and both
                // are true.
                Text(String(localized: "Glucose · time in range · \(r.tirDaily.count) days").uppercased())
                    .font(.liviqaKicker(9.5)).tracking(1)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(tirHeadline(r))
                    .font(.liviqaSerif(19)).kerning(-0.2).lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7).padding(.bottom, 10)
                TIRTrendBarChart(
                    slots: r.tirSlots,
                    bandLo: r.tirBandLo, bandHi: r.tirBandHi,
                    todayAnnotation: r.tirTodayPct.map { String(localized: "\($0)% today") },
                    neutralDates: markedDates(r))
                if markedCount(r) > 0 {
                    contextStrip(markedCount(r))
                        .padding(.top, 12)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
        } else {
            honestCard(
                title: String(localized: "No glucose readings in this window yet"),
                detail: String(localized: "Connect a data source and your time-in-range trend appears here, drawn against your own usual band."))
        }
    }

    // MARK: - Context flags (FR-CTX-04) — marked days stay in, read neutral

    /// Every calendar day of the selected window (today back `windowDays - 1`).
    /// Exact by construction: the window is defined by the range itself, so no
    /// day is inferred from the chart series.
    private func windowDays(_ r: TrendsRange) -> [Date] {
        let cal = ContextWindow.calendar
        let today = cal.startOfDay(for: Date())
        return (0..<r.windowDays).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    private func markedCount(_ r: TrendsRange) -> Int {
        let windows = appState.contextWindows
        guard !windows.isEmpty else { return 0 }
        return ContextFlagDeriver.markedCount(among: windowDays(r), in: windows)
    }

    /// The marked days as DATES — handed to the chart so the right bars go
    /// neutral. Now that each bar knows its own day, "which bar is Tuesday" is
    /// answerable; before this it was not, which is why the chart could not
    /// carry FR-CTX-04 at all.
    private func markedDates(_ r: TrendsRange) -> Set<Date> {
        let windows = appState.contextWindows
        guard !windows.isEmpty else { return [] }
        let cal = ContextWindow.calendar
        return Set(windowDays(r)
            .filter { ContextFlagDeriver.isMarked($0, in: windows) }
            .map { cal.startOfDay(for: $0) })
    }

    /// True when TODAY is marked. Used to hold back the "lately…" tail on the
    /// hero sentence — the only place that sentence makes a deviation claim,
    /// and it reads the last charted day, which is today exactly when
    /// `tirTodayPct` is non-nil.
    private func todayIsMarked(_ r: TrendsRange) -> Bool {
        r.tirTodayPct != nil
            && ContextFlagDeriver.isMarked(Date(), in: appState.contextWindows)
    }

    /// Honest annotation, not a redraw: the bars stay exactly as recorded, and
    /// the line says what marking did and did not change. Slate, hatched —
    /// never an alarm colour.
    private func contextStrip(_ count: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(LiviqaTheme.accentFinance.opacity(0.16))
                .frame(width: 12, height: 12)
                .overlay {
                    ZoneHatch(color: LiviqaTheme.accentFinance.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.top, 1)
            Text(count == 1
                 ? String(localized: "One day in this window is marked. It stays in the figures exactly as recorded — Liviqa just doesn't read it as a drift from your usual.")
                 : String(localized: "\(count) days in this window are marked. They stay in the figures exactly as recorded — Liviqa just doesn't read them as drifts from your usual."))
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Lately" has to mean lately. The last CHARTED day is the last day with a
    /// reading, which can sit well back in the window when a sensor has been
    /// off; past two days the tail is dropped rather than dated wrongly.
    private func lastChartedDayIsRecent(_ r: TrendsRange) -> Bool {
        guard let last = r.tirDailyDates.max() else { return false }
        let cal = DaySeries.calendar
        let gap = cal.dateComponents([.day], from: cal.startOfDay(for: last),
                                     to: cal.startOfDay(for: r.windowEnd)).day ?? 0
        return gap <= 2
    }

    /// Fixed descriptive templates only — the verdict tail renders only when a
    /// personal band exists to compare against.
    private func tirHeadline(_ r: TrendsRange) -> String {
        let pct = r.tirPeriodPct
        let period = range.periodWord
        guard let lo = r.tirBandLo, let hi = r.tirBandHi, let recent = r.tirDaily.last,
              !todayIsMarked(r), lastChartedDayIsRecent(r) else {
            return String(localized: "In range \(pct)% of this \(period).")
        }
        if recent < lo {
            return String(localized: "In range \(pct)% of this \(period) — lately a little under your usual band.")
        }
        if recent > hi {
            return String(localized: "In range \(pct)% of this \(period) — lately a little above your usual band.")
        }
        return String(localized: "In range \(pct)% of this \(period) — steady in your usual band.")
    }

    // MARK: - Correlations (gate-first)

    private func correlationCard(_ c: TrendCorrelation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(c.pairTitle)
                    .font(.lato(14, .bold))
                    .kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer(minLength: 6)
                Text((c.strong ? String(localized: "Strong") : String(localized: "Moderate")).uppercased())
                    .font(.liviqaKicker(9.5))
                    .tracking(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(c.strong ? LiviqaTheme.moss2 : LiviqaTheme.clay2)
                    .foregroundStyle(c.strong ? LiviqaTheme.moss : LiviqaTheme.clayText)
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LiviqaTheme.line2)
                    Capsule()
                        .fill(c.strong ? LiviqaTheme.moss : LiviqaTheme.clay)
                        .frame(width: geo.size.width * min(1, abs(c.r)))
                }
            }
            .frame(height: 5)
            .padding(.vertical, 11)

            Text(c.body)
                .font(.lato(13))
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            // The evidence, always on (FR-XPL-01) — same chips as the nudge detail.
            HStack(spacing: 6) {
                evidenceChip("N", "\(c.n) days")
                evidenceChip("r", String(format: "%.2f", c.r))
                evidenceChip(nil, "p\(c.pText)")
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
        .padding(.bottom, 10)
    }

    private func evidenceChip(_ key: String?, _ value: String) -> some View {
        HStack(spacing: 4) {
            if let key { Text(key).foregroundStyle(LiviqaTheme.ink3) }
            Text(value).foregroundStyle(LiviqaTheme.ink)
        }
        .font(.liviqaMono(10.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(LiviqaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    /// Below the gate we refuse to assert — the honest still-learning state.
    private func connectionsLearningCard(_ r: TrendsRange) -> some View {
        honestCard(
            title: String(localized: "Still learning how your signals move together"),
            detail: String(localized: "A connection appears here once a pattern in your own data passes the evidence gate — a clear relationship (r ≥ 0.4, p ≤ 0.05) over enough days. Below that bar, Liviqa doesn't claim one."))
    }

    // MARK: - Aggregate tiles

    private func monthMetric(value: String?, label: String,
                             delta: String, good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value ?? "—")
                .font(.liviqaMono(18))
                .monospacedDigit()
                .foregroundStyle(LiviqaTheme.ink)
            Text(label.uppercased())
                .font(.liviqaKicker(9))
                .tracking(0.8)
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(delta)
                .font(.lato(11, .bold))
                .foregroundStyle(value == nil ? LiviqaTheme.ink4
                                 : (good ? LiviqaTheme.moss : LiviqaTheme.ink3))
                .padding(.top, 6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 4, y: 1)
        .accessibilityElement(children: .combine)
    }

    private static func sleepText(_ hours: Double) -> String {
        var h = Int(hours)
        var m = Int(((hours - Double(h)) * 60).rounded())
        if m == 60 { h += 1; m = 0 }
        return String(format: "%dh%02d", h, m)
    }

    private func sleepDeltaText(_ r: TrendsRange) -> String {
        guard r.sleepAvgHours != nil else { return String(localized: "no data yet") }
        guard let d = r.sleepDeltaMin else { return String(localized: "– no earlier window") }
        if abs(d) < 5 { return String(localized: "– flat") }
        return d > 0 ? "▲ \(d) min" : "▼ \(abs(d)) min"
    }

    private func rhrDeltaText(_ r: TrendsRange) -> String {
        guard r.rhrAvg != nil else { return String(localized: "no data yet") }
        guard let d = r.rhrDeltaBpm else { return String(localized: "– no earlier window") }
        if abs(d) < 1 { return String(localized: "– flat") }
        return d > 0 ? "▲ \(d) bpm" : "▼ \(abs(d)) bpm"
    }

    private func activeDeltaText(_ r: TrendsRange) -> String {
        guard r.activeMinPerDay != nil else { return String(localized: "no data yet") }
        guard let d = r.activeDeltaMin else { return String(localized: "– no earlier window") }
        if abs(d) < 3 { return String(localized: "– flat") }
        return d > 0 ? "▲ \(d) min" : "▼ \(abs(d)) min"
    }

    // MARK: - Honest states

    private func honestCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.lato(14, .bold))
                .foregroundStyle(LiviqaTheme.ink)
            Text(detail)
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 26)).foregroundStyle(LiviqaTheme.moss)
            Text("Your trends are still filling in")
                .font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
            Text("Trends build from your own readings on this device — once there's a week or more of data, this page compares each period against your own usual.")
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card)
            .stroke(LiviqaTheme.line, lineWidth: 0.5))
    }
}
