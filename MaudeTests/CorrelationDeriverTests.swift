import Testing
import Foundation
@testable import Maude

// FR-PAS-05 / DM-06 — on-device 7-day correlation grid. T-COR-01.
struct CorrelationDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ o: Int) -> Date { cal.date(byAdding: .day, value: -o, to: Date())! }

    /// Steady HRV across the week except one sharp dip 4 days ago.
    private func samplesWithHRVOutlier() -> HealthSamples {
        var s = HealthSamples()
        for off in 0...6 {
            let v = (off == 4) ? 15.0 : 55.0      // day -4 is the outlier
            s.hrv.append(DailyMetric(date: day(off), kind: .hrvSDNN, value: v,
                source: "watch", tier: .good, provenance: .real))
        }
        return s
    }

    @Test func gridShapeIsSevenBySeven() {
        let g = CorrelationDeriver.derive(from: samplesWithHRVOutlier())
        #expect(g.signals.count == 7)
        #expect(g.rows.count == 7)
        #expect(g.rows.allSatisfy { $0.cells.count == 7 })
        // External signals (spending/calendar/weather) are never fabricated.
        #expect(g.rows.allSatisfy { $0.cells[4...6].allSatisfy { $0 == .noData } })
        // Oldest first.
        #expect(g.rows.first?.dateOffset == 6 && g.rows.last?.dateOffset == 0)
    }

    @Test func flagsTheOutlierDayAndNamesTheSignal() {
        let g = CorrelationDeriver.derive(from: samplesWithHRVOutlier())
        let hrvCol = 2
        let outlierRow = g.rows.first { $0.cells[hrvCol] == .outlier }
        #expect(outlierRow != nil)
        #expect(g.patternSources.contains("HRV"))
        #expect(g.patternStrength == "Strong")
        // Pattern note must be FR-NDG-06 clean (no clinical/diagnostic language).
        #expect(NudgeGuard.check(g.patternNote) == nil)
    }

    /// Regression (T-COR-02): an ordinary MIXED week — steady active-energy kcal
    /// every day plus two normal ~45-min walks — must NOT flag the walk days.
    /// The old column mixed workout MINUTES (workout days) with active-energy
    /// KCAL (other days), so a 45-min value z-scored against a ~500-kcal mean
    /// flagged both healthy walk days `.high` and fabricated an exercise standout.
    @Test func ordinaryMixedExerciseWeekFlagsNoWalkDays() {
        var s = HealthSamples()
        for off in 0...6 {
            s.activeEnergy.append(DailyMetric(date: day(off), kind: .activeEnergy,
                value: 500.0, source: "watch", tier: .estimate, provenance: .real))
        }
        // Two ordinary 45-minute walks (their burn is already in active energy).
        for off in [2, 5] {
            let start = cal.startOfDay(for: day(off)).addingTimeInterval(9 * 3600)
            s.workouts.append(WorkoutReading(start: start, end: start + 45 * 60,
                type: "walking", durMin: 45, kcal: 200, distKm: 4,
                source: "watch", tier: .good, provenance: .real))
        }
        let g = CorrelationDeriver.derive(from: s)
        let exCol = 3
        #expect(g.rows.allSatisfy { $0.cells[exCol] != .high && $0.cells[exCol] != .outlier })
        // Exercise must not be fabricated as the week's standout signal.
        #expect(!g.patternSources.contains("Exercise"))
        #expect(NudgeGuard.check(g.patternNote) == nil)
    }

    @Test func steadyWeekHasNoSources() {
        var s = HealthSamples()
        for off in 0...6 {
            s.hrv.append(DailyMetric(date: day(off), kind: .hrvSDNN, value: 55.0,
                source: "watch", tier: .good, provenance: .real))
        }
        let g = CorrelationDeriver.derive(from: s)
        #expect(g.patternSources.isEmpty)
        #expect(g.patternStrength == "Steady")
        #expect(NudgeGuard.check(g.patternNote) == nil)
    }
}
