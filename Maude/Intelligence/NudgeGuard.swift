// NudgeGuard.swift — FR-NDG-06 forbidden-construction check (DESIGNATED CONTROL).
//
// This is a safety control, not a convenience. Its tests are BLOCKING and may
// never be skipped or marked allow-fail. Every user-facing nudge string must
// pass `check(...) == nil`. It rejects three construction classes:
//   1. dosing/treatment language (a dose, or "adjust/take your insulin/meds")
//   2. affirmative diagnostic claims ("you have X", "diagnosed with", "detected")
//   3. clinical-normality verdicts ("normal/abnormal", "within normal limits")
//
// It is intentionally phrased to catch affirmative *claims* — disclaimers like
// "this is not a diagnosis" must still pass. Pure Foundation (Android-portable).
import Foundation

public nonisolated enum ForbiddenConstruction: String, Sendable, CaseIterable {
    case dose                  // a numeric dose, e.g. "12 units", "500 mg"
    case treatmentDirective    // "adjust/take/stop your insulin/medication/dose"
    case dosingVerb            // "inject", "bolus", "titrate", "administer"
    case diagnosticClaim       // "you have …", "diagnosed with …", "… detected"
    case clinicalNormality     // "normal/abnormal", "within normal limits"
}

public nonisolated enum NudgeGuard {

    /// (case, regex pattern) — matched case-insensitively against title+body.
    private static let rules: [(ForbiddenConstruction, String)] = [
        // 1. Dose quantity: a number followed by a dose unit. mmol/L is NOT a
        //    dose unit, so glucose numbers (e.g. "6.4 mmol/L") are allowed.
        (.dose, #"(?i)\b\d+(\.\d+)?\s?(u|iu|units?|mg|mcg|µg|ml|grams?)\b"#),
        // 2. Treatment directive aimed at meds/insulin/dose.
        (.treatmentDirective,
         #"(?i)\b(adjust|increase|decrease|raise|lower|change|take|stop\s+taking|skip)\b[^.]{0,40}\b(insulin|dose|dosage|medication|meds?|basal|bolus|tablet|pill)\b"#),
        // 3. Dosing/administration verbs.
        (.dosingVerb, #"(?i)\b(inject|bolus|titrate|administer|dose up)\b"#),
        // 4. Affirmative diagnostic claim. "not a diagnosis" / "doesn't
        //    diagnose" stay clean because they lack the affirmative pattern.
        (.diagnosticClaim,
         #"(?i)(\byou\s+(have|'ve got|are having|suffer from)\b|\bdiagnos(ed\s+with|is\s+of)\b|\b(detected|confirmed)\b)"#),
        // 5. Clinical-normality verdict (we speak only of the PERSONAL baseline).
        (.clinicalNormality,
         #"(?i)(\bab?normal\b|\bwithin\s+normal\b|\bhealthy\s+range\b|\bnormal\s+(range|limits)\b)"#),
    ]

    /// Returns the first violated construction, or nil if the text is clean.
    public static func check(_ text: String) -> ForbiddenConstruction? {
        for (kind, pattern) in rules {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return kind
            }
        }
        return nil
    }

    /// A nudge is valid iff neither its title nor body contains a forbidden
    /// construction.
    public static func violation(in nudge: EngineNudge) -> ForbiddenConstruction? {
        check(nudge.title) ?? check(nudge.body)
    }

    public static func isValid(_ nudge: EngineNudge) -> Bool { violation(in: nudge) == nil }
}
