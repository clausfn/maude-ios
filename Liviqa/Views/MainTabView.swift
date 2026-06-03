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

    var body: some View {
        ZStack(alignment: .bottom) {
            LiviqaTheme.paper.ignoresSafeArea()

            Group {
                switch tab {
                case .today:
                    NavigationStack {
                        TodayView(
                            nudges: appState.nudges,
                            displayName: appState.profile?.displayName,
                            isDemoData: appState.isDemoData,
                            onOpen: { nudge in selectedNudge = nudge },
                            onCalibrate: { anchor in
                                nudgeProfileAnchor = anchor
                                showProfile = true
                            }
                        )
                        .task { await appState.refreshFromHealth() }
                        .navigationDestination(item: $selectedNudge) { nudge in
                            NudgeDetailView(nudge: nudge)
                        }
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                avatarButton
                            }
                        }
                    }
                case .trends:
                    NavigationStack {
                        WeekInContextView()
                            .toolbar { ToolbarItem(placement: .automatic) { avatarButton } }
                    }
                case .wallet:
                    NavigationStack {
                        WalletView()
                            .toolbar { ToolbarItem(placement: .automatic) { avatarButton } }
                    }
                case .care:
                    NavigationStack {
                        MessagesView()
                            .toolbar { ToolbarItem(placement: .automatic) { avatarButton } }
                    }
                case .journal:
                    JournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)

            tabBar
        }
        .sheet(isPresented: $showProfile, onDismiss: { nudgeProfileAnchor = nil }) {
            ProfileSheet(openSection: nudgeProfileAnchor)
        }
    }

    // MARK: - Avatar button (universal)

    private var avatarButton: some View {
        Button {
            nudgeProfileAnchor = nil
            showProfile = true
        } label: {
            ZStack {
                Circle()
                    .fill(LiviqaTheme.invertBG)
                    .frame(width: 32, height: 32)
                Text(profileInitials)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiviqaTheme.invertFG)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("avatarButton")
        .accessibilityLabel("Profile and settings")
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

    private var profileInitials: String {
        let name = appState.profile?.displayName ?? "C"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
