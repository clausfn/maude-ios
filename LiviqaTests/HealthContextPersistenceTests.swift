import Testing
import Foundation
@testable import Liviqa

// FIELD BUG 10.103 (CN, on device): "When I enter my goals and ranges, they
// get deleted." Two mechanisms, both reproduced red before the fix:
//
//  1. LOCKED-LAUNCH CLOBBER — healthcontext.v1.json is written with
//     NSFileProtectionComplete, so whenever iOS prewarms/relaunches the app
//     while the phone is locked the file EXISTS but is UNREADABLE. The old
//     load() collapsed that into nil = "never saved": AppState seeded an
//     empty profile (goals/ranges "deleted" on screen), and the next Save —
//     an atomic rename, which ignores the old file's read lock — clobbered
//     the stored profile on disk. Now `loadOutcome` distinguishes absent
//     from unreadable, `healthContextRestored` stays false on unreadable,
//     and the restore retries on unlock and before every draft.
//
//  2. DECIMAL-COMMA WIPE — ProfileSheet's old optional-Double binding
//     adapters parsed with `Double(String)` ("." only) while the Danish
//     decimal pad offers ONLY the comma, and the get side reformatted every
//     keystroke ("4" → "4.0"), so typing a separator stored nil and visibly
//     emptied the field. Targets are now edited through String-backed
//     `ClinicalTargetsDraft`, parsed tolerantly on Save.
//
// Pinned here: an edit made anywhere (Settings profile, onboarding passport
// — both are ProfileSheet → saveHealthContext — during sample mode, or a
// Sundhed import merge) survives relaunch, sign-out/sign-in, and
// sample-mode round-trips.
@MainActor
struct HealthContextPersistenceTests {

