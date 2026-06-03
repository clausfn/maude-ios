import Testing
import Foundation
@testable import Liviqa

// FR-NDG (§6.2 lead example) — workout↔glucose coupling. Within-user only;
// must stay FR-NDG-06 clean. T-NDG-08.
struct WorkoutGlucoseNudgeTests {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: Date())!
    }

    /// A cycling session at `start` (90 min) with glucose `pre` before and `post` after.
    private func ride(dayOffset: Int, pre: Double, post: Double,
                      into s: inout HealthSamples) {
        let start = day(dayOffset)
        let end = start.addingTimeInterval(90 * 60)
        s.workouts.append(WorkoutReading(start: start, end: end, type: "Cycling",
            durMin: 90, kcal: 600, distKm: 30,
            source: "watch", tier: .good, provenance: .real))
        // pre: 30 min before start; post: 30 min after end
        s.glucose.append(GlucoseReading(ts: start.addingTimeInterval(-30*60), mmol: pre,
            source: "cgm", tier: .good, provenance: .real))
        s.glucose.append(GlucoseReading(ts: end.addingTimeInterval(30*60), mmol: post,
            source: "cgm", tier: .good, provenance: .real))
    }

    @Test func firesWhenLatestRideDropsGlucoseMoreThanUsual() {
        var s = HealthSamples()
        // 4 prior rides: ~0.6 mmol/L drop each.
        ride(dayOffset: -6, pre: 8.0, post: 7.4, into: &s)
        ride(dayOffset: -5, pre: 8.1, post: 7.5, into: &s)
        ride(dayOffset: -4, pre: 7.9, post: 7.3, into: &s)
        ride(dayOffset: -3, pre: 8.0, post: 7.4, into: &s)
        // latest ride: big 2.5 drop
        ride(dayOffset: 0, pre: 8.0, post: 5.5, into: &s)

        let nudges = NudgeEngine().generate(samples: s)
        let coupling = nudges.first { $0.title.lowercased().contains("after your cycling") }
        #expect(coupling != nil)
        #expect(coupling?.lane == .watch)
        // Guard: lead example must be FR-NDG-06 clean.
        #expect(coupling.map { NudgeGuard.isValid($0) } == true)
        #expect(coupling?.body.contains("%") == true)
    }

    @Test func silentWhenDropIsTypical() {
        var s = HealthSamples()
        for d in [-6, -5, -4, -3, 0] { ride(dayOffset: d, pre: 8.0, post: 7.4, into: &s) }
        let nudges = NudgeEngine().generate(samples: s)
        #expect(!nudges.contains { $0.title.lowercased().contains("after your cycling") })
    }

    @Test func silentWithoutEnoughHistory() {
        var s = HealthSamples()
        ride(dayOffset: -3, pre: 8.0, post: 7.4, into: &s)
        ride(dayOffset: 0, pre: 8.0, post: 5.0, into: &s)   // only 1 prior → no baseline
        let nudges = NudgeEngine().generate(samples: s)
        #expect(!nudges.contains { $0.title.lowercased().contains("after your cycling") })
    }
}
