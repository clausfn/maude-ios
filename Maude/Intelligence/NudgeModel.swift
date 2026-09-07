// NudgeModel.swift — L3 on-device intelligence: output model (portable).
//
// The nudge output is a strict ALLOW-LIST (FR-NDG): verdict / number /
// band-status / behavioural-lever / route-to-clinician. Nothing else can be
// constructed. Output NEVER prints a dose or a diagnosis (enforced by
// `NudgeGuard`, FR-NDG-06). Everything is personal-baseline-relative — there are
// no clinical reference ranges here. Pure Foundation (Android-portable).
import Foundation

/// Each analytical stream is tagged with its regulatory lane (SRS L3 map).
public nonisolated enum RegulatoryLane: String, Sendable, CaseIterable {
    case wellness        // recovery, sleep, body-comp, activity
    case watch           // glucose, BP, labs — surface a number/band, no advice
    case constrained     // insulin×glucose, cross-signal — tightly bounded
    case displayOnly     // AFib/cardiac (D9): render + route, never interpret
}

/// Position of a value relative to the PERSONAL baseline band (not clinical).
public nonisolated enum Band: String, Sendable { case below, inBand, above }

/// Non-diagnostic qualitative summary words. Deliberately not clinical.
public nonisolated enum Verdict: String, Sendable {
    case onTrack, mixed, needsAttention
    var phrase: String {
        switch self {
        case .onTrack:        return String(localized: "tracking close to your usual pattern")
        case .mixed:          return String(localized: "a mixed picture versus your usual pattern")
        case .needsAttention: return String(localized: "drifting from your usual pattern")
        }
    }
}

/// Generic, non-medical behaviour suggestions. No drug/dose/treatment language.
public nonisolated enum Lever: String, Sendable {
    case windDown, earlierNight, move, getOutside, hydrate, breathe
    var phrase: String {
        switch self {
        case .windDown:     return String(localized: "A calmer wind-down tonight may help.")
        case .earlierNight: return String(localized: "An earlier night could help you catch up.")
        case .move:         return String(localized: "A short walk could be a good idea today.")
        case .getOutside:   return String(localized: "Some daylight and fresh air could help.")
        case .hydrate:      return String(localized: "Keeping your water topped up could help.")
        case .breathe:      return String(localized: "A few minutes of slow breathing may help you settle.")
        }
    }
}

public nonisolated enum Specialty: String, Sendable {
    case cardiologist, gp
    var phrase: String {
        switch self {
        case .cardiologist: return String(localized: "your cardiologist")
        case .gp:           return String(localized: "your doctor")
        }
    }
}

/// The allow-listed output categories. The engine can ONLY emit these.
public nonisolated enum NudgeCategory: String, Sendable, CaseIterable {
    case verdict, number, bandStatus, behaviouralLever, routeToClinician
}

/// A single capped nudge produced by the engine. `title`/`body` are user-facing
/// and MUST pass FR-NDG-06. NOTE: carries no `provenance` — that field never
/// reaches this layer. Named `EngineNudge` to stay distinct from the prototype's
/// presentation-layer `Nudge` card view-model (a future UI PR maps one to the other).
public nonisolated struct EngineNudge: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let category: NudgeCategory
    public let lane: RegulatoryLane
    public let title: String
    public let body: String
    public let priority: Int
    /// The numbers behind the sentence — shown in the card's "Why this?"
    /// expansion (transparency-first presentation, 2026-06-11). Optional so
    /// every existing emit stays valid.
    public let evidence: String?
    public let points: [String]

    public init(id: UUID = UUID(), category: NudgeCategory, lane: RegulatoryLane,
                title: String, body: String, priority: Int,
                evidence: String? = nil, points: [String] = []) {
        self.id = id; self.category = category; self.lane = lane
        self.title = title; self.body = body; self.priority = priority
        self.evidence = evidence; self.points = points
    }
}

/// Personal baseline (mean ± sd) over a metric's history. Not a clinical range.
public nonisolated struct Baseline: Sendable, Equatable {
    public let mean: Double
    public let sd: Double

    public init(mean: Double, sd: Double) { self.mean = mean; self.sd = sd }

    /// Requires ≥3 points to be meaningful; otherwise nil (no nudge fires).
    public static func from(_ values: [Double]) -> Baseline? {
        guard values.count >= 3 else { return nil }
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        let varc = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        return Baseline(mean: mean, sd: varc.squareRoot())
    }

    /// Band membership at ±k·sd (default 1σ). Flat history ⇒ always in-band.
    public func band(for value: Double, k: Double = 1.0) -> Band {
        guard sd > 0 else { return .inBand }
        if value < mean - k * sd { return .below }
        if value > mean + k * sd { return .above }
        return .inBand
    }
}

/// Clinical signals that live outside the HealthKit MVP read set (BP, AFib).
/// Optional; absent in the synthetic demo.
public nonisolated struct ClinicalSignals: Sendable {
    public var afibSignalPresent: Bool
    public init(afibSignalPresent: Bool = false) {
        self.afibSignalPresent = afibSignalPresent
    }
}
