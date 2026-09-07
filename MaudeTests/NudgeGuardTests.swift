import Testing
@testable import Maude

// FR-NDG-06 forbidden-construction guard — DESIGNATED CONTROL, **BLOCKING**.
// These tests must never be skipped or marked allow-fail (qms/VnV.md).
struct NudgeGuardTests {

    // T-NDG-06 — known-bad constructions are all blocked.
    @Test(arguments: [
        ("Take 12 units of insulin now.",      ForbiddenConstruction.dose),
        ("That's 500 mg per day.",             .dose),
        ("Increase your insulin dose.",        .treatmentDirective),
        ("You should stop taking your meds.",  .treatmentDirective),
        ("Inject before your meal.",           .dosingVerb),
        ("Titrate up tonight.",                .dosingVerb),
        ("You have atrial fibrillation.",      .diagnosticClaim),
        ("AFib detected on your watch.",       .diagnosticClaim),
        ("You were diagnosed with diabetes.",  .diagnosticClaim),
        ("Your reading is abnormal.",          .clinicalNormality),
        ("This is within normal limits.",      .clinicalNormality),
    ])
    func blocksForbidden(_ text: String, _ expected: ForbiddenConstruction) {
        #expect(NudgeGuard.check(text) == expected)
    }

    // T-NDG-06b — legitimate, baseline-relative copy passes (incl. disclaimers).
    @Test(arguments: [
        "Your glucose today is running above your usual range.",
        "Your most recent resting heart rate is 58 bpm.",
        "Maude does not interpret heart rhythm — please share this recording with your cardiologist.",
        "This is not a diagnosis.",
        "Your glucose is 6.4 mmol/L.",
        "A short walk could be a good idea today.",
        "An earlier night could help you catch up.",
    ])
    func allowsLegitimate(_ text: String) {
        #expect(NudgeGuard.check(text) == nil)
    }

    // T-NDG-06c — every nudge the engine can author passes the guard.
    @Test func everyEngineOutputIsClean() {
        for s in NudgeFixtures.triggering() {
            let nudges = NudgeEngine().generate(samples: s.samples, signals: s.signals)
            #expect(nudges.allSatisfy { NudgeGuard.isValid($0) })
        }
    }
}
