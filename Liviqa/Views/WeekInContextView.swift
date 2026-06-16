// WeekInContextView.swift — 7-day correlation grid · v01 2026-05-22
import SwiftUI

// MARK: - WeekInContextView

struct WeekInContextView: View {

    @Environment(AppState.self) private var appState
    @AppStorage("liquidGlass") private var glassOn = true
    /// PR-100 promotion #2 — graded deviation ramp instead of the 2-state moss/clay
    /// fill. SIGNED OFF by CN, now live by default (still a flag for instant revert).
    @AppStorage("gradedHeatmap") private var gradedHeatmap = true
    @State private var showShare = false
    /// Interactive grid selection: (dayIndex, metricIndex).
    @State private var selected: SelectedCell? = nil

    /// Correlation heatmap — real on-device grid once Health is connected
    /// (AppState derives it in refreshFromHealth), the demo grid otherwise.
    private var week: CorrelationWeek { appState.correlationWeek }

    private let metricLabels = [
        "GLUCOSE", "SLEEP", "HRV", "EXERCISE",
        "SPENDING", "CALENDAR", "WEATHER"
    ]

    /// Weekly glucose time-in-range %, oldest → today (presentation seed).
    private static let tirWeek: [Double] = [71, 74, 69, 78, 80, 76, 84]
    /// Weekly HRV (ms), oldest → today — the recovery / stress axis (presentation seed).
    private static let hrvWeek: [Double] = [48, 45, 39, 41, 44, 50, 52]

    // Real derived series/values when Health is connected, else the seeds above.
    private var sig: TodaySignals? { appState.todaySignals }
    private var tirValues: [Double] { (sig?.inRangeWeek.isEmpty == false) ? sig!.inRangeWeek : Self.tirWeek }
    private var hrvValues: [Double] { (sig?.hrvWeek.isEmpty == false) ? sig!.hrvWeek : Self.hrvWeek }
    private var hasRealTIR: Bool { (sig?.inRange ?? "—") != "—" }
    private var hasRealHRV: Bool { (sig?.hrv ?? "—") != "—" }
    private var tirHeadline: String { hasRealTIR ? sig!.inRange : "84%" }
    private var hrvHeadline: String { hasRealHRV ? sig!.hrv + " ms" : "52 ms" }

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

