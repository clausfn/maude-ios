// LiviqaComplication.swift — watchOS face complication (WidgetKit).
// Add to a new **Widget Extension (watchOS)** target (see README_SETUP §Complication).
// Shows a single DESCRIPTIVE fact — today's glucose time-in-range — with the calm
// aperture glyph. No score/verdict (non-MDSW).
//
// Reads the latest value the watch app wrote to the shared App Group
// (group.dev.liviqa.app, key "watch.inRange"); falls back to "—".
import WidgetKit
import SwiftUI

private let appGroup = "group.dev.liviqa.app"
private func latestInRange() -> String {
    UserDefaults(suiteName: appGroup)?.string(forKey: "watch.inRange") ?? "—"
}

struct LiviqaEntry: TimelineEntry {
    let date: Date
    let inRange: String
}

struct LiviqaProvider: TimelineProvider {
    func placeholder(in context: Context) -> LiviqaEntry { LiviqaEntry(date: Date(), inRange: "68%") }
    func getSnapshot(in context: Context, completion: @escaping (LiviqaEntry) -> Void) {
        completion(LiviqaEntry(date: Date(), inRange: latestInRange()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LiviqaEntry>) -> Void) {
        let entry = LiviqaEntry(date: Date(), inRange: latestInRange())
        // Refresh ~hourly; the watch app updates the value and reloads timelines on change.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

struct LiviqaComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LiviqaEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "drop.fill").font(.system(size: 10))
                    Text(entry.inRange).font(.system(size: 15, weight: .heavy, design: .rounded))
                }
            }
        case .accessoryCorner:
            Text(entry.inRange).font(.system(size: 15, weight: .heavy, design: .rounded))
                .widgetLabel("In range")
        default: // accessoryRectangular / inline
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                VStack(alignment: .leading, spacing: 0) {
                    Text("In range").font(.system(size: 11, weight: .semibold))
                    Text(entry.inRange).font(.system(size: 16, weight: .heavy, design: .rounded))
                }
            }
        }
    }
}

@main
struct LiviqaComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LiviqaComplication", provider: LiviqaProvider()) { entry in
            LiviqaComplicationView(entry: entry)
        }
        .configurationDisplayName("In range")
        .description("Today's glucose time-in-range.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
