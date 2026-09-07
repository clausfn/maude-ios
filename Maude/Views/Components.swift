// Components.swift — Shared UI components · v02 2026-05-22
// Design ref: Maude_App_UI_Aperture_v01_20260521.html
import SwiftUI

// MARK: - Aperture mark
// Embeds the LOCKED iris-mark asset (brand v2) — never redraw the mark in code (brand
// kit §1; code redraws caused prior drift). Same source SVGs as maude.app.

struct MaudeApertureMark: View {
    var size: CGFloat = 28
    /// Override the asset variant. `nil` (default) = auto: reversed (white ring)
    /// on dark Midnight, primary (ink ring) on light Paper. Pass an explicit
    /// value only when the mark sits on a surface that opposes the page (e.g. a
    /// watermark on an invert card).
    var reversed: Bool? = nil

    @Environment(\.colorScheme) private var colorScheme
    private var useReversed: Bool { reversed ?? (colorScheme == .dark) }

    var body: some View {
        Image(useReversed ? "MaudeMarkReversed" : "MaudeMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Maude")
    }
}

// MARK: - App bar row (used on Today, Wallet, Trends screens)

struct MaudeAppBar: View {
    var title: String               // nil → show mark+wordmark; else show plain title
    var showMark: Bool = false      // true on Today screen only
    var chipLabel: String? = nil    // nil = no chip; only pass on onboarding/Settings
    /// Root tab screens show the profile avatar (since they hide the system nav
    /// bar). Pushed detail screens pass `false` (they have a back affordance).
    var showsAvatar: Bool = true

    @Environment(AppState.self) private var appState: AppState?

    var body: some View {
        HStack(spacing: 10) {
            if showMark {
                // A7.2 pattern 2: the masthead iris wears the app-icon badge — a
                // cobalt-gradient tile (28% corner radius) with the white iris at
                // ~72% of tile size. Bare marks elsewhere keep the flat asset.
                ZStack {
                    RoundedRectangle(cornerRadius: 26 * 0.28, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x3059C2), Color(hex: 0x1A3696)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 26, height: 26)
                    MaudeApertureMark(size: 26 * 0.72, reversed: true)
                }
                .accessibilityHidden(true)
                Text("Maude")
                    .font(.lato(17, .black))
                    .kerning(-0.3)
                    .foregroundStyle(MaudeTheme.ink)
            } else {
                Text(title)
                    .font(.maudeSerif(17))
                    .kerning(-0.3)
                    .foregroundStyle(MaudeTheme.ink)
            }

            Spacer()

            if let label = chipLabel {
                HStack(spacing: 7) {
                    Circle()
                        .fill(MaudeTheme.moss)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.lato(11, .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MaudeTheme.moss2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MaudeTheme.moss3, lineWidth: 1))
                .foregroundStyle(MaudeTheme.moss)
            }

            if let appState, appState.researchNotificationUnread {
                Button {
                    appState.researchNotificationUnread = false
                    appState.showStudyConsent = true
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.lato(15, .bold))
                        .foregroundStyle(MaudeTheme.ink)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(MaudeTheme.paper2))
                        .overlay(Circle().stroke(MaudeTheme.line, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(MaudeTheme.amber)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(MaudeTheme.paper, lineWidth: 1.5))
                                .offset(x: 2, y: -2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New research notification")
            }

            // A7.2: the standing "On device" privacy chip — in every root app bar.
            if showsAvatar {
                OnDeviceChip()
            }

            if showsAvatar, let appState {
                Button {
                    appState.showAssistant = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.lato(15, .bold))
                        .foregroundStyle(MaudeTheme.moss)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(MaudeTheme.moss2))
                        .overlay(Circle().stroke(MaudeTheme.moss3, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask the assistant")
            }

            if showsAvatar, let appState {
                Button {
                    appState.showProfileSheet = true
                } label: {
                    ZStack {
                        Circle().fill(MaudeTheme.invertBG).frame(width: 32, height: 32)
                        Text(MaudeAppBar.initials(appState.profile?.displayName))
                            .font(.lato(12, .semibold))
                            .foregroundStyle(MaudeTheme.invertFG)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("avatarButton")
                .accessibilityLabel("Profile and settings")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    static func initials(_ name: String?) -> String {
        let n = name ?? "C"
        let parts = n.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(n.prefix(2)).uppercased()
    }
}

// MARK: - Detail-screen modifier (hides the floating tab bar while pushed)

private struct MaudeDetailScreen: ViewModifier {
    @Environment(AppState.self) private var appState: AppState?
    func body(content: Content) -> some View {
        content
            .onAppear { appState?.detailDepth += 1 }
            .onDisappear { if let a = appState { a.detailDepth = max(0, a.detailDepth - 1) } }
    }
}

extension View {
    /// Mark a pushed/full-screen detail so MainTabView hides the floating tab bar
    /// (so it can't overlap the content — e.g. a chat composer or a video call).
    func maudeDetail() -> some View { modifier(MaudeDetailScreen()) }
}

// MARK: - Sheet chrome (A6 Liquid Glass)

/// Liquid-Glass sheet surface with an opaque fallback under Reduce Transparency /
/// Increase Contrast, so text contrast over the sheet is always preserved.
private struct MaudeSheetBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        if reduceTransparency || contrast == .increased {
            MaudeTheme.paper                     // opaque, theme-dynamic (Paper/Midnight)
        } else {
            Rectangle().fill(.ultraThinMaterial)  // glass
        }
    }
}

/// Makes a sheet's own root background transparent so the glass shows through —
/// but opaque (MaudeTheme.paper) when Reduce Transparency / Increase Contrast is on.
private struct MaudeSheetSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(MaudeTheme.paper.ignoresSafeArea())
        } else {
            content   // transparent → the glass presentationBackground shows
        }
    }
}

extension View {
    /// Transparent-or-opaque root background for content shown inside a maude sheet.
    func maudeSheetSurface() -> some View { modifier(MaudeSheetSurface()) }

