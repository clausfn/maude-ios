import Testing
import Foundation
@testable import Liviqa

// HealthKit ingestion coverage audit (2026-08-18) — RTM: FR-ING-16 (nightly
// wrist temperature), FR-ING-17 (cumulative daily roll-up never sums sources).
// Everything here is pure-value: NO HealthKit store is ever constructed and no
// live read path is awaited (the two-hangs rule).
struct HealthKitCoverageTests {

    private let cal = Calendar(identifier: .gregorian)
    private var d0: Date { cal.startOfDay(for: Date(timeIntervalSince1970: 1_755_400_000)) }
    private var d1: Date { cal.date(byAdding: .day, value: 1, to: d0)! }

    // MARK: DailyRollup — the multi-source double-count killer (FR-ING-17)

    // T-COV-01 — cumulative NEVER sums across sources: a watch and a phone both
    // recording the same walk yield the best-covering source's total, not the
    // two devices added together (the steps/energy analogue of the sleep
    // union-not-sum rule).
    @Test func cumulativeNeverSumsAcrossSources() {
        let rows = [
            DailyRollup.Row(day: d0, value: 5200, source: "Watch"),
            DailyRollup.Row(day: d0, value: 2800, source: "Watch"),
            DailyRollup.Row(day: d0, value: 5000, source: "iPhone"),
        ]
        let out = DailyRollup.rollUp(rows, cumulative: true)
        #expect(out.count == 1)
        #expect(out.first?.value == 8000)          // watch total — NOT 13 000
        #expect(out.first?.source == "Watch")
    }

    // T-COV-02 — a day only one device witnessed keeps that device's full
    // total (gap fill; the fix must not drop phone-only days).
    @Test func cumulativeKeepsSingleSourceDays() {
        let rows = [
            DailyRollup.Row(day: d0, value: 8000, source: "Watch"),
            DailyRollup.Row(day: d0, value: 7000, source: "iPhone"),
            DailyRollup.Row(day: d1, value: 4200, source: "iPhone"),   // charger day
        ]
        let out = DailyRollup.rollUp(rows, cumulative: true)
        #expect(out.count == 2)
        #expect(out.first?.value == 8000)
        #expect(out.last?.value == 4200 && out.last?.source == "iPhone")
    }

    // T-COV-03 — mean kinds still average across all samples (several estimates
    // of the same quantity average; they do not accumulate).
    @Test func meanAveragesWithinDay() {
        let rows = [
            DailyRollup.Row(day: d0, value: 60, source: "Watch"),
            DailyRollup.Row(day: d0, value: 64, source: "Oura"),
        ]
        let out = DailyRollup.rollUp(rows, cumulative: false)
        #expect(out.count == 1)
        #expect(out.first?.value == 62)
    }

    // T-COV-04 — deterministic: equal totals tie-break by source name, results
    // sorted by day, empty in → empty out (no fabricated rows).
    @Test func rollUpIsDeterministicAndHonest() {
        let tie = [
            DailyRollup.Row(day: d0, value: 500, source: "B"),
            DailyRollup.Row(day: d0, value: 500, source: "A"),
        ]
        let a = DailyRollup.rollUp(tie, cumulative: true)
        let b = DailyRollup.rollUp(tie.reversed(), cumulative: true)
        #expect(a == b)
        #expect(DailyRollup.rollUp([], cumulative: true).isEmpty)
        let days = DailyRollup.rollUp([
            DailyRollup.Row(day: d1, value: 1, source: "A"),
            DailyRollup.Row(day: d0, value: 1, source: "A"),
        ], cumulative: true).map(\.day)
        #expect(days == [d0, d1])
    }

    // MARK: Wrist temperature (FR-ING-16)

    private func mockWeek() async throws -> HealthSamples {
        let end = Date(timeIntervalSince1970: 1_750_000_000)
        return try await MockDataProvider().fetchSamples(from: end.addingTimeInterval(-6 * 86_400), to: end)
    }

