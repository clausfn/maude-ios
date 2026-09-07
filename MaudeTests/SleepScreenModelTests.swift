import Testing
import Foundation
@testable import Maude

// Sleep visualisation wave 2026-08 — the SCREEN model's guarantees, after the
// same-screen contradiction CN photographed (tiles "Core 7h21m" while chart
// labels said "16h20m").
//
// The claims under test:
//   1. AGREEMENT WALK: every number in every string the screen can render
//      traces back to the one night model's canonical figures — an
//      independently recomputed set, so a second arithmetic path would fail
//      the walk, not just look odd.
//   2. Tiles, hero, chart labels and a11y all print the SAME formatted string
//      for the same figure (structural: they are one stored property).
//   3. TIME IN BED never counts toward TIME ASLEEP; it reads "—" with a why
//      when the source recorded none — never estimated.
//   4. A score leg missing for lack of nights reads "—", never a false zero;
//      a genuine Rhythm 0 is explained as a measurement.
//   5. Hypnogram hour marks come from the night's own clocks.
//   6. The hypnogram's draw-time merge never alters spans, never bridges a
//      real unrecorded gap, and discloses itself; blocks respect the 2pt floor.
//   7. Week clock columns sit at their own hour; gap nights stay gaps.
//   8. Every sentence any model variant can render is FR-NDG-06 clean.
//   9. The design seed goes through the REAL deriver (demo cannot
//      self-contradict) and never leaks a fixture source name into prose.
//  10. SOURCE LINT: view code formats no figures — all formatting lives in
//      the model, above the render layer's reach.
struct SleepScreenModelTests {

