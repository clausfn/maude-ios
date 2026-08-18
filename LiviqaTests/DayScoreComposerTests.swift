// DayScoreComposerTests.swift — T-DSC-01: the adaptive evening day score
// (CN directive 2026-08-19 — the score composes from the domains the person
// ACTUALLY tracks; movement joins now that steps are ingested).
//
// Pinned here:
//  · COMPOSITION: a CGM user scores the designed trio sleep+glucose+movement
//    (/100); a gym user without a CGM scores sleep+movement+recovery (/90);
//    a CGM user without steps keeps the shipped sleep+glucose+recovery shape.
//  · FIXED WEIGHTS: 50/30/20/20 per domain, never re-weighted by absence —
//    the denominator shrinks instead and the disclosure says so.
//  · HONESTY: <2 domains ⇒ no score; a domain with data that the 3-part cap
//    outranks is NAMED in the disclosure, never silently dropped; movement and
//    recovery refuse to derive without ≥4 days of own history or with a
//    non-positive own mean.
//  · NO DRIFT: the sleep/glucose/recovery arithmetic equals the shipped
//    SeeWhyExplainer.dayScoreLegs to the point.
//  · FR-NDG-06 (DESIGNATED CONTROL): every sentence any composition can put on
//    screen — part lines, verdicts, every "See why" row, surface, footer —
//    passes NudgeGuard.
import Testing
import Foundation
@testable import Liviqa

struct DayScoreComposerTests {

    // Real-shaped week series (days WITH data, oldest → latest).
    private let steps4: [Double] = [7000, 7400, 7800, 8200]   // prior mean 7400
    private let stepsLow: [Double] = [7000, 7400, 7800, 3700] // latest under own mean
    private let hrv4: [Double] = [40, 44, 48, 52]             // prior mean 44

    // MARK: - Composition per persona

