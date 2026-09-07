import Testing
import Foundation
@testable import Maude

// FR-SMP-01…05, the structural half — source lint.
//
// Some of what sample mode promises is not observable by running the app,
// because the regression would be the ADDITION of something: a persistence call
// inside the sample path, a preference gating the label, a third door into
// sample mode that nobody reviews. The established pattern here
// (ReleasePostureTests, JournalSeedPostureTests, scripts/guard_provenance.sh)
// is to read the SOURCE and fail the run. These do that.
//
// Every lint asserts its target EXISTS before asserting anything about it — a
// lint that silently stops finding its subject stops guarding anything.
struct SampleModePostureTests {

    private func source(_ path: String) throws -> String { try SourceLint.text(path) }

    // MARK: - The defective preference is gone, and cannot come back

    /// `maudeShowDemoChip` defaulted to FALSE, so a person could switch the
    /// only label off — or never see it. The key must not exist anywhere.
    @Test func theDemoChipPreferenceNoLongerExists() {
        var offenders: [String] = []
        for file in SourceLint.swiftFiles(in: "Maude") {
            if !SourceLint.matches("maudeShowDemoChip", in: file.source).isEmpty {
                offenders.append(file.path)
            }
        }
        #expect(offenders.isEmpty,
                "the retired demo-chip preference is back in: \(offenders.joined(separator: ", "))")
    }

    /// Nothing may gate the label on a stored preference. The banner reads
    /// exactly one condition and holds no `@AppStorage` of its own.
    @Test func theLabelIsNotGatedByAnyPreference() throws {
        let src = try source("Maude/Views/SampleModeBanner.swift")
        #expect(src.contains("SampleModePolicy.labelIsVisible"),
                "the banner no longer consults the policy (lint is stale?)")
        #expect(SourceLint.matches("@AppStorage", in: src).isEmpty,
                "a preference reached the sample-data label")
        #expect(SourceLint.matches("UserDefaults", in: src).isEmpty)
    }

    /// `isDemoData` must no longer mean "no real data" — that meaning is what
    /// let fabricated values render for a brand-new real citizen.
    @Test func isDemoDataNoLongerMeansNoRealData() throws {
        let src = try source("Maude/AppState.swift")
        #expect(SourceLint.matches(#"isDemoData: Bool \{ !usingRealData \}"#, in: src).isEmpty,
                "isDemoData is back to meaning 'no real readings yet'")
        #expect(!SourceLint.matches(#"var isDemoData: Bool \{ isSampleMode \}"#, in: src).isEmpty,
                "the isDemoData alias moved (lint is stale?)")
        #expect(!SourceLint.matches(#"var hasNoRealReadings: Bool"#, in: src).isEmpty)
    }

    // MARK: - Only two doors, both deliberate

    /// `enterSampleMode` may be called from exactly the two surfaces that ask
    /// the citizen, plus its own definition. A third call site — anything that
    /// could enter it on the app's initiative — fails here.
    @Test func thereAreExactlyTwoDoorsIntoSampleMode() {
        var callers: [String] = []
        for file in SourceLint.swiftFiles(in: "Maude") {
            guard !SourceLint.matches(#"enterSampleMode\("#, in: file.source).isEmpty else { continue }
            callers.append(file.path)
        }
        #expect(Set(callers) == ["Maude/SampleMode.swift",                     // the definition
                                 "Maude/Views/Onboarding/OnboardingFlowView.swift",
                                 "Maude/Views/SettingsView.swift"],
                "unexpected way into sample mode: \(callers.joined(separator: ", "))")
    }

    /// Both call sites name the deliberate act they answer, so no caller can
    /// enter sample mode without declaring which door it is.
    @Test func bothDoorsDeclareThemselves() throws {
        let onboarding = try source("Maude/Views/Onboarding/OnboardingFlowView.swift")
        let settings = try source("Maude/Views/SettingsView.swift")
        #expect(onboarding.contains("enterSampleMode(.onboardingChoice)"))
        #expect(settings.contains("enterSampleMode(.settingsChoice)"))
    }

    // MARK: - The sample path touches no store

    /// The synthetic record is a VALUE. If any of these appear in it, sample
    /// data has acquired a way to reach a place real data lives.
    @Test func theSampleDatasetHasNoWayToPersistAnything() throws {
        let src = try source("Maude/Ingestion/SampleDataset.swift")
        #expect(src.contains("public static func samples("), "lint is stale — target moved")
        for forbidden in ["ModelContext", "ModelContainer", "PersistentModel",
                          "JournalStore", "HealthVaultStore", "HealthRecordStore",
                          "EncryptedAnchorStore", "WalletGrant", "WalletEvent",
                          "UserDefaults", "FileManager", "URLSession", "URLRequest",
                          "IngestionCoordinator"] {
            #expect(SourceLint.matches(forbidden, in: src).isEmpty,
                    "SampleDataset gained a path to \(forbidden)")
        }
    }

    /// Same for the state machine — except the one preference that records the
    /// citizen's choice, which is a preference and never data.
    @Test func theSampleModeStateMachineTouchesNoStore() throws {
        let src = try source("Maude/SampleMode.swift")
        #expect(src.contains("func enterSampleMode("), "lint is stale — target moved")
        for forbidden in ["ModelContext", "ModelContainer", "PersistentModel",
                          "JournalStore", "HealthVaultStore", "HealthRecordStore",
                          "EncryptedAnchorStore", "DonationConsentStore",
                          "FileManager", "URLSession", "URLRequest",
                          "IngestionCoordinator", "healthStore"] {
            #expect(SourceLint.matches(forbidden, in: src).isEmpty,
                    "the sample-mode path gained access to \(forbidden)")
        }
        // The only persistence is the flag.
        let defaultsLines = SourceLint.matches("UserDefaults", in: src)
        #expect(defaultsLines.count <= 3,
                "sample mode is writing more to UserDefaults than the flag")
    }

    /// The ingest path is skipped while sample mode is on — the structural
    /// reason a sample value can never reach the on-device store.
    @Test func refreshSkipsTheIngestPathInSampleMode() throws {
        let src = try source("Maude/AppState.swift")
        let body = try #require(SourceLint.body(ofDeclarationContaining: "func refreshFromHealth() async",
                                                in: src),
                                "refreshFromHealth moved — this lint is stale")
        let guardLine = body.components(separatedBy: "\n")
            .first { $0.contains("if isSampleMode {") }
        #expect(guardLine != nil, "refreshFromHealth no longer short-circuits in sample mode")
        // …and the short-circuit comes BEFORE anything that fetches or persists.
        let idxGuard = try #require(body.range(of: "if isSampleMode {")).lowerBound
        for later in ["fetchSamples(", "IngestionCoordinator(", "requestReadAuthorization("] {
            if let r = body.range(of: later) {
                #expect(idxGuard < r.lowerBound,
                        "\(later) can run before the sample-mode short-circuit")
            }
        }
    }

    // MARK: - Fabricated stand-ins are gone from Home

    /// The three canned blocks Home used to draw when it had no signals — a
    /// day score, a momentum strip and a 30-day recovery line, none of them
    /// measured by anyone — must not return.
    @Test func homeNoLongerCarriesHardcodedStandInFigures() throws {
        let src = try source("Maude/Views/TodayView.swift")
        for gone in ["Late dinners are costing you sleep.",
                     "Calmest when dinner's before 20:30.",
                     "Recovery up 4 vs your usual",
                     "val: 42, max: 50",
                     "66, 64, 67, 63, 65, 68, 66, 70"] {
            // Code lines only — this file quotes the removed strings itself,
            // and a lint that matches its own documentation guards nothing.
            #expect(!SourceLint.codeLines(src).contains { $0.line.contains(gone) },
                    "a hardcoded stand-in figure came back: \(gone)")
        }
        // And the remaining seed helper asks the policy, not the cold-start flag.
        #expect(src.contains("SampleModePolicy.mayRenderSampleValues"),
                "TodayView's seed rule no longer goes through the policy")
    }
}
