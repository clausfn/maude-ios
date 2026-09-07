// Entities.swift — L2 typed sample sources (DataModel v1 Reference §2.1).
//
// Each row carries `source` + `tier` + `provenance`. Every initializer runs the
// schema gate `validateTierProvenance` (clinical can never be SIMULATED).
// These @Model classes are the iOS persistence shape; the portable rules live
// in CoreTypes.swift. `provenance` is data-only and must never be rendered.
import Foundation
import SwiftData

// MARK: - Cardiometabolic

@Model
final class GlucoseSample: Provenanced {
    var ts: Date
    /// Canonical mmol/L (OD-07). mg/dL is converted at ingestion via GlucoseUnit.
    var mmol: Double
    /// Meal-time metadata retained per FR-ING-08 (e.g. "pre-meal", "fasting").
    var mealContext: String?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, mmol: Double, mealContext: String? = nil,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        guard mmol >= 0 else { throw DataModelError.invalidValue(field: "mmol") }
        self.ts = ts; self.mmol = mmol; self.mealContext = mealContext
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// InsulinDose is modelled at raw-event granularity (DataModel v1). NOTE: there
/// is **no insulin/dosing surface in MVP** (FR-REG-04) — this entity is a
/// data-layer source only and must not be rendered or used to print a dose.
@Model
final class InsulinDose: Provenanced {
    var ts: Date
    var kind: InsulinKind
    var units: Double
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, kind: InsulinKind, units: Double,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        guard units >= 0 else { throw DataModelError.invalidValue(field: "units") }
        self.ts = ts; self.kind = kind; self.units = units
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

@Model
final class HeartDaily: Provenanced {
    var date: Date
    var hrMean: Double?
    var hrMin: Double?
    var hrMax: Double?
    var hrvMean: Double?   // HRV-SDNN, ms
    var rhr: Double?       // resting HR, bpm
    var walkHr: Double?
    var hrRecovery: Double?
    var resp: Double?
    var spo2: Double?      // %
    var vo2max: Double?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(date: Date, hrMean: Double? = nil, hrMin: Double? = nil, hrMax: Double? = nil,
         hrvMean: Double? = nil, rhr: Double? = nil, walkHr: Double? = nil,
         hrRecovery: Double? = nil, resp: Double? = nil, spo2: Double? = nil,
         vo2max: Double? = nil, source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        self.date = date; self.hrMean = hrMean; self.hrMin = hrMin; self.hrMax = hrMax
        self.hrvMean = hrvMean; self.rhr = rhr; self.walkHr = walkHr
        self.hrRecovery = hrRecovery; self.resp = resp; self.spo2 = spo2; self.vo2max = vo2max
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

@Model
final class BPReading: Provenanced {
    var ts: Date
    var sys: Int   // mmHg
    var dia: Int   // mmHg
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, sys: Int, dia: Int,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        guard sys > 0, dia > 0 else { throw DataModelError.invalidValue(field: "bp") }
        self.ts = ts; self.sys = sys; self.dia = dia
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// AFib burden (%). D9: display-only — data layer only here; rendering is
/// signal + route-to-cardiologist, never interpretation (enforced in L3/UI).
@Model
final class AFibBurden: Provenanced {
    var ts: Date
    var pct: Double
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, pct: Double,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        guard (0...100).contains(pct) else { throw DataModelError.invalidValue(field: "pct") }
        self.ts = ts; self.pct = pct
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

// MARK: - Sleep, activity, body

@Model
final class SleepSegment: Provenanced {
    var date: Date
    var stage: SleepStage
    var hours: Double
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(date: Date, stage: SleepStage, hours: Double,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        guard hours >= 0 else { throw DataModelError.invalidValue(field: "hours") }
        self.date = date; self.stage = stage; self.hours = hours
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

@Model
final class Workout: Provenanced {
    var start: Date
    var end: Date
    var type: String
    var durMin: Double
    var kcal: Double?
    var distKm: Double?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(start: Date, end: Date, type: String, durMin: Double,
         kcal: Double? = nil, distKm: Double? = nil,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        self.start = start; self.end = end; self.type = type; self.durMin = durMin
        self.kcal = kcal; self.distKm = distKm
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

enum BodyCompositionSource: String, Codable, Sendable { case inBody = "InBody", withings = "Withings" }

@Model
final class BodyComposition: Provenanced {
    var ts: Date
    var weightKg: Double?
    var fatPct: Double?
    var fatKg: Double?
    var muscleKg: Double?
    var visceral: Double?
    var bmi: Double?
    var trunkFatPct: Double?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, weightKg: Double? = nil, fatPct: Double? = nil, fatKg: Double? = nil,
         muscleKg: Double? = nil, visceral: Double? = nil, bmi: Double? = nil,
         trunkFatPct: Double? = nil, source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        self.ts = ts; self.weightKg = weightKg; self.fatPct = fatPct; self.fatKg = fatKg
        self.muscleKg = muscleKg; self.visceral = visceral; self.bmi = bmi; self.trunkFatPct = trunkFatPct
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

/// Lab result with reference range for banding (DataModel v1: ref_low/ref_high).
@Model
final class LabResult: Provenanced {
    var ts: Date
    var analyte: String
    var value: Double
    var unit: String
    var refLow: Double?
    var refHigh: Double?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, analyte: String, value: Double, unit: String,
         refLow: Double? = nil, refHigh: Double? = nil,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        self.ts = ts; self.analyte = analyte; self.value = value; self.unit = unit
        self.refLow = refLow; self.refHigh = refHigh
        self.source = source; self.tier = tier; self.provenance = provenance
    }

    /// Type-safe clinical constructor: cannot be called with SIMULATED data
    /// because `ClinicalProvenance` has no `.simulated` case.
    convenience init(clinicalAt ts: Date, analyte: String, value: Double, unit: String,
                     refLow: Double? = nil, refHigh: Double? = nil,
                     source: String, provenance: ClinicalProvenance) throws {
        try self.init(ts: ts, analyte: analyte, value: value, unit: unit,
                      refLow: refLow, refHigh: refHigh,
                      source: source, tier: .clinical, provenance: provenance.provenance)
    }
}

// MARK: - Medication

@Model
final class MedicationRecord: Provenanced {
    var name: String
    var dose: String?
    var drugClass: String?
    var indication: String?
    var since: Date?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(name: String, dose: String? = nil, drugClass: String? = nil,
         indication: String? = nil, since: Date? = nil,
         source: String, tier: DataTier, provenance: Provenance) throws {
        try validateTierProvenance(tier, provenance)
        self.name = name; self.dose = dose; self.drugClass = drugClass
        self.indication = indication; self.since = since
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

@Model
final class MedicationInteraction {
    var a: String
    var b: String
    var note: String

    init(a: String, b: String, note: String) {
        self.a = a; self.b = b; self.note = note
    }
}

// MARK: - External context (DataModel v1 §2.1, provenance = EXTERNAL)

@Model
final class WeatherContext: Provenanced {
    var ts: Date
    var tempC: Double?
    var precipMm: Double?
    var aqi: Int?       // populated only when air-quality is connected
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(ts: Date, tempC: Double? = nil, precipMm: Double? = nil, aqi: Int? = nil,
         source: String = "Open-Meteo", tier: DataTier = .estimate,
         provenance: Provenance = .external) throws {
        try validateTierProvenance(tier, provenance)
        self.ts = ts; self.tempC = tempC; self.precipMm = precipMm; self.aqi = aqi
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}

@Model
final class CalendarLoad: Provenanced {
    var date: Date
    var meetingHours: Double
    var label: String?
    var source: String
    var tier: DataTier
    var provenance: Provenance

    init(date: Date, meetingHours: Double, label: String? = nil,
         source: String = "Calendar", tier: DataTier = .estimate,
         provenance: Provenance = .real) throws {
        try validateTierProvenance(tier, provenance)
        self.date = date; self.meetingHours = meetingHours; self.label = label
        self.source = source; self.tier = tier; self.provenance = provenance
    }
}