    private let cal = Calendar(identifier: .gregorian)
    private var now: Date { cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())! }
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
    }
    /// A TIMED segment on night bucket `offset`, from `startH` to `endH` hours
    /// relative to that bucket's midnight (−1.0 ⇒ 23:00 the evening before).
    private func seg(_ stage: SleepStage, from startH: Double, to endH: Double,
                     night offset: Int = 0, source: String = "Apple Watch") -> SleepReading {
        let b = day(offset)
        return SleepReading(date: b, stage: stage, hours: endH - startH,
                            start: b.addingTimeInterval(startH * 3600),
                            source: source, tier: .estimate, provenance: .real)
    }
    /// Reference night 23:00 → 06:30: core 2.0h · deep 1.2h · awake 0.2h ·
    /// core 2.5h · REM 1.6h ⇒ asleep 438 min, awake 12 min.
    private func watchNight(_ off: Int = 0) -> [SleepReading] {
        [seg(.core, from: -1.0, to: 1.0, night: off),
         seg(.deep, from: 1.0, to: 2.2, night: off),
         seg(.awake, from: 2.2, to: 2.4, night: off),
         seg(.core, from: 2.4, to: 4.9, night: off),
         seg(.rem, from: 4.9, to: 6.5, night: off)]
    }
    private func derive(_ s: HealthSamples) throws -> SleepWeekDetail {
        try #require(SleepDetailDeriver.derive(from: s, now: now))
    }
    private func fixture(nights offs: [Int]) throws -> SleepWeekDetail {
        var s = HealthSamples()
        for o in offs { s.sleep += watchNight(o) }
        return try derive(s)
    }
    private func fmtMin(_ m: Int) -> String {
        "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }

    // MARK: token extraction + the independently recomputed canonical set

    /// Every numeric token in a rendered string ("7h 05m" → ["7","05"];
    /// "14.2" → ["14.2"]; "23:04" → ["23","04"]).
    private func numericTokens(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        var hasDot = false
        func flush() {
            if current.hasSuffix(".") { current.removeLast() }
            if !current.isEmpty { out.append(current) }
            current = ""; hasDot = false
        }
        for ch in text {
            if ch.isNumber { current.append(ch) }
            else if ch == ".", !current.isEmpty, !hasDot { current.append(ch); hasDot = true }
            else { flush() }
        }
        flush()
        return out
    }

    /// The canonical token set, recomputed from the DERIVED detail itself —
    /// not from the screen model — so the walk cross-checks two paths.
    private func canonicalTokens(for d: SleepWeekDetail) -> Set<String> {
        var out: Set<String> = []
        func num(_ n: Int) { out.insert(String(n)) }
        func duration(_ mins: Int) {
            num(mins / 60); num(mins % 60); num(mins)
            out.insert(String(format: "%02d", mins % 60))
        }
        func clock(_ c: String?) {
            guard let c else { return }
            for p in c.split(separator: ":") {
                out.insert(String(p))
                if let v = Int(p) { num(v) }
            }
        }
        for v in [d.asleepMin, d.deepMin, d.remMin, d.coreMin, d.awakeMin,
                  d.weekMeanMin] { duration(v) }
        if let p = d.prevWeekMeanMin { duration(p) }
        if let bed = d.night.inBedMin { duration(bed) }
        clock(d.shape?.startClock); clock(d.shape?.endClock)
        clock(d.night.fellAsleepClock); clock(d.night.wokeUpClock)
        if let w = d.shape?.wake { clock(w.clock); duration(w.minutes) }
        if let b = d.bedtime {
            clock(b.thisWeekClock); clock(b.prevWeekClock)
            num(b.nightsNearUsual); num(b.nightCount)
        }
        for h in 0..<24 { out.insert(String(format: "%02d", h)); num(h) }
        for n in d.nights { out.insert(String(format: "%.1f", n.hours)) }
        for c in 0...7 { num(c) }                       // week counts
        let total = max(1, d.deepMin + d.remMin + d.coreMin)
        for v in [d.deepMin, d.remMin, d.coreMin, d.deepMin + d.remMin] {
            num(Int((Double(v) / Double(total) * 100).rounded()))
        }
        if let s = SleepDetailDeriver.score(of: d) {
            for v in [s.rest, s.depth, s.rhythm] { num(Int(v.rounded())) }
            num(s.total)
        }
        for v in [0, 20, 30, 50] { num(v) }             // score denominators
        // longest unbroken stretch — recomputed here, independently
        if let segs = d.night.segments {
            var best: (Int, Date)? = nil
            var runStart: Date? = nil, runEnd: Date? = nil
            for s in segs {
                if s.stage == .awake { runStart = nil; runEnd = nil; continue }
                if let e = runEnd, s.start.timeIntervalSince(e) <= 60 {
                    runEnd = max(e, s.end)
                } else { runStart = s.start; runEnd = s.end }
                if let st = runStart, let e = runEnd {
                    let m = Int((e.timeIntervalSince(st) / 60).rounded())
                    if m > (best?.0 ?? 0) { best = (m, e) }
                }
            }
            if let best { duration(best.0); clock(SleepNight.clock(best.1)) }
        }
        for nap in d.night.naps {
            num(nap.asleepMin)
            if let st = nap.start { clock(SleepNight.clock(st)) }
        }
        if let r = d.night.respiratoryRateMean { out.insert(String(format: "%.1f", r)) }
        if let b = d.night.respiratoryRateBaseline { out.insert(String(format: "%.1f", b)) }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_GB")
        fmt.dateFormat = "d MMM"
        for r in [d.month, d.sixMonths] {
            num(r.nightsWithData); num(r.slots.count)
            if let m = r.meanAsleepMin { duration(m) }
            if let f = r.slots.first?.date { numericTokens(fmt.string(from: f)).forEach { out.insert($0) } }
            if let l = r.slots.last?.date { numericTokens(fmt.string(from: l)).forEach { out.insert($0) } }
        }
        num(d.week.days.count); num(d.week.nightsWithData)
        return out
    }

    // 1 — the agreement walk.
    @Test func everyDisplayedFigureTracesToTheModel() throws {
        var s = HealthSamples()
        for o in [0, -1, -2, -3, -4, -5, -8, -9, -10] { s.sleep += watchNight(o) }
        // a source-written in-bed span, a second source, and a nap — the full anatomy
        s.sleepInBed.append(InBedSpan(
            date: day(0), start: day(0).addingTimeInterval(-1.3 * 3600), hours: 8.1,
            source: "Apple Watch", tier: .estimate, provenance: .real))
        s.sleep.append(SleepReading(
            date: day(0), stage: .asleepUnspecified, hours: 7.4,
            start: day(0).addingTimeInterval(-0.9 * 3600),
            source: "iPhone", tier: .estimate, provenance: .real))
        s.sleep.append(seg(.asleepUnspecified, from: 14.0, to: 15.2))
        let d = try derive(s)
        #expect(d.assertAgreement().isEmpty)

        let m = SleepDetailView.Model(derived: d)
        let canonical = canonicalTokens(for: d)
        var unknown: [String: [String]] = [:]
        for text in m.allDisplayedStrings() {
            for token in numericTokens(text) where !canonical.contains(token) {
                unknown[text, default: []].append(token)
            }
        }
        #expect(unknown.isEmpty, "figures with no canonical source: \(unknown)")
    }

    // 2 — tiles, hero, chart labels: one stored property each, so equal by
    //     construction — asserted against the night model directly.
    @Test func tilesHeroAndChartLabelsCannotContradict() throws {
        var s = HealthSamples()
        for o in [0, -1, -2, -3] { s.sleep += watchNight(o) }
        // the historical double-count shape: a second undifferentiated source
        s.sleep.append(SleepReading(
            date: day(0), stage: .asleepUnspecified, hours: 7.4,
            start: day(0).addingTimeInterval(-0.9 * 3600),
            source: "iPhone", tier: .estimate, provenance: .real))
        let d = try derive(s)
        #expect(d.assertAgreement().isEmpty)
        let m = SleepDetailView.Model(derived: d)

        #expect(m.statText == fmtMin(d.night.asleepMin))
        #expect(m.stats.first(where: { $0.1 == "DEEP" })?.0 == fmtMin(d.night.deepMin))
        #expect(m.stats.first(where: { $0.1 == "REM" })?.0 == fmtMin(d.night.remMin))
        #expect(m.stats.first(where: { $0.1 == "CORE" })?.0 == fmtMin(d.night.coreMin))
        #expect(m.hypnogramA11y.contains("Deep \(fmtMin(d.night.deepMin))"))
        #expect(m.hypnogramA11y.contains("Core \(fmtMin(d.night.coreMin))"))
        #expect(m.heroSub.contains("Deep \(fmtMin(d.night.deepMin))"))
        // and the 7.3h watch night can never read as a ~15h union again
        #expect(d.night.asleepMin < 8 * 60)
    }

    // 3 — TIME IN BED honesty.
    @Test func inBedNeverCountsTowardAsleepAndReadsDashWhenAbsent() throws {
        // (a) source-written in-bed rows → the figure, from-source, no foot
        var s = HealthSamples()
        for o in [0, -1, -2] { s.sleep += watchNight(o) }
        s.sleepInBed.append(InBedSpan(
            date: day(0), start: day(0).addingTimeInterval(-1.25 * 3600), hours: 8.0,
            source: "Apple Watch", tier: .estimate, provenance: .real))
        let with = SleepDetailView.Model(derived: try derive(s))
        #expect(with.inBedText == fmtMin(480))
        #expect(with.statText == fmtMin(438))       // asleep untouched by in-bed
        #expect(with.inBedFoot == nil)

        // (b) timed night, no in-bed rows → the night's own span, disclosed
        let envelope = SleepDetailView.Model(derived: try fixture(nights: [0]))
        #expect(envelope.inBedText == fmtMin(450))  // 23:00 → 06:30
        #expect(envelope.statText == fmtMin(438))
        #expect(envelope.inBedFoot?.contains("night's own span") == true)

        // (c) untimed night → "—" with the why, never an estimate
        var s2 = HealthSamples()
        s2.sleep = [
            SleepReading(date: day(0), stage: .deep, hours: 1.5, source: "Import",
                         tier: .estimate, provenance: .real),
            SleepReading(date: day(0), stage: .core, hours: 4.0, source: "Import",
                         tier: .estimate, provenance: .real),
            SleepReading(date: day(0), stage: .rem, hours: 1.5, source: "Import",
                         tier: .estimate, provenance: .real),
        ]
        let without = SleepDetailView.Model(derived: try derive(s2))
        #expect(without.inBedText == "—")
        #expect(without.inBedFoot?.contains("never estimated") == true)
        #expect(without.statText == fmtMin(420))
    }

    // 4 — score legs: "—" for not-yet, explanation for a genuine zero.
    @Test func missingScoreLegsReadDashNotZero() throws {
        let m = SleepDetailView.Model(derived: try fixture(nights: [0, -1, -2]))
        #expect(m.score == nil)
        let note = try #require(m.scoreNote)
        #expect(note.contains("—"))
        #expect(!m.heroSub.contains("/50"))          // no legs rendered at all
        #expect(NudgeGuard.check(note) == nil)
    }

    @Test func rhythmZeroIsExplainedAsMeasurementNotFault() throws {
        var s = HealthSamples()
        for o in [-1, -2, -3, -4] { s.sleep += watchNight(o) }
        // a real, far-off last night (4h staged) — |night − own mean| > 2h
        s.sleep += [seg(.core, from: 0, to: 2), seg(.deep, from: 2, to: 3),
                    seg(.rem, from: 3, to: 4)]
        let d = try derive(s)
        let m = SleepDetailView.Model(derived: d)
        let sc = try #require(m.score)
        #expect(Int(sc.rhythm.rounded()) == 0)
        #expect(m.heroSub.contains("Rhythm 0/20"))
        #expect(m.scoreNote?.contains("measurement") == true)
    }

    // 5 — hour marks come from the night's own clocks.
    @Test func hourMarksComeFromTheNightsOwnClocks() {
        let short = SleepDetailView.Model.hourMarks(startClock: "23:04", endClock: "06:14")
        #expect(short.map(\.label) == ["00", "01", "02", "03", "04", "05"])
        #expect(short.map(\.t) == short.map(\.t).sorted())
        #expect(short.allSatisfy { $0.t > 0 && $0.t < 1 })

        let long = SleepDetailView.Model.hourMarks(startClock: "21:00", endClock: "09:00")
        #expect(long.map(\.label) == ["22", "00", "02", "04", "06", "08"])

        #expect(SleepDetailView.Model.hourMarks(startClock: "nonsense", endClock: "06:14").isEmpty)
    }

    // 6 — the draw-time merge: spans preserved, gaps never bridged, disclosed.
    @Test func drawTimeMergeNeverAltersSpansAndDisclosesItself() {
        var segs: [SleepHypnoSegment] = []
        var t = 0.0
        for i in 0..<60 {                               // 60 slivers ≈ 0.64pt each
            segs.append(SleepHypnoSegment(stage: i % 2 == 0 ? 2 : 0, t0: t, t1: t + 0.002))
            t += 0.002
        }
        segs.append(SleepHypnoSegment(stage: 3, t0: t, t1: t + 0.4)); t += 0.4
        segs.append(SleepHypnoSegment(stage: 1, t0: t, t1: 1.0))

        let narrow = SleepBlockHypnogram.drawBlocks(segs, plotWidth: 320)
        #expect(narrow.simplified)                      // merge disclosed
        #expect(abs(narrow.blocks.first!.x0 - 0) < 0.01)
        #expect(abs(narrow.blocks.last!.x1 - 320) < 0.01)
        for (a, b) in zip(narrow.blocks, narrow.blocks.dropFirst()) {
            #expect(a.x1 <= b.x0 + 0.01)                // ordered, non-overlapping
        }
        for b in narrow.blocks {
            #expect(b.width >= 2 - 0.01)                // the 2pt floor holds
        }

        // plenty of room ⇒ nothing merges, nothing disclosed
        let wide = SleepBlockHypnogram.drawBlocks(segs, plotWidth: 100_000)
        #expect(!wide.simplified)

        // a REAL unrecorded gap is never bridged, even between same-stage blocks
        let gapped = [SleepHypnoSegment(stage: 2, t0: 0, t1: 0.4),
                      SleepHypnoSegment(stage: 2, t0: 0.6, t1: 1.0)]
        let g = SleepBlockHypnogram.drawBlocks(gapped, plotWidth: 300)
        #expect(g.blocks.count == 2)
        #expect(!g.simplified)
    }

    // 7 — week clock columns: own hour, gaps stay gaps.
    @Test func clockColumnsSitAtTheirOwnHourAndGapsStayGaps() throws {
        var s = HealthSamples()
        for o in [0, -1, -3, -5] { s.sleep += watchNight(o) }   // −2/−4/−6 = gaps
        let d = try derive(s)
        let m = SleepDetailView.Model(derived: d)
        let wk = try #require(m.weekClock)
        #expect(wk.nights.count == 7)
        #expect(wk.nights.filter { $0.f0 == nil }.count == 3)   // gaps preserved
        let lastNight = try #require(wk.nights.last)
        #expect(lastNight.isLastNight)
        // bedtime 23:00 on the 22:00→14:00 axis = 1/16; wake 06:30 = 8.5/16
        #expect(abs(try #require(lastNight.f0) - 1.0 / 16.0) < 0.01)
        #expect(abs(try #require(lastNight.f1) - 8.5 / 16.0) < 0.01)
        #expect(!lastNight.stripes.isEmpty)
    }

    // 8 — every sentence, every variant, FR-NDG-06 clean.
    @Test func everyRenderedSentencePassesTheGuard() throws {
        var models: [SleepDetailView.Model] = [.designSeed]
        models.append(SleepDetailView.Model(derived: try fixture(nights: [0])))
        models.append(SleepDetailView.Model(
            derived: try fixture(nights: [0, -1, -2, -3, -4, -8, -9, -10])))
        var untimed = HealthSamples()
        untimed.sleep = [
            SleepReading(date: day(0), stage: .deep, hours: 1.5, source: "Import",
                         tier: .estimate, provenance: .real),
            SleepReading(date: day(0), stage: .core, hours: 4.0, source: "Import",
                         tier: .estimate, provenance: .real),
        ]
        models.append(SleepDetailView.Model(derived: try derive(untimed)))

        for m in models {
            for text in m.allDisplayedStrings() {
                #expect(NudgeGuard.check(text) == nil, "guard hit: \(text)")
            }
        }
        for fixed in [SleepBlockHypnogram.simplifiedNote, SleepBlockHypnogram.steadyNote] {
            #expect(NudgeGuard.check(fixed) == nil)
        }
    }

    // 9 — the design seed: real deriver, full anatomy, no fixture names in prose.
    @Test func designSeedGoesThroughTheRealDeriverAndLeaksNoFixtureName() {
        let seed = SleepDetailView.Model.designSeed
        #expect(seed.showDemoDepthChart)                // demo-seed marker
        #expect(!seed.hypnoSegments.isEmpty)
        #expect(seed.weekClock != nil)
        #expect(seed.monthTrend != nil)
        #expect(seed.sixMonthTrend != nil)
        #expect(seed.score != nil)
        #expect(seed.inBedText != "—")
        #expect(seed.highlights.contains { $0.text.contains("nap") })
        #expect(seed.highlights.contains { $0.text.contains("second app") })
        for text in seed.allDisplayedStrings() {
            #expect(!text.lowercased().contains("sample data"), "fixture name in prose: \(text)")
            #expect(!text.lowercased().contains("mock"), "fixture name in prose: \(text)")
        }
    }

    // 9b — a real derived model is never marked as the demo seed.
    @Test func derivedModelIsNeverTheDemoSeed() throws {
        let m = SleepDetailView.Model(derived: try fixture(nights: [0]))
        #expect(m.showDemoDepthChart == false)
    }

    // 10 — SOURCE LINT: no figure formatting above the model marker.
    @Test func viewCodeFormatsNoFigures() throws {
        let src = try SourceLint.text("Maude/Views/SleepDetailView.swift")
        let marker = "// MARK: - Screen model building"
        let parts = src.components(separatedBy: marker)
        #expect(parts.count >= 2, "the model marker went missing — the lint guards nothing")
        let viewPart = try #require(parts.first)
        for pattern in ["String(format", "minText(", ".rounded()"] {
            let hits = SourceLint.codeLines(viewPart).filter { $0.line.contains(pattern) }
            #expect(hits.isEmpty,
                    "figure formatting in view code (\(pattern)) at lines \(hits.map(\.n))")
        }
    }

    // Longest-unbroken-stretch arithmetic, pinned.
    @Test func longestUnbrokenStretchIsExact() {
        let b = day(0)
        func at(_ h: Double) -> Date { b.addingTimeInterval(h * 3600) }
        let segs: [SleepNight.Segment] = [
            .init(stage: .core, start: at(-1.0), end: at(0.5)),    // 90 min
            .init(stage: .awake, start: at(0.5), end: at(0.7)),    // breaks the run
            .init(stage: .deep, start: at(0.7), end: at(2.0)),
            .init(stage: .rem, start: at(2.0), end: at(3.4)),      // 0.7→3.4 = 162 min
        ]
        let run = SleepDetailView.Model.longestUnbrokenStretch(segs)
        #expect(run?.minutes == 162)
        #expect(run?.end == at(3.4))

        // an unrecorded gap breaks a run too — gaps are not sleep
        let gapped: [SleepNight.Segment] = [
            .init(stage: .core, start: at(0), end: at(2.0)),
            .init(stage: .core, start: at(2.5), end: at(4.0)),
        ]
        #expect(SleepDetailView.Model.longestUnbrokenStretch(gapped)?.minutes == 120)
    }
}
