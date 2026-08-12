// NudgeRun.swift — the ONE on-device path from health samples to the nudge feed.
//
// Why this file exists: FR-NOT-02's earned-attention micro-loop runs while the
// app is in the background (BGAppRefreshTask). It must decide from the SAME
// engine the foreground uses — a second, drifting copy of "how Liviqa reads your
// numbers" would be exactly the opacity the product exists to answer. So both
// callers go through here and nowhere else:
//
//   • foreground — `AppState.refreshFromHealth()` arbitrates once (it needs the
//     samples for its other sixteen derivers) and calls `nudges(from:context:)`.
//   • background — `BackgroundRefresh` has no AppState, so it calls `run(...)`,
//     which performs the identical read → arbitrate → engine sequence.
//
// There is no analysis in this file. It is a seam, deliberately thin, so that
// "the background loop uses the same engine" is provable by reading it.
//
// FR-CTX-04 note: `context` is carried through unchanged — it is a SUPPRESSION
// gate inside NudgeEngine and nothing here can add to, re-rank, or rewrite what
// the engine returns.
//
// Pure Foundation (Android-portable).
import Foundation

enum NudgeRun {

    /// Run the on-device engine over already-arbitrated samples.
    /// The single call site of `NudgeEngine.generate` in the app.
    ///
    /// `nonisolated` because both callers run it OFF the main actor —
    /// AppState's detached deriver chain (FB-AJR9AqEk) and the background
    /// earned-attention loop. `NudgeEngine` is itself a `nonisolated` Sendable
    /// value type, so this states the isolation that was already true at
    /// runtime (and clears the Swift-6 warning at the AppState call site).
    nonisolated static func nudges(from samples: HealthSamples,
                                   context: [ContextWindow],
                                   now: Date = Date()) -> [EngineNudge] {
        NudgeEngine().generate(samples: samples, context: context, now: now)
    }

    /// Full on-device run: read → arbitrate (§2.3) → engine. Used by the
    /// background micro-loop, which has no already-fetched samples to reuse.
    /// Returns the arbitrated samples too, so the caller can tell "no data on
    /// this phone" apart from "the engine found nothing worth saying".
    static func run(provider: any HealthDataProvider,
                    from start: Date,
                    to end: Date,
                    context: [ContextWindow],
                    now: Date = Date()) async throws -> (samples: HealthSamples, nudges: [EngineNudge]) {
        try await provider.requestReadAuthorization()
        let samples = try await provider.fetchSamples(from: start, to: end).arbitrated()
        return (samples, nudges(from: samples, context: context, now: now))
    }
}
