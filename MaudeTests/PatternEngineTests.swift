import Testing
import Foundation
@testable import Maude

// FR-PAT-01 — long-horizon pattern engine: generic detectors, computed
// wording, threshold gating. Same contracts as the console engine. T-PAT-01..04.
struct PatternEngineTests {

    // T-PAT-01 — values in titles are COMPUTED (event-free months from dates).
    @Test func arrhythmiaMonthsComputed() {
        var p = PatternInput()
        p.asOf = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 11))!
        p.rhythm = (episodes: 4, lastEpisode: DateComponents(year: 2023, month: 7), ecgTotal: 84, ecgAfib: 12)
        let f = PatternEngine.run(p)
        let arr = f.first { $0.id == "D-ARR-01" }
        #expect(arr != nil)
        #expect(arr!.title.contains("35 months event-free"))
    }

    // T-PAT-02 — active phase (<3 months since episode) produces NO card.
    @Test func activePhaseStaysQuiet() {
        var p = PatternInput()
        let cal = Calendar.current
        let recent = cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: -1, to: Date())!)
        p.rhythm = (episodes: 1, lastEpisode: recent, ecgTotal: 4, ecgAfib: 2)
        #expect(PatternEngine.run(p).first { $0.id == "D-ARR-01" } == nil)
    }

    // T-PAT-03 — thresholds gate firing: a 5 mmHg home/office gap is not a finding.
    @Test func smallGapNotAFinding() {
        var p = PatternInput()
        p.bp = (homeSys: 126, homeDia: 78, officeSysAvg: 131, nHome: 50, spanYears: 3)
        #expect(PatternEngine.run(p).first { $0.id == "D-WCG-01" } == nil)
        p.bp = (homeSys: 115, homeDia: 73, officeSysAvg: 131, nHome: 50, spanYears: 3)
        let f = PatternEngine.run(p).first { $0.id == "D-WCG-01" }
        #expect(f != nil)
        #expect(f!.title.contains("16 mmHg below office"))
    }

    // T-PAT-04 — empty input → no findings; LV001 seed → full set.
    @Test func emptyAndSeed() {
        #expect(PatternEngine.run(PatternInput()).isEmpty)
        let f = PatternEngine.run(.lv001)
        #expect(f.count >= 7)
        #expect(f.allSatisfy { !$0.citizen.isEmpty && !$0.title.isEmpty })
    }
}