    // MARK: - Fixtures (isolated: own temp URL, own defaults suite, in-memory
    // store, mock service — never the shared standard defaults or live stores)

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hc-test-\(UUID().uuidString).json")
    }

    private func makeState(url: URL) -> AppState {
        let s = AppState(supabase: MockSupabaseService(),
                         sampleModeDefaults: UserDefaults(suiteName: "hc-\(UUID().uuidString)")!,
                         store: try? LiviqaStore.makeContainer(inMemory: true),
                         healthContextURL: url)
        s.dataProviderKind = .mock
        return s
    }

    /// Deterministic fixture — fixed id/date so equality holds across calls
    /// and across an encode/decode round trip.
    private func storedProfile() -> HealthContext {
        var ctx = HealthContext()
        ctx.goals = [GoalEntry(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                               text: "Keep TIR above 80%",
                               createdAt: Date(timeIntervalSince1970: 1_755_000_000))]
        ctx.targets.glucoseRangeLow = 4.0
        ctx.targets.glucoseRangeHigh = 10.0
        return ctx
    }

    private func lock(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o000],
                                              ofItemAtPath: url.path)
    }
    private func unlock(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o644],
                                              ofItemAtPath: url.path)
    }

    // MARK: - Store: absent vs unreadable are different answers

    @Test func roundTripKeepsGoalsAndRanges() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        HealthContextStore.save(storedProfile(), to: url)
        #expect(HealthContextStore.loadOutcome(from: url) == .loaded(storedProfile()))
    }

    @Test func nothingSavedReadsAsAbsent() {
        #expect(HealthContextStore.loadOutcome(from: tempURL()) == .absent)
    }

    @Test func unreadableFileNeverReadsAsAbsent() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        HealthContextStore.save(storedProfile(), to: url)
        try lock(url)
        defer { try? unlock(url) }
        #expect(HealthContextStore.loadOutcome(from: url) == .unreadable)
    }

    // MARK: - Mechanism 1: locked launch must not clobber the stored profile

    @Test func lockedLaunchThenUnlockRestoresStoredProfile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        HealthContextStore.save(storedProfile(), to: url)
        try lock(url)

        // Prewarmed launch while locked: seed shows, but the app KNOWS the
        // restore is still pending.
        let s = makeState(url: url)
        // The cold-start seed shows (demo in DEBUG, empty in Release) — but the
        // app KNOWS the restore is still pending, so nothing can clobber disk.
        #expect(s.healthContext == AppState.ColdStart.healthContext)
        #expect(s.healthContextRestored == false)

        // Device unlocks (protected data available) → retry restores.
        try unlock(url)
        s.retryHealthContextRestoreIfNeeded()
        #expect(s.healthContextRestored)
        #expect(s.healthContext == storedProfile())
    }

    @Test func editAfterLockedLaunchKeepsBothOldAndNew() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        HealthContextStore.save(storedProfile(), to: url)
        try lock(url)
        let s = makeState(url: url)

        // ProfileSheet can only be on screen unlocked; its onAppear retries
        // BEFORE seeding the draft, so the draft starts from the stored
        // profile, not the seed.
        try unlock(url)
        s.retryHealthContextRestoreIfNeeded()
        var draft = s.healthContext
        draft.targets.restingHRCeiling = 100
        s.saveHealthContext(draft)

        // Relaunch: the earlier goals/ranges AND the new edit both survive.
        let next = makeState(url: url)
        #expect(next.healthContext.goals.map(\.text) == ["Keep TIR above 80%"])
        #expect(next.healthContext.targets.glucoseRangeLow == 4.0)
        #expect(next.healthContext.targets.restingHRCeiling == 100)
    }

    @Test func retryWhileStillLockedChangesNothing() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url); try? unlock(url) }
        HealthContextStore.save(storedProfile(), to: url)
        try lock(url)
        let s = makeState(url: url)
        s.retryHealthContextRestoreIfNeeded()   // still unreadable
        #expect(s.healthContextRestored == false)
        #expect(s.healthContext == AppState.ColdStart.healthContext)  // the seed, honestly
    }

    // MARK: - Survives relaunch, sign-out/sign-in, sample-mode round-trips

    @Test func saveSurvivesRelaunch() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let s = makeState(url: url)
        s.saveHealthContext(storedProfile())
        #expect(makeState(url: url).healthContext == storedProfile())
    }

    @Test func signOutThenSignInKeepsProfile() async {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let s = makeState(url: url)
        s.saveHealthContext(storedProfile())
        await s.signOut()
        #expect(s.healthContext == storedProfile())
        // Sign back in: /me carries no health context and must not overwrite it.
        await s.signInWithEmail(email: "t@example.com", password: "pw")
        #expect(s.healthContext == storedProfile())
    }

    @Test func sampleModeRoundTripKeepsProfileAndEditsMadeDuringIt() async {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let s = makeState(url: url)
        s.saveHealthContext(storedProfile())

        await s.enterSampleMode(.settingsChoice)
        // The declared profile is the citizen's own — never overlaid by sample.
        #expect(s.healthContext == storedProfile())

        // An edit saved DURING sample mode is a real edit and persists.
        var edited = s.healthContext
        edited.goals.append(GoalEntry(text: "Reduce nocturnal lows"))
        s.saveHealthContext(edited)

        s.exitSampleMode()
        #expect(s.healthContext.goals.map(\.text) ==
                ["Keep TIR above 80%", "Reduce nocturnal lows"])
        #expect(makeState(url: url).healthContext.goals.count == 2)
    }

    @Test func eraseRemovesTheStore() async {
        let url = tempURL()
        let s = makeState(url: url)
        s.saveHealthContext(storedProfile())
        await s.deleteAllData()
        #expect(HealthContextStore.loadOutcome(from: url) == .absent)
        #expect(s.healthContextRestored)   // nothing stored ⇒ seed is the truth
    }

    // MARK: - Mechanism 2: targets are typed as text, parsed tolerantly on Save

    @Test func commaAndPointBothParse() {
        #expect(ClinicalTargetsDraft.parseDouble("4,5") == 4.5)
        #expect(ClinicalTargetsDraft.parseDouble("4.5") == 4.5)
        #expect(ClinicalTargetsDraft.parseDouble(" 10,0 ") == 10.0)
        #expect(ClinicalTargetsDraft.parseDouble("") == nil)
        #expect(ClinicalTargetsDraft.parseDouble("abc") == nil)
        #expect(ClinicalTargetsDraft.parseInt(" 80 ") == 80)
        #expect(ClinicalTargetsDraft.parseInt("") == nil)
    }

    @Test func displayNeverRewritesWhatTheUserTyped() {
        // Seeding shows the minimal form; while editing the String IS the
        // state — there is no per-keystroke reformat left to wipe a field.
        #expect(ClinicalTargetsDraft.display(4.0) == "4")
        #expect(ClinicalTargetsDraft.display(4.5) == "4.5")
        #expect(ClinicalTargetsDraft.display(nil) == "")
    }

    @Test func draftAppliesTypedRangesToTheModel() {
        var draft = ClinicalTargetsDraft(from: ClinicalTargets())
        draft.glucoseLow = "4,0"
        draft.glucoseHigh = "10"
        draft.hbA1c = "48"
        draft.tir = "80"
        draft.restingHR = "100"
        let t = draft.applied(to: ClinicalTargets())
        #expect(t.glucoseRangeLow == 4.0)
        #expect(t.glucoseRangeHigh == 10.0)
        #expect(t.hbA1cTarget == 48)
        #expect(t.tirTarget == 80)
        #expect(t.restingHRCeiling == 100)
    }

    @Test func draftSeedsFromAndRoundTripsTheModel() {
        let seeded = ClinicalTargetsDraft(from: storedProfile().targets)
        #expect(seeded.glucoseLow == "4")
        #expect(seeded.glucoseHigh == "10")
        #expect(seeded.applied(to: ClinicalTargets()) == storedProfile().targets)
    }
}
