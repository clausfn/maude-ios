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
                        .task { await appState.refreshFromHealth() }
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
        .fullScreenCover(item: $joiningConsult) { consult in
            NavigationStack { ConsultView(consult: consult) }
        }
        .task {
            // App-level one-time ingest so every tab (not just Home) has the user's
            // real derived data — Home also refreshes on appear for freshness.
            if !didInitialRefresh {
                didInitialRefresh = true
                await appState.refreshFromHealth()
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
                Button {
                    tab = item
                    if item != .home { selectedNudge = nil }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab == item ? item.symbolFilled : item.symbol)
                            .font(.lato(20))
                        Text(item.title)
                            .font(.lato(10, tab == item ? .bold : .regular))
                            .tracking(0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        // Active moss dot
                        Circle()
                            .fill(tab == item ? LiviqaTheme.moss : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(tab == item ? LiviqaTheme.ink : LiviqaTheme.ink3)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        // Floating Liquid-Glass capsule (A6). Opaque LiviqaTheme.paper2 fallback when
        // Reduce Transparency / Increase Contrast is on, so label contrast is preserved.
        .background {
            if useSolidBar {
                Capsule().fill(LiviqaTheme.paper2)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay {
            Capsule().strokeBorder(useSolidBar ? LiviqaTheme.ink3 : LiviqaTheme.line,
                                   lineWidth: useSolidBar ? 1 : 0.5)
        }
        // Lift the capsule off the canvas (no shadow on the high-contrast solid bar).
        .shadow(color: LiviqaTheme.cardShadow, radius: useSolidBar ? 0 : 12, y: useSolidBar ? 0 : 4)
        // Detach from the screen edges so it reads as a floating surface.
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        // Cap growth so the six labels never wrap ("Settings" → "Setting s").
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

}