    @Test func cgmUserWithEverythingScoresTheDesignedTrioOutOf100() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 8, tirPct: 80, stepsWeek: steps4, hrvWeek: hrv4))
        #expect(s.parts.map(\.domain) == [.sleep, .glucose, .movement])
        #expect(s.outOf == 100)
        // Recovery had data too — it is dropped by the cap, and NAMED.
        #expect(s.dropped == [.recovery])
        let why = DayScoreComposer.seeWhy(s, fromRealSignals: true)
        #expect(why.rows.contains { $0.value.lowercased().contains("recovery") &&
                                    $0.value.contains("not folded in") })
    }

    @Test func gymUserWithoutCGMScoresSleepMovementRecoveryOutOf90() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 7, tirPct: nil, stepsWeek: steps4, hrvWeek: hrv4))
        #expect(s.parts.map(\.domain) == [.sleep, .movement, .recovery])
        #expect(s.outOf == 90)
        #expect(s.dropped.isEmpty)
        // The shrunken denominator is said out loud, not hidden.
        let why = DayScoreComposer.seeWhy(s, fromRealSignals: true)
        #expect(why.rows.contains { $0.value.contains("out of 90 rather than 100") })
    }

    @Test func cgmUserWithoutStepsKeepsTheShippedShape() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 7, tirPct: 80, stepsWeek: [], hrvWeek: hrv4))
        #expect(s.parts.map(\.domain) == [.sleep, .glucose, .recovery])
        #expect(s.outOf == 100)
        #expect(s.dropped.isEmpty)
    }

    @Test func noSleepStillComposesFromTheRest() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: nil, tirPct: 80, stepsWeek: steps4, hrvWeek: hrv4))
        #expect(s.parts.map(\.domain) == [.glucose, .movement, .recovery])
        #expect(s.outOf == 70)
    }

    // MARK: - Honesty gates

    @Test func oneDomainAloneIsNotADay() {
        #expect(DayScoreComposer.compose(sleepHours: 7, tirPct: nil,
                                         stepsWeek: [], hrvWeek: []) == nil)
        #expect(DayScoreComposer.compose(sleepHours: nil, tirPct: nil,
                                         stepsWeek: steps4, hrvWeek: []) == nil)
        #expect(DayScoreComposer.compose(sleepHours: nil, tirPct: nil,
                                         stepsWeek: [], hrvWeek: []) == nil)
    }

    @Test func movementNeedsFourDaysOfOwnHistory() {
        // 3 step days: no own mean yet → no movement part, score composes without it.
        let s = DayScoreComposer.compose(sleepHours: 7, tirPct: 80,
                                         stepsWeek: [7000, 7400, 8200], hrvWeek: [])
        #expect(s?.parts.map(\.domain) == [.sleep, .glucose])
        #expect(s?.outOf == 80)
    }

    @Test func aZeroOwnMeanRefusesThePartInsteadOfDividing() {
        let s = DayScoreComposer.compose(sleepHours: 7, tirPct: 80,
                                         stepsWeek: [0, 0, 0, 500], hrvWeek: [])
        #expect(s?.parts.map(\.domain) == [.sleep, .glucose])
    }

    // MARK: - Arithmetic (visible, capped, no drift from the shipped legs)

    @Test func movementArithmeticIsLatestOverOwnPriorMeanCappedTimes20() throws {
        // Above own usual: capped at the fixed weight.
        let capped = try #require(DayScoreComposer.compose(
            sleepHours: nil, tirPct: 80, stepsWeek: [7000, 7400, 7800, 22000], hrvWeek: []))
        let cappedMove = try #require(capped.parts.first { $0.domain == .movement })
        #expect(cappedMove.points == 20)
        #expect(cappedMove.max == 20)

        // Under own usual: the plain ratio. 3700 / 7400 × 20 = 10.
        let under = try #require(DayScoreComposer.compose(
            sleepHours: nil, tirPct: 80, stepsWeek: stepsLow, hrvWeek: []))
        let underMove = try #require(under.parts.first { $0.domain == .movement })
        #expect(abs(underMove.points - 10) < 0.001)
        // The printed line carries both of the person's own numbers.
        #expect(underMove.line.contains("3,700") && underMove.line.contains("7,400"))
    }

    @Test func sleepGlucoseRecoveryPointsMatchTheShippedLegsExactly() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 6.9, tirPct: 78, stepsWeek: [], hrvWeek: hrv4))
        let legacy = SeeWhyExplainer.dayScoreLegs(
            sleepHours: 6.9, tirPct: 78,
            hrvLatest: hrv4.last, hrvPriorMean: hrv4.dropLast().reduce(0, +) / 3)
        for part in s.parts {
            let match = try #require(legacy.first { $0.kind.rawValue == part.domain.rawValue })
            #expect(abs(part.points - match.points) < 0.0001)
            #expect(part.max == match.max)
        }
    }

    // MARK: - Verdict: allow-listed, thresholded on the RATIO (never a /100 bar)

    @Test func verdictsUseTheRatioNotAFixed100Bar() throws {
        // 43.75 + 20 + 20 of 90 → 0.93 → a good day.
        let good = try #require(DayScoreComposer.compose(
            sleepHours: 7, tirPct: nil, stepsWeek: steps4, hrvWeek: hrv4))
        #expect(good.verdict.hasPrefix("A good day"))

        // 30 + 21 of 80 → 0.6375 → steady (out of 80, a fixed-100 bar would call it lighter).
        let steady = try #require(DayScoreComposer.compose(
            sleepHours: 4.8, tirPct: 70, stepsWeek: [], hrvWeek: []))
        #expect(steady.verdict == String(localized: "A steady day."))

        // 25 + 15 of 80 → 0.5 → lighter.
        let lighter = try #require(DayScoreComposer.compose(
            sleepHours: 4, tirPct: 50, stepsWeek: [], hrvWeek: []))
        #expect(lighter.verdict == String(localized: "A lighter day — they happen."))
    }

    @Test func aGoodDayNamesItsStrongestPart() throws {
        // Movement is the only full part (sleep 6/8 = .75, TIR 76% = .76, steps capped 1.0).
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 6, tirPct: 76, stepsWeek: [7000, 7400, 7800, 22000], hrvWeek: []))
        #expect(s.verdict == String(localized: "A good day — mostly thanks to movement."))
    }

    // MARK: - "See why" (FR-XPL-01): shared references NAMED, sample branch honest

    @Test func theSharedReferenceRowNamesWhatTheCompositionActuallyLeansOn() throws {
        let withSleep = try #require(DayScoreComposer.compose(
            sleepHours: 7, tirPct: 80, stepsWeek: steps4, hrvWeek: []))
        #expect(DayScoreComposer.referenceLine(for: withSleep).contains("8-hour"))

        let glucoseNoSleep = try #require(DayScoreComposer.compose(
            sleepHours: nil, tirPct: 80, stepsWeek: steps4, hrvWeek: hrv4))
        #expect(DayScoreComposer.referenceLine(for: glucoseNoSleep).contains("target band"))

        let onlyOwn = try #require(DayScoreComposer.compose(
            sleepHours: nil, tirPct: nil, stepsWeek: steps4, hrvWeek: hrv4))
        #expect(DayScoreComposer.referenceLine(for: onlyOwn).contains("your own week"))
    }

    @Test func sampleFiguresGetTheHonestAbsenceCopyAndNoRows() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 7, tirPct: 80, stepsWeek: steps4, hrvWeek: hrv4))
        let why = DayScoreComposer.seeWhy(s, fromRealSignals: false)
        #expect(why.rows.isEmpty)
        #expect(why.unexplained != nil)
    }

    @Test func theDisclosurePrintsTheRingsExactArithmetic() throws {
        let s = try #require(DayScoreComposer.compose(
            sleepHours: 7, tirPct: nil, stepsWeek: steps4, hrvWeek: hrv4))
        let why = DayScoreComposer.seeWhy(s, fromRealSignals: true)
        // One row per part, carrying that part's own printed line and fraction.
        for part in s.parts {
            #expect(why.rows.contains {
                $0.label == part.name && $0.value.contains(part.line)
                    && $0.value.contains("/\(Int(part.max))")
            })
        }
        // The total row adds up to the same figures the ring shows.
        #expect(why.rows.contains { $0.value.contains("\(s.total) out of \(s.outOf)") })
    }

    // MARK: - FR-NDG-06 (designated control) — every printable sentence

    /// Every composition shape this feature can produce.
    private func allScores() -> [DayScoreComposer.Score] {
        [
            DayScoreComposer.compose(sleepHours: 8, tirPct: 80, stepsWeek: steps4, hrvWeek: hrv4),
            DayScoreComposer.compose(sleepHours: 7, tirPct: nil, stepsWeek: steps4, hrvWeek: hrv4),
            DayScoreComposer.compose(sleepHours: 7, tirPct: 80, stepsWeek: [], hrvWeek: hrv4),
            DayScoreComposer.compose(sleepHours: nil, tirPct: 80, stepsWeek: steps4, hrvWeek: hrv4),
            DayScoreComposer.compose(sleepHours: nil, tirPct: nil, stepsWeek: steps4, hrvWeek: hrv4),
            DayScoreComposer.compose(sleepHours: 4.8, tirPct: 70, stepsWeek: [], hrvWeek: []),
            DayScoreComposer.compose(sleepHours: 4, tirPct: 50, stepsWeek: stepsLow, hrvWeek: []),
        ].compactMap { $0 }
    }

    @Test func everySentenceEveryCompositionCanPrintPassesTheGuard() {
        for score in allScores() {
            #expect(NudgeGuard.check(score.verdict) == nil, "verdict: \(score.verdict)")
            for part in score.parts {
                #expect(NudgeGuard.check(part.line) == nil, "line: \(part.line)")
                #expect(NudgeGuard.check(part.name) == nil)
            }
            for real in [true, false] {
                let why = DayScoreComposer.seeWhy(score, fromRealSignals: real)
                #expect(NudgeGuard.check(why.surface) == nil)
                #expect(NudgeGuard.check(why.verdict) == nil)
                #expect(NudgeGuard.check(why.footer) == nil)
                for row in why.rows {
                    #expect(NudgeGuard.check(row.label) == nil, "label: \(row.label)")
                    #expect(NudgeGuard.check(row.value) == nil, "row: \(row.value)")
                }
                if let u = why.unexplained {
                    #expect(NudgeGuard.check(u) == nil)
                }
            }
        }
    }
}
