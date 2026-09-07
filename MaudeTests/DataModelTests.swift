// DataModelTests.swift — L2 data-model invariants (DataModel v1 Reference).
// Covers: clinical-tier rejects SIMULATED (the schema gate), mmol/L canonical
// (OD-07), the type-level clinical constructor, and SwiftData schema validity.
import Testing
import Foundation
import SwiftData
@testable import Maude

struct DataModelTests {

    // MARK: clinical rejects SIMULATED (DataModel v1 §2.1)

    @Test func clinicalRejectsSimulated_validator() {
        #expect(throws: DataModelError.clinicalRejectsSimulated) {
            try validateTierProvenance(.clinical, .simulated)
        }
    }

    @Test func clinicalRejectsSimulated_onConstruction() {
        #expect(throws: DataModelError.clinicalRejectsSimulated) {
            _ = try GlucoseSample(ts: Date(), mmol: 6.0,
                                  source: "LibreView", tier: .clinical, provenance: .simulated)
        }
    }

    @Test func clinicalReal_isAllowed() throws {
        let s = try GlucoseSample(ts: Date(), mmol: 6.0,
                                  source: "LibreView", tier: .clinical, provenance: .real)
        #expect(s.tier == .clinical)
        #expect(s.provenance == .real)
    }

    @Test func nonClinicalSimulated_isAllowed() throws {
        // Synthetic cohort rows are SIMULATED at good/estimate tier — permitted.
        let s = try GlucoseSample(ts: Date(), mmol: 5.4,
                                  source: "Cohort", tier: .estimate, provenance: .simulated)
        #expect(s.provenance == .simulated)
    }

    // MARK: type-level clinical constructor (ClinicalProvenance has no .simulated)

    @Test func clinicalLabFactory_setsClinicalTier() throws {
        let lab = try LabResult(clinicalAt: Date(), analyte: "HbA1c", value: 48, unit: "mmol/mol",
                                refLow: 20, refHigh: 42, source: "Sundhed.dk", provenance: .real)
        #expect(lab.tier == .clinical)
        #expect(lab.provenance == .real)
    }

    // MARK: glucose canonical unit (OD-07 / D10)

    @Test func glucoseConversion_mgdlToMmol() {
        #expect(abs(GlucoseUnit.mmol(fromMgdl: 180) - 9.99) < 0.01)
        #expect(abs(GlucoseUnit.mmol(fromMgdl: 90) - 4.99) < 0.01)
    }

    @Test func glucoseConversion_roundTrip() {
        let mmol = GlucoseUnit.mmol(fromMgdl: 126)
        #expect(abs(GlucoseUnit.mgdl(fromMmol: mmol) - 126) < 0.0001)
    }

    @Test func invalidValue_isRejected() {
        #expect(throws: DataModelError.invalidValue(field: "pct")) {
            _ = try AFibBurden(ts: Date(), pct: 150, source: "Apple Watch",
                               tier: .good, provenance: .real)
        }
    }

    // MARK: SwiftData schema loads and round-trips

    @MainActor
    @Test func schemaLoadsAndPersists() throws {
        let container = try MaudeStore.makeContainer(inMemory: true)
        let ctx = container.mainContext

        ctx.insert(try GlucoseSample(ts: Date(), mmol: 6.1, source: "Dexcom",
                                     tier: .good, provenance: .real))
        ctx.insert(try BPReading(ts: Date(), sys: 120, dia: 80, source: "Withings",
                                 tier: .good, provenance: .real))
        ctx.insert(try AFibBurden(ts: Date(), pct: 2.0, source: "Apple Watch",
                                  tier: .good, provenance: .real))
        try ctx.save()

        let glucose = try ctx.fetch(FetchDescriptor<GlucoseSample>())
        #expect(glucose.count == 1)
        #expect(abs((glucose.first?.mmol ?? 0) - 6.1) < 0.0001)
    }
}
