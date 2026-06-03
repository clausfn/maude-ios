// WeekInContextView.swift — 7-day correlation grid · v01 2026-05-22
import SwiftUI

// MARK: - WeekInContextView

struct WeekInContextView: View {

    @State private var showShare = false
    /// Interactive grid selection: (dayIndex, metricIndex).
    @State private var selected: SelectedCell? = nil

    private let week = MockData.correlationWeek

    private let metricLabels = [
        "GLUCOSE", "SLEEP", "HRV", "EXERCISE",
        "SPENDING", "CALENDAR", "WEATHER"
    ]

    /// Weekly glucose time-in-range %, oldest → today (presentation seed).
    private static let tirWeek: [Double] = [71, 74, 69, 78, 80, 76, 84]

    struct SelectedCell: Equatable { let day: Int; let metric: Int }

    /// Theme-aware fill for a correlation level (the model's own `.color` is
    /// light-mode-only hex; remap to dynamic tokens so Midnight reads correctly).
    private func fill(_ level: CorrelationLevel) -> Color {
        switch level {
        case .noData:  return LiviqaTheme.gridEmpty
        case .low:     return LiviqaTheme.moss3
        case .medium:  return LiviqaTheme.moss.opacity(0.5)
        case .high:    return LiviqaTheme.moss
        case .outlier: return LiviqaTheme.amber
        }
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
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .sheet(isPresented: $showShare) {
            shareSheet
        }
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
                    Text("84%").font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
                    StatusPill(text: "▲ 8 pts", dot: nil)
                }
            }
            AreaTrendChart(values: Self.tirWeek, tint: LiviqaTheme.moss,
                           xTicks: week.days.map { $0.dayLabel })
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
                    Text(day.dayLabel)
                        .font(.liviqaKicker(9))
                        .tracking(0.5)
                        .foregroundStyle(selected?.day == dayIndex ? LiviqaTheme.ink : LiviqaTheme.ink3)
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
                                GridCell(color: fill(level), selected: isSel)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(label), \(day.dayLabel): \(level.accessibilityLabel)")
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

    private var fullDayNames: [String] { ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"] }

    @ViewBuilder
    private var gridReadout: some View {
        if let sel = selected,
           sel.day < week.days.count,
           sel.metric < week.days[sel.day].values.count {
            let level = week.days[sel.day].values[sel.metric]
            let dayName = sel.day < fullDayNames.count ? fullDayNames[sel.day] : week.days[sel.day].dayLabel
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(dayName) · \(metricLabels[sel.metric].capitalized)")
                        .font(.lato(13, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Spacer()
                    StatusPill(text: level.accessibilityLabel.capitalized,
                               dot: fill(level),
                               bg: level == .outlier ? LiviqaTheme.amber2 : LiviqaTheme.moss2,
                               fg: level == .outlier ? LiviqaTheme.amber : LiviqaTheme.moss)
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
        HStack(spacing: 14) {
            LegendSwatch(color: fill(.noData),  label: "No data")
            LegendSwatch(color: fill(.low),     label: "Normal")
            LegendSwatch(color: fill(.high),    label: "Elevated")
            LegendSwatch(color: fill(.outlier), label: "Outlier")
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
                    .foregroundStyle(LiviqaTheme.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LiviqaTheme.amber2)
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
                .foregroundStyle(LiviqaTheme.amber)
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
        .background(LiviqaTheme.amber2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(LiviqaTheme.amber.opacity(0.5), lineWidth: 0.5)
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

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(width: 28, height: 28)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .inset(by: -2)
                    .stroke(selected ? LiviqaTheme.ink : .clear, lineWidth: 2)
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