    /// Full A6 bottom-sheet chrome — detents, grabber, and a Liquid-Glass background
    /// (opaque fallback under Reduce Transparency / Increase Contrast). Apply on the
    /// presented view's root when the call site sets no presentation chrome of its own.
    func maudeSheet(_ detents: Set<PresentationDetent> = [.medium, .large],
                     grabber: Visibility = .visible) -> some View {
        #if os(iOS)
        return self
            .maudeSheetSurface()
            .presentationDetents(detents)
            .presentationDragIndicator(grabber)
            .presentationBackground { MaudeSheetBackground() }
        #else
        return self.maudeSheetSurface()
        #endif
    }

    /// Just the Liquid-Glass background + transparent surface, for sheets whose call
    /// sites already declare their own detents/grabber (so we don't override them).
    func maudeSheetGlass() -> some View {
        #if os(iOS)
        return self
            .maudeSheetSurface()
            .presentationBackground { MaudeSheetBackground() }
        #else
        return self.maudeSheetSurface()
        #endif
    }
}

// MARK: - Section header

struct MaudeSectionHeader: View {
    let label: String
    var trailing: String? = nil
    var trailingColor: Color = MaudeTheme.moss

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label.uppercased())
                .font(.maudeKicker(11))
                .tracking(1.6)
                .foregroundStyle(MaudeTheme.ink3)
            Spacer()
            if let t = trailing {
                Text(t.uppercased())
                    .font(.maudeKicker(10.5))
                    .tracking(1)
                    .foregroundStyle(trailingColor)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

// MARK: - NudgeAccent colours

extension NudgeAccent {
    var accentColor: Color {
        switch self {
        case .glucose: return MaudeTheme.clay
        case .sleep:   return MaudeTheme.moss
        case .cardiac: return MaudeTheme.ink3
        case .travel:  return MaudeTheme.amber   // PR-100: rust is boundary/refusal-only
        case .general: return MaudeTheme.ink4
        }
    }
    /// PR-100: domain SF Symbol — reinforces category by shape, not colour alone.
    var icon: String {
        switch self {
        case .glucose: return "drop.fill"
        case .sleep:   return "moon.zzz.fill"
        case .cardiac: return "waveform.path.ecg"
        case .travel:  return "airplane"
        case .general: return "sparkles"
        }
    }
    // Kept for backward compat
    var borderColor: Color { accentColor }
}

// MARK: - NudgeCard

struct NudgeCard: View {
    let nudge: Nudge
    var compact = false
    /// Called when the user taps the calibration prompt — pass a ProfileSheet.Section to deep-link.
    var onCalibrate: ((ProfileSheet.Section?) -> Void)? = nil
    /// Transparency-first presentation (2026-06-11): the insight sentence
    /// LEADS, and "Why this?" expands the numbers behind it in-card — the same
    /// evidence-then-meaning structure the clinician console uses, in the
    /// citizen's voice. No more burying the why two taps away.
    @State private var showWhy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Kicker row: time · TAG (mono, 10 pt)
            HStack(spacing: 0) {
                Text(nudge.time)
                    .font(.maudeKicker(10))
                    .tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                Text(" · ")
                    .font(.maudeKicker(10))
                    .foregroundStyle(MaudeTheme.ink3)
                Text(nudge.tag.uppercased())
                    .font(.maudeKicker(10))
                    .tracking(1.2)
                    .foregroundStyle(nudge.accent.accentColor)
                Spacer()
            }

            // The insight leads — full ink, reads as a sentence said to you.
            Text(nudge.body)
                .font(.lato(15.5))
                .foregroundStyle(MaudeTheme.ink)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            // "Why this?" — the numbers behind the sentence, in the card.
            if !compact, nudge.reasoning != nil || !nudge.dataPoints.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showWhy.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showWhy ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("Why this?")
                            .font(.lato(12, .bold))
                    }
                    .foregroundStyle(nudge.accent.accentColor)
                }
                .buttonStyle(.plain)

