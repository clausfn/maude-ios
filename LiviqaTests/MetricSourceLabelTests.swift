import Testing
import Foundation
@testable import Liviqa

// T-DED-06 (extended) — the SAME rule the data-sources dedup card holds, now on
// the metric-detail heroes. Design-QA 2026-08-13 caught the Sleep hero printing
// "… Core 5h 31m · Sample data": the demo badge was standing in the slot a
// reader parses as a device name, right after three real figures. The rule:
// a demo seed is never named in prose — the clause is dropped, and the demo
// disclosure stays on the honesty chip driven by `isDemoData`.
struct MetricSourceLabelTests {

    @Test func realDeviceNamesSurvive() {
        #expect(MetricSourceLabel.inProse("Dexcom G7") == "Dexcom G7")
        #expect(MetricSourceLabel.inProse("Apple Watch") == "Apple Watch")
        #expect(MetricSourceLabel.inProse("Bike computer · Strava") == "Bike computer · Strava")
    }

    @Test func fixtureNamesAreDroppedNotRenamed() {
        for name in ["Mock", "mock", "MOCK", "Sample data", "sample data", "Demo", " mock "] {
            #expect(MetricSourceLabel.inProse(name) == nil,
                    "fixture name leaked into prose: \(name)")
        }
    }

    @Test func nothingToNameIsNil() {
        #expect(MetricSourceLabel.inProse(nil) == nil)
        #expect(MetricSourceLabel.inProse("") == nil)
        #expect(MetricSourceLabel.inProse("   ") == nil)
    }

    /// A device whose name merely CONTAINS a fixture word is still a device.
    @Test func onlyExactFixtureNamesMatch() {
        #expect(MetricSourceLabel.inProse("Mockingbird Ring") == "Mockingbird Ring")
        #expect(MetricSourceLabel.inProse("Sample Labs CGM") == "Sample Labs CGM")
        #expect(MetricSourceLabel.isFixture("Mockingbird Ring") == false)
    }

    /// The Sleep hero's sub line, end to end: the shipped bug and its fix.
    @Test func sleepSubLineNeverNamesTheFixture() {
        var parts = ["Deep 0h 52m · REM 1h 25m · Core 5h 31m"]
        if let src = MetricSourceLabel.inProse("Mock") { parts.append(src) }
        let sub = parts.joined(separator: " · ")
        #expect(!sub.localizedCaseInsensitiveContains("mock"))
        #expect(!sub.localizedCaseInsensitiveContains("sample data"))
        #expect(sub.hasSuffix("Core 5h 31m"))
    }
}
