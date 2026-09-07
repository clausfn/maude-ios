import Testing
@testable import Maude

#if canImport(HealthKit)
import HealthKit

// HealthKit read-only contract — RTM: FR-ARCH-04, blocking-adjacent.
struct HealthKitTests {

    // T-HK-RO-01 — the share/write set MUST be empty (never write to HealthKit).
    @Test func writeSetIsEmpty() {
        #expect(HealthKitService.shareTypes.isEmpty)
    }

    // T-HK-RO-02 — full-HealthKit capture read set: the original MVP types plus
    // the extended panel (insulin, AFib, BP, body-comp, heart/respiratory).
    // Still read-only — the write side is covered by writeSetIsEmpty.
    @Test func readSetIsFullCaptureSet() {
        let t = HealthKitService.readTypes
        #expect(t.contains(HKObjectType.workoutType()))
        // MVP set still present
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .bloodGlucose)!))
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!))
        #expect(t.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
        // Extended capture present
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .insulinDelivery)!))
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .atrialFibrillationBurden)!))
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!))
        #expect(t.contains(HKObjectType.quantityType(forIdentifier: .bodyMass)!))
        // Comfortably larger than the original 7-type MVP set.
        #expect(t.count >= 20)
    }

    // T-HK-RO-03 — sleep stage mapping covers the asleep stages.
    @Test func sleepStageMapping() {
        #expect(HealthKitService.mapSleepStage(HKCategoryValueSleepAnalysis.asleepREM.rawValue) == .rem)
        #expect(HealthKitService.mapSleepStage(HKCategoryValueSleepAnalysis.asleepDeep.rawValue) == .deep)
        #expect(HealthKitService.mapSleepStage(HKCategoryValueSleepAnalysis.inBed.rawValue) == .inBed)
    }
}
#endif
