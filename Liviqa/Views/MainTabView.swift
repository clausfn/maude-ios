// MainTabView.swift — Root tab container · v04 2026-05-22
// v03: Settings (gear toolbar) and TokenWallet wired in.
// v04: Avatar tap → ProfileSheet (universal). Settings accessible from ProfileSheet footer.
// Design ref: Liviqa_App_UI_Aperture_v01_20260521.html (tab bar)
import SwiftUI

// Information architecture: Home · Insights · Care · Journal · Privacy · Settings.
// Care (clinician messaging + video consult) is a first-class tab so it's directly
// discoverable; it's also still reachable from the profile sheet.
enum LiviqaTab: String, CaseIterable {
    case home, insights, care, journal, privacy, settings

    var title: String {
        switch self {
        case .home:     return String(localized: "Home")
        case .insights: return String(localized: "Insights")
        case .care:     return String(localized: "Care")
        case .journal:  return String(localized: "Journal")
        case .privacy:  return String(localized: "Privacy")
        case .settings: return String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .home:     return "circle"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .care:     return "bubble.left.and.bubble.right"
        case .journal:  return "doc.text"
        case .privacy:  return "lock.shield"
        case .settings: return "gearshape"
        }
    }

    var symbolFilled: String {
        switch self {
        case .home:     return "circle.fill"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .care:     return "bubble.left.and.bubble.right.fill"
        case .journal:  return "doc.text.fill"
        case .privacy:  return "lock.shield.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var tab: LiviqaTab = {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["LIVIQA_TAB"],
           let t = LiviqaTab(rawValue: raw) { return t }
        #endif
        return .home
    }()
    @State private var selectedNudge: Nudge?
    @State private var showProfile  = false   // ProfileSheet — universal avatar target
    @State private var nudgeProfileAnchor: ProfileSheet.Section? = nil
    @State private var joiningConsult: ConsultSummary? = nil   // accepted an incoming call
    @AppStorage("liviqaShowDemoChip") private var showDemoChip = false
    @State private var didInitialRefresh = false
    // Liquid Glass (A6): honour Reduce Transparency / Increase Contrast with an opaque fallback.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("liquidGlass") private var glassOn = true
    @Namespace private var tabGlass   // glides the magnifier lens between tabs
    #if DEBUG
    @State private var debugOpenChat = false
    @State private var debugOpenThread = false
    #endif

    /// The connect-Apple-Health hint, plus a DEBUG-only force flag so the banner
    /// can be screenshot-verified on the Simulator (where the provider is `.mock`).
    private var showConnectHintResolved: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["LIVIQA_FORCE_HINT"] == "1" { return true }
        #endif
        return appState.showConnectHealthHint
    }

