import Testing
import Foundation
@testable import Liviqa

// T-DON-03 — what a donation file may contain, proved against the bytes.
//
// The consent form promises a donor four things about the file: it holds only
// the readings they ticked, it holds nothing they were told it would not, it
// carries no invented data, and its dates are moved. Each is asserted here
// against the ENCODED payload rather than against the intention.
struct DonationPayloadTests {

    // MARK: - Fixtures

    private static let ref = "DON-2026-01-TEST01"
    private static let base = Date(timeIntervalSince1970: 1_750_000_000)   // 2025-06-15 UTC

    private func window(around date: Date = base, days: Double = 90) -> DateInterval {
        DateInterval(start: date.addingTimeInterval(-days * 86_400), end: date)
    }

    private func inputs() throws -> DonationAssembler.Inputs {
        DonationAssembler.Inputs(
            glucose: [
                try GlucoseSample(ts: Self.base.addingTimeInterval(-3_600), mmol: 6.4,
                                  mealContext: "after lunch, felt shaky",
                                  source: "Dexcom G7", tier: .good, provenance: .real),
            ],
            heart: [
                try HeartDaily(date: Self.base.addingTimeInterval(-86_400), hrMean: 62, hrMin: 48,
                               hrMax: 141, hrvMean: 58, rhr: 51, source: "Claus' Apple Watch",
                               tier: .good, provenance: .real),
            ],
            sleep: [
                try SleepSegment(date: Self.base.addingTimeInterval(-86_400), stage: .deep, hours: 1.4,
                                 source: "Oura Gen3", tier: .good, provenance: .real),
            ],
            workouts: [
                try Workout(start: Self.base.addingTimeInterval(-7_200),
                            end: Self.base.addingTimeInterval(-4_000),
                            type: "cycling", durMin: 53, kcal: 410, distKm: 22.4,
                            source: "Garmin Edge", tier: .good, provenance: .real),
            ])
    }

    private let allScopes: Set<String> = ["glucose", "heart_daily", "sleep", "workouts"]

    private func build(_ inputs: DonationAssembler.Inputs,
                       scopes: Set<String>? = nil,
                       window: DateInterval? = nil,
                       reference: String = DonationPayloadTests.ref) -> DonationPayload {
        DonationAssembler.build(inputs: inputs,
                                grantReference: reference,
                                scopes: scopes ?? allScopes,
                                window: window ?? self.window(),
                                timeZone: TimeZone(identifier: "Europe/Copenhagen")!,
                                appVersion: "1.0", appBuild: "10.102",
                                sealedAt: Self.base)
    }

    private func json(_ payload: DonationPayload) throws -> String {
        String(decoding: try DonationAssembler.encode(payload), as: UTF8.self)
    }

    // MARK: - 1. Only the four consented streams exist at all

