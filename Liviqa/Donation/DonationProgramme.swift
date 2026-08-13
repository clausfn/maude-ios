// DonationProgramme.swift — FR-DON-01 · programme constants and the donor gate.
//
// The Donated Data Programme (DON-2026-01) is a SEPARATE thing from everything
// else in this app. Read `Liviqa_DonorDataProgramme_v01_20260813.md` before
// touching this directory; the three facts that shape every line here are:
//
//   1. Donation is an EXPORT the donor performs, never an upload the app
//      performs. Nothing in `Liviqa/Donation/` opens a network connection, and
//      `DonationEgressTests` fails the test run if that ever changes. The app
//      binary therefore keeps ZERO raw-egress capability (T-RSCH-05, T-SUND-01
//      stay green and unweakened).
//   2. The flow exists only in a DONOR BUILD (`-D LIVIQA_DONOR`). In every
//      shipped binary `isDonorBuild` is a compile-time `false`, so no ordinary
//      citizen can reach any of it and nothing about their app changes.
//   3. The payload is sealed on THIS DEVICE to the programme's public key. The
//      private half is held by two custodians on hardware tokens and never
//      exists in the app, in this repo, or on any laptop — so a donor build
//      cannot read back what it sealed, and neither can a stolen phone.
//
// CN DECISION 2026-08-13 (recorded, not silently widened): the corpus IS for
// model training, not verification only — overruling OD-D1's v01 recommendation
// — and anonymity is abandoned as a strategy. The corpus is IDENTIFIABLE
// special-category health data protected by lawful basis, explicit consent,
// encryption, access control and governance. The words "anonymous"/"anonymised"
// still may not appear in any programme copy (§3.3), and this file's copy obeys
// that. What the DONOR is told about training lives on the signed consent form,
// which is the authoritative consent — not in this app.
import Foundation
import CryptoKit

enum DonationProgramme {

    /// Programme id, per the design document. Written into every manifest and
    /// every ledger row so a sealed file can be attributed without opening it.
    static let id = "DON-2026-01"

    /// Controller of the corpus. Named in full on the donor screen: a donor must
    /// never be left guessing who holds the file.
    static let controller = "Data for Good Foundation"

    /// Recipient label for the consent grant. Deliberately explicit that the
    /// recipient is the app's own maker acting as controller (§2.6, OD-D2).
    static let recipientName = "Data for Good Foundation — donor programme DON-2026-01"

    /// Payload schema id. Version it: a custodian must be able to tell which
    /// assembler wrote a file without guessing.
    static let payloadSchema = "liviqa.donation.v1"

    /// Sealed-envelope format id (see `DonationSealer`).
    static let envelopeFormat = "LVDN1"

    /// The consented retrospective window (§3.2). 90 days is long enough for
    /// baseline behaviour and at least one clock change, short enough to be a
    /// bounded ask.
    static let windowDays = 90

    /// Grant lifetime (§2.6): 12 months, mandatory, no auto-renew.
    static let grantMonths = 12

    /// File extension for a sealed donation. Not a format the app can read.
    static let fileExtension = "lvdn"

    // MARK: - The donor gate

    /// TRUE only in a build compiled with `-D LIVIQA_DONOR`. Every shipped
    /// binary (Debug, TestFlight, Release) is compiled WITHOUT it, so this is a
    /// compile-time `false` there and the donor surfaces are unreachable —
    /// asserted by `DonationEgressTests.donorBuildFlagIsCompileTimeGated`.
    #if LIVIQA_DONOR
    static let isDonorBuild = true
    #else
    static let isDonorBuild = false
    #endif

    // MARK: - Programme public key

    /// The programme's X25519 public key, base64 (raw representation, 32 bytes).
    ///
    /// DELIBERATELY `nil` TODAY. §7.3 item 7 requires both custodian keys to be
    /// generated, escrowed and tested BEFORE any byte is collected; pinning a
    /// key here before that ceremony would either (a) bake in a key whose
    /// private half someone improvised on a laptop, or (b) let a donor build
    /// produce files nobody can ever open. While this is nil the export refuses,
    /// on screen, with that reason — which is the correct behaviour, not a bug.
    ///
    /// When the ceremony has run, paste the PUBLIC half here. The private half
    /// must never appear in this repository in any form.
    static let publicKeyBase64: String? = nil

    /// DEBUG-only override so a donor build can be exercised end to end against
    /// a throwaway key before the ceremony. Never available in a Release binary
    /// (and TestFlight/App Store installs cannot set process environment at all).
    static var configuredPublicKeyBase64: String? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["LIVIQA_DONATION_PUBKEY"],
           !raw.isEmpty {
            return raw
        }
        #endif
        return publicKeyBase64
    }

    /// The pinned programme key, or nil when no key is configured.
    static func programmePublicKey() -> Curve25519.KeyAgreement.PublicKey? {
        guard let b64 = configuredPublicKeyBase64,
              let data = Data(base64Encoded: b64),
              let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        else { return nil }
        return key
    }

    // MARK: - Copy shown to the donor (EN; the signed form is authoritative)

    /// Exactly what a sealed file contains, in the donor's own language. Every
    /// line here must be true of the file the code actually writes — asserted by
    /// `DonationManifestTests.screenListingMatchesThePayloadShape`.
    static let includedItems: [String] = [
        "Glucose readings — the value in mmol/L and when it was taken",
        "Daily heart figures — resting, average, minimum and maximum heart rate, heart-rate variability, walking heart rate, recovery, breathing rate, blood-oxygen and VO₂ max, as this phone stores them (one row per day, not individual beats)",
        "Sleep segments — which night, which stage, how many hours, and which device recorded it",
        "Workouts — start, end, duration, activity type, distance and energy, with no route",
        "For every row: which kind of device or app recorded it, and the clock offset that applied at the time",
    ]

    /// What is NOT in the file. Named as specifically as what is (§2.3).
    static let excludedItems: [String] = [
        "Your name, email, phone number, address or account id",
        "Any location, and no workout route",
        "Anything you have written in Liviqa — journal entries, notes, voice notes, chat",
        "Anything from your national health record — no lab results, no diagnoses, no medication",
        "Blood pressure, atrial-fibrillation figures, insulin doses and body-composition readings",
        "Your age and sex — those are on your signed form, not in this file",
        "Steps and active energy — this phone does not keep them as rows, so there is nothing to include",
    ]

    /// The honesty line the programme requires in every description of the
    /// corpus (§3.3): a random code is a real protection and is not anonymity.
    static let pseudonymityNotice = String(localized:
        "Your file carries a random code instead of your name. That is a real protection, and it is not the same as being anonymous: weeks of one person's readings are close to unique to that person. Data for Good treats your donation as personal information about you for as long as it is held, and you keep every right you have over it.")

    /// The date-shift explanation (§3.2, OD-D6).
    static let dateShiftNotice = String(localized:
        "Every date in the file is moved by a whole number of weeks, the same amount throughout. Weekdays, the gaps between readings and the clock changes all survive the move; matching your file against a calendar of real events does not.")
}
