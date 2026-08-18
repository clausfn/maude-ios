// WholePersonSurfacingTests.swift — T-WPS-01 (CN directive 2026-08-19: "Why
// don't I see activities, steps, exercise? … This is an app for all people").
//
// Two guarantees:
//  1. The week grid's EXERCISE row is REAL: it derives from the person's own
//     ingested active energy (workout minutes only as the whole-week fallback),
//     and stays honestly empty when neither exists — never demo-fed on the real
//     path. (`AppState.refreshFromHealth` builds the grid from the same
//     `HealthSamples` the HealthKit provider returned; pinned behaviourally
//     here at the deriver seam.)
//  2. The Activity / Fitness / Body / Vitals detail screens are no longer
//     reachable ONLY through the Passport: the Insights root carries first-class
//     entries, and the Passport keeps its own (the defect was exclusivity).
//     Structural, so it is pinned SourceLint-style — the regression would be a
//     deleted NavigationLink, which no behavioural test can see.
import Testing
import Foundation
@testable import Liviqa

struct WholePersonSurfacingTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ o: Int) -> Date { cal.date(byAdding: .day, value: -o, to: Date())! }

    // MARK: 1 — the EXERCISE row renders from real ingested movement

    @Test func exerciseRowDerivesFromRealActiveEnergy() {
        var s = HealthSamples()
        // A real week of active energy with one clearly bigger day.
        for off in 0...6 {
            let v = (off == 2) ? 980.0 : 430.0
            s.activeEnergy.append(DailyMetric(date: day(off), kind: .activeEnergy,
                value: v, source: "watch", tier: .estimate, provenance: .real))
        }
        let g = CorrelationDeriver.derive(from: s)
        let exCol = 3
        // Every day with a reading gets a real cell — the row is not demo-fed
        // and not permanently empty.
        #expect(g.rows.allSatisfy { $0.cells[exCol] != .noData })
        // The big day reads as a deviation from the person's OWN week.
        let bigDay = g.rows.first { $0.dateOffset == 2 }
        #expect(bigDay?.cells[exCol] == .high || bigDay?.cells[exCol] == .outlier)
    }

    @Test func exerciseRowFallsBackToWorkoutMinutesOnlyWhenTheWeekHasNoEnergy() {
        var s = HealthSamples()
        for off in [1, 3, 5] {
            let start = cal.startOfDay(for: day(off)).addingTimeInterval(17 * 3600)
            s.workouts.append(WorkoutReading(start: start, end: start + 40 * 60,
                type: "functionalStrengthTraining", durMin: 40, kcal: 300, distKm: 0,
                source: "watch", tier: .good, provenance: .real))
        }
        let g = CorrelationDeriver.derive(from: s)
        let exCol = 3
        let workoutDays = g.rows.filter { [1, 3, 5].contains($0.dateOffset) }
        #expect(workoutDays.allSatisfy { $0.cells[exCol] != .noData })
        // Days without a workout stay honestly empty in the fallback unit.
        let restDays = g.rows.filter { [0, 2, 4, 6].contains($0.dateOffset) }
        #expect(restDays.allSatisfy { $0.cells[exCol] == .noData })
    }

    @Test func noMovementDataMeansAnHonestlyEmptyExerciseRow() {
        var s = HealthSamples()
        for off in 0...6 {
            s.hrv.append(DailyMetric(date: day(off), kind: .hrvSDNN, value: 48,
                source: "watch", tier: .good, provenance: .real))
        }
        let g = CorrelationDeriver.derive(from: s)
        #expect(g.rows.allSatisfy { $0.cells[3] == .noData })
    }

    // MARK: 2 — Activity/Fitness/Body/Vitals are first-class, not Passport-only

    @Test func insightsRootCarriesEntriesToAllFourDepthScreens() throws {
        let src = try SourceLint.text("Liviqa/Views/WeekInContextView.swift")
        for pillar in ["activity", "fitness", "body", "vitals"] {
            #expect(!SourceLint.matches(#"depthRow\(pillar: \.\#(pillar)\)"#, in: src).isEmpty,
                    "Insights root lost its \(pillar) entry")
        }
        // The rows navigate somewhere real.
        #expect(!SourceLint.matches(#"NavigationLink\(destination: MetricDetailView\(pillar: pillar\)\)"#,
                                    in: src).isEmpty)
    }

    @Test func thePassportKeepsItsOwnEntriesTheDefectWasExclusivity() throws {
        let src = try SourceLint.text("Liviqa/Views/HealthPassportView.swift")
        for pillar in ["activity", "fitness", "body", "vitals"] {
            #expect(!SourceLint.matches(#"depthRow\(pillar: \.\#(pillar)\)"#, in: src).isEmpty,
                    "Passport lost its \(pillar) entry")
        }
    }
}
