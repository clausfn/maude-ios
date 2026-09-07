// HealthContext.swift — Self-declared baseline data. Things only the user knows.
// v01 · 2026-05-22
// Rule: if a sensor or API could eventually infer it, it belongs in PassportStats (derived).
//       If only the user knows it, it lives here.
import Foundation

// MARK: - Condition

struct ConditionEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String           // e.g. "LADA / Type 1 Diabetes"
    var diagnosedYear: Int?    // e.g. 2015
    var notes: String?         // e.g. "Confirmed GAD-65 antibodies"
}

// MARK: - Medication

struct MedicationEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String           // e.g. "Insulin Degludec (Tresiba)"
    var dose: String           // e.g. "10 U"
    var frequency: String      // e.g. "Once daily, evening"
}

// MARK: - Clinical targets

/// Values set by a clinician or agreed in a care plan — not derivable from raw sensor data.
struct ClinicalTargets: Codable, Equatable {
    var glucoseRangeLow: Double?   // mmol/L,  e.g. 4.0
    var glucoseRangeHigh: Double?  // mmol/L,  e.g. 10.0
    var hbA1cTarget: Double?       // mmol/mol, e.g. 48
    var tirTarget: Int?            // %, e.g. 80
    var restingHRCeiling: Int?     // bpm, e.g. 100
}

// MARK: - Goal

struct GoalEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String               // plain language, e.g. "Keep TIR above 80%"
    var createdAt: Date = Date()
}

// MARK: - Care team

/// People or functions the user might share data with.
/// Role + organisation matters more than a person's name — roles persist, people change.
struct CareTeamMember: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var role: String               // e.g. "Diabetes Nurse"
    var organisation: String       // e.g. "University Hospital"
    var name: String?              // optional — user may not know the specific person
}

// MARK: - HealthContext (root)

struct HealthContext: Codable, Equatable {
    var conditions:     [ConditionEntry]  = []
    var medications:    [MedicationEntry] = []
    var targets:        ClinicalTargets   = ClinicalTargets()
    var goals:          [GoalEntry]       = []
    var careTeam:       [CareTeamMember]  = []
    var dietApproach:   String            = ""   // "Low-carb", "Mediterranean", free text
    var trainingPattern: String           = ""   // "Cycling 4× / week, 60–90 min"
}

// MARK: - Demo seed

extension HealthContext {
    static let demo = HealthContext(
        conditions: [
            ConditionEntry(
                name: String(localized: "LADA / Type 1 Diabetes"),
                diagnosedYear: 2015,
                notes: String(localized: "Confirmed GAD-65 antibodies. Basal-bolus insulin since 2022.")
            ),
            ConditionEntry(
                name: String(localized: "Paroxysmal Atrial Fibrillation"),
                diagnosedYear: 2021,
                notes: String(localized: "DOAC. Self-detected on Apple Watch. LVEF 45%.")
            )
        ],
        medications: [
            MedicationEntry(name: "Insulin Degludec (Tresiba)",  dose: "10 U",  frequency: String(localized: "Once daily, evening")),
            MedicationEntry(name: "Apixaban (Eliquis)",          dose: "5 mg",  frequency: String(localized: "Twice daily")),
            MedicationEntry(name: "Metoprolol",                  dose: "25 mg", frequency: String(localized: "Once daily, morning"))
        ],
        targets: ClinicalTargets(
            glucoseRangeLow:  4.0,
            glucoseRangeHigh: 10.0,
            hbA1cTarget:      48,
            tirTarget:        80,
            restingHRCeiling: 100
        ),
        goals: [
            GoalEntry(text: String(localized: "Keep TIR above 80%")),
            GoalEntry(text: String(localized: "Reduce nocturnal lows")),
            GoalEntry(text: String(localized: "Run half marathon in October"))
        ],
        careTeam: [
            CareTeamMember(role: String(localized: "Diabetes Nurse"),    organisation: String(localized: "University Hospital"),     name: nil),
            CareTeamMember(role: String(localized: "Cardiologist"),      organisation: String(localized: "Heart Centre"),            name: nil),
            CareTeamMember(role: String(localized: "Sports Coach"),      organisation: "Yourcoach.health",        name: nil)
        ],
        dietApproach:    String(localized: "Low-carbohydrate"),
        trainingPattern: String(localized: "Cycling 4× / week, 60–90 min. Occasional running.")
    )
}
