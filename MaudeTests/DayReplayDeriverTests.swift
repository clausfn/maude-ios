import Testing
import Foundation
@testable import Maude

// Area ② "Replay your day" — DayReplayDeriver. The moment card narrates ONLY
// what these figures hold; if the derivation is nil the screen stays honestly
// empty (never a fabricated curve).
struct DayReplayDeriverTests {

    private let cal = Calendar(identifier: .gregorian)
    private var startOfDay: Date { cal.startOfDay(for: Date()) }

    private func reading(_ hour: Double, _ mmol: Double) -> GlucoseReading {
        GlucoseReading(ts: startOfDay.addingTimeInterval(hour * 3600), mmol: mmol,
                       source: "cgm", tier: .good, provenance: .real)
    }

    @Test func fewReadingsDeriveNil() {
        var s = HealthSamples()
        s.glucose = [reading(9, 6.0)]
        #expect(DayReplayDeriver.derive(from: s) == nil)
    }

    @Test func yesterdayReadingsDoNotCount() {
        var s = HealthSamples()
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfDay)!
        s.glucose = (0..<5).map {
            GlucoseReading(ts: yesterday.addingTimeInterval(Double($0) * 3600 + 8 * 3600),
                           mmol: 6.0, source: "cgm", tier: .good, provenance: .real)
        }
        #expect(DayReplayDeriver.derive(from: s) == nil)
    }

    @Test func derivesPeakAndBackInRange() throws {
        var s = HealthSamples()
        // A steady morning, one lunch spike at 13:40 (11.2), back in band by 15:20.
        s.glucose = [
            reading(8.0, 5.6), reading(10.0, 6.1), reading(12.0, 7.0),
            reading(13.0, 9.4),
            reading(13.0 + 40.0 / 60.0, 11.2),        // 13:40 — the peak
            reading(14.5, 10.4),
            reading(15.0 + 20.0 / 60.0, 8.9),         // 15:20 — back in range
            reading(17.0, 6.4),
        ]
        let r = try #require(DayReplayDeriver.derive(from: s))
        #expect(r.points.count == 8)
        #expect(r.aboveRuns == 1)
        let peak = try #require(r.peakIndex)
        #expect(r.points[peak].mmol == 11.2)
        #expect(r.points[peak].timeText == "13:40")
        #expect(r.backInRangeText == "15:20")
        #expect(r.workoutNote == nil)      // no workout tracked → nothing claimed
    }

    @Test func steadyDayHasNoPeakOrRuns() throws {
        var s = HealthSamples()
        s.glucose = [reading(8, 5.2), reading(11, 6.4), reading(14, 7.1), reading(18, 5.9)]
        let r = try #require(DayReplayDeriver.derive(from: s))
        #expect(r.peakIndex == nil)
        #expect(r.aboveRuns == 0)
        #expect(r.backInRangeText == nil)
    }

    @Test func workoutNearPeakIsNamedFromRealData() throws {
        var s = HealthSamples()
        s.glucose = [reading(11, 6.0), reading(13, 11.5), reading(15, 7.0)]
        // A real tracked walk ending 30 minutes before the 13:00 peak.
        let end = startOfDay.addingTimeInterval(12.5 * 3600)
        s.workouts = [WorkoutReading(start: end.addingTimeInterval(-30 * 60), end: end,
                                     type: "Walking", durMin: 30,
                                     source: "watch", tier: .good, provenance: .real)]
        let r = try #require(DayReplayDeriver.derive(from: s))
        let note = try #require(r.workoutNote)
        #expect(note.contains("30-min"))
        #expect(note.lowercased().contains("walking"))
        #expect(NudgeGuard.check(note) == nil)
    }
}