                if showWhy {
                    VStack(alignment: .leading, spacing: 6) {
                        if let reasoning = nudge.reasoning {
                            Text(reasoning)
                                .font(.lato(12.5))
                                .foregroundStyle(MaudeTheme.ink2)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !nudge.dataPoints.isEmpty {
                            FlowChips(items: nudge.dataPoints)
                        }
                        Text("Computed on this device · your data, your baseline · shown, not judged.")
                            .font(.maudeKicker(9.5))
                            .tracking(0.6)
                            .foregroundStyle(MaudeTheme.ink3)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Actions (full cards only)
            if !compact, !nudge.primaryAction.isEmpty {
                HStack(spacing: 8) {
                    Button(nudge.primaryAction) {}
                        .buttonStyle(NudgePrimaryButtonStyle())
                    ForEach(nudge.secondaryActions, id: \.self) { label in
                        Button(label) {}
                            .buttonStyle(NudgeSecondaryButtonStyle())
                    }
                }
            }

            // Calibration prompt — only when a declared datum is missing that would improve this nudge
            if !compact, let prompt = nudge.calibrationPrompt {
                Divider()
                    .background(MaudeTheme.line)

                Button {
                    onCalibrate?(nudge.calibrationAnchor)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.lato(11))
                            .foregroundStyle(MaudeTheme.clay)
                        Text(prompt)
                            .font(.lato(12))
                            .foregroundStyle(MaudeTheme.ink3)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.lato(10, .medium))
                            .foregroundStyle(MaudeTheme.ink4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MaudeTheme.line, lineWidth: 0.5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(nudge.accent.accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)
        }
        .shadow(color: MaudeTheme.cardShadow, radius: 8, y: 2)
    }
}

// MARK: - Button styles

struct NudgePrimaryButtonStyle: ButtonStyle {
    /// Invert surface so the primary CTA contrasts the page on BOTH themes
    /// (was `ink` + white → cream-on-cream, invisible on Midnight).
    var color: Color = MaudeTheme.invertBG

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lato(12.5, .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color)
            .foregroundStyle(MaudeTheme.invertFG)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct NudgeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lato(12.5, .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(MaudeTheme.paper)
            .foregroundStyle(MaudeTheme.ink2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(MaudeTheme.line))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - MetricRingCard (circular arc ring)

struct MetricRingCard: View {
    let ring: MetricRing
    private let ringSize: CGFloat = 80
    private let strokeWidth: CGFloat = 7.5

    var ringColor: Color {
        ring.warn ? MaudeTheme.clay : MaudeTheme.moss
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(MaudeTheme.line2, lineWidth: strokeWidth)
                    .frame(width: ringSize, height: ringSize)

                // Progress arc
                Circle()
                    .trim(from: 0, to: ring.progress)
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: strokeWidth,
                                               lineCap: .round))
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: ring.progress)

                // Value
                Text(ring.value)
                    .font(.maudeMono(16))
                    .monospacedDigit()
                    .foregroundStyle(MaudeTheme.ink)
            }

            // Label
            Text(ring.label.uppercased())
                .font(.maudeKicker(9.5))
                .tracking(1)
                .foregroundStyle(MaudeTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MetricRingsRow (3-up circular rings in a card)

struct MetricRingsRow: View {
    let rings: [MetricRing]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(rings.prefix(3)) { ring in
                MetricRingCard(ring: ring)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 0.5))
        .shadow(color: MaudeTheme.cardShadow, radius: 8, y: 2)
    }
}

// MARK: - ChartPlaceholder (Trends view)

struct ChartPlaceholder: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.maudeKicker(10.5))
                    .tracking(0.8)
                    .foregroundStyle(MaudeTheme.ink3)
                Spacer()
                Text(value)
                    .font(.maudeMono(15))
                    .monospacedDigit()
                    .foregroundStyle(MaudeTheme.ink)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(MaudeTheme.moss.opacity(0.07))
                    Path { path in
                        path.move(to: CGPoint(x: 0,          y: h * 0.70))
                        path.addCurve(
                            to:       CGPoint(x: w,          y: h * 0.38),
                            control1: CGPoint(x: w * 0.27,   y: h * 0.75),
                            control2: CGPoint(x: w * 0.60,   y: h * 0.25)
                        )
                    }
                    .stroke(MaudeTheme.moss, lineWidth: 2)
                    .padding(12)
                }
            }
            .frame(height: 120)
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 0.5))
        .shadow(color: MaudeTheme.cardShadow, radius: 8, y: 2)
    }
}