    // T-COV-05 — the demo session exercises the wrist-temperature path: one
    // reading per night, every reading SIMULATED (never mistakable for the
    // citizen's own), in a physiologically plausible band, and each `date` is a
    // start-of-day night bucket so the DaySeries day-axis discipline holds.
    @Test func mockEmitsNightlyWristTemperature() async throws {
        let s = try await mockWeek()
        #expect(!s.wristTemperature.isEmpty)
        #expect(s.wristTemperature.allSatisfy { $0.provenance == .simulated })
        #expect(s.wristTemperature.allSatisfy { $0.celsius > 33.0 && $0.celsius < 37.0 })
        #expect(s.wristTemperature.allSatisfy { cal.startOfDay(for: $0.date) == $0.date })
        // One figure per night, and the nights are the sleep stream's nights.
        let nights = Set(s.wristTemperature.map(\.date))
        #expect(nights.count == s.wristTemperature.count)
        #expect(nights.isSubset(of: Set(s.sleep.map(\.date))))
    }

    // T-COV-06 — determinism + no fabricated defaults: the same demo seed
    // yields the identical series, and an empty aggregate carries no reading.
    @Test func wristTemperatureIsDeterministicNeverDefaulted() async throws {
        let a = try await mockWeek()
        let b = try await mockWeek()
        #expect(a.wristTemperature.map(\.celsius) == b.wristTemperature.map(\.celsius))
        #expect(HealthSamples.empty.wristTemperature.isEmpty)
    }

    // T-COV-07 — §2.3 arbitration per night: two sources recording the same
    // night keep only the higher tier (never blended); a night with only an
    // estimate keeps it (gap fill). Dedup across sources from day one.
    @Test func wristTemperatureArbitratesPerNight() {
        var s = HealthSamples()
        s.wristTemperature = [
            WristTemperatureReading(date: d0, celsius: 34.6, source: "Watch", tier: .good, provenance: .real),
            WristTemperatureReading(date: d0, celsius: 35.4, source: "Ring", tier: .estimate, provenance: .real),
            WristTemperatureReading(date: d1, celsius: 35.1, source: "Ring", tier: .estimate, provenance: .real),
        ]
        let out = s.arbitrated(calendar: cal)
        #expect(out.wristTemperature.count == 2)
        #expect(out.wristTemperature.first { $0.date == d0 }?.tier == .good)
        #expect(out.wristTemperature.first { $0.date == d0 }?.celsius == 34.6)
        #expect(out.wristTemperature.first { $0.date == d1 }?.celsius == 35.1)   // gap filled
    }
}

#if canImport(HealthKit)
import HealthKit

// Static read-set assertions only — no HKHealthStore is constructed here.
struct HealthKitCoverageReadSetTests {

    // T-COV-08 — the authorization READ set covers the wrist-temperature type
    // (the request must equal the set actually read), and the write set stays
    // empty (FR-ARCH-04).
    @Test func readSetCoversWristTemperature() {
        let t = HealthKitService.readTypes
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!))
        #expect(HealthKitService.shareTypes.isEmpty)
    }

    // T-COV-09 — every quantity type fetchSamples reads is in the request set:
    // the request never under-asks (a silent all-nil stream) and the audit's
    // "exactly the set read" claim stays checkable in one place.
    @Test func readSetMatchesWhatIsFetched() {
        let fetched: [HKQuantityTypeIdentifier] = [
            .bloodGlucose, .heartRateVariabilitySDNN, .restingHeartRate,
            .stepCount, .activeEnergyBurned,
            .heartRate, .walkingHeartRateAverage, .heartRateRecoveryOneMinute,
            .respiratoryRate, .oxygenSaturation, .vo2Max,
            .insulinDelivery, .atrialFibrillationBurden,
            .bloodPressureSystolic, .bloodPressureDiastolic,
            .bodyMass, .bodyFatPercentage, .leanBodyMass, .bodyMassIndex,
            .appleSleepingWristTemperature,
        ]
        let t = HealthKitService.readTypes
        for id in fetched {
            let type = HKObjectType.quantityType(forIdentifier: id)
            #expect(type != nil, "unknown identifier \(id.rawValue)")
            if let type { #expect(t.contains(type), "read set missing \(id.rawValue)") }
        }
        #expect(t.contains(HKObjectType.workoutType()))
        #expect(t.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
    }
}
#endif
