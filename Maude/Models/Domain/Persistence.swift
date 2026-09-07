// Persistence.swift — on-device SwiftData store (OD-09).
//
// The local store is on-device only. `cloudKitDatabase: .none` is explicit:
// raw samples, sample-granularity derived metrics, and workouts NEVER leave the
// device (NFR-PRIV-01). The thin opt-in cloud (consent grants, ledger, journal-
// if-synced) is a SEPARATE store and never holds these entities.
//
// PR-2 establishes the schema + an encrypted-at-rest store (file protection
// complete). The verified AES-256 + Secure-Enclave key-wrap primitive (NFR-SEC-02)
// lives in `Maude/Security/` (`CryptoBox`/`KeyWrap`/`KeyVault`, PR-8) and is the
// sanctioned way to encrypt any blob the app holds outside this store (exports,
// caches, journal-if-synced). Ingestion (PR-4) is this store's first writer.
// Tests use the in-memory variant.
import Foundation
import SwiftData

enum MaudeStore {
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
        // Canonical, source-agnostic health record (Sundhed live/PDF, OCR, HealthKit,
        // manual…). On-device only; leaves only by explicit user action.
        HealthObservation.self,
        HealthCondition.self,
        HealthMedication.self,
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

    /// Encrypt the store at rest with the DATABASE-appropriate protection level.
    ///
    /// MUST be `.completeUntilFirstUserAuthentication`, NOT `.complete`:
    ///  · `.complete` evicts the file's key whenever the device locks, making the
    ///    SQLite file UNREADABLE while locked / on a background relaunch. With WAL
    ///    journaling (SwiftData's default) the `-wal`/`-shm` siblings kept the OS
    ///    default level, so the main `.store` could become inaccessible before the
    ///    WAL checkpointed — writes were recorded, then RANDOMLY lost when the device
    ///    locked. (That is the "data came in, then disappeared, seems random" bug.)
    ///  · `.completeUntilFirstUserAuthentication` keeps the file encrypted at rest but
    ///    available from the first unlock after boot until reboot — the standard,
    ///    correct level for an app database, and what Core Data/SwiftData default to.
    ///
    /// Applied to the store AND its `-wal` / `-shm` companions so all three files share
    /// one consistent, lock-safe protection level.
    private static func applyFileProtection(to url: URL) {
        let level = FileProtectionType.completeUntilFirstUserAuthentication
        let base = url.path
        for path in [base, base + "-wal", base + "-shm"] {
            try? FileManager.default.setAttributes([.protectionKey: level], ofItemAtPath: path)
        }
    }
}
