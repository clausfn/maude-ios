// SettingsView.swift — Profile · Consent · Regulatory v02 · 2026-05-22
// Three zones: My Data (profile + connected sources) / Consent & Sharing (audit trail)
// / Regulatory (disclaimer, privacy policy, delete). This is the trust layer.
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirmStep: Int = 0   // 0=idle 1=warn 2=confirm 3=done
    @State private var showExportDone = false

    // Runtime display options (drive the locked design tokens at the root).
    // Default MUST match LiviqaApp's default (Paper) or the picker shows the wrong
    // selection on a fresh install.
    @AppStorage("liviqaThemeMode")    private var themeModeRaw = LiviqaTheme.Mode.paper.rawValue
    @AppStorage("liviqaReduceMotion") private var reduceMotion = false
    @AppStorage("liviqaShowDemoChip") private var showDemoChip = false

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

            // Export button
            Button {
                withAnimation { showExportDone = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showExportDone = false }
                }
            } label: {
                HStack {
                    Image(systemName: showExportDone ? "checkmark.circle.fill" : "square.and.arrow.up")
                        .foregroundStyle(showExportDone ? LiviqaTheme.moss : LiviqaTheme.ink3)
                    Text(showExportDone ? "Export ready in Files" : "Export all my Liviqa data")
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.ink2)
                    Spacer()
                }
                .padding(14)
                .background(LiviqaTheme.paper2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
            }
        }
    }

    private var profileRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LiviqaTheme.invertBG)
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiviqaTheme.invertFG)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.profile?.displayName ?? "Demo User")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text("Device-stored only · never uploaded")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
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
                    Text("This will permanently delete all local Liviqa data, including your health records, vault files, journal entries, and nudge history. It cannot be undone.")
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

                    Button("Delete permanently") {
                        withAnimation { showDeleteConfirmStep = 3 }
                        // TODO: call AppState.deleteAllData()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(LiviqaTheme.rust)
                    .cornerRadius(10)

                    Button("Cancel") {
                        withAnimation { showDeleteConfirmStep = 0 }
                    }
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                }
                .padding(14)
                .background(LiviqaTheme.rust2)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.rust.opacity(0.3), lineWidth: 1))

            default:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("All local data deleted.")
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
            }
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

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
}
