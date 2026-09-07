import Testing
@testable import Maude

// L1 provider resolution (go-live Wave 1). The app must read REAL HealthKit on a
// device that has Health, fall back to demo when it doesn't, and force demo for
// screenshot/UI-test runs so the "Demo data" labelling stays honest.
struct ProviderResolutionTests {

    // Real device (Health available), no overrides → real HealthKit.
    @Test func realDeviceUsesHealthKit() {
        let kind = AppState.resolveProviderKind(arguments: [], env: [:], realAvailable: true)
        #expect(kind == .healthKit)
    }

    // Platform without Health (e.g. a Simulator that reports unavailable) → demo.
    @Test func noHealthFallsBackToMock() {
        let kind = AppState.resolveProviderKind(arguments: [], env: [:], realAvailable: false)
        #expect(kind == .mock)
    }

    // Screenshot / UI-test runs force demo even on a Health-capable platform.
    @Test func uiTestFlagForcesMock() {
        let kind = AppState.resolveProviderKind(arguments: ["-uiTestAutoDemo"], env: [:], realAvailable: true)
        #expect(kind == .mock)
    }

    // Explicit env overrides win.
    @Test func envForcesMock() {
        let kind = AppState.resolveProviderKind(arguments: [], env: ["MAUDE_DATA": "mock"], realAvailable: true)
        #expect(kind == .mock)
    }

    @Test func envForcesHealthKitEvenWhenUnavailableFlag() {
        // Explicit healthKit request is honoured regardless of the availability hint
        // (the actual fetch still degrades gracefully if the SDK can't serve it).
        let kind = AppState.resolveProviderKind(arguments: [], env: ["MAUDE_DATA": "healthKit"], realAvailable: false)
        #expect(kind == .healthKit)
    }

    // The demo flag is independent of provider kind: mock data is always "demo".
    @Test func mockKindIsDemo() {
        #expect(DataProviderKind.mock.isDemoData)
        #expect(!DataProviderKind.healthKit.isDemoData)
    }
}
