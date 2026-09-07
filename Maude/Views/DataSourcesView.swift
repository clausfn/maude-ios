// DataSourcesView.swift — Manage data sources (UC-14) · v02 2026-08-12
// A7.2 Area ⑦: rebuilt to the ScrDataSources canvas (b-integrations.jsx).
// Anatomy: verdict band → Connected → "You can add these too" → manual entry →
// Sundhed.dk (live rows when the flags are on; the amber lawful-basis gate card
// ONLY when the web-connect flag is off — the gate must never regress the live
// path) → disconnect → on-device strip → "See everything in one place".
//
// HONEST STATES: the Connected card lists only sources that are genuinely
// connected in this build (Apple Health via the real HealthKit deriver, the
// Sundhed.dk returning-user record, and the demo-seed rows in DEBUG). Manual
// entry is REAL — hand-typed readings land in HealthRecordStore tagged
// `.manual` ("Entered by you"), glucose in mmol/L (OD-07). The FR-PROV-02
// "Recorded twice — counted once" merge disclosure is a deliberate keep (in
// code, not in canvas). Provenance{REAL,SIMULATED,EXTERNAL} never renders.
import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
import UIKit
#endif

struct DataSourcesView: View {

    /// A source name fit to stand INSIDE A SENTENCE — nil when the name is a
    /// demo seed rather than a device. Design-QA 2026-08-13: mapping the
    /// fixture to "Sample data" was right for a chip and wrong in prose
    /// ("Kept Sample data for counting" read exactly like the fixture name it
    /// replaced). Sentences drop the clause; the demo label goes on the card's
    /// chip, where a label belongs.
    nonisolated static func deviceName(_ raw: String) -> String? {
        raw.caseInsensitiveCompare("Mock") == .orderedSame ? nil : raw
    }

    /// An enrichment field carries its own source suffix ("distance · Bike
    /// computer"). Same rule: the field survives, a demo source is dropped.
    nonisolated static func gainedField(_ raw: String) -> String {
        let parts = raw.components(separatedBy: " · ")
        guard parts.count > 1 else { return raw }
        let source = parts.dropFirst().joined(separator: " · ")
        guard let name = deviceName(source) else { return parts[0] }
        return "\(parts[0]) · \(name)"
    }

    /// One merge, said in English. Never names a source that isn't a device.
    nonisolated static func mergeSentence(_ m: WorkoutMerge) -> String {
        let merged = m.merged.compactMap(deviceName).joined(separator: ", ")
        var s: String
        switch (deviceName(m.kept), merged.isEmpty) {
        case (let kept?, false): s = String(localized: "Kept \(kept) for counting · merged \(merged)")
        case (let kept?, true):  s = String(localized: "Kept \(kept) for counting")
        case (nil, false):       s = String(localized: "Merged \(merged)")
        case (nil, true):        s = ""
        }
        let gained = m.enrichedFields.map(gainedField).joined(separator: ", ")
        if !gained.isEmpty {
            s += s.isEmpty ? String(localized: "Gained \(gained)")
                           : String(localized: " · gained \(gained)")
        }
        return s
    }

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var showBankSheet = false
    @State private var showCalendarSheet = false
    @State private var showVault = false
    @State private var showSundhedWeb = false        // live in-app MitID connect (Path A)
    @State private var showSundhedImport = false     // Path B — PDF/file export import
    @State private var showLabImport = false         // FR-REC-03 — any-lab PDF/photo import
    @State private var showDisconnectSheet = false
    @State private var manualKind: ManualReadingKind?
    @State private var connecting = false
    @State private var importedNote: String?
    @State private var showVaultImporter = false

    private var citizenId: String? {
        appState.profile?.alias ?? appState.session?.userId.uuidString
    }

    // MARK: - Calendar load (FR-CTX-CAL-01)
    //
    // A REAL connection state, read from two places that can both say no: the
    // citizen's opt-in record (`CalendarLoadStore`, account-scoped) and iOS's
    // own grant (`CalendarLoadIngestor.accessState()`). There is no literal
    // anywhere on this path — the 2026-08-13 incident was a Settings screen
    // printing "Connected" from a hard-coded string.

    /// The account scope the calendar numbers live under. Same accessor the
    /// journal uses, so one person's days can never open under another's
    /// account on a shared phone.
    private var calendarAccount: String? { appState.journalAccountID }

    @State private var calendarOptedIn = false
    @State private var calendarAccess: CalendarAccessState = .notDetermined
    @State private var calendarDays = 0

    /// A connect attempt that ended without a connection. Shown as an ALERT at
    /// the point of the tap — field report 10.103: the failure note used to
    /// render at the very bottom of this scroll view, below the fold, so a
    /// denied request read as "nothing happened".
    private struct CalendarConnectIssue: Identifiable {
        let id = UUID()
        let message: String
        let settingsCanFix: Bool
    }
    @State private var calendarIssue: CalendarConnectIssue?

    /// Connected means BOTH: the citizen said yes, and iOS still allows the
    /// read. Either one going away shows as not connected, truthfully.
    private var calendarConnected: Bool { calendarOptedIn && calendarAccess == .fullAccess }

