// PatternSeed.swift — LV001's long-horizon aggregates (demo input · 2026-06-11).
//
// Mirrors the console's LV001_INPUT (real values, mined from the consented
// record). The engine is generic; this is ONE citizen's input. With real
// HealthKit data the summarisation pipeline will compute PatternInput from
// the device history instead (backlog: FR-PAT-02).
import Foundation

extension PatternInput {
    static var lv001: PatternInput {
        var p = PatternInput()
        p.rhythm = (episodes: 4, lastEpisode: DateComponents(year: 2023, month: 7), ecgTotal: 84, ecgAfib: 12)
        p.glucoseYearly = [2016: 7.0, 2017: 6.7, 2018: 6.9, 2019: 7.9, 2020: 9.9,
                           2021: 8.1, 2022: 8.6, 2023: 8.2, 2024: 8.0, 2025: 8.1]
        p.bp = (homeSys: 115, homeDia: 73, officeSysAvg: 131, nHome: 180, spanYears: 14)
        p.sleepYearly = [2024: 5.8, 2025: 7.7]
        p.trainingGap = (weeks: 8, weeksToBaseline: 14)
        p.exposure = (pctMinutesHighPM: 20, eveningPM: 57, morningPM: 40)
        p.benchmark = (routeKm: 23.5, firstMin: 44.5, bestMin: 41.5, bestWhen: "Apr 2026")
        p.drift = (bpmRise: 21, ())
        return p
    }
}

extension Nudge {
    /// Card from a long-horizon pattern finding: the citizen sentence leads;
    /// "Why this?" carries the chart-note title + the fact + provenance.
    init(finding f: PatternFinding) {
        let accent: NudgeAccent
        switch f.group {
        case "Heart & rhythm":      accent = .cardiac
        case "Glucose":             accent = .glucose
        case "Sleep", "Recovery":   accent = .sleep
        default:                    accent = .general
        }
        self.init(
            time: "pattern",
            tag: f.group,
            body: f.citizen,
            accent: accent,
            primaryAction: "Show pattern",
            secondaryActions: ["Later"],
            reasoning: "\(f.title). \(f.fact)",
            dataPoints: [f.source, "Detector \(f.id)"]
        )
    }
}
