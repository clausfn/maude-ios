import Testing
import Foundation
@testable import Liviqa

// Design-QA 2026-08-13, Area ④ heroes. Two rules the sweep caught being broken,
// both pinned here so a future template edit can't quietly re-break them.
struct MetricDetailCopyTests {

    // MARK: Activity — the direction of a change is said exactly ONCE.
    //
    // Shipped copy read "−2 % fewer steps than your usual": the sign said "less"
    // and the words said "less" again, so the sentence literally claims the
    // opposite of a 2 % shortfall. The number carries the size, the words carry
    // the direction.

    private func activity(pct: Int?) -> ActivityWeekDetail {
        ActivityWeekDetail(
            stepsWeek: [7400, 8100, 5600, 9200, 8800, 11400, 12600],
            stepsLabels: ["M", "T", "W", "T", "F", "S", "S"],
            kcalWeek: [], kcalLabels: [],
            usualSteps: 8300, usualFromHistory: true, usualKcal: nil,
            weekStepsTotal: 63100, weekKcalTotal: nil,
            pctVsUsual: pct, daysAboveUsual: 4,
            longestDayName: "Sunday", longestDaySteps: 12600, workoutsLogged: 4)
    }

    @Test func belowUsualNeverDoublesTheNegative() {
        let m = ActivityDetailView.Model(derived: activity(pct: -2))
        #expect(m.stat == "2")
        #expect(m.statUnit == "% fewer steps than your usual")
        let line = "\(m.stat ?? "") \(m.statUnit ?? "")"
        #expect(!line.contains("-"))
        #expect(!line.contains("\u{2212}"))          // minus sign
    }

    @Test func aboveUsualSaysMoreOnce() {
        let m = ActivityDetailView.Model(derived: activity(pct: 12))
        #expect(m.stat == "12")
        #expect(m.statUnit == "% more steps than your usual")
        #expect(!(m.stat ?? "").contains("+"))
    }

    @Test func levelWeekSaysNeitherMoreNorFewer() {
        let m = ActivityDetailView.Model(derived: activity(pct: 0))
        #expect(m.stat == "0")
        #expect(m.statUnit?.contains("more") == false)
        #expect(m.statUnit?.contains("fewer") == false)
    }

    @Test func noPriorHistoryClaimsNothing() {
        let m = ActivityDetailView.Model(derived: activity(pct: nil))
        #expect(m.stat == nil)
        #expect(m.statUnit == nil)
    }

    /// The demo seed follows the same rule as the derived path — otherwise the
    /// screenshot everyone reviews and the shipping screen disagree.
    @Test func designSeedUsesTheSameRule() {
        let seed = ActivityDetailView.Model.designSeed
        #expect(!(seed.stat ?? "").contains("+"))
        #expect(seed.statUnit?.contains("more") == true)
    }

    // MARK: Heart — hero WEIGHT follows the verdict, not the domain.
    //
    // The rose plate is the strongest surface in the app. It carried "Resting
    // lower than your usual band" — a reassuring sentence on an alarm-weight
    // card. The full-bleed plate is now reserved for the verdict that actually
    // asks the reader to look; the token itself is untouched.

    private func heart(rhr: Int, band: ClosedRange<Double>?) -> HeartWeekDetail {
        HeartWeekDetail(
            rhrLatest: rhr, rhrSeries: [59, 60, 58, 61, 59, 58, 57],
            rhrBand: band, rhrWindowDays: 60, bp: [],
            sysBand: nil, diaBand: nil, bpLatestText: nil, bpPeakIndex: nil,
            bpEdgeLabels: [], bpSource: nil, afibLatestPct: nil,
            afibDaysObserved: 0, afibLatestDateText: nil)
    }

    @Test func calmVerdictsGetTheQuietHero() {
        // Inside the band, and below it — both are calm or descriptive.
        for rhr in [58, 48] {
            let m = HeartDetailView.Model(derived: heart(rhr: rhr, band: 56...61))
            #expect(m.needsAttention == false, "\(m.verdict) asked for the loud plate")
        }
        // No band yet ⇒ purely descriptive.
        let m = HeartDetailView.Model(derived: heart(rhr: 58, band: nil))
        #expect(m.needsAttention == false)
        #expect(HeartDetailView.Model.designSeed.needsAttention == false)
    }

    @Test func onlyTheWorthALookVerdictEarnsTheSolidHero() {
        let m = HeartDetailView.Model(derived: heart(rhr: 72, band: 56...61))
        #expect(m.needsAttention == true)
        #expect(m.verdict.contains("worth a look"))
    }

    /// Weight and words come off the same branch, so they cannot drift apart.
    @Test func weightAndVerdictNeverDisagree() {
        for rhr in [44, 52, 58, 61, 65, 80] {
            let m = HeartDetailView.Model(derived: heart(rhr: rhr, band: 56...61))
            #expect(m.needsAttention == m.verdict.contains("worth a look"))
        }
    }
}
