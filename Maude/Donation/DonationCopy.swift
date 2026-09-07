// DonationCopy.swift — FR-DON-06 · the "never leaves this phone" claim, scoped.
//
// THE PROBLEM THIS FILE EXISTS TO SOLVE. Four consent surfaces tell the citizen,
// verbatim: "Your individual readings never leave this phone." For every person
// who is not a donor that sentence is TRUE — it is the product, it is pinned by
// `T-RSCH-05` and `T-SUND-01`, and nothing here changes it by a character. For
// a donor who has signed the donation agreement it would be FALSE, and telling
// a donor something untrue on a consent screen is the one thing that corrodes
// everything else the app promises (§6.3, OD-D11).
//
// So the claim is a FUNCTION of whether a donation grant is active, and there
// is exactly one of it. Every surface that makes the claim calls this — asserted
// by `DonationCopyTests.noSurfaceHardCodesTheReadingsClaim`, which fails the
// test run if the literal sentence reappears in a view.
//
// The donor sentence names the exception specifically: what leaves, how, by
// whose hand, and how it ends. "Some data may be shared" would be worse than
// the original claim, not better.
import Foundation

enum DonationCopy {

    /// The standing, unconditional claim. Unchanged since before the donor
    /// programme existed, and rendered for every citizen who is not a donor —
    /// which, in every shipped build, is everyone.
    static let standingClaim = String(localized:
        "Your individual readings never leave this phone.")

    /// The donor's version. Every clause is true of the running app: the app
    /// itself still sends nothing (there is no transport in the donation path);
    /// the donor exports a sealed file and performs the transfer themselves;
    /// and withdrawing stops any further export.
    static let donorClaim = String(localized:
        "Nothing in Maude sends your individual readings anywhere. The one exception is the donation you signed for: you export an encrypted copy yourself and hand it to Data for Good's engineers. That happens only when you do it, and you can withdraw at any time.")

    /// The claim to render on a consent surface.
    /// - Parameter donating: true only when an active, unexpired donation grant
    ///   is recorded on this device (`AppState.hasActiveDonationGrant`).
    static func readingsClaim(donating: Bool) -> String {
        donating ? donorClaim : standingClaim
    }

    /// The one-line description of what a specific RECIPIENT can see, for the
    /// per-grant rows on the privacy screen. Scoped per grant rather than per
    /// donor: a clinician still only ever sees summaries, whether or not the
    /// person is also a donor — and the donation grant must not be described in
    /// words written for a summaries-only recipient.
    static func recipientRowClaim(recipientType: RecipientType) -> String {
        recipientType == .controllerInternal
            ? String(localized: "Your own readings, in an encrypted file you export yourself")
            : String(localized: "Summaries only · your individual readings never leave this phone")
    }
}
