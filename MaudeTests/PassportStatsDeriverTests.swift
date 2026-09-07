import Testing
import Foundation
@testable import Maude

// FR-PAS-05 / DM-05 — on-device derivation of the Passport's sensor half. T-PAS-01.
struct PassportStatsDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ o: Int) -> Date { cal.date(byAdding: .day, value: o, to: Date())! }

    private func sampleSet() -> HealthSamples {
        var s = HealthSamples()
        // 10 glucose: 7 in 3.9–10.0, 3 out → TIR 70%
        let mmols = [5.0, 6.0, 7.0, 8.0, 9.0, 4.0, 9.9, 11.5, 3.0, 12.0]
        for (i, v) in mmols.enumerated() {
            s.glucose.append(GlucoseReading(ts: day(-(i % 3)), mmol: v,
                source: "cgm", tier: .good, provenance: .real))
        }
        // sleep: 3 nights asleep 7/8/6h, each with an excluded 1h awake row
        for (i, h) in [7.0, 8.0, 6.0].enumerated() {
            s.sleep.append(SleepReading(date: day(-(i+1)), stage: .asleepUnspecified, hours: h,
                source: "watch", tier: .good, provenance: .real))
            s.sleep.append(SleepReading(date: day(-(i+1)), stage: .awake, hours: 1.0,
                source: "watch", tier: .good, provenance: .real))
        }
        s.steps.append(DailyMetric(date: day(-3), kind: .steps, value: 8000,
            source: "phone", tier: .good, provenance: .real))
        return s
    }

    @Test func derivesTirSleepDaysAndReadings() {
        let d = PassportStatsDeriver.derive(from: sampleSet())
        #expect(d.glucoseTimeInRange == 70)      // 7/10
        #expect(d.avgSleepHours == 7.0)          // (7+8+6)/3, awake excluded
        #expect(d.daysTracked == 4)              // days 0,-1,-2,-3
        #expect(d.totalReadings == 17)           // 10 glucose + 6 sleep + 1 steps
    }

    @Test func emptySamplesAreSafe() {
        let d = PassportStatsDeriver.derive(from: .empty)
        #expect(d.glucoseTimeInRange == 0)
        #expect(d.avgSleepHours == 0)
        #expect(d.daysTracked == 0)
        #expect(d.totalReadings == 0)
    }

    @Test func tirRespectsCustomBand() {
        var s = HealthSamples()
        for v in [4.5, 5.0, 11.0, 12.0] {     // tight band 4–6 → 2/4 in range
            s.glucose.append(GlucoseReading(ts: day(0), mmol: v,
                source: "cgm", tier: .good, provenance: .real))
        }
        let d = PassportStatsDeriver.derive(from: s, tirLowMmol: 4.0, tirHighMmol: 6.0)
        #expect(d.glucoseTimeInRange == 50)
    }
}
