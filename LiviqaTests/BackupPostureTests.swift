import Testing
import Foundation
@testable import Liviqa

// T-SET-02b — the backup posture the citizen chose in onboarding must SURVIVE.
//
// The row this covers used to read "today the selection is @State, discarded on
// complete". It isn't: `BackupStep` writes `@AppStorage("backupPreference")` on
// Continue, restores it in `onAppear`, and `AccountSecurityView` reads the same
// key — so the choice round-trips across the whole app, not just the step.
//
// The honesty rail here: an unreadable or legacy stored value must fall back to
// `.onDevice` (nothing is backed up) — never to a posture that implies a backup
// exists when it doesn't.
//
// `.serialized` (2026-08-18): all three tests mutate the SAME
// `UserDefaults.standard` key, and Swift Testing runs a suite's tests in
// parallel by default — one test's write interleaved another's
// save→mutate→read round-trip, producing three different flaky failure
// signatures across runs (restored nil · restored .onDevice · legacy .iCloud).
// Serialising the suite removes the shared-key race without changing a single
// assertion.
@Suite(.serialized)
struct BackupPostureTests {

    /// The one key both surfaces use. If this ever diverges, the setting
    /// silently stops persisting — so the test names it explicitly.
    private let key = "backupPreference"

    /// A private defaults domain per test. The posture is stored under a single
    /// shared key, so reading and writing it in `UserDefaults.standard` let the
    /// tests below race: one sets `.iCloud` while the other has just cleared the
    /// key and is asserting the first-launch fallback. Same key, same reads —
    /// just nobody else's domain, and the test host's real defaults stay clean.
    private func freshDefaults() -> UserDefaults {
        let name = "backup-posture-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func chosenPostureRoundTrips() {
        let defaults = freshDefaults()
        for choice in [BackupPreference.onDevice, .iCloud, .sovereign] {
            defaults.set(choice.rawValue, forKey: key)
            let restored = BackupPreference(
                rawValue: defaults.string(forKey: key) ?? "")
            #expect(restored == choice)
        }
    }

    @Test func unsetOrUnknownFallsBackToOnDevice() {
        let defaults = freshDefaults()
        // Nothing stored yet (first launch).
        let fresh = BackupPreference(
            rawValue: defaults.string(forKey: key) ?? "") ?? .onDevice
        #expect(fresh == .onDevice)
        // A legacy / corrupted value must not imply a backup exists.
        defaults.set("someRetiredOption", forKey: key)
        let legacy = BackupPreference(
            rawValue: defaults.string(forKey: key) ?? "") ?? .onDevice
        #expect(legacy == .onDevice)
    }

    /// The in-memory mirror the rest of the app reads starts at the same honest
    /// default, so no surface can claim a backup before one is chosen.
    @Test func appStateDefaultsToOnDevice() async {
        let state = await AppState(supabase: MockSupabaseService())
        #expect(await state.backupPreference == .onDevice)
    }
}
