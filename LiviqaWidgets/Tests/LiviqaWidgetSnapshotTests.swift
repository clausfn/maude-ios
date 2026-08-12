// LiviqaWidgetSnapshotTests.swift — FR-WID-01 rail tests.
//
// TARGET MEMBERSHIP: **LiviqaTests**. Add together with the two
// `LiviqaWidgets/Shared/` files and `LiviqaWidgets/App/WidgetSnapshotPublisher.swift`
// (SETUP.md §7) — these tests exercise the app-side composer, so they cannot run
// until those files are members of the app target.
//
// STATUS: written, NOT yet executing — the widget targets do not exist yet, so
// none of this source is compiled by any scheme. Do not record these ids as
// passing in the RTM until the targets are created and the suite runs green.
//
// Test ids:
//   T-WID-01  the snapshot's wire format carries no `provenance` — ever
//   T-WID-02  FR-NDG-06: static widget copy is clean; a violating verdict is
//             replaced, never published
//   T-WID-03  the composer decomposes and never fabricates
//   T-WID-04  the "as of" staleness line is honest across day boundaries
//   T-WID-05  time in range is two-state and clamped
//   T-WID-06  the shared store fails CLOSED when the App Group is missing
import XCTest
@testable import Liviqa

final class LiviqaWidgetSnapshotTests: XCTestCase {

    // MARK: Fixtures

    private func signals(inRange: String = "68%",
                         hrv: String = "48",
                         rhr: String = "58",
                         sleep: String = "6h52",
                         inRangeWeek: [Double] = [61, 64, 66, 70, 69, 72],
                         sleepWeek: [Double] = [6.1, 6.3, 6.4, 6.9, 7.0, 7.1],
                         hrvWeek: [Double] = [44, 45, 46, 49, 50, 51]) -> TodaySignals {
        TodaySignals(sleep: sleep, inRange: inRange, hrv: hrv, rhr: rhr,
                     inRangeIsClay: false,
                     sleepWeek: sleepWeek, inRangeWeek: inRangeWeek,
                     hrvWeek: hrvWeek, rhrWeek: [58, 58, 57, 58, 58, 57])
    }

    private func snapshot(_ s: TodaySignals? = nil) -> LiviqaWidgetSnapshot? {
        WidgetSnapshotComposer.compose(signals: s ?? signals(),
                                       verdict: "You're having a steady week.",
                                       sleepHeadline: "6h 52",
                                       now: Date())
    }

    // MARK: T-WID-01 — provenance never crosses the process boundary

