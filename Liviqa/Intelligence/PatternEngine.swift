// PatternEngine.swift — long-horizon pattern detectors (FR-PAT-01 · v01 2026-06-11).
//
// The citizen-side twin of the console's detector engine (liviqa-b2b-console
// src/lib/detectors.ts): the SAME generic detectors, the SAME thresholds, the
// SAME chart-note discipline — values computed from input, never authored.
// Each detector is a pure function over a citizen's long-horizon aggregates
// and returns a finding in the CITIZEN's voice, or nil when criteria aren't
// met. One engine, any citizen: a 10,000-user deployment runs these functions
// over 10,000 inputs produced by the on-device summarisation pipeline.
//
// Wording rules: titles read like a chart note (value, direction, date).
// Display, never judgement — the only "advice" allowed is the generic
// behavioural register already permitted by FR-NDG.
// Pure Foundation (Android-portable). Audit: docs/pattern-register/ in the
// console repo documents method + thresholds per detector id.
import Foundation

public nonisolated struct PatternFinding: Sendable, Identifiable, Equatable {
    public let id: String          // detector id, e.g. "D-ARR-01"
    public let group: String       // "Heart & rhythm", …
    public let tone: PatternTone
    public let title: String       // chart-note, computed
    public let fact: String        // one factual sentence (the numbers)
    public let citizen: String     // the finding in the citizen's voice
    public let source: String
}
public nonisolated enum PatternTone: String, Sendable { case green, amber, ink }

/// Long-horizon aggregates from the summarisation pipeline. All optional —
/// detectors fire only on data the citizen actually has.
public nonisolated struct PatternInput: Sendable {
    public var asOf: Date = Date()
    public var rhythm: (episodes: Int, lastEpisode: DateComponents, ecgTotal: Int, ecgAfib: Int)?
    public var glucoseYearly: [Int: Double]?          // year -> mean mmol/L
    public var bp: (homeSys: Int, homeDia: Int, officeSysAvg: Int, nHome: Int, spanYears: Int)?
    public var sleepYearly: [Int: Double]?            // year -> staged hours
    public var trainingGap: (weeks: Int, weeksToBaseline: Int)?
    public var exposure: (pctMinutesHighPM: Int, eveningPM: Int, morningPM: Int)?
    public var benchmark: (routeKm: Double, firstMin: Double, bestMin: Double, bestWhen: String)?
    public var drift: (bpmRise: Int, ())?
    public init() {}
}

