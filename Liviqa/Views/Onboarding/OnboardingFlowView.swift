// OnboardingFlowView.swift — A7.2 designed onboarding flow · v01 2026-08-12
// The 9-step container from the design handoff (f-onboarding.jsx): cover →
// why → sign-in → Apple Health (→ declined) → Data for Good → name →
// Health Passport → sharing → backup (→ app lock) → (literacy) → how it
// works → ready. Shared chrome: 9-segment progress bar, back chevron, "n/9"
// tabular counter, per-step ambient accent glow.
//
// PrivacyDeclarationView stays the FIRST gate before this flow (FR-REG-01) —
// LiviqaApp presents it, then this. On completion the caller sets ALL the
// legacy gates (hasSeenHealthKitPrimer, hasSeenDfGOnboarding,
// seenOnboardingVersion) so the existing upgrade logic keeps working.
//
// DEBUG env hook (snapshot family): LIVIQA_ONB_STEP=<0..10|declined|lock|literacy>
// forces the flow open at that frame (0..10 = the 11 handoff frames).
import SwiftUI

// MARK: - Frames

enum OnbFrame: String, CaseIterable {
    case cover, why, signIn, health, healthDeclined, dfg, name,
         passport, sharing, backup, appLock, literacy, howLearns, ready

    /// Progress slot 1…9 (nil = chromeless cover/ready).
    var progressSlot: Int? {
        switch self {
        case .cover, .ready:        return nil
        case .why:                  return 1
        case .signIn:               return 2
        case .health, .healthDeclined: return 3
        case .dfg:                  return 4
        case .name:                 return 5
        case .passport:             return 6
        case .sharing:              return 7
        case .backup, .appLock:     return 8
        case .literacy, .howLearns: return 9
        }
    }

    /// Per-step accent — each content step gets its own identity (handoff ACCENTS).
    var accent: Color {
        switch self {
        case .health, .healthDeclined: return LiviqaTheme.accentGlucose
        case .name:                    return LiviqaTheme.accentSleep
        case .passport:                return LiviqaTheme.accentRecovery
        case .sharing:                 return LiviqaTheme.brass
        case .backup:                  return LiviqaTheme.accentHeart
        default:                       return LiviqaTheme.moss
        }
    }

    #if DEBUG
    /// LIVIQA_ONB_STEP values → frames (0..10 = the 11 handoff frames).
    static func forced(from raw: String) -> OnbFrame? {
        switch raw {
        case "0": return .cover
        case "1": return .why
        case "2": return .signIn
        case "3": return .health
        case "4": return .dfg
        case "5": return .name
        case "6": return .passport
        case "7": return .sharing
        case "8": return .backup
        case "9": return .howLearns
        case "10": return .ready
        case "declined": return .healthDeclined
        case "lock": return .appLock
        case "literacy": return .literacy
        default: return nil
        }
    }
    #endif
}

// MARK: - Flow container

struct OnboardingFlowView: View {
    var onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("liviqaReduceMotion") private var appReduceMotion = false

    @State private var frame: OnbFrame
    @State private var history: [OnbFrame] = []
    @State private var forward = true

