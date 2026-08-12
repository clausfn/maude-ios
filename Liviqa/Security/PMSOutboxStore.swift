// PMSOutboxStore.swift — UC-19 / FR-PMS-01: the post-market-surveillance intake
// outbox for "Report a wrong or harmful insight".
//
// SUMMARY-ONLY BY CONSTRUCTION: `PMSReport` carries the nudge's id, tag and
// headline, when it was shown, a fixed-choice reason and the user's optional
// note — and has NO field that can hold a reading, a series, or any raw health
// value. The payload is a summary of the pattern, never the data behind it
// (unit-tested key allow-list, T-PMS-01).
//
// QUEUE-ONLY TRANSPORT (today): the sovereign backend client exposes no PMS
// endpoint yet, so reports persist here — device-local JSON in Application
// Support with NSFileProtectionComplete (encrypted at rest) — and the UI says
// so honestly ("will send when a reporting channel opens"). When the backend
// route lands, a send loop marks records `.sent`; nothing transmits until then.
// Wiped by the GDPR erase-everything path alongside the journal.
import Foundation

/// One report record — the EXACT payload that is queued (and would eventually
/// leave the device). Every field is named in the user's receipt.
struct PMSReport: Codable, Identifiable, Equatable {

    enum Status: String, Codable { case queued, sent }

    /// Fixed-choice reasons (ScrReportNudge). Stable raw values for the record;
    /// display strings live on `label`.
    enum Reason: String, Codable, CaseIterable {
        case doesntMatchHowIFeel = "doesnt_match_how_i_feel"
        case feltAlarmingOrUnsafe = "felt_alarming_or_unsafe"
        case numbersLookWrong = "numbers_look_wrong"
        case readLikeMedicalAdvice = "read_like_medical_advice"
        case somethingElse = "something_else"

        var label: String {
            switch self {
            case .doesntMatchHowIFeel:  return String(localized: "It doesn't match how I feel")
            case .feltAlarmingOrUnsafe: return String(localized: "It felt alarming or unsafe")
            case .numbersLookWrong:     return String(localized: "The numbers look wrong")
            case .readLikeMedicalAdvice: return String(localized: "It read like medical advice")
            case .somethingElse:        return String(localized: "Something else")
            }
        }
    }

    let id: UUID
    let createdAt: Date
    let nudgeID: UUID
    let tag: String            // e.g. "Sleep · meals"
    let headline: String       // the nudge sentence being reported
    let shownAt: String        // display string, e.g. "today · 13:40"
    let reason: Reason
    let note: String?          // the user's own words (optional)
    var status: Status
}

enum PMSOutboxStore {

    /// Default on-device location (Application Support/pms-outbox.v1.json).
    static func defaultURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("pms-outbox.v1.json")
    }

    /// Loaded outbox, or nil when nothing has been queued yet.
    static func load(from url: URL? = PMSOutboxStore.defaultURL()) -> [PMSReport]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([PMSReport].self, from: data)
    }

    /// Atomically persist the outbox, file-protected (encrypted at rest when the
    /// device is locked). Failures are swallowed — reporting must never crash.
    static func save(_ reports: [PMSReport], to url: URL? = PMSOutboxStore.defaultURL()) {
        guard let url, let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Append one report to the persisted outbox.
    static func queue(_ report: PMSReport, at url: URL? = PMSOutboxStore.defaultURL()) {
        var all = load(from: url) ?? []
        all.append(report)
        save(all, to: url)
    }
}
