// SettingsView.swift — Profile · Consent · Regulatory v03 · 2026-08-12
// Three zones: My Data (profile + connected sources) / Consent & Sharing (audit trail)
// / Regulatory (disclaimer, privacy policy, delete). This is the trust layer.
// v03 (A7.2 Area ⑧): Account & security nav row added (pushes the new
// AccountSecurityView); the inline 3-step delete card is replaced by a nav row
// to the dedicated DeleteDataView (server-first failure state preserved there);
// "Nudge Settings" renamed "Notifications" (edition ladder); the MDR notice is
// single-sourced from RegulatoryCopy (FR-REG-01 — the two divergent wordings
// are gone).
import SwiftUI
import LocalAuthentication
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    // GDPR Art. 20 export (T1): GET /me/export → share sheet with the JSON.
    @State private var isExporting = false
    @State private var exportFile: ExportFile?
    @State private var exportFailed = false

    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    // Runtime display options (drive the locked design tokens at the root).
    // Default MUST match MaudeApp's default (Paper) or the picker shows the wrong
    // selection on a fresh install.
    @AppStorage("maudeThemeMode")    private var themeModeRaw = MaudeTheme.Mode.paper.rawValue
    @AppStorage("maudeReduceMotion") private var reduceMotion = false
    @AppStorage("liquidGlass")        private var liquidGlass = true
    @AppStorage("clinicalTIRZones")   private var clinicalTIRZones = true
    @AppStorage("gradedHeatmap")      private var gradedHeatmap = true
    @AppStorage("visualNudge")        private var visualNudge = true
    @AppStorage("crossSourceCards")   private var crossSourceCards = false
    @AppStorage("maude.appLanguage") private var appLanguage = "system"
    // Face ID app lock (NFR-SEC) — runtime overlay wired in MaudeApp.
    @AppStorage("appLockEnabled")     private var appLockEnabled = false
    @State private var appLockNote: String? = nil

    /// The health data space's real state, read with the SAME call the vault
    /// screen makes (`HealthVaultSession.open`) — so the count on this row is
    /// the count that screen lists. nil access ⇒ not opened yet ⇒ "Checking…",
    /// never a number.
    /// FR-SMP-05 — the sample-mode card's in-flight state (the synthetic record
    /// is built off the main actor, so the button says what it is doing).
    @State private var enteringSample = false
    @State private var confirmLeaveSample = false

    @State private var vaultAccess: VaultAccess?
    @State private var vaultDocumentCount = 0

    // Navigation destinations
    @State private var showDataSources    = false
    @State private var showVault          = false
    @State private var showHealthPassport = false
    @State private var showSundhedImport  = false
    @State private var showConsentLedger  = false
    @State private var showNudgeSettings  = false
    @State private var showPrivacy        = false
    @State private var showShare          = false
    @State private var showAccount        = false
    @State private var showDelete         = false
    @State private var showDonorExport    = false
    /// FR-CTX-04 — review/clear the user's own context flags.
    @State private var showContextFlags   = false
    /// FR-DIAG-01 — the sleep diagnostics instrument (sleep incident 2026-08).
    @State private var showSleepDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                displaySection
                myDataSection
                consentSection
                // Donor programme (DON-2026-01). `isDonorBuild` is a
                // compile-time false in every shipped binary, so no citizen
                // sees this row and nothing about their app changes.
                if DonationProgramme.isDonorBuild { donorSection }
                regulatorySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
        .maudeScrollEdge()       // same edge treatment as the reading surfaces
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: $showDataSources)    { DataSourcesView() }
        .navigationDestination(isPresented: $showVault)          { HealthVaultView() }
        .navigationDestination(isPresented: $showHealthPassport) { HealthPassportView() }
        .navigationDestination(isPresented: $showSundhedImport)  {
            // A7.2: one calm MitID prompt fronts the real linking session
            // (FR-ING-11 anatomy — the check happens with the official provider).
            MitIDPromptView(onCancel: { showSundhedImport = false }) {
                SundhedWebSessionView(
                    ingest: appState.supabase as? SundhedIngesting,
                    citizenId: appState.profile?.alias ?? appState.session?.userId.uuidString
                )
            }
        }
        .navigationDestination(isPresented: $showConsentLedger)  { ConsentLedgerView() }
        .navigationDestination(isPresented: $showNudgeSettings)  { NotificationSettingsView() }
        .navigationDestination(isPresented: $showPrivacy)        { InAppPrivacyView() }
        .navigationDestination(isPresented: $showAccount)        { AccountSecurityView() }
        .navigationDestination(isPresented: $showDelete)         { DeleteDataView() }
        .navigationDestination(isPresented: $showDonorExport)    { DonorExportView() }
        .sheet(isPresented: $showShare) {
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
        // FR-CTX-04 — review / end the days marked as travelling, unwell or
        // off-routine (same surface as the Today entry affordance).
        .sheet(isPresented: $showContextFlags) { ContextFlagSheet() }
        // FR-DIAG-01 — on-device sleep report, share-sheet export only.
        .sheet(isPresented: $showSleepDiagnostics) { SleepDiagnosticsView() }
        // The vault row's count is read here and re-read on the way back from
        // the vault, so adding or deleting a document there is reflected here.
        .task { readVaultState() }
        .onChange(of: showVault) { _, pushed in if !pushed { readVaultState() } }
        // Data sources can add a document to the same space — re-read on return
        // so this row never lags behind the store it reports on.
        .onChange(of: showDataSources) { _, pushed in if !pushed { readVaultState() } }
        #if DEBUG
        // Snapshot hooks (A7.2 Area ⑧): with MAUDE_TAB=settings —
        // MAUDE_OPEN_ACCOUNT=1 → Account & security; MAUDE_OPEN_NOTIFS=1 →
        // Notifications; MAUDE_OPEN_DELETE=1 → Delete all my data.
        .task {
            let env = ProcessInfo.processInfo.environment
            if env["MAUDE_OPEN_ACCOUNT"] == "1" { showAccount = true }
            if env["MAUDE_OPEN_NOTIFS"]  == "1" { showNudgeSettings = true }
            if env["MAUDE_OPEN_DELETE"]  == "1" { showDelete = true }
        }
        #endif
    }

    // MARK: — Zone 0: Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("DISPLAY", icon: "paintbrush")

            VStack(spacing: 14) {
                // Theme — Midnight (default) / Paper
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Theme")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Spacer()
                    }
                    Picker("Theme", selection: $themeModeRaw) {
                        Text("Midnight").tag(MaudeTheme.Mode.midnight.rawValue)
                        Text("Paper").tag(MaudeTheme.Mode.paper.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Divider().overlay(MaudeTheme.line2)

                // Language — the real iOS per-app-language rail (AppleLanguages
                // override; applies on next launch). Honest per-language status:
                // English complete; the rest have approved terminology in
                // Weblate with full interface translation to follow.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Language")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Spacer()
                        Picker("Language", selection: $appLanguage) {
                            Text("System").tag("system")
                            Text("English").tag("en")
                            Text("Dansk").tag("da")
                            Text("Norsk").tag("nb")
                            Text("Svenska").tag("sv")
                            Text("Español").tag("es")
                            Text("Português").tag("pt")
                        }
                        .tint(MaudeTheme.ink2)
                    }
                    Text(appLanguage == "system"
                         ? "Follows your iPhone language."
                         : "Applies at next launch. Terminology approved in all six languages; interface translation rolling out.")
                        .font(.caption).foregroundStyle(MaudeTheme.ink4)
                }
                .onChange(of: appLanguage) { _, lang in
                    if lang == "system" {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
                    }
                }

                Divider().overlay(MaudeTheme.line2)

                Toggle(isOn: $reduceMotion) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reduce motion")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Text("Skip ring draw-in and chart animations")
                            .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .tint(MaudeTheme.moss)

                Divider().overlay(MaudeTheme.line2)

                Toggle(isOn: $liquidGlass) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Liquid Glass")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Text("Translucent chrome on iPhones running iOS 26")
                            .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .tint(MaudeTheme.moss)

                Divider().overlay(MaudeTheme.line2)

                Toggle(isOn: $clinicalTIRZones) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clinical glucose zones")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Text("Red / amber / green time-in-range bands on the glucose chart")
                            .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .tint(MaudeTheme.moss)

                Divider().overlay(MaudeTheme.line2)

                Toggle(isOn: $gradedHeatmap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Graded heatmap")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Text("Shade each day by how far it is from your usual (Insights)")
                            .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .tint(MaudeTheme.moss)

                Divider().overlay(MaudeTheme.line2)

                Toggle(isOn: $visualNudge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nudge domain icons")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Text("Show a category icon on each insight on Home")
                            .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .tint(MaudeTheme.moss)

                Divider().overlay(MaudeTheme.line2)

                Toggle(isOn: $crossSourceCards) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cross-source patterns")
                            .font(.footnote).foregroundStyle(MaudeTheme.ink)
                        Text("Show health × spending × lab correlation cards on Insights")
                            .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .tint(MaudeTheme.moss)

                // The "Demo data chip" toggle that used to sit here is GONE, on
                // purpose. It let a person switch the label off and then forget,
                // leaving synthetic values on screen with nothing marking them —
                // and it defaulted to OFF. Labelling is no longer a preference:
                // sample mode labels itself (SampleModeBanner, FR-SMP-03), and
                // the way in and out is the card in My data below.
            }
            .padding(14)
            .background(MaudeTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
        }
    }

    // MARK: — Sample data (FR-SMP-05)

    /// The way in and the way out, in one card, stating plainly what sample
    /// mode is and what it does NOT do. Deliberately not a Toggle: entering
    /// replaces every figure on screen, which is a decision, not a display
    /// preference — and the preference-shaped control is exactly what the app
    /// got wrong before (see the note where the demo chip toggle used to be).
    private var sampleDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(appState.isSampleMode ? MaudeTheme.clay : MaudeTheme.fjordBright)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.isSampleMode
                         ? String(localized: "Sample data is on")
                         : String(localized: "Sample data"))
                        .font(.lato(14, .bold)).foregroundStyle(MaudeTheme.ink)
                    Text(appState.isSampleMode
                         ? String(localized: "Every figure on screen right now is made up.")
                         : String(localized: "Try Maude on a made-up person's month."))
                        .font(.caption).foregroundStyle(MaudeTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
            }

            Text(appState.isSampleMode
                 ? String(localized: "Your own data is untouched and waiting. Nothing from the sample has been saved — it only ever existed on screen.")
                 : String(localized: "A synthetic record — a watch, a sensor and a scale belonging to nobody — so you can see what the app does before you have two weeks of your own. It is never saved, never mixed with your readings, and every screen stays marked while it is on."))
                .font(.caption)
                .lineSpacing(2.5)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            if appState.isSampleMode {
                Button { confirmLeaveSample = true } label: {
                    Text("Leave sample mode")
                        .font(.lato(14, .bold))
                        .foregroundStyle(MaudeTheme.primaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(MaudeTheme.primaryFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    guard !enteringSample else { return }
                    enteringSample = true
                    Task {
                        await appState.enterSampleMode(.settingsChoice)
                        enteringSample = false
                    }
                } label: {
                    Text(enteringSample
                         ? String(localized: "Preparing the sample…")
                         : String(localized: "Explore with sample data"))
                        .font(.lato(14, .bold))
                        .foregroundStyle(MaudeTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(MaudeTheme.line, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .disabled(enteringSample)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(appState.isSampleMode ? MaudeTheme.clay3 : MaudeTheme.line2, lineWidth: 1))
        .confirmationDialog(String(localized: "Leave sample mode?"),
                            isPresented: $confirmLeaveSample, titleVisibility: .visible) {
            Button(String(localized: "Leave sample mode")) {
                Task { await appState.leaveSampleMode() }
            }
            Button(String(localized: "Stay"), role: .cancel) { }
        } message: {
            Text("Maude goes back to your own data. Nothing from the sample is kept — it was never saved anywhere.")
        }
    }

    // MARK: — Zone 1: My Data

    private var myDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("MY DATA", icon: "person.circle")

            // Every status word in this card is DERIVED (SettingsStatus) — see
            // the incident note above that type. Each row also pushes the screen
            // its status is about, so the two can be compared in one tap.
            VStack(spacing: 1) {
                profileRow
                Divider().padding(.leading, 56)
                Button { showDataSources = true } label: {
                    connectedSourceRow(
                        icon: "heart.fill",
                        color: MaudeTheme.accentHeart,
                        label: "Apple Health",
                        status: appleHealthStatus.label,
                        statusColor: statusColor(appleHealthStatus)
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                Button { showVault = true } label: {
                    connectedSourceRow(
                        icon: "doc.fill",
                        color: MaudeTheme.clay,
                        label: "Health Vault",
                        status: vaultStatus.label,
                        statusColor: statusColor(vaultStatus)
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                Button {
                    if Config.sundhedWebConnectEnabled { showSundhedImport = true }
                    else { showDataSources = true }
                } label: {
                    connectedSourceRow(
                        icon: "cross.case.fill",
                        color: MaudeTheme.accentRecovery,
                        label: "Sundhedsplatformen",
                        status: sundhedStatus.label,
                        statusColor: statusColor(sundhedStatus)
                    )
                }
                .buttonStyle(.plain)
            }
            .background(MaudeTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

            // Account & security — the designed pushed screen (A7.2 Area ⑧:
            // b-integrations ScrAccount — sign-in state, app lock, backup,
            // recovery, held-vs-on-device, delete).
            Button { showAccount = true } label: {
                settingsNavRow(
                    icon: "key.fill",
                    color: MaudeTheme.fjordBright,
                    label: String(localized: "Account & security"),
                    // Was `?? "Demo session"` — which a signed-out session read
                    // as a demo one.
                    detail: SettingsStatus.accountDetail(email: appState.session?.email,
                                                         signedIn: appState.session != nil)
                )
                .background(MaudeTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Context flags (FR-CTX-04) — the days the user marked as
            // travelling / unwell / off-routine, reviewable and clearable here.
            Button { showContextFlags = true } label: {
                settingsNavRow(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    color: MaudeTheme.accentFinance,
                    label: String(localized: "Days you've marked"),
                    detail: contextFlagDetail
                )
                .background(MaudeTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Sample data (FR-SMP-05) — the second of the app's two doors into
            // sample mode (the first is the Apple Health step in onboarding).
            // Both are explicit acts by the citizen; nothing else can open it.
            sampleDataCard

            // Face ID app lock quick toggle (NFR-SEC-08, Area ① — kept here;
            // the Account screen exposes the same @AppStorage pref).
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: Binding(
                    get: { appLockEnabled },
                    set: { on in
                        appLockNote = nil
                        if on {
                            let ctx = LAContext()
                            var err: NSError?
                            if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
                                appLockEnabled = true
                            } else {
                                appLockNote = String(localized: "Face ID isn't available on this device right now.")
                            }
                        } else {
                            appLockEnabled = false
                        }
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .foregroundStyle(MaudeTheme.moss)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face ID app lock")
                                .font(.footnote)
                                .foregroundStyle(MaudeTheme.ink)
                            Text("Maude asks for Face ID each time it wakes.")
                                .font(.caption)
                                .foregroundStyle(MaudeTheme.ink4)
                        }
                    }
                }
                .tint(MaudeTheme.moss)
                if let appLockNote {
                    Text(appLockNote)
                        .font(.caption)
                        .foregroundStyle(MaudeTheme.clayText)
                }
            }
            .padding(14)
            .background(MaudeTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

            // Data Sources + Health Passport
            VStack(spacing: 1) {
                if Config.sundhedConnectEnabled {
                    Button { showSundhedImport = true } label: {
                        settingsNavRow(
                            icon: "cross.case.fill",
                            color: MaudeTheme.moss,
                            label: "Connect Sundhed.dk",
                            detail: "Import labs, medicine & diagnoses"
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 56)
                }
                Button { showDataSources = true } label: {
                    settingsNavRow(
                        icon: "externaldrive.connected.to.line.below.fill",
                        color: MaudeTheme.ink3,
                        label: "Data Sources",
                        // The SAME counter the pushed screen's verdict band
                        // uses — the two numbers cannot drift apart.
                        detail: String(localized: "\(connectedSourceCount) connected")
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                Button { showHealthPassport = true } label: {
                    settingsNavRow(
                        icon: "staroflife.fill",
                        color: MaudeTheme.moss,
                        label: "Health Passport",
                        detail: "\(appState.passportStats.daysTracked) days"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(MaudeTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

            // Export — GDPR Art. 20 (T1): fetches the real server export
            // (`GET /me/export`) on the sovereign backend, an honest device-local
            // JSON otherwise, and hands the file to the share sheet.
            Button {
                guard !isExporting else { return }
                isExporting = true
                exportFailed = false
                Task { @MainActor in
                    defer { isExporting = false }
                    if let url = await appState.exportMyData() {
                        exportFile = ExportFile(url: url)
                    } else {
                        withAnimation { exportFailed = true }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(MaudeTheme.ink3)
                        }
                        Text(isExporting ? "Preparing your export…" : "Export all my Maude data")
                            .font(.footnote)
                            .foregroundStyle(MaudeTheme.ink2)
                        Spacer()
                    }
                    if exportFailed {
                        Text("The export couldn't be prepared. Check your connection and try again.")
                            .font(.caption)
                            .foregroundStyle(MaudeTheme.rust)
                    }
                }
                .padding(14)
                .background(MaudeTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            }
            .disabled(isExporting)
            #if os(iOS)
            .sheet(item: $exportFile) { file in
                ActivityShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            #endif

            // Sleep diagnostics (FR-DIAG-01, sleep incident 2026-08): a
            // 14-night raw-vs-derived sleep report, built on device, exported
            // only through the share sheet. Ships in Release too — the report
            // this instrument exists for came from a TestFlight build.
            Button { showSleepDiagnostics = true } label: {
                settingsNavRow(
                    icon: "moon.zzz.fill",
                    color: MaudeTheme.fjordBright,
                    label: String(localized: "Sleep diagnostics"),
                    detail: String(localized: "14-night report")
                )
                .background(MaudeTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: — Derived state for the "My data" rows

    /// Apple Health: the real provider/read outcome, never a constant.
    private var appleHealthStatus: SettingsStatus.AppleHealth {
        SettingsStatus.appleHealth(
            rowConnected: appState.connectedSources
                .first { $0.name == "Apple Health" }?.isConnected ?? false,
            didAttemptFetch: appState.didAttemptHealthFetch,
            outcome: appState.healthReadOutcome)
    }

    /// The vault: whatever `HealthVaultSession.open` last answered.
    private var vaultStatus: SettingsStatus.Vault {
        SettingsStatus.vault(access: vaultAccess, documentCount: vaultDocumentCount)
    }

    /// Sundhed.dk: the persisted returning-user record (the same read Data
    /// sources uses for its "Connected" row).
    private var sundhedStatus: SettingsStatus.Sundhed {
        SettingsStatus.sundhed(
            hasImportRecord: sundhedConnected,
            connectAvailable: Config.sundhedWebConnectEnabled || Config.sundhedConnectEnabled)
    }

    private var sundhedConnected: Bool {
        let citizenId = appState.profile?.alias ?? appState.session?.userId.uuidString
        return SundhedWebSessionView.lastPullSummary(citizenId: citizenId) != nil
    }

    /// Connected-source count, computed by the counter Data sources itself uses.
    private var connectedSourceCount: Int {
        DataSourcesView.connectedSourceCount(appState.connectedSources,
                                             sundhedConnected: sundhedConnected)
    }

    /// One open of the encrypted space — the same call, and therefore the same
    /// answer, as the screen this row pushes.
    private func readVaultState() {
        let session = HealthVaultSession.open(keyVault: .shared,
                                              userScope: LocalUserScope.current())
        vaultAccess = session.access
        vaultDocumentCount = session.documents.count
    }

    private func statusColor(_ s: SettingsStatus.AppleHealth) -> Color {
        switch s {
        case .connected:                 return MaudeTheme.moss
        case .noReadings, .couldNotRead: return MaudeTheme.ink3
        case .notCheckedYet, .notConnected: return MaudeTheme.ink4
        }
    }

    private func statusColor(_ s: SettingsStatus.Vault) -> Color {
        switch s {
        case .documents(let n):              return n == 0 ? MaudeTheme.ink4 : MaudeTheme.ink3
        case .unreadable:                    return MaudeTheme.clayText
        case .checking, .lockedUntilUnlock, .unavailable: return MaudeTheme.ink4
        }
    }

    private func statusColor(_ s: SettingsStatus.Sundhed) -> Color {
        s == .connected ? MaudeTheme.moss : MaudeTheme.ink4
    }

    private var profileRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MaudeTheme.invertBG)
                    .frame(width: 40, height: 40)
                if let initials {
                    Text(initials)
                        .font(.lato(14, .semibold))
                        .foregroundStyle(MaudeTheme.invertFG)
                } else {
                    Image(systemName: "person.fill")
                        .font(.lato(14))
                        .foregroundStyle(MaudeTheme.invertFG)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                // No "Demo User" stand-in: an unnamed profile says so rather
                // than inventing a person (matches ProfileSheet).
                Text(displayName ?? String(localized: "Your profile"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MaudeTheme.ink)
                // Was the flat claim "Device-stored only · never uploaded" —
                // untrue of a name that arrived from the account.
                Text(SettingsStatus.nameOrigin(
                        shown: displayName,
                        declaredOnDevice: UserDefaults.standard
                            .string(forKey: AppState.displayNameKey)).label)
                    .font(.caption)
                    .foregroundStyle(MaudeTheme.ink4)
                if appState.walletVerified {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 9))
                        Text("Verified with Partisia" + (appState.walletVerificationRef.map { " · \($0)" } ?? ""))
                            .font(.maudeKicker(8.5)).tracking(0.3)
                    }
                    .foregroundStyle(MaudeTheme.moss)
                    .padding(.top, 1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func connectedSourceRow(icon: String, color: Color, label: String, status: String, statusColor: Color) -> some View {
        HStack(spacing: 14) {
            // A7.2 pattern 1: SOLID icon square + white glyph (adjacent label carries meaning).
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.lato(13))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 16)

            Text(label)
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink)
            Spacer()
            Text(status)
                .font(.footnote)
                .foregroundStyle(statusColor)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(MaudeTheme.line)
                .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
    }

    // MARK: — Zone 2: Consent & Sharing

    /// Donor-programme entry (DON-2026-01). Rendered only when the build was
    /// compiled with `-D MAUDE_DONOR`; the row states plainly that the app
    /// sends nothing, because the whole point of the export model is that it
    /// cannot.
    private var donorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("DONOR PROGRAMME", icon: "shippingbox")
            Button { showDonorExport = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lock.doc")
                        .font(.system(size: 15)).foregroundStyle(MaudeTheme.brass)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Donate a copy to the engineers")
                            .font(.lato(15, .semibold)).foregroundStyle(MaudeTheme.ink)
                        Text(appState.hasActiveDonationGrant
                             ? String(localized: "Agreement recorded · you export the file yourself")
                             : String(localized: "Needs the reference from your signed form"))
                            .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12)).foregroundStyle(MaudeTheme.ink4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("CONSENT & SHARING", icon: "lock.shield")

            if appState.grants.isEmpty {
                // "You haven't shared data with anyone" is a claim about the
                // consent record — it may only be made once that record has
                // actually been read back. While the read is in flight the card
                // says so instead.
                if appState.isLoadingWallet { checkingGrantsCard } else { emptyGrantsCard }
            } else {
                VStack(spacing: 1) {
                    ForEach(appState.grants) { grant in
                        consentGrantRow(grant)
                        if grant.id != appState.grants.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(MaudeTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
            }

            // Privacy record link
            Button { showConsentLedger = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle")
                        .foregroundStyle(MaudeTheme.ink4)
                        .font(.caption)
                    Text(consentLogClaim)
                        .font(.caption)
                        .foregroundStyle(MaudeTheme.ink4)
                    Spacer()
                    Text("View log →")
                        .font(.caption)
                        .foregroundStyle(MaudeTheme.moss)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }

    /// FR-WAL-09 — the SAME claim gate the ledger screen applies, and its exact
    /// wording. This line used to make the strong claim unconditionally ("All
    /// sharing changes are independently logged and cannot be altered"), so on
    /// a stub-mode consent engine — where events carry no evidentiary receipt —
    /// Settings promised something the screen it links to explicitly softens.
    private var consentLogClaim: String {
        let hasEvidence = appState.walletEvents.contains { $0.ce?.isEvidentiary == true }
        return String(localized: "Every sharing change is recorded. ")
             + ConsentLedgerView.headerClaim(hasEvidence: hasEvidence)
    }

    private var checkingGrantsCard: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text("Reading your sharing record…")
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink3)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))
    }

    private var emptyGrantsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(MaudeTheme.moss)
                .font(.lato(20))
            VStack(alignment: .leading, spacing: 2) {
                Text("No active sharing")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MaudeTheme.ink)
                Text("You haven't shared data with anyone. This is the default.")
                    .font(.caption)
                    .foregroundStyle(MaudeTheme.ink3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.moss2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.moss3, lineWidth: 1))
    }

    private func consentGrantRow(_ grant: WalletGrant) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(grant.isActive ? MaudeTheme.moss2 : MaudeTheme.line2)
                    .frame(width: 32, height: 32)
                Image(systemName: "building.2")
                    .font(.lato(12))
                    .foregroundStyle(grant.isActive ? MaudeTheme.moss : MaudeTheme.ink4)
            }
            .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(grant.recipientName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MaudeTheme.ink)
                Text(grant.isActive ? "Active · \(grant.scopeKeys.prefix(2).joined(separator: ", "))" : "Withdrawn")
                    .font(.caption)
                    .foregroundStyle(grant.isActive ? MaudeTheme.ink3 : MaudeTheme.ink4)
            }

            Spacer()

            if grant.isActive {
                Circle()
                    .fill(MaudeTheme.moss)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 16)
            } else {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(MaudeTheme.line)
                    .padding(.trailing, 16)
            }
        }
        .frame(minHeight: 52)
    }

    // MARK: — Zone 3: Regulatory

    private var regulatorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("REGULATORY", icon: "info.circle")

            // The disclaimer card — visible, not buried
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(MaudeTheme.clay)
                    Text("IMPORTANT NOTICE")
                        .font(.maudeKicker(9))
                        .foregroundStyle(MaudeTheme.clay)
                        .kerning(1)
                }

                // FR-REG-01 — the ONE canonical MDR notice (RegulatoryCopy).
                // Previously this card carried its own divergent wording.
                Text(RegulatoryCopy.mdrNotice)
                    .font(.caption)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(MaudeTheme.clay2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.clay.opacity(0.3), lineWidth: 1))

            // Links
            VStack(spacing: 1) {
                Button { showNudgeSettings = true } label: {
                    regulatoryLinkRow(label: "Notifications", icon: "bell")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                Button { showPrivacy = true } label: {
                    regulatoryLinkRow(label: "Privacy", icon: "hand.raised")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                regulatoryLinkRow(label: "Privacy Policy", icon: "doc.text")
                Divider().padding(.leading, 56)
                regulatoryLinkRow(label: "Terms of Use", icon: "doc.plaintext")
                Divider().padding(.leading, 56)
                regulatoryLinkRow(label: "Open Source Licences", icon: "curlybraces")
                Divider().padding(.leading, 56)
                versionRow
            }
            .background(MaudeTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

            // Delete all data — the dedicated designed screen (A7.2 Area ⑧;
            // server-first ordering + retryable failure live in DeleteDataView).
            Button { showDelete = true } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete all my data")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(MaudeTheme.rust.opacity(0.6))
                }
                .font(.footnote)
                .foregroundStyle(MaudeTheme.rust)
                .padding(14)
                .background(MaudeTheme.rust2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.rust.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func regulatoryLinkRow(label: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.lato(13))
                .foregroundStyle(MaudeTheme.ink3)
                .frame(width: 32)
                .padding(.leading, 16)
            Text(label)
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(MaudeTheme.line)
                .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
    }

    private var versionRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "info.circle")
                .font(.lato(13))
                .foregroundStyle(MaudeTheme.ink4)
                .frame(width: 32)
                .padding(.leading, 16)
            // Read from the bundle: "Version 1.0" was frozen in source while
            // the build number moved every TestFlight upload, so a tester's
            // report could never say which build they were on.
            Text(SettingsStatus.versionLabel(
                    short: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String))
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink4)
            Spacer()
        }
        .frame(minHeight: 48)
    }

    // (deleteSection + runErase moved to DeleteDataView — A7.2 Area ⑧.)

    // MARK: Helpers

    private func settingsNavRow(icon: String, color: Color, label: String, detail: String) -> some View {
        HStack(spacing: 14) {
            // A7.2 pattern 1: SOLID icon square + white glyph.
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.lato(13))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 16)
            Text(label)
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink)
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink3)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(MaudeTheme.line)
                .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
    }

    private func zoneHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.lato(11))
                .foregroundStyle(MaudeTheme.ink3)
            Text(title)
                .font(.maudeKicker(10))
                .foregroundStyle(MaudeTheme.ink3)
                .kerning(1)
        }
    }

    /// Honest right-hand detail on the context-flag row: the open flag if there
    /// is one, else the count of stretches on record, else nothing marked.
    private var contextFlagDetail: String {
        if let open = appState.openContextFlags.first { return open.kind.label }
        let n = appState.contextFlags.count
        if n == 0 { return String(localized: "None") }
        return n == 1 ? String(localized: "1 past") : String(localized: "\(n) past")
    }

    /// The name actually on record, or nil — never a stand-in.
    private var displayName: String? {
        let name = (appState.profile?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// nil when there is no name to take initials from (the avatar falls back
    /// to a person glyph rather than inventing "DE" for "Demo").
    private var initials: String? {
        guard let name = displayName else { return nil }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Derived settings statuses (the truth behind every status word)
//
// DATA-HONESTY INCIDENT 2026-08-13. The three "My data" rows shipped with their
// statuses WRITTEN IN — "Apple Health · Connected", "Health Vault · 3 files",
// "Sundhedsplatformen · Not connected" — so they read identically for a
// brand-new citizen with nothing connected. A tester saw "3 files" over an
// empty vault and "Connected" while Home was still waiting for its first Apple
// Health sample. Every status word below is now computed from state the app can
// actually observe, and each genuinely-unknown case says so instead of guessing
// a reassuring default.
//
// Pure Foundation (no SwiftUI, no HealthKit, no device) so the whole truth
// table is testable without a simulator — MaudeTests/SettingsTruthTests.swift.
enum SettingsStatus {

    // MARK: Apple Health
    //
    // WORDING RULE — see `AppState.HealthReadOutcome`: HealthKit does not report
    // READ authorisation, and a denied read is specified to look exactly like an
    // empty one. So no case here may claim access was denied, refused or
    // blocked; `.noReadings` states precisely what was observed.
    enum AppleHealth: Equatable {
        /// A real read returned samples (or this session's source row is
        /// genuinely marked connected).
        case connected
        /// The read completed and every requested type came back empty.
        case noReadings
        /// The read itself threw.
        case couldNotRead
        /// No read has completed yet — unknown, and said so.
        case notCheckedYet
        /// A read ran without ever asking HealthKit (no Health on this platform).
        case notConnected

        var label: String {
            switch self {
            case .connected:     return String(localized: "Connected")
            case .noReadings:    return String(localized: "No readings yet")
            case .couldNotRead:  return String(localized: "Couldn't be read")
            case .notCheckedYet: return String(localized: "Not checked yet")
            case .notConnected:  return String(localized: "Not connected")
            }
        }
    }

    static func appleHealth(rowConnected: Bool,
                            didAttemptFetch: Bool,
                            outcome: AppState.HealthReadOutcome) -> AppleHealth {
        switch outcome {
        case .readings:   return .connected
        case .noReadings: return .noReadings
        case .failed:     return .couldNotRead
        case .notAttempted:
            // No verdict from HealthKit this session. The source row is still
            // truthful (a real read marked it, or a DEBUG demo seed set it).
            if rowConnected { return .connected }
            return didAttemptFetch ? .notConnected : .notCheckedYet
        }
    }

    // MARK: Health data space (vault)
    //
    // The count comes from the SAME `HealthVaultSession.open` the vault screen
    // uses, so the number here is the number the pushed screen lists. In every
    // non-`.ready` state the count is genuinely unobtainable — those cases name
    // the state and print NO number (a "0 files" over sealed documents would be
    // the worst possible lie on this screen).
    enum Vault: Equatable {
        case checking
        case documents(Int)
        case lockedUntilUnlock
        case unreadable
        case unavailable

        var label: String {
            switch self {
            case .checking:          return String(localized: "Checking…")
            case .documents(let n):
                if n == 0 { return String(localized: "Empty") }
                return n == 1 ? String(localized: "1 document")
                              : String(localized: "\(n) documents")
            case .lockedUntilUnlock: return String(localized: "Locked for now")
            case .unreadable:        return String(localized: "Can't be opened")
            case .unavailable:       return String(localized: "Not available")
            }
        }

        /// True only when the row is printing a real, obtained count.
        var showsCount: Bool { if case .documents = self { return true }; return false }
    }

    static func vault(access: VaultAccess?, documentCount: Int) -> Vault {
        switch access {
        case .none:                          return .checking
        case .ready?:                        return .documents(documentCount)
        case .lockedUntilDeviceUnlock?:      return .lockedUntilUnlock
        case .sealedDataUnreadable?:         return .unreadable
        case .keyUnavailable?:               return .unavailable
        }
    }

    // MARK: Sundhedsplatformen (national record)

    enum Sundhed: Equatable {
        case connected
        case notConnected
        /// The connect path itself isn't open in this build (lawful-basis gate).
        case notAvailableYet

        var label: String {
            switch self {
            case .connected:       return String(localized: "Connected")
            case .notConnected:    return String(localized: "Not connected")
            case .notAvailableYet: return String(localized: "Not available yet")
            }
        }
    }

    static func sundhed(hasImportRecord: Bool, connectAvailable: Bool) -> Sundhed {
        if hasImportRecord { return .connected }
        return connectAvailable ? .notConnected : .notAvailableYet
    }

    // MARK: Account row detail

    static func accountDetail(email: String?, signedIn: Bool) -> String {
        guard signedIn else { return String(localized: "Not signed in") }
        if let email, !email.trimmingCharacters(in: .whitespaces).isEmpty { return email }
        return String(localized: "Signed in")
    }

    // MARK: Where the displayed name came from
    //
    // The onboarding-declared name is device-local (`AppState.displayNameKey`,
    // never uploaded); an account name arrives from `/me`. The old row asserted
    // "Device-stored only · never uploaded" under BOTH.
    enum NameOrigin: Equatable {
        case none
        case declaredOnDevice
        case fromAccount

        var label: String {
            switch self {
            case .none:             return String(localized: "No name saved on this device")
            case .declaredOnDevice: return String(localized: "The name you gave Maude · kept on this phone")
            case .fromAccount:      return String(localized: "From your Maude account")
            }
        }
    }

    static func nameOrigin(shown: String?, declaredOnDevice: String?) -> NameOrigin {
        let name = (shown ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .none }
        let declared = (declaredOnDevice ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !declared.isEmpty, declared.caseInsensitiveCompare(name) == .orderedSame {
            return .declaredOnDevice
        }
        return .fromAccount
    }

    // MARK: Version
    //
    // Was the literal "Version 1.0" — which stayed 1.0 across every TestFlight
    // build, so a tester's report could never identify what they were running.
    static func versionLabel(short: String?, build: String?) -> String {
        let s = (short ?? "").trimmingCharacters(in: .whitespaces)
        let b = (build ?? "").trimmingCharacters(in: .whitespaces)
        switch (s.isEmpty, b.isEmpty) {
        case (false, false): return String(localized: "Version \(s) (\(b))")
        case (false, true):  return String(localized: "Version \(s)")
        case (true, false):  return String(localized: "Build \(b)")
        case (true, true):   return String(localized: "Version unavailable")
        }
    }
}

#if os(iOS)
/// Minimal UIActivityViewController wrapper for the data-export share sheet
/// (GDPR Art. 20 — the /me/export JSON handed to Files/AirDrop/Mail).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
}
