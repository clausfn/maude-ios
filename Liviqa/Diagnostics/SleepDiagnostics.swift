// SleepDiagnostics.swift — FR-DIAG-01, sleep incident 2026-08.
//
// The on-device instrument for a field defect we cannot reproduce: the citizen
// generates a human-readable report of the last 14 nights — every RAW HealthKit
// sleep sample (source bundle id + device, stage, start, end) laid against
// every DERIVED value (per-night totals, stage minutes, bedtime, the week
// series) and, per night, exactly WHICH samples the total was computed from and
// which were excluded, with the reason. The discrepancy between what Apple
// Health shows and what Liviqa said becomes inspectable from one text file.
//
// SCOPE, deliberately narrow: sleep TIMING only. No glucose, no heart, no
// other type is read or mentioned. The report is handed to the share sheet by
// the citizen — there is no upload path (the app has none), no network here.
// Ships in DEBUG and Release: the field report came from a TestFlight build.
//
// Pure Foundation — no SwiftUI, no HealthKit — so every line of the report is
// unit-testable from fixtures (no live stores, T-DIAG-01).
import Foundation

/// One raw HealthKit `sleepAnalysis` sample, as stored — including what
/// ingestion drops (in-bed, zero-length), so the drop itself is visible.
public struct SleepRawSegment: Sendable {
    public let sourceName: String
    public let bundleId: String
    public let device: String?
    public let stage: SleepStage
    public let start: Date
    public let end: Date
    public init(sourceName: String, bundleId: String, device: String?,
                stage: SleepStage, start: Date, end: Date) {
        self.sourceName = sourceName; self.bundleId = bundleId; self.device = device
        self.stage = stage; self.start = start; self.end = end
    }
    public var hours: Double { end.timeIntervalSince(start) / 3600 }
    /// Mirrors `HealthKitService.readSleep`: in-bed and empty spans never enter
    /// the derivation stream.
    public var droppedAtIngestion: Bool { stage == .inBed || end <= start }
}

public enum SleepDiagnostics {

    public static let nightsInWindow = 14

    /// Everything the report is built from. `samples` is the provider's fetch
    /// BEFORE arbitration — the builder replays the real pipeline itself so the
    /// report shows both what arrived and what the app derived from it.
    public struct Input {
        public let raw: [SleepRawSegment]
        public let samples: HealthSamples
        public let providerIsHealthKit: Bool
        public let appVersion: String
        public let now: Date
        public let calendar: Calendar
        public init(raw: [SleepRawSegment], samples: HealthSamples,
                    providerIsHealthKit: Bool, appVersion: String,
                    now: Date, calendar: Calendar = .current) {
            self.raw = raw; self.samples = samples
            self.providerIsHealthKit = providerIsHealthKit
            self.appVersion = appVersion; self.now = now; self.calendar = calendar
        }
    }

    // MARK: — Report

