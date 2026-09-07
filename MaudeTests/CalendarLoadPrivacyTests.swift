import Testing
import Foundation
@testable import Maude

// FR-CTX-CAL-01 privacy posture — T-CAL-02.
//
// The promise on the iOS permission prompt is "Maude reads how full your days
// are, never what is in them." That is a claim about CODE, so it is checked
// against the code rather than asserted in a comment. Three ways:
//
//   1. the one file that touches EventKit may read five members of an event and
//      no others — a future edit that reaches for a title fails this suite;
//   2. nothing else in the repo reads events at all;
//   3. the persisted shape is numbers, so there is no field content could be
//      kept in even if it were read.
//
// Every check FAILS if its target disappears: a lint that no longer finds what
// it guards has stopped guarding anything, which is worse than no lint.
struct CalendarLoadPrivacyTests {

    private static let ingestorPath = "Maude/Ingestion/CalendarLoadIngestor.swift"

    /// The five members of an `EKEvent` the read path may touch. Everything
    /// else — including `calendar`, because a calendar's NAME is content — is
    /// forbidden.
    private static let allowedEventMembers: Set<String> = [
        "status", "startDate", "endDate", "isAllDay", "availability",
    ]

    /// The fields that carry other people's personal data as well as the
    /// citizen's. Named explicitly so the denylist itself is reviewable.
    private static let contentFields = [
        "title", "attendees", "location", "structuredLocation", "notes",
        "organizer", "url", "calendarItemIdentifier", "eventIdentifier",
        "birthdayContactIdentifier", "hasAttendees", "hasNotes",
    ]

    // MARK: - 1. The read path may touch five members and no others

    @Test func readPathNeverTouchesEventContent() throws {
        let src = try SourceLint.text(Self.ingestorPath)

        // The lint must still have a target.
        #expect(SourceLint.body(ofDeclarationContaining: "static func intervals(", in: src) != nil,
                "the EventKit read function is gone — this lint is guarding nothing")