    /// What the row says underneath its name — PURE + STATIC so the truth
    /// table is unit-testable (same discipline as `connectedSourceCount`).
    /// States the real situation, including the two awkward ones: opted in but
    /// iOS access withdrawn, and NOT opted in while iOS access is already
    /// switched off (the 10.103 stuck state — the row must say where the
    /// switch is before the citizen taps a button that cannot prompt).
    nonisolated static func calendarRowNote(optedIn: Bool,
                                            access: CalendarAccessState,
                                            daysRead: Int) -> String {
        if optedIn && access == .fullAccess {
            let days = daysRead == 1
                ? String(localized: "1 day read")
                : String(localized: "\(daysRead) days read")
            return String(localized: "How full your days are — \(days). Never what is in them.")
        }
        if optedIn {
            switch access {
            case .denied, .restricted:
                return String(localized: "You turned this on, but calendar access is off in iOS Settings, so nothing is being read.")
            case .writeOnly:
                return String(localized: "iOS is allowing Maude to add an event but not to read one, so nothing is being read.")
            default:
                return String(localized: "You turned this on, but iOS has not granted access, so nothing is being read.")
            }
        }
        switch access {
        case .denied:
            return String(localized: "iOS has calendar access switched off for Maude. Allow Full Access in iOS Settings, then connect here.")
        case .restricted:
            return String(localized: "Calendar access is restricted on this device — for example by Screen Time — so Maude cannot read how full your days are.")
        case .writeOnly:
            return String(localized: "iOS lets Maude add an event but not read one. Allow Full Access in iOS Settings, then connect here.")
        default:
            return String(localized: "Reads only how full your days are — never titles, people, places or notes")
        }
    }

    private var calendarNote: String {
        Self.calendarRowNote(optedIn: calendarOptedIn, access: calendarAccess, daysRead: calendarDays)
    }

    private func refreshCalendarState() {
        calendarAccess = CalendarLoadIngestor.accessState()
        let record = CalendarLoadStore.load(forAccount: calendarAccount)
        calendarOptedIn = record != nil
        calendarDays = record?.days.count ?? 0
    }

    /// The citizen has read what is collected and pressed the button. Only now
    /// is the opt-in written, and only then is iOS asked. Every outcome SPEAKS
    /// at the point of the tap (10.103: a pre-denied request shows no iOS
    /// prompt at all, so silence here read as a dead button).
    private func connectCalendar() async {
        let outcome = await CalendarLoadIngestor.connect(
            accountID: calendarAccount,
            request: { await CalendarLoadIngestor.requestFullAccess() },
            optIn: { CalendarLoadStore.optIn(forAccount: $0) },
            refresh: { account in
                await Task.detached(priority: .utility) {
                    _ = CalendarLoadIngestor.refresh(accountID: account)
                }.value
            },
            daysRead: { CalendarLoadStore.load(forAccount: $0)?.days.count ?? 0 })
        refreshCalendarState()
        switch outcome {
        case .connected(let days):
            importedNote = days > 0
                ? String(localized: "Calendar connected — Maude kept \(days) days of numbers, and nothing else.")
                : String(localized: "Calendar connected — nothing to read yet.")
        case .noAccount:
            calendarIssue = CalendarConnectIssue(message: CalendarLoadCopy.connectNoAccountLine,
                                                 settingsCanFix: false)
        case .optInFailed:
            calendarIssue = CalendarConnectIssue(message: CalendarLoadCopy.connectOptInFailedLine,
                                                 settingsCanFix: false)
        case .accessNotGranted(let state):
            calendarIssue = CalendarConnectIssue(
                message: CalendarLoadCopy.connectFailureLine(afterRequest: state),
                settingsCanFix: CalendarLoadCopy.settingsCanFix(state))
        }
    }

