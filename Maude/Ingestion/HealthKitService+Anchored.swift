// HealthKitService+Anchored.swift — FR-ING-03/04: anchored incremental reads +
// observer queries + background delivery, with the query anchor persisted in
// ENCRYPTED on-device storage (EncryptedAnchorStore → KeyVault DEK), keyed to a
// device-local user scope (never UserDefaults, never a server id).
//
// Kept behind a capability protocol (`IncrementalHealthSource`) so the portable
// layer and the mock/demo providers never depend on HealthKit (NFR-PORT-01).
import Foundation

/// Framework-free summary of one incremental pass (what changed since the last
/// persisted anchor). No HealthKit types cross this seam.
public struct IngestDelta: Sendable, Equatable {
    public let changedTypes: [String]
    public let newSampleCount: Int
    public init(changedTypes: [String], newSampleCount: Int) {
        self.changedTypes = changedTypes
        self.newSampleCount = newSampleCount
    }
    public var hasChanges: Bool { newSampleCount > 0 }
}

/// Anchor-tracked incremental ingestion + background observation. Implemented by
/// `HealthKitService`; deliberately off the base `HealthDataProvider` so demo
/// sources and the portable code stay HealthKit-free.
public protocol IncrementalHealthSource: Sendable {
    /// Advance every MVP type from its persisted (encrypted) anchor, store the new
    /// anchors, and report what changed. Cheap when nothing is new.
    func ingestDelta() async throws -> IngestDelta

    /// Register an HKObserverQuery + background delivery per type. `onChange` may
    /// fire while the app is backgrounded when HealthKit reports new data.
    func startBackgroundObservers(_ onChange: @escaping @Sendable () -> Void) throws
    func stopBackgroundObservers()
}

/// Portable anchor-advance seam (no HealthKit). `advance` loads the current
/// persisted (encrypted) anchor, hands it to `fetch` (the source — real HealthKit
/// in prod, a fake in tests), persists the returned anchor, and reports how many
/// new samples arrived. This is the unit that makes "the anchor advances on each
/// sync" testable without a device.
public enum AnchorSync {
    @discardableResult
    public static func advance(
        store: EncryptedAnchorStore,
        key: String,
        fetch: (_ current: Data?) async throws -> (added: Int, anchor: Data?)
    ) async throws -> Int {
        let current = try store.load(for: key)
        let (added, newAnchor) = try await fetch(current)
        if let newAnchor { try store.save(newAnchor, for: key) }
        return added
    }
}

#if canImport(HealthKit)
import HealthKit

/// HKQueryAnchor ⇆ Data codec. Secure-coding archive so the bytes round-trip
/// losslessly; the resulting Data is what EncryptedAnchorStore seals at rest.
enum AnchorCodec {
    static func encode(_ anchor: HKQueryAnchor) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }
    static func decode(_ data: Data) throws -> HKQueryAnchor {
        guard let anchor = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: HKQueryAnchor.self, from: data) else {
            throw HealthProviderError.notConfigured
        }
        return anchor
    }
}

/// Holds the live observer queries (so they can be retained + stopped) and a
/// re-entrancy flag so an observer wake-up during an in-flight sync is coalesced
/// rather than running a second overlapping pass. Reference type (a struct
/// provider can't own mutable query handles).
final class ObserverRegistry: @unchecked Sendable {
    private var queries: [HKObserverQuery] = []
    private var syncing = false
    private let lock = NSLock()

    /// Re-entrancy guard: returns false if a sync is already running.
    func beginSync() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if syncing { return false }
        syncing = true
        return true
    }
    func endSync() {
        lock.lock(); syncing = false; lock.unlock()
    }

    func start(store: HKHealthStore,
               types: [(HKSampleType, HKUpdateFrequency)],
               onChange: @escaping @Sendable () -> Void) {
        for (type, freq) in types {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                onChange()
                completion()   // ack: tell HealthKit we handled this background wake
            }
            store.execute(q)
            lock.lock(); queries.append(q); lock.unlock()
            store.enableBackgroundDelivery(for: type, frequency: freq) { _, _ in }
        }
    }

    func stop(store: HKHealthStore) {
        lock.lock(); let qs = queries; queries.removeAll(); lock.unlock()
        qs.forEach { store.stop($0) }
        store.disableAllBackgroundDelivery { _, _ in }
    }
}

extension HealthKitService: IncrementalHealthSource {

    /// MVP sample types we track incrementally (mirrors the read set).
    static var observedTypes: [HKSampleType] {
        var t: [HKSampleType] = [HKObjectType.workoutType()]
        let qids: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN, .restingHeartRate, .stepCount,
            .activeEnergyBurned, .bloodGlucose,
        ]
        t += qids.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { t.append(sleep) }
        return t
    }

    /// Per-type background-delivery cadence: step count batches `.hourly` (high
    /// churn, low urgency); every other signal is `.immediate`.
    static var observedTypesWithFrequency: [(HKSampleType, HKUpdateFrequency)] {
        let steps = HKObjectType.quantityType(forIdentifier: .stepCount)
        return observedTypes.map { type in
            (type, (type == steps) ? .hourly : .immediate)
        }
    }

    public func ingestDelta() async throws -> IngestDelta {
        // Re-entrancy guard: an observer wake-up mid-sync is coalesced (no overlap).
        guard registry.beginSync() else { return IngestDelta(changedTypes: [], newSampleCount: 0) }
        defer { registry.endSync() }

        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }

        var changed: [String] = []
        var total = 0
        for type in Self.observedTypes {
            let key = type.identifier
            let added: Int
            if let anchors {
                // Resume from the encrypted, persisted anchor and advance it.
                added = try await AnchorSync.advance(store: anchors, key: key) { current in
                    let from = current.flatMap { try? AnchorCodec.decode($0) }
                    let (n, newAnchor) = try await self.queryAnchored(type, from: from)
                    return (n, try newAnchor.map { try AnchorCodec.encode($0) })
                }
            } else {
                // No encrypted store available → still fetch, just not persisted.
                added = try await queryAnchored(type, from: nil).added
            }
            if added > 0 { changed.append(key); total += added }
        }
        return IngestDelta(changedTypes: changed, newSampleCount: total)
    }

    public func startBackgroundObservers(_ onChange: @escaping @Sendable () -> Void) throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }
        registry.start(store: store, types: Self.observedTypesWithFrequency, onChange: onChange)
    }

    public func stopBackgroundObservers() {
        registry.stop(store: store)
    }

    /// One HKAnchoredObjectQuery from `anchor`; returns new-sample count + the
    /// advanced anchor.
    private func queryAnchored(_ type: HKSampleType, from anchor: HKQueryAnchor?) async throws -> (added: Int, anchor: HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { cont in
            let q = HKAnchoredObjectQuery(
                type: type, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit
            ) { _, added, _, newAnchor, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: (added?.count ?? 0, newAnchor)) }
            }
            store.execute(q)
        }
    }
}
#endif
