// MaudeApp.swift — Phase 1 entry point. Injects AppState; gates on session.
// Onboarding flow (A7.2): PrivacyDeclaration (once, FR-REG-01) →
// OnboardingFlowView (the designed 9-step flow: why → sign-in → Apple Health
// → Data for Good → name → Passport → sharing → backup → app lock → literacy
// → how it works → ready) → MainTabView. A returning signed-out user (gates
// already set) gets the restyled AuthView standalone, not the whole flow.
// v04 2026-08-12
import SwiftUI

@main
struct MaudeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    init() {
        // TESTPROD posture check (T1): a Release build that regressed any demo
        // gate crashes here, on the first launch — not in a review.
        ReleasePosture.verify()
    }
    #if DEBUG
    @State private var debugWallet = false
    @State private var debugIDP: IDProvider? = nil
    @State private var debugGlassLab = false
    @State private var debugDayLab = false
    @State private var debugMitIDPrompt = false
    @State private var debugIdentityVerify = false
    #endif

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

    // Face ID app lock (NFR-SEC): while enabled, the AppLockScreen overlays on
    // wake (cold launch + background→active). Reads UserDefaults directly at
    // init so a cold launch starts locked without a flash of content.
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var isLocked = UserDefaults.standard.bool(forKey: "appLockEnabled")
    /// True while iOS may be photographing the window (`.inactive`) — drives the
    /// app-switcher privacy cover. Separate from `isLocked`: covering the screen
    /// must never cost the user a Face ID prompt.
    @State private var isScreenObscured = false
    @Environment(\.scenePhase) private var scenePhase

    // Runtime theme (Midnight default) — flips every MaudeTheme.* token at the root.
    // Default to Paper — the Design System v2 ground (warm paper, ink, moss/clay).
    // Users can still switch to Midnight in Settings; the dynamic tokens flip the app.
    @AppStorage("maudeThemeMode") private var themeModeRaw = MaudeTheme.Mode.paper.rawValue
    private var themeMode: MaudeTheme.Mode { MaudeTheme.Mode(rawValue: themeModeRaw) ?? .midnight }

    /// The designed flow shows while any of its legacy gates are open — a
    /// fresh install AND the once-per-version replay both land here. It embeds
    /// sign-in as step 2 (auto-skipped for an already-signed-in replay).
    private var needsOnboardingFlow: Bool {
        !hasSeenHealthKitPrimer || !hasSeenDfGOnboarding
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenPrivacyDeclaration {
                    // Screen 1 — privacy declaration (first launch only, before
                    // anything else; FR-REG-01 regulatory — do not reorder).
                    PrivacyDeclarationView {
                        hasSeenPrivacyDeclaration = true
                    }
                } else if appState.session == nil && appState.isRestoringSession {
                    // Restoring a previous sign-in (Keychain token, revalidated by the
                    // backend) — calm launch progress, never a flash of the auth screen.
                    ZStack {
                        MaudeTheme.paper.ignoresSafeArea()
                        ProgressView().tint(MaudeTheme.ink)
                    }
                } else if needsOnboardingFlow {
                    // Screens 2…10 — the A7.2 designed flow (cover → … → ready).
                    // Completion sets ALL legacy gates so the existing
                    // version-replay logic keeps working unchanged.
                    OnboardingFlowView {
                        hasSeenHealthKitPrimer = true
                        hasSeenDfGOnboarding   = true
                        seenOnboardingVersion  = Self.currentOnboardingVersion
                    }
                } else if appState.session == nil {
                    // Returning signed-out user — the restyled sign-in, standalone.
                    AuthView()
                } else {
                    // Main app
                    MainTabView()
                }
            }
            .environment(appState)
            // Face ID app lock — minimal runtime overlay (blur-free, honest):
            // covers everything incl. the onboarding while locked.
            .overlay {
                if isLocked {
                    AppLockScreen { isLocked = false }
                } else if isScreenObscured {
                    // Privacy cover for the app-switcher snapshot. iOS photographs
                    // the window on `.inactive` — WITHOUT this, a locked phone's
                    // switcher still showed the citizen's readings (found by
                    // T-SEC-07, 2026-08-13). Cover only: no Face ID prompt here,
                    // so a system alert or share sheet never triggers an auth
                    // round-trip; the real lock still runs on background→active.
                    AppPrivacyCover()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if appLockEnabled { isLocked = true }
                    isScreenObscured = appLockEnabled
                case .inactive:
                    if appLockEnabled { isScreenObscured = true }
                case .active:
                    isScreenObscured = false
                @unknown default:
                    break
                }
            }
            #if DEBUG
            .fullScreenCover(isPresented: $debugWallet) {
                DfGWalletLoginView(onComplete: { _ in debugWallet = false },
                                   onCancel: { debugWallet = false })
            }
            .fullScreenCover(item: $debugIDP) { p in
                IDProviderLoginView(provider: p, onComplete: { debugIDP = nil }, onCancel: { debugIDP = nil })
            }
            .fullScreenCover(isPresented: $debugGlassLab) { GlassLabView() }
            .fullScreenCover(isPresented: $debugDayLab) {
                NavigationStack {
                    DayTimelineView(injectedSamples: [5.1,4.8,5.4,6.2,7.1,8.4,7.2,6.1,5.6,6.8,9.1,7.7,
                                                      6.4,5.9,5.2,4.7,5.0,6.3,7.0,6.6,5.8,5.3,5.1,4.9])
                        .background(MaudeTheme.paper.ignoresSafeArea())
                }
                .environment(appState)   // covers don't inherit the env automatically
            }
            // Onboarding satellites (MAUDE_ONB_STEP=mitid|identity)
            .fullScreenCover(isPresented: $debugMitIDPrompt) {
                MitIDPromptView(onCancel: { debugMitIDPrompt = false }) {
                    // The real linking use case the prompt fronts (FR-ING-14).
                    SundhedWebSessionView(
                        ingest: appState.supabase as? SundhedIngesting,
                        citizenId: appState.profile?.alias ?? appState.session?.userId.uuidString
                    )
                }
                .environment(appState)
            }
            .fullScreenCover(isPresented: $debugIdentityVerify) {
                IdentityVerifyView(onContinue: { _ in debugIdentityVerify = false },
                                   onBack: { debugIdentityVerify = false })
            }
            #endif
            .preferredColorScheme(themeMode.colorScheme)   // Paper (light) by default
            .task {
                // Session restore FIRST (before the debug hooks, so the restoring
                // flag always resolves): a valid Keychain token puts the tester
                // straight back in the app across cold launches. Resolves
                // instantly when no token is stored, so the hooks below and a
                // true first launch are not delayed.
                await appState.restoreSession()
                // FR-NOT-01/02 (A7.2 Area ⑧): re-schedule the local edition
                // loops from the persisted prefs on every launch. No-op until
                // notification permission is granted.
                EditionNotifications.resync()
                #if DEBUG
                // Design-exploration hook: open the Liquid Glass Lab (gallery).
                if ProcessInfo.processInfo.arguments.contains("-glassLab") {
                    hasSeenPrivacyDeclaration = true
                    debugGlassLab = true
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-dayLab") {
                    hasSeenPrivacyDeclaration = true
                    debugDayLab = true
                    return
                }
                // Snapshot hook (A7.2): force the onboarding flow open at a frame.
                // MAUDE_ONB_STEP=<0..10|declined|lock|literacy|mitid|identity>
                if let raw = ProcessInfo.processInfo.environment["MAUDE_ONB_STEP"] {
                    hasSeenPrivacyDeclaration = true
                    seenOnboardingVersion = Self.currentOnboardingVersion
                    isLocked = false
                    switch raw {
                    case "mitid":
                        // Keep the flow (cover) behind the sheet — MainTabView
                        // would fire the push-permission prompt over the shot.
                        hasSeenHealthKitPrimer = false; hasSeenDfGOnboarding = false
                        debugMitIDPrompt = true
                    case "identity":
                        hasSeenHealthKitPrimer = false; hasSeenDfGOnboarding = false
                        debugIdentityVerify = true
                    default:
                        // In-flow frames: open the flow; OnboardingFlowView reads
                        // the same env and jumps. Frames past sign-in need a
                        // session so step 2 doesn't intercept.
                        hasSeenHealthKitPrimer = false
                        hasSeenDfGOnboarding = false
                        if raw != "0", raw != "1", raw != "2", appState.session == nil {
                            appState.signInDemo()
                        }
                    }
                    return
                }
                // Snapshot hook: open the DfG Wallet login flow directly.
                if ProcessInfo.processInfo.environment["MAUDE_OPEN_WALLET"] == "1" {
                    hasSeenPrivacyDeclaration = true
                    debugWallet = true
                    return
                }
                switch ProcessInfo.processInfo.environment["MAUDE_OPEN_IDP"] {
                case "altid":  hasSeenPrivacyDeclaration = true; debugIDP = .altID; return
                case "eboks":  hasSeenPrivacyDeclaration = true; debugIDP = .eBoks; return
                case "igrant": hasSeenPrivacyDeclaration = true; debugIDP = .iGrant; return
                default: break
                }
                // Snapshot hook: show the DfG onboarding screen (signed-in, gates set).
                if ProcessInfo.processInfo.environment["MAUDE_SHOW_DFG_ONBOARDING"] == "1" {
                    hasSeenPrivacyDeclaration = true
                    hasSeenHealthKitPrimer = true
                    hasSeenDfGOnboarding = false
                    seenOnboardingVersion = Self.currentOnboardingVersion
                    if appState.session == nil { appState.signInDemo() }
                    return
                }
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