    /// The one place the app can send the citizen to flip the calendar switch
    /// iOS refuses to re-prompt on (verified: a denied request shows no
    /// dialog). Opens Maude's own page in the Settings app.
    private func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #endif
    }

    /// Revoking. Stops collection AND removes what was collected.
    private func disconnectCalendar() {
        CalendarLoadStore.disconnect(forAccount: calendarAccount)
        refreshCalendarState()
        importedNote = String(localized: "Calendar disconnected — nothing new will be read, and the numbers Maude had were deleted.")
    }

    /// The persisted Sundhed.dk returning-user record — the honest "connected"
    /// signal for the national-record row (read-only; the session owns writes).
    private var sundhedLast: (date: Date, labs: Int, conditions: Int, meds: Int)? {
        SundhedWebSessionView.lastPullSummary(citizenId: citizenId)
    }

    private func source(_ name: String) -> DataSourceConnection? {
        appState.connectedSources.first { $0.name == name }
    }

    /// Count of genuinely connected sources (mock vault/national rows excluded —
    /// the vault is a place, not a source; Sundhed connects via its own record).
    ///
    /// PURE + SHARED so the number can never differ from the number Settings
    /// prints on the row that pushes this screen (data-honesty incident
    /// 2026-08-13: Settings counted `connectedSources.filter(\.isConnected)`
    /// straight, which in a demo build counts the "Health Vault" seed row and
    /// misses a Sundhed.dk connection — "3 connected" on a screen that then
    /// said "Two sources connected"). Both call sites now call this.
    nonisolated static func connectedSourceCount(_ sources: [DataSourceConnection],
                                                 sundhedConnected: Bool) -> Int {
        let rows = sources.filter {
            $0.isConnected && $0.name != "Health Vault" && $0.name != "Sundhedsplatformen"
        }
        return rows.count + (sundhedConnected ? 1 : 0)
    }

    private var connectedCount: Int {
        Self.connectedSourceCount(appState.connectedSources, sundhedConnected: sundhedLast != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                verdictBand

                // FR-PROV-02 — the dedup disclosure (deliberate keep, not in canvas).
                if !appState.workoutMerges.isEmpty { mergeDisclosureCard }

                connectedCard
                addTheseCard
                manualEntryCard
                labImportCard
                sundhedSection
                disconnectCard
                onDeviceStrip
                vaultCard
                dataBrowserCard

                if let importedNote {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundStyle(MaudeTheme.moss)
                        Text(importedNote).font(.lato(12)).foregroundStyle(MaudeTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(MaudeTheme.paper)
        .navigationTitle("Data sources")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBankSheet) {
            OpenBankingSheet { bank in connect(named: "Bank account · Open Banking", detail: "\(bank) · daily totals & categories") }
        }
        .sheet(isPresented: $showCalendarSheet) {
            CalendarLoadSheet(connected: calendarConnected,
                              daysRead: calendarDays,
                              access: calendarAccess,
                              onConnect: { showCalendarSheet = false; Task { await connectCalendar() } },
                              onOpenSettings: { showCalendarSheet = false; openAppSettings() },
                              onDisconnect: { showCalendarSheet = false; disconnectCalendar() })
        }
        .sheet(isPresented: $showDisconnectSheet) { disconnectSheet }
        .sheet(item: $manualKind) { kind in
            ManualReadingSheet(kind: kind) { saved in
                importedNote = saved
            }
        }
        .task { refreshCalendarState() }
        // Coming back from iOS Settings (or anywhere): re-read both truths the
        // row is a conjunction of, so a switch flipped outside the app shows
        // here without a relaunch.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshCalendarState() }
        }
        // Every failed connect attempt speaks HERE, at the tap — never only in
        // a note below the fold (field report 10.103). When Settings is where
        // the answer lives, the alert takes the citizen there.
        .alert(String(localized: "Calendar not connected"),
               isPresented: Binding(get: { calendarIssue != nil },
                                    set: { if !$0 { calendarIssue = nil } }),
               presenting: calendarIssue) { issue in
            if issue.settingsCanFix {
                Button(String(localized: "Open iOS Settings")) { openAppSettings() }
            }
            Button(String(localized: "OK"), role: .cancel) {}
        } message: { issue in
            Text(issue.message)
        }
        .navigationDestination(isPresented: $showVault) { HealthVaultView() }
        .navigationDestination(isPresented: $showSundhedWeb) {
            // The single calm MitID prompt (Area ① satellite) fronts the real
            // linking use case — the session itself is untouched behind it.
            MitIDPromptView {
                SundhedWebSessionView(
                    ingest: appState.supabase as? SundhedIngesting,
                    citizenId: citizenId
                )
            }
        }
        .navigationDestination(isPresented: $showSundhedImport) { SundhedImportView() }
        .navigationDestination(isPresented: $showLabImport) { LabReportImportView() }
        .fileImporter(isPresented: $showVaultImporter,
                      allowedContentTypes: [.pdf, .image, .plainText, .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                importIntoVault(url)
            }
        }
        #endif
    }

    // MARK: - Verdict band (honest connected count)

    private var verdictBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "applewatch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MaudeTheme.accentRecovery)
                Text(String(localized: "What Maude reads — and from where").uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
            }
            Text(verdictText)
                .font(.maudeSerif(22)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            RoundedRectangle(cornerRadius: 2)
                .fill(MaudeTheme.accentRecovery)
                .frame(width: 44, height: 3)
        }
        .padding(.top, 4)
    }

    private var verdictText: String {
        let words = ["No", "One", "Two", "Three", "Four", "Five", "Six"]
        let n = connectedCount
        if n == 0 { return String(localized: "Nothing connected yet — Apple Health is one tap below.") }
        let count = n < words.count ? words[n] : "\(n)"
        return n == 1
            ? String(localized: "\(count) source connected, and you can add more.")
            : String(localized: "\(count) sources connected, and you can add more.")
    }

    // MARK: - Connected card

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker(String(localized: "Connected"))
            if connectedCount == 0 {
                Text("Nothing yet. Everything below is one tap away.")
                    .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
                    .padding(.vertical, 12)
            } else {
                if let ah = source("Apple Health"), ah.isConnected {
                    sourceRow(icon: "heart.fill", color: Color(hex: 0xFF3B30),
                              name: "Apple Health",
                              note: appleHealthNote(ah),
                              state: .live)
                }
                if let lp = sundhedLast {
                    Button { showSundhedWeb = true } label: {
                        sourceRow(icon: "cross.case.fill", color: Color(hex: 0x2992A5),
                                  name: "Sundhed.dk",
                                  note: String(localized: "\(lp.labs) labs · \(lp.conditions) diagnoses · \(lp.meds) medicines · updated \(lp.date.formatted(date: .abbreviated, time: .omitted))"),
                                  state: .live)
                    }
                    .buttonStyle(.plain)
                }
                if calendarConnected {
                    Button { showCalendarSheet = true } label: {
                        sourceRow(icon: "calendar", color: Color(hex: 0xCC3333),
                                  name: String(localized: "Your calendar"),
                                  note: calendarNote, state: .live)
                    }
                    .buttonStyle(.plain)
                }
                if let bank = source("Bank account · Open Banking"), bank.isConnected {
                    sourceRow(icon: "building.columns.fill", color: Color(hex: 0x1B2A4A),
                              name: String(localized: "Bank spending"), note: bank.dataDescription, state: .live)
                }
                if let st = source("Screen Time"), st.isConnected {
                    sourceRow(icon: "hourglass", color: Color(hex: 0x566472),
                              name: st.name, note: st.dataDescription, state: .live)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func appleHealthNote(_ ah: DataSourceConnection) -> String {
        if let sync = ah.lastSync {
            return String(localized: "Sleep, heart, activity · \(syncLabel(sync).lowercased())")
        }
        return String(localized: "Sleep, heart, activity")
    }

    // MARK: - "You can add these too"

    private var addTheseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker(String(localized: "You can add these too"))

            // Apple Health first when it isn't connected yet — the one real
            // one-tap deriver (appState.refreshFromHealth).
            if source("Apple Health")?.isConnected != true {
                Button { connectAppleHealth() } label: {
                    sourceRow(icon: "heart.fill", color: Color(hex: 0xFF3B30),
                              name: "Apple Health",
                              note: connecting
                                  ? String(localized: "Connecting…")
                                  : String(localized: "Sleep, heart, activity — one tap to connect"),
                              state: .off)
                }
                .buttonStyle(.plain)
                .disabled(connecting)
            }

            sourceRow(icon: "applewatch", color: MaudeTheme.accentRecovery,
                      name: String(localized: "Another watch or ring"),
                      note: String(localized: "Garmin, Withings, Oura, Fitbit — via Apple Health"),
                      state: .off)
            Button { manualKind = .weight } label: {
                sourceRow(icon: "scalemass.fill", color: MaudeTheme.accentHeart,
                          name: String(localized: "Bathroom scale"),
                          note: String(localized: "Yes, weight is a connection — a smart scale sends it in, or type it in yourself"),
                          state: .off)
            }
            .buttonStyle(.plain)
            sourceRow(icon: "waveform.path.ecg", color: MaudeTheme.accentHeart,
                      name: String(localized: "Blood-pressure cuff"),
                      note: String(localized: "Home cuffs that write to Apple Health"),
                      state: .off)
            // Opt-in, and the screen states what would be read BEFORE asking:
            // the button opens the sheet, the sheet lists the numbers and the
            // never-list, and only its own button reaches iOS's prompt.
            if !calendarConnected {
                Button { showCalendarSheet = true } label: {
                    sourceRow(icon: "calendar", color: Color(hex: 0xCC3333),
                              name: String(localized: "Your calendar"),
                              note: calendarNote,
                              state: calendarOptedIn ? .pending : .off)
                }
                .buttonStyle(.plain)
            }
            if source("Bank account · Open Banking")?.isConnected != true {
                Button { showBankSheet = true } label: {
                    sourceRow(icon: "building.columns.fill", color: Color(hex: 0x1B2A4A),
                              name: String(localized: "Bank spending"),
                              note: String(localized: "Yes, this means linking a bank account. Reads only how much and which category — never where you shopped. Optional, and rarely needed."),
                              state: .off)
                }
                .buttonStyle(.plain)
            }
            // Screen Time is NOT connectable and this row no longer pretends
            // it is. iOS exposes app/website usage only through DeviceActivity,
            // which requires Apple's Family Controls entitlement (an approval
            // Maude has not been granted); the report extension is sandboxed so
            // it cannot hand values back to the app in any case. The previous
            // row opened a sheet whose "Connect Screen Time" button reached a
            // seed array that does not exist in a shipping build — it changed
            // nothing and read nothing, while looking like a connection.
            // Full working: docs/ScreenTime_Feasibility_20260813.md.
            sourceRow(icon: "hourglass", color: Color(hex: 0x566472),
                      name: String(localized: "Screen Time"),
                      note: String(localized: "Not available. iOS only opens phone-use data to apps with Apple's Family Controls approval, which Maude doesn't have — so nothing is read."),
                      state: .off)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func connectAppleHealth() {
        Task {
            connecting = true
            appState.dataProviderKind = .healthKit
            await appState.refreshFromHealth()
            connecting = false
            importedNote = Self.connectResultNote(
                usingRealData: appState.usingRealData,
                outcome: appState.healthReadOutcome,
                isDemoData: appState.isDemoData)
        }
    }

    /// What to say after the one-tap connect — the OUTCOME, never a hopeful
    /// "Connected." (data-honesty incident 2026-08-13). Follows the
    /// `AppState.HealthReadOutcome` wording rule: HealthKit cannot report read
    /// authorisation, so an empty read is reported as an empty read and the two
    /// possible explanations are offered without accusing anyone of a denial.
    nonisolated static func connectResultNote(usingRealData: Bool,
                                              outcome: AppState.HealthReadOutcome,
                                              isDemoData: Bool) -> String {
        if usingRealData || outcome == .readings {
            return String(localized: "Synced — your Home now shows your own data.")
        }
        switch outcome {
        case .readings:
            return String(localized: "Synced — your Home now shows your own data.")
        case .noReadings:
            return isDemoData
                ? String(localized: "No readings came through yet — either there's nothing recorded on this phone for these types, or reading isn't allowed. Until some arrive you'll see sample data, clearly marked.")
                : String(localized: "No readings came through yet — either there's nothing recorded on this phone for these types, or reading isn't allowed. You can check in Health → Sharing → Apps → Maude.")
        case .failed:
            return String(localized: "Apple Health couldn't be read just now. Nothing has changed — you can try again.")
        case .notAttempted:
            return String(localized: "Apple Health isn't available on this device.")
        }
    }

    // MARK: - Manual entry (the path for people with no device)

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MaudeTheme.moss2)
                        .frame(width: 32, height: 32)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MaudeTheme.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Type readings in yourself")
                        .font(.lato(14, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text("No device needed")
                        .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                }
            }
            Text("Weight, blood pressure, a finger-prick glucose reading, or how you slept. Hand-typed values are marked as yours, so a nurse can tell them apart from a sensor.")
                .font(.lato(12.5)).lineSpacing(2.5)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            FlowRow(spacing: 7) {
                ForEach(ManualReadingKind.allCases) { kind in
                    Button { manualKind = kind } label: {
                        Text("+ \(kind.title)")
                            .font(.lato(12, .semibold))
                            .foregroundStyle(MaudeTheme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(MaudeTheme.ink.opacity(0.08)))
                            .overlay(Capsule().stroke(MaudeTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    // MARK: - Any-lab report import (FR-REC-03)

    /// Works with ANY lab's paperwork, not just Sundhed.dk: the file is read on
    /// this device (PDF text layer, or Vision text recognition for a photo) and
    /// every recognised result is reviewed before a single row is saved.
    private var labImportCard: some View {
        Button { showLabImport = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(MaudeTheme.moss2)
                            .frame(width: 32, height: 32)
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MaudeTheme.moss)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Import a lab report")
                            .font(.lato(14, .bold)).foregroundStyle(MaudeTheme.ink)
                        Text("Any lab · PDF or photo")
                            .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(MaudeTheme.ink4)
                }
                Text("Blood work from a private clinic, a hospital letter, a printout from abroad. Maude reads it on this phone, shows you every value it found — and what it couldn't read — and saves only what you approve, next to your own last result.")
                    .font(.lato(12.5)).lineSpacing(2.5)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sundhed.dk (live rows, or the lawful-basis gate when flagged off)

    @ViewBuilder
    private var sundhedSection: some View {
        if Config.sundhedWebConnectEnabled {
            VStack(alignment: .leading, spacing: 10) {
                Button { showSundhedWeb = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cross.case").font(.system(size: 14, weight: .medium))
                        Text(sundhedLast == nil ? "Connect Sundhed.dk" : "Update from Sundhed.dk")
                            .font(.lato(14, .bold))
                    }
                    .foregroundStyle(MaudeTheme.primaryLabel)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(MaudeTheme.primaryFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Path B stays alongside the live button, not instead of it —
                // labs (svaroversigt) + journal can't be pulled headless.
                if Config.sundhedConnectEnabled {
                    Button { showSundhedImport = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 14, weight: .medium))
                            Text("Import Sundhed.dk export (labs · journal)").font(.lato(14, .bold))
                        }
                        .foregroundStyle(MaudeTheme.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(MaudeTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Text("Sign in with MitID on this device — Maude never sees or stores your login. Only summaries and codes are read, and they stay on this phone.")
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
        } else {
            // The pending gate — the FLAG-OFF state only, never a regression of
            // the live path above.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MaudeTheme.brass)
                    Text("Sundhedsplatformen (national record)")
                        .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                }
                Text("Connecting your national health record needs a lawful-basis ruling that's still pending. When it clears, you'll sign in with MitID — on device — and it stays your choice.")
                    .font(.lato(12)).lineSpacing(2.5)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("AWAITING APPROVAL")
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.brass)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.brass2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.brass.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Disconnect

    private var disconnectCard: some View {
        Button { showDisconnectSheet = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disconnect a source")
                        .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text("Stops new readings immediately. What's already on your phone stays until you delete it.")
                        .font(.lato(12)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(MaudeTheme.ink4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Honest per-source disconnect: mock-connect rows flip off for real;
    /// Apple Health read access is controlled by iOS (we say so instead of
    /// faking a revoke); Sundhed.dk "forget" clears the returning-user record.
    private var disconnectSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Disconnecting stops new readings immediately. What's already on your phone stays until you delete it.")
                        .font(.lato(13)).lineSpacing(2.5)
                        .foregroundStyle(MaudeTheme.ink2)

                    if let ah = source("Apple Health"), ah.isConnected {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Health").font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                            Text("iOS holds this permission, not Maude. Turn it off in the Health app: Sharing → Apps → Maude.")
                                .font(.lato(12)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MaudeTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if sundhedLast != nil {
                        disconnectRow(name: "Sundhed.dk",
                                      sub: String(localized: "Forgets the connection. Imported labs, medicines and diagnoses stay on this phone until you delete them.")) {
                            SundhedWebSessionView.forgetConnection(citizenId: citizenId)
                            importedNote = String(localized: "Sundhed.dk disconnected — nothing new will be read.")
                            showDisconnectSheet = false
                        }
                    }

                    if calendarOptedIn {
                        disconnectRow(name: String(localized: "Your calendar"),
                                      sub: String(localized: "Stops reading, and deletes the day numbers Maude kept. Nothing in your calendar is touched.")) {
                            disconnectCalendar()
                            showDisconnectSheet = false
                        }
                    }

                    ForEach(["Bank account · Open Banking", "Screen Time"], id: \.self) { name in
                        if let row = source(name), row.isConnected {
                            disconnectRow(name: name, sub: row.dataDescription) {
                                disconnect(named: name)
                                showDisconnectSheet = false
                            }
                        }
                    }

                    if connectedCount == 0, !calendarOptedIn {
                        Text("Nothing is connected right now.")
                            .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
                    }
                }
                .padding(20)
            }
            .background(MaudeTheme.paper)
            .navigationTitle("Disconnect a source")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showDisconnectSheet = false }
                }
            }
        }
    }

    private func disconnectRow(name: String, sub: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                Text(sub).font(.lato(11.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: action) {
                Text("Disconnect")
                    .font(.lato(12.5, .bold)).foregroundStyle(MaudeTheme.rust)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(MaudeTheme.rust2))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func disconnect(named name: String) {
        guard let i = appState.connectedSources.firstIndex(where: { $0.name == name }) else { return }
        appState.connectedSources[i].isConnected = false
        appState.connectedSources[i].lastSync = nil
        importedNote = String(localized: "\(name) disconnected — nothing new will be read.")
    }

    // MARK: - On-device strip + vault card

    private var onDeviceStrip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13)).foregroundStyle(MaudeTheme.moss)
            Text("Every source reads on-device only. Maude keeps just what it needs to find your patterns.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// "Everything you measure" — the breadth layer's named consumer
    /// (FR-ING-19). Values only, never verdicts.
    private var dataBrowserCard: some View {
        NavigationLink { DataBrowserView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MaudeTheme.moss)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Everything you measure")
                        .font(.lato(14.5, .semibold)).foregroundStyle(MaudeTheme.ink)
                    Text("Every Apple Health type you've shared, with its own history")
                        .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(MaudeTheme.ink4)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var vaultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { showVault = true } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("See everything in one place")
                            .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.ink)
                        Text("Your health data space holds every reading, document and note kept on this phone — whatever it came from.")
                            .font(.lato(12)).lineSpacing(2)
                            .foregroundStyle(MaudeTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(MaudeTheme.ink4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Real import wiring (FR-ING-15): a file picked here lands in the
            // encrypted document store — not in a toast.
            Button { showVaultImporter = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc").font(.system(size: 12, weight: .medium))
                    Text("Add a document to it now").font(.lato(12.5, .bold))
                }
                .foregroundStyle(MaudeTheme.moss)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private func importIntoVault(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let store = try? HealthVaultStore(keyVault: .shared, userScope: LocalUserScope.current())
        else {
            importedNote = String(localized: "That file couldn't be read. Nothing was stored.")
            return
        }
        do {
            let meta = try store.add(name: url.lastPathComponent, data: data,
                                     source: String(localized: "Data sources"))
            importedNote = String(localized: "“\(meta.name)” encrypted into your health data space.")
        } catch {
            importedNote = String(localized: "The document couldn't be saved. Nothing was stored.")
        }
    }

    // MARK: - Row anatomy (34pt solid icon square + status dot)

    private enum RowState { case live, pending, off }

    private func sourceRow(icon: String, color: Color, name: String, note: String,
                           state: RowState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.lato(14, .semibold)).foregroundStyle(MaudeTheme.ink)
                Text(note)
                    .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            statusBadge(state)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusBadge(_ state: RowState) -> some View {
        switch state {
        case .live:
            HStack(spacing: 5) {
                Circle().fill(MaudeTheme.moss).frame(width: 6, height: 6)
                Text("Connected").font(.lato(11.5, .bold)).foregroundStyle(MaudeTheme.moss)
            }
        case .pending:
            HStack(spacing: 5) {
                Circle().fill(MaudeTheme.brass).frame(width: 6, height: 6)
                Text("Pending").font(.lato(11.5, .bold)).foregroundStyle(MaudeTheme.brass)
            }
        case .off:
            HStack(spacing: 5) {
                Circle().stroke(MaudeTheme.ink4, lineWidth: 1.5).frame(width: 6, height: 6)
                Text("Not connected").font(.lato(11.5, .bold)).foregroundStyle(MaudeTheme.ink4)
            }
        }
    }

    private func kicker(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.maudeKicker(10)).tracking(1.2)
            .foregroundStyle(MaudeTheme.ink3)
            .padding(.top, 8).padding(.bottom, 2)
    }

    // MARK: - Sync label

    private func syncLabel(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 120 { return String(localized: "Synced just now") }

        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return String(localized: "Synced today at \(df.string(from: date))")
        }
        if cal.isDateInYesterday(date) { return String(localized: "Synced yesterday") }

        let days = Int(seconds / 86400)
        if days < 7 { return String(localized: "Synced \(days) days ago") }

        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return String(localized: "Synced \(df.string(from: date))")
    }

    private func connect(named name: String, detail: String?) {
        guard let i = appState.connectedSources.firstIndex(where: { $0.name == name }) else { return }
        appState.connectedSources[i].isConnected = true
        appState.connectedSources[i].lastSync = Date()
        if let detail { appState.connectedSources[i].dataDescription = detail }
    }
}

// MARK: - Manual reading entry (HealthRecordStore.ingest, source: .manual)

enum ManualReadingKind: String, CaseIterable, Identifiable {
    case weight, bloodPressure, glucose, sleep, note
    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight:        return String(localized: "Weight")
        case .bloodPressure: return String(localized: "Blood pressure")
        case .glucose:       return String(localized: "Glucose")
        case .sleep:         return String(localized: "Sleep")
        case .note:          return String(localized: "A note")
        }
    }
}

/// One small honest form per chip. Readings land in the canonical on-device
/// record via the same `ingest()` every source uses, tagged `.manual` — the
/// user-facing label is "Entered by you" (the hidden Provenance enum is not
/// this and never renders). Glucose is mmol/L (OD-07). "A note" files a
/// journal entry instead (notes are prose, not observations).
struct ManualReadingSheet: View {
    let kind: ManualReadingKind
    var onSaved: (String) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var primary = ""     // value (or systolic for BP)
    @State private var secondary = ""   // diastolic for BP
    @State private var noteText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    fields
                    Text("Saved readings are marked “Entered by you”, so a nurse can tell them apart from a sensor. They stay on this device.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { save() } label: {
                        Text("Save")
                            .font(.lato(15, .bold))
                            .foregroundStyle(canSave ? MaudeTheme.primaryLabel : MaudeTheme.primaryOffLabel)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(canSave ? MaudeTheme.primaryFill : MaudeTheme.primaryOffFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(MaudeTheme.paper)
            .navigationTitle(kind.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch kind {
        case .weight:
            valueField("Weight", unit: "kg", text: $primary)
        case .bloodPressure:
            valueField("Systolic (top number)", unit: "mmHg", text: $primary)
            valueField("Diastolic (bottom number)", unit: "mmHg", text: $secondary)
        case .glucose:
            valueField("Glucose", unit: "mmol/L", text: $primary)
            Text("Finger-prick readings are in mmol/L — the number your meter shows.")
                .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
        case .sleep:
            valueField("Hours slept last night", unit: "h", text: $primary)
        case .note:
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR NOTE").font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                TextEditor(text: $noteText)
                    .font(.lato(14))
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line, lineWidth: 1))
            }
        }
    }

    private func valueField(_ label: String, unit: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.maudeKicker(10)).tracking(1.2)
                .foregroundStyle(MaudeTheme.ink3)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .font(.maudeMono(18))
                    .foregroundStyle(MaudeTheme.ink)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(unit).font(.lato(13, .semibold)).foregroundStyle(MaudeTheme.ink3)
            }
            .padding(12)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line, lineWidth: 1))
        }
    }

    private func number(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        switch kind {
        case .weight:        return number(primary).map { (20...350).contains($0) } ?? false
        case .bloodPressure: return (number(primary).map { (60...260).contains($0) } ?? false)
                                 && (number(secondary).map { (30...200).contains($0) } ?? false)
        case .glucose:       return number(primary).map { (1...35).contains($0) } ?? false
        case .sleep:         return number(primary).map { (0...24).contains($0) } ?? false
        case .note:          return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        guard canSave else { return }
        let now = Date()
        var observations: [HealthObservation] = []

        switch kind {
        case .weight:
            observations = [HealthObservation(scopeKey: "weight", value: number(primary)!,
                                              unit: "kg", effectiveDate: now,
                                              source: HealthDataSource.manual.rawValue)]
        case .bloodPressure:
            observations = [
                HealthObservation(scopeKey: "systolic_bp", value: number(primary)!,
                                  unit: "mmHg", effectiveDate: now,
                                  source: HealthDataSource.manual.rawValue),
                HealthObservation(scopeKey: "diastolic_bp", value: number(secondary)!,
                                  unit: "mmHg", effectiveDate: now,
                                  source: HealthDataSource.manual.rawValue),
            ]
        case .glucose:
            // OD-07: canonical glucose unit is mmol/L — entered and stored as such.
            observations = [HealthObservation(scopeKey: "glucose", value: number(primary)!,
                                              unit: "mmol/L", effectiveDate: now,
                                              source: HealthDataSource.manual.rawValue)]
        case .sleep:
            observations = [HealthObservation(scopeKey: "sleep_hours", value: number(primary)!,
                                              unit: "h", effectiveDate: now,
                                              source: HealthDataSource.manual.rawValue)]
        case .note:
            // FR-JRNL-SCOPE-01: read the SIGNED-IN account's journal, prepend,
            // write it back. (It used to save `appState.journalEntries` — an
            // in-memory list nothing ever loaded into — which overwrote the whole
            // file with this one note.)
            guard let account = appState.journalAccountID else {
                dismiss()
                onSaved(String(localized: "Your note couldn't be saved — you're not signed in."))
                return
            }
            let entry = JournalEntry(body: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
            var entries = JournalStore.openForAccount(account)
            entries.insert(entry, at: 0)
            JournalStore.save(entries, forAccount: account)
            appState.journalEntries = entries
            dismiss()
            onSaved(String(localized: "Note saved to your journal — on this device."))
            return
        }

        guard let store = appState.healthStore else {
            dismiss()
            onSaved(String(localized: "The reading couldn't be saved to this device. Please try again."))
            return
        }
        do {
            try store.ingest(observations: observations, conditions: [], medications: [],
                             source: .manual)
            appState.reloadHealthRecord()
            dismiss()
            onSaved(String(localized: "\(kind.title) saved — marked as entered by you."))
        } catch {
            dismiss()
            onSaved(String(localized: "The reading couldn't be saved to this device. Nothing was stored."))
        }
    }
}

// The manual-entry chips wrap with the shared FlowRow layout
// (EvidenceComponents.swift).

// MARK: - Preview

#Preview {
    NavigationStack {
        DataSourcesView()
            .environment(AppState())
    }
}

// FR-PROV-02 — tell the citizen, don't silently fix. One physical session
// recorded by two trackers is counted ONCE; the richer fields of each
// recording are kept (the watch's energy, the bike computer's distance).
extension DataSourcesView {
    var mergeDisclosureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.lato(15))
                    .foregroundStyle(MaudeTheme.moss)
                Text("Recorded twice — counted once")
                    .font(.lato(14, .bold))
                    .foregroundStyle(MaudeTheme.ink)
                Spacer(minLength: 6)
                // The demo label lives HERE — a chip, not a stand-in device
                // name in the sentence below.
                if appState.isDemoData {
                    Text(String(localized: "Sample data").uppercased())
                        .font(.maudeKicker(9)).tracking(0.8)
                        .foregroundStyle(MaudeTheme.clayText)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(MaudeTheme.clay2))
                        .fixedSize()
                }
            }
            ForEach(Array(appState.workoutMerges.prefix(3).enumerated()), id: \.offset) { _, m in
                let sentence = Self.mergeSentence(m)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(m.type) · \(m.start.formatted(date: .abbreviated, time: .shortened))")
                        .font(.lato(13))
                        .foregroundStyle(MaudeTheme.ink)
                    if !sentence.isEmpty {
                        Text(verbatim: sentence)
                            .font(.lato(12))
                            .foregroundStyle(MaudeTheme.ink2)
                    }
                }
            }
            Text("Two trackers logged the same session. Maude counts it once so minutes and energy are never doubled — and keeps the best of both recordings for insights.")
                .font(.caption)
                .lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MaudeTheme.moss.opacity(0.4), lineWidth: 0.5))
    }
}

