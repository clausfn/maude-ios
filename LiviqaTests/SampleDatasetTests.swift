import Testing
import Foundation
@testable import Liviqa

// FR-SMP-02 — the sample dataset is SYNTHETIC, deterministic, and shaped like a
// real record without being one.
//
// The point of these tests is not that the numbers are pretty. It is that the
// dataset cannot quietly become something else: not a real person's export
// pasted in, not a stream that names a device that never existed, and not a
// fixture that drifts every launch so a tester cannot tell what they saw.
@MainActor
struct SampleDatasetTests {

    /// A fixed instant so every expectation below is about arithmetic, not about
    /// what time the test happened to run.
    private var anchor: Date {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 17; c.hour = 9
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func fingerprint(_ s: HealthSamples) -> [Double] {
        s.glucose.map(\.mmol) + s.hrv.map(\.value) + s.restingHR.map(\.value)
            + s.steps.map(\.value) + s.sleep.map(\.hours)
            + s.workouts.map(\.durMin) + s.workoutHeartRate.map(\.bpm)
            + s.bodyComposition.compactMap(\.weightKg)
    }

    // MARK: - Deterministic

    @Test func theSampleIsIdenticalOnEveryLaunch() {
        #expect(fingerprint(SampleDataset.samples(now: anchor))
                == fingerprint(SampleDataset.samples(now: anchor)))
    }

