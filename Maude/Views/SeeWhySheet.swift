// SeeWhySheet.swift — FR-XPL-01: the ONE "See why" affordance and the ONE
// disclosure it opens (Bevel absorb ②).
//
// Universality is the point. Maude already showed its work in three places (the
// evening score legend, the Trends N·r·p chips, the nudge evidence row) — three
// different shapes for the same promise. This file makes it one shape, placed
// under every verdict the app prints: the Today hero, each signal card, the
// evening day score, every metric-detail hero, the baseline detail, and the
// insight detail.
//
// The disclosure never composes language: it renders a `SeeWhyExplanation` built
// by `SeeWhyExplainer` (pure Foundation, guard-tested). When a surface cannot be
// decomposed from real data the explanation carries `unexplained` copy and this
// view shows THAT, plainly — an empty state is a truthful answer; a vague blurb
// is not.
//
// COLOUR RAILS: moss (trust/explain) only. No clay, no clinical red — a
// disclosure is never an alarm.
import SwiftUI

// MARK: - The affordance

/// The single "See why" chip. Two skins only: on paper (moss) and on a tinted
/// hero band (white-on-translucent), so it reads the same everywhere it lands.
struct SeeWhyChip: View {
    var label: String = String(localized: "See why")
    /// True when the chip sits on a tinted MetricHero band.
    var onTint: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(label)
                    .font(.lato(12, .bold))
            }
            .foregroundStyle(onTint ? Color.white : MaudeTheme.moss)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(onTint ? Color.white.opacity(0.18) : MaudeTheme.moss2))
            .overlay(Capsule().stroke(onTint ? Color.white.opacity(0.30) : MaudeTheme.moss3,
                                      lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("See why"))
        .accessibilityHint(Text("Opens the numbers behind this verdict"))
    }
}

/// The standard placement under a metric-detail hero band — same inset as the
/// hero itself, so every detail screen carries it in the same spot.
struct SeeWhyHeroRow: View {
    var action: () -> Void
    var body: some View {
        HStack {
            SeeWhyChip(action: action)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }
}

extension View {
    /// Attach the shared disclosure sheet to a surface that owns a
    /// `SeeWhyExplanation?` state.
    func seeWhySheet(_ item: Binding<SeeWhyExplanation?>, appState: AppState) -> some View {
        sheet(item: item) { explanation in
            SeeWhySheetView(explanation: explanation, appState: appState)
        }
    }
}

// MARK: - The disclosure

struct SeeWhySheetView: View {
    let explanation: SeeWhyExplanation
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var methodTopic: LearnTopic? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    verdictBlock
                    if let unexplained = explanation.unexplained {
                        honestAbsence(unexplained)
                    } else {
                        rowsCard
                    }
                    if let topic = explanation.method {
                        methodLink(topic)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(MaudeTheme.paper)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(item: $methodTopic) { topic in
                LearnArticleView(topic: topic, appState: appState)
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(explanation.surface.uppercased())
                .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                .foregroundStyle(MaudeTheme.ink3)
            Spacer(minLength: 8)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MaudeTheme.ink3)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(MaudeTheme.paper2))
                    .overlay(Circle().stroke(MaudeTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.top, 16)
    }

    /// The verdict, repeated in the words the surface used — so the user can see
    /// they are reading the explanation of the sentence they tapped.
    private var verdictBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(explanation.verdict)
                .font(.maudeSerif(21)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            RoundedRectangle(cornerRadius: 2)
                .fill(MaudeTheme.moss)
                .frame(width: 44, height: 3)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(explanation.rows.enumerated()), id: \.element.id) { i, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.label.uppercased())
                        .font(.maudeKicker(9.5)).tracking(1)
                        .foregroundStyle(MaudeTheme.ink3)
                    Text(row.value)
                        .font(.lato(13)).lineSpacing(3)
                        .foregroundStyle(MaudeTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
                if i < explanation.rows.count - 1 {
                    Rectangle().fill(MaudeTheme.line).frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 15).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card)
            .stroke(MaudeTheme.line, lineWidth: 0.5))
    }

    /// An honest empty state beats a vague blurb — this is the whole point of the
    /// feature, so it gets a proper card rather than a grey line.
    private func honestAbsence(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MaudeTheme.moss)
                .padding(.top, 1)
            Text(text)
                .font(.lato(13)).lineSpacing(3)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card)
            .stroke(MaudeTheme.moss3, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func methodLink(_ topic: LearnTopic) -> some View {
        Button { methodTopic = topic } label: {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .font(.system(size: 12, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Read the method note")
                        .font(.lato(13.5, .bold))
                    Text(Self.methodBlurb(topic))
                        .font(.lato(11.5))
                        .foregroundStyle(MaudeTheme.ink3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(MaudeTheme.moss)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// One line naming what the linked note publishes.
    static func methodBlurb(_ topic: LearnTopic) -> String {
        switch topic {
        case .hrv:          return String(localized: "What HRV is, and how yours is measured")
        case .usualBand:    return String(localized: "How “your usual” band is worked out")
        case .dayScore:     return String(localized: "What the evening score adds up")
        case .evidenceGate: return String(localized: "When a pattern is strong enough to mention")
        case .verdictWords: return String(localized: "Why the verdict words never change")
        }
    }

    private var footer: some View {
        Text(explanation.footer)
            .font(.lato(11)).lineSpacing(2)
            .foregroundStyle(MaudeTheme.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }
}
