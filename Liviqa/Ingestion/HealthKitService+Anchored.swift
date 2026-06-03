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

/// Holds the live observer queries so they can be retained and stopped. Reference
/// type (a struct provider can't own mutable query handles).
final class ObserverRegistry: @unchecked Sendable {
    private var queries: [HKObserverQuery] = []
    private let lock = NSLock()

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

    /// Per-type background-delivery cadence: glucose is time-critical (.immediate);
    /// the rest batch hourly to spare the battery.
    static var observedTypesWithFrequency: [(HKSampleType, HKUpdateFrequency)] {
        observedTypes.map { type in
            let isGlucose = (type as? HKQuantityType) == HKObjectType.quantityType(forIdentifier: .bloodGlucose)
            return (type, isGlucose ? .immediate : .hourly)
        }
    }

    public func ingestDelta() async throws -> IngestDelta {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthProviderError.unavailableOnPlatform
        }
        var changed: [String] = []
        var total = 0
        for type in Self.observedTypes {
            let key = type.identifier
            let (added, newAnchor) = try await runAnchored(type, anchorKey: key)
            if added > 0 { changed.append(key); total += added }
            if let newAnchor { try? anchors?.save(try AnchorCodec.encode(newAnchor), for: key) }
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

    /// Run one HKAnchoredObjectQuery from the persisted (decrypted) anchor;
    /// returns the count of new samples + the advanced anchor.
    private func runAnchored(_ type: HKSampleType, anchorKey: String) async throws -> (added: Int, anchor: HKQueryAnchor?) {
        let storedData: Data? = (try? anchors?.load(for: anchorKey)) ?? nil
        let stored = storedData.flatMap { try? AnchorCodec.decode($0) }
        return try await withCheckedThrowingContinuation { cont in
            let q = HKAnchoredObjectQuery(
                type: type, predicate: nil, anchor: stored, limit: HKObjectQueryNoLimit
            ) { _, added, _, newAnchor, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: (added?.count ?? 0, newAnchor)) }
            }
            store.execute(q)
        }
    }
}
#endif
