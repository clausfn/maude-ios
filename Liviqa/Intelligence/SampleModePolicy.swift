// SampleModePolicy.swift — the two rules that keep sample data from ever being
// mistaken for a citizen's own (FR-SMP-01 / FR-SMP-03). Pure Foundation.
//
// WHY THIS FILE EXISTS
// ────────────────────
// Until 2026-08-14 the app had ONE flag, `AppState.isDemoData`, defined as
// `!usingRealData` — "we have no real readings yet". Dozens of screens used it
// to decide whether to draw a fabricated stand-in value. Those are two
// different questions, and conflating them is what let invented numbers render
// for a brand-new REAL user (the class of defect behind the 2026-08-13
// incident, qms/CHANGELOG.md PR-111):
//
//     "there is nothing of yours to show yet"   → an honest empty / calibrating state
//     "the citizen asked to see a sample"       → sample values, labelled, everywhere
//
// The first NEVER authorises the second. That single sentence is the whole
// policy, and `mayRenderSampleValues` is where it is enforced and tested — a
// pure function so the rule can be proven without a device, a store, or a view.
import Foundation

public nonisolated enum SampleModePolicy {

    /// May a screen draw a fabricated stand-in value right now?
    ///
    /// ONLY when the citizen deliberately turned sample mode on. Having no real
    /// readings is not a licence to invent them — that path shows the honest
    /// empty/calibrating state instead. `hasRealReadings` is taken as a
    /// parameter precisely so the test can hold it at `false` and prove it
    /// changes nothing.
    public static func mayRenderSampleValues(sampleModeOn: Bool,
                                             hasRealReadings: Bool) -> Bool {
        sampleModeOn
    }

    /// Must the "sample data" labelling be on screen right now?
    ///
    /// Exactly whenever sample mode is on — and `userPreference` is accepted
    /// and ignored on purpose. A display preference used to gate this
    /// (`liviqaShowDemoChip`, default FALSE), which is how unlabelled seeds
    /// reached testers. There is no preference, no dismissal and no timeout
    /// that can take the label off while sample values are on screen.
    public static func labelIsVisible(sampleModeOn: Bool,
                                      userPreference: Bool = false) -> Bool {
        sampleModeOn
    }

    /// Sample mode is only ever entered by an explicit act of the citizen.
    /// There is no state of the world — no empty fetch, no failed read, no
    /// first launch, no missing permission — that turns it on.
    public enum Entry: String, Sendable, CaseIterable {
        /// The onboarding Apple Health step: "Explore with sample data".
        case onboardingChoice
        /// Settings → My data → Sample data.
        case settingsChoice
    }

    /// True only for the deliberate entries above. Kept as an enumeration so a
    /// future "just this once, because the app looked empty" branch has to add
    /// a case here — and fail `entryIsAlwaysDeliberate`.
    public static func mayEnter(_ entry: Entry) -> Bool {
        switch entry {
        case .onboardingChoice, .settingsChoice: return true
        }
    }
}
