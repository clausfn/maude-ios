import Testing
import Foundation
@testable import Liviqa

// A7.2 Area ④ — Fitness (FR-FIT-01) + Activity derivations. Invariants: load
// arithmetic is the published formula (duration × intensity, own-data only);
// avg-HR/zones exist ONLY when HR samples are provided (ingestion gap T-FIT-01
// stays honest); the activity "usual" is the user's own prior weeks, and the
// %-vs-usual claim refuses to render without real history.
struct FitnessDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    }
    private func at(day: Int, hour: Int = 17) -> Date {
        let d = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: now))!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d)!
    }
    private func ride(day: Int, durMin: Double = 60, kcal: Double? = 480,
                      km: Double? = 20) -> WorkoutReading {
        WorkoutReading(start: at(day: day), end: at(day: day).addingTimeInterval(durMin * 60),
                       type: "Cycling", durMin: durMin, kcal: kcal, distKm: km,
                       source: "Watch", tier: .estimate, provenance: .real)
    }
    private func vo2(_ v: Double, day: Int) -> DailyMetric {
        DailyMetric(date: at(day: day), kind: .vo2max, value: v,
                    source: "Watch", tier: .good, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(FitnessDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func loadArithmeticWithoutHR() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0, durMin: 60, kcal: 480)]   // 480/60/8 = 1.0 ⇒ 60 pts
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(d.weekLoadPoints == 60)
        #expect(d.weekCount == 1)
        #expect(d.weekAvgHR == nil)          // no HR samples ⇒ honest absence
        #expect(d.zones.isEmpty)
        #expect(d.dominantType == "Cycling")
        #expect(d.workouts.first?.load == 60)
        #expect(d.workouts.first?.meta.contains("bpm") == false)
    }

    @Test func fourWeekBucketsAndOwnUsual() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0), ride(day: -8), ride(day: -15), ride(day: -22)]
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(d.loadWeeks.count == 4)
        #expect(d.loadWeeks.last?.label == "now")
        let usual = try #require(d.loadUsual)      // mean of the 3 prior weeks
        #expect(abs(usual - 60) < 0.5)
    }

    @Test func hrSamplesUnlockAvgHRAndZones() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0, durMin: 60)]
        // 60 minutes of samples at 1/min: 30 min @ 120 bpm, 30 min @ 150 bpm;
        // own observed max = 160 (a separate spike sample inside the workout).
        var hr: [FitnessDeriver.HRSample] = []
        for m in 0..<30 { hr.append(.init(ts: at(day: 0).addingTimeInterval(Double(m) * 60), bpm: 120)) }
        for m in 30..<59 { hr.append(.init(ts: at(day: 0).addingTimeInterval(Double(m) * 60), bpm: 150)) }
        hr.append(.init(ts: at(day: 0).addingTimeInterval(59 * 60), bpm: 160))
        let d = try #require(FitnessDeriver.derive(from: s, hrSamples: hr, now: now))
        #expect(d.weekAvgHR != nil)
        #expect(!d.zones.isEmpty)
        #expect(d.zoneWorkoutTitle?.contains("heart-rate zones") == true)
        // Zone minutes must not exceed the workout duration.
        #expect(d.zones.map(\.minutes).reduce(0, +) <= 61)
        // 120/160 = 0.75 ⇒ Z2; 150/160 ≈ 0.94 ⇒ Z4 — both present.
        #expect(d.zones.contains { $0.name.hasPrefix("Z2") })
        #expect(d.zones.contains { $0.name.hasPrefix("Z4") })
    }

    @Test func vo2TrendAndDerivedHigh() throws {
        var s = HealthSamples()
        for (i, v) in [33.8, 34.0, 34.3, 34.6, 34.9, 35.2].enumerated() {
            s.heartExtras.append(vo2(v, day: i - 5))
        }
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        #expect(d.vo2Series.count == 6)
        #expect(d.vo2Latest == 35.2)
        #expect(d.vo2IsNewHigh)              // latest IS the window max, ≥5 readings
        #expect(d.vo2Band != nil)
        #expect(!d.vo2XLabels.isEmpty)
    }

    @Test func fixedTemplatesPassNudgeGuard() throws {
        var s = HealthSamples()
        s.workouts = [ride(day: 0), ride(day: -2), ride(day: -8), ride(day: -15)]
        for (i, v) in [33.8, 34.0, 34.3, 34.6, 34.9, 35.2].enumerated() {
            s.heartExtras.append(vo2(v, day: i - 5))
        }
        let d = try #require(FitnessDeriver.derive(from: s, now: now))
        let derived = FitnessDetailView.Model(derived: d)
        let seed = FitnessDetailView.Model.designSeed
        for m in [derived, seed] {
            #expect(NudgeGuard.check(m.verdict) == nil)
            #expect(NudgeGuard.check(m.loadHeadline) == nil)
            #expect(NudgeGuard.check(m.workoutsHeadline) == nil)
            #expect(NudgeGuard.check(m.vo2Headline) == nil)
        }
        // The designated no-target line stays guard-clean.
        #expect(NudgeGuard.check("Load points add up how long and how hard you moved. Only your own week-to-week change matters — there is no target.") == nil)
    }
}