    func testT_WID_01_encodedSnapshotHasNoProvenanceKey() throws {
        let snap = try XCTUnwrap(snapshot())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snap)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.lowercased().contains("provenance"),
                       "provenance is a DATA field and must never reach a widget payload")

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys),
                       ["schema", "derivedAt", "edition", "verdict", "chips", "timeInRange"],
                       "the snapshot's key set is an allow-list — a new key is a deliberate act")
    }

    func testT_WID_01_roundTripIsLossless() throws {
        let snap = try XCTUnwrap(snapshot())
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(LiviqaWidgetSnapshot.self,
                                      from: try encoder.encode(snap))
        XCTAssertEqual(back, snap)
    }

    func testT_WID_01_unsupportedSchemaIsNotRendered() throws {
        let snap = try XCTUnwrap(snapshot())
        let future = LiviqaWidgetSnapshot(schema: LiviqaWidgetSnapshot.currentSchema + 1,
                                          derivedAt: snap.derivedAt, edition: snap.edition,
                                          verdict: snap.verdict, chips: snap.chips,
                                          timeInRange: snap.timeInRange)
        XCTAssertFalse(future.isSchemaSupported)
    }

    // MARK: T-WID-02 — FR-NDG-06 (DESIGNATED CONTROL)

    func testT_WID_02_allStaticWidgetCopyPassesNudgeGuard() {
        for text in WidgetCopy.allStatic {
            XCTAssertNil(NudgeGuard.check(text),
                         "forbidden construction in widget copy: \"\(text)\"")
        }
    }

    func testT_WID_02_violatingVerdictIsReplacedNotPublished() {
        // NOTE (2026-08-13, FR-WID-01): the clinicalNormality fixture is
        // "abnormal", not bare "normal". `NudgeGuard` rule 5 is
        // `\bab?normal\b`, which matches "abnormal"/"anormal" but NOT a bare
        // "normal" used as a predicate ("your readings are normal"). That looks
        // like it was meant to be `\b(ab)?normal\b`. It is a DESIGNATED CONTROL,
        // so this PR does not touch it — the gap is written up in
        // qms/RISK.md (RK-WID-02) for the control's owner to rule on.
        let violations = [
            "Take 12 units with dinner.",          // dose + dosing context
            "Adjust your insulin tonight.",        // treatmentDirective
            "Titrate before bed.",                 // dosingVerb
            "You have sleep apnoea.",              // diagnosticClaim
            "Your readings are abnormal.",         // clinicalNormality
            "That sits within normal limits.",     // clinicalNormality
        ]
        for text in violations {
            XCTAssertNotNil(NudgeGuard.check(text), "fixture should violate: \(text)")
            let out = WidgetSnapshotComposer.sanitizedVerdict(text)
            XCTAssertEqual(out, WidgetSnapshotComposer.neutralVerdict)
            XCTAssertNil(NudgeGuard.check(out), "the fallback must itself be clean")
        }
    }

    func testT_WID_02_cleanVerdictSurvivesUnchanged() {
        let clean = "You're having a steady week."
        XCTAssertEqual(WidgetSnapshotComposer.sanitizedVerdict(clean), clean)
        XCTAssertEqual(WidgetSnapshotComposer.sanitizedVerdict("   "),
                       WidgetSnapshotComposer.neutralVerdict)
    }

    // MARK: T-WID-03 — decomposition, and no fabrication

    func testT_WID_03_noSignalsPublishesNothing() {
        XCTAssertNil(WidgetSnapshotComposer.compose(signals: nil,
                                                    verdict: "You're having a steady week.",
                                                    sleepHeadline: nil))
    }

    func testT_WID_03_chipsAreDecomposedAndCarryBaselineWords() throws {
        let snap = try XCTUnwrap(snapshot())
        XCTAssertEqual(snap.chips.map(\.label), ["Sleep", "Recovery", "Heart"])
        XCTAssertEqual(snap.chips.first?.value, "6h 52", "Home's sleep headline wins")
        XCTAssertEqual(snap.chips[1].value, "48 ms")
        for chip in snap.chips {
            XCTAssertNotNil(chip.note)
            XCTAssertFalse(chip.value.isEmpty)
        }
    }

    func testT_WID_03_dashValuesAreOmittedNotShownAsZero() {
        let thin = TodaySignals(sleep: "—", inRange: "—", hrv: "—", rhr: "—",
                                inRangeIsClay: false)
        let chips = WidgetSnapshotComposer.chips(for: thin, sleepHeadline: nil)
        XCTAssertTrue(chips.isEmpty, "a calibrating signal is absent, never zero")
        XCTAssertNil(WidgetSnapshotComposer.timeInRange(for: thin))
    }

    func testT_WID_03_editionMatchesTheAppsRule() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        func at(_ hour: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: hour))!
        }
        XCTAssertEqual(WidgetEdition.current(at: at(9), calendar: cal), .morning)
        XCTAssertEqual(WidgetEdition.current(at: at(20), calendar: cal), .morning)
        XCTAssertEqual(WidgetEdition.current(at: at(21), calendar: cal), .evening)
        XCTAssertEqual(WidgetEdition.current(at: at(2), calendar: cal), .evening)
        XCTAssertEqual(WidgetEdition.current(at: at(4), calendar: cal), .morning)
    }

    // MARK: T-WID-04 — honest staleness

    func testT_WID_04_asOfTextSameDayAndEarlierDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let derived = cal.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 7, minute: 12))!
        let sameDay = cal.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 19))!
        let nextDay = cal.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 8))!

        XCTAssertEqual(WidgetStaleness.asOfText(derived, now: sameDay, calendar: cal), "as of 07:12")
        XCTAssertEqual(WidgetStaleness.asOfText(derived, now: nextDay, calendar: cal),
                       "as of 07:12, 12 Aug")
        XCTAssertEqual(WidgetStaleness.timeText(derived, calendar: cal), "07:12")
    }

    // MARK: T-WID-05 — two-state, clamped TIR

    func testT_WID_05_twoStatesAlwaysComplement() {
        for pct in [-20, 0, 1, 50, 68, 99, 100, 140] {
            let tir = WidgetTimeInRange(inRangePct: pct, daysWithReadings: 6)
            XCTAssertEqual(tir.insidePct + tir.outsidePct, 100)
            XCTAssertTrue((0...100).contains(tir.insidePct))
            XCTAssertTrue((0...1).contains(tir.insideFraction))
        }
    }

    func testT_WID_05_percentParsingIsStrict() {
        XCTAssertEqual(WidgetSnapshotComposer.percentValue("68%"), 68)
        XCTAssertEqual(WidgetSnapshotComposer.percentValue("0%"), 0)
        XCTAssertNil(WidgetSnapshotComposer.percentValue("—"))
        XCTAssertNil(WidgetSnapshotComposer.percentValue(""))
        XCTAssertNil(WidgetSnapshotComposer.percentValue("68"))
        XCTAssertNil(WidgetSnapshotComposer.percentValue("about 68%"))
    }

    func testT_WID_05_coverageIsTheNumberOfDaysWithReadings() throws {
        let snap = try XCTUnwrap(snapshot())
        let tir = try XCTUnwrap(snap.timeInRange)
        XCTAssertEqual(tir.daysWithReadings, 6)
        XCTAssertEqual(tir.coverageWindowDays, 7)
    }

    // MARK: T-WID-06 — the store fails closed

    func testT_WID_06_storeIsInertWithoutAnAppGroup() throws {
        // A bundle with no `LiviqaAppGroup` key stands in for a target that was
        // not set up: reads are nil, writes report failure. Never a guessed group.
        XCTAssertNil(LiviqaWidgetSnapshotStore.appGroupIdentifier(bundle: Bundle(for: type(of: self))))
        XCTAssertNil(LiviqaWidgetSnapshotStore.load(from: nil))
        let snap = try XCTUnwrap(snapshot())
        XCTAssertFalse(LiviqaWidgetSnapshotStore.save(snap, to: nil))
    }

    func testT_WID_06_saveLoadClearRoundTripInAnIsolatedSuite() throws {
        let suiteName = "liviqa.widget.tests.\(UUID().uuidString)"
        let store = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let snap = try XCTUnwrap(snapshot())
        XCTAssertTrue(LiviqaWidgetSnapshotStore.save(snap, to: store))
        XCTAssertEqual(LiviqaWidgetSnapshotStore.load(from: store), snap)
        LiviqaWidgetSnapshotStore.clear(in: store)
        XCTAssertNil(LiviqaWidgetSnapshotStore.load(from: store))
    }
}
