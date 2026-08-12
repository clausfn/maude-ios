// DayReplayDeriver.swift — the "Replay your day" (scrub-your-day) derivation:
// today's timestamped glucose curve plus the cross-signal figures the "At HH:MM"
// moment card narrates (peak, back-in-range time, a real workout near the peak).
//
// HONESTY RULE: the canvas's canned sentence ("Steps were low — you were
// sitting. Heart rate 78 bpm.") is NOT reproducible from the read model — steps
// and heart rate are ingested at DAILY granularity, so an at-timestamp claim
// would be fabricated. This deriver only emits what the samples actually carry:
// timestamped glucose (mmol/L, OD-07) and timestamped workouts. The view builds
// its narration from fixed templates over these figures — omitted, never faked.
// Pure Foundation — no SwiftData / SwiftUI / HealthKit (NFR-PORT-01).
import Foundation

public nonisolated struct DayReplay: Sendable, Equatable {

    public struct Point: Sendable, Equatable {
        public let hour: Double        // 0…24, fraction of the day
        public let mmol: Double
        public let timeText: String    // "13:40" (24h)
        public init(hour: Double, mmol: Double, timeText: String) {
            self.hour = hour; self.mmol = mmol; self.timeText = timeText
        }
    }

    /// Today's readings in time order (always ≥2 — fewer derives nil).
    public let points: [Point]
    /// The personal target band the day is read against (mmol/L).
    public let bandLo: Double
    public let bandHi: Double
    /// Index of the day's highest reading, only when it sits ABOVE the band —
    /// the design's dashed marker. nil ⇒ a steady day, no marker.
    public let peakIndex: Int?
    /// "Back in range by HH:MM" — first in-band reading after the LAST
    /// above-band run. nil when there was no run, or it hasn't come back yet.
    public let backInRangeText: String?
    /// Number of separate above-band runs in today's readings.
    public let aboveRuns: Int
    /// Fixed-template note about a REAL tracked workout that ended within the
    /// 2 hours before the peak (nil when none, or no peak).
    public let workoutNote: String?

    public init(points: [Point], bandLo: Double, bandHi: Double, peakIndex: Int?,
                backInRangeText: String?, aboveRuns: Int, workoutNote: String?) {
        self.points = points; self.bandLo = bandLo; self.bandHi = bandHi
        self.peakIndex = peakIndex; self.backInRangeText = backInRangeText
        self.aboveRuns = aboveRuns; self.workoutNote = workoutNote
    }
}

public nonisolated enum DayReplayDeriver {

    private static let cal = Calendar(identifier: .gregorian)

    /// nil ⇒ fewer than 2 glucose readings today → the screen keeps its honest
    /// empty state (never a fabricated curve).
    public static func derive(from s: HealthSamples,
                              now: Date = Date(),
                              tirLowMmol: Double = 3.9,
                              tirHighMmol: Double = 10.0) -> DayReplay? {
        let startOfDay = cal.startOfDay(for: now)
        let lo = min(tirLowMmol, tirHighMmol), hi = max(tirLowMmol, tirHighMmol)

        let todays = s.glucose
            .filter { cal.isDate($0.ts, inSameDayAs: startOfDay) }
            .sorted { $0.ts < $1.ts }
        guard todays.count >= 2 else { return nil }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_DK")
        fmt.dateFormat = "HH:mm"

        let points = todays.map { g in
            DayReplay.Point(hour: g.ts.timeIntervalSince(startOfDay) / 3600,
                            mmol: g.mmol,
                            timeText: fmt.string(from: g.ts))
        }

        // Above-band runs + the peak (only meaningful when it exceeds the band).
        var runs = 0
        var inRun = false
        for p in points {
            if p.mmol > hi {
                if !inRun { runs += 1; inRun = true }
            } else {
                inRun = false
            }
        }
        var peakIndex: Int? = nil
        if let maxIdx = points.indices.max(by: { points[$0].mmol < points[$1].mmol }),
           points[maxIdx].mmol > hi {
            peakIndex = maxIdx
        }

        // "Back in range by …" — after the LAST above-band reading.
        var backText: String? = nil
        if runs > 0, let lastAbove = points.lastIndex(where: { $0.mmol > hi }) {
            if let back = points[(lastAbove + 1)...].first(where: { $0.mmol >= lo && $0.mmol <= hi }) {
                backText = back.timeText
            }
        }

        // A real workout that ended within the 2 h before the peak (fixed template).
        var workoutNote: String? = nil
        if let pi = peakIndex {
            let peakTs = startOfDay.addingTimeInterval(points[pi].hour * 3600)
            if let w = s.workouts.first(where: {
                $0.end <= peakTs && peakTs.timeIntervalSince($0.end) <= 2 * 3600
            }) {
                let mins = Int(w.durMin.rounded())
                let type = w.type.lowercased()
                workoutNote = String(localized: "Earlier: a \(mins)-min \(type) ended at \(fmt.string(from: w.end)).")
            }
        }

        return DayReplay(points: points, bandLo: lo, bandHi: hi,
                         peakIndex: peakIndex, backInRangeText: backText,
                         aboveRuns: runs, workoutNote: workoutNote)
    }

    #if DEBUG
    /// Lab-only (LiviqaApp's day lab): spread injected raw values across today's
    /// elapsed hours and run the REAL derivation over them. Marked SIMULATED at
    /// the data layer; never available in Release.
    public static func debugReplay(fromInjected values: [Double]) -> DayReplay? {
        guard values.count > 1 else { return nil }
        let start = Calendar(identifier: .gregorian).startOfDay(for: Date())
        let span = min(24.0, max(1.0, Date().timeIntervalSince(start) / 3600))
        var s = HealthSamples()
        for (i, v) in values.enumerated() {
            let h = Double(i) / Double(values.count - 1) * span
            s.glucose.append(GlucoseReading(ts: start.addingTimeInterval(h * 3600),
                                            mmol: v, source: "lab",
                                            tier: .estimate, provenance: .simulated))
        }
        return derive(from: s)
    }
    #endif
}
