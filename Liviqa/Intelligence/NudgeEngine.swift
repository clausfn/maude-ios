// NudgeEngine.swift — L3 on-device heuristic nudge engine (portable).
//
// Heuristic, personal-baseline-relative, on-device. Emits at most `cap` nudges
// ("4 nudges, not 48 charts"). Output is the strict allow-list (NudgeCategory)
// and is run through `NudgeGuard` (FR-NDG-06) before release — any nudge that
// would contain a forbidden construction is dropped (and trapped in debug, since
// the engine should never author one). AFib is display-only (D9): the only
// cardiac output is route-to-clinician, never an interpretation.
// Pure Foundation — no SwiftData/HealthKit/SwiftUI. Android-portable.
import Foundation

public struct NudgeEngine: Sendable {
    public init() {}

    public func generate(samples: HealthSamples,
                         signals: ClinicalSignals = .init(),
                         now: Date = Date(),
                         cap: Int = 4) -> [Nudge] {
        var candidates: [Nudge] = []

        candidates += afibNudge(signals)          // displayOnly, top priority
        candidates += glucoseNudge(samples)        // watch
        candidates += recoveryNudge(samples)       // wellness (HRV)
        candidates += sleepNudge(samples)          // wellness
        candidates += activityNudge(samples)       // wellness
        candidates += restingHRNumber(samples)     // watch (number echo)

        // FR-NDG-06: nothing forbidden ever ships. Drop (and trap) violators.
        let safe = candidates.filter { nudge in
            if let bad = NudgeGuard.violation(in: nudge) {
                assertionFailure("NudgeEngine authored forbidden construction \(bad): \(nudge.body)")
                return false
            }
            return true
        }

        // Cap: highest-priority first; cardiac display-only always survives.
        return Array(safe.sorted { $0.priority > $1.priority }.prefix(max(0, cap)))
    }

    // MARK: streams

    /// D9 display-only: render the signal + route to cardiologist. No verdict,
    /// no band, no interpretation.
    private func afibNudge(_ s: ClinicalSignals) -> [Nudge] {
        guard s.afibSignalPresent else { return [] }
        return [Nudge(
            category: .routeToClinician, lane: .displayOnly,
            title: "Irregular heart-rhythm signal",
            body: "Your device recorded an irregular heart-rhythm signal. "
                + "Liviqa does not interpret heart rhythm — please share this "
                + "recording with \(Specialty.cardiologist.phrase).",
            priority: 100)]
    }

    /// Glucose (watch): today's mean vs the personal baseline of prior days.
    /// Band-status only — no targets, no dosing.
    private func glucoseNudge(_ s: HealthSamples) -> [Nudge] {
        let cal = Calendar(identifier: .gregorian)
        let byDay = Dictionary(grouping: s.glucose) { cal.startOfDay(for: $0.ts) }
        guard let today = byDay.keys.max(), byDay.count >= 4 else { return [] }
        let priorMeans = byDay.filter { $0.key < today }.map { mean($0.value.map(\.mmol)) }
        guard let base = Baseline.from(priorMeans) else { return [] }
        let todayMean = mean(byDay[today]!.map(\.mmol))

        switch base.band(for: todayMean) {
        case .inBand:
            return [Nudge(category: .bandStatus, lane: .watch,
                          title: "Glucose steady",
                          body: "Your glucose today is sitting in your usual range.",
                          priority: 55)]
        case .above:
            return [Nudge(category: .bandStatus, lane: .watch,
                          title: "Glucose above your usual",
                          body: "Your glucose today is running above your usual range. "
                              + "A short walk after meals helps many people. "
                              + "If this keeps up, it's worth raising with \(Specialty.gp.phrase).",
                          priority: 75)]
        case .below:
            return [Nudge(category: .bandStatus, lane: .watch,
                          title: "Glucose below your usual",
                          body: "Your glucose today is running below your usual range.",
                          priority: 75)]
        }
    }

    /// Recovery (wellness): HRV-SDNN latest vs baseline of earlier days.
    private func recoveryNudge(_ s: HealthSamples) -> [Nudge] {
        guard let (latest, base) = latestVsBaseline(s.hrv.sorted { $0.date < $1.date }.map(\.value))
        else { return [] }
        switch base.band(for: latest) {
        case .below:
            return [Nudge(category: .behaviouralLever, lane: .wellness,
                          title: "Recovery looks low",
                          body: "Your heart-rate variability is below your usual. \(Lever.windDown.phrase)",
                          priority: 60)]
        case .above:
            return [Nudge(category: .verdict, lane: .wellness,
                          title: "Recovery looking strong",
                          body: "Your recovery signals are \(Verdict.onTrack.phrase).",
                          priority: 35)]
        case .inBand:
            return []
        }
    }

    /// Sleep (wellness): last night vs baseline.
    private func sleepNudge(_ s: HealthSamples) -> [Nudge] {
        let nightly = s.sleep.sorted { $0.date < $1.date }.map(\.hours)
        guard let (latest, base) = latestVsBaseline(nightly) else { return [] }
        if base.band(for: latest) == .below {
            return [Nudge(category: .behaviouralLever, lane: .wellness,
                          title: "Short night",
                          body: "Last night was shorter than your usual. \(Lever.earlierNight.phrase)",
                          priority: 45)]
        }
        return []
    }

    /// Activity (wellness): latest steps vs baseline.
    private func activityNudge(_ s: HealthSamples) -> [Nudge] {
        let steps = s.steps.sorted { $0.date < $1.date }.map(\.value)
        guard let (latest, base) = latestVsBaseline(steps) else { return [] }
        if base.band(for: latest) == .below {
            return [Nudge(category: .behaviouralLever, lane: .wellness,
                          title: "Quieter day for movement",
                          body: "You're moving less than your usual today. \(Lever.move.phrase)",
                          priority: 30)]
        }
        return []
    }

    /// Resting HR (watch): a plain number echo — never a target.
    private func restingHRNumber(_ s: HealthSamples) -> [Nudge] {
        guard let latest = s.restingHR.sorted(by: { $0.date < $1.date }).last else { return [] }
        let bpm = Int(latest.value.rounded())
        return [Nudge(category: .number, lane: .watch,
                      title: "Resting heart rate",
                      body: "Your most recent resting heart rate is \(bpm) bpm.",
                      priority: 20)]
    }

    // MARK: helpers

    private func mean(_ xs: [Double]) -> Double {
        xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
    }

    /// Split a chronologically-sorted series into (latest, baseline-of-rest).
    private func latestVsBaseline(_ series: [Double]) -> (Double, Baseline)? {
        guard series.count >= 4, let latest = series.last,
              let base = Baseline.from(Array(series.dropLast())) else { return nil }
        return (latest, base)
    }
}
