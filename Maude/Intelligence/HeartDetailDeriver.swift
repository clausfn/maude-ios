// HeartDetailDeriver.swift — everything the A7.2 Heart metric-detail screen shows,
// derived on device from local `HealthSamples`. Pure Foundation (NFR-PORT-01).
//
// NUMBERS ONLY: the view maps these figures onto fixed descriptive templates.
//
// SAFETY LANES on this screen (all rails held at the deriver level):
// · Resting HR / blood pressure: PERSONAL-baseline framing only — every band
//   here is the user's own mean ±1σ over the local window, never a clinical
//   reference range.
// · AFib (OD-11 / D9): DISPLAY-ONLY. This deriver re-presents the watch's own
//   burden figure and counts observation days. It computes NO trend, NO score,
//   NO interpretation of rhythm — those fields deliberately do not exist.
//   FR-NDG-06 (designated control) is untouched.
//
// nil ⇒ no RHR, no BP and no AFib in the window → demo seeds (demo mode) or an
// honest empty state (real-data mode).
import Foundation

public nonisolated struct HeartWeekDetail: Sendable, Equatable {

    /// One blood-pressure reading for the dot-range strip (oldest → latest).
    public struct BPPoint: Sendable, Equatable {
        public let sys: Int          // mmHg
        public let dia: Int          // mmHg
        public let isLatest: Bool
        public init(sys: Int, dia: Int, isLatest: Bool) {
            self.sys = sys; self.dia = dia; self.isLatest = isLatest
        }
    }

    // Resting heart rate — own-baseline framing.
    public let rhrLatest: Int?
    /// Last-14-days series (days with data), oldest → latest. Empty ⇒ no spark.
    public let rhrSeries: [Double]
    /// The user's OWN usual band: mean ±1σ over the full window (nil below 5 days).
    public let rhrBand: ClosedRange<Double>?
    /// Days spanned by the band window (for the honest "your own N-day usual" foot).
    public let rhrWindowDays: Int

    // Blood pressure — last 14 days of readings (day-latest), oldest → latest.
    public let bp: [BPPoint]
    /// Own usual corridors, mean ±1σ over the window's readings (nil below 5).
    public let sysBand: ClosedRange<Double>?
    public let diaBand: ClosedRange<Double>?
    /// "121/78" — the latest reading, for the hero sub line.
    public let bpLatestText: String?
    /// Index into `bp` of the highest systolic reading when it sits above the
    /// usual corridor — drives the single annotation. nil when steady.
    public let bpPeakIndex: Int?
    /// Edge labels for the strip ("24 Jun", "7 Jul").
    public let bpEdgeLabels: [String]
    public let bpSource: String?

    // AFib — display-only re-presentation (OD-11). No trend, no interpretation.
    public let afibLatestPct: Double?
    /// Distinct days carrying an AFib-burden measurement in the window.
    public let afibDaysObserved: Int
    /// "12 Aug" — when the latest figure was recorded.
    public let afibLatestDateText: String?

    public init(rhrLatest: Int?, rhrSeries: [Double], rhrBand: ClosedRange<Double>?,
                rhrWindowDays: Int, bp: [BPPoint], sysBand: ClosedRange<Double>?,
                diaBand: ClosedRange<Double>?, bpLatestText: String?,
                bpPeakIndex: Int?, bpEdgeLabels: [String], bpSource: String?,
                afibLatestPct: Double?, afibDaysObserved: Int,
                afibLatestDateText: String?) {
        self.rhrLatest = rhrLatest; self.rhrSeries = rhrSeries; self.rhrBand = rhrBand
        self.rhrWindowDays = rhrWindowDays; self.bp = bp; self.sysBand = sysBand
        self.diaBand = diaBand; self.bpLatestText = bpLatestText
        self.bpPeakIndex = bpPeakIndex; self.bpEdgeLabels = bpEdgeLabels
        self.bpSource = bpSource; self.afibLatestPct = afibLatestPct
        self.afibDaysObserved = afibDaysObserved
        self.afibLatestDateText = afibLatestDateText
    }
}