// MARK: - Calendar load connect sheet (FR-CTX-CAL-01)

/// States what will be read BEFORE anything is asked for. iOS's own permission
/// prompt is reached only by the button at the bottom of this screen, so nobody
/// meets the system dialog without having first seen the two lists below.
///
/// Both lists come from `CalendarLoadCopy`, which is the same source the
/// `Info.plist` promise and `CalendarLoadPrivacyTests` check against — the
/// screen, the system prompt and the code cannot drift apart silently.
struct CalendarLoadSheet: View {
    let connected: Bool
    let daysRead: Int
    /// What iOS currently allows. The sheet's button must say the truth about
    /// what tapping it will DO: with access already denied, iOS shows no
    /// prompt at all (verified on-simulator 2026-08-19), so the only honest
    /// button is the one that opens Settings.
    let access: CalendarAccessState
    var onConnect: () -> Void
    var onOpenSettings: () -> Void
    var onDisconnect: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// True when iOS will not show a permission prompt for this app again and
    /// the switch really is on Maude's page in iOS Settings. (`restricted` is
    /// NOT here: a Screen Time restriction never appears on that page, so a
    /// Settings button would promise a fix the page cannot deliver.)
    private var settingsIsTheOnlyPath: Bool {
        access == .denied
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text(CalendarLoadCopy.promise)
                        .font(.maudeSerif(19)).lineSpacing(3)
                        .foregroundStyle(MaudeTheme.ink)

                    Text("A full week and a quiet week look different in your body. Maude can put how full your days were next to your own sleep, heart and glucose — as two facts side by side. It never says one caused the other.")
                        .font(.lato(13.5)).lineSpacing(3)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)

