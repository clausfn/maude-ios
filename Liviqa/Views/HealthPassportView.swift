// HealthPassportView.swift — Lifetime personal data record · v02 2026-05-22
// v02: Added "About you" section (declared HealthContext) with Edit → ProfileSheet.
import SwiftUI

struct HealthPassportView: View {
    @Environment(AppState.self) private var appState
    @State private var showConsentLedger = false
    @State private var showDataSources   = false
    @State private var showProfile       = false
    @State private var profileAnchor: ProfileSheet.Section? = nil
    @State private var selectedMetric: BaselineMetric? = nil
    @State private var shareItem: HealthShareItem? = nil
    @State private var isContributing = false
    @State private var researchNote: String? = nil

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

                        // ── YOUR HEALTH RECORD (imported, source-agnostic) ──
                        healthRecordSection

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
                                deltaColor: LiviqaTheme.moss,
                                baseline: BaselineMetric(
                                    name: "Sleep", short: "Sleep", value: 7.1, unit: "h",
                                    normalLow: 6.6, normalHigh: 7.8,
                                    warm: "Right in your range — and steadier than your last 30 days. Nice.")
                            )
                            Divider()
                                .background(LiviqaTheme.line2)
                            summaryRow(
                                icon: "waveform.path.ecg",
                                label: "Resting HRV",
                                value: "42 ms",
                                delta: "▼ 8 ms vs last month",
                                deltaColor: LiviqaTheme.rust,
                                baseline: BaselineMetric(
                                    name: "Heart-rate variability", short: "HRV", value: 42, unit: "ms",
                                    normalLow: 38, normalHigh: 54,
                                    warm: "A calm day for you — recovery's been trending up across the week.")
                            )
                        }
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
                        .sheet(item: $selectedMetric) { m in
                            MetricBaselineView(metric: m)
                            #if os(iOS)
                                .presentationDragIndicator(.visible)
                            #endif
                        }

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
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(items: [item.text])
                .presentationDetents([.medium, .large])
        }
        #endif
        .onAppear { appState.reloadHealthRecord() }
    }

    // MARK: - Health record (Task 3: display · Task 4: share + research)

    private var healthRecordSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            let labs = appState.healthObservations
            let conds = appState.healthConditions
            let meds = appState.healthMedications
            let isEmpty = labs.isEmpty && conds.isEmpty && meds.isEmpty

            if isEmpty {
                LiviqaSectionHeader(label: "Health record")
                recordEmptyState
            } else {
                // Lab results
                LiviqaSectionHeader(label: "Lab results")
                recordCard {
                    ForEach(Array(labs.enumerated()), id: \.element.persistentModelID) { i, o in
                        if i > 0 { Divider().background(LiviqaTheme.line2).padding(.leading, 14) }
                        labRow(o)
                    }
                }

                // Diagnoses
                if !conds.isEmpty {
                    LiviqaSectionHeader(label: "Diagnoses")
                    recordCard {
                        ForEach(Array(conds.enumerated()), id: \.element.persistentModelID) { i, c in
                            if i > 0 { Divider().background(LiviqaTheme.line2).padding(.leading, 14) }
                            diagnosisRow(c)
                        }
                    }
                }

                // Medicine
                if !meds.isEmpty {
                    LiviqaSectionHeader(label: "Medicine")
                    recordCard {
                        ForEach(Array(meds.enumerated()), id: \.element.persistentModelID) { i, m in
                            if i > 0 { Divider().background(LiviqaTheme.line2).padding(.leading, 14) }
                            medRow(m)
                        }
                    }
                }

                // Consented exits — the ONLY ways data leaves the device.
                recordActions
            }
        }
    }

    /// Friendly empty state.
    private var recordEmptyState: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .font(.lato(15)).foregroundStyle(LiviqaTheme.ink4)
            Text("Connect a source to import your labs and diagnoses. Everything you bring in stays on this device until you choose to share it.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func recordCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
            .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    private func labRow(_ o: HealthObservation) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HealthDisplay.labName(for: o.scopeKey))
                    .font(.lato(13.5, .semibold)).foregroundStyle(LiviqaTheme.ink)
                Text(o.effectiveDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4)
            }
            Spacer()
            sourceChip(o.source)
            Text("\(HealthDisplay.number(o.value)) \(o.unit)")
                .font(.liviqaMono(15)).monospacedDigit()
                .foregroundStyle(LiviqaTheme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func diagnosisRow(_ c: HealthCondition) -> some View {
        // Name leads (plain language), the code + start year are the small print —
        // a citizen reads "Type 1 diabetes with nerve complications · since 2019",
        // not a bare "DE104".
        let name = (c.label?.isEmpty == false) ? c.label! : HealthDisplay.conditionName(for: c.icd10)
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.lato(13.5, .semibold)).foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(c.icd10)
                        .font(.liviqaMono(10.5)).foregroundStyle(LiviqaTheme.ink3)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(LiviqaTheme.clay2).clipShape(Capsule())
                    if let d = c.onsetDate {
                        Text("since \(String(Calendar.current.component(.year, from: d)))")
                            .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
            }
            Spacer()
            sourceChip(c.source)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func medRow(_ m: HealthMedication) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name).font(.lato(13.5, .semibold)).foregroundStyle(LiviqaTheme.ink).lineLimit(1)
                if let atc = m.atc, !atc.isEmpty {
                    Text(atc).font(.lato(11, .medium)).foregroundStyle(LiviqaTheme.moss)
                }
            }
            Spacer()
            sourceChip(m.source)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Small source-provenance chip (which source filed the row). Uses the friendly
    /// HealthDataSource label — never the hidden arbitration field.
    private func sourceChip(_ rawSource: String) -> some View {
        Text((HealthDataSource(rawValue: rawSource)?.displayLabel ?? rawSource).uppercased())
            .font(.liviqaKicker(8.5)).tracking(0.5)
            .foregroundStyle(LiviqaTheme.moss)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(LiviqaTheme.moss3).clipShape(Capsule())
    }

    /// The two explicit, consented exits (share + research). Both are user taps.
    private var recordActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                shareItem = HealthShareItem(text: appState.healthStore?.summaryReport() ?? "")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                    Text("Share health summary").font(.lato(14, .bold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                guard !isContributing else { return }
                isContributing = true
                researchNote = nil
                Task {
                    await appState.contributeHealthResearch()
                    isContributing = false
                    researchNote = appState.researchContributed
                        ? "Thanks — your coded, privacy-preserving summary was contributed to research."
                        : (appState.lastError ?? "Couldn't contribute right now. Please try again.")
                }
            } label: {
                HStack(spacing: 8) {
                    if isContributing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "heart.text.square").font(.system(size: 14)) }
                    Text(isContributing ? "Contributing…" : "Contribute to research")
                        .font(.lato(14, .bold))
                    Spacer()
                }
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isContributing)

            if let researchNote {
                Text(researchNote)
                    .font(.lato(12)).lineSpacing(2)
                    .foregroundStyle(appState.researchContributed ? LiviqaTheme.moss : LiviqaTheme.rust)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Nothing here leaves your phone unless you tap one of these. Sharing sends a readable summary you choose; contributing sends only coded, privacy-preserving numbers.")
                .font(.lato(11)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
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
                        .foregroundStyle(LiviqaTheme.clay)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LiviqaTheme.clay2)
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
                              : tir >= 60 ? LiviqaTheme.clay
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
                            delta: String, deltaColor: Color,
                            baseline: BaselineMetric? = nil) -> some View {
        Button {
            if let baseline { selectedMetric = baseline }
        } label: {
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
                if baseline != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.ink4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(baseline == nil)
    }
}

// MARK: - Share payload

/// Identifiable wrapper so the one-page text report can drive `.sheet(item:)`.
struct HealthShareItem: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - Preview

#Preview {
    HealthPassportView()
        .environment(AppState())
}