// MARK: - WalletSwitch (kept for any toggle use)

struct WalletSwitch: View {
    @Binding var on: Bool

    var body: some View {
        Capsule()
            .fill(on ? MaudeTheme.moss : MaudeTheme.line)
            .frame(width: 36, height: 22)
            .overlay(
                Circle()
                    .fill(.white)
                    .shadow(radius: 1, y: 1)
                    .frame(width: 18, height: 18)
                    .offset(x: on ? 7 : -7),
                alignment: on ? .trailing : .leading
            )
            .padding(2)
            .onTapGesture { on.toggle() }
    }
}

/// Small mono chips for the evidence points inside a nudge's "Why this?".
struct FlowChips: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.maudeKicker(10))
                    .tracking(0.4)
                    .foregroundStyle(MaudeTheme.ink2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MaudeTheme.paper)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MaudeTheme.line, lineWidth: 0.5))
            }
        }
    }
}

// MARK: - On-device chip (A7.2 trust moment — always visible, tappable proof)

/// "On device" — the standing privacy chip. Tap → the proof surface
/// (InAppPrivacyView: what stays on the phone, what's logged, who governs).
struct OnDeviceChip: View {
    @State private var showProof = false

    var body: some View {
        Button { showProof = true } label: {
            HStack(spacing: 5) {
                ZStack {
                    Circle().stroke(MaudeTheme.moss, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                    Circle().fill(MaudeTheme.moss).frame(width: 3.5, height: 3.5)
                }
                Text("On device")
                    .font(.lato(11.5, .semibold))
                    .foregroundStyle(MaudeTheme.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(MaudeTheme.paper2))
            .overlay(Capsule().stroke(MaudeTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showProof) {
            NavigationStack { InAppPrivacyView() }
        }
        .accessibilityLabel("On device — your data stays on this phone. Opens the privacy overview.")
    }
}