    private func hideNavBar<V: View>(_ v: V) -> some View {
        #if os(iOS)
        return v.toolbar(.hidden, for: .navigationBar)
        #else
        return v
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LiviqaTheme.paper.ignoresSafeArea()

            Group {
                switch tab {
                case .home:
                    NavigationStack {
                        hideNavBar(TodayView(
                            nudges: appState.nudges,
                            displayName: appState.profile?.displayName,
                            isDemoData: appState.isDemoData && showDemoChip,
                            signals: appState.todaySignals,
                            onOpen: { nudge in selectedNudge = nudge },
                            onCalibrate: { anchor in
                                nudgeProfileAnchor = anchor
                                appState.showProfileSheet = true
                            },
                            showConnectHint: showConnectHintResolved,
                            onOpenSettings: { tab = .settings }
                        ))
                        // Health refresh runs from the app-level one-time `.task`
                        // below — NOT re-fired on every Home appearance, which used
                        // to race (and drop) the user's tab tap (FB-AJR9AqEk).
                        .navigationDestination(item: $selectedNudge) { nudge in
                            NudgeDetailView(nudge: nudge).liviqaDetail()
                        }
                    }
                case .insights:
                    NavigationStack { hideNavBar(WeekInContextView()) }
                case .care:
                    NavigationStack { MessagesView() }
                case .journal:
                    JournalView()
                case .privacy:
                    NavigationStack { hideNavBar(WalletView()) }
                case .settings:
                    NavigationStack { SettingsView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, appState.detailDepth == 0 ? 96 : 0)

            if appState.detailDepth == 0 {
                tabBar
            }

            // Incoming instant call (a clinician started a consult) — consent-first.
            if let incoming = appState.incomingConsult, joiningConsult == nil {
                IncomingCallView(
                    consult: incoming,
                    onJoin: { joiningConsult = incoming; appState.dismissIncoming() },
                    onDecline: { appState.dismissIncoming() }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.incomingConsult?.id)
        #if DEBUG
        .sheet(isPresented: $debugOpenChat) { ChatView(nudges: appState.nudges) }
        .fullScreenCover(isPresented: $debugOpenThread) {
            NavigationStack {
                MessageThreadView(recipientId: "care-nurse", title: "Diabetes nurse", subtitle: "Endocrinology")
            }
        }
        .task {
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_CHAT"] == "1" { debugOpenChat = true }
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_THREAD"] == "1" { debugOpenThread = true }
            // UC-RSCH deterministic screenshots: SHOW_RESEARCH=1 → Home card (s09);
            // OPEN_STUDY=1 → consent (s10); OPEN_STUDY=joined → joined (s11).
            let study = ProcessInfo.processInfo.environment["LIVIQA_OPEN_STUDY"]
            if ProcessInfo.processInfo.environment["LIVIQA_SHOW_RESEARCH"] == "1" || study != nil {
                appState.researchOpportunity = MockData.demoStudy
            }
            if study != nil { appState.showStudyConsent = true }
        }
        #endif
        .sheet(isPresented: Binding(
            get: { appState.showAssistant },
            set: { appState.showAssistant = $0 }
        )) {
            ChatView(nudges: appState.nudges)
        }
        .sheet(isPresented: Binding(
            get: { showProfile || appState.showProfileSheet },
            set: { open in
                if !open {
                    showProfile = false
                    appState.showProfileSheet = false
                    nudgeProfileAnchor = nil
                }
            }
        )) {
            ProfileSheet(openSection: nudgeProfileAnchor)
        }
        .sheet(isPresented: Binding(
            get: { appState.showStudyConsent },
            set: { appState.showStudyConsent = $0 }
        )) {
            let startJoined: Bool = {
                #if DEBUG
                return ProcessInfo.processInfo.environment["LIVIQA_OPEN_STUDY"] == "joined"
                #else
                return false
                #endif
            }()
            StudyConsentView(study: appState.researchOpportunity ?? MockData.demoStudy,
                             startJoined: startJoined)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $joiningConsult) { consult in
            NavigationStack { ConsultView(consult: consult) }
        }
        .task {
            // App-level one-time ingest so every tab (not just Home) has the user's
            // real derived data — Home also refreshes on appear for freshness.
            if !didInitialRefresh {
                didInitialRefresh = true
                await appState.refreshFromHealth()
                // Register for push reminders once signed in — but never during
                // automated snapshots/UI tests (the system prompt would block them).
                if !ProcessInfo.processInfo.arguments.contains("-uiTestAutoDemo") {
                    appState.requestPushAuthorization()
                }
            }
        }
        .task {
            // Poll for an incoming instant call (no push infra yet).
            while !Task.isCancelled {
                await appState.pollIncomingCall()
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
    }

    /// Reduce Transparency or Increase Contrast → opaque bar instead of glass.
    private var useSolidBar: Bool { reduceTransparency || contrast == .increased }

    private var tabBar: some View {
        HStack {
            ForEach(LiviqaTab.allCases, id: \.self) { item in
                let active = tab == item
                Button {
                    // Spring so the magnifier lens glides to the new tab (still under Reduce Motion).
                    withAnimation(glassOn && !reduceMotion ? .spring(response: 0.34, dampingFraction: 0.82) : nil) {
                        tab = item
                    }
                    if item != .home { selectedNudge = nil }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: active ? item.symbolFilled : item.symbol)
                            .font(.lato(active && glassOn ? 21 : 20))
                            .scaleEffect(active && glassOn ? 1.06 : 1)   // magnify the active tab
                        Text(item.title)
                            .font(.lato(10, active ? .bold : .regular))
                            .tracking(0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        // Active moss dot — kept only when the lens is OFF (flag off = today's look).
                        Circle()
                            .fill(active && !glassOn ? LiviqaTheme.moss : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(active ? LiviqaTheme.ink : LiviqaTheme.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    // The gliding translucent magnifier lens behind the active tab.
                    .background {
                        if active && glassOn {
                            MagnifierLens()
                                .matchedGeometryEffect(id: "tabMagnifier", in: tabGlass)
                                .padding(.horizontal, 3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        // Floating capsule — three-tier ladder (LiviqaBarGlass): real Liquid Glass on
        // iOS 26 (flag on) → `.ultraThinMaterial` on iOS 17–25 → opaque paper2 under
        // Reduce Transparency / Increase Contrast, so label contrast is preserved.
        .liviqaBarGlass(solid: useSolidBar)
        // Detach from the screen edges so it reads as a floating surface.
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        // Cap growth so the six labels never wrap ("Settings" → "Setting s").
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

}
