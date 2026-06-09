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

    // Onboarding-version gate. The consent + start flow is skipped once its
    // `hasSeen*` flags are set, so an existing install never sees it again — which
    // is why it "stopped starting up". Bumping `currentOnboardingVersion` replays
    // the whole start flow ONCE for everyone (and re-prompts HealthKit connect).
    @AppStorage("onboardingVersion") private var seenOnboardingVersion = 0
    static let currentOnboardingVersion = 1

    // Runtime theme (Midnight default) — flips every LiviqaTheme.* token at the root.
    // Default to Paper — the Design System v2 ground (warm paper, ink, moss/clay).
    // Users can still switch to Midnight in Settings; the dynamic tokens flip the app.
    @AppStorage("liviqaThemeMode") private var themeModeRaw = LiviqaTheme.Mode.paper.rawValue
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
                        // Connect → switch to real on-device Health data and request read
                        // authorization now (FR-ING-01/02). The system permission sheet
                        // appears; ingestion + nudges then refresh against the user's
                        // real HealthKit data. (Skip stays on demo data — never an error.)
                        appState.dataProviderKind = .healthKit
                        Task { await appState.refreshFromHealth() }
                        hasSeenHealthKitPrimer = true
                    } onSkip: {
                        // FR-ING-02: skipped authorization routes to demo data, not an error.
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
            .preferredColorScheme(themeMode.colorScheme)   // Paper (light) by default
            .task {
                #if DEBUG
                // Snapshot/UI-test hook: jump straight into demo Today (skips onboarding+auth).
                if ProcessInfo.processInfo.arguments.contains("-uiTestAutoDemo") {
                    hasSeenPrivacyDeclaration = true
                    hasSeenHealthKitPrimer = true
                    hasSeenDfGOnboarding = true
                    seenOnboardingVersion = Self.currentOnboardingVersion
                    if appState.session == nil { appState.signInDemo() }
                    return
                }
                #endif
                // Reinstate the consent + start flow once after an onboarding revision.
                if seenOnboardingVersion < Self.currentOnboardingVersion {
                    hasSeenPrivacyDeclaration = false
                    hasSeenHealthKitPrimer    = false
                    hasSeenDfGOnboarding      = false
                    seenOnboardingVersion     = Self.currentOnboardingVersion
                }
            }
        }
    }
}
