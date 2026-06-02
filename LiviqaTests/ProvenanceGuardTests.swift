import Testing
@testable import Liviqa

// Provenance-never-renders — RTM: NFR-PRIV (display), guard T-PROV-01.
//
// The file-level guard (scripts/guard_provenance.sh) is the primary blocking
// control. These tests add a type-level safety net: `Provenance` must not gain
// a human-facing string form that could be interpolated straight into a `Text`.
struct ProvenanceGuardTests {

    // T-PROV-02 — Provenance must not be CustomStringConvertible (would let
    // `Text("\(provenance)")` render a friendly label).
    @Test func provenanceHasNoCustomDescription() {
        #expect(!((Provenance.real as Any) is CustomStringConvertible))
    }

    // T-PROV-03 — raw values stay machine tokens, never UI copy.
    @Test func provenanceRawValuesAreTokens() {
        #expect(Provenance.real.rawValue == "REAL")
        #expect(Provenance.simulated.rawValue == "SIMULATED")
        #expect(Provenance.external.rawValue == "EXTERNAL")
    }
}