    /// …and does not change under a tester's hands as the day goes on: morning
    /// and evening on the same date produce the same record.
    @Test func theSampleIsStableThroughTheDay() {
        let evening = anchor.addingTimeInterval(11 * 3600)
        #expect(fingerprint(SampleDataset.samples(now: anchor))
                == fingerprint(SampleDataset.samples(now: evening)))
    }

    // MARK: - Shaped like a record, without being one

    @Test func itCarriesTheAdvertisedWindowAtSensorCadence() {
        let s = SampleDataset.samples(now: anchor)
        #expect(SampleDataset.days == 60)
        #expect(s.restingHR.count == 60)
        #expect(s.hrv.count == 60)
        #expect(s.steps.count == 60)
        // A 15-minute CGM cadence across every day.
        #expect(s.glucose.count == 60 * 96)
        #expect(!s.sleep.isEmpty)
        #expect(!s.workouts.isEmpty)
        #expect(!s.workoutHeartRate.isEmpty)
        #expect(!s.bodyComposition.isEmpty)
    }

    /// Physiologically plausible, and a long way from anything that could read
    /// as an emergency. A demo must never simulate a crisis.
    @Test func everyValueSitsInAPlausibleBand() {
        let s = SampleDataset.samples(now: anchor)
        for g in s.glucose { #expect(g.mmol >= 3.5 && g.mmol <= 14.0) }
        for m in s.restingHR { #expect(m.value >= 45 && m.value <= 75) }
        for m in s.hrv { #expect(m.value >= 20 && m.value <= 80) }
        for m in s.steps { #expect(m.value >= 2000 && m.value <= 23_000) }
        for hr in s.workoutHeartRate { #expect(hr.bpm >= 80 && hr.bpm <= 185) }
        for b in s.bodyComposition {
            #expect((b.weightKg ?? 0) >= 65 && (b.weightKg ?? 0) <= 85)
        }
        // Nights between 4½ and 9½ hours, counted as a union of real intervals.
        let byNight = Dictionary(grouping: s.sleep, by: \.date)
        for (_, segs) in byNight {
            let hours = SleepReading.mergedAsleepHours(segs, asleep: [.rem, .core, .deep, .asleepUnspecified])
            #expect(hours >= 4.5 && hours <= 9.5)
        }
    }

    /// The dataset has texture — a demo where every day is identical teaches a
    /// tester nothing, and a demo that is pure noise teaches them something
    /// false. Both the spread and the coupling are asserted.
    @Test func itHasRealVariabilityAndTheCouplingItClaims() {
        let s = SampleDataset.samples(now: anchor)
        let hrv = s.hrv.map(\.value)
        let mean = hrv.reduce(0, +) / Double(hrv.count)
        let sd = (hrv.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(hrv.count)).squareRoot()
        #expect(sd > 2, "HRV is too flat to be a plausible record")
        #expect(Set(s.steps.map { Int($0.value) }).count > 40, "step counts repeat suspiciously")
        // A short night is followed by a lower-HRV, higher-glucose morning —
        // the story the sample is built to show.
        let cal = Calendar(identifier: .gregorian)
        let nights = Dictionary(grouping: s.sleep, by: \.date).mapValues {
            SleepReading.mergedAsleepHours($0, asleep: [.rem, .core, .deep, .asleepUnspecified])
        }
        let hrvByDay = Dictionary(uniqueKeysWithValues: s.hrv.map { (cal.startOfDay(for: $0.date), $0.value) })
        var afterShort: [Double] = [], afterLong: [Double] = []
        for (night, hours) in nights {
            guard let v = hrvByDay[cal.startOfDay(for: night)] else { continue }
            if hours < 6.3 { afterShort.append(v) } else if hours > 7.0 { afterLong.append(v) }
        }
        #expect(!afterShort.isEmpty && !afterLong.isEmpty)
        let shortMean = afterShort.reduce(0, +) / Double(afterShort.count)
        let longMean = afterLong.reduce(0, +) / Double(afterLong.count)
        #expect(shortMean < longMean, "a short night should not read as a better morning")
    }

    // MARK: - It cannot be mistaken for a device, or for a clinical claim

    /// Every stream is attributed to a name `MetricSourceLabel` classifies as a
    /// fixture, so no screen can print a fabricated device beside a fabricated
    /// number (T-DED-06).
    @Test func noStreamCanEverPrintAsADeviceName() {
        let s = SampleDataset.samples(now: anchor)
        var names = Set<String>()
        names.formUnion(s.glucose.map(\.source))
        names.formUnion(s.allDaily.map(\.source))
        names.formUnion(s.sleep.map(\.source))
        names.formUnion(s.workouts.map(\.source))
        names.formUnion(s.workoutHeartRate.map(\.source))
        names.formUnion(s.bodyComposition.map(\.source))
        #expect(names == [SampleDataset.sourceName])
        for n in names {
            #expect(MetricSourceLabel.isFixture(n), "sample stream would print as a device: \(n)")
            #expect(MetricSourceLabel.inProse(n) == nil)
        }
    }

    /// The sample deliberately says nothing on the surfaces where an invented
    /// value would look most like a clinical fact about the reader.
    @Test func theSampleNeverSimulatesAClinicalEvent() {
        let s = SampleDataset.samples(now: anchor)
        #expect(s.afib.isEmpty, "the sample must never simulate a rhythm finding (D9)")
        #expect(s.bloodPressure.isEmpty)
        #expect(s.insulin.isEmpty, "the sample must never simulate a dose (FR-REG-04)")
    }

    // MARK: - What the citizen actually reads

    /// FR-NDG-06 is a designated control. Sample mode shows engine output, not
    /// hand-written copy, so every sentence it can produce has been through
    /// `NudgeGuard` — asserted here directly over the sample's own nudges.
    @Test func everySentenceTheSampleProducesPassesTheNudgeGuard() {
        let derived = AppState.deriveSample(now: anchor)
        #expect(!derived.engineNudges.isEmpty, "the sample produced no insight at all")
        for n in derived.engineNudges {
            #expect(NudgeGuard.violation(in: n) == nil,
                    "sample nudge violates FR-NDG-06: \(n.body)")
        }
    }

    /// The whole point of sample mode: the screens have something to show.
    @Test func theSampleFillsTheSurfacesItIsMeantToDemonstrate() {
        let d = AppState.deriveSample(now: anchor)
        #expect(d.signals != nil)
        #expect(d.glucose != nil)
        #expect(d.sleep != nil)
        #expect(d.trends != nil)
        #expect(d.baselines != nil)
        #expect(d.hrvLearn != nil)
        #expect(d.passport.daysTracked > 0)
    }
}
