import Testing
import Foundation
@testable import Liviqa

// UC-01 / FR-ACC-NAME-01 — what the app may call a person.
//
// The incident: the greeting read "Good morning, 75sg6pvfys." — the local-part
// of an Apple private-relay address that `/me` hands back as `displayName`,
// while the name the citizen typed in onboarding was ignored because the
// backend value was non-empty.
//
// One pure function decides this (`DisplayNameResolution.resolve`); this is its
// table. No simulator, no state, no I/O.
@MainActor
struct DisplayNameResolutionTests {

    // MARK: - The four required cases

    @Test func declaredNameWins() {
        #expect(DisplayNameResolution.resolve(
            declared: "Clara", backend: "75sg6pvfys",
            accountEmail: "75sg6pvfys@privaterelay.appleid.com") == "Clara")
        // …including over a perfectly good backend name: the citizen chose it.
        #expect(DisplayNameResolution.resolve(
            declared: "Clara", backend: "Clara Winther",
            accountEmail: "clara@example.com") == "Clara")
    }

    @Test func emailLocalPartIsRejectedAsAPlaceholder() {
        #expect(DisplayNameResolution.resolve(
            declared: nil, backend: "75sg6pvfys",
            accountEmail: "75sg6pvfys@privaterelay.appleid.com") == nil)
        // Not Apple-specific — ANY provider echoing the mailbox name.
        #expect(DisplayNameResolution.resolve(
            declared: nil, backend: "c.nielsen",
            accountEmail: "c.nielsen@example.dk") == nil)
        // Case is not a disguise.
        #expect(DisplayNameResolution.resolve(
            declared: nil, backend: "C.Nielsen",
            accountEmail: "c.nielsen@example.dk") == nil)
    }

    @Test func realBackendNameIsAccepted() {
        #expect(DisplayNameResolution.resolve(
            declared: nil, backend: "Clara Winther",
            accountEmail: "75sg6pvfys@privaterelay.appleid.com") == "Clara Winther")
        #expect(DisplayNameResolution.resolve(
            declared: "   ", backend: "Anders",
            accountEmail: nil) == "Anders")
    }

    @Test func nothingKnownYieldsNoName() {
        #expect(DisplayNameResolution.resolve(declared: nil, backend: nil, accountEmail: nil) == nil)
        #expect(DisplayNameResolution.resolve(declared: "", backend: "  ",
                                              accountEmail: "someone@example.com") == nil)
    }

    // MARK: - An address is never a name, wherever it came from

    @Test func anythingEmailShapedIsRefused() {
        #expect(DisplayNameResolution.resolve(
            declared: nil, backend: "75sg6pvfys@privaterelay.appleid.com",
            accountEmail: nil) == nil)
        #expect(DisplayNameResolution.resolve(
            declared: "me@example.com", backend: nil, accountEmail: nil) == nil)
        // A declared address doesn't get to shadow a real backend name either.
        #expect(DisplayNameResolution.resolve(
            declared: "me@example.com", backend: "Clara", accountEmail: nil) == "Clara")
        #expect(DisplayNameResolution.isPlaceholder("a@b.dk", accountEmail: nil))
    }

    // MARK: - Shape details

    @Test func namesAreTrimmedNotAltered() {
        #expect(DisplayNameResolution.resolve(declared: "  Clara \n", backend: nil,
                                              accountEmail: nil) == "Clara")
        #expect(DisplayNameResolution.resolve(declared: nil, backend: " Clara Winther ",
                                              accountEmail: nil) == "Clara Winther")
    }

    @Test func localPartExtraction() {
        #expect(DisplayNameResolution.localPart(ofEmail: "clara@example.com") == "clara")
        #expect(DisplayNameResolution.localPart(ofEmail: "not-an-email") == nil)
        #expect(DisplayNameResolution.localPart(ofEmail: "@example.com") == nil)
        #expect(DisplayNameResolution.localPart(ofEmail: nil) == nil)
        #expect(DisplayNameResolution.localPart(ofEmail: "  ") == nil)
    }

    @Test func aNameThatMerelyResemblesTheMailboxIsStillAName() {
        // Only EQUALITY with the local-part is a placeholder — "Clara" stays a
        // name even when the address is clara.winther@example.com.
        #expect(DisplayNameResolution.resolve(
            declared: nil, backend: "Clara",
            accountEmail: "clara.winther@example.com") == "Clara")
    }

    // MARK: - Wired into AppState (every surface reads profile.displayName)

    /// Isolated defaults so the suite never reads (or writes) the test host's
    /// real declared name.
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "displayname-\(UUID().uuidString)")!
    }

    private func state(email: String?, backendName: String?) -> (AppState, UUID) {
        let s = AppState(supabase: MockSupabaseService())
        let id = UUID()
        s.session = UserSession(userId: id, email: email)
        s.profile = UserProfile(id: id, displayName: backendName, avatarURL: nil,
                                createdAt: nil, alias: nil)
        return (s, id)
    }

    @Test func appStateDropsAPrivateRelayPlaceholderFromTheProfile() {
        let (s, _) = state(email: "75sg6pvfys@privaterelay.appleid.com", backendName: "75sg6pvfys")

        s.applyResolvedDisplayName(defaults: defaults())

        #expect(s.profile?.displayName == nil)   // greeted without a name, not with an id
    }

    @Test func appStateKeepsARealBackendName() {
        let (s, _) = state(email: "75sg6pvfys@privaterelay.appleid.com", backendName: "Clara Winther")

        s.applyResolvedDisplayName(defaults: defaults())

        #expect(s.profile?.displayName == "Clara Winther")
    }

    @Test func appStateLetsTheDeclaredNameBeatThePlaceholder() {
        let (s, _) = state(email: "75sg6pvfys@privaterelay.appleid.com", backendName: "75sg6pvfys")
        let defs = defaults()

        s.setDisplayName("Clara", defaults: defs)
        s.applyResolvedDisplayName(defaults: defs)

        #expect(s.profile?.displayName == "Clara")
    }

    @Test func appStateRefusesToStoreAnAddressAsTheDeclaredName() {
        let (s, _) = state(email: "someone@example.com", backendName: nil)
        let defs = defaults()

        s.setDisplayName("someone@example.com", defaults: defs)

        #expect(s.profile?.displayName == nil)
        #expect(defs.string(forKey: AppState.displayNameKey) == nil)
    }
}