        // Every `event.<member>` in the file, comments excluded.
        var seen: Set<String> = []
        let pattern = #"\bevent\.([A-Za-z_][A-Za-z0-9_]*)"#
        for (_, line) in SourceLint.codeLines(src) {
            var search = line[...]
            while let r = search.range(of: pattern, options: .regularExpression) {
                let hit = String(search[r])
                seen.insert(String(hit.dropFirst("event.".count)))
                search = search[r.upperBound...]
            }
        }
        #expect(!seen.isEmpty, "no event member access found — the read path moved and this lint is stale")
        let forbidden = seen.subtracting(Self.allowedEventMembers)
        #expect(forbidden.isEmpty,
                "the calendar read path touched \(forbidden.sorted()) — density only, never content")
    }

    @Test func theContentFieldsAppearNowhereOnTheCalendarPath() throws {
        // Applied to the platform edge, where an EKEvent actually exists.
        let src = try SourceLint.text(Self.ingestorPath)
        for field in Self.contentFields {
            let hits = SourceLint.matches(#"\."# + field + #"\b"#, in: src)
            #expect(hits.isEmpty, "\(field) is read on the calendar path (line \(hits.first?.n ?? -1))")
        }
    }

    @Test func nothingIsEverLoggedFromTheCalendarPath() throws {
        // An event's content must not exist in a console either. The derivation
        // and store files are swept too — they hold the numbers.
        for path in [Self.ingestorPath,
                     "Maude/Context/CalendarLoad.swift",
                     "Maude/Context/CalendarLoadStore.swift",
                     "Maude/Context/CalendarLoadCopy.swift"] {
            let src = try SourceLint.text(path)
            for call in [#"\bprint\("#, #"\bdebugPrint\("#, #"\bNSLog\("#, #"\bos_log\b"#, #"\bLogger\b"#] {
                #expect(SourceLint.matches(call, in: src).isEmpty,
                        "\(path) logs — nothing on the calendar path may be written to a console")
            }
        }
    }

    // MARK: - 2. Nothing else in the repo reads events

    @Test func onlyTheIngestorReadsCalendarEvents() {
        let files = SourceLint.swiftFiles(in: "Maude")
        #expect(!files.isEmpty)
        for probe in [#"events\(matching:"#, #"predicateForEvents\("#, #"requestFullAccessToEvents"#] {
            let readers = files
                .filter { !SourceLint.matches(probe, in: $0.source).isEmpty }
                .map(\.path)
            #expect(readers == [Self.ingestorPath],
                    "\(probe) appears in \(readers) — the calendar read must have exactly one seam")
        }
    }

    @Test func eventKitIsImportedByTheReadSeamAndTheConsultWriterOnly() {
        // PlanConsultView WRITES one event the citizen asked Maude to create;
        // it never reads. Any third importer is a new, unreviewed calendar path.
        let importers = SourceLint.swiftFiles(in: "Maude")
            .filter { !SourceLint.matches(#"^\s*import EventKit"#, in: $0.source).isEmpty }
            .map(\.path)
            .sorted()
        #expect(importers == [Self.ingestorPath, "Maude/Views/PlanConsultView.swift"],
                "unexpected EventKit importers: \(importers)")
    }

    // MARK: - 3. There is no field content could be stored in

    @Test func storedShapeIsNumbersOnly() throws {
        let load = CalendarDayLoad(dayStart: Date(timeIntervalSince1970: 1_760_000_000),
                                   eventCount: 4, scheduledHours: 5.25, longestRunHours: 2.5,
                                   freeWakingHours: 10.75, earliestStartMinute: 540,
                                   latestEndMinute: 1_020)
        let data = try JSONEncoder().encode(load)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let expected: Set<String> = ["dayStart", "eventCount", "scheduledHours",
                                     "longestRunHours", "freeWakingHours",
                                     "earliestStartMinute", "latestEndMinute"]
        #expect(Set(object.keys) == expected,
                "the stored day gained or lost a field: \(object.keys.sorted())")
        for (key, value) in object {
            #expect(value is NSNumber, "\(key) is not a number — only numbers may be kept")
        }

        // Round-trips, so the numbers are the whole record.
        #expect(try JSONDecoder().decode(CalendarDayLoad.self, from: data) == load)
    }

    @Test func theIntervalThatLeavesEventKitCarriesNoWords() throws {
        // `ScheduledInterval` is the only value that crosses the seam. Two
        // instants and two flags: there is nothing here a title could ride in.
        let src = try SourceLint.text("Maude/Context/CalendarLoad.swift")
        let body = try #require(SourceLint.body(ofDeclarationContaining: "struct ScheduledInterval", in: src))
        #expect(SourceLint.matches(#":\s*String"#, in: body).isEmpty,
                "ScheduledInterval gained a String field — content could now cross the seam")
        #expect(src.contains("public let start: Date"))
        #expect(src.contains("public let end: Date"))
    }

    // MARK: - The permission prompt says exactly what the code does

    @Test func theUsageStringMakesThePromiseTheCodeKeeps() throws {
        let plistText = try SourceLint.text("Maude/Info.plist")
        let data = try #require(plistText.data(using: .utf8))
        let plist = try #require(try PropertyListSerialization
            .propertyList(from: data, format: nil) as? [String: Any])

        let usage = try #require(plist["NSCalendarsFullAccessUsageDescription"] as? String)
        #expect(usage.hasPrefix(CalendarLoadCopy.promise),
                "the prompt must open with the promise the app screen makes")
        // It names what is never read, in the citizen's words.
        for noun in ["Titles", "people", "places", "notes", "names of your calendars"] {
            #expect(usage.localizedCaseInsensitiveContains(noun), "the prompt does not mention \(noun)")
        }
        // It names the numbers that ARE kept.
        for noun in ["how many entries", "how many hours", "longest unbroken run"] {
            #expect(usage.localizedCaseInsensitiveContains(noun), "the prompt does not mention \(noun)")
        }

        // The narrower write-only grant must no longer make an app-wide
        // "never reads" claim — that stopped being true of the running app.
        let writeOnly = try #require(plist["NSCalendarsWriteOnlyAccessUsageDescription"] as? String)
        #expect(!writeOnly.localizedCaseInsensitiveContains("never reads your existing events"))
    }

    // MARK: - FR-NDG-06: every sentence passes the designated control

    @Test func everyCalendarSentencePassesNudgeGuard() {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.startOfDay(for: Date())

        var strings: [String] = [CalendarLoadCopy.promise, CalendarLoadCopy.neutralFallback]
        strings += CalendarLoadCopy.readsList
        strings += CalendarLoadCopy.neverList
        strings += [CalendarRowState.notConnected, .noEntriesAtAll,
                    .calibrating(daysSoFar: 0), .calibrating(daysSoFar: 1),
                    .calibrating(daysSoFar: 2), .ready].map(CalendarLoadCopy.stateLine)

        // A wide sweep of real shapes: empty days, single entries, all-day
        // marathons, half-hour fractions, midnight edges, every direction and
        // both notable states.
        let counts = [0, 1, 7]
        let hours: [Double] = [0, 0.5, 2.25, 6.5, 16]
        let directions: [CalendarLoadCopy.Direction?] = [nil, .busier, .quieter, .likeUsual]
        for c in counts {
            for h in hours {
                for run in [0.0, 1.0, h] {
                    for minute in [0, 540, 1_439] {
                        for d in directions {
                            for usual in [nil, 0.0, 3.4] as [Double?] {
                                for notable in [true, false] {
                                    let load = CalendarDayLoad(
                                        dayStart: day, eventCount: c, scheduledHours: h,
                                        longestRunHours: run,
                                        freeWakingHours: max(0, 16 - h),
                                        earliestStartMinute: c == 0 ? nil : minute,
                                        latestEndMinute: c == 0 ? nil : min(1_440, minute + 60))
                                    strings.append(CalendarLoadCopy.dayReadout(
                                        day: "Tuesday", state: .ready, load: load,
                                        usualScheduledHours: usual, direction: d, notable: notable))
                                }
                            }
                        }
                    }
                }
            }
        }
        // A never-read day, in every state.
        for state in [CalendarRowState.notConnected, .noEntriesAtAll,
                      .calibrating(daysSoFar: 3), .ready] {
            strings.append(CalendarLoadCopy.dayReadout(day: "Monday", state: state, load: nil,
                                                       usualScheduledHours: nil,
                                                       direction: nil, notable: false))
        }

        #expect(strings.count > 1_000, "the sweep got smaller — it is not covering the copy any more")
        #expect(Set(strings).count > 200, "the sweep is generating one sentence over and over")
        for s in strings {
            #expect(NudgeGuard.check(s) == nil, "FR-NDG-06 violation in calendar copy: \(s)")
            #expect(s != CalendarLoadCopy.neutralFallback || s == CalendarLoadCopy.neutralFallback)
        }
    }

    @Test func calendarCopyNeverJudgesOrClaimsCause() {
        let cal = Calendar(identifier: .gregorian)
        let load = CalendarDayLoad(dayStart: cal.startOfDay(for: Date()), eventCount: 9,
                                   scheduledHours: 9, longestRunHours: 5, freeWakingHours: 7,
                                   earliestStartMinute: 7 * 60, latestEndMinute: 19 * 60)
        let sentence = CalendarLoadCopy.dayReadout(day: "Thursday", state: .ready, load: load,
                                                   usualScheduledHours: 3, direction: .busier,
                                                   notable: true)
        // It compares to the person's own usual…
        #expect(sentence.contains("your usual"))
        // …states the non-finding disclaimer…
        #expect(sentence.localizedCaseInsensitiveContains("not a medical finding"))
        #expect(sentence.localizedCaseInsensitiveContains("not read as a cause"))
        // …and never tells anyone how to live.
        for judgement in ["too many", "should", "try to", "cut back", "reduce", "recommend",
                          "caused", "because of", "average person", "most people"] {
            #expect(!sentence.localizedCaseInsensitiveContains(judgement),
                    "calendar copy judged or claimed cause: \(judgement)")
        }
    }
}
