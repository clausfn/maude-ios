// ContextFlagTests.swift — T-CTX-04 (FR-CTX-04, Bevel absorb ③).
//
// The load-bearing claims, each with its own test:
//   1. a marked day SUPPRESSES baseline-deviation nudges
//   2. a flag can NEVER create a nudge, and never widens the output
//   3. suppression can never silence the D9 safety route (AFib → clinician)
//   4. the day range is inclusive at both ends and open-ended when unfinished
//   5. every user-facing string the flag introduces is FR-NDG-06 clean
//   6. the store round-trips on disk and can be erased
//
// Claim 2 is the FR-NDG-06 interaction rule and is checked structurally
// (output-with-flag ⊆ output-without-flag), not by spot-checking sentences.
import Testing
import Foundation
@testable import Liviqa

struct ContextFlagTests {

    private static let cal = ContextWindow.calendar

    /// Fixed "now" so the fixtures never drift with the wall clock.
    private static let now = Date(timeIntervalSince1970: 1_750_000_000)

    private static func day(_ offset: Int, from base: Date = ContextFlagTests.now) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: base))!
    }

    /// 7 days ending at `now`, with the LAST day deviating on every stream —
    /// low HRV, few steps, a short night and higher glucose. Mirrors
    /// NudgeFixtures.triggering but anchored so `now` is the deviating day.
    private static func deviatingWeek(afib: Bool = false) -> (HealthSamples, ClinicalSignals) {
        var s = HealthSamples.empty
        for i in 0..<7 {
            let d = day(-6 + i)
            let last = (i == 6)
            s.hrv.append(.init(date: d, kind: .hrvSDNN, value: last ? 30 : 55 + Double(i),
                               source: "Test", tier: .good, provenance: .simulated))
            s.restingHR.append(.init(date: d, kind: .restingHR, value: 58,
                                     source: "Test", tier: .good, provenance: .simulated))
            s.steps.append(.init(date: d, kind: .steps, value: last ? 2000 : 8000,
                                 source: "Test", tier: .estimate, provenance: .simulated))
            s.sleep.append(.init(date: d, stage: .asleepUnspecified, hours: last ? 5 : 7.5,
                                 source: "Test", tier: .estimate, provenance: .simulated))
            for h in [7, 12, 18] {
                let ts = cal.date(byAdding: .hour, value: h, to: d)!
                s.glucose.append(.init(ts: ts, mmol: last ? 9.2 : 6.0,
                                       source: "Test", tier: .good, provenance: .simulated))
            }
        }
        return (s, ClinicalSignals(afibSignalPresent: afib))
    }

    private static func travelling(from: Int, to: Int?) -> [ContextWindow] {
        [ContextWindow(kind: .travelling, start: day(from), end: to.map { day($0) })]
    }

    // MARK: - 1. Suppression

    // T-CTX-04a — an unmarked deviating day DOES produce deviation nudges.
    // (The control: without it, "suppressed" could just mean "nothing fired".)
    @Test func deviationsFireWhenTheDayIsNotMarked() {
        let (samples, signals) = Self.deviatingWeek()
        let out = NudgeEngine().generate(samples: samples, signals: signals,
                                         context: [], now: Self.now, cap: 10)
        #expect(out.contains { $0.category == .behaviouralLever })
        #expect(out.contains { $0.category == .bandStatus })
    }

    // T-CTX-04b — marking the day suppresses every baseline-comparison stream.
    @Test func markedDaySuppressesBaselineDeviations() {
        let (samples, signals) = Self.deviatingWeek()
        let out = NudgeEngine().generate(samples: samples, signals: signals,
                                         context: Self.travelling(from: -1, to: nil),
                                         now: Self.now, cap: 10)
        #expect(!out.contains { $0.category == .behaviouralLever })
        #expect(!out.contains { $0.category == .bandStatus })
        // The plain number echo is NOT a baseline claim — it survives, so a
        // marked day still shows the user their own reading.
        #expect(out.contains { $0.category == .number })
    }

    // T-CTX-04c — a flag that ended BEFORE today does not suppress today.
    @Test func endedFlagDoesNotSuppressLaterDays() {
        let (samples, signals) = Self.deviatingWeek()
        let out = NudgeEngine().generate(samples: samples, signals: signals,
                                         context: Self.travelling(from: -5, to: -1),
                                         now: Self.now, cap: 10)
        #expect(out.contains { $0.category == .behaviouralLever })
    }

    // MARK: - 2. The FR-NDG-06 interaction rule — suppression ONLY

    // T-CTX-04d — a flag can never CREATE a nudge: with no samples at all, a
    // flag produces no output whatsoever.
    @Test func flagAloneGeneratesNothing() {
        for kind in ContextFlagKind.allCases {
            let windows = [ContextWindow(kind: kind, start: Self.day(-3), end: nil)]
            let out = NudgeEngine().generate(samples: .empty, context: windows,
                                             now: Self.now, cap: 10)
            #expect(out.isEmpty, "\(kind) fabricated a nudge from an empty store")
        }
    }

    // T-CTX-04e — structural proof: for every kind, the marked-day output is a
    // SUBSET of the unmarked output. Nothing new appears, nothing is rewritten,
    // and no priority is raised.
    @Test func markedOutputIsAlwaysASubsetOfUnmarked() {
        let (samples, signals) = Self.deviatingWeek(afib: true)
        let base = NudgeEngine().generate(samples: samples, signals: signals,
                                          context: [], now: Self.now, cap: 10)
        let baseKeys = Set(base.map { "\($0.category.rawValue)|\($0.title)|\($0.body)|\($0.priority)" })

        for kind in ContextFlagKind.allCases {
            let windows = [ContextWindow(kind: kind, start: Self.day(-2), end: nil)]
            let marked = NudgeEngine().generate(samples: samples, signals: signals,
                                                context: windows, now: Self.now, cap: 10)
            #expect(marked.count <= base.count)
            for n in marked {
                let key = "\(n.category.rawValue)|\(n.title)|\(n.body)|\(n.priority)"
                #expect(baseKeys.contains(key),
                        "\(kind) produced a nudge that does not exist unmarked: \(n.title)")
            }
        }
    }

    // MARK: - 3. Safety is never suppressed

    // T-CTX-04f — D9: the AFib route-to-clinician survives any flag. A
    // self-declared travel note must never silence a safety route.
    @Test func clinicianRouteSurvivesSuppression() {
        let (samples, signals) = Self.deviatingWeek(afib: true)
        let out = NudgeEngine().generate(samples: samples, signals: signals,
                                         context: Self.travelling(from: -1, to: nil),
                                         now: Self.now, cap: 10)
        let route = out.first { $0.category == .routeToClinician }
        #expect(route != nil)
        #expect(route?.lane == .displayOnly)
    }

    // MARK: - 4. Window arithmetic

    // T-CTX-04g — both ends inclusive; open-ended runs forward forever.
    @Test func windowCoversInclusiveRange() {
        let closed = ContextWindow(kind: .unwell, start: Self.day(-3), end: Self.day(-1))
        #expect(!closed.covers(Self.day(-4)))
        #expect(closed.covers(Self.day(-3)))          // first day inclusive
        #expect(closed.covers(Self.day(-2)))
        #expect(closed.covers(Self.day(-1)))          // last day inclusive
        #expect(!closed.covers(Self.day(0)))

        let open = ContextWindow(kind: .offRoutine, start: Self.day(-1), end: nil)
        #expect(!open.covers(Self.day(-2)))
        #expect(open.covers(Self.day(-1)))
        #expect(open.covers(Self.day(0)))
        #expect(open.covers(Self.day(30)))
    }

    // T-CTX-04h — any instant within a marked day counts, not just midnight.
    @Test func coverageIsDayGranular() {
        let w = ContextWindow(kind: .travelling, start: Self.day(0), end: Self.day(0))
        let evening = Self.cal.date(byAdding: .hour, value: 23, to: Self.day(0))!
        #expect(w.covers(evening))
    }

    // T-CTX-04i — markedCount counts only days actually passed in; it never
    // invents a day that isn't in the window.
    @Test func markedCountCountsOnlyRealDays() {
        let windows = Self.travelling(from: -2, to: -1)
        let week = (0..<7).map { Self.day(-$0) }
        #expect(ContextFlagDeriver.markedCount(among: week, in: windows) == 2)
        #expect(ContextFlagDeriver.markedCount(among: [], in: windows) == 0)
        #expect(ContextFlagDeriver.markedCount(among: week, in: []) == 0)
    }

    // T-CTX-04j — overlapping stretches resolve to the most recently started
    // one (the user's latest word about their own life).
    @Test func latestStartWinsWhenStretchesOverlap() {
        let windows = [
            ContextWindow(kind: .travelling, start: Self.day(-5), end: nil),
            ContextWindow(kind: .unwell,     start: Self.day(-2), end: nil),
        ]
        #expect(ContextFlagDeriver.window(covering: Self.day(0), in: windows)?.kind == .unwell)
        #expect(ContextFlagDeriver.window(covering: Self.day(-4), in: windows)?.kind == .travelling)
    }

    // MARK: - 5. FR-NDG-06 clean copy (DESIGNATED CONTROL — never skipped)

    // T-CTX-04k — every string the context flag introduces passes NudgeGuard.
    // These are fixed templates, so the check is exhaustive over the enum.
    @Test func everyContextStringIsGuardClean() {
        for kind in ContextFlagKind.allCases {
            for text in [kind.label, kind.explainer, kind.todayHeadline,
                         kind.todayDetail, kind.quietNote] {
                #expect(NudgeGuard.check(text) == nil,
                        "\(kind) copy tripped the FR-NDG-06 guard: \(text)")
            }
        }
    }

    // MARK: - 6. Persistence (on-device only, erasable)

    // T-CTX-04l — round-trip through the file-protected store, then delete.
    @Test func storeRoundTripsAndErases() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ctxflags-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(ContextFlagStore.load(from: url) == nil)   // nothing marked yet

        let flags = [
            ContextFlag(kind: .travelling, startedOn: Self.day(-4), endedOn: Self.day(-1),
                        note: "Conference"),
            ContextFlag(kind: .unwell, startedOn: Self.day(0)),
        ]
        ContextFlagStore.save(flags, to: url)

        let loaded = try #require(ContextFlagStore.load(from: url))
        #expect(loaded == flags)
        #expect(loaded[1].isOpen)
        #expect(loaded[0].note == "Conference")

        ContextFlagStore.delete(at: url)
        #expect(ContextFlagStore.load(from: url) == nil)
    }

    // T-CTX-04m — the engine-facing projection carries kind + dates and nothing
    // else: the user's note has no representation in the Intelligence layer.
    @Test func windowProjectionDropsTheNote() {
        let flag = ContextFlag(kind: .offRoutine, startedOn: Self.day(-1),
                               note: "moved house, sleeping on a sofa")
        let w = flag.window
        #expect(w.kind == .offRoutine)
        #expect(w.start == Self.day(-1))
        #expect(w.end == nil)
        // Structural, not incidental: ContextWindow's whole value is (kind,
        // start, end) — two windows built from different notes are equal.
        let other = ContextFlag(kind: .offRoutine, startedOn: Self.day(-1), note: "something else")
        #expect(other.window == w)
    }
}
