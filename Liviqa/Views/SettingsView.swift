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
    // Default MUST match LiviqaApp's default (Paper) or the picker shows the wrong
    // selection on a fresh install.
    @AppStorage("liviqaThemeMode")    private var themeModeRaw = LiviqaTheme.Mode.paper.rawValue
    @AppStorage("liviqaReduceMotion") private var reduceMotion = false
    @AppStorage("liquidGlass")        private var liquidGlass = true
    @AppStorage("clinicalTIRZones")   private var clinicalTIRZones = true
    @AppStorage("gradedHeatmap")      private var gradedHeatmap = true
    @AppStorage("visualNudge")        private var visualNudge = true
    @AppStorage("crossSourceCards")   private var crossSourceCards = false
    @AppStorage("liviqaShowDemoChip") private var showDemoChip = false
    @AppStorage("liviqa.appLanguage") private var appLanguage = "system"
    // Face ID app lock (NFR-SEC) — runtime overlay wired in LiviqaApp.
    @AppStorage("appLockEnabled")     private var appLockEnabled = false
    @State private var appLockNote: String? = nil

    // Navigation destinations
    @State private var showDataSources    = false
    @State private var showHealthPassport = false
    @State private var showSundhedImport  = false
    @State private var showConsentLedger  = false
    @State private var showNudgeSettings  = false
    @State private var showPrivacy        = false
    @State private var showShare          = false
    @State private var showAccount        = false
    @State private var showDelete         = false
    /// FR-CTX-04 — review/clear the user's own context flags.
    @State private var showContextFlags   = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                displaySection
                myDataSection
                consentSection
                regulatorySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: $showDataSources)    { DataSourcesView() }
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
        .sheet(isPresented: $showShare) {
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
        // FR-CTX-04 — review / end the days marked as travelling, unwell or
        // off-routine (same surface as the Today entry affordance).
        .sheet(isPresented: $showContextFlags) { ContextFlagSheet() }
        #if DEBUG
        // Snapshot hooks (A7.2 Area ⑧): with LIVIQA_TAB=settings —
        // LIVIQA_OPEN_ACCOUNT=1 → Account & security; LIVIQA_OPEN_NOTIFS=1 →
        // Notifications; LIVIQA_OPEN_DELETE=1 → Delete all my data.
        .task {
            let env = ProcessInfo.processInfo.environment
            if env["LIVIQA_OPEN_ACCOUNT"] == "1" { showAccount = true }
            if env["LIVIQA_OPEN_NOTIFS"]  == "1" { showNudgeSettings = true }
            if env["LIVIQA_OPEN_DELETE"]  == "1" { showDelete = true }
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
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Spacer()
                    }
                    Picker("Theme", selection: $themeModeRaw) {
                        Text("Midnight").tag(LiviqaTheme.Mode.midnight.rawValue)
                        Text("Paper").tag(LiviqaTheme.Mode.paper.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Divider().overlay(LiviqaTheme.line2)

                // Language — the real iOS per-app-language rail (AppleLanguages
                // override; applies on next launch). Honest per-language status:
                // English complete; the rest have approved terminology in
                // Weblate with full interface translation to follow.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Language")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
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
                        .tint(LiviqaTheme.ink2)
                    }
                    Text(appLanguage == "system"
                         ? "Follows your iPhone language."
                         : "Applies at next launch. Terminology approved in all six languages; interface translation rolling out.")
                        .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                }
                .onChange(of: appLanguage) { _, lang in
                    if lang == "system" {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
                    }
                }

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $reduceMotion) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reduce motion")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Skip ring draw-in and chart animations")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $liquidGlass) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Liquid Glass")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Translucent chrome on iPhones running iOS 26")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $clinicalTIRZones) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clinical glucose zones")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Red / amber / green time-in-range bands on the glucose chart")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $gradedHeatmap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Graded heatmap")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Shade each day by how far it is from your usual (Insights)")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $visualNudge) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nudge domain icons")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Show a category icon on each insight on Home")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $crossSourceCards) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cross-source patterns")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Show health × spending × lab correlation cards on Insights")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)

                Divider().overlay(LiviqaTheme.line2)

                Toggle(isOn: $showDemoChip) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo data chip")
                            .font(.footnote).foregroundStyle(LiviqaTheme.ink)
                        Text("Show the “Demo data” marker on Today")
                            .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .tint(LiviqaTheme.moss)
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
        }
    }

    // MARK: — Zone 1: My Data

    private var myDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("MY DATA", icon: "person.circle")

            VStack(spacing: 1) {
                profileRow
                Divider().padding(.leading, 56)
                connectedSourceRow(
                    icon: "heart.fill",
                    color: LiviqaTheme.accentHeart,
                    label: "Apple Health",
                    status: "Connected",
                    statusColor: LiviqaTheme.moss
                )
                Divider().padding(.leading, 56)
                connectedSourceRow(
                    icon: "doc.fill",
                    color: LiviqaTheme.clay,
                    label: "Health Vault",
                    status: "3 files",
                    statusColor: LiviqaTheme.ink3
                )
                Divider().padding(.leading, 56)
                connectedSourceRow(
                    icon: "cross.case.fill",
                    color: LiviqaTheme.accentRecovery,
                    label: "Sundhedsplatformen",
                    status: "Not connected",
                    statusColor: LiviqaTheme.ink4
                )
            }
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

            // Account & security — the designed pushed screen (A7.2 Area ⑧:
            // b-integrations ScrAccount — sign-in state, app lock, backup,
            // recovery, held-vs-on-device, delete).
            Button { showAccount = true } label: {
                settingsNavRow(
                    icon: "key.fill",
                    color: LiviqaTheme.fjordBright,
                    label: String(localized: "Account & security"),
                    detail: appState.session?.email ?? String(localized: "Demo session")
                )
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Context flags (FR-CTX-04) — the days the user marked as
            // travelling / unwell / off-routine, reviewable and clearable here.
            Button { showContextFlags = true } label: {
                settingsNavRow(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    color: LiviqaTheme.accentFinance,
                    label: String(localized: "Days you've marked"),
                    detail: contextFlagDetail
                )
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)

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
                            .foregroundStyle(LiviqaTheme.moss)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face ID app lock")
                                .font(.footnote)
                                .foregroundStyle(LiviqaTheme.ink)
                            Text("Liviqa asks for Face ID each time it wakes.")
                                .font(.caption)
                                .foregroundStyle(LiviqaTheme.ink4)
                        }
                    }
                }
                .tint(LiviqaTheme.moss)
                if let appLockNote {
                    Text(appLockNote)
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.clayText)
                }
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

            // Data Sources + Health Passport
            VStack(spacing: 1) {
                if Config.sundhedConnectEnabled {
                    Button { showSundhedImport = true } label: {
                        settingsNavRow(
                            icon: "cross.case.fill",
                            color: LiviqaTheme.moss,
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
                        color: LiviqaTheme.ink3,
                        label: "Data Sources",
                        detail: "\(appState.connectedSources.filter(\.isConnected).count) connected"
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
                Button { showHealthPassport = true } label: {
                    settingsNavRow(
                        icon: "staroflife.fill",
                        color: LiviqaTheme.moss,
                        label: "Health Passport",
                        detail: "\(appState.passportStats.daysTracked) days"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

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
                                .foregroundStyle(LiviqaTheme.ink3)
                        }
                        Text(isExporting ? "Preparing your export…" : "Export all my Liviqa data")
                            .font(.footnote)
                            .foregroundStyle(LiviqaTheme.ink2)
                        Spacer()
                    }
                    if exportFailed {
                        Text("The export couldn't be prepared. Check your connection and try again.")
                            .font(.caption)
                            .foregroundStyle(LiviqaTheme.rust)
                    }
                }
                .padding(14)
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
            .disabled(isExporting)
            #if os(iOS)
            .sheet(item: $exportFile) { file in
                ActivityShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            #endif
        }
    }

    private var profileRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LiviqaTheme.invertBG)
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.lato(14, .semibold))
                    .foregroundStyle(LiviqaTheme.invertFG)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.profile?.displayName ?? "Demo User")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text("Device-stored only · never uploaded")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                if appState.walletVerified {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 9))
                        Text("Verified with Partisia" + (appState.walletVerificationRef.map { " · \($0)" } ?? ""))
                            .font(.liviqaKicker(8.5)).tracking(0.3)
                    }
                    .foregroundStyle(LiviqaTheme.moss)
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
                .foregroundStyle(LiviqaTheme.ink)
            Spacer()
            Text(status)
                .font(.footnote)
                .foregroundStyle(statusColor)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(LiviqaTheme.line)
                .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
    }

    // MARK: — Zone 2: Consent & Sharing

    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader("CONSENT & SHARING", icon: "lock.shield")

            if appState.grants.isEmpty {
                emptyGrantsCard
            } else {
                VStack(spacing: 1) {
                    ForEach(appState.grants) { grant in
                        consentGrantRow(grant)
                        if grant.id != appState.grants.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }

            // Privacy record link
            Button { showConsentLedger = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle")
                        .foregroundStyle(LiviqaTheme.ink4)
                        .font(.caption)
                    Text("All sharing changes are independently logged and cannot be altered.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink4)
                    Spacer()
                    Text("View log →")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.moss)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }

    private var emptyGrantsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(LiviqaTheme.moss)
                .font(.lato(20))
            VStack(alignment: .leading, spacing: 2) {
                Text("No active sharing")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text("You haven't shared data with anyone. This is the default.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
    }

    private func consentGrantRow(_ grant: WalletGrant) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(grant.isActive ? LiviqaTheme.moss2 : LiviqaTheme.line2)
                    .frame(width: 32, height: 32)
                Image(systemName: "building.2")
                    .font(.lato(12))
                    .foregroundStyle(grant.isActive ? LiviqaTheme.moss : LiviqaTheme.ink4)
            }
            .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(grant.recipientName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(grant.isActive ? "Active · \(grant.scopeKeys.prefix(2).joined(separator: ", "))" : "Withdrawn")
                    .font(.caption)
                    .foregroundStyle(grant.isActive ? LiviqaTheme.ink3 : LiviqaTheme.ink4)
            }

            Spacer()

            if grant.isActive {
                Circle()
                    .fill(LiviqaTheme.moss)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 16)
            } else {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.line)
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
                        .foregroundStyle(LiviqaTheme.clay)
                    Text("IMPORTANT NOTICE")
                        .font(.liviqaKicker(9))
                        .foregroundStyle(LiviqaTheme.clay)
                        .kerning(1)
                }

                // FR-REG-01 — the ONE canonical MDR notice (RegulatoryCopy).
                // Previously this card carried its own divergent wording.
                Text(RegulatoryCopy.mdrNotice)
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(LiviqaTheme.clay2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.clay.opacity(0.3), lineWidth: 1))

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
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

            // Delete all data — the dedicated designed screen (A7.2 Area ⑧;
            // server-first ordering + retryable failure live in DeleteDataView).
            Button { showDelete = true } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete all my data")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(LiviqaTheme.rust.opacity(0.6))
                }
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.rust)
                .padding(14)
                .background(LiviqaTheme.rust2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.rust.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func regulatoryLinkRow(label: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.lato(13))
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(width: 32)
                .padding(.leading, 16)
            Text(label)
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(LiviqaTheme.line)
                .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
    }

    private var versionRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "info.circle")
                .font(.lato(13))
                .foregroundStyle(LiviqaTheme.ink4)
                .frame(width: 32)
                .padding(.leading, 16)
            Text("Version 1.0")
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink4)
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
                .foregroundStyle(LiviqaTheme.ink)
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink3)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(LiviqaTheme.line)
                .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
    }

    private func zoneHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.lato(11))
                .foregroundStyle(LiviqaTheme.ink3)
            Text(title)
                .font(.liviqaKicker(10))
                .foregroundStyle(LiviqaTheme.ink3)
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

    private var initials: String {
        let name = appState.profile?.displayName ?? "Demo"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
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
