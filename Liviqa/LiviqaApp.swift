// LiviqaApp.swift — Phase 1 entry point. Injects AppState; gates on session.
// Onboarding flow: PrivacyDeclaration (once) → Auth → HealthKitPrimer (once) → DfGOnboarding (once) → MainTabView
// v03 2026-05-22
import SwiftUI

@main
struct LiviqaApp: App {
    @State private var appState = AppState()

    // One-time flags — persist across launches
    @AppStorage("hasSeenPrivacyDeclaration") private var hasSeenPrivacyDeclaration = false
    @AppStorage("hasSeenHealthKitPrimer")    private var hasSeenHealthKitPrimer    = false
    @AppStorage("hasSeenDfGOnboarding")      private var hasSeenDfGOnboarding      = false

    // Runtime theme (Midnight default) — flips every LiviqaTheme.* token at the root.
    @AppStorage("liviqaThemeMode") private var themeModeRaw = LiviqaTheme.Mode.midnight.rawValue
    private var themeMode: LiviqaTheme.Mode { LiviqaTheme.Mode(rawValue: themeModeRaw) ?? .midnight }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenPrivacyDeclaration {
                    // Screen 1 — privacy declaration (first launch only, before auth)
                    PrivacyDeclarationView {
                        hasSeenPrivacyDeclaration = true
                    }
                } else if appState.session == nil {
                    // Screen 2 — sign in / demo mode
                    AuthView()
                } else if !hasSeenHealthKitPrimer {
                    // Screen 3 — HealthKit primer (once, after first sign-in)
                    HealthKitPrimerView {
                        // Connect → request HealthKit permissions (TODO: add HKHealthStore call)
                        hasSeenHealthKitPrimer = true
                    } onSkip: {
                        hasSeenHealthKitPrimer = true
                    }
                } else if !hasSeenDfGOnboarding {
                    // Screen 4 — consent governance intro (once, after HealthKit)
                    DfGOnboardingView {
                        hasSeenDfGOnboarding = true
                    }
                } else {
                    // Main app
                    MainTabView()
                }
            }
            .environment(appState)
            .preferredColorScheme(themeMode.colorScheme)   // Midnight (dark) by default
            #if DEBUG
            .task {
                // Snapshot/UI-test hook: jump straight into demo Today (skips onboarding+auth).
                if ProcessInfo.processInfo.arguments.contains("-uiTestAutoDemo") {
                    hasSeenPrivacyDeclaration = true
                    hasSeenHealthKitPrimer = true
                    hasSeenDfGOnboarding = true
                    if appState.session == nil { appState.signInDemo() }
                }
            }
            #endif
        }
    }
}