struct ActivityDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }
    private func steps(_ v: Double, day offset: Int) -> DailyMetric {
        DailyMetric(date: day(offset), kind: .steps, value: v,
                    source: "iPhone", tier: .estimate, provenance: .real)
    }
    private func kcal(_ v: Double, day offset: Int) -> DailyMetric {
        DailyMetric(date: day(offset), kind: .activeEnergy, value: v,
                    source: "Watch", tier: .estimate, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(ActivityDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func weekSeriesWithoutHistoryHasNoVsUsualClaim() throws {
        var s = HealthSamples()
        s.steps = [steps(8000, day: 0), steps(9000, day: -1), steps(7000, day: -2)]
        let d = try #require(ActivityDeriver.derive(from: s, now: now))
        #expect(d.stepsWeek.count == 3)
        #expect(d.usualFromHistory == false)
        #expect(d.pctVsUsual == nil)          // a week can't be compared to itself
        #expect(d.usualSteps == 8000)         // falls back to the week's own mean
        #expect(d.weekStepsTotal == 24000)
    }

    @Test func priorWeeksBuildTheOwnUsual() throws {
        var s = HealthSamples()
        // This week: mean 8800 over 2 days. Prior weeks: 5 days @ 8000.
        s.steps = [steps(8600, day: 0), steps(9000, day: -1)]
        for off in [-8, -10, -14, -18, -21] { s.steps.append(steps(8000, day: off)) }
        s.activeEnergy = [kcal(500, day: 0), kcal(450, day: -1)]
        let d = try #require(ActivityDeriver.derive(from: s, now: now))
        #expect(d.usualFromHistory)
        #expect(d.usualSteps == 8000)
        #expect(d.pctVsUsual == 10)           // (8800−8000)/8000
        #expect(d.daysAboveUsual == 2)
        #expect(d.longestDaySteps == 9000)
        #expect(d.kcalWeek.count == 2)
    }

    @Test func fixedTemplatesPassNudgeGuard() throws {
        var s = HealthSamples()
        s.steps = [steps(8600, day: 0), steps(9000, day: -1)]
        for off in [-8, -10, -14, -18, -21] { s.steps.append(steps(8000, day: off)) }
        let d = try #require(ActivityDeriver.derive(from: s, now: now))
        let derived = ActivityDetailView.Model(derived: d)
        let seed = ActivityDetailView.Model.designSeed
        for m in [derived, seed] {
            #expect(NudgeGuard.check(m.verdict) == nil)
            #expect(NudgeGuard.check(m.stepsHeadline) == nil)
            #expect(NudgeGuard.check(m.kcalHeadline) == nil)
            #expect(NudgeGuard.check(m.sub) == nil)
        }
    }
}
