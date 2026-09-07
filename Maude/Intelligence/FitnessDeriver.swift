// FitnessDeriver.swift — everything the A7.2 Fitness & exercise screen shows
// (FR-FIT-01), derived on device from local `HealthSamples`. Pure Foundation
// (NFR-PORT-01).
//
// NO TARGETS EVER (designated line): training load is a descriptive addition of
// how long and how hard the user moved; the only reference drawn anywhere is the
// user's OWN prior weeks. Nothing here encodes a goal, plan or recommendation.
//
// LOAD POINTS (published arithmetic, anti-score-opacity): one workout's load =
// duration-in-minutes × an intensity factor. With heart-rate samples the factor
// is the workout's mean HR as a fraction of the user's own observed maximum
// (0.5…1.0 → ×0.75…×2.0); without HR it falls back to energy density
// (kcal/min ÷ 8, clamped 0.5…2.0), and to ×1.0 (pure duration) when kcal is
// absent. All three paths are printed in the screen's foot copy.
//
// INGESTION (T-FIT-01 closed, 2026-08-13): workouts, vo2Max, daily kcal AND the
// beats inside each recent workout interval are ingested — `HealthKitService`
// reads `heartRate` bounded by the workout intervals into
// `HealthSamples.workoutHeartRate`, and this deriver reads that stream by
// default. Avg-HR and the zone card therefore render from the citizen's own
// data when their watch recorded it, and stay honestly absent when it didn't
// (a phone-only session, or a workout logged by hand).
//
// ZONES ARE PERSONAL, NOT POPULATION: every zone edge is a fraction of the
// HIGHEST heart rate this citizen's OWN recent workouts recorded — never an
// age formula (220−age), never a published athlete scale, and never a target.
// The card says so in its foot copy.
import Foundation

public nonisolated struct FitnessDetail: Sendable, Equatable {

    public struct WorkoutRow: Sendable, Equatable {
        public let title: String        // "Sunday · Cycling"
        public let meta: String         // "62 km · 2h 18m · avg 138 bpm"
        public let type: String         // raw type for the icon mapping
        public let load: Int
        public init(title: String, meta: String, type: String, load: Int) {
            self.title = title; self.meta = meta; self.type = type; self.load = load
        }
    }

    public struct WeekLoad: Sendable, Equatable {
        public let label: String        // "W1" … "now"
        /// Load for the week, or nil when the workout record does not yet cover
        /// it. A week INSIDE the covered span with no workouts is a real 0 (a
        /// rest week, which must stay visible) — only weeks before the first
        /// recorded workout are absent.
        public let points: Double?
        public init(label: String, points: Double?) { self.label = label; self.points = points }
    }

    /// One HR training zone share (only when HR samples were provided).
    public struct ZoneShare: Sendable, Equatable {
        public let name: String         // "Z2 · endurance"
        public let minutes: Double
        public init(name: String, minutes: Double) { self.name = name; self.minutes = minutes }
    }

    // This week (last 7 days).
    public let weekLoadPoints: Int
    public let weekCount: Int
    public let weekDistanceKm: Double?   // nil when no workout carried distance
    public let weekMovingMin: Double
    /// Dominant workout type this week ("Cycling") — drives copy like "rides".
    public let dominantType: String?
    /// Mean HR across the week's workouts — only when HR samples were provided.
    public let weekAvgHR: Int?

    /// Up to 4 week buckets of load, oldest → current ("W1"…"now").
    public let loadWeeks: [WeekLoad]
    /// Mean of the PRIOR weeks' loads (the dashed own-usual line); nil below 2.
    public let loadUsual: Double?

    /// This week's workouts, newest first.
    public let workouts: [WorkoutRow]

    // Zones — the longest workout of the week, only when HR samples exist.
    public let zoneWorkoutTitle: String?
    public let zones: [ZoneShare]
    /// The citizen's OWN highest recorded workout heart rate in this window —
    /// the reference every zone edge is a fraction of. Printed on the card so
    /// the scale can never be mistaken for a population or age-based one.
    public let zoneOwnMaxHR: Int?

    // VO₂max long trend over the whole local window.
    public let vo2Series: [Double]
    public let vo2Band: ClosedRange<Double>?    // own mean ±1σ
    public let vo2Latest: Double?
    /// True when the latest reading is the window's highest (the only milestone
    /// ever annotated — derived, never invented).
    public let vo2IsNewHigh: Bool
    public let vo2XLabels: [String]             // ["Jun", "Jul", "Aug"]

    public init(weekLoadPoints: Int, weekCount: Int, weekDistanceKm: Double?,
                weekMovingMin: Double, dominantType: String?, weekAvgHR: Int?,
                loadWeeks: [WeekLoad], loadUsual: Double?, workouts: [WorkoutRow],
                zoneWorkoutTitle: String?, zones: [ZoneShare], zoneOwnMaxHR: Int? = nil,
                vo2Series: [Double],
                vo2Band: ClosedRange<Double>?, vo2Latest: Double?, vo2IsNewHigh: Bool,
                vo2XLabels: [String]) {
        self.weekLoadPoints = weekLoadPoints; self.weekCount = weekCount
        self.weekDistanceKm = weekDistanceKm; self.weekMovingMin = weekMovingMin
        self.dominantType = dominantType; self.weekAvgHR = weekAvgHR
        self.loadWeeks = loadWeeks; self.loadUsual = loadUsual; self.workouts = workouts
        self.zoneWorkoutTitle = zoneWorkoutTitle; self.zones = zones
        self.zoneOwnMaxHR = zoneOwnMaxHR
        self.vo2Series = vo2Series; self.vo2Band = vo2Band; self.vo2Latest = vo2Latest
        self.vo2IsNewHigh = vo2IsNewHigh; self.vo2XLabels = vo2XLabels
    }
}

