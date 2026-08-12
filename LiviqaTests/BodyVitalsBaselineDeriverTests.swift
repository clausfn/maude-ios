import Testing
import Foundation
@testable import Liviqa

// A7.2 Area ④ — Body, Vitals (FR-VIT-01) and per-domain baseline derivations.
// Invariants: corridors/bands are the user's own mean ±1σ and refuse to render
// below 5 readings (never a clinical reference range); milestones are derived
// window extremes, never invented; verdict words come from the fixed
// vocabulary; all templates pass FR-NDG-06.
struct BodyTrendDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }
    private func comp(_ w: Double?, fat: Double? = nil, lean: Double? = nil,
                      bmi: Double? = nil, day offset: Int) -> BodyCompositionReading {
        BodyCompositionReading(ts: day(offset), weightKg: w, fatPct: fat,
                               leanKg: lean, bmi: bmi, source: "InBody",
                               tier: .good, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(BodyTrendDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func weightTrendCorridorDeltaAndDerivedLow() throws {
        var s = HealthSamples()
        let weights = [71.8, 71.6, 71.4, 71.2, 70.9, 70.4]
        for (i, w) in weights.enumerated() {
            s.bodyComposition.append(comp(w, fat: 25.0 - Double(i) * 0.2,
                                          lean: 53.4, bmi: 23.0,
                                          day: i - weights.count + 1))
        }
        let d = try #require(BodyTrendDeriver.derive(from: s, now: now))
        #expect(d.weightSeries.count == 6)
        #expect(d.weightCorridor != nil)          // ≥5 readings
        #expect(d.latestWeightKg == 70.4)
        #expect(d.weightDeltaKg == -1.4)
        #expect(d.latestIsWindowLow)              // derived milestone, not invented
        #expect(d.latestIsWindowHigh == false)
        #expect(d.fatSeries.count == 6)
        #expect(d.latestLeanKg == 53.4)
        #expect(abs((d.leanDeltaKg ?? 99)) < 0.01)
        #expect(d.source == "InBody")
        #expect(!d.sinceMonthName.isEmpty)
    }

    @Test func fewReadingsMeanNoCorridorNoMilestone() throws {
        var s = HealthSamples()
        s.bodyComposition = [comp(71.0, day: -3), comp(70.5, day: 0)]
        let d = try #require(BodyTrendDeriver.derive(from: s, now: now))
        #expect(d.weightCorridor == nil)          // <5 readings ⇒ no own-band claim
        #expect(d.latestIsWindowLow == false)     // <5 readings ⇒ no milestone
    }

    @Test func fixedTemplatesPassNudgeGuard() throws {
        var s = HealthSamples()
        for (i, w) in [71.8, 71.6, 71.4, 71.2, 70.9, 70.4].enumerated() {
            s.bodyComposition.append(comp(w, fat: 24.5, lean: 53.0, day: i - 5))
        }
        let d = try #require(BodyTrendDeriver.derive(from: s, now: now))
        let derived = BodyDetailView.Model(derived: d)
        let seed = BodyDetailView.Model.designSeed
        for m in [derived, seed] {
            #expect(NudgeGuard.check(m.verdict) == nil)
            #expect(NudgeGuard.check(m.weightHeadline) == nil)
            #expect(NudgeGuard.check(m.fatHeadline) == nil)
            if let f = m.fatFoot { #expect(NudgeGuard.check(f) == nil) }
        }
    }
}

struct VitalsDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    }
    private func metric(_ kind: DailyMetricKind, _ v: Double, day offset: Int) -> DailyMetric {
        DailyMetric(date: cal.date(byAdding: .day, value: offset,
                                   to: cal.startOfDay(for: now))!,
                    kind: kind, value: v, source: "Watch", tier: .good, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(VitalsDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func bandNeedsHistoryAndStripNeedsRecentReadings() throws {
        var s = HealthSamples()
        // Only 4 SpO₂ days — below the own-band minimum.
        for off in 0..<4 { s.heartExtras.append(metric(.spo2, 97, day: -off)) }
        #expect(VitalsDeriver.derive(from: s, now: now) == nil)

        // 6 days with spread ⇒ band exists, strip renders, verdict is personal.
        s.heartExtras.append(metric(.spo2, 96, day: -4))
        s.heartExtras.append(metric(.spo2, 98, day: -5))
        let d = try #require(VitalsDeriver.derive(from: s, now: now))
        let spo2 = try #require(d.vitals.first)
        #expect(spo2.name == "Oxygen saturation")
        #expect(spo2.series.count == 6)
        #expect(spo2.band.contains(97))
        #expect(spo2.latestIsTypical)
        #expect(d.allTypical)
    }

    @Test func respiratoryRateRidesAlong() throws {
        var s = HealthSamples()
        for off in 0..<6 {
            s.heartExtras.append(metric(.spo2, 96 + Double(off % 3), day: -off))
            s.heartExtras.append(metric(.respiratoryRate, 14 + Double(off % 2) * 0.4, day: -off))
        }
        let d = try #require(VitalsDeriver.derive(from: s, now: now))
        #expect(d.vitals.count == 2)
        #expect(d.vitals.last?.unit == "breaths/min")
    }

    @Test func verdictWordsAreAllowListedAndGuardClean() throws {
        var s = HealthSamples()
        for off in 0..<6 { s.heartExtras.append(metric(.spo2, 96 + Double(off % 3), day: -off)) }
        let d = try #require(VitalsDeriver.derive(from: s, now: now))
        let derived = VitalsDetailView.Model(derived: d)
        let seed = VitalsDetailView.Model.designSeed
        let allowed: Set<String> = ["Typical", "Worth a look"]
        for m in [derived, seed] {
            #expect(NudgeGuard.check(m.verdict) == nil)
            for row in m.vitals {
                #expect(allowed.contains(row.verdictWord))
                #expect(NudgeGuard.check(row.headline) == nil)
            }
        }
    }
}

struct BaselineDeriverTests {

    private let cal = Calendar(identifier: .gregorian)

    private var now: Date {
        cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }
    private func hrv(_ v: Double, day offset: Int) -> DailyMetric {
        DailyMetric(date: day(offset), kind: .hrvSDNN, value: v,
                    source: "Watch", tier: .good, provenance: .real)
    }

    @Test func emptySamplesDeriveNil() throws {
        #expect(BaselineDeriver.derive(from: .empty, now: now) == nil)
    }

    @Test func hrvBaselineNeedsFiveDays() throws {
        var s = HealthSamples()
        for off in 0..<4 { s.hrv.append(hrv(42 + Double(off), day: -off)) }
        #expect(BaselineDeriver.derive(from: s, now: now) == nil)

        s.hrv.append(hrv(40, day: -4))
        let book = try #require(BaselineDeriver.derive(from: s, now: now))
        let b = try #require(book.entry(.hrv))
        #expect(b.unit == "ms")
        #expect(b.learnedFromDays == 5)
        #expect(b.band.lowerBound < b.band.upperBound)
        #expect(b.series.count == 5)
        #expect(book.entry(.sleep) == nil)     // no sleep data ⇒ no sleep baseline
    }

    @Test func sleepBaselineFromNightlyUnions() throws {
        var s = HealthSamples()
        for off in 0..<6 {
            s.sleep.append(SleepReading(date: day(-off), stage: .core,
                                        hours: 6.5 + Double(off % 3) * 0.5,
                                        source: "Watch", tier: .estimate, provenance: .real))
        }
        let book = try #require(BaselineDeriver.derive(from: s, now: now))
        let b = try #require(book.entry(.sleep))
        #expect(b.unit == "h")
        #expect(b.learnedFromDays == 6)
        #expect(b.latest > 5 && b.latest < 9)
    }
}
