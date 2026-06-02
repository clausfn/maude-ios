// Persistence.swift — on-device SwiftData store (OD-09).
//
// The local store is on-device only. `cloudKitDatabase: .none` is explicit:
// raw samples, sample-granularity derived metrics, and workouts NEVER leave the
// device (NFR-PRIV-01). The thin opt-in cloud (consent grants, ledger, journal-
// if-synced) is a SEPARATE store and never holds these entities.
//
// PR-2 establishes the schema + an encrypted-at-rest store (file protection
// complete). Full AES-256 verification + Secure Enclave key wrapping is PR-7
// (NFR-SEC-02). This factory is not yet wired into app launch; ingestion (PR-4)
// becomes its first writer. Tests use the in-memory variant.
import Foundation
import SwiftData

enum LiviqaStore {
    /// Every on-device sample/source entity (DataModel v1 §2.1).
    static let models: [any PersistentModel.Type] = [
        GlucoseSample.self,
        InsulinDose.self,
        HeartDaily.self,
        BPReading.self,
        AFibBurden.self,
        SleepSegment.self,
        Workout.self,
        BodyComposition.self,
        LabResult.self,
        MedicationRecord.self,
        MedicationInteraction.self,
        WeatherContext.self,
        CalendarLoad.self,
    ]

    static var schema: Schema { Schema(models) }

    /// Build the on-device model container.
    /// - Parameter inMemory: ephemeral store for tests/previews (no disk, no encryption).
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: .none   // on-device only — no cloud sync of samples
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        if !inMemory {
            applyFileProtection(to: configuration.url)
        }
        return container
    }

    /// Best-effort: mark the store file as `complete` data protection (hardware
    /// AES, key evicted when the device locks). Hardened further in PR-7.
    private static func applyFileProtection(to url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}