public nonisolated enum FitnessDeriver {

    private static let cal = Calendar(identifier: .gregorian)

    /// A timestamped heart-rate sample (bpm) for the avg-HR / zone computation.
    /// Ingestion supplies these as `HealthSamples.workoutHeartRate` (T-FIT-01);
    /// the parameter form stays for tests and for any future source.
    public struct HRSample: Sendable, Equatable {
        public let ts: Date
        public let bpm: Double
        public init(ts: Date, bpm: Double) { self.ts = ts; self.bpm = bpm }
    }

    /// `hrSamples: nil` (the default) reads the ingested workout heart-rate
    /// stream. Passing an explicit array overrides it — an empty array means
    /// "no HR", which is how the honest-absence path is exercised in tests.
    public static func derive(from s: HealthSamples,
                              hrSamples: [HRSample]? = nil,
                              now: Date = Date()) -> FitnessDetail? {
        guard !s.workouts.isEmpty || !vo2Metrics(s).isEmpty else { return nil }
        let today = cal.startOfDay(for: now)
        let all = s.workouts.sorted { $0.start < $1.start }
        let hrSamples = hrSamples
            ?? s.workoutHeartRate.map { HRSample(ts: $0.ts, bpm: $0.bpm) }

        // Own observed max HR across ALL provided samples — the personal
        // reference for zone fractions (own data, never an age formula).
        let ownMaxHR = hrSamples.map(\.bpm).max()

        func avgHR(_ w: WorkoutReading) -> Double? {
            let inWorkout = hrSamples.filter { $0.ts >= w.start && $0.ts <= w.end }
            guard !inWorkout.isEmpty else { return nil }
            return inWorkout.map(\.bpm).reduce(0, +) / Double(inWorkout.count)
        }

        func load(_ w: WorkoutReading) -> Double {
            let factor: Double
            if let hr = avgHR(w), let maxHR = ownMaxHR, maxHR > 0 {
                let frac = min(1, max(0.5, hr / maxHR))
                factor = 0.75 + (frac - 0.5) * 2.5      // 0.5→0.75, 1.0→2.0
            } else if let kcal = w.kcal, w.durMin > 0 {
                factor = min(2.0, max(0.5, kcal / w.durMin / 8))
            } else {
                factor = 1.0
            }
            return w.durMin * factor
        }

        // — This week —
        let week = all.filter { daysBetween($0.start, today) <= 6 }
        let weekLoad = week.map(load).reduce(0, +)
        let distances = week.compactMap(\.distKm)
        let weekDist = distances.isEmpty ? nil : distances.reduce(0, +)
        let weekMoving = week.map(\.durMin).reduce(0, +)
        let dominant = Dictionary(grouping: week, by: \.type)
            .max { $0.value.count < $1.value.count }?.key
        let weekHRs = week.compactMap(avgHR)
        let weekAvgHR = weekHRs.isEmpty ? nil
            : Int((weekHRs.reduce(0, +) / Double(weekHRs.count)).rounded())

        // — 4 week buckets (oldest → now), on the real week axis —
        // A week with no workouts INSIDE the recorded span is a genuine rest
        // week and keeps its slot at 0; a week before the first recorded
        // workout has no record at all and stays nil. Dropping either would
        // slide the remaining weeks together and hide a rest week entirely.
        let firstRecorded = all.map(\.start).min()
        var buckets: [FitnessDetail.WeekLoad] = []
        for b in (0..<4).reversed() {           // b=0 is the current week
            let ws = all.filter {
                let d = daysBetween($0.start, today)
                return d >= b * 7 && d <= b * 7 + 6
            }
            let label = b == 0 ? "now" : "W\(4 - b)"
            if !ws.isEmpty {
                buckets.append(.init(label: label, points: ws.map(load).reduce(0, +).rounded()))
            } else if let first = firstRecorded,
                      daysBetween(first, today) >= b * 7 {
                buckets.append(.init(label: label, points: 0))   // a real rest week
            } else {
                buckets.append(.init(label: label, points: nil)) // no record yet
            }
        }
        let prior = buckets.filter { $0.label != "now" }.compactMap(\.points)
        let loadUsual = prior.count >= 2 ? prior.reduce(0, +) / Double(prior.count) : nil

        // — Workout rows (this week, newest first) —
        let rows: [FitnessDetail.WorkoutRow] = week.sorted { $0.start > $1.start }.map { w in
            var meta: [String] = []
            if let km = w.distKm { meta.append(String(format: "%.0f km", km)) }
            meta.append(durText(w.durMin))
            if let hr = avgHR(w) { meta.append("avg \(Int(hr.rounded())) bpm") }
            else if let kcal = w.kcal { meta.append("\(Int(kcal.rounded())) kcal") }
            return .init(title: "\(weekdayName(w.start)) · \(w.type)",
                         meta: meta.joined(separator: " · "),
                         type: w.type,
                         load: Int(load(w).rounded()))
        }

        // — Zones for the longest workout of the week (HR samples required) —
        var zones: [FitnessDetail.ZoneShare] = []
        var zoneTitle: String? = nil
        if let maxHR = ownMaxHR,
           let longest = week.max(by: { $0.durMin < $1.durMin }),
           avgHR(longest) != nil {
            let inWorkout = hrSamples
                .filter { $0.ts >= longest.start && $0.ts <= longest.end }
                .sorted { $0.ts < $1.ts }
            // Attribute the gap to the sample opening it, capped at 60 s so
            // sparse recordings can't inflate a zone.
            var mins = [0.0, 0.0, 0.0, 0.0]
            for (i, sample) in inWorkout.enumerated() {
                let dt: TimeInterval = i < inWorkout.count - 1
                    ? min(60, inWorkout[i + 1].ts.timeIntervalSince(sample.ts))
                    : 5
                let frac = sample.bpm / maxHR
                let z = frac < 0.68 ? 0 : frac < 0.80 ? 1 : frac < 0.90 ? 2 : 3
                mins[z] += dt / 60
            }
            let names = ["Z1 · easy", "Z2 · endurance", "Z3 · tempo", "Z4 · threshold"]
            zones = zip(names, mins).filter { $0.1 >= 0.5 }
                .map { FitnessDetail.ZoneShare(name: $0.0, minutes: $0.1.rounded()) }
            if !zones.isEmpty {
                zoneTitle = "\(weekdayName(longest.start)) \(longest.type.lowercased()) · heart-rate zones"
            }
        }

        // — VO₂max long trend —
        let vo2 = vo2Metrics(s).sorted { $0.date < $1.date }
        let vo2Values = vo2.map { ($0.value * 10).rounded() / 10 }
        let vo2Band = HeartDetailDeriver.band(vo2Values)
        let vo2Latest = vo2Values.last
        let vo2NewHigh = vo2Values.count >= 5
            && vo2Latest != nil && vo2Latest == vo2Values.max()
        var vo2Labels: [String] = []
        if let first = vo2.first?.date, let last = vo2.last?.date, vo2.count >= 2 {
            vo2Labels = monthLabels(from: first, to: last)
        }

        return FitnessDetail(
            weekLoadPoints: Int(weekLoad.rounded()),
            weekCount: week.count,
            weekDistanceKm: weekDist,
            weekMovingMin: weekMoving,
            dominantType: dominant,
            weekAvgHR: weekAvgHR,
            loadWeeks: buckets,
            loadUsual: loadUsual,
            workouts: rows,
            zoneWorkoutTitle: zoneTitle,
            zones: zones,
            zoneOwnMaxHR: zones.isEmpty ? nil : ownMaxHR.map { Int($0.rounded()) },
            vo2Series: vo2Values.count >= 2 ? vo2Values : [],
            vo2Band: vo2Band,
            vo2Latest: vo2Latest,
            vo2IsNewHigh: vo2NewHigh,
            vo2XLabels: vo2Labels)
    }

    // MARK: helpers

    private static func vo2Metrics(_ s: HealthSamples) -> [DailyMetric] {
        s.heartExtras.filter { $0.kind == .vo2max }
    }

    private static func daysBetween(_ a: Date, _ b: Date) -> Int {
        abs(cal.dateComponents([.day], from: cal.startOfDay(for: a),
                               to: cal.startOfDay(for: b)).day ?? 0)
    }

    static func durText(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(m) min"
    }

    static func weekdayName(_ d: Date) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday",
                     "Thursday", "Friday", "Saturday"]
        return names[(cal.component(.weekday, from: d) - 1) % 7]
    }

    /// First / middle / last month abbreviations across the span (EN, fixed).
    static func monthLabels(from a: Date, to b: Date) -> [String] {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        func label(_ d: Date) -> String { months[(cal.component(.month, from: d) - 1) % 12] }
        let mid = Date(timeIntervalSince1970: (a.timeIntervalSince1970 + b.timeIntervalSince1970) / 2)
        let l = [label(a), label(mid), label(b)]
        return l[0] == l[2] ? [l[0]] : (l[0] == l[1] || l[1] == l[2] ? [l[0], l[2]] : l)
    }
}
