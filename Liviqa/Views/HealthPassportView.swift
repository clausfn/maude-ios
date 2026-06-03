// HealthPassportView.swift — Lifetime personal data record · v02 2026-05-22
// v02: Added "About you" section (declared HealthContext) with Edit → ProfileSheet.
import SwiftUI

struct HealthPassportView: View {
    @Environment(AppState.self) private var appState
    @State private var showConsentLedger = false
    @State private var showDataSources   = false
    @State private var showProfile       = false
    @State private var profileAnchor: ProfileSheet.Section? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                    // ── App bar ──
                    LiviqaAppBar(title: "Health Passport", showMark: false)

                    VStack(alignment: .leading, spacing: 0) {

                        // ── ABOUT YOU (declared — user fills this in) ──
                        LiviqaSectionHeader(label: "About you")

                        VStack(alignment: .leading, spacing: 0) {
                            aboutYouRow(
                                icon: "cross.case.fill",
                                label: "Conditions",
                                value: appState.healthContext.conditions.map(\.name).joined(separator: ", "),
                                fallback: "Not set",
                                anchor: .conditions
                            )
                            Divider().background(LiviqaTheme.line2).padding(.leading, 44)
                            aboutYouRow(
                                icon: "target",
                                label: "Glucose target",
                                value: {
                                    let t = appState.healthContext.targets
                                    if let lo = t.glucoseRangeLow, let hi = t.glucoseRangeHigh {
                                        return "\(String(format: "%.1f", lo))–\(String(format: "%.1f", hi)) mmol/L"
                                    }
                                    return nil
                                }(),
                                fallback: "Not set — tap to calibrate",
                                anchor: .targets
                            )
                            Divider().background(LiviqaTheme.line2).padding(.leading, 44)
                            aboutYouRow(
                                icon: "flag.fill",
                                label: "Goals",
                                value: appState.healthContext.goals.isEmpty ? nil
                                    : appState.healthContext.goals.map(\.text).joined(separator: " · "),
                                fallback: "Not set",
                                anchor: .goals
                            )
                            Divider().background(LiviqaTheme.line2).padding(.leading, 44)
                            aboutYouRow(
                                icon: "figure.run",
                                label: "Diet & training",
                                value: [appState.healthContext.dietApproach,
                                        appState.healthContext.trainingPattern]
                                    .filter { !$0.isEmpty }.joined(separator: " · "),
                                fallback: "Not set",
                                anchor: .lifestyle
                            )
                        }
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
                        .sheet(isPresented: $showProfile, onDismiss: { profileAnchor = nil }) {
                            ProfileSheet(openSection: profileAnchor)
                        }

                        // ── YOUR NUMBERS ──
                        LiviqaSectionHeader(label: "Your numbers")

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            statTile(
                                value: appState.passportStats.totalReadings.formatted(),
                                label: "READINGS LOGGED",
                                subtitle: "since you started"
                            )
                            statTile(
                                value: "\(appState.passportStats.nudgesGenerated)",
                                label: "PATTERNS FOUND",
                                subtitle: "in your data"
                            )
                            statTile(
                                value: "\(appState.passportStats.daysTracked)",
                                label: "DAYS TRACKED",
                                subtitle: "and counting"
                            )
                            timeInRangeTile
                        }

                        // ── 7 DAYS IN CONTEXT (live correlation grid, FR-PAS-05 / DM-06) ──
                        LiviqaSectionHeader(label: "7 days in context")
                        correlationCard

                        // ── YOUR WELLNESS SUMMARY ──
                        LiviqaSectionHeader(label: "Your wellness summary")