    // Flow-scoped state
    @State private var firstName = ""
    @State private var lastName = ""
    /// nil until the Apple Health step resolves; true = connect, false = demo.
    @State private var healthConnected: Bool? = nil
    /// True while the Health read authorization + first fetch are in flight.
    @State private var connectingHealth = false
    /// Why the declined frame is showing — a chosen skip, or a read that
    /// completed with nothing in it (never stated as a denial; see that view).
    @State private var declinedReason: HealthAccessDeclinedView.Reason = .skipped

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        var initial: OnbFrame = .cover
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["LIVIQA_ONB_STEP"],
           let f = OnbFrame.forced(from: raw) {
            initial = f
        }
        #endif
        _frame = State(initialValue: initial)
    }

    private var reduceMotion: Bool { systemReduceMotion || appReduceMotion }

    /// The name the flow greets with — captured name first, then the profile,
    /// never the pseudonymous LV001 alias.
    private var greetName: String? {
        let typed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        if let n = appState.profile?.displayName, !n.isEmpty, n != "LV001" { return n }
        return nil
    }

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            if frame == .cover {
                coverFrame
                    .transition(frameTransition)
            } else if frame == .ready {
                readyFrame
                    .transition(frameTransition)
            } else {
                contentChrome
                    .transition(frameTransition)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: frame)
        // Sign-in resolved (Apple / email / demo) while on the sign-in frame →
        // move on. Also skips the frame outright for already-signed-in replays.
        .onChange(of: appState.session != nil) { _, signedIn in
            if signedIn && frame == .signIn { advance() }
        }
        .onChange(of: frame) { _, new in
            if new == .signIn && appState.session != nil { advance(replacing: true) }
        }
        .onAppear {
            if frame == .signIn && appState.session != nil { advance(replacing: true) }
        }
    }

    // MARK: Navigation

    private func advance(replacing: Bool = false) {
        guard let next = nextFrame(after: frame) else { onComplete(); return }
        forward = true
        if !replacing { history.append(frame) }
        frame = next
    }

    private func goBack() {
        guard let prev = history.popLast() else { return }
        forward = false
        frame = prev
    }

    private func nextFrame(after f: OnbFrame) -> OnbFrame? {
        switch f {
        case .cover:          return .why
        case .why:            return .signIn
        case .signIn:         return .health
        case .health:         return .dfg          // connect path; skip routes to .healthDeclined
        case .healthDeclined: return .dfg
        case .dfg:            return .name
        case .name:           return .passport
        case .passport:       return .sharing
        case .sharing:        return .backup
        case .backup:         return .appLock
        case .appLock:        return .literacy
        case .literacy:       return .howLearns
        case .howLearns:      return .ready
        case .ready:          return nil
        }
    }

    private var frameTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: Shared chrome (progress + back + counter + ambient)

    private var contentChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                        .frame(width: 34, height: 34, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Back"))
                .opacity(history.isEmpty ? 0 : 1)
                .disabled(history.isEmpty)

                progressBar

                Text("\(frame.progressSlot ?? 0)/9")
                    .font(.liviqaMono(11))
                    .fontWeight(.bold)
                    .tracking(0.6)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ZStack(alignment: .top) {
                ambientGlow
                stepContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(1...9, id: \.self) { s in
                RoundedRectangle(cornerRadius: 2)
                    .fill(segmentColor(s))
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Step \(frame.progressSlot ?? 0) of 9"))
    }

    private func segmentColor(_ s: Int) -> Color {
        guard let slot = frame.progressSlot else { return LiviqaTheme.line }
        if s < slot { return LiviqaTheme.moss }
        if s == slot { return frame.accent }
        return LiviqaTheme.ink.opacity(0.14)
    }

    /// Soft single-colour ambient per content step — identity, not clutter.
    private var ambientGlow: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(colors: [frame.accent.opacity(0.15), .clear],
                               center: .center, startRadius: 0,
                               endRadius: geo.size.width * 0.4)
                    .frame(width: geo.size.width * 0.78, height: geo.size.height * 0.38)
                    .blur(radius: 24)
                    .position(x: geo.size.width * 1.02, y: 0)
                ZStack {
                    IrisArc(radius: IrisGeometry.inner.radius,
                            startDeg: IrisGeometry.inner.start,
                            sweepDeg: IrisGeometry.inner.sweep)
                        .stroke(frame.accent.opacity(0.35), lineWidth: 2)
                    IrisArc(radius: IrisGeometry.middle.radius,
                            startDeg: IrisGeometry.middle.start,
                            sweepDeg: IrisGeometry.middle.sweep)
                        .stroke(frame.accent.opacity(0.2), lineWidth: 1.6)
                }
                .frame(width: geo.size.width * 0.58, height: geo.size.width * 0.58)
                .position(x: geo.size.width * 0.98, y: geo.size.width * 0.08)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch frame {
        case .cover, .ready:
            EmptyView()
        case .why:
            WhyLiviqaStep(accent: frame.accent, onContinue: { advance() })
        case .signIn:
            AuthView(flowKicker: String(localized: "Step 2 of 9"),
                     onDemoContinue: {
                         // Demo entry (button exists only in DEBUG AuthView; body
                         // compiled out of Release too — T1 posture): no HealthKit,
                         // demo jumps straight to DfG per the handoff. Move frames
                         // FIRST so the session onChange (fired by signInDemo)
                         // can't double-advance from .signIn.
                         #if DEBUG
                         healthConnected = false
                         forward = true
                         history.append(.signIn)
                         frame = .dfg
                         appState.signInDemo()
                         #endif
                     })
        case .health:
            HealthKitPrimerView(
                greetName: greetName,
                isConnecting: connectingHealth,
                onConnect: {
                    // Real connect path (FR-ING-01/02): switch to on-device
                    // HealthKit and request read authorization now. We WAIT for
                    // the first fetch to resolve, because its answer decides the
                    // next frame: readings ⇒ carry on; nothing at all ⇒ the
                    // honest "nothing came through" screen (inferred-denial
                    // cue) instead of a silently empty app.
                    appState.dataProviderKind = .healthKit
                    connectingHealth = true
                    Task {
                        await appState.refreshFromHealth()
                        connectingHealth = false
                        healthConnected = !appState.healthReadReturnedNothing
                        if appState.healthReadReturnedNothing {
                            declinedReason = .noReadings
                            forward = true
                            history.append(.health)
                            frame = .healthDeclined
                        } else {
                            advance()
                        }
                    }
                },
                onSkip: {
                    healthConnected = false
                    declinedReason = .skipped
                    forward = true
                    history.append(frame)
                    frame = .healthDeclined
                })
        case .healthDeclined:
            HealthAccessDeclinedView(reason: declinedReason, onContinue: { advance() })
        case .dfg:
            DfGGovernanceStep(accent: frame.accent, onContinue: { advance() })
        case .name:
            NameCaptureStep(accent: frame.accent,
                            firstName: $firstName, lastName: $lastName,
                            onContinue: {
                                let full = [firstName, lastName]
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                if let first = full.first, !first.isEmpty {
                                    appState.setDisplayName(first)
                                }
                                advance()
                            })
        case .passport:
            PassportStep(accent: frame.accent, onContinue: { advance() })
        case .sharing:
            SharingStep(accent: frame.accent, onContinue: { advance() })
        case .backup:
            BackupStep(accent: frame.accent, onContinue: { advance() })
        case .appLock:
            AppLockSetupView(onDone: { advance() })
        case .literacy:
            LiteracyStep(accent: frame.accent, onContinue: { advance() })
        case .howLearns:
            HowLearnsStep(accent: frame.accent, onContinue: { advance() })
        }
    }

    // MARK: Cover (frame 0)

    private var coverFrame: some View {
        OnboardingCover {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                OnboardingIrisMark(size: 66)

                Text("Liviqa")
                    .font(.liviqaSerif(40, .bold, relativeTo: .largeTitle))
                    .kerning(-0.8)
                    .foregroundStyle(.white)
                    .padding(.top, 26)

                Text("A quiet daily read on your health — that never leaves your phone.")
                    .font(.liviqaSerif(24, .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: 0xC9A96A))
                    .frame(width: 46, height: 3)
                    .padding(.vertical, 18)
                    .accessibilityHidden(true)

                Text("Liviqa reads the health data you already have, finds patterns in *your own* normal, and keeps every reading on this device.")
                    .font(.lato(14.5))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                VStack(spacing: 11) {
                    Button { advance() } label: {
                        Text("Get started")
                            .font(.lato(15, .bold))
                            .foregroundStyle(Color(hex: 0x122C46))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    #if DEBUG
                    // Demo posture is DEBUG-only (T1 TestProd): Release never
                    // promises an account-less path it can't honour.
                    Button { advance() } label: {
                        Text("Try it without an account")
                            .font(.lato(13.5, .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
    }

    // MARK: Ready (frame 10)

    private var readyFrame: some View {
        ReadyStepView(name: greetName,
                      healthConnected: healthConnected ?? (appState.dataProviderKind == .healthKit),
                      onOpen: onComplete)
    }
}

// MARK: - Ready finale

private struct ReadyStepView: View {
    var name: String?
    var healthConnected: Bool
    var onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("liviqaReduceMotion") private var appReduceMotion = false
    @State private var drawn = false

    private var reduceMotion: Bool { systemReduceMotion || appReduceMotion }

    var body: some View {
        OnboardingCover(spin: true) {
            GeometryReader { geo in
                ScrollView {
                    readyContent
                        // Center the finale between the notch and the CTA inset
                        // (Spacers only expand once the stack fills the height).
                        .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onOpen) {
                        Text("Open today's edition")
                            .font(.lato(15, .bold))
                            .foregroundStyle(Color(hex: 0x122C46))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    Text("Printed on your device — nothing left it today.\nGoverned by the Data for Good Foundation.")
                        .font(.lato(11.5))
                        .lineSpacing(3)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 16)
                .padding(.top, 8)
            }
        }
        .onAppear { drawn = true }
    }

    private var readyContent: some View {
                VStack(spacing: 0) {
                    Spacer(minLength: 30)

                    // 110pt iris, drawn stroke by stroke (staggered trim).
                    OnboardingIrisMark(size: 110,
                                       draw: reduceMotion || drawn
                                           ? (1, 1, 1)
                                           : (0, 0, 0))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(0.1),
                                   value: drawn)

                    Text(name.map { "You're set, \($0)." } ?? "You're set.")
                        .font(.liviqaSerif(29, .bold, relativeTo: .title1))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 26)

                    Text(healthConnected
                         ? "Your first edition arrives as your readings come in. Everything lives on this phone."
                         : "Your first edition arrives as soon as you connect Apple Health. Everything lives on this phone.")
                        .font(.lato(14.5))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                        .padding(.horizontal, 8)

                    // The guardian promise
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: 0xC9A96A))
                            Text("YOUR PRIVATE VAULT")
                                .font(.liviqaKicker(10.5))
                                .tracking(LiviqaTheme.Tracking.kicker)
                                .foregroundStyle(Color(hex: 0xC9A96A))
                        }
                        Text("Because your data never leaves your control, Liviqa can be a guardian that goes further than Apple or any cloud is allowed to — reading everything together to look out for you, while you alone decide what's ever shared.")
                            .font(.lato(13))
                            .lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: 0xC9A96A).opacity(0.45), lineWidth: 1))
                    .padding(.top, 18)

                    HStack(spacing: 7) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13, weight: .medium))
                        Text("You can already export a summary as a PDF.")
                            .font(.lato(12.5, .semibold))
                    }
                    .foregroundStyle(Color(hex: 0xC9A96A))
                    .padding(.top, 16)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity)
    }
}
