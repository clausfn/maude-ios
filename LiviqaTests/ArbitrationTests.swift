import Testing
import Foundation
@testable import Liviqa

// FR-PROV-01 — per-metric source arbitration (DataModel v1 §2.3).
// Highest tier present wins per slot; lower tiers fill gaps; never blend.
// T-ARB-01..05.
struct ArbitrationTests {

    private func metric(_ value: Double, _ tier: DataTier, _ src: String,
                        day: Date) -> DailyMetric {
        DailyMetric(date: day, kind: .hrvSDNN, value: value, source: src,
                    tier: tier, provenance: tier == .clinical ? .real : .simulated)
    }

    private let d0 = Date(timeIntervalSince1970: 1_750_000_000)
    private var d1: Date { d0.addingTimeInterval(86_400) }

    // T-ARB-01 — clinical beats good and estimate for the same slot.
    @Test func highestTierWins() {
        let input = [
            metric(40, .estimate, "watch", day: d0),
            metric(44, .good,     "oura",  day: d0),
            metric(48, .clinical, "ecg",   day: d0),
        ]
        let out = SourceArbiter.arbitrate(input) { $0.kind.rawValue }
        #expect(out.count == 1)
        #expect(out.first?.tier == .clinical)
        #expect(out.first?.value == 48)
    }

    // T-ARB-02 — lower tiers FILL GAPS: a slot with no clinical keeps its best present.
    @Test func lowerTierFillsGaps() {
        let input = [
            metric(48, .clinical, "ecg",   day: d0),   // day 0 has clinical
            metric(40, .estimate, "watch", day: d1),   // day 1 only estimate
        ]
        let out = SourceArbiter.arbitrate(input) { "\($0.kind.rawValue)@\($0.date.timeIntervalSince1970)" }
        #expect(out.count == 2)
        #expect(out.contains { $0.tier == .clinical && $0.value == 48 })
        #expect(out.contains { $0.tier == .estimate && $0.value == 40 })   // gap filled
    }

    // T-ARB-03 — never blend: clinical + estimate in one slot → only clinical remains.
    @Test func neverBlendsTiers() {
        let input = [
            metric(48, .clinical, "ecg",   day: d0),
            metric(40, .estimate, "watch", day: d0),
        ]
        let out = SourceArbiter.arbitrate(input) { $0.kind.rawValue }
        #expect(out.allSatisfy { $0.tier == .clinical })
        #expect(!out.contains { $0.tier == .estimate })
    }

    // T-ARB-04 — empty input → empty output.
    @Test func emptyInputIsEmpty() {
        #expect(SourceArbiter.arbitrate([DailyMetric]()) { $0.kind.rawValue }.isEmpty)
    }

    // T-ARB-05 — HealthSamples.arbitrated collapses multi-source duplicates per day.
    @Test func samplesArbitratedAcrossStreams() {
        var s = HealthSamples()
        s.hrv = [metric(40, .estimate, "watch", day: d0),
                 metric(48, .clinical, "ecg",   day: d0)]
        let out = s.arbitrated(calendar: Calendar(identifier: .gregorian))
        #expect(out.hrv.count == 1)
        #expect(out.hrv.first?.tier == .clinical)
    }
}
