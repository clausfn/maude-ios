// MaudeComplication.swift — watchOS face complication (WidgetKit).
//
// TARGET MEMBERSHIP: a **Widget Extension (watchOS)** target named
// "Maude Complication". See `MaudeWidgets/SETUP.md` §8 for the click-path.
// It also needs `MaudeWidgets/Shared/MaudeWidgetSnapshot.swift` and
// `MaudeWidgets/Shared/WidgetCopy.swift` as members.
//
// Shows a single DESCRIPTIVE fact — time in range — plus, where the family has
// room, WHEN it was last updated. No score, no verdict, no advice (non-MDSW,
// same line as the phone). Time in range is two-state by construction here: one
// number, no clinical band ramp, no red.
//
// DATA (FR-WID-01). Preferred source is the shared App Group snapshot the phone
// publishes (`MaudeWidgetSnapshotStore`), which also carries `derivedAt` so the
// complication can be honest about staleness. It falls back to the legacy
// `watch.inRange` key that `WatchSessionReceiver` writes on WatchConnectivity
// delivery, so a watch that has only ever had a glance still shows a value.
// Neither path is available ⇒ "—". Nothing is ever invented.
//
// COLOUR. Deliberately none: watch faces tint complications themselves, and the
// A7.2 palette does not survive that tinting. The face's own accent wins.
import WidgetKit
import SwiftUI

// MARK: - Data

/// The complication's read of the world. `asOf` nil ⇒ we have a value but not a
/// timestamp (the legacy glance path) → the staleness line is omitted rather
/// than filled with a guess.
nonisolated struct MaudeComplicationState: Equatable {
    let inRange: String
    let asOf: Date?

    static let absent = MaudeComplicationState(inRange: WidgetCopy.placeholderDash, asOf: nil)
    var hasValue: Bool { inRange != WidgetCopy.placeholderDash }

    /// Snapshot first (richer + timestamped), then the legacy glance key.
    /// The App Group id comes from the target's Info.plist `MaudeAppGroup`
    /// (= `$(APP_GROUP)`); it is never hard-coded here.
    static func current() -> MaudeComplicationState {
        if let snap = MaudeWidgetSnapshotStore.load(), let tir = snap.timeInRange {
            return MaudeComplicationState(inRange: "\(tir.insidePct)%", asOf: snap.derivedAt)
        }
        if let legacy = MaudeWidgetSnapshotStore.defaults()?.string(forKey: legacyGlanceKey),
           !legacy.isEmpty, legacy != WidgetCopy.placeholderDash {
            return MaudeComplicationState(inRange: legacy, asOf: nil)
        }
        return .absent
    }

    /// Written by `MaudeWatch/Connectivity/WatchSessionReceiver.swift`.
    /// Kept for backwards compatibility — do not remove without that file.
    static let legacyGlanceKey = "watch.inRange"
}

// MARK: - Timeline

nonisolated struct MaudeEntry: TimelineEntry {
    let date: Date
    let state: MaudeComplicationState

    var inRange: String { state.inRange }
}

nonisolated struct MaudeProvider: TimelineProvider {

    func placeholder(in context: Context) -> MaudeEntry {
        // Gallery/redacted cell only — shaped like a real value so the layout
        // previews truthfully. Never reaches a configured complication.
        MaudeEntry(date: Date(),
                    state: MaudeComplicationState(inRange: "68%", asOf: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (MaudeEntry) -> Void) {
        let state = context.isPreview
            ? MaudeComplicationState(inRange: "68%", asOf: Date())
            : MaudeComplicationState.current()
        completion(MaudeEntry(date: Date(), state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MaudeEntry>) -> Void) {
        let entry = MaudeEntry(date: Date(), state: .current())
        // The watch app and the phone both reload this kind when a new value
        // lands; the hourly policy is only the backstop.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct MaudeComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MaudeEntry

    private var label: String { WidgetCopy.complicationInRangeLabel }

    var body: some View {
        switch family {

        case .accessoryCircular:
            // Glyph over the figure. The circular slot has no room for a
            // timestamp, so it carries none rather than an abbreviation.
            VStack(spacing: -1) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9))
                    .widgetAccentable()
                Text(entry.inRange)
                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityLabel(accessibilityText)

        case .accessoryCorner:
            // The figure sits in the corner; the curved label rides the bezel.
            Text(entry.inRange)
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .minimumScaleFactor(0.7)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetLabel(label)
                .accessibilityLabel(accessibilityText)

        case .accessoryInline:
            // Inline gets its own single-line branch (design: "In range 68%") —
            // the rectangular HStack flattens unpredictably in inline slots.
            // Inline is a single unstyled string; no timestamp fits.
            Text("\(label) \(entry.inRange)")
                .accessibilityLabel(accessibilityText)

        default: // .accessoryRectangular
            // The only family with room for the honest staleness line.
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .widgetAccentable()
                    Text(entry.inRange)
                        .font(.system(size: 16, weight: .heavy).monospacedDigit())
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    if let asOf = entry.state.asOf {
                        Text(WidgetStaleness.asOfText(asOf))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    /// One spoken sentence for every family. Honest when there is no value yet.
    private var accessibilityText: String {
        guard entry.state.hasValue else { return WidgetCopy.emptyTitle }
        var text = "\(label) \(entry.inRange)"
        if let asOf = entry.state.asOf {
            text += ", \(WidgetStaleness.asOfText(asOf))"
        }
        return text
    }
}

// MARK: - Widget

@main
struct MaudeComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MaudeComplication.kind, provider: MaudeProvider()) { entry in
            MaudeComplicationView(entry: entry)
        }
        .configurationDisplayName(WidgetCopy.complicationName)
        .description(WidgetCopy.complicationDescription)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular,
                            .accessoryCorner, .accessoryInline])
    }

    static let kind = "MaudeComplication"
}
