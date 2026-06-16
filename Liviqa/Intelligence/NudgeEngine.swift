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

public nonisolated struct NudgeEngine: Sendable {
    public init() {}

    public func generate(samples: HealthSamples,
                         signals: ClinicalSignals = .init(),
                         now: Date = Date(),
                         cap: Int = 4) -> [EngineNudge] {
        var candidates: [EngineNudge] = []

        candidates += afibNudge(signals)            // displayOnly, top priority
        candidates += glucoseNudge(samples)         // watch
        candidates += workoutGlucoseNudge(samples)  // watch (§6.2 lead example)
        candidates += recoveryNudge(samples)        // wellness (HRV)
        candidates += sleepNudge(samples)           // wellness
        candidates += activityNudge(samples)        // wellness
        candidates += restingHRNumber(samples)      // watch (number echo)

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
    private func afibNudge(_ s: ClinicalSignals) -> [EngineNudge] {
        guard s.afibSignalPresent else { return [] }
        return [EngineNudge(
            category: .routeToClinician, lane: .displayOnly,
            title: String(localized: "Irregular heart-rhythm signal"),
            body: String(localized: "Your device recorded an irregular heart-rhythm signal. Liviqa does not interpret heart rhythm — please share this recording with \(Specialty.cardiologist.phrase)."),
            priority: 100)]
    }

    /// Glucose (watch): today's mean vs the personal baseline of prior days.
    /// Band-status only — no targets, no dosing.
    private func glucoseNudge(_ s: HealthSamples) -> [EngineNudge] {
        let cal = Calendar(identifier: .gregorian)
        let byDay = Dictionary(grouping: s.glucose) { cal.startOfDay(for: $0.ts) }
        guard let today = byDay.keys.max(), byDay.count >= 4 else { return [] }
        let priorMeans = byDay.filter { $0.key < today }.map { mean($0.value.map(\.mmol)) }
        guard let base = Baseline.from(priorMeans) else { return [] }
        let todayMean = mean(byDay[today]!.map(\.mmol))

        switch base.band(for: todayMean) {
        case .inBand:
            return [EngineNudge(category: .bandStatus, lane: .watch,
                          title: String(localized: "Glucose steady"),
                          body: String(localized: "Your glucose today is sitting in your usual range."),
                          priority: 55)]
        case .above:
            return [EngineNudge(category: .bandStatus, lane: .watch,
                          title: String(localized: "Glucose above your usual"),
                          body: String(localized: "Your glucose today is running above your usual range. A short walk after meals helps many people. If this keeps up, it's worth raising with \(Specialty.gp.phrase)."),
                          priority: 75)]
        case .below:
            return [EngineNudge(category: .bandStatus, lane: .watch,
                          title: String(localized: "Glucose below your usual"),
                          body: String(localized: "Your glucose today is running below your usual range."),
                          priority: 75)]
        }
    }

    /// Workout↔glucose coupling (§6.2 lead example — the cycling-glucose nudge):
    /// does the latest session of a given type drop glucose materially more than
    /// the user's OWN recent sessions of that type at similar effort? This is a
    /// within-user correlation only — no targets, no advice, no dosing.
    private func workoutGlucoseNudge(_ s: HealthSamples) -> [EngineNudge] {
        guard !s.workouts.isEmpty, s.glucose.count >= 4 else { return [] }

        struct Drop { let type: String; let start: Date; let drop: Double }
        let drops: [Drop] = s.workouts.compactMap { w in
            guard let d = glucoseDrop(for: w, glucose: s.glucose) else { return nil }
            return Drop(type: w.type.trimmingCharacters(in: .whitespaces), start: w.start, drop: d)
        }
        guard let latest = drops.max(by: { $0.start < $1.start }) else { return [] }

        // Baseline from the user's PRIOR same-type sessions only.
        let priorSameType = drops
            .filter { $0.type.caseInsensitiveCompare(latest.type) == .orderedSame && $0.start < latest.start }
            .map(\.drop)
        guard let base = Baseline.from(priorSameType), base.mean > 0.3 else { return [] }
        // Fire only when the latest drop is materially steeper than usual.
        guard base.band(for: latest.drop) == .above else { return [] }
        let pct = Int((((latest.drop - base.mean) / base.mean) * 100).rounded())
        guard pct >= 15 else { return [] }

        let label = String(localized: String.LocalizationValue(latest.type.lowercased()))
        let pctStr = "\(pct)%"
        return [EngineNudge(
            category: .bandStatus, lane: .watch,
            title: String(localized: "Glucose after your \(label)"),
            body: String(localized: "Your glucose fell about \(pctStr) more than usual after your latest \(label) session, compared with your recent \(label) sessions at similar effort. Worth a note in your journal."),
            priority: 70)]
    }

    /// Glucose change around one workout: mean of the hour before start minus
    /// mean of the two hours after end (positive ⇒ glucose fell). nil when there
    /// isn't a reading on both sides.
    private func glucoseDrop(for w: WorkoutReading, glucose: [GlucoseReading]) -> Double? {
        let pre = glucose
            .filter { $0.ts >= w.start.addingTimeInterval(-3600) && $0.ts <= w.start }
            .map(\.mmol)
        let post = glucose
            .filter { $0.ts >= w.end && $0.ts <= w.end.addingTimeInterval(7200) }
            .map(\.mmol)
        guard !pre.isEmpty, !post.isEmpty else { return nil }
        return mean(pre) - mean(post)
    }

    /// Recovery (wellness): HRV-SDNN latest vs baseline of earlier days.
    private func recoveryNudge(_ s: HealthSamples) -> [EngineNudge] {
        guard let (latest, base) = latestVsBaseline(s.hrv.sorted { $0.date < $1.date }.map(\.value))
        else { return [] }
        switch base.band(for: latest) {
        case .below:
            return [EngineNudge(category: .behaviouralLever, lane: .wellness,
                          title: String(localized: "Recovery looks low"),
                          body: String(localized: "Your heart-rate variability is below your usual. \(Lever.windDown.phrase)"),
                          priority: 60)]
        case .above:
            return [EngineNudge(category: .verdict, lane: .wellness,
                          title: String(localized: "Recovery looking strong"),
                          body: String(localized: "Your recovery signals are \(Verdict.onTrack.phrase)."),
                          priority: 35)]
        case .inBand:
            return []
        }
    }

    /// Sleep (wellness): last night vs baseline.
    private func sleepNudge(_ s: HealthSamples) -> [EngineNudge] {
        let nightly = s.sleep.sorted { $0.date < $1.date }.map(\.hours)
        guard let (latest, base) = latestVsBaseline(nightly) else { return [] }
        if base.band(for: latest) == .below {
            return [EngineNudge(category: .behaviouralLever, lane: .wellness,
                          title: String(localized: "Short night"),
                          body: String(localized: "Last night was shorter than your usual. \(Lever.earlierNight.phrase)"),
                          priority: 45)]
        }
        return []
    }

    /// Activity (wellness): latest steps vs baseline.
    private func activityNudge(_ s: HealthSamples) -> [EngineNudge] {
        let steps = s.steps.sorted { $0.date < $1.date }.map(\.value)
        guard let (latest, base) = latestVsBaseline(steps) else { return [] }
        if base.band(for: latest) == .below {
            return [EngineNudge(category: .behaviouralLever, lane: .wellness,
                          title: String(localized: "Quieter day for movement"),
                          body: String(localized: "You're moving less than your usual today. \(Lever.move.phrase)"),
                          priority: 30)]
        }
        return []
    }

    /// Resting HR (watch): a plain number echo — never a target.
    private func restingHRNumber(_ s: HealthSamples) -> [EngineNudge] {
        guard let latest = s.restingHR.sorted(by: { $0.date < $1.date }).last else { return [] }
        let bpm = Int(latest.value.rounded())
        return [EngineNudge(category: .number, lane: .watch,
                      title: String(localized: "Resting heart rate"),
                      body: String(localized: "Your most recent resting heart rate is \(bpm) bpm."),
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
