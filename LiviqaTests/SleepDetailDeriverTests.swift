import Testing
import Foundation
@testable import Liviqa

// A7.2 Area ④ — the Sleep detail screen's on-device derivation. Data-honesty
// invariants: nil without asleep segments; the transparent decomposed score
// refuses to render below 4 nights or without stage detail; last-week
// comparison absent without last-week nights; fixed templates pass FR-NDG-06.
struct SleepDetailDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }
    private func seg(_ stage: SleepStage, _ hours: Double, day offset: Int,
                     source: String = "Watch") -> SleepReading {
        SleepReading(date: day(offset), stage: stage, hours: hours,
                     source: source, tier: .estimate, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(SleepDetailDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func awakeOnlySegmentsDeriveNil() throws {
        var s = HealthSamples()
        s.sleep = [seg(.awake, 0.5, day: 0), seg(.inBed, 8, day: 0)]
        #expect(SleepDetailDeriver.derive(from: s, now: now) == nil)
    }

    @Test func lastNightStageTotalsAndWeek() throws {
        var s = HealthSamples()
        s.sleep = [
            seg(.deep, 1.5, day: 0), seg(.rem, 1.5, day: 0), seg(.core, 4.0, day: 0),
            seg(.deep, 1.0, day: -1), seg(.core, 5.0, day: -1),
        ]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        #expect(d.asleepMin == 420)           // 7h last night
        #expect(d.deepMin == 90)
        #expect(d.remMin == 90)
        #expect(d.coreMin == 240)
        #expect(d.hasStageDetail)
        #expect(d.nights.count == 2)
        #expect(d.nights.last?.isLastNight == true)
        #expect(d.weekMeanMin == (420 + 360) / 2)
        #expect(d.prevWeekMeanMin == nil)     // no nights −13…−7
        #expect(d.source == "Watch")
    }

    @Test func prevWeekMeanWhenLastWeekHasNights() throws {
        var s = HealthSamples()
        s.sleep = [
            seg(.core, 7.0, day: 0),
            seg(.core, 6.0, day: -8), seg(.core, 8.0, day: -10),
        ]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        #expect(d.prevWeekMeanMin == 420)     // mean(6h, 8h)
        #expect(d.hasStageDetail == false)    // undifferentiated total only
    }

    @Test func scoreNeedsStagesAndFourNights() throws {
        var s = HealthSamples()
        // Three nights with stages — too few for a rhythm claim.
        for off in [0, -1, -2] {
            s.sleep += [seg(.deep, 1, day: off), seg(.rem, 1.5, day: off),
                        seg(.core, 4.5, day: off)]
        }
        let d3 = try #require(SleepDetailDeriver.derive(from: s, now: now))
        #expect(SleepDetailDeriver.score(of: d3) == nil)

        s.sleep += [seg(.deep, 1, day: -3), seg(.rem, 1.5, day: -3),
                    seg(.core, 4.5, day: -3)]
        let d4 = try #require(SleepDetailDeriver.derive(from: s, now: now))
        let score = try #require(SleepDetailDeriver.score(of: d4))
        // 7h identical nights: rest = 7/8×50, depth share 2.5/7 vs 0.35 cap,
        // rhythm = perfect (night == own mean).
        #expect(abs(score.rest - 43.75) < 0.01)
        #expect(abs(score.depth - min((2.5 / 7.0) / 0.35, 1) * 30) < 0.01)
        #expect(abs(score.rhythm - 20) < 0.01)
        #expect(score.total == Int((score.rest + score.depth + score.rhythm).rounded()))
    }

    @Test func fixedTemplatesPassNudgeGuard() throws {
        var s = HealthSamples()
        for off in [0, -1, -2, -3, -8] {
            s.sleep += [seg(.deep, 1, day: off), seg(.rem, 1.5, day: off),
                        seg(.core, 4.5, day: off)]
        }
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        let derived = SleepDetailView.Model(derived: d)
        let seed = SleepDetailView.Model.designSeed
        for m in [derived, seed] {
            #expect(NudgeGuard.check(m.verdict) == nil)
            #expect(NudgeGuard.check(m.weekHeadline) == nil)
            if let c = m.compareSentence { #expect(NudgeGuard.check(c) == nil) }
            #expect(NudgeGuard.check(m.sub) == nil)
        }
    }

    /// The søkort depth chart cannot be drawn from real data (no intra-night
    /// times at ingestion) — the derived model must never request it.
    @Test func realModelNeverShowsTheDemoDepthChart() throws {
        var s = HealthSamples()
        s.sleep = [seg(.deep, 1, day: 0), seg(.core, 5, day: 0)]
        let d = try #require(SleepDetailDeriver.derive(from: s, now: now))
        #expect(SleepDetailView.Model(derived: d).showDemoDepthChart == false)
        #expect(SleepDetailView.Model.designSeed.showDemoDepthChart == true)
    }
}
