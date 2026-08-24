import Testing
import Foundation
import SwiftUI
@testable import Liviqa

// FB-APC4qJBj — "Try to make yellow and red zones for better visualisation.
// You did before."
//
// The tester was right, and right about "before": the five-zone clinical
// Time-in-Range ramp already shipped, on Glucose detail and Metric detail,
// behind the `clinicalTIRZones` setting that defaults ON. Day Replay was never
// migrated onto it — it hard-coded one flat personal band and never read the
// flag. So the same 19.9 peak drew banded on one screen and unbanded on
// another. The defect was that inconsistency, not a missing feature.
//
// What these tests hold:
//   1. There is ONE ramp. Extracting it must not have produced a second
//      palette, a second set of boundaries, or a second implementation.
//   2. PR-105 is load-bearing: severity NEVER rests on colour alone — very-low
//      hatched, very-high dotted, every band with room labelled.
//   3. The five signed-off tokens are the only colours (CN 2026-08-12,
//      qms/RISK.md PR-105).
//   4. Zones on widens the y-domain enough that the amber and sienna bands are
//      actually visible on an in-range day — a ramp squeezed to a sliver would
//      satisfy the code review and not the tester.
//   5. Zones off reproduces the old single-band geometry exactly.
struct ClinicalTIRZoneTests {

    // The citizen's own target bounds, and the chart defaults.
    private let low = 3.9, high = 10.0
    private let yMin = 2.0, yMax = 14.0

    private var ramp: [ClinicalTIRZones.Band] {
        ClinicalTIRZones.bands(yMin: yMin, yMax: yMax, low: low, high: high)
    }

    // MARK: - 1. One ramp, contiguous, in clinical order

    @Test func theRampIsFiveContiguousBandsBottomToTop() {
        #expect(ramp.count == 5)
        #expect(ramp.map(\.label) == ["VERY LOW", "LOW", "IN RANGE", "HIGH", "VERY HIGH"])

        // Contiguous: no gap a reading could fall into, no overlap that would
        // let one reading claim two severities.
        for (a, b) in zip(ramp, ramp.dropFirst()) {
            #expect(a.upper == b.lower, "gap or overlap between \(a.label) and \(b.label)")
        }
        #expect(ramp.first?.lower == yMin)
        #expect(ramp.last?.upper == yMax)

        // The personal target bounds are the TARGET band's edges — the citizen's
        // own range, not a population one.
        let target = ramp[2]
        #expect(target.lower == low)
        #expect(target.upper == high)

        // …while the L2 boundaries are clinical constants, not personal.
        #expect(ClinicalTIRZones.veryLowCeiling == 3.0)
        #expect(ClinicalTIRZones.veryHighFloor == 13.9)
    }

    /// A citizen with a tighter personal range moves the TARGET edges and
    /// nothing else — the clinical L2 boundaries stay put.
    @Test func aPersonalRangeMovesOnlyTheTargetEdges() {
        let tight = ClinicalTIRZones.bands(yMin: yMin, yMax: yMax, low: 4.5, high: 8.0)
        #expect(tight[1].upper == 4.5)      // LOW now runs 3.0 → 4.5
        #expect(tight[2].lower == 4.5)
        #expect(tight[2].upper == 8.0)
        #expect(tight[3].lower == 8.0)      // HIGH now runs 8.0 → 13.9
        #expect(tight[0].upper == 3.0)      // unchanged
        #expect(tight[4].lower == 13.9)     // unchanged
    }

    // MARK: - 2. Severity never rests on colour alone (PR-105)

    @Test func severityCarriesANonColourSignal() {
        #expect(ramp[0].pattern == .hatch, "very-low lost its hatch")
        #expect(ramp[4].pattern == .dots, "very-high lost its dots")
        // Every band names itself, so the ramp is readable with no colour
        // perception at all.
        #expect(ramp.allSatisfy { !$0.label.isEmpty })
    }

    // MARK: - 3. The five signed-off tokens, and no others

    @Test func theRampUsesTheFrozenPalette() {
        #expect(ramp[0].color == LiviqaTheme.tirVeryLow)
        #expect(ramp[1].color == LiviqaTheme.tirLow)
        #expect(ramp[2].color == LiviqaTheme.tirTarget)
        #expect(ramp[3].color == LiviqaTheme.tirHigh)
        #expect(ramp[4].color == LiviqaTheme.tirVeryHigh)
        #expect(Set(ramp.map(\.color)).count == 5, "two bands share a colour")
    }

