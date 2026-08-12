// NotificationSettingsView.swift — "Calm by default" edition ladder · v02
// 2026-08-12 (A7.2 Area ⑧, FR-NOT-01). Rebuilt from b-extra.jsx NotifSettings:
// verdict ("Liviqa speaks rarely — only when it matters.") + five toggle rows
// (morning edition / earned attention / evening wind-down / care messages /
// study & consent activity, the last default-OFF) + the on-device lock footer.
// Replaces the v01 metric-category model (timing radio + 5 category toggles +
// quiet hours). Quiet hours were dropped WITH the model: the edition ladder is
// time-shaped by design (one morning note, one closing note after 21:00, at
// most one earned-attention alert a day) — a separate quiet window had nothing
// left to silence.
//
// Prefs are PERSISTED (@AppStorage — the old v01 toggles were throwaway @State)
// and wired to real scheduling where it exists: morning/evening resync actual
// local notifications (EditionNotifications); earned attention and care/study
// store the preference honestly (see the honesty ledger in EditionNotifications).
// FR-NDG-06: "At most one a day" is the engine's cadence guarantee, restated
// verbatim; notification content is allow-listed template text only.
import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState

    // The five designed rows — persisted. Defaults mirror the canvas:
    // everything on except study & consent activity.
    @AppStorage(EditionNotifications.Pref.morning) private var morningOn = true
    @AppStorage(EditionNotifications.Pref.earned)  private var earnedOn  = true
    @AppStorage(EditionNotifications.Pref.evening) private var eveningOn = true
    @AppStorage(EditionNotifications.Pref.care)    private var careOn    = true
    @AppStorage(EditionNotifications.Pref.study)   private var studyOn   = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Verdict block (design: bell icon · "Calm by default") ──
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(LiviqaTheme.fjordBright)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Calm by default").uppercased())
                            .font(.liviqaKicker(10)).tracking(1.2)
                            .foregroundStyle(LiviqaTheme.ink3)
                        Text("Liviqa speaks rarely — only when it matters.")
                            .font(.liviqaSerif(21)).kerning(-0.2).lineSpacing(2)
                            .foregroundStyle(LiviqaTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 6)

                // ── The edition ladder ──
                VStack(spacing: 0) {
                    prefRow(String(localized: "Your morning edition"),
                            String(localized: "One quiet note when today's edition is ready"),
                            isOn: $morningOn, first: true)
                    prefRow(String(localized: "Earned attention"),
                            String(localized: "At most one a day, and only when something in your own numbers is worth a look"),
                            isOn: $earnedOn)
                    prefRow(String(localized: "Evening wind-down"),
                            String(localized: "A short closing note after 21:00"),
                            isOn: $eveningOn)
                    prefRow(String(localized: "Care messages"),
                            String(localized: "When your nurse or coach writes to you"),
                            isOn: $careOn)
                    prefRow(String(localized: "Study & consent activity"),
                            String(localized: "When a share is viewed or a study updates"),
                            isOn: $studyOn)
                }
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))

                // ── On-device lock footer (design verbatim) ──
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: "lock.fill")
                        .font(.lato(13))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Notifications are built on this phone from your own data — their content never leaves it.")
                        .font(.lato(11.5)).lineSpacing(1.5)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))

                // Honest status line (not in the canvas, required by the honesty
                // rail): morning/evening notes are scheduled on this phone today;
                // the other three apply when their channels launch.
                Text("Morning and evening notes are scheduled on this phone. Earned attention, care and study alerts apply when those channels launch.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Any toggle change → re-schedule the real local loops from the stored
        // prefs. Turning a loop ON also (re)requests permission — iOS only ever
        // prompts once; afterwards this is a no-op.
        .onChange(of: morningOn) { _, on in prefsChanged(requestPermission: on) }
        .onChange(of: eveningOn) { _, on in prefsChanged(requestPermission: on) }
        .onChange(of: earnedOn)  { _, _  in prefsChanged(requestPermission: false) }
        .onChange(of: careOn)    { _, _  in prefsChanged(requestPermission: false) }
        .onChange(of: studyOn)   { _, _  in prefsChanged(requestPermission: false) }
    }

    private func prefsChanged(requestPermission: Bool) {
        if requestPermission { appState.requestPushAuthorization() }
        EditionNotifications.resync()
    }

    // MARK: — One ladder row

    private func prefRow(_ title: String, _ sub: String,
                         isOn: Binding<Bool>, first: Bool = false) -> some View {
        VStack(spacing: 0) {
            if !first { Divider().overlay(LiviqaTheme.line2).padding(.leading, 14) }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.lato(14, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text(sub)
                        .font(.lato(11.5)).lineSpacing(1.5)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .tint(LiviqaTheme.moss)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
    }
}

// MARK: — Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .environment(AppState())
}
