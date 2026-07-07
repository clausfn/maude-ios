// SettingsView.swift — Profile · Consent · Regulatory v02 · 2026-05-22
// Three zones: My Data (profile + connected sources) / Consent & Sharing (audit trail)
// / Regulatory (disclaimer, privacy policy, delete). This is the trust layer.
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    // 0=idle 1=warn 2=confirm 3=done 4=server-erase failed (retryable)
    @State private var showDeleteConfirmStep: Int = 0
    @State private var isErasing = false
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

    // Navigation destinations
    @State private var showDataSources    = false
    @State private var showHealthPassport = false
    @State private var showConsentLedger  = false
    @State private var showNudgeSettings  = false
    @State private var showPrivacy        = false
    @State private var showShare          = false

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
        .navigationDestination(isPresented: $showConsentLedger)  { ConsentLedgerView() }
        .navigationDestination(isPresented: $showNudgeSettings)  { NotificationSettingsView() }
        .navigationDestination(isPresented: $showPrivacy)        { InAppPrivacyView() }
        .sheet(isPresented: $showShare) {
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
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
                    color: .red,
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
                    color: Color(hex: 0x2992A5),
                    label: "Sundhedsplatformen",
                    status: "Not connected",
                    statusColor: LiviqaTheme.ink4
                )
            }
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

            // Data Sources + Health Passport
            VStack(spacing: 1) {
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
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.lato(13))
                    .foregroundStyle(color)
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

                Text("Liviqa is a personal wellness application. It is not a medical device, and it does not diagnose, treat, monitor, or manage any medical condition.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink2)

                Text("Nudges are first-person observations generated from your own data. They are not medical advice. Always consult a qualified healthcare professional before making changes to your care or medication.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink2)
            }
            .padding(14)
            .background(LiviqaTheme.clay2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.clay.opacity(0.3), lineWidth: 1))

            // Links
            VStack(spacing: 1) {
                Button { showNudgeSettings = true } label: {
                    regulatoryLinkRow(label: "Nudge Settings", icon: "bell")
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

            // Delete all data — three-step confirmation
            deleteSection
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

    private var deleteSection: some View {
        VStack(spacing: 8) {
            switch showDeleteConfirmStep {
            case 0:
                Button {
                    withAnimation(.spring(response: 0.3)) { showDeleteConfirmStep = 1 }
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete all my data")
                    }
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.rust)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(LiviqaTheme.rust2)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.rust.opacity(0.3), lineWidth: 1))
                }

            case 1:
                VStack(spacing: 8) {
                    Text("This will permanently delete your data from Liviqa's servers and from this device — health records, vault files, journal entries, consent grants, messages, and nudge history. It cannot be undone.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.rust)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)

                    HStack(spacing: 10) {
                        Button("Cancel") {
                            withAnimation { showDeleteConfirmStep = 0 }
                        }
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(LiviqaTheme.paper2)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 1))

                        Button("Yes, delete everything") {
                            withAnimation { showDeleteConfirmStep = 2 }
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(LiviqaTheme.rust)
                        .cornerRadius(10)
                    }
                }
                .padding(14)
                .background(LiviqaTheme.rust2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.rust.opacity(0.3), lineWidth: 1))

            case 2:
                VStack(spacing: 8) {
                    Text("Final confirmation. This action is irreversible.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LiviqaTheme.rust)

                    Button {
                        runErase()
                    } label: {
                        Group {
                            if isErasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Delete permanently")
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(LiviqaTheme.rust)
                        .cornerRadius(10)
                    }
                    .disabled(isErasing)

                    Button("Cancel") {
                        withAnimation { showDeleteConfirmStep = 0 }
                    }
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                    .disabled(isErasing)
                }
                .padding(14)
                .background(LiviqaTheme.rust2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.rust.opacity(0.3), lineWidth: 1))

            case 4:
                // Server erase failed — nothing was removed anywhere. Honest
                // failure + retry (T1: server FIRST, local wipe only after).
                VStack(spacing: 8) {
                    Text("The server couldn't confirm the deletion, so nothing was removed yet — not from Liviqa's servers and not from this device.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.rust)
                        .multilineTextAlignment(.center)
                    if let detail = appState.eraseServerError {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(LiviqaTheme.ink4)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        runErase()
                    } label: {
                        Group {
                            if isErasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Try again")
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(LiviqaTheme.rust)
                        .cornerRadius(10)
                    }
                    .disabled(isErasing)
                    Button("Cancel") {
                        withAnimation { showDeleteConfirmStep = 0 }
                    }
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                    .disabled(isErasing)
                }
                .padding(14)
                .background(LiviqaTheme.rust2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.rust.opacity(0.3), lineWidth: 1))

            default:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Your data has been deleted from Liviqa's servers and this device.")
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
            }
        }
    }

    /// T-DEL-01 + T1 GDPR ordering: erase SERVER-side first (POST /me/erase),
    /// wipe the device only after the server confirmed — a network failure can
    /// then never strand server data behind a success message. On failure the
    /// flow lands on the retryable error state; on success deleteAllData()
    /// signs out, so the root swaps to AuthView behind the confirmation.
    private func runErase() {
        guard !isErasing else { return }
        isErasing = true
        Task { @MainActor in
            defer { isErasing = false }
            let ok = await appState.eraseEverythingServerFirst()
            withAnimation { showDeleteConfirmStep = ok ? 3 : 4 }
        }
    }

    // MARK: Helpers

    private func settingsNavRow(icon: String, color: Color, label: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.lato(13))
                    .foregroundStyle(color)
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