public nonisolated enum HeartDetailDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    /// Minimum distinct days/readings before an "own usual" band is honest.
    private static let bandMinCount = 5

    public static func derive(from s: HealthSamples, now: Date = Date()) -> HeartWeekDetail? {
        guard !s.restingHR.isEmpty || !s.bloodPressure.isEmpty || !s.afib.isEmpty
        else { return nil }
        let today = cal.startOfDay(for: now)

        // — Resting HR —
        let rhrSorted = s.restingHR.sorted { $0.date < $1.date }
        let rhrLatest = rhrSorted.last.map { Int($0.value.rounded()) }
        let series14: [Double] = rhrSorted
            .filter { daysBetween($0.date, today) <= 13 }
            .map(\.value)
        let rhrValues = rhrSorted.map(\.value)
        let rhrBand = band(rhrValues)
        let rhrWindowDays: Int = {
            guard let first = rhrSorted.first else { return 0 }
            return daysBetween(first.date, today) + 1
        }()

        // — Blood pressure (day-latest reading per day, last 14 days) —
        let bpWindow = s.bloodPressure
            .filter { daysBetween(cal.startOfDay(for: $0.ts), today) <= 13 }
            .sorted { $0.ts < $1.ts }
        var byDay: [Date: BloodPressureReading] = [:]
        for r in bpWindow { byDay[cal.startOfDay(for: r.ts)] = r }   // latest wins
        let bpDaily = byDay.keys.sorted().compactMap { byDay[$0] }
        let bpPoints = bpDaily.enumerated().map { i, r in
            HeartWeekDetail.BPPoint(sys: r.sys, dia: r.dia, isLatest: i == bpDaily.count - 1)
        }
        // Corridors from the FULL window's readings (30–90 d), not just 14 days.
        let allBP = s.bloodPressure
        let sysBand = band(allBP.map { Double($0.sys) })
        let diaBand = band(allBP.map { Double($0.dia) })
        let latestBP = s.bloodPressure.max { $0.ts < $1.ts }
        let bpLatestText = latestBP.map { "\($0.sys)/\($0.dia)" }
        var peakIndex: Int? = nil
        if let upper = sysBand?.upperBound,
           let maxI = bpDaily.indices.max(by: { bpDaily[$0].sys < bpDaily[$1].sys }),
           Double(bpDaily[maxI].sys) > upper {
            peakIndex = maxI
        }
        var edges: [String] = []
        if let first = bpDaily.first, let last = bpDaily.last, bpDaily.count >= 2 {
            edges = [dayText(first.ts), dayText(last.ts)]
        }
        let bpSource = Dictionary(grouping: allBP, by: \.source)
            .max { $0.value.count < $1.value.count }?.key

        // — AFib (display-only re-presentation, OD-11) —
        let afibSorted = s.afib.sorted { $0.ts < $1.ts }
        let afibLatest = afibSorted.last
        let afibDays = Set(afibSorted.map { cal.startOfDay(for: $0.ts) }).count

        return HeartWeekDetail(
            rhrLatest: rhrLatest,
            rhrSeries: series14.count >= 2 ? series14 : [],
            rhrBand: rhrBand,
            rhrWindowDays: rhrWindowDays,
            bp: bpPoints.count >= 2 ? bpPoints : [],
            sysBand: sysBand,
            diaBand: diaBand,
            bpLatestText: bpLatestText,
            bpPeakIndex: peakIndex,
            bpEdgeLabels: edges,
            bpSource: bpSource,
            afibLatestPct: afibLatest.map { ($0.pct * 10).rounded() / 10 },
            afibDaysObserved: afibDays,
            afibLatestDateText: afibLatest.map { dayText($0.ts) })
    }

    // MARK: helpers

    /// Own mean ±1σ band; nil below `bandMinCount` values or with zero spread.
    static func band(_ values: [Double]) -> ClosedRange<Double>? {
        guard values.count >= bandMinCount else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let sd = (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)).squareRoot()
        guard sd > 0.0001 else { return nil }
        let lo = ((mean - sd) * 10).rounded() / 10
        let hi = ((mean + sd) * 10).rounded() / 10
        return lo...hi
    }

    private static func daysBetween(_ a: Date, _ b: Date) -> Int {
        abs(cal.dateComponents([.day], from: cal.startOfDay(for: a),
                               to: cal.startOfDay(for: b)).day ?? 0)
    }

    /// "7 Jul" — fixed English month abbreviation, deterministic across locales
    /// (copy is EN; matches the design package's edge labels).
    static func dayText(_ d: Date) -> String {
        let c = cal.dateComponents([.day, .month], from: d)
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(c.day ?? 1) \(months[max(0, min(11, (c.month ?? 1) - 1))])"
    }
}