    /// The cluster column — the day with the most "worth noticing" signals.
    /// A lit column is the whole point of the heatmap; we ring it and name it.
    private var clusterDay: Int? {
        var best: (idx: Int, score: Int)? = nil
        for (i, day) in week.days.enumerated() {
            let score = day.values.reduce(0) { $0 + ($1 == .outlier ? 2 : $1 == .high ? 1 : 0) }
            if score > 0, best == nil || score > best!.score { best = (i, score) }
        }
        return best?.idx
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // 1. App bar
                LiviqaAppBar(title: "Your Week", showMark: false)

                VStack(alignment: .leading, spacing: 0) {

                    // 2a. Weekly time-in-range trend (gradient area + draw-in)
                    tirTrendCard
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    // Liquid Glass "Your day" detail (flagged): scrub your day on a
                    // glass timeline over an ambient field. Pushes an additive screen.
                    if glassOn {
                        NavigationLink {
                            DayTimelineView()
                        } label: { dayScrubEntry }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // 2b. Recovery & stress (HRV) — descriptive, no stress score/verdict
                    recoveryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // 2. Section header
                    LiviqaSectionHeader(label: "7 days in context")
                        .padding(.horizontal, 20)

                    // 3. Correlation grid card
                    correlationGridCard
                        .padding(.horizontal, 16)

                    // 4. Pattern callout
                    patternCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // 5. MDR/AI Act note
                    regulatoryNoteCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // 6. Section header — weekly metrics
                    LiviqaSectionHeader(label: "This week")
                        .padding(.horizontal, 20)

                    // 7. Three metric cards
                    weeklyMetricsRow
                        .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
        }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: chrome dissolves into the trend feed
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .sheet(isPresented: $showShare) {
            shareSheet
        }
    }

    // MARK: - "Your day" glass-timeline entry (flagged)

    private var dayScrubEntry: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw").font(.system(size: 18)).foregroundStyle(LiviqaTheme.moss)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scrub your day").font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
                Text("Move through today's readings on a glass timeline")
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
                HStack(spacing: 6) {
                    Text(tirHeadline).font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
                    if !hasRealTIR { StatusPill(text: "▲ 8 pts", dot: nil) }
                }
            }
            AreaTrendChart(values: tirValues, tint: LiviqaTheme.moss,
                           xTicks: week.days.map { $0.localizedDayLetter }, unit: "%")
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
                HStack(spacing: 6) {
                    Text(hrvHeadline).font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
                    if !hasRealHRV { StatusPill(text: "▲ 4 ms", dot: nil) }
                }
            }
            AreaTrendChart(values: hrvValues, tint: LiviqaTheme.moss,
                           xTicks: week.days.map { $0.localizedDayLetter }, unit: " ms")
            Text("In your data, your HRV ran lower mid-week — the days with higher meeting load and later meals. A pattern in your own data, not a medical finding.")
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
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Grid card

    private var correlationGridCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Day column headers
            HStack(spacing: 0) {
                // Y-axis label gutter
                Spacer()
                    .frame(width: 74)

                ForEach(Array(week.days.enumerated()), id: \.offset) { dayIndex, day in
                    Text(day.localizedDayLetter)
                        .font(.liviqaKicker(9))
                        .tracking(0.5)
                        .foregroundStyle(dayIndex == clusterDay ? LiviqaTheme.clayText
                                         : (selected?.day == dayIndex ? LiviqaTheme.ink : LiviqaTheme.ink3))
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
                            let level = rowIndex < day.values.count
                                ? day.values[rowIndex]
                                : .noData
                            let isSel = selected == SelectedCell(day: dayIndex, metric: rowIndex)
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selected = SelectedCell(day: dayIndex, metric: rowIndex)
                                }
                            } label: {
                                GridCell(color: fill(level), selected: isSel,
                                         cluster: dayIndex == clusterDay)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(label), \(day.localizedDayName): \(level.accessibilityLabel)")
                        }
                    }
                }
            }

            // Legend
            gridLegend
                .padding(.top, 6)

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
           sel.metric < week.days[sel.day].values.count {
            let level = week.days[sel.day].values[sel.metric]
            let dayName = week.days[sel.day].localizedDayName
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(dayName) · \(metricLabels[sel.metric].capitalized)")
                        .font(.lato(13, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Spacer()
                    StatusPill(text: level.accessibilityLabel.capitalized,
                               dot: fill(level),
                               bg: level == .outlier ? LiviqaTheme.clay2 : LiviqaTheme.moss2,
                               fg: level == .outlier ? LiviqaTheme.clay : LiviqaTheme.moss)
                }
                Text(readout(metric: sel.metric, level: level, day: dayName))
                    .font(.lato(13)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
            }
            .transition(.opacity)
        } else {
            Text("Tap any square to read that day's signal.")
                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 2)
        }
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
                Text("This is a pattern in your own data — not a medical finding. Worth discussing with your care team if it repeats.")
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

    private var weeklyMetricsRow: some View {
        HStack(spacing: 8) {
            WeeklyMetricCard(
                value: "7.1",
                unit: "mmol/L",
                label: "GLUCOSE AVG",
                deltaLabel: "▼ 0.8 from last week",
                deltaColor: LiviqaTheme.moss
            )
            WeeklyMetricCard(
                value: "7h 02",
                unit: "",
                label: "SLEEP",
                deltaLabel: "▲ 18 min",
                deltaColor: LiviqaTheme.moss
            )
            WeeklyMetricCard(
                value: "42 ms",
                unit: "",
                label: "HRV",
                deltaLabel: "▼ 8 ms",
                deltaColor: LiviqaTheme.rust
            )
        }
    }

    // MARK: - Share sheet placeholder

    private var shareSheet: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Share flow coming soon")
                .font(.lato(15, .medium))
                .foregroundStyle(LiviqaTheme.ink2)
            Button("Dismiss") { showShare = false }
                .font(.lato(14))
                .foregroundStyle(LiviqaTheme.moss)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }
}

// MARK: - GridCell

private struct GridCell: View {
    let color: Color
    var selected: Bool = false
    var cluster: Bool = false   // part of the lit cluster column

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(width: 28, height: 28)
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

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
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
}

// Locale-correct weekday labels derived from the day's actual date (dateOffset
// back from today) — static English letters can't map across languages.
private extension CorrelationDay {
    var dayDate: Date { Calendar.current.date(byAdding: .day, value: -dateOffset, to: Date()) ?? Date() }
    var localizedDayLetter: String { dayDate.formatted(.dateTime.weekday(.narrow)) }
    var localizedDayName: String { dayDate.formatted(.dateTime.weekday(.wide)) }
}
