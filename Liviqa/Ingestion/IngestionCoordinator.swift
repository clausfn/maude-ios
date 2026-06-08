// IngestionCoordinator.swift — L1→L2 normalization + persistence.
//
// Pulls a `HealthSamples` aggregate from the active provider and maps it into
// the SwiftData entities (DataModel v1). Read-only upstream (FR-ARCH-04); the
// only writes are to the on-device store. provenance flows through untouched
// and is never surfaced. Re-syncing a date range is idempotent: existing rows
// in the window are replaced (no duplicate accretion).
//
// NOTE: steps + active energy are read at L1 but have no raw entity in
// DataModel v1 — they feed L3 derived activity/recovery streams (PR-5), so they
// stay on the in-memory `HealthSamples` rather than being persisted here.
import Foundation
import SwiftData

/// Counts written, for UI/QMS feedback. Carries no health values.
public struct IngestSummary: Sendable, Equatable {
    public var glucose = 0
    public var heartDaily = 0
    public var sleep = 0
    public var workouts = 0
    public var insulin = 0
    public var bloodPressure = 0
    public var afib = 0
    public var bodyComposition = 0
    public var total: Int {
        glucose + heartDaily + sleep + workouts
            + insulin + bloodPressure + afib + bodyComposition
    }
}

/// Pure mapping (HealthSamples → entities). Static + throwing (schema gates).
enum SampleMapper {
    static func glucose(_ s: HealthSamples) throws -> [GlucoseSample] {
        try s.glucose.map {
            try GlucoseSample(ts: $0.ts, mmol: $0.mmol, mealContext: $0.mealContext,
                              source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    /// Merge the full daily heart/respiratory panel into one HeartDaily per day
    /// (HRV-SDNN, resting/mean/walking HR, HR-recovery, respiratory rate, SpO₂, VO₂max).
    static func heartDaily(_ s: HealthSamples) throws -> [HeartDaily] {
        let cal = Calendar(identifier: .gregorian)
        struct Acc {
            var hrMean: Double?, hrv: Double?, rhr: Double?, walkHr: Double?
            var hrRecovery: Double?, resp: Double?, spo2: Double?, vo2max: Double?
            var source = "", tier: DataTier = .good, prov: Provenance = .real
        }
        var byDay: [Date: Acc] = [:]
        for m in s.hrv + s.restingHR + s.heartExtras {
            let day = cal.startOfDay(for: m.date)
            var cur = byDay[day] ?? Acc()
            cur.source = m.source; cur.prov = m.provenance
            switch m.kind {
            case .hrvSDNN:         cur.hrv = m.value
            case .restingHR:       cur.rhr = m.value
            case .heartRate:       cur.hrMean = m.value
            case .walkingHR:       cur.walkHr = m.value
            case .hrRecovery:      cur.hrRecovery = m.value
            case .respiratoryRate: cur.resp = m.value
            case .spo2:            cur.spo2 = m.value
            case .vo2max:          cur.vo2max = m.value
            case .steps, .activeEnergy: break   // not heart metrics
            }
            // Keep the most cautious (lowest) tier across merged metrics.
            if m.tier == .estimate { cur.tier = .estimate }
            byDay[day] = cur
        }
        return try byDay.map { day, v in
            try HeartDaily(date: day, hrMean: v.hrMean, hrvMean: v.hrv, rhr: v.rhr,
                           walkHr: v.walkHr, hrRecovery: v.hrRecovery, resp: v.resp,
                           spo2: v.spo2, vo2max: v.vo2max,
                           source: v.source.isEmpty ? "HealthKit" : v.source,
                           tier: v.tier, provenance: v.prov)
        }.sorted { $0.date < $1.date }
    }

    static func insulin(_ s: HealthSamples) throws -> [InsulinDose] {
        try s.insulin.map {
            try InsulinDose(ts: $0.ts, kind: $0.kind, units: $0.units,
                            source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    static func bloodPressure(_ s: HealthSamples) throws -> [BPReading] {
        try s.bloodPressure.map {
            try BPReading(ts: $0.ts, sys: $0.sys, dia: $0.dia,
                          source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    static func afib(_ s: HealthSamples) throws -> [AFibBurden] {
        try s.afib.map {
            try AFibBurden(ts: $0.ts, pct: $0.pct,
                           source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    static func bodyComposition(_ s: HealthSamples) throws -> [BodyComposition] {
        try s.bodyComposition.map {
            // leanKg → muscleKg (closest standard field); visceral/trunk-fat are InBody-only.
            try BodyComposition(ts: $0.ts, weightKg: $0.weightKg, fatPct: $0.fatPct,
                                muscleKg: $0.leanKg, bmi: $0.bmi,
                                source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    static func sleep(_ s: HealthSamples) throws -> [SleepSegment] {
        try s.sleep.map {
            try SleepSegment(date: $0.date, stage: $0.stage, hours: $0.hours,
                             source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    static func workouts(_ s: HealthSamples) throws -> [Workout] {
        try s.workouts.map {
            try Workout(start: $0.start, end: $0.end, type: $0.type, durMin: $0.durMin,
                        kcal: $0.kcal, distKm: $0.distKm,
                        source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }
}

@MainActor
public final class IngestionCoordinator {
    private let context: ModelContext
    private let provider: any HealthDataProvider

    public init(context: ModelContext, provider: any HealthDataProvider) {
        self.context = context
        self.provider = provider
    }

    /// True when the active source is synthetic — drives the FR-ARCH-05 badge.
    public var isDemoData: Bool { provider.kind.isDemoData }

    public func requestAuthorization() async throws {
        try await provider.requestReadAuthorization()
    }

    /// Fetch + normalize + persist a date range. Idempotent (replaces the window).
    @discardableResult
    public func sync(from start: Date, to end: Date) async throws -> IngestSummary {
        let samples = try await provider.fetchSamples(from: start, to: end)
        return try persist(samples, from: start, to: end)
    }

    /// Normalize + persist already-fetched samples (lets a caller fetch once and
    /// reuse the samples for L3 nudges). Idempotent over the window.
    @discardableResult
    public func persist(_ samples: HealthSamples, from start: Date, to end: Date) throws -> IngestSummary {
        let glucose = try SampleMapper.glucose(samples)
        let heart = try SampleMapper.heartDaily(samples)
        let sleep = try SampleMapper.sleep(samples)
        let workouts = try SampleMapper.workouts(samples)
        let insulin = try SampleMapper.insulin(samples)
        let bp = try SampleMapper.bloodPressure(samples)
        let afib = try SampleMapper.afib(samples)
        let body = try SampleMapper.bodyComposition(samples)

        try replaceGlucose(in: start...end, with: glucose)
        try replaceHeartDaily(in: start...end, with: heart)
        try replaceSleep(in: start...end, with: sleep)
        try replaceWorkouts(in: start...end, with: workouts)
        try replaceInsulin(in: start...end, with: insulin)
        try replaceBloodPressure(in: start...end, with: bp)
        try replaceAFib(in: start...end, with: afib)
        try replaceBodyComposition(in: start...end, with: body)
        try context.save()

        return IngestSummary(glucose: glucose.count, heartDaily: heart.count,
                             sleep: sleep.count, workouts: workouts.count,
                             insulin: insulin.count, bloodPressure: bp.count,
                             afib: afib.count, bodyComposition: body.count)
    }

    // MARK: replace-range helpers (idempotent re-sync)

    /// Delete bounds = the requested window expanded to cover every row about to
    /// be inserted, so a re-sync deletes the prior rows in full — idempotent even
    /// when a provider returns boundary samples whose timestamp falls just outside
    /// the window (e.g. a daily reading near `from`/`to`). Drops no in-window data.
    private func bounds(_ range: ClosedRange<Date>, _ dates: [Date]) -> (Date, Date) {
        (min(range.lowerBound, dates.min() ?? range.lowerBound),
         max(range.upperBound, dates.max() ?? range.upperBound))
    }

    private func replaceGlucose(in range: ClosedRange<Date>, with rows: [GlucoseSample]) throws {
        let (lo, hi) = bounds(range, rows.map(\.ts))
        try context.delete(model: GlucoseSample.self,
                           where: #Predicate { $0.ts >= lo && $0.ts <= hi })
        rows.forEach(context.insert)
    }

    private func replaceHeartDaily(in range: ClosedRange<Date>, with rows: [HeartDaily]) throws {
        let (lo, hi) = bounds(range, rows.map(\.date))
        try context.delete(model: HeartDaily.self,
                           where: #Predicate { $0.date >= lo && $0.date <= hi })
        rows.forEach(context.insert)
    }

    private func replaceSleep(in range: ClosedRange<Date>, with rows: [SleepSegment]) throws {
        let (lo, hi) = bounds(range, rows.map(\.date))
        try context.delete(model: SleepSegment.self,
                           where: #Predicate { $0.date >= lo && $0.date <= hi })
        rows.forEach(context.insert)
    }

    private func replaceWorkouts(in range: ClosedRange<Date>, with rows: [Workout]) throws {
        let (lo, hi) = bounds(range, rows.map(\.start))
        try context.delete(model: Workout.self,
                           where: #Predicate { $0.start >= lo && $0.start <= hi })
        rows.forEach(context.insert)
    }

    private func replaceInsulin(in range: ClosedRange<Date>, with rows: [InsulinDose]) throws {
        let (lo, hi) = bounds(range, rows.map(\.ts))
        try context.delete(model: InsulinDose.self,
                           where: #Predicate { $0.ts >= lo && $0.ts <= hi })
        rows.forEach(context.insert)
    }

    private func replaceBloodPressure(in range: ClosedRange<Date>, with rows: [BPReading]) throws {
        let (lo, hi) = bounds(range, rows.map(\.ts))
        try context.delete(model: BPReading.self,
                           where: #Predicate { $0.ts >= lo && $0.ts <= hi })
        rows.forEach(context.insert)
    }

    private func replaceAFib(in range: ClosedRange<Date>, with rows: [AFibBurden]) throws {
        let (lo, hi) = bounds(range, rows.map(\.ts))
        try context.delete(model: AFibBurden.self,
                           where: #Predicate { $0.ts >= lo && $0.ts <= hi })
        rows.forEach(context.insert)
    }

    private func replaceBodyComposition(in range: ClosedRange<Date>, with rows: [BodyComposition]) throws {
        let (lo, hi) = bounds(range, rows.map(\.ts))
        try context.delete(model: BodyComposition.self,
                           where: #Predicate { $0.ts >= lo && $0.ts <= hi })
        rows.forEach(context.insert)
    }
}
