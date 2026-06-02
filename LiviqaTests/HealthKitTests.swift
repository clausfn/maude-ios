import Testing
@testable import Liviqa

#if canImport(HealthKit)
import HealthKit

// HealthKit read-only contract — RTM: FR-ARCH-04, blocking-adjacent.
struct HealthKitTests {

    // T-HK-RO-01 — the share/write set MUST be empty (never write to HealthKit).
    @Test func writeSetIsEmpty() {
        #expect(HealthKitService.shareTypes.isEmpty)
    }

    // T-HK-RO-02 — read set is exactly the MVP read set (7 types).
    @Test func readSetIsMvpReadSet() {
        #expect(HealthKitService.readTypes.count == 7)
        #expect(HealthKitService.readTypes.contains(HKObjectType.workoutType()))
    }

    // T-HK-RO-03 — sleep stage mapping covers the asleep stages.
    @Test func sleepStageMapping() {
        #expect(HealthKitService.mapSleepStage(HKCategoryValueSleepAnalysis.asleepREM.rawValue) == .rem)
        #expect(HealthKitService.mapSleepStage(HKCategoryValueSleepAnalysis.asleepDeep.rawValue) == .deep)
        #expect(HealthKitService.mapSleepStage(HKCategoryValueSleepAnalysis.inBed.rawValue) == .inBed)
    }
}
#endif