    public static func report(_ input: Input) -> String {
        let cal = input.calendar
        var out: [String] = []

        // Header — what this file is and is not.
        out.append("LIVIQA SLEEP DIAGNOSTICS")
        out.append("Generated \(stamp(input.now, cal)) · \(input.appVersion)")
        out.append("Window: the last \(nightsInWindow) nights. Contains sleep timing only —")
        out.append("sources, stages, start/end times and Liviqa's derived sleep figures.")
        out.append("No other health data. This file leaves the phone only if you share it.")
        if !input.providerIsHealthKit {
            out.append("")
            out.append("NOTE: this report was generated against a demo/sample data provider,")
            out.append("not Apple Health — the raw-sample section below is empty.")
        }
        out.append(String(repeating: "=", count: 72))

        // The derivation pipeline, replayed exactly as the app runs it.
        let arbitrated = input.samples.arbitrated(calendar: cal)
        let detail = SleepDetailDeriver.derive(from: arbitrated, now: input.now)

        // — Section 1: what the app shows —
        out.append("")
        out.append("WHAT THE APP DERIVED (the figures on screen)")
        if let d = detail {
            let stages = "deep \(mins(d.deepMin)) · light \(mins(d.coreMin)) · REM \(mins(d.remMin))"
                + (d.awakeMin > 0 ? " · awake \(mins(d.awakeMin))" : "")
            out.append("Last night: asleep \(mins(d.asleepMin)) (\(stages))")
            if let shape = d.shape {
                out.append("Night drawn: \(shape.startClock)–\(shape.endClock)")
            } else {
                out.append("Night drawn: none (no intra-night times from the source)")
            }
            let bars = d.nights.map { "\($0.label) \(String(format: "%.1f", $0.hours))" }
                .joined(separator: "  ")
            out.append("Week bars: \(bars.isEmpty ? "none" : bars)")
            out.append("Week mean: \(mins(d.weekMeanMin))"
                + (d.prevWeekMeanMin.map { " · previous week: \(mins($0))" } ?? ""))
            if let b = d.bedtime {
                out.append("Bedtime: usually \(b.thisWeekClock) this week"
                    + (b.prevWeekClock.map { " (previous week \($0))" } ?? ""))
            }
            out.append("Source line shown: \(d.source ?? "—")")
        } else {
            out.append("No sleep derived in the window (screens show their empty state).")
        }

        // — Section 2: night by night —
        out.append("")
        out.append(String(repeating: "=", count: 72))
        out.append("NIGHT BY NIGHT — raw samples vs. what the total was computed from")

        let today = cal.startOfDay(for: input.now)
        let rawByNight = Dictionary(grouping: input.raw) {
            cal.startOfDay(for: SleepNightRule.nightDay($0.start, calendar: cal))
        }
        // The tier-arbitrated ingested stream, per night, BEFORE per-night
        // source resolution — so the resolver's choices are shown, not assumed.
        let tierArbitrated = SourceArbiter.arbitrate(input.samples.sleep) {
            "\($0.stage.rawValue)@\(cal.startOfDay(for: $0.date).timeIntervalSince1970)"
        }
        let ingestedByNight = Dictionary(grouping: tierArbitrated) {
            cal.startOfDay(for: $0.date)
        }

        for offset in stride(from: 0, through: -(nightsInWindow - 1), by: -1) {
            guard let night = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let raws = (rawByNight[night] ?? []).sorted { $0.start < $1.start }
            let ingested = ingestedByNight[night] ?? []
            guard !raws.isEmpty || !ingested.isEmpty else { continue }

            out.append("")
            out.append("NIGHT OF \(nightLabel(night, cal))")
            out.append("  Raw HealthKit samples (every source, including what ingestion drops):")
            if raws.isEmpty {
                out.append("    none in HealthKit for this night")
            }
            for r in raws {
                var line = "    \(clockRange(r.start, r.end, cal))  \(stageLabel(r.stage).padding(toLength: 11, withPad: " ", startingAt: 0))"
                    + " \(duration(r.hours))  \(r.sourceName) [\(r.bundleId)]"
                if let device = r.device { line += " · \(device)" }
                if r.droppedAtIngestion { line += "  — dropped at ingestion (\(r.stage == .inBed ? "in-bed, no stage" : "empty span"))" }
                out.append(line)
            }

            let res = SleepNightResolver.resolve(night: ingested)
            let nightAsleep = res.night.filter { SleepNightResolver.asleepStages.contains($0.stage) }
            if nightAsleep.isEmpty {
                out.append("  Derived: no asleep segments for this night")
                continue
            }
            let deep = SleepReading.mergedAsleepHours(res.night, asleep: [.deep])
            let rem  = SleepReading.mergedAsleepHours(res.night, asleep: [.rem])
            let core = SleepReading.mergedAsleepHours(res.night, asleep: [.core, .asleepUnspecified])
            var derived = "  Derived: asleep \(duration(deep + rem + core))"
                + " (deep \(duration(deep)) · light \(duration(core)) · REM \(duration(rem)))"
            if let source = res.chosenSource { derived += " · source used: \(source)" }
            out.append(derived)
            if let bed = nightAsleep.compactMap(\.start).min() {
                out.append("  Fell asleep: \(clock(bed, cal))")
            }
            out.append("  Computed from:")
            for seg in res.night.sorted(by: { $0.intervalStart < $1.intervalStart }) {
                out.append("    \(ingestedLine(seg, cal))")
            }
            if !res.excludedOtherSources.isEmpty {
                out.append("  Excluded — another source recorded the same night (one source per night, as Apple Health shows it):")
                for seg in res.excludedOtherSources { out.append("    \(ingestedLine(seg, cal))") }
            }
            if !res.excludedOtherEpisodes.isEmpty {
                out.append("  Excluded — separate sleep episode in the same day bucket (e.g. a nap), not part of the night:")
                for seg in res.excludedOtherEpisodes { out.append("    \(ingestedLine(seg, cal))") }
            }
            if !res.excludedNonSleep.isEmpty {
                out.append("  Excluded — not an asleep stage:")
                for seg in res.excludedNonSleep { out.append("    \(ingestedLine(seg, cal))") }
            }
        }

        out.append("")
        out.append(String(repeating: "=", count: 72))
        out.append("How to read this: compare each night's \"Raw HealthKit samples\" with")
        out.append("Apple Health (Browse → Sleep → night, \"Show All Data\"), and the")
        out.append("\"Derived\" line with what Liviqa's sleep screens showed. If the two")
        out.append("disagree, the lines above show exactly which samples made the figure.")
        return out.joined(separator: "\n")
    }

    // MARK: — Formatting (fixed EN, 24h clock, explicit timezone in the stamp)

    private static func stamp(_ d: Date, _ cal: Calendar) -> String {
        let f = formatter(cal, "yyyy-MM-dd HH:mm")
        return "\(f.string(from: d)) (\(cal.timeZone.identifier))"
    }
    private static func nightLabel(_ d: Date, _ cal: Calendar) -> String {
        formatter(cal, "EEE d MMM yyyy").string(from: d).uppercased()
    }
    private static func clock(_ d: Date, _ cal: Calendar) -> String {
        formatter(cal, "HH:mm").string(from: d)
    }
    private static func clockRange(_ a: Date, _ b: Date, _ cal: Calendar) -> String {
        "\(clock(a, cal))–\(clock(b, cal))"
    }
    private static func duration(_ hours: Double) -> String {
        let m = Int((hours * 60).rounded())
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
    private static func mins(_ m: Int) -> String {
        "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
    private static func stageLabel(_ s: SleepStage) -> String {
        switch s {
        case .inBed: return "IN BED"
        case .awake: return "AWAKE"
        case .rem:   return "REM"
        case .core:  return "CORE"
        case .deep:  return "DEEP"
        case .asleepUnspecified: return "ASLEEP"
        }
    }
    private static func ingestedLine(_ seg: SleepReading, _ cal: Calendar) -> String {
        let timing = seg.start != nil
            ? clockRange(seg.intervalStart, seg.intervalEnd, cal)
            : "(no start time kept)"
        return "\(timing)  \(stageLabel(seg.stage).padding(toLength: 11, withPad: " ", startingAt: 0)) \(duration(seg.hours))  \(seg.source)"
    }
    private static func formatter(_ cal: Calendar, _ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = cal.timeZone
        f.dateFormat = format
        return f
    }
}
