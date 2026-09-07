// DerivedShareBuilder.swift — builds the scoped, derived share package the device
// pushes to the sovereign backend (PUT /shares/{grantId}), per
// Maude_iOS_Backend_Contract_v01 §4 and D-BACKEND-SCOPE.
//
// CARDINAL: raw HealthKit samples NEVER leave the device. This builder emits only
// derived summaries/series for the metrics inside the citizen's CONSENTED GROUPS.
// `provenance`/`source` are deliberately NOT included (must never render; backend
// also strips). Framework-free + pure → unit-testable (NFR-PORT-01).
//
// FR-SHARE-01 (derive scoped share) · RTM row required before merge.
import Foundation

// MARK: - Wire payload (matches backend PUT /shares body)

public struct SeriesPoint: Codable, Equatable, Sendable {
    public let x: String   // bucket label (yyyy-MM-dd for D, yyyy-MM for M)
    public let v: Double
}

public struct EventCount: Codable, Equatable, Sendable {
    public let label: String
    public let count: Int
}

public struct InsightPayload: Codable, Equatable, Sendable {
    public let key: String?
    public let severity: String?
    public let title: String
    public let meaning: String?
    public let suggested: String?
    public init(key: String?, severity: String?, title: String, meaning: String?, suggested: String?) {
        self.key = key; self.severity = severity; self.title = title
        self.meaning = meaning; self.suggested = suggested
    }
}

/// One derived metric. All-optional so each metric emits only what it has; the
/// backend re-checks scope/guardrails server-side regardless.
public struct MetricPayload: Codable, Equatable, Sendable {
    public var unit: String?
    public var goal: Double?
    public var better: String?            // "hi" | "lo"
    public var summary: [String: Double]?
    public var series: [String: [SeriesPoint]]?   // {"D":[…], "M":[…]}
    public var events: [EventCount]?
}

public struct DerivedSharePayloadBody: Codable, Equatable, Sendable {
    public let metrics: [String: MetricPayload]
    public let insights: [InsightPayload]
}

/// The full PUT /shares/{grantId} request body.
public struct DerivedShareRequest: Codable, Equatable, Sendable {
    public let asOf: String                // ISO-8601
    public let payload: DerivedSharePayloadBody
}

// MARK: - Builder

public enum DerivedShareBuilder {

    /// Glucose target range for time-in-range (mmol/L).
    static let tirLow = 3.9, tirHigh = 10.0

    /// Build the derived share for the citizen's consented GROUPS (e.g.
    /// ["glucose","activity","sleep","recovery"]). Metrics outside the granted
    /// groups are never computed or emitted.
    public static func build(
        from s: HealthSamples,
        scopeGroups: Set<String>,
        insights: [InsightPayload] = [],
        asOf: Date = Date()
    ) -> DerivedShareRequest {
        var metrics: [String: MetricPayload] = [:]

        if scopeGroups.contains("glucose") {
            if let tir = glucoseTIR(s.glucose) { metrics["tir"] = tir }
            if let mg = glucoseMean(s.glucose) { metrics["mean_g"] = mg }
        }
        if scopeGroups.contains("recovery") || scopeGroups.contains("hrv") {
            if let hrv = dailyMetric(s.hrv, unit: "ms", better: "hi") { metrics["hrv"] = hrv }
            if let rhr = dailyMetric(s.restingHR, unit: "bpm", better: "lo") { metrics["rhr"] = rhr }
        }
        if scopeGroups.contains("activity") {
            if let steps = dailyMetric(s.steps, unit: "/day", better: "hi", goal: 8000) { metrics["steps"] = steps }
            if let energy = dailyMetric(s.activeEnergy, unit: "kcal", better: "hi") { metrics["exercise"] = energy }
            if let wk = workouts(s.workouts) { metrics["workouts"] = wk }
        }
        if scopeGroups.contains("sleep") {
            if let sl = sleep(s.sleep) { metrics["sleep"] = sl }
        }

        let body = DerivedSharePayloadBody(metrics: metrics, insights: insights)
        return DerivedShareRequest(asOf: iso(asOf), payload: body)
    }

    // MARK: - Glucose derivations

    static func glucoseMean(_ readings: [GlucoseReading]) -> MetricPayload? {
        guard !readings.isEmpty else { return nil }
        let mean = readings.map(\.mmol).reduce(0, +) / Double(readings.count)
        // daily mean series
        let byDay = Dictionary(grouping: readings) { dayKey($0.ts) }
        let daily = byDay.map { (k, v) in SeriesPoint(x: k, v: round1(v.map(\.mmol).reduce(0, +) / Double(v.count))) }
            .sorted { $0.x < $1.x }
        return MetricPayload(unit: "mmol/L", goal: 8, better: "lo",
                             summary: ["mean": round1(mean)],
                             series: ["D": daily, "M": monthly(daily)], events: nil)
    }