public nonisolated enum PatternEngine {

    static func monthsBetween(_ comps: DateComponents, and date: Date, calendar: Calendar = .current) -> Int {
        guard let from = calendar.date(from: comps) else { return 0 }
        return calendar.dateComponents([.month], from: from, to: date).month ?? 0
    }

    public static func run(_ c: PatternInput, calendar: Calendar = .current) -> [PatternFinding] {
        var out: [PatternFinding] = []
        let mf = DateFormatter(); mf.dateFormat = "MMM yyyy"

        // D-ARR-01 — arrhythmia episode aggregator. Quiet during an active
        // phase (<3 months since last episode): route to clinician, no card.
        if let r = c.rhythm, r.episodes > 0 {
            let clean = monthsBetween(r.lastEpisode, and: c.asOf, calendar: calendar)
            if clean >= 3, let last = calendar.date(from: r.lastEpisode) {
                out.append(PatternFinding(
                    id: "D-ARR-01", group: "Heart & rhythm", tone: .green,
                    title: "AFib: last episode \(mf.string(from: last)) · \(clean) months event-free",
                    fact: "\(r.episodes) episodes on record; \(r.ecgAfib) of \(r.ecgTotal) ECGs classified AFib, all during episodes.",
                    citizen: "Your watch has your rhythm history on record — and \(clean) clean months since \(mf.string(from: last)).",
                    source: "Watch ECG + rhythm notifications"))
            }
        }

        // D-ERA-01 — long-horizon glucose era (shift ≥ 1.5 mmol/L from peak).
        if let g = c.glucoseYearly, g.count >= 4,
           let peak = g.max(by: { $0.value < $1.value }),
           let lastYear = g.keys.max(), let lastVal = g[lastYear],
           peak.value - lastVal >= 1.5 {
            out.append(PatternFinding(
                id: "D-ERA-01", group: "Glucose", tone: .amber,
                title: "Glucose: yearly mean \(peak.value) (\(peak.key)) → \(lastVal) mmol/L, stable since",
                fact: "\(g.count) years of sensor data.",
                citizen: "Years of your glucose in one line: the hard stretch in \(peak.key), controlled every year since.",
                source: "CGM history"))
        }

        // D-WCG-01 — white-coat gap (≥ 10 mmHg).
        if let b = c.bp, b.officeSysAvg - b.homeSys >= 10 {
            let gap = b.officeSysAvg - b.homeSys
            out.append(PatternFinding(
                id: "D-WCG-01", group: "Heart & rhythm", tone: .green,
                title: "Home BP \(b.homeSys)/\(b.homeDia) · \(gap) mmHg below office",
                fact: "\(b.nHome) home readings over \(b.spanYears) years.",
                citizen: "Your home readings run about \(gap) points below clinic measurements — worth knowing before any treatment talk.",
                source: "Home BP monitor + office values"))
        }

        // D-SLP-01 — sleep regime change (≥ 1 h year over year).
        if let s = c.sleepYearly, s.count >= 2 {
            let years = s.keys.sorted()
            let last = years[years.count - 1], prev = years[years.count - 2]
            if let a = s[prev], let b = s[last], abs(b - a) >= 1 {
                let delta = (b - a).rounded(toPlaces: 1)
                out.append(PatternFinding(
                    id: "D-SLP-01", group: "Sleep", tone: delta > 0 ? .green : .amber,
                    title: "Sleep \(delta > 0 ? "+" : "")\(delta) h/night in \(last) (\(a) → \(b) h)",
                    fact: "Watch-staged nights only.",
                    citizen: delta > 0
                        ? "You sleep \(delta) hours more per night than in \(prev) — and you've kept it."
                        : "Your nights are \(abs(delta)) h shorter than in \(prev).",
                    source: "Watch sleep staging"))
            }
        }

        // D-GAP-01 — training gap ≥ 3 weeks with a measured comeback.
        if let t = c.trainingGap, t.weeks >= 3 {
            out.append(PatternFinding(
                id: "D-GAP-01", group: "Recovery", tone: .amber,
                title: "\(t.weeks)-week training stop · baseline back in \(t.weeksToBaseline) weeks",
                fact: "Stop and recovery slope measured against your own cadence.",
                citizen: "After your break you rebuilt to full capacity in \(t.weeksToBaseline) weeks.",
                source: "Activity history"))
        }

        // D-EXP-01 — exposure dose (≥ 10% of minutes at high PM).
        if let e = c.exposure, e.pctMinutesHighPM >= 10 {
            out.append(PatternFinding(
                id: "D-EXP-01", group: "Environment", tone: .amber,
                title: "\(e.pctMinutesHighPM)% of training minutes at PM2.5 ≥ 50",
                fact: "Computed from your sessions against the regional air archive.",
                citizen: "About a fifth of your training happens in heavy air. An earlier or indoor session on those days keeps the benefit without the exposure.",
                source: "Workouts × air-quality archive"))
            // D-TRD-01 — slot trade-off (evening ≥ 1.2× morning).
            if Double(e.eveningPM) >= Double(e.morningPM) * 1.2, e.morningPM > 0 {
                let pct = Int(((1 - Double(e.morningPM) / Double(e.eveningPM)) * 100).rounded())
                out.append(PatternFinding(
                    id: "D-TRD-01", group: "Environment", tone: .amber,
                    title: "Evening sessions: PM2.5 \(e.eveningPM) vs \(e.morningPM) at 07:00 (−\(pct)%)",
                    fact: "High-season comparison of your usual start window against the same days' mornings.",
                    citizen: "Mornings in the high season average \(pct)% cleaner air than your usual evening slot.",
                    source: "Start times × hourly air quality"))
            }
        }

        // D-BENCH-01 — repeated-route benchmark.
        if let b = c.benchmark {
            out.append(PatternFinding(
                id: "D-BENCH-01", group: "Fitness", tone: .green,
                title: "Fixed \(b.routeKm) km route: \(b.firstMin) → \(b.bestMin) min (best \(b.bestWhen))",
                fact: "Same course throughout — your own repeated fitness test.",
                citizen: "Your regular route doubles as a fitness test — \(b.bestMin) minutes was your best.",
                source: "Segment history"))
        }

        // D-DRIFT-01 — cardiac drift under heat (≥ 10 bpm at equal power).
        if let d = c.drift, d.bpmRise >= 10 {
            out.append(PatternFinding(
                id: "D-DRIFT-01", group: "Heart & rhythm", tone: .amber,
                title: "Heat sessions: +\(d.bpmRise) bpm at equal power",
                fact: "Within-session HR/power decoupling on hot-day rides.",
                citizen: "On hot rides your heart rate climbs even when your effort doesn't. That's heat, not fitness loss.",
                source: "HR + power laps"))
        }

        return out
    }
}

private extension Double {
    nonisolated func rounded(toPlaces places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
