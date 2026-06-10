import Testing
import Foundation
@testable import Liviqa

// Real last-night sleep-stage breakdown (descriptive). Verifies the derivation
// that drives the production sleep visualisation.
struct SleepDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    private func night(_ daysAgo: Int, deep: Double, core: Double, rem: Double) -> [SleepReading] {
        let d = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
        return [
            SleepReading(date: d, stage: .deep, hours: deep, source: "t", tier: .estimate, provenance: .real),
            SleepReading(date: d, stage: .core, hours: core, source: "t", tier: .estimate, provenance: .real),
            SleepReading(date: d, stage: .rem,  hours: rem,  source: "t", tier: .estimate, provenance: .real),
        ]
    }

    @Test func emptyIsNil() {
        #expect(SleepDeriver.derive(from: .empty) == nil)
    }

    @Test func lastNightStagesAndTotal() {
        // last night: deep 1.0h, core 4.0h, rem 1.0h = 6.0h asleep
        let s = HealthSamples(sleep: night(0, deep: 1.0, core: 4.0, rem: 1.0))
        let sum = SleepDeriver.derive(from: s)
        #expect(sum?.deepMin == 60)
        #expect(sum?.coreMin == 240)
        #expect(sum?.remMin == 60)
        #expect(sum?.asleepMinutes == 360)
        #expect(sum?.hasStageDetail == true)
        #expect(sum?.asleepHoursText == "6h 00m")
    }

    @Test func usesTheMostRecentNight() {
        // older night has different totals; deriver must pick the most recent day.
        let s = HealthSamples(sleep: night(3, deep: 0.5, core: 2.0, rem: 0.5) + night(0, deep: 1.0, core: 4.0, rem: 1.0))
        let sum = SleepDeriver.derive(from: s)
        #expect(sum?.asleepMinutes == 360)   // the recent night, not the old one
    }

    @Test func nightlyWeekHasOnePointPerNight() {
        let s = HealthSamples(sleep: night(2, deep: 1, core: 4, rem: 1) + night(1, deep: 1, core: 3, rem: 1) + night(0, deep: 1, core: 4, rem: 1))
        let sum = SleepDeriver.derive(from: s)
        #expect(sum?.nightlyHoursWeek.count == 3)
    }

    // Undifferentiated total (e.g. a basic tracker) → no stage detail, total still right.
    @Test func unspecifiedOnlyHasNoStageDetail() {
        let d = cal.startOfDay(for: Date())
        let s = HealthSamples(sleep: [SleepReading(date: d, stage: .asleepUnspecified, hours: 7.0,
                                                   source: "t", tier: .estimate, provenance: .real)])
        let sum = SleepDeriver.derive(from: s)
        #expect(sum?.hasStageDetail == false)
        #expect(sum?.asleepMinutes == 420)
    }
}