    static func glucoseTIR(_ readings: [GlucoseReading]) -> MetricPayload? {
        guard !readings.isEmpty else { return nil }
        func tir(_ rs: [GlucoseReading]) -> Double {
            let inRange = rs.filter { $0.mmol >= tirLow && $0.mmol <= tirHigh }.count
            return round1(Double(inRange) / Double(rs.count) * 100)
        }
        let byDay = Dictionary(grouping: readings) { dayKey($0.ts) }
        let daily = byDay.map { SeriesPoint(x: $0.key, v: tir($0.value)) }.sorted { $0.x < $1.x }
        let lows = readings.filter { $0.mmol < tirLow }.count
        let highs = readings.filter { $0.mmol > tirHigh }.count
        return MetricPayload(unit: "%", goal: 70, better: "hi",
                             summary: ["mean": tir(readings)],
                             series: ["D": daily, "M": monthly(daily)],
                             events: [EventCount(label: "Hypos (<3.9)", count: lows),
                                      EventCount(label: "Hypers (>10)", count: highs)])
    }

    // MARK: - Daily-metric & other derivations

    static func dailyMetric(_ ms: [DailyMetric], unit: String, better: String, goal: Double? = nil) -> MetricPayload? {
        guard !ms.isEmpty else { return nil }
        let mean = ms.map(\.value).reduce(0, +) / Double(ms.count)
        let daily = ms.map { SeriesPoint(x: dayKey($0.date), v: round1($0.value)) }.sorted { $0.x < $1.x }
        return MetricPayload(unit: unit, goal: goal, better: better,
                             summary: ["mean": round1(mean)],
                             series: ["D": daily, "M": monthly(daily)], events: nil)
    }

    static func sleep(_ rs: [SleepReading]) -> MetricPayload? {
        guard !rs.isEmpty else { return nil }
        // Total asleep hours per day = UNION of asleep intervals: overlapping
        // two-source nights (iPhone + Watch) count once (never summed twice),
        // and awake/inBed are excluded rather than inflating the shared figure.
        let asleep: Set<SleepStage> = [.rem, .core, .deep, .asleepUnspecified]
        let byDay = Dictionary(grouping: rs) { dayKey($0.date) }
        let daily = byDay.map { SeriesPoint(x: $0.key, v: round1(SleepReading.mergedAsleepHours($0.value, asleep: asleep))) }
            .sorted { $0.x < $1.x }
        let mean = daily.isEmpty ? 0 : daily.map(\.v).reduce(0, +) / Double(daily.count)
        return MetricPayload(unit: "h", goal: 8, better: "hi",
                             summary: ["mean": round1(mean)],
                             series: ["D": daily, "M": monthly(daily)], events: nil)
    }

    static func workouts(_ ws: [WorkoutReading]) -> MetricPayload? {
        guard !ws.isEmpty else { return nil }
        let byType = Dictionary(grouping: ws, by: \.type).mapValues(\.count)
        let events = byType.map { EventCount(label: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
        let weeks = max(1.0, Double(spanDays(ws.map(\.start))) / 7.0)
        return MetricPayload(unit: "sessions", goal: nil, better: "hi",
                             summary: ["perWeek": round1(Double(ws.count) / weeks)],
                             series: nil, events: events)
    }

    // MARK: - Helpers

    static func monthly(_ daily: [SeriesPoint]) -> [SeriesPoint] {
        let byMonth = Dictionary(grouping: daily) { String($0.x.prefix(7)) } // yyyy-MM
        return byMonth.map { SeriesPoint(x: $0.key, v: round1($0.value.map(\.v).reduce(0, +) / Double($0.value.count))) }
            .sorted { $0.x < $1.x }
    }

    static func spanDays(_ dates: [Date]) -> Int {
        guard let lo = dates.min(), let hi = dates.max() else { return 1 }
        return max(1, Int(hi.timeIntervalSince(lo) / 86400))
    }

    static func round1(_ x: Double) -> Double { (x * 10).rounded() / 10 }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    static func dayKey(_ d: Date) -> String { dayFmt.string(from: d) }

    private static let isoFmt: ISO8601DateFormatter = ISO8601DateFormatter()
    static func iso(_ d: Date) -> String { isoFmt.string(from: d) }
}
