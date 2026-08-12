// EditionWidget.swift — the iOS home-screen widget (FR-WID-01, Bevel absorb ①).
//
// TARGET MEMBERSHIP: the **Liviqa Widgets** iOS Widget Extension target only.
//
// WHAT THIS IS NOT. It is not a score ring. Bevel's loudest user complaint was
// score opacity — a single number with hidden arithmetic. Liviqa's structural
// answer is decomposition, so this widget shows: the edition SENTENCE, the
// individual signals behind it (each with the user's own value and a
// baseline-relative word), and a two-state time-in-range read. There is no
// composite figure anywhere on it, and there is nothing to tap to "find out how
// it was calculated" — the calculation is the face of the widget.
//
// A widget always renders CACHED state, so every family carries "as of HH:MM".
// Saying when is the difference between a stale widget and a dishonest one.
import WidgetKit
import SwiftUI

// MARK: - Entry

nonisolated struct EditionEntry: TimelineEntry {
    let date: Date
    /// nil ⇒ nothing published yet → the honest empty state. Never a stand-in.
    let snapshot: LiviqaWidgetSnapshot?
}

// MARK: - Provider

nonisolated struct EditionProvider: TimelineProvider {

    /// The gallery/placeholder cell. Redacted by WidgetKit, so these figures are
    /// never read as the user's — but they are still shaped like real ones so
    /// the layout previews truthfully.
    func placeholder(in context: Context) -> EditionEntry {
        EditionEntry(date: Date(), snapshot: Self.galleryPreview)
    }

    func getSnapshot(in context: Context, completion: @escaping (EditionEntry) -> Void) {
        // In the gallery (isPreview) there is no user context to show; anywhere
        // else, show exactly what the app last published — or nothing.
        let snap = context.isPreview
            ? Self.galleryPreview
            : LiviqaWidgetSnapshotStore.load()
        completion(EditionEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EditionEntry>) -> Void) {
        let entry = EditionEntry(date: Date(), snapshot: LiviqaWidgetSnapshotStore.load())
        // The app reloads this timeline after every derivation
        // (`AppState.publishWidgetSnapshot`), so this interval is only the
        // backstop that keeps the "as of" line from silently ageing all day.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Gallery-only sample. It is NOT user data and never reaches a configured
    /// widget — `getTimeline` reads the real store unconditionally.
    static let galleryPreview = LiviqaWidgetSnapshot(
        derivedAt: Date(),
        edition: .morning,
        verdict: String(localized: "You're having a steady week."),
        chips: [
            WidgetSignalChip(label: String(localized: "Sleep"), value: "6h52",
                             note: String(localized: "As usual")),
            WidgetSignalChip(label: String(localized: "Recovery"), value: "48 ms",
                             note: String(localized: "Steady")),
            WidgetSignalChip(label: String(localized: "Heart"), value: "58",
                             note: String(localized: "Calm")),
        ],
        timeInRange: WidgetTimeInRange(inRangePct: 68, daysWithReadings: 6))
}

// MARK: - Widget

struct LiviqaEditionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LiviqaEditionWidget.kind, provider: EditionProvider()) { entry in
            EditionWidgetView(entry: entry)
                .containerBackground(LiviqaTheme.paper2, for: .widget)
        }
        .configurationDisplayName(WidgetCopy.editionWidgetName)
        .description(WidgetCopy.editionWidgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }

    /// Must match `AppState.editionWidgetKind` in the app target.
    static let kind = "LiviqaEditionWidget"
}
