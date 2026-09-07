// AccountSecurityView.swift — Account & security · v01 2026-08-12 (A7.2 Area ⑧)
// Anatomy from b-integrations.jsx ScrAccount ("Account & security (FR-AUTH)"):
// verdict ("Your account — held by DfG" / "Only your name and email live here.")
// → account card (signed-in row · Face ID app lock toggle · backup status ·
// recovery contact · sign out) → the held-vs-on-device two-column card → the
// DfG wellness footer (FR-REG-01 framing, single-sourced in RegulatoryCopy).
// Pushed from Settings (MY DATA zone); DEBUG hook MAUDE_OPEN_ACCOUNT=1.
//
// HONESTY deviations from the canvas (all deliberate, census-flagged):
//  • "Signed in with Apple" → "Signed in": the session model carries no
//    provider, and claiming Apple for an email session would be false.
//  • Backup row: there is NO backup engine yet — the row shows the posture the
//    user chose in onboarding and says plainly that backups aren't running.
//    The canvas' "Encrypted iCloud backup is on" ships only with the engine.
//  • Recovery contact: no storage or backend endpoint exists — the row opens an
//    honest "coming soon" note instead of pretending to save a contact.
// The Face ID toggle reads the SAME @AppStorage("appLockEnabled") pref as the
// Settings toggle and the MaudeApp scene-phase overlay (NFR-SEC-08, Area ① —
// wrapped here, not rebuilt).
import SwiftUI
import LocalAuthentication

struct AccountSecurityView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("backupPreference") private var backupPrefRaw = BackupPreference.onDevice.rawValue
    @State private var appLockNote: String? = nil
    @State private var showRecoveryNote = false
    @State private var showDelete = false
    @State private var isSigningOut = false

    private var backupPref: BackupPreference {
        BackupPreference(rawValue: backupPrefRaw) ?? .onDevice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Verdict block ──
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "key")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(MaudeTheme.fjordBright)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Your account — held by DfG").uppercased())
                            .font(.maudeKicker(10)).tracking(1.2)
                            .foregroundStyle(MaudeTheme.ink3)
                        Text("Only your name and email live here.")
                            .font(.maudeSerif(21)).kerning(-0.2).lineSpacing(2)
                            .foregroundStyle(MaudeTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 6)

                // ── The account card ──
                VStack(spacing: 0) {
                    // 1 · Signed in (honest: no provider claim without a provider field)
                    accountRow(first: true) {
                        rowText(String(localized: "Signed in"),
                                appState.session?.email ?? String(localized: "Demo session — no account"))
                    }

                    // 2 · Face ID app lock — same pref + gate as Settings (NFR-SEC-08)
                    divider
                    HStack(alignment: .center, spacing: 12) {
                        rowText(String(localized: "Face ID app lock"),
                                String(localized: "Required each time Maude wakes"))
                        Spacer()
                        Toggle("", isOn: Binding(
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
                        ))
                        .tint(MaudeTheme.moss)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    if let appLockNote {
                        Text(appLockNote)
                            .font(.caption)
                            .foregroundStyle(MaudeTheme.clayText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.bottom, 10)
                    }

                    // 3 · Backup — HONEST status (no backup engine exists yet)
                    divider
                    accountRow {
                        rowText(String(localized: "Backup"), backupStatusLine)
                        Spacer()
                        if backupPref == .onDevice {
                            HStack(spacing: 6) {
                                Circle().fill(MaudeTheme.moss).frame(width: 6, height: 6)
                                Text("On device")
                                    .font(.lato(11.5, .bold))
                                    .foregroundStyle(MaudeTheme.moss)
                            }
                        } else {
                            Text("Coming soon")
                                .font(.lato(11.5, .bold))
                                .foregroundStyle(MaudeTheme.ink4)
                        }
                    }

                    // 4 · Recovery contact — honest coming-soon note
                    divider
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showRecoveryNote.toggle() }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            rowText(String(localized: "Recovery contact"),
                                    String(localized: "Add a trusted person to help you back in"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(MaudeTheme.line)
                                .rotationEffect(.degrees(showRecoveryNote ? 90 : 0))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    if showRecoveryNote {
                        Text("Coming soon — recovery contacts arrive together with account recovery. There is nothing to set up yet.")
                            .font(.caption)
                            .foregroundStyle(MaudeTheme.ink3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.bottom, 12)
                    }

                    // 5 · Sign out — real; local data files stay on the device
                    divider
                    Button {
                        guard !isSigningOut else { return }
                        isSigningOut = true
                        Task { @MainActor in
                            await appState.signOut()
                            isSigningOut = false
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign out")
                                    .font(.lato(14, .semibold))
                                    .foregroundStyle(MaudeTheme.rust)
                                Text("Your on-device data stays on this phone")
                                    .font(.lato(11.5))
                                    .foregroundStyle(MaudeTheme.ink3)
                            }
                            Spacer()
                            if isSigningOut {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(MaudeTheme.line)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                }
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

                // ── What we hold vs what stays here ──
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "What we hold vs what stays here").uppercased())
                        .font(.maudeKicker(10)).tracking(1.2)
                        .foregroundStyle(MaudeTheme.ink3)
                    HStack(spacing: 10) {
                        heldColumn(String(localized: "IN YOUR ACCOUNT"),
                                   String(localized: "Name · email · consent receipts"),
                                   tint: MaudeTheme.ink3, border: MaudeTheme.line)
                        heldColumn(String(localized: "ON THIS PHONE ONLY"),
                                   String(localized: "Every health reading, always"),
                                   tint: MaudeTheme.moss, border: MaudeTheme.moss3)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaudeTheme.moss2.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.moss3, lineWidth: 1))

                // ── Delete lives under Account (design: ScrDeleteData back='Account') ──
                Button { showDelete = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.lato(13))
                            .foregroundStyle(MaudeTheme.rust)
                        Text("Delete all my data")
                            .font(.lato(14, .semibold))
                            .foregroundStyle(MaudeTheme.rust)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(MaudeTheme.line)
                    }
                    .padding(14)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.rust.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // ── DfG wellness footer (FR-REG-01 framing — single-sourced) ──
                Text(RegulatoryCopy.dfgWellnessFooter)
                    .font(.lato(12)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
        .navigationTitle("Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: $showDelete) { DeleteDataView() }
    }

    /// Backup sub-line — states only what is true today.
    private var backupStatusLine: String {
        switch backupPref {
        case .onDevice:
            return String(localized: "Your data lives on this phone — no cloud copy exists")
        case .iCloud:
            return String(localized: "iCloud chosen — the backup engine is coming soon; nothing has been backed up yet")
        case .sovereign:
            return String(localized: "Sovereign cloud chosen — coming soon; nothing has been backed up yet")
        }
    }

    // MARK: — Small builders

    private var divider: some View {
        Divider().overlay(MaudeTheme.line2).padding(.leading, 14)
    }

    private func accountRow(first: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) { content() }
            .padding(.horizontal, 14).padding(.vertical, 13)
    }

    private func rowText(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.lato(14, .semibold))
                .foregroundStyle(MaudeTheme.ink)
            Text(sub)
                .font(.lato(11.5)).lineSpacing(1.5)
                .foregroundStyle(MaudeTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heldColumn(_ kicker: String, _ body: String, tint: Color, border: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker)
                .font(.maudeKicker(9)).tracking(0.8)
                .foregroundStyle(tint)
            Text(body)
                .font(.lato(12.5)).lineSpacing(1.5)
                .foregroundStyle(MaudeTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
    }
}

// MARK: — Preview

#Preview {
    NavigationStack {
        AccountSecurityView()
    }
    .environment(AppState())
}
