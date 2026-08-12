import Testing
import Foundation
@testable import Liviqa

// T-FIT-01 — the HR-in-interval ingestion that turns the Fitness screen's
// avg-HR and Z1–Z4 time-in-zone from demo-only into real-data surfaces.
//
// The claims under test:
//   1. the deriver reads `HealthSamples.workoutHeartRate` with no extra wiring
//   2. arbitration (§2.3) carries that stream through — a dropped stream would
//      silently re-open the gap after `arbitrated()`
//   3. absence stays honest: no beats ⇒ no avg-HR figure and no zone card
//   4. the zone scale is the citizen's OWN observed maximum, and the card says
//      so — never an age formula, never a population scale, never a target
//   5. the demo provider now carries beats too, so the demo screen shows the
//      same anatomy the design package draws
struct WorkoutHeartRateIngestionTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date { cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())! }
    private func at(day: Int, hour: Int = 17) -> Date {
        let d = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: now))!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d)!
    }
    private func ride(day: Int, durMin: Double = 60) -> WorkoutReading {
        WorkoutReading(start: at(day: day), end: at(day: day).addingTimeInterval(durMin * 60),
                       type: "Cycling", durMin: durMin, kcal: 480, distKm: 20,
                       source: "Watch", tier: .estimate, provenance: .real)
    }
    /// 60 min of beats inside the day-`day` ride: 30 at 120, 29 at 150, one 160.
    private func beats(day: Int) -> [HeartRateSample] {
        var out: [HeartRateSample] = []
        for m in 0..<30 { out.append(.init(ts: at(day: day).addingTimeInterval(Double(m) * 60), bpm: 120, source: "Watch", tier: .good, provenance: .real)) }
        for m in 30..<59 { out.append(.init(ts: at(day: day).addingTimeInterval(Double(m) * 60), bpm: 150, source: "Watch", tier: .good, provenance: .real)) }
        out.append(.init(ts: at(day: day).addingTimeInterval(59 * 60), bpm: 160, source: "Watch", tier: .good, provenance: .real))
        return out
    }

    // 1 — ingested beats reach the deriver without a parameter.
    @Test func ingestedBeatsUnlockAvgHRAndZones() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0)]
        s.workoutHeartRate = beats(day: 0)
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(d.weekAvgHR != nil)
        #expect(!d.zones.isEmpty)
        #expect(d.workouts.first?.meta.contains("bpm") == true)
        // 120/160 = 0.75 ⇒ Z2; 150/160 ≈ 0.94 ⇒ Z4.
        #expect(d.zones.contains { $0.name.hasPrefix("Z2") })
        #expect(d.zones.contains { $0.name.hasPrefix("Z4") })
        // Time in zone can never exceed the session it came from.
        #expect(d.zones.map(\.minutes).reduce(0, +) <= 61)
    }

    // 2 — §2.3 arbitration must not drop the stream.
    @Test func arbitrationCarriesWorkoutHeartRate() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0)]
        s.workoutHeartRate = beats(day: 0)
        let a = s.arbitrated()
        #expect(a.workoutHeartRate.count == s.workoutHeartRate.count)
        #expect(FitnessDeriver.derive(from: a, now: now)?.weekAvgHR != nil)
    }

    // 3 — honest absence: a session with no beats shows no HR and no zones.
    @Test func withoutBeatsAvgHRAndZonesStayAbsent() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0)]
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(d.weekAvgHR == nil)
        #expect(d.zones.isEmpty)
        #expect(d.zoneOwnMaxHR == nil)
        #expect(d.workouts.first?.meta.contains("bpm") == false)
    }

    // 4 — the zone reference is the citizen's own observed maximum, printed.
    @Test func zoneScaleIsTheCitizensOwnMaximum() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0)]
        s.workoutHeartRate = beats(day: 0)
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(d.zoneOwnMaxHR == 160)              // the highest beat, not 220−age
        let m = FitnessDetailView.Model(derived: d)
        let foot = try #require(m.zonesFoot)
        #expect(foot.contains("160 bpm"))
        #expect(foot.contains("your own"))
        #expect(foot.lowercased().contains("not a target"))
        // Every sentence on this card is FR-NDG-06 clean.
        #expect(NudgeGuard.check(foot) == nil)
        #expect(NudgeGuard.check(m.zonesHeadline) == nil)
        #expect(NudgeGuard.check(m.verdict) == nil)
    }

    // 5 — the demo provider carries beats, so the demo screen is the real one.
    @Test func demoProviderCarriesWorkoutBeats() async throws {
        let end = Date(timeIntervalSince1970: 1_750_000_000)
        let s = try await MockDataProvider().fetchSamples(from: end.addingTimeInterval(-13 * 86_400), to: end)
        #expect(!s.workoutHeartRate.isEmpty)
        // Demo data must stay SIMULATED (the clinical-tier gate).
        #expect(s.workoutHeartRate.allSatisfy { $0.provenance == .simulated })
        // Every beat falls inside a workout interval — nothing free-floating.
        #expect(s.workoutHeartRate.allSatisfy { beat in
            s.workouts.contains { beat.ts >= $0.start && beat.ts <= $0.end }
        })
        let d = try #require(FitnessDeriver.derive(from: s.arbitrated(), now: end))
        #expect(d.weekAvgHR != nil)
    }
}
