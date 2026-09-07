import Testing
import Foundation
@testable import Maude

// Sleep intra-night ingestion — the segment START times and the AWAKE stage
// that turn the søkort depth chart, the wake-up moment and the bedtime card
// from demo-only into real-data surfaces.
//
// The claims under test:
//   1. with times, last night derives a shape (segments, soundings, wake-up)
//   2. without times, the shape is nil — the screen keeps its reduced anatomy
//      rather than inventing a night
//   3. AWAKE never inflates an asleep total, and the AWAKE tile counts only
//      wake-ups INSIDE the night
//   4. the nightly union uses the real start times (many short segments of one
//      night used to collapse to the longest one)
//   5. bedtime is compared to the citizen's OWN mean bedtime, never to a
//      recommended hour, and refuses to render below three timed nights
//   6. every sentence these surfaces introduce is FR-NDG-06 clean
struct SleepNightShapeTests {

    private let cal = Calendar(identifier: .gregorian)
    private var now: Date { cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())! }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }
    /// A segment on the night ending on day `offset`, starting `hoursBefore`
    /// hours before that day's midnight (so 1.5 ⇒ 22:30 the evening before).
    private func seg(_ stage: SleepStage, _ hours: Double,
                     night offset: Int, from hoursBefore: Double,
                     source: String = "Watch") -> SleepReading {
        SleepReading(date: day(offset), stage: stage, hours: hours,
                     start: day(offset).addingTimeInterval(-hoursBefore * 3600),
                     source: source, tier: .estimate, provenance: .real)
    }
    /// A timed night: 23:00 → ~06:00, deep first, REM last, one 12-min wake-up.
    private func timedNight(_ offset: Int, bedAt hoursBefore: Double = 1.0) -> [SleepReading] {
        var t = hoursBefore
        func take(_ stage: SleepStage, _ h: Double) -> SleepReading {
            let s = seg(stage, h, night: offset, from: t)
            t -= h
            return s
        }
        return [take(.core, 0.5), take(.deep, 1.5), take(.core, 2.0),
                take(.awake, 0.2), take(.rem, 1.5), take(.core, 1.3)]
    }

    // 1 — a timed night derives a shape.
    @Test func timedNightDerivesAShape() throws {
        var s = HealthSamples()
        s.sleep = timedNight(0)
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        let shape = try #require(d.shape)
        #expect(shape.segments.count == 6)
        #expect(shape.segments.first?.t0 == 0)
        #expect(shape.segments.last?.t1 == 1)
        #expect(shape.startClock == "23:00")
        // Soundings carry the stage TOTALS (deep 90, REM 90, core 228).
        #expect(shape.soundings.first(where: { $0.stage == 3 })?.minutes == 90)
        #expect(shape.soundings.first(where: { $0.stage == 1 })?.minutes == 90)
        // The wake-up is annotated with its real clock time and length.
        let wake = try #require(shape.wake)
        #expect(wake.minutes == 12)
        #expect(wake.t > 0 && wake.t < 1)
        // The AWAKE tile counts only that in-night wake-up.
        #expect(d.awakeMin == 12)
    }

    // 2 — no times ⇒ no shape (the honest reduced anatomy, not a guess).
    @Test func untimedNightHasNoShape() throws {
        var s = HealthSamples()
        s.sleep = [
            SleepReading(date: day(0), stage: .deep, hours: 1.5, source: "Import", tier: .estimate, provenance: .real),
            SleepReading(date: day(0), stage: .core, hours: 4.0, source: "Import", tier: .estimate, provenance: .real),
            SleepReading(date: day(0), stage: .rem, hours: 1.5, source: "Import", tier: .estimate, provenance: .real),
        ]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        #expect(d.shape == nil)
        #expect(d.bedtime == nil)
        #expect(d.awakeMin == 0)
        #expect(SleepDetailView.Model(derived: d).showDemoDepthChart == false)
        // The reduced anatomy still stands.
        #expect(d.asleepMin == 420)
    }

    // 3 — awake time never counts as sleep.
    @Test func awakeNeverInflatesAsleepTotals() throws {
        var s = HealthSamples()
        s.sleep = timedNight(0)
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        // deep 1.5 + rem 1.5 + core 3.8 = 6.8 h — the 12 min awake is excluded.
        #expect(d.asleepMin == 408)
        #expect(d.deepMin == 90)
        #expect(d.remMin == 90)
        #expect(d.coreMin == 228)
        #expect(d.nights.last?.hours == 6.8)
    }

    // 4 — the nightly union uses the real starts. Before the start times
    // landed, every segment of a night shared one instant, so the union of a
    // fragmented night collapsed to its longest fragment.
    @Test func unionUsesRealStartTimesNotTheNightBucket() {
        let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
        let fragments = (0..<8).map { i in
            seg(.core, 0.5, night: 0, from: 8.0 - Double(i) * 0.5)
        }
        #expect(SleepReading.mergedAsleepHours(fragments, asleep: asleep) == 4)
        // Same fragments with no times: they all pile onto one instant and the
        // union can only be the longest — which is why ingestion keeps starts.
        let untimed = fragments.map {
            SleepReading(date: $0.date, stage: $0.stage, hours: $0.hours,
                         source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
        #expect(SleepReading.mergedAsleepHours(untimed, asleep: asleep) == 0.5)
    }

    // 5 — bedtime is the citizen's own usual, and needs three timed nights.
    @Test func bedtimeComparesToTheCitizensOwnUsual() throws {
        var s = HealthSamples()
        // Two nights only ⇒ no "usual" can be claimed.
        s.sleep = timedNight(0, bedAt: 1.0) + timedNight(-1, bedAt: 1.5)
        let two = try #require(SleepDetailDeriver.derive(from: s, now: now))
        #expect(two.bedtime == nil)

        // Five nights: 23:00, 22:30, 23:00, 22:30, 23:00 ⇒ own mean 22:48.
        s.sleep += timedNight(-2, bedAt: 1.0) + timedNight(-3, bedAt: 1.5)
            + timedNight(-4, bedAt: 1.0)
        let five = try #require(SleepDetailDeriver.derive(from: s, now: now))
        let b = try #require(five.bedtime)
        #expect(b.nightCount == 5)
        #expect(b.thisWeekClock == "22:48")
        #expect(b.nightsNearUsual == 5)          // all within 30 min of their own mean
        #expect(b.prevWeekClock == nil)          // nothing in −13…−7
    }

    // 6 — the sentences these surfaces introduce pass the guard.
    @Test func intraNightTemplatesPassNudgeGuard() throws {
        var s = HealthSamples()
        for off in [0, -1, -2, -3] { s.sleep += timedNight(off, bedAt: 1.0) }
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        let m = SleepDetailView.Model(derived: d)
        #expect(NudgeGuard.check(m.sub) == nil)
        #expect(NudgeGuard.check(m.verdict) == nil)
        let shape = try #require(d.shape)
        #expect(NudgeGuard.check(SleepDetailView.depthHeadline(shape)) == nil)
        let b = try #require(d.bedtime)
        #expect(NudgeGuard.check(
            "Within half an hour of your own usual, \(b.nightsNearUsual) of \(b.nightCount) nights.") == nil)
    }

    // The demo provider lays out real nights too, so the demo screen shows the
    // designed anatomy from data rather than from a hard-coded picture.
    @Test func demoProviderLaysOutTimedNights() async throws {
        let end = Date(timeIntervalSince1970: 1_750_000_000)
        let s = try await MockDataProvider().fetchSamples(from: end.addingTimeInterval(-13 * 86_400), to: end)
        #expect(s.sleep.allSatisfy { $0.start != nil })
        #expect(s.sleep.contains { $0.stage == .awake })
        let d = try #require(SleepDetailDeriver.derive(from: s.arbitrated(), now: end))
        #expect(d.shape != nil)
        #expect(d.bedtime != nil)
    }
}