                    list(title: String(localized: "What Maude keeps"),
                         items: CalendarLoadCopy.readsList,
                         symbol: "checkmark",
                         tint: MaudeTheme.moss,
                         background: MaudeTheme.moss2)

                    list(title: String(localized: "What Maude never reads"),
                         items: CalendarLoadCopy.neverList,
                         symbol: "xmark",
                         tint: MaudeTheme.rust,
                         background: MaudeTheme.rust2)

                    Text("Maude can't even offer you a list of your calendars to choose from, because it would have to read their names to show it. Everything is worked out on this phone and stays on it — there is no upload path for any of it.")
                        .font(.lato(12)).lineSpacing(2.5)
                        .foregroundStyle(MaudeTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)

                    if connected {
                        let days = daysRead == 1
                            ? String(localized: "1 day")
                            : String(localized: "\(daysRead) days")
                        Text("Connected. Maude is holding \(days) of numbers. Turning this off stops the reading and deletes those numbers — your calendar itself is never touched.")
                            .font(.lato(12.5)).lineSpacing(2.5)
                            .foregroundStyle(MaudeTheme.ink2)
                        Button(action: onDisconnect) {
                            Text("Turn off and delete the numbers")
                                .font(.lato(15, .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(MaudeTheme.rust2)
                                .foregroundStyle(MaudeTheme.rust)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else if settingsIsTheOnlyPath {
                        // iOS will not prompt again for this app, so a button
                        // that promises "iOS asks next" would be a lie. The
                        // honest button goes where the switch actually is.
                        Button(action: onOpenSettings) {
                            Text("Allow Full Access in iOS Settings")
                                .font(.lato(15, .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(MaudeTheme.moss)
                                .foregroundStyle(MaudeTheme.invertBG)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        Text("iOS has calendar access switched off for Maude, so it cannot ask you again here. Allow Full Access in iOS Settings, then come back and connect.")
                            .font(.lato(11.5))
                            .foregroundStyle(MaudeTheme.ink4)
                    } else if access == .restricted {
                        // No button at all: nothing a tap could do here would
                        // work, and an honest sheet says so instead.
                        Text("Calendar access is restricted on this device — for example by Screen Time — so iOS will not show Maude's request, and Maude cannot connect. Nothing has been read.")
                            .font(.lato(12.5)).lineSpacing(2.5)
                            .foregroundStyle(MaudeTheme.ink2)
                    } else {
                        Button(action: onConnect) {
                            Text("Read how full my days are")
                                .font(.lato(15, .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(MaudeTheme.moss)
                                .foregroundStyle(MaudeTheme.invertBG)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        Text(access == .writeOnly
                             ? String(localized: "iOS currently lets Maude add an event but not read one. It will ask whether to allow Full Access next.")
                             : String(localized: "iOS asks next. You can change your mind here or in iOS Settings at any time."))
                            .font(.lato(11.5))
                            .foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .padding(20)
            }
            .background(MaudeTheme.paper)
            .navigationTitle("Your calendar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func list(title: String, items: [String], symbol: String,
                      tint: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.maudeKicker(9)).tracking(1.1)
                .foregroundStyle(MaudeTheme.ink3)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(.top, 2)
                    Text(item)
                        .font(.lato(12.5)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
