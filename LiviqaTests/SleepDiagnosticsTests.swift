import Testing
import Foundation
@testable import Liviqa

// FR-DIAG-01 — the sleep diagnostics report (sleep incident 2026-08).
// Fixture-driven, no live stores (the builder is pure Foundation): the report
// must show every raw sample with its source identity, mark what ingestion
// dropped, name the chosen source per night, list exactly which segments each
// total came from and which were excluded (with the reason) — and contain
// nothing beyond sleep timing. T-DIAG-01.
struct SleepDiagnosticsTests {

    private let cal = Calendar(identifier: .gregorian)
    private var now: Date { cal.date(bySettingHour: 10, minute: 0, second: 0, of: Date())! }
    private var bucket: Date { cal.startOfDay(for: now) }

    private func raw(_ stage: SleepStage, from startH: Double, to endH: Double,
                     source: String = "Apple Watch", bundle: String = "com.apple.health",
                     device: String? = "Apple Watch", nightsAgo: Int = 0) -> SleepRawSegment {
        let b = cal.date(byAdding: .day, value: -nightsAgo, to: bucket)!
        return SleepRawSegment(sourceName: source, bundleId: bundle, device: device,
                               stage: stage,
                               start: b.addingTimeInterval(startH * 3600),
                               end: b.addingTimeInterval(endH * 3600))
    }
    private func ingested(_ stage: SleepStage, from startH: Double, to endH: Double,
                          source: String = "Apple Watch", nightsAgo: Int = 0) -> SleepReading {
        let b = cal.date(byAdding: .day, value: -nightsAgo, to: bucket)!
        return SleepReading(date: b, stage: stage, hours: endH - startH,
                            start: b.addingTimeInterval(startH * 3600),
                            source: source, tier: .estimate, provenance: .real)
    }

    /// The incident fixture: watch-staged night + iPhone in-bed and overlapping
    /// span + an afternoon nap. Raw and ingested views of the same night.
    private func fixture() -> SleepDiagnostics.Input {
        let rawSegs = [
            raw(.inBed, from: -1.5, to: 7.5, source: "CNs iPhone",
                bundle: "com.apple.health.stub", device: "iPhone"),
            raw(.asleepUnspecified, from: -1.25, to: 7.0, source: "CNs iPhone",
                bundle: "com.apple.health.stub", device: "iPhone"),
            raw(.core, from: -1.0, to: 1.0), raw(.deep, from: 1.0, to: 2.2),
            raw(.core, from: 2.2, to: 4.9), raw(.rem, from: 4.9, to: 6.5),
            raw(.asleepUnspecified, from: 14.5, to: 15.0),
        ]
        var s = HealthSamples()
        s.sleep = [
            ingested(.asleepUnspecified, from: -1.25, to: 7.0, source: "CNs iPhone"),
            ingested(.core, from: -1.0, to: 1.0), ingested(.deep, from: 1.0, to: 2.2),
            ingested(.core, from: 2.2, to: 4.9), ingested(.rem, from: 4.9, to: 6.5),
            ingested(.asleepUnspecified, from: 14.5, to: 15.0),
        ]
        return .init(raw: rawSegs, samples: s, providerIsHealthKit: true,
                     appVersion: "Version 1.0 (10.104)", now: now, calendar: cal)
    }

    @Test func rawSamplesAppearWithFullSourceIdentity() {
        let text = SleepDiagnostics.report(fixture())
        #expect(text.contains("Apple Watch [com.apple.health]"))
        #expect(text.contains("CNs iPhone [com.apple.health.stub] · iPhone"))
        #expect(text.contains("23:00–01:00"))          // the watch's first core block
        #expect(text.contains("DEEP"))
        #expect(text.contains("IN BED"))
    }

    @Test func ingestionDropsAreMarkedNotHidden() {
        let text = SleepDiagnostics.report(fixture())
        #expect(text.contains("dropped at ingestion (in-bed, no stage)"))
    }

    @Test func derivedNightNamesItsChosenSourceAndExclusions() {
        let text = SleepDiagnostics.report(fixture())
        #expect(text.contains("Derived: asleep 7h 30m"))          // the fixed figure
        #expect(text.contains("source used: Apple Watch"))
        #expect(text.contains("Excluded — another source recorded the same night"))
        #expect(text.contains("Excluded — separate sleep episode in the same day bucket"))
        #expect(text.contains("Fell asleep: 23:00"))
    }

    @Test func headlineFiguresMatchTheDeriver() throws {
        let input = fixture()
        let text = SleepDiagnostics.report(input)
        let d = try #require(SleepDetailDeriver.derive(from: input.samples.arbitrated(calendar: cal),
                                                       now: now))
        #expect(d.asleepMin == 450)
        #expect(text.contains("Last night: asleep 7h 30m"))
        #expect(text.contains("Source line shown: Apple Watch"))
        #expect(text.contains(input.appVersion))
    }

    @Test func windowIsFourteenNightsAndNothingOlder() {
        var input = fixture()
        let old = raw(.asleepUnspecified, from: 0, to: 7, source: "Ancient",
                      bundle: "com.old", nightsAgo: 20)
        input = .init(raw: input.raw + [old], samples: input.samples,
                      providerIsHealthKit: true, appVersion: input.appVersion,
                      now: now, calendar: cal)
        let text = SleepDiagnostics.report(input)
        #expect(!text.contains("Ancient"))
        #expect(text.contains("last 14 nights"))
    }

    @Test func demoProviderIsSaidOutLoud() {
        let input = SleepDiagnostics.Input(raw: [], samples: .empty,
                                           providerIsHealthKit: false,
                                           appVersion: "Version 1.0", now: now, calendar: cal)
        let text = SleepDiagnostics.report(input)
        #expect(text.contains("demo/sample data provider"))
        #expect(text.contains("No sleep derived in the window"))
    }

    @Test func reportCarriesSleepTimingOnlyAndNoDataFieldLeaks() {
        let text = SleepDiagnostics.report(fixture())
        // provenance{REAL,SIMULATED,EXTERNAL} is a data field and never renders
        // — not on screens, and not in this export either.
        #expect(!text.lowercased().contains("provenance"))
        #expect(!text.contains("SIMULATED") && !text.contains("EXTERNAL"))
        // No tier vocabulary, no other metric names.
        for word in ["clinical", "estimate", "glucose", "mmol", "heart", "HRV", "steps"] {
            #expect(!text.lowercased().contains(word.lowercased()), "leaked: \(word)")
        }
        // The no-egress promise is stated to the citizen.
        #expect(text.contains("leaves the phone only if you share it"))
    }

    // Structural: the diagnostics path has no transport construct — the report
    // leaves the device through the share sheet ONLY (same posture as the
    // donation export, T-DON-02's pattern).
    @Test func diagnosticsPathHasNoEgressConstruct() {
        let files = SourceLint.swiftFiles(in: "Liviqa/Diagnostics")
        #expect(!files.isEmpty, "Liviqa/Diagnostics missing — lint lost its target")
        let forbidden = "URLSession|URLRequest|httpMethod|httpBody|dataTask|uploadTask|NWConnection|CFStream|https?://"
        for f in files {
            let hits = SourceLint.matches(forbidden, in: f.source)
            #expect(hits.isEmpty, "egress construct in \(f.path): \(hits.map(\.line))")
        }
    }
}
