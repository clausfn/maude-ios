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

/// Collects each tab's slot rect (in the bar's coordinate space) so a single
/// travelling lens can be positioned over the selection and slide between slots.
private struct TabFrameKey: PreferenceKey {
    static let defaultValue: [LiviqaTab: CGRect] = [:]
    static func reduce(value: inout [LiviqaTab: CGRect], nextValue: () -> [LiviqaTab: CGRect]) {
        value.merge(nextValue()) { _, new in new }
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
    @State private var tabFrames: [LiviqaTab: CGRect] = [:]   // measured slots → drive the lens position
    @State private var pillTravelling = false                 // pulses true mid-travel → flares the chromatic rim
    private let tabBarSpace = "liviqaTabBar"
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
            // Ambient animated field behind the glass chrome (FB 86exz2177). Flag- and
            // a11y-gated: flag-OFF / Reduce Transparency / Increase Contrast keep the
            // flat paper canvas byte-for-byte; TidelineField itself freezes under
            // Reduce Motion. Subtle (low opacity) so card/label contrast is preserved.
            if showAmbientBackground {
                TidelineField(phase: 0.62, breathPeriod: 13, calm: 0.86)
                    .ignoresSafeArea()
                    .opacity(0.5)
                    .allowsHitTesting(false)
            }

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

    /// Which render path the selected-tab pill takes (single source of truth).
    private var barTier: LiviqaBarTier {
        liviqaBarTier(glassOn: glassOn,
                      reduceTransparency: reduceTransparency,
                      increasedContrast: contrast == .increased)
    }

    /// Ambient animated background shows only with glass on and full transparency/
    /// contrast (TidelineField itself freezes under Reduce Motion). Flag off ⇒ flat paper.
    private var showAmbientBackground: Bool { glassOn && !useSolidBar }

    private var tabRow: some View {
        HStack {
            ForEach(LiviqaTab.allCases, id: \.self) { item in
                let active = tab == item
                Button {
                    // Spring so the lens glides to the new tab (held still under Reduce Motion).
                    let animate = glassOn && !reduceMotion
                    if animate { pillTravelling = true }   // flare the chromatic rim mid-travel
                    withAnimation(animate ? LiviqaBarMotion.travel : nil) {
                        tab = item
                    }
                    if item != .home { selectedNudge = nil }
                    // Let the flare decay once the spring has settled.
                    if animate {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 420_000_000)
                            withAnimation(.easeOut(duration: 0.25)) { pillTravelling = false }
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: active ? item.symbolFilled : item.symbol)
                            .font(.lato(19))
                            // The lens "magnifies" the active glyph (subtle, calm) — a
                            // render-only scale, so it never reflows the bar layout.
                            .scaleEffect(active && glassOn ? 1.14 : 1.0)
                        Text(item.title)
                            .font(.lato(10, active ? .bold : .regular))
                            .tracking(0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        // Active dot only when the glass pill is OFF (flag off = today's look);
                        // not rendered when the pill is on, so it adds no extra bar height.
                        if active && !glassOn {
                            Circle().fill(LiviqaTheme.moss).frame(width: 4, height: 4)
                        }
                    }
                    .foregroundStyle(active ? LiviqaTheme.ink : LiviqaTheme.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    // Report this tab's slot rect so the single travelling lens can sit
                    // over it and slide between slots (measured in the bar's space).
                    .background(GeometryReader { g in
                        Color.clear.preference(key: TabFrameKey.self,
                                               value: [item: g.frame(in: .named(tabBarSpace))])
                    })
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The single travelling lens rect: the selected tab's slot, inset slightly.
    private var pillRect: CGRect? {
        guard let r = tabFrames[tab], r.width > 0 else { return nil }
        return r.insetBy(dx: 3, dy: 0)
    }

    /// ONE persistent lens, sized to the selected slot and moved by `.offset` (NOT
    /// `.position`, which would expand to fill and balloon the bar). Sliding the offset
    /// makes the single glass element travel — the Flighty glide. Placed via background
    /// so it adopts the row's size rather than dictating it; on iOS 26 it's real glass
    /// that refracts the bar surface behind it and merges into the bar capsule.
    @ViewBuilder private func lensView() -> some View {
        if glassOn, let r = pillRect {
            TravellingTabPill(tier: barTier, travelling: pillTravelling, reduceMotion: reduceMotion)
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
                .allowsHitTesting(false)
        }
    }

    private var tabBar: some View {
        // Floating capsule — three-tier ladder (LiviqaBarGlass): real Liquid Glass on
        // iOS 26 (flag on) → `.ultraThinMaterial` on iOS 17–25 → opaque paper2 under
        // Reduce Transparency / Increase Contrast, so label contrast is preserved.
        let bar = tabRow
            // The lens sits BEHIND the row so labels/icons stay crisp (a frosted lens
            // ON TOP hides the selected tab). It still travels as one glass element —
            // the Flighty glide — and the active glyph is magnified (below) so the
            // selection still reads as sitting under a magnifier.
            .background(alignment: .topLeading) { lensView() }
            .coordinateSpace(.named(tabBarSpace))
            .onPreferenceChange(TabFrameKey.self) { tabFrames = $0 }
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .liviqaBarGlass(solid: useSolidBar)
        return Group {
            // Wrap the glassy bar in a GlassEffectContainer so the lens and the bar
            // capsule MERGE into one continuous glass on iOS 26 (not two stacked blurs).
            // Flag off / iOS 17–25 pass straight through — identical to before.
            if glassOn {
                GlassEffectContainerCompat { bar }
            } else {
                bar
            }
        }
        // Detach from the screen edges so it reads as a floating surface.
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        // Cap growth so the six labels never wrap ("Settings" → "Setting s").
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

}