    /// The payload's top-level shape IS the minimisation: there is no field a
    /// future caller could fill with a lab result or a journal entry.
    @Test func thePayloadHasNoFieldForAnythingExcluded() throws {
        let text = try json(build(try inputs()))
        let data = try #require(text.data(using: .utf8))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["manifest", "glucose", "heartDaily", "sleep", "workouts"],
                "unexpected top-level keys: \(object.keys.sorted())")
    }

    /// And nothing excluded leaks through a value either — including the free
    /// text HealthKit hangs on a glucose reading and the person's own name on
    /// their watch. Scanned over the SERIES (the manifest deliberately names the
    /// excluded categories in order to tell the custodians they are absent).
    @Test func nothingExcludedAppearsInTheSeries() throws {
        let payload = build(try inputs())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let series = [try encoder.encode(payload.glucose), try encoder.encode(payload.heartDaily),
                      try encoder.encode(payload.sleep), try encoder.encode(payload.workouts)]
            .map { String(decoding: $0, as: UTF8.self) }
            .joined()
            .lowercased()
        for leak in ["after lunch", "felt shaky", "mealcontext", "claus",
                     "journal", "diagnos", "medication", "latitude", "longitude",
                     "route", "email", "@", "provenance", "simulated", "tier"] {
            #expect(!series.contains(leak),
                    "a donated series must never carry '\(leak)'")
        }
    }

    // MARK: - 2. Real only — a fabricated row cannot enter a corpus

    @Test func simulatedAndExternalRowsAreDropped() throws {
        var rows = try inputs()
        rows.glucose.append(try GlucoseSample(ts: Self.base.addingTimeInterval(-1_800), mmol: 5.1,
                                              source: "MockProvider", tier: .good, provenance: .simulated))
        rows.sleep.append(try SleepSegment(date: Self.base.addingTimeInterval(-86_400), stage: .rem,
                                           hours: 1.1, source: "LV001", tier: .good, provenance: .external))
        let payload = build(rows)
        #expect(payload.glucose.count == 1, "a simulated reading must never be donated")
        #expect(payload.sleep.count == 1, "an external-fixture reading must never be donated")
        #expect(payload.rowCount == 4)
    }

    // MARK: - 3. Sources become device classes, never names

    @Test func sourceNamesAreClassifiedNotCopied() throws {
        let payload = build(try inputs())
        #expect(payload.heartDaily.first?.source == "apple-watch")
        #expect(payload.glucose.first?.source == "dexcom")
        #expect(payload.sleep.first?.source == "oura")
        #expect(payload.workouts.first?.source == "garmin")
    }

    @Test func anUnknownSourceBecomesAStableSaltedToken() {
        let a = DonationSourceClass.classify("Bodil's homebrew logger", salt: Self.ref)
        let b = DonationSourceClass.classify("Bodil's homebrew logger", salt: Self.ref)
        let c = DonationSourceClass.classify("A different app", salt: Self.ref)
        #expect(a.hasPrefix("unknown-"))
        #expect(a == b, "the same device must stay the same token within a donation")
        #expect(a != c, "two different sources must stay distinguishable (dedup defects need it)")
        #expect(!a.lowercased().contains("bodil"), "the raw name must never survive")
    }

    // MARK: - 4. Dates are shifted by whole weeks, consistently

    @Test func theShiftIsWholeWeeksAndConstantPerDonor() {
        for ref in ["DON-2026-01-A", "DON-2026-01-B", "DON-2026-01-C", "x", ""] {
            let days = DonationDateShift.days(forGrantReference: ref)
            #expect(days % 7 == 0, "\(ref): the shift must be whole weeks, got \(days)")
            #expect(abs(days) <= 182, "\(ref): the shift must stay within ±26 weeks, got \(days)")
            #expect(days == DonationDateShift.days(forGrantReference: ref), "the shift must be deterministic")
        }
    }

    @Test func shiftedTimestampsKeepTheWeekdayAndTheGaps() throws {
        let payload = build(try inputs())
        let shift = Double(payload.manifest.dateShiftDays) * 86_400

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let workout = try #require(payload.workouts.first)
        let start = try #require(iso.date(from: workout.start))
        let end = try #require(iso.date(from: workout.end))

        // The gap between two readings is untouched — it is the whole point.
        #expect(abs(end.timeIntervalSince(start) - 3_200) < 1)
        // And the instant really moved.
        let original = Self.base.addingTimeInterval(-7_200)
        #expect(abs(start.timeIntervalSince(original) - shift) < 1)
        // Weekday survives a whole-week shift.
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.weekday, from: start) == cal.component(.weekday, from: original))
    }

    /// The clock offset that applied at the ORIGINAL instant travels with each
    /// row, so a DST defect is still findable after the shift.
    @Test func eachRowCarriesTheOriginalClockOffset() throws {
        let payload = build(try inputs())
        let expected = TimeZone(identifier: "Europe/Copenhagen")!
            .secondsFromGMT(for: Self.base.addingTimeInterval(-3_600))
        #expect(payload.glucose.first?.tzOffsetSec == expected)
        #expect(payload.manifest.timeZoneIdentifier == "Europe/Copenhagen")
    }

    // MARK: - 5. Scope and window are obeyed

    @Test func anUntickedStreamIsNotAssembled() throws {
        let payload = build(try inputs(), scopes: ["sleep"])
        #expect(payload.sleep.count == 1)
        #expect(payload.glucose.isEmpty)
        #expect(payload.heartDaily.isEmpty)
        #expect(payload.workouts.isEmpty)
        #expect(payload.manifest.consentedScopes == ["sleep"])
    }

    @Test func readingsOutsideTheConsentedWindowAreDropped() throws {
        var rows = try inputs()
        rows.glucose.append(try GlucoseSample(ts: Self.base.addingTimeInterval(-400 * 86_400),
                                              mmol: 7.7, source: "Dexcom G7",
                                              tier: .good, provenance: .real))
        let payload = build(rows)
        #expect(payload.glucose.count == 1, "a reading from before the agreed period must not be donated")
    }

    // MARK: - 6. The manifest describes the file it is in

    @Test func theManifestCountsMatchTheSeries() throws {
        let payload = build(try inputs())
        #expect(payload.manifest.counts == payload.countsByStream)
        #expect(payload.manifest.counts == ["glucose": 1, "heart_daily": 1, "sleep": 1, "workouts": 1])
        #expect(payload.manifest.programmeId == DonationProgramme.id)
        #expect(payload.manifest.grantReference == Self.ref)
        #expect(payload.manifest.schema == DonationProgramme.payloadSchema)
    }

    /// The list the donor reads on screen is the list inside the file — one
    /// source, so a wording change cannot leave the screen describing a file
    /// that no longer matches.
    @Test func screenListingMatchesThePayloadShape() throws {
        let payload = build(try inputs())
        #expect(payload.manifest.included == DonationProgramme.includedItems)
        #expect(payload.manifest.excluded == DonationProgramme.excludedItems)
        #expect(Set(payload.countsByStream.keys)
                == Set(DonationAssembler.Scope.allCases.map(\.rawValue)))
    }

    /// No programme copy may CLAIM anonymity (§3.3). The word itself is allowed
    /// exactly where the consent text uses it — in a denial ("not the same as
    /// being anonymous") — because refusing to say it at all would leave a donor
    /// assuming it.
    @Test func noProgrammeCopyClaimsAnonymity() {
        let copy = ([DonationProgramme.pseudonymityNotice, DonationProgramme.dateShiftNotice,
                     DonationCopy.donorClaim, DonationCopy.standingClaim]
                    + DonationProgramme.includedItems + DonationProgramme.excludedItems)
            .joined(separator: " ").lowercased()
        for claim in ["is anonymous", "are anonymous", "fully anonymous", "completely anonymous",
                      "anonymised", "anonymized", "anonymous data", "anonymously"] {
            #expect(!copy.contains(claim), "programme copy must never claim '\(claim)'")
        }
        #expect(DonationProgramme.pseudonymityNotice.lowercased()
                    .contains("not the same as being anonymous"),
                "the notice must say plainly that a random code is not anonymity")
    }

    // MARK: - 7. Determinism (the recorded digest has to mean something)

    @Test func theSameRowsProduceTheSameBytes() throws {
        let a = try DonationAssembler.encode(build(try inputs()))
        let b = try DonationAssembler.encode(build(try inputs()))
        #expect(a == b, "two assemblies of the same rows must be byte-identical")
    }
}