    /// Extraction, not duplication: the private implementation must be GONE
    /// from GlucoseCurveView, and there must be exactly one ramp in the tree.
    @Test func thereIsExactlyOneImplementationOfTheRamp() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let oura = try String(contentsOf: root.appendingPathComponent("Liviqa/Views/OuraComponents.swift"),
                              encoding: .utf8)
        #expect(!oura.contains("private func clinicalZones"),
                "GlucoseCurveView still carries its own copy of the ramp")
        #expect(!oura.contains("private func zoneBand"),
                "GlucoseCurveView still carries its own band builder")
        #expect(oura.components(separatedBy: "struct ClinicalTIRZones").count - 1 == 1)

        let trends = try String(contentsOf: root.appendingPathComponent("Liviqa/Views/TrendsCharts.swift"),
                                encoding: .utf8)
        #expect(trends.contains("ClinicalTIRZones("),
                "DayReplayChart is not drawing the shared ramp")
        // No second palette: the day replay must not name the tokens directly.
        for token in ["tirVeryLow", "tirLow", "tirTarget", "tirHigh", "tirVeryHigh"] {
            #expect(!trends.contains("LiviqaTheme.\(token)"),
                    "TrendsCharts reaches for \(token) directly — the ramp owns the palette")
        }
    }

    // MARK: - 4. A peak in each of the five bands

    @Test func aReadingLandsInTheBandItsValueBelongsTo() {
        func bandLabel(_ v: Double) -> String {
            ClinicalTIRZones.band(containing: v, yMin: yMin, yMax: yMax,
                                  low: low, high: high).label
        }
        #expect(bandLabel(2.4) == "VERY LOW")     // L2 hypo
        #expect(bandLabel(3.4) == "LOW")          // the tester's 09:01 low
        #expect(bandLabel(6.2) == "IN RANGE")
        #expect(bandLabel(12.0) == "HIGH")
        #expect(bandLabel(19.9) == "VERY HIGH")   // the tester's 04:58 peak

        // Boundaries belong to the band above them, and nothing is unclassified
        // beyond the drawn axis.
        #expect(bandLabel(3.0) == "LOW")
        #expect(bandLabel(3.9) == "IN RANGE")
        #expect(bandLabel(10.0) == "HIGH")
        #expect(bandLabel(13.9) == "VERY HIGH")
        #expect(bandLabel(0.5) == "VERY LOW")
        #expect(bandLabel(30.0) == "VERY HIGH")
    }

    // MARK: - 5. The y-domain

    private func pt(_ hour: Double, _ mmol: Double) -> DayReplay.Point {
        DayReplay.Point(hour: hour, mmol: mmol,
                        timeText: String(format: "%02d:00", Int(hour)))
    }

    /// An entirely in-range day is the case that exposes a token fix: if the
    /// domain still clamped to the data, HIGH and VERY HIGH would be a sliver
    /// or absent, and the tester would report the same thing again.
    @Test func zonesOnWidenTheDomainSoTheOuterBandsAreVisible() {
        let steadyDay = [pt(7, 5.2), pt(12, 6.1), pt(18, 5.8)]
        let d = DayReplayChart.domain(points: steadyDay, bandLo: 3.9, bandHi: 10.0,
                                      clinicalZones: true)
        #expect(d.lo <= 2.0)
        #expect(d.hi >= 14.0)

        // The bands the day is read against get real height — this is the point
        // of widening. HIGH in particular (the tester's "yellow") must be a
        // readable stripe, not a hairline.
        let span = d.hi - d.lo
        let bands = ClinicalTIRZones.bands(yMin: d.lo, yMax: d.hi, low: 3.9, high: 10.0)
        func share(_ label: String) -> Double {
            guard let b = bands.first(where: { $0.label == label }) else { return 0 }
            return (b.upper - b.lower) / span
        }
        #expect(share("VERY LOW") > 0.05)
        #expect(share("LOW") > 0.05)
        #expect(share("IN RANGE") > 0.05)
        #expect(share("HIGH") > 0.20, "the amber band is the one the tester asked for")

        // VERY HIGH is a hairline here, and that is CORRECT rather than a
        // defect: this day never went above 13.9, so the axis stops just past
        // the L2 floor and there is nothing up there to show. On a day that
        // does go there the domain follows the reading — see the test below,
        // where the tester's own 19.9 peak gives the sienna band real height.
        // (Both shipped glucose charts behave identically: they pass the same
        // 2.0…14.0 defaults.)
        #expect(bands.last?.label == "VERY HIGH")
        #expect(share("VERY HIGH") > 0)
    }

    /// The counterpart: on a day that DOES reach L2 hyper, the sienna band is a
    /// real stripe, because the domain follows the reading.
    @Test func aDayThatReachesLevelTwoHyperGivesTheSiennaBandRealHeight() {
        let spikeDay = [pt(5, 19.9), pt(9, 3.4), pt(14, 7.7)]
        let d = DayReplayChart.domain(points: spikeDay, bandLo: 3.9, bandHi: 10.0,
                                      clinicalZones: true)
        let bands = ClinicalTIRZones.bands(yMin: d.lo, yMax: d.hi, low: 3.9, high: 10.0)
        let veryHigh = try! #require(bands.last)
        #expect((veryHigh.upper - veryHigh.lower) / (d.hi - d.lo) > 0.20,
                "the day's peak sits in VERY HIGH — that band must be plainly visible")
    }

    /// …and widening must not clip the day. The tester's own day ran 3.4–19.9.
    @Test func theDomainStillContainsTheDaysOwnExtremes() {
        let testersDay = [pt(4.97, 19.9), pt(9.02, 3.4), pt(14, 7.7)]
        let d = DayReplayChart.domain(points: testersDay, bandLo: 3.9, bandHi: 10.0,
                                      clinicalZones: true)
        #expect(d.lo < 3.4, "the 09:01 low would sit on the axis floor")
        #expect(d.hi > 19.9, "the 04:58 peak would be clipped")
    }

    /// Regression: with the flag off, the geometry is what it was before this
    /// change — the old formula, to the value.
    @Test func zonesOffReproduceTheLegacyDomainExactly() {
        let day = [pt(7, 5.2), pt(12, 11.4), pt(18, 4.1)]
        let d = DayReplayChart.domain(points: day, bandLo: 3.9, bandHi: 10.0,
                                      clinicalZones: false)
        // legacy: min(data.min, bandLo) − 0.8 … max(data.max, bandHi) + 0.8
        #expect(abs(d.lo - (min(4.1, 3.9) - 0.8)) < 1e-9)
        #expect(abs(d.hi - (max(11.4, 10.0) + 0.8)) < 1e-9)

        // A flat day still gets a non-degenerate axis.
        let flat = [pt(7, 5.0), pt(8, 5.0)]
        let f = DayReplayChart.domain(points: flat, bandLo: 5.0, bandHi: 5.0,
                                      clinicalZones: false)
        #expect(f.hi > f.lo)
    }

    /// The y-axis work must not disturb the x-axis (PR-116, DayAxisIntegrity).
    @Test func theTimeAxisIsUnaffectedByTheZoneWork() {
        let day = [pt(7, 5.2), pt(8, 6.0), pt(9, 5.5), pt(20, 12.0)]
        // Positions come from the clock, not the domain or the reading count.
        #expect(DayReplayChart.fraction(in: day, of: 0) == 0)
        #expect(DayReplayChart.fraction(in: day, of: 3) == 1)
        #expect(abs(DayReplayChart.fraction(in: day, of: 1) - 1.0 / 13.0) < 1e-9)
        #expect(DayReplayChart.nearestIndex(in: day, toFraction: 0.5) == 2)
    }
}

