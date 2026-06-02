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
    public var total: Int { glucose + heartDaily + sleep + workouts }
}

/// Pure mapping (HealthSamples → entities). Static + throwing (schema gates).
enum SampleMapper {
    static func glucose(_ s: HealthSamples) throws -> [GlucoseSample] {
        try s.glucose.map {
            try GlucoseSample(ts: $0.ts, mmol: $0.mmol, mealContext: $0.mealContext,
                              source: $0.source, tier: $0.tier, provenance: $0.provenance)
        }
    }

    /// Merge HRV-SDNN + resting-HR daily metrics into one HeartDaily per day.
    static func heartDaily(_ s: HealthSamples) throws -> [HeartDaily] {
        let cal = Calendar(identifier: .gregorian)
        var byDay: [Date: (hrv: Double?, rhr: Double?, source: String, tier: DataTier, prov: Provenance)] = [:]
        for m in s.hrv + s.restingHR {
            let day = cal.startOfDay(for: m.date)
            var cur = byDay[day] ?? (nil, nil, m.source, m.tier, m.provenance)
            switch m.kind {
            case .hrvSDNN:   cur.hrv = m.value
            case .restingHR: cur.rhr = m.value
            default:         break
            }
            // Keep the most cautious (lowest) tier across merged metrics.
            if m.tier == .estimate { cur.tier = .estimate }
            byDay[day] = cur
        }
        return try byDay.map { day, v in
            try HeartDaily(date: day, hrvMean: v.hrv, rhr: v.rhr,
                           source: v.source, tier: v.tier, provenance: v.prov)
        }.sorted { $0.date < $1.date }
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

        let glucose = try SampleMapper.glucose(samples)
        let heart = try SampleMapper.heartDaily(samples)
        let sleep = try SampleMapper.sleep(samples)
        let workouts = try SampleMapper.workouts(samples)

        try replaceGlucose(in: start...end, with: glucose)
        try replaceHeartDaily(in: start...end, with: heart)
        try replaceSleep(in: start...end, with: sleep)
        try replaceWorkouts(in: start...end, with: workouts)
        try context.save()

        return IngestSummary(glucose: glucose.count, heartDaily: heart.count,
                             sleep: sleep.count, workouts: workouts.count)
    }

    // MARK: replace-range helpers (idempotent re-sync)

    private func replaceGlucose(in range: ClosedRange<Date>, with rows: [GlucoseSample]) throws {
        let lo = range.lowerBound, hi = range.upperBound
        try context.delete(model: GlucoseSample.self,
                           where: #Predicate { $0.ts >= lo && $0.ts <= hi })
        rows.forEach(context.insert)
    }

    private func replaceHeartDaily(in range: ClosedRange<Date>, with rows: [HeartDaily]) throws {
        let lo = range.lowerBound, hi = range.upperBound
        try context.delete(model: HeartDaily.self,
                           where: #Predicate { $0.date >= lo && $0.date <= hi })
        rows.forEach(context.insert)
    }

    private func replaceSleep(in range: ClosedRange<Date>, with rows: [SleepSegment]) throws {
        let lo = range.lowerBound, hi = range.upperBound
        try context.delete(model: SleepSegment.self,
                           where: #Predicate { $0.date >= lo && $0.date <= hi })
        rows.forEach(context.insert)
    }

    private func replaceWorkouts(in range: ClosedRange<Date>, with rows: [Workout]) throws {
        let lo = range.lowerBound, hi = range.upperBound
        try context.delete(model: Workout.self,
                           where: #Predicate { $0.start >= lo && $0.start <= hi })
        rows.forEach(context.insert)
    }
}
