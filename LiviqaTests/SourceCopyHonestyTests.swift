import Testing
import Foundation
@testable import Liviqa

// T-DED-06 — FR-PROV-02 disclosure COPY. The dedup card is the one place a
// source name is interpolated into a running sentence, so it is the one place
// a fixture name can pretend to be a device. Design-QA 2026-08-13 caught
// "Kept Sample data for counting · merged Bike computer · Strava" in the
// running app: the demo flag was standing in a slot the reader parses as a
// device. The rule these tests hold: a demo seed is NEVER named in prose —
// the sentence drops the clause and the demo label moves to the card's chip.
struct SourceCopyHonestyTests {

    private func merge(kept: String, merged: [String], gained: [String] = []) -> WorkoutMerge {
        WorkoutMerge(start: Date(timeIntervalSince1970: 1_760_000_000),
                     type: "Cycling", kept: kept, merged: merged, enrichedFields: gained)
    }

    // Real devices keep the named sentence.
    @Test func namedDevicesReadAsDevices() {
        let s = DataSourcesView.mergeSentence(
            merge(kept: "Apple Watch", merged: ["Bike computer · Strava"]))
        #expect(s.contains("Apple Watch"))
        #expect(s.contains("Bike computer · Strava"))
        #expect(s.hasPrefix("Kept "))
    }

    // The demo seed is dropped from the sentence — not renamed inside it.
    @Test func demoSeedNeverStandsInProse() {
        let s = DataSourcesView.mergeSentence(
            merge(kept: "Mock", merged: ["Bike computer · Strava"]))
        #expect(!s.localizedCaseInsensitiveContains("mock"))
        #expect(!s.localizedCaseInsensitiveContains("sample data"))
        #expect(s.contains("Bike computer · Strava"))
        #expect(!s.contains("Kept "))
    }

    // A demo seed on the merged side is dropped too, and a sentence with
    // nothing truthful left to say is empty (the view renders no line).
    @Test func demoSeedDroppedFromEitherSide() {
        let s = DataSourcesView.mergeSentence(merge(kept: "Apple Watch", merged: ["Mock"]))
        #expect(!s.localizedCaseInsensitiveContains("mock"))
        #expect(s.contains("Apple Watch"))
        #expect(DataSourcesView.mergeSentence(merge(kept: "Mock", merged: ["mock"])).isEmpty)
    }

    // Enrichment fields carry their own source suffix — same rule applies.
    @Test func gainedFieldKeepsTheFieldAndDropsTheSeed() {
        #expect(DataSourcesView.gainedField("distance · Mock") == "distance")
        #expect(DataSourcesView.gainedField("energy · Bike computer · Strava")
                == "energy · Bike computer · Strava")
        let s = DataSourcesView.mergeSentence(
            merge(kept: "Mock", merged: ["Bike computer"], gained: ["distance · Mock"]))
        #expect(s.contains("distance"))
        #expect(!s.localizedCaseInsensitiveContains("mock"))
    }

    // The fixture rule is case-insensitive (the provider name is a constant,
    // but the disclosure must not depend on its casing).
    @Test func fixtureMatchIsCaseInsensitive() {
        #expect(DataSourcesView.deviceName("mock") == nil)
        #expect(DataSourcesView.deviceName("MOCK") == nil)
        #expect(DataSourcesView.deviceName("Mockingbird Ring") == "Mockingbird Ring")
    }
}
