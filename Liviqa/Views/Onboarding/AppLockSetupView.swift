// AppLockSetupView.swift — Face ID app lock (NFR-SEC) · v01 2026-08-12
// Two pieces, both small and honest:
//  • AppLockSetupView — the onboarding offer ("Lock Liviqa to your face."),
//    also reachable later from Settings → My data. Enabling verifies the
//    device can actually evaluate biometrics first.
//  • AppLockScreen — the minimal runtime lock (cover palette + retry).
//    No passcode UI of our own: `.deviceOwnerAuthentication` lets iOS present
//    its own system passcode fallback. LiviqaApp overlays it on scenePhase
//    background→active while @AppStorage("appLockEnabled") is on.
import SwiftUI
import LocalAuthentication

struct AppLockSetupView: View {
    var onDone: () -> Void

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var unavailableNote: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LiviqaTheme.moss2)
                    .frame(width: 84, height: 84)
                Image(systemName: "faceid")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .accessibilityHidden(true)

            Text("Lock Liviqa to your face.")
                .font(.liviqaSerif(26, .bold, relativeTo: .title2))
                .kerning(LiviqaTheme.Tracking.h1)
                .foregroundStyle(LiviqaTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 22)

            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.moss)
                .frame(width: 44, height: 3)
                .padding(.top, 12)
                .accessibilityHidden(true)

            Text("Your health lives on this phone — so it opens only for you. Liviqa asks for Face ID each time it wakes. No passcode leaves the device.")
                .font(.lato(14))
                .lineSpacing(4)
                .foregroundStyle(LiviqaTheme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .padding(.horizontal, 8)

            if let unavailableNote {
                Text(unavailableNote)
                    .font(.lato(12))
                    .foregroundStyle(LiviqaTheme.clayText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            Spacer()

            VStack(spacing: 10) {
                OnbPrimaryButton(label: String(localized: "Turn on Face ID"), icon: "faceid") {
                    enableLock()
                }
                OnbQuietButton(label: String(localized: "Not now"), action: onDone)
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 20)
    }

    private func enableLock() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unavailableNote = String(localized: "Face ID isn't available on this device right now. You can turn the lock on later in Settings.")
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: String(localized: "Confirm it's you to turn on the app lock.")) { success, _ in
            Task { @MainActor in
                if success {
                    appLockEnabled = true
                    onDone()
                }
                // Cancelled/failed: stay on the offer — no error voice needed.
            }
        }
    }
}

// MARK: - Runtime lock screen

/// Minimal blur + retry lock. Reuses the cover palette; auto-prompts on appear.
struct AppLockScreen: View {
    var onUnlock: () -> Void

    @State private var authFailed = false
    @State private var inFlight = false

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Color(hex: 0x0E5F5A), location: 0),
                .init(color: Color(hex: 0x0B3F4E), location: 0.52),
                .init(color: Color(hex: 0x122C46), location: 1)
            ], startPoint: UnitPoint(x: 0.31, y: 0.04),
               endPoint: UnitPoint(x: 0.69, y: 0.96))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                OnboardingIrisMark(size: 66)
                Text("Liviqa is locked")
                    .font(.liviqaSerif(24, .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                Text("Unlock with Face ID to open your edition.")
                    .font(.lato(13.5))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 6)
                Spacer()
                Button { attempt() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid").font(.system(size: 16, weight: .medium))
                        Text(authFailed ? String(localized: "Try again")
                                        : String(localized: "Unlock"))
                            .font(.lato(15, .bold))
                    }
                    .foregroundStyle(Color(hex: 0x122C46))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 30)
                .padding(.bottom, 28)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { attempt() }
    }

    private func attempt() {
        guard !inFlight else { return }
        inFlight = true
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Biometrics/passcode unavailable (should not normally happen once
            // enabled) — fail open rather than brick the user out of their data.
            inFlight = false
            onUnlock()
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: String(localized: "Unlock Liviqa.")) { success, _ in
            Task { @MainActor in
                inFlight = false
                if success { onUnlock() } else { authFailed = true }
            }
        }
    }
}
