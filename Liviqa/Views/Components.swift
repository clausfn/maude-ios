// Components.swift — Shared UI components · v02 2026-05-22
// Design ref: Liviqa_App_UI_Aperture_v01_20260521.html
import SwiftUI

// MARK: - Aperture mark
// Embeds the LOCKED aperture-mark asset — never redraw the mark in code (brand
// kit §1; code redraws caused prior drift). Same source SVGs as liviqa.app.

struct LiviqaApertureMark: View {
    var size: CGFloat = 28
    /// false = primary (on light bg, ink + moss); true = reversed (on dark).
    var reversed: Bool = false

    var body: some View {
        Image(reversed ? "LiviqaMarkReversed" : "LiviqaMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Liviqa")
    }
}

// MARK: - App bar row (used on Today, Wallet, Trends screens)

struct LiviqaAppBar: View {
    var title: String               // nil → show mark+wordmark; else show plain title
    var showMark: Bool = false      // true on Today screen only
    var chipLabel: String? = nil    // nil = no chip; only pass on onboarding/Settings

    var body: some View {
        HStack(spacing: 10) {
            if showMark {
                LiviqaApertureMark(size: 26, reversed: false)
                Text("Liviqa")
                    .font(.system(size: 17, weight: .black))
                    .kerning(-0.3)
                    .foregroundStyle(LiviqaTheme.ink)
            } else {
                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .kerning(-0.3)
                    .foregroundStyle(LiviqaTheme.ink)
            }

            Spacer()

            if let label = chipLabel {
                HStack(spacing: 7) {
                    Circle()
                        .fill(LiviqaTheme.moss)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(LiviqaTheme.moss2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LiviqaTheme.moss3, lineWidth: 1))
                .foregroundStyle(LiviqaTheme.moss)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - Section header

struct LiviqaSectionHeader: View {
    let label: String
    var trailing: String? = nil
    var trailingColor: Color = LiviqaTheme.moss

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label.uppercased())
                .font(.liviqaKicker(11))
                .tracking(1.6)
                .foregroundStyle(LiviqaTheme.ink3)
            Spacer()
            if let t = trailing {
                Text(t.uppercased())
                    .font(.liviqaKicker(10.5))
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
        case .glucose: return LiviqaTheme.amber
        case .sleep:   return LiviqaTheme.moss
        case .cardiac: return LiviqaTheme.ink3
        case .travel:  return LiviqaTheme.rust
        case .general: return LiviqaTheme.ink4
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Kicker row: time · TAG (mono, 10 pt)
            HStack(spacing: 0) {
                Text(nudge.time)
                    .font(.liviqaKicker(10))
                    .tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(" · ")
                    .font(.liviqaKicker(10))
                    .foregroundStyle(LiviqaTheme.ink3)
                Text(nudge.tag.uppercased())
                    .font(.liviqaKicker(10))
                    .tracking(1.2)
                    .foregroundStyle(nudge.accent.accentColor)
                Spacer()
            }

            // Body
            Text(nudge.body)
                .font(.system(size: 14.5))
                .foregroundStyle(LiviqaTheme.ink2)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

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
                    .background(LiviqaTheme.line)

                Button {
                    onCalibrate?(nudge.calibrationAnchor)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                            .foregroundStyle(LiviqaTheme.amber)
                        Text(prompt)
                            .font(.system(size: 12))
                            .foregroundStyle(LiviqaTheme.ink3)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(nudge.accent.accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)
        }
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }
}

// MARK: - Button styles

struct NudgePrimaryButtonStyle: ButtonStyle {
    var color: Color = LiviqaTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct NudgeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(LiviqaTheme.paper)
            .foregroundStyle(LiviqaTheme.ink2)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - MetricRingCard (circular arc ring)

struct MetricRingCard: View {
    let ring: MetricRing
    private let ringSize: CGFloat = 80
    private let strokeWidth: CGFloat = 7.5

    var ringColor: Color {
        ring.warn ? LiviqaTheme.amber : LiviqaTheme.moss
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(LiviqaTheme.line2, lineWidth: strokeWidth)
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
                    .font(.liviqaMono(16))
                    .monospacedDigit()
                    .foregroundStyle(LiviqaTheme.ink)
            }

            // Label
            Text(ring.label.uppercased())
                .font(.liviqaKicker(9.5))
                .tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
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
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
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
                    .font(.liviqaKicker(10.5))
                    .tracking(0.8)
                    .foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                Text(value)
                    .font(.liviqaMono(15))
                    .monospacedDigit()
                    .foregroundStyle(LiviqaTheme.ink)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(LiviqaTheme.moss.opacity(0.07))
                    Path { path in
                        path.move(to: CGPoint(x: 0,          y: h * 0.70))
                        path.addCurve(
                            to:       CGPoint(x: w,          y: h * 0.38),
                            control1: CGPoint(x: w * 0.27,   y: h * 0.75),
                            control2: CGPoint(x: w * 0.60,   y: h * 0.25)
                        )
                    }
                    .stroke(LiviqaTheme.moss, lineWidth: 2)
                    .padding(12)
                }
            }
            .frame(height: 120)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }
}

// MARK: - WalletSwitch (kept for any toggle use)

struct WalletSwitch: View {
    @Binding var on: Bool

    var body: some View {
        Capsule()
            .fill(on ? LiviqaTheme.moss : LiviqaTheme.line)
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
