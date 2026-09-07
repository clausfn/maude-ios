// BodyTrendDeriver.swift — everything the A7.2 Body / composition screen shows,
// derived on device from local `HealthSamples`. Pure Foundation (NFR-PORT-01).
//
// PERSONAL CORRIDOR ONLY: the shaded corridor is the user's own mean ±1σ over
// the local window — never a BMI class, never a goal weight (FR-NDG-06 rail).
// MILESTONES DERIVED, NEVER INVENTED: the only annotation ever produced is
// "lowest/highest in this window" for the latest reading, computed from the
// series itself.
//
// WINDOW HONESTY: the live fetch spans 30 days (90 on first run), so the trend
// covers whatever history the window carries; `sinceMonthName` reports the true
// start so the screen never claims "since March" beyond its data. (Extending to
// the persisted store's full history is a named open item.)
//
// nil ⇒ no body-composition rows → demo seeds / honest empty state.
import Foundation

public nonisolated struct BodyTrendDetail: Sendable, Equatable {

    public let weightSeries: [Double]          // per-day kg, oldest → latest
    public let weightCorridor: ClosedRange<Double>?
    public let fatSeries: [Double]             // per-day %, oldest → latest
    public let fatCorridor: ClosedRange<Double>?

    public let latestWeightKg: Double?
    public let latestFatPct: Double?
    public let latestLeanKg: Double?
    public let latestBMI: Double?

    /// last − first over the weight series (≥2 points), kg (1 dp).
    public let weightDeltaKg: Double?
    /// last − first over the lean series (≥2 points), kg (1 dp).
    public let leanDeltaKg: Double?
    /// True when the latest weight is the window's lowest / highest.
    public let latestIsWindowLow: Bool
    public let latestIsWindowHigh: Bool

    /// "July" — the month the window's data actually starts.
    public let sinceMonthName: String
    public let xLabels: [String]               // ["Jun", "Jul", "Aug"]
    public let source: String?

    public init(weightSeries: [Double], weightCorridor: ClosedRange<Double>?,
                fatSeries: [Double], fatCorridor: ClosedRange<Double>?,
                latestWeightKg: Double?, latestFatPct: Double?,
                latestLeanKg: Double?, latestBMI: Double?, weightDeltaKg: Double?,
                leanDeltaKg: Double?, latestIsWindowLow: Bool,
                latestIsWindowHigh: Bool, sinceMonthName: String,
                xLabels: [String], source: String?) {
        self.weightSeries = weightSeries; self.weightCorridor = weightCorridor
        self.fatSeries = fatSeries; self.fatCorridor = fatCorridor
        self.latestWeightKg = latestWeightKg; self.latestFatPct = latestFatPct
        self.latestLeanKg = latestLeanKg; self.latestBMI = latestBMI
        self.weightDeltaKg = weightDeltaKg; self.leanDeltaKg = leanDeltaKg
        self.latestIsWindowLow = latestIsWindowLow
        self.latestIsWindowHigh = latestIsWindowHigh
        self.sinceMonthName = sinceMonthName; self.xLabels = xLabels
        self.source = source
    }
}

public nonisolated enum BodyTrendDeriver {

    private static let cal = Calendar(identifier: .gregorian)
    private static let monthNames = ["January", "February", "March", "April", "May",
                                     "June", "July", "August", "September",
                                     "October", "November", "December"]

    public static func derive(from s: HealthSamples, now: Date = Date()) -> BodyTrendDetail? {
        let rows = s.bodyComposition.sorted { $0.ts < $1.ts }
        guard !rows.isEmpty else { return nil }

        let weights = rows.compactMap { r in r.weightKg.map { (r.ts, ($0 * 10).rounded() / 10) } }
        let fats = rows.compactMap { r in r.fatPct.map { (r.ts, ($0 * 10).rounded() / 10) } }
        let leans = rows.compactMap { r in r.leanKg.map { (r.ts, ($0 * 10).rounded() / 10) } }

        let weightValues = weights.map(\.1)
        let fatValues = fats.map(\.1)

        let latest = rows.last
        let latestWeight = weights.last?.1
        let weightDelta: Double? = weightValues.count >= 2
            ? (((weightValues.last! - weightValues.first!) * 10).rounded() / 10) : nil
        let leanDelta: Double? = leans.count >= 2
            ? (((leans.last!.1 - leans.first!.1) * 10).rounded() / 10) : nil

        let firstDate = weights.first?.0 ?? rows.first!.ts
        let lastDate = weights.last?.0 ?? rows.last!.ts
        let sinceMonth = monthNames[(cal.component(.month, from: firstDate) - 1) % 12]

        let source = Dictionary(grouping: rows, by: \.source)
            .max { $0.value.count < $1.value.count }?.key

        return BodyTrendDetail(
            weightSeries: weightValues.count >= 2 ? weightValues : [],
            weightCorridor: HeartDetailDeriver.band(weightValues),
            fatSeries: fatValues.count >= 2 ? fatValues : [],
            fatCorridor: HeartDetailDeriver.band(fatValues),
            latestWeightKg: latestWeight,
            latestFatPct: fats.last?.1,
            latestLeanKg: leans.last?.1,
            latestBMI: rows.compactMap(\.bmi).last.map { ($0 * 10).rounded() / 10 },
            weightDeltaKg: weightDelta,
            leanDeltaKg: leanDelta,
            latestIsWindowLow: weightValues.count >= 5 && latestWeight != nil
                && latestWeight == weightValues.min(),
            latestIsWindowHigh: weightValues.count >= 5 && latestWeight != nil
                && latestWeight == weightValues.max(),
            sinceMonthName: sinceMonth,
            xLabels: weightValues.count >= 2
                ? FitnessDeriver.monthLabels(from: firstDate, to: lastDate) : [],
            source: latest.map { _ in source ?? "Apple Health" })
    }
}
