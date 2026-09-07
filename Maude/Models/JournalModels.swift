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
    /// Voice-note audio file (FR-JRN-04) — a filename inside the device-local
    /// VoiceNoteAudioStore, NEVER a remote reference. Local persistence only:
    /// journal sync uses DTOs (server stores text + timestamp), so the audio —
    /// and even its filename — never leaves the device.
    var audioFilename: String? = nil

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
        case audioFilename = "audio_filename"
    }

    // Full initialiser (sync mapping — MaudeBackendService / BackendMapping).
    init(id: UUID, userId: UUID? = nil, body: String, mood: Int? = nil,
         metrics: MetricSnapshot? = nil, tags: [String] = [],
         syncEnabled: Bool = false, createdAt: Date, updatedAt: Date) {
        self.id          = id
        self.userId      = userId
        self.body        = body
        self.mood        = mood
        self.metrics     = metrics
        self.tags        = tags
        self.syncEnabled = syncEnabled
        self.createdAt   = createdAt
        self.updatedAt   = updatedAt
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
