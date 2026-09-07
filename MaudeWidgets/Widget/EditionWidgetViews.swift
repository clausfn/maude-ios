// EditionWidgetViews.swift — small + medium home-screen layouts.
//
// TARGET MEMBERSHIP: the **Maude Widgets** iOS Widget Extension target only.
// Requires `Maude/Theme.swift` to be a member of that target too (SETUP.md §4)
// — every colour and face here is a MaudeTheme token, no hex literals, so the
// widget recolours with the app.
//
// A7.2 "Morning / Evening Edition":
//   • morning — paper ground, moss rule under the sentence
//   • evening — the SAME structure with the clay rule and the "Tonight" kicker.
//     Not an inversion: the dark ground is the user's theme, not the edition.
// The two editions differ in kicker + rule colour only, exactly as Home differs
// between its day hero and its closing note.
//
// Colour rails honoured here:
//   • red is CLINICAL GLUCOSE TIR CHARTS ONLY — nothing in this file uses
//     `clinRed` or the `tir*` ramp. The widget's TIR is TWO-STATE: moss (inside
//     your range) on a `line` track (outside).
//   • the attention state is clay (amber), the app's locked second state.
import WidgetKit
import SwiftUI

// MARK: - Root

struct EditionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: EditionEntry

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                switch family {
                case .systemMedium: MediumEditionView(snapshot: snap)
                default:            SmallEditionView(snapshot: snap)
                }
            } else {
                EmptyEditionView()
            }
        }
        .padding(14)
    }
}

// MARK: - Small (158×158) — sentence + one decomposed read + staleness

struct SmallEditionView: View {
    let snapshot: MaudeWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditionKicker(edition: snapshot.edition)

