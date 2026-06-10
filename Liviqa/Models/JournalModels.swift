// JournalModels.swift — Journal entries and embedded metric snapshots.
import Foundation

struct MetricSnapshot: Codable, Equatable {
    var glucoseMgdl: Double?
    var hrvMs: Double?
    var sleepHours: Double?
    var stepsCount: Int?
    var activeCalories: Double?

    enum CodingKeys: String, CodingKey {
        case glucoseMgdl    = "glucose_mgdl"
        case hrvMs          = "hrv_ms"
        case sleepHours     = "sleep_hours"
        case stepsCount     = "steps_count"
        case activeCalories = "active_calories"
    }

    static let empty = MetricSnapshot(
        glucoseMgdl: nil, hrvMs: nil,
        sleepHours: nil, stepsCount: nil, activeCalories: nil
    )
}

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var userId: UUID?
    var body: String
    var mood: Int?                    // 1–5 scale; nil = not rated
    var metrics: MetricSnapshot?
    var tags: [String]
    var syncEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case body
        case mood
        case metrics
        case tags
        case syncEnabled = "sync_enabled"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }

    // Local-only initialiser (pre-sync)
    init(body: String, mood: Int? = nil, tags: [String] = []) {
        self.id          = UUID()
        self.userId      = nil
        self.body        = body
        self.mood        = mood
        self.metrics     = .empty
        self.tags        = tags
        self.syncEnabled = false
        self.createdAt   = Date()
        self.updatedAt   = Date()
    }
}