// MARK: - Equivalence with the pre-refactor geometry
//
// The ramp was lifted OUT of GlucoseCurveView, which has shipped for months.
// "Extract, do not duplicate" also means "extract, do not move anything by a
// pixel": Glucose detail and Metric detail must render exactly as before.
//
// The old code placed each band with `top = y(upper)` and
// `height = y(lower) - y(upper)` over the plot height, as siblings in a
// GeometryReader-sized ZStack. The new code stacks them top-down. These are the
// same rects only if the stack's running cursor lands on each band's old `top`
// and the heights match — which is what this asserts, to a thousandth of a
// point, across several plot heights and personal ranges.
struct ClinicalTIRZoneGeometryTests {

    private func check(height H: CGFloat, yMin: Double, yMax: Double,
                       low: Double, high: Double) {
        func oldY(_ v: Double) -> CGFloat {          // the pre-refactor mapping
            let frac = (v - yMin) / (yMax - yMin)
            return H - CGFloat(min(1, max(0, frac))) * H
        }
        let bands = ClinicalTIRZones.bands(yMin: yMin, yMax: yMax, low: low, high: high)
        var cursor: CGFloat = 0                       // top of the stack
        for b in bands.reversed() {                   // drawn top → bottom
            let drawn = ClinicalTIRZones.drawnHeight(of: b, yMin: yMin, yMax: yMax, height: H)
            #expect(abs(cursor - oldY(b.upper)) < 0.001,
                    "\(b.label) starts at \(cursor), old geometry put it at \(oldY(b.upper))")
            #expect(abs(drawn - (oldY(b.lower) - oldY(b.upper))) < 0.001,
                    "\(b.label) is \(drawn) tall, old geometry drew \(oldY(b.lower) - oldY(b.upper))")
            cursor += drawn
        }
        // …and the ramp fills the plot exactly — no gap at the bottom, no overrun.
        #expect(abs(cursor - H) < 0.001, "the ramp covers \(cursor) of \(H)")
    }

    @Test func theStackReproducesThePreRefactorBandRects() {
        // GlucoseCurveView's own defaults, at its default and a compact height.
        check(height: 150, yMin: 2.0, yMax: 14.0, low: 3.9, high: 10.0)
        check(height: 90,  yMin: 2.0, yMax: 14.0, low: 3.9, high: 10.0)
        // A tighter personal range.
        check(height: 150, yMin: 2.0, yMax: 14.0, low: 4.5, high: 8.0)
        // The widened Day Replay domain on a day that reaches L2 hyper.
        check(height: 138, yMin: 2.0, yMax: 20.7, low: 3.9, high: 10.0)
    }
}
