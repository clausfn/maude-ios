// EngineNudge+Card.swift — adapt L3 engine output to the locked prototype card.
//
// The engine emits `EngineNudge` (domain). The prototype renders `Nudge` (a
// presentation card view-model in Models/MockData.swift, left untouched per the
// cardinal rule). This is the one seam between the two. The card text comes
// straight from the engine (already FR-NDG-06-clean); we add no clinical copy.
import Foundation

extension NudgeAccent {
    /// Visual accent from the regulatory lane + category (no interpretation).
    init(lane: RegulatoryLane, category: NudgeCategory) {
        switch (lane, category) {
        case (.displayOnly, _):     self = .cardiac     // AFib / cardiac
        case (.watch, .bandStatus): self = .glucose     // glucose band
        case (.wellness, _):        self = .sleep        // recovery / sleep / activity
        default:                    self = .general      // numbers, verdicts
        }
    }
}

extension Nudge {
    /// Build a prototype card from an engine nudge. `at` is the display time.
    init(engine n: EngineNudge, at date: Date = Date()) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"

        let primary: String
        switch n.category {
        case .routeToClinician: primary = "Share with clinician"
        case .behaviouralLever: primary = "Show pattern"
        default:                primary = "Open"
        }

        self.init(
            time: df.string(from: date),
            tag: n.title,
            body: n.body,
            accent: NudgeAccent(lane: n.lane, category: n.category),
            primaryAction: primary,
            secondaryActions: ["Note in journal", "Later"],
            reasoning: n.evidence ?? "Computed on this device from your consented data, against your own baseline — not a clinical range.",
            dataPoints: n.points
        )
    }
}
