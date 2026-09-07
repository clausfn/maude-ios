// SampleModeBanner.swift — the labelling that cannot be switched off (FR-SMP-03).
//
// WHY A BAR, NOT A CHIP
// ─────────────────────
// The app already had a "Sample data" chip. It sat in ONE header, it scrolled
// with the page, and — the part that mattered — it was gated by a display
// preference, `maudeShowDemoChip`, which defaulted to FALSE. Synthetic values
// could therefore render with no label at all, which is how unlabelled seeds
// reached testers. A label a person can turn off, or scroll past, or forget, is
// not a label; it is a courtesy.
//
// So the treatment is CHROME, not content:
//   • it is drawn by the app shell, above every tab and every pushed detail, and
//     is attached to every value-bearing sheet the shell presents;
//   • it does not scroll, cannot be dismissed, and no preference reaches it —
//     `SampleModePolicy.labelIsVisible` takes a preference argument and ignores
//     it, so "hide the label while sample mode is on" is unrepresentable;
//   • it says what the numbers are AND whose they are not, in words, not a code;
//   • it carries the exit, so the way out is on screen wherever the citizen is
//     when they decide they have seen enough.
//
// The per-screen chips (Home's app bar, Trends' header) stay — a second,
// nearer reminder next to the numbers themselves — but they are no longer the
// only thing standing between a tester and a fabricated value.
import SwiftUI

struct SampleModeBanner: View {
    /// Called when the citizen taps the way out.
    var onLeave: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MaudeTheme.clayText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("SAMPLE DATA")
                    .font(.maudeKicker(10))
                    .tracking(MaudeTheme.Tracking.kicker)
                    .foregroundStyle(MaudeTheme.clayText)
                Text("Made-up numbers. Not your readings.")
                    .font(.lato(12))
                    .foregroundStyle(MaudeTheme.clayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onLeave) {
                Text("Leave")
                    .font(.lato(12.5, .bold))
                    .foregroundStyle(MaudeTheme.clayText)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().stroke(MaudeTheme.clayText.opacity(0.55), lineWidth: 1.2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Leave sample mode"))
            .accessibilityHint(String(localized: "Puts your own data back on screen."))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque tint, not glass: this label must survive Reduce Transparency,
        // a busy chart behind it, and every theme.
        .background(
            ZStack {
                MaudeTheme.paper2
                MaudeTheme.clay2
            }
            .opacity(reduceTransparency ? 1 : 0.98))
        .overlay(alignment: .top) { Rectangle().fill(MaudeTheme.clay).frame(height: 2) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Sample data. The numbers on screen are made up and are not your readings."))
    }
}

// MARK: - Attaching it

extension View {
    /// Pin the sample-data bar to the bottom of this surface while sample mode
    /// is on. Used by the app shell AND by every value-bearing sheet the shell
    /// presents (a sheet is drawn above the shell, so it would otherwise cover
    /// the label). `bottomInset` lifts the bar clear of a floating tab bar.
    func maudeSampleModeBanner(_ appState: AppState,
                                bottomInset: CGFloat = 0,
                                onHeight: ((CGFloat) -> Void)? = nil) -> some View {
        modifier(SampleModeBannerModifier(appState: appState,
                                          bottomInset: bottomInset,
                                          onHeight: onHeight))
    }
}

private struct SampleModeBannerModifier: ViewModifier {
    let appState: AppState
    let bottomInset: CGFloat
    /// Reports the bar's MEASURED height so the shell can reserve exactly the
    /// room it takes — a hard-coded reserve is wrong at accessibility sizes
    /// (the same defect the tab bar had, design-QA 2026-08-13).
    let onHeight: ((CGFloat) -> Void)?
    @State private var confirmLeave = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                // No preference is consulted here, and there is deliberately no
                // dismiss control: `labelIsVisible` is the only condition.
                if SampleModePolicy.labelIsVisible(sampleModeOn: appState.isSampleMode) {
                    SampleModeBanner(onLeave: { confirmLeave = true })
                        .background(GeometryReader { g in
                            Color.clear.onAppear { onHeight?(g.size.height) }
                                .onChange(of: g.size.height) { _, h in onHeight?(h) }
                        })
                        .padding(.bottom, bottomInset)
                        .transition(.opacity)
                }
            }
            .confirmationDialog(String(localized: "Leave sample mode?"),
                                isPresented: $confirmLeave, titleVisibility: .visible) {
                Button(String(localized: "Leave sample mode")) {
                    Task { await appState.leaveSampleMode() }
                }
                Button(String(localized: "Stay"), role: .cancel) { }
            } message: {
                Text("Maude goes back to your own data. Nothing from the sample is kept — it was never saved anywhere.")
            }
    }
}