            Text(snapshot.verdict)
                .font(.maudeSerif(15))
                .kerning(-0.2)
                .lineSpacing(1)
                .foregroundStyle(MaudeTheme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            EditionRule(edition: snapshot.edition)
                .padding(.vertical, 8)

            Spacer(minLength: 0)

            if let tir = snapshot.timeInRange {
                TwoStateRangeBar(tir: tir, height: 6)
                Text(WidgetCopy.inRangeHeadline(tir.insidePct))
                    .font(.maudeMono(12))
                    .foregroundStyle(MaudeTheme.ink2)
                    .padding(.top, 5)
            } else {
                Text(WidgetCopy.noGlucoseLine)
                    .font(.lato(11))
                    .foregroundStyle(MaudeTheme.ink3)
                    .lineLimit(2)
            }

            StalenessLine(derivedAt: snapshot.derivedAt)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Medium (338×158) — sentence + the signals behind it + TIR

struct MediumEditionView: View {
    let snapshot: MaudeWidgetSnapshot

    /// Three chips is what fits honestly at this width without truncating a
    /// value. If the app publishes fewer, fewer are shown — never padded.
    private var chips: [WidgetSignalChip] { Array(snapshot.chips.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .firstTextBaseline) {
                EditionKicker(edition: snapshot.edition)
                Spacer(minLength: 8)
                StalenessLine(derivedAt: snapshot.derivedAt)
            }

            Text(snapshot.verdict)
                .font(.maudeSerif(17))
                .kerning(-0.2)
                .lineSpacing(1)
                .foregroundStyle(MaudeTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            EditionRule(edition: snapshot.edition)
                .padding(.vertical, 7)

            // The shown work: the parts, side by side. No weights, no total.
            if chips.isEmpty {
                Text(WidgetCopy.calibratingNote)
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink3)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { idx, chip in
                        if idx > 0 {
                            Rectangle()
                                .fill(MaudeTheme.line)
                                .frame(width: 1, height: 26)
                                .padding(.horizontal, 9)
                        }
                        SignalChipView(chip: chip)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint(WidgetCopy.accessibilityDecomposed)
            }

            Spacer(minLength: 6)

            if let tir = snapshot.timeInRange {
                TwoStateRangeRow(tir: tir)
            } else {
                Text(WidgetCopy.noGlucoseLine)
                    .font(.lato(11.5))
                    .foregroundStyle(MaudeTheme.ink3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Honest empty state

struct EmptyEditionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WidgetCopy.brandKicker.uppercased())
                .font(.maudeKicker(9)).tracking(1.2)
                .foregroundStyle(MaudeTheme.ink3)
            Text(WidgetCopy.emptyTitle)
                .font(.maudeSerif(15))
                .kerning(-0.2)
                .foregroundStyle(MaudeTheme.ink)
                .lineLimit(2)
                .padding(.top, 6)
            Text(WidgetCopy.emptyBody)
                .font(.lato(11.5)).lineSpacing(1)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pieces

/// The edition kicker — the only all-caps in the type scale.
struct EditionKicker: View {
    let edition: WidgetEdition
    var body: some View {
        Text((edition == .evening ? WidgetCopy.eveningKicker : WidgetCopy.morningKicker).uppercased())
            .font(.maudeKicker(9))
            .tracking(1.2)
            .foregroundStyle(MaudeTheme.ink3)
    }
}

/// The short rule under the sentence: moss in the morning, clay in the evening
/// — the same two marks Home uses for its hero and its closing note.
struct EditionRule: View {
    let edition: WidgetEdition
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(edition == .evening ? MaudeTheme.clay : MaudeTheme.moss)
            .frame(width: 34, height: 2.5)
            .accessibilityHidden(true)
    }
}

/// "as of 07:12" — a widget shows cached state; this makes that honest.
struct StalenessLine: View {
    let derivedAt: Date
    var body: some View {
        Text(WidgetStaleness.asOfText(derivedAt))
            .font(.maudeMono(10))
            .foregroundStyle(MaudeTheme.ink3)
            .lineLimit(1)
    }
}

/// One decomposed signal: label, the user's own value, the baseline-relative
/// word. The attention dot is clay — the app's locked second state, never red.
struct SignalChipView: View {
    let chip: WidgetSignalChip

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if chip.needsAttention {
                    Circle()
                        .fill(MaudeTheme.clay)
                        .frame(width: 5, height: 5)
                }
                Text(chip.label.uppercased())
                    .font(.maudeKicker(8.5))
                    .tracking(1.0)
                    .foregroundStyle(MaudeTheme.ink3)
                    .lineLimit(1)
            }
            Text(chip.value)
                .font(.maudeMono(15))
                .foregroundStyle(MaudeTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(chip.note ?? WidgetCopy.placeholderDash)
                .font(.lato(10))
                .foregroundStyle(chip.needsAttention ? MaudeTheme.clayText : MaudeTheme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// TWO-STATE time in range: inside your range (moss) on an outside track
/// (`line`). Deliberately NOT the clinical five-band ramp and never `clinRed` —
/// a home-screen widget is not a clinical surface.
struct TwoStateRangeBar: View {
    let tir: WidgetTimeInRange
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MaudeTheme.line)
                Capsule()
                    .fill(MaudeTheme.moss)
                    .frame(width: max(0, geo.size.width * tir.insideFraction))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The medium family's full TIR row: bar + the two states named + coverage.
struct TwoStateRangeRow: View {
    let tir: WidgetTimeInRange

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            TwoStateRangeBar(tir: tir)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(WidgetCopy.inRangeHeadline(tir.insidePct))
                    .font(.maudeMono(12))
                    .foregroundStyle(MaudeTheme.ink)
                Text("·")
                    .font(.lato(11))
                    .foregroundStyle(MaudeTheme.ink4)
                Text(WidgetCopy.outsideLabel(tir.outsidePct))
                    .font(.maudeMono(12))
                    .foregroundStyle(MaudeTheme.ink3)
                Spacer(minLength: 4)
                if tir.daysWithReadings > 0 {
                    Text(WidgetCopy.coverageFooter(days: tir.daysWithReadings,
                                                   of: tir.coverageWindowDays))
                        .font(.lato(9.5))
                        .foregroundStyle(MaudeTheme.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetCopy.accessibilityTimeInRange(tir.insidePct))
    }
}
