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
    @State private var tabFrames: [LiviqaTab: CGRect] = [:]   // measured slots → hit-test the finger
    @State private var dragLoc: CGPoint? = nil               // finger location in bar space while pressing; nil = idle
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

    // MARK: Tab selection + finger hit-testing

    private func select(_ item: LiviqaTab) {
        guard tab != item else { return }
        tab = item
        if item != .home { selectedNudge = nil }
    }

    /// The tab whose slot centre is nearest the given x (robust at edges/gaps).
    private func tabAt(_ x: CGFloat) -> LiviqaTab? {
        guard !tabFrames.isEmpty else { return nil }
        return tabFrames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    /// The tab the finger is currently over (only while the magnifier is active).
    /// Union of all tab slots — the area the lens may roam within.
    private var barBounds: CGRect? {
        guard !tabFrames.isEmpty else { return nil }
        let r = Array(tabFrames.values)
        let minX = r.map(\.minX).min()!, maxX = r.map(\.maxX).max()!
        let minY = r.map(\.minY).min()!, maxY = r.map(\.maxY).max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private var tabRow: some View {
        HStack(spacing: 0) {
            ForEach(LiviqaTab.allCases, id: \.self) { item in
                tabCell(item)
            }
        }
    }

    @ViewBuilder private func tabCell(_ item: LiviqaTab) -> some View {
        let active = tab == item
        VStack(spacing: 3) {
            Image(systemName: active ? item.symbolFilled : item.symbol)
                .font(.lato(19))
            Text(item.title)
                .font(.lato(10, active ? .bold : .regular))
                .tracking(0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            // Flag-off keeps the legacy dot; with glass on, the resting selection is the
            // chip below (which becomes the glass lens on touch).
            Circle().fill(LiviqaTheme.moss)
                .frame(width: 4, height: 4)
                .opacity(!glassOn && active && dragLoc == nil ? 1 : 0)
        }
        .foregroundStyle(active ? LiviqaTheme.ink : LiviqaTheme.ink3)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        // Resting selection chip (glass on) — the pill that "becomes glass" on touch.
        // Hidden while the lens is up so the two never double.
        .background {
            if glassOn && active && dragLoc == nil {
                Capsule().fill(LiviqaTheme.moss.opacity(0.12))
                    .padding(.horizontal, 6).padding(.vertical, 4)
            }
        }
        .background(GeometryReader { g in
            Color.clear.preference(key: TabFrameKey.self,
                                   value: [item: g.frame(in: .named(tabBarSpace))])
        })
        // Selection stays fully accessible without the drag gesture (VoiceOver).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default) { select(item) }
    }

    /// Capsule lens geometry at the current finger position (nil while idle). Bigger
    /// than a tab, centred vertically on the bar.
    private var lens: (cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, capR: CGFloat, halfLen: CGFloat)? {
        guard glassOn, let p = dragLoc, let b = barBounds else { return nil }
        let w = (b.width / CGFloat(LiviqaTab.allCases.count)) * 1.6
        let h = b.height * 0.92
        let capR = h / 2
        let halfLen = max(0, w / 2 - capR)
        let cx = min(max(p.x, b.minX + w / 2), b.maxX - w / 2)
        return (cx, b.midY, w, h, capR, halfLen)
    }

    /// The lens edge drawn over the shader-magnified content: the chromatic rainbow rim
    /// (Flighty), or a plain solid capsule under Reduce Transparency / Increase Contrast
    /// (where the magnify shader is disabled for comfort).
    @ViewBuilder private var lensRim: some View {
        if let l = lens {
            Group {
                if useSolidBar {
                    Capsule().fill(LiviqaTheme.moss2)
                        .overlay(Capsule().strokeBorder(LiviqaTheme.moss3, lineWidth: 1))
                } else {
                    Capsule().strokeBorder(
                        AngularGradient(colors: [.cyan, .blue, .purple, .pink, .orange, .green, .cyan],
                                        center: .center),
                        lineWidth: 1.5
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.6)
                }
            }
            .frame(width: l.w, height: l.h)
            .position(x: l.cx, y: l.cy)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// Touch anywhere on the bar raises the bubble; dragging moves it; lifting selects
    /// the tab under the finger and dismisses it.
    private var barDrag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(tabBarSpace))
            .onChanged { v in
                if dragLoc == nil {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { dragLoc = v.location }
                } else {
                    dragLoc = v.location                          // track the finger 1:1, no lag
                }
            }
            .onEnded { v in
                if let t = tabAt(v.location.x) { select(t) }
                withAnimation(.easeOut(duration: 0.18)) { dragLoc = nil }
            }
    }

    private var tabBar: some View {
        // Floating capsule — three-tier ladder (LiviqaBarGlass): real Liquid Glass on
        // iOS 26 (flag on) → `.ultraThinMaterial` on iOS 17–25 → opaque paper2 under
        // Reduce Transparency / Increase Contrast, so label contrast is preserved.
        let l = lens
        let bar = tabRow
            // Real magnification: a Metal layerEffect samples the row pixels and enlarges
            // them (with chromatic aberration) inside the capsule at the finger — so the
            // actual icons magnify through the lens (Flighty), not a frosted overlay.
            // Disabled under Reduce Transparency / Increase Contrast (lensRim shows a
            // plain solid capsule there instead).
            .layerEffect(
                ShaderLibrary.tabMagnifier(
                    .float2(l?.cx ?? 0, l?.cy ?? 0),
                    .float(l?.halfLen ?? 0),
                    .float(l?.capR ?? 1),
                    .float(1.7),                                 // magnification
                    .float(4)                                    // chromatic-aberration px
                ),
                maxSampleOffset: CGSize(width: 60, height: 60),
                isEnabled: l != nil && !useSolidBar
            )
            .coordinateSpace(.named(tabBarSpace))
            .onPreferenceChange(TabFrameKey.self) { tabFrames = $0 }
            .overlay { lensRim }
            .contentShape(Rectangle())
            .gesture(barDrag)
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .liviqaBarGlass(solid: useSolidBar)
        return Group {
            // Wrap the bar in a GlassEffectContainer so the bubble lens and the bar
            // capsule blend into one continuous glass on iOS 26 (not two stacked blurs).
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
