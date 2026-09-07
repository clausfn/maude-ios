import Testing
import Foundation
import SwiftData
@testable import Maude

// L1→L2 mapping + idempotent persistence — RTM: FR-ING-02..05, OD-09.
@MainActor
struct MappingTests {

    private func week() -> (Date, Date) {
        let end = Date(timeIntervalSince1970: 1_750_000_000)
        return (end.addingTimeInterval(-6 * 86_400), end)
    }

    // T-MAP-01 — mock samples map to entities, provenance preserved (SIMULATED).
    @Test func mapsMockToEntities() async throws {
        let (from, to) = week()
        let s = try await MockDataProvider().fetchSamples(from: from, to: to)

        let glucose = try SampleMapper.glucose(s)
        let heart = try SampleMapper.heartDaily(s)
        #expect(glucose.count == s.glucose.count)
        #expect(glucose.allSatisfy { $0.provenance == .simulated })
        // HRV + RHR merge into one HeartDaily per day, both fields populated.
        #expect(!heart.isEmpty)
        #expect(heart.allSatisfy { $0.hrvMean != nil && $0.rhr != nil })
    }

    // T-MAP-02 — coordinator persists and re-sync is idempotent (no duplicates).
    @Test func reSyncIsIdempotent() async throws {
        let container = try MaudeStore.makeContainer(inMemory: true)
        let coord = IngestionCoordinator(context: container.mainContext, provider: MockDataProvider())
        let (from, to) = week()

        let first = try await coord.sync(from: from, to: to)
        let second = try await coord.sync(from: from, to: to)
        #expect(first.glucose > 0)
        #expect(first == second) // same window ⇒ same counts

        let stored = try container.mainContext.fetch(FetchDescriptor<GlucoseSample>())
        #expect(stored.count == first.glucose) // replaced, not doubled
    }
}
