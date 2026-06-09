// MainTabView.swift — Root tab container · v04 2026-05-22
// v03: Settings (gear toolbar) and TokenWallet wired in.
// v04: Avatar tap → ProfileSheet (universal). Settings accessible from ProfileSheet footer.
// Design ref: Liviqa_App_UI_Aperture_v01_20260521.html (tab bar)
import SwiftUI

enum LiviqaTab: String, CaseIterable {
    case today, trends, wallet, care, journal

    var title: String {
        switch self {
        case .today:   return "Today"
        case .trends:  return "Trends"
        case .wallet:  return "Wallet"
        case .care:    return "Care"
        case .journal: return "Journal"
        }
    }

    // SF Symbols that approximate the mockup icons
    var symbol: String {
        switch self {
        case .today:   return "circle"
        case .trends:  return "chart.line.uptrend.xyaxis"
        case .wallet:  return "rectangle.stack"
        case .care:    return "bubble.left.and.bubble.right"
        case .journal: return "doc.text"
        }
    }

    var symbolFilled: String {
        switch self {
        case .today:   return "circle.fill"
        case .trends:  return "chart.line.uptrend.xyaxis"
        case .wallet:  return "rectangle.stack.fill"
        case .care:    return "bubble.left.and.bubble.right.fill"
        case .journal: return "doc.text.fill"
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
        return .today
    }()
    @State private var selectedNudge: Nudge?
    @State private var showProfile  = false   // ProfileSheet — universal avatar target
    @State private var nudgeProfileAnchor: ProfileSheet.Section? = nil
    @State private var joiningConsult: ConsultSummary? = nil   // accepted an incoming call
    @AppStorage("liviqaShowDemoChip") private var showDemoChip = false
    #if DEBUG
    @State private var debugOpenChat = false
    #endif

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
                case .today:
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
                            }
                        ))
                        .task { await appState.refreshFromHealth() }
                        .navigationDestination(item: $selectedNudge) { nudge in
                            NudgeDetailView(nudge: nudge).liviqaDetail()
                        }
                    }
                case .trends:
                    NavigationStack { hideNavBar(WeekInContextView()) }
                case .wallet:
                    NavigationStack { hideNavBar(WalletView()) }
                case .care:
                    NavigationStack { hideNavBar(MessagesView()) }
                case .journal:
                    JournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, appState.detailDepth == 0 ? 72 : 0)

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
        .task {
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_CHAT"] == "1" { debugOpenChat = true }
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
            // Poll for an incoming instant call (no push infra yet).
            while !Task.isCancelled {
                await appState.pollIncomingCall()
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(LiviqaTab.allCases, id: \.self) { item in
                Button {
                    tab = item
                    if item != .today { selectedNudge = nil }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab == item ? item.symbolFilled : item.symbol)
                            .font(.lato(20))
                        Text(item.title)
                            .font(.lato(10, tab == item ? .bold : .regular))
                            .tracking(0.2)
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
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(LiviqaTheme.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LiviqaTheme.line)
                .frame(height: 0.5)
        }
    }

}