                        VStack(spacing: 0) {
                            summaryRow(
                                icon: "moon.fill",
                                label: "Average sleep",
                                value: "7h 05",
                                delta: "▲ 18 min vs last month",
                                deltaColor: LiviqaTheme.moss
                            )
                            Divider()
                                .background(LiviqaTheme.line2)
                            summaryRow(
                                icon: "waveform.path.ecg",
                                label: "Resting HRV",
                                value: "42 ms",
                                delta: "▼ 8 ms vs last month",
                                deltaColor: LiviqaTheme.rust
                            )
                        }
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)

                        // ── PRIVACY RECORD ──
                        LiviqaSectionHeader(label: "Privacy record")

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.lato(16))
                                    .foregroundStyle(LiviqaTheme.moss)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("All data processing happens on this device.")
                                        .font(.lato(13.5, .bold))
                                        .foregroundStyle(LiviqaTheme.ink)
                                    Text("Your consent decisions are independently logged and cannot be edited by anyone — including Liviqa.")
                                        .font(.lato(12.5))
                                        .lineSpacing(2)
                                        .foregroundStyle(LiviqaTheme.ink2)
                                }
                            }

                            Divider()
                                .background(LiviqaTheme.moss3)

                            HStack {
                                Text("\(appState.passportStats.consentDecisions) decisions on record")
                                    .font(.caption)
                                    .foregroundStyle(LiviqaTheme.ink4)
                                Spacer()
                                NavigationLink(destination: ConsentLedgerView()) {
                                    Text("View full log →")
                                        .font(.caption)
                                        .foregroundStyle(LiviqaTheme.moss)
                                }
                            }
                        }
                        .padding(14)
                        .background(LiviqaTheme.moss2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))

                        // ── CONNECTED SOURCES ──
                        LiviqaSectionHeader(label: "Connected sources")

                        HStack {
                            Text("\(appState.passportStats.sourcesConnected) active")
                                .font(.lato(13.5, .medium))
                                .foregroundStyle(LiviqaTheme.moss)
                            Spacer()
                            NavigationLink(destination: DataSourcesView()) {
                                Text("Manage →")
                                    .font(.lato(13.5, .medium))
                                    .foregroundStyle(LiviqaTheme.moss)
                            }
                        }
                        .padding(14)
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)

                        // ── Footer ──
                        Text("Your data belongs to you. Liviqa has no access to your raw records.")
                            .font(.caption)
                            .foregroundStyle(LiviqaTheme.ink4)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Health Passport")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Correlation grid (FR-PAS-05 / DM-06, live appState.correlationWeek)

    /// Column order mirrors `CorrelationDeriver.signalLabels`:
    /// glucose · sleep · hrv · exercise · spending · calendar · weather.
    private let correlationMetricLabels = [
        "GLUCOSE", "SLEEP", "HRV", "EXERCISE", "SPENDING", "CALENDAR", "WEATHER"
    ]

    private var correlationCard: some View {
        let week = appState.correlationWeek
        return VStack(alignment: .leading, spacing: 12) {

            // Heat-map: rows = signals, columns = days (oldest → today).
            VStack(alignment: .leading, spacing: 10) {
                // Day headers
                HStack(spacing: 0) {
                    Spacer().frame(width: 74)
                    ForEach(week.days) { day in
                        Text(day.dayLabel)
                            .font(.liviqaKicker(9))
                            .tracking(0.5)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                // Metric rows
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(correlationMetricLabels.enumerated()), id: \.offset) { rowIndex, label in
                        HStack(spacing: 0) {
                            Text(label)
                                .font(.liviqaKicker(8))
                                .tracking(0.4)
                                .foregroundStyle(LiviqaTheme.ink4)
                                .frame(width: 74, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            ForEach(week.days) { day in
                                let level = rowIndex < day.values.count ? day.values[rowIndex] : .noData
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(level.color)
                                    .frame(width: 28, height: 28)
                                    .frame(maxWidth: .infinity)
                                    // NFR-A11Y-01: per-cell label = metric + day + the
                                    // existing CorrelationLevel.accessibilityLabel.
                                    .accessibilityElement()
                                    .accessibilityLabel("\(label), \(day.dayLabel): \(level.accessibilityLabel)")
                            }
                        }
                    }
                }
                // Legend
                HStack(spacing: 14) {
                    correlationSwatch(.noData,  "No data")
                    correlationSwatch(.low,     "Normal")
                    correlationSwatch(.high,    "Elevated")
                    correlationSwatch(.outlier, "Outlier")
                    Spacer()
                }
                .padding(.top, 2)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)

            // Pattern note / sources / strength — your-own-data framing, no chips.
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PATTERN")
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
                Text(week.patternNote)
                    .font(.lato(13))
                    .foregroundStyle(LiviqaTheme.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
    }

    private func correlationSwatch(_ level: CorrelationLevel, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(level.color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.liviqaKicker(8))
                .foregroundStyle(LiviqaTheme.ink4)
        }
    }

    // MARK: - Stat tile

    private func statTile(value: String, label: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.liviqaMono(28))
                .monospacedDigit()
                .foregroundStyle(LiviqaTheme.ink)
            Text(label)
                .font(.liviqaKicker(9))
                .tracking(0.8)
                .foregroundStyle(LiviqaTheme.ink4)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(LiviqaTheme.ink4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    private var timeInRangeTile: some View {
        let tir = appState.passportStats.glucoseTimeInRange
        let valueColor: Color = tir >= 80 ? LiviqaTheme.moss
                              : tir >= 60 ? LiviqaTheme.amber
                              : LiviqaTheme.rust

        return VStack(alignment: .leading, spacing: 6) {
            Text("\(tir)%")
                .font(.liviqaMono(28))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Text("TIME IN RANGE")
                .font(.liviqaKicker(9))
                .tracking(0.8)
                .foregroundStyle(LiviqaTheme.ink4)
            Text("last 30 days")
                .font(.caption2)
                .foregroundStyle(LiviqaTheme.ink4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    // MARK: - About you row

    private func aboutYouRow(icon: String, label: String, value: String?,
                              fallback: String, anchor: ProfileSheet.Section) -> some View {
        Button {
            profileAnchor = anchor
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.lato(13))
                    .foregroundStyle(value != nil ? LiviqaTheme.moss : LiviqaTheme.ink4)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.lato(12, .semibold))
                        .foregroundStyle(LiviqaTheme.ink3)
                    if let v = value, !v.isEmpty {
                        Text(v)
                            .font(.lato(13))
                            .foregroundStyle(LiviqaTheme.ink)
                            .lineLimit(1)
                    } else {
                        Text(fallback)
                            .font(.lato(13))
                            .foregroundStyle(LiviqaTheme.ink4)
                            .italic()
                    }
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.lato(12))
                    .foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wellness summary row

    private func summaryRow(icon: String, label: String, value: String,
                            delta: String, deltaColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.lato(14))
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.lato(12.5))
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(delta)
                    .font(.lato(11.5))
                    .foregroundStyle(deltaColor)
            }
            Spacer()
            Text(value)
                .font(.liviqaMono(18))
                .monospacedDigit()
                .foregroundStyle(LiviqaTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    HealthPassportView()
        .environment(AppState())
}
