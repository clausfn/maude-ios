// DonationPayload.swift — FR-DON-02 · what a donation file contains, and the
// pure assembler that builds it.
//
// FOUR STRUCTURAL PROPERTIES, each of them a deliberate design choice rather
// than a convention (see `DonationEgressTests` for the lints that pin them):
//
//   1. **ENCODABLE ONLY.** No type in this file conforms to `Decodable`, and
//      nothing in the app target constructs a `JSONDecoder` for them. The app
//      can WRITE a donation and can never READ one. That is the technical half
//      of §6's hard rule: donated data cannot render as anyone's data in this
//      app because the app has no way to turn a donation back into values.
//   2. **NO SLOT FOR THE EXCLUDED.** The payload has no field for labs,
//      diagnoses, medication, journal text, notes, chat, location, routes,
//      blood pressure, AFib, insulin or body composition. Minimisation is
//      expressed as an absent field, not as a filter someone can forget to run.
//   3. **REAL ONLY.** Every row whose `provenance` is not `.real` is dropped by
//      the assembler. Demo seeds, mock providers and LV001 fixtures are
//      `.simulated`/`.external`, so fabricated data cannot enter a corpus even
//      from a mis-configured donor build.
//   4. **NO FREE TEXT.** Source names arrive from HealthKit as
//      `sourceRevision.source.name`, which is user-editable and routinely
//      carries a person's own name ("Claus' Apple Watch"). They are normalised
//      to a device CLASS plus a stable, salted discriminator, so arbitration and
//      dedup defects stay visible while the string itself never leaves.
//
// Pure Foundation + CryptoKit (for the discriminator hash): no SwiftUI, no
// network, no SwiftData writes.
import Foundation
import CryptoKit

// MARK: - Rows

/// One glucose reading. `t` is the SHIFTED instant (ISO-8601, UTC);
/// `tzOffsetSec` is the UTC offset that applied at the ORIGINAL instant, so a
/// clock change is still analysable after the shift.
struct DonatedGlucoseRow: Encodable, Equatable {
    let t: String
    let tzOffsetSec: Int
    let mmol: Double
    let source: String
}

/// One day of heart/respiratory figures, exactly as this phone stores them.
/// NOTE for the custodians: these are DAILY values, not per-beat samples — the
/// on-device store keeps one `HeartDaily` row per day. Nothing here pretends to
/// be sample-level.
struct DonatedHeartDayRow: Encodable, Equatable {
    let day: String            // shifted, yyyy-MM-dd
    let tzOffsetSec: Int
    let hrMean: Double?
    let hrMin: Double?
    let hrMax: Double?
    let hrvSDNN: Double?
    let restingHR: Double?
    let walkingHR: Double?
    let hrRecovery: Double?
    let respiratoryRate: Double?
    let spo2: Double?
    let vo2max: Double?
    let source: String
}

/// One sleep segment: the night it belongs to, the stage, the hours, the source.
struct DonatedSleepRow: Encodable, Equatable {
    let night: String          // shifted, yyyy-MM-dd
    let tzOffsetSec: Int
    let stage: String
    let hours: Double
    let source: String
}

/// One workout. Start, end, type, duration, distance, energy — never a route.
struct DonatedWorkoutRow: Encodable, Equatable {
    let start: String
    let end: String
    let tzOffsetSec: Int
    let type: String
    let durationMin: Double
    let kcal: Double?
    let distanceKm: Double?
    let source: String
}

// MARK: - Manifest

/// The file's own account of itself: what is inside, whose grant permits it,
/// how far the dates were moved, and what was deliberately left out. A custodian
/// who opens a donation learns its scope from the file, not from a side channel.
struct DonationManifest: Encodable, Equatable {
    let schema: String
    let programmeId: String
    let controller: String
    /// The grant reference from the donor's SIGNED consent form. It is also the
    /// donor code — one identifier, resolvable to a person only through the
    /// donor register held in the isolated environment.
    let grantReference: String
    let consentedScopes: [String]
    /// Window bounds AFTER the shift (the file's own coordinate system).
    let windowStart: String
    let windowEnd: String
    let windowDays: Int
    let dateShiftDays: Int
    let timeZoneIdentifier: String
    /// Real wall-clock instant the file was sealed — the retention clock starts
    /// here, so it is deliberately not shifted.
    let sealedAt: String
    let appVersion: String
    let appBuild: String
    let counts: [String: Int]
    let included: [String]
    let excluded: [String]
    let pseudonymityNotice: String
    let dateShiftNotice: String
}

// MARK: - Payload

/// Everything that gets sealed. The four series and the manifest — and no field
/// for anything else, ever.
struct DonationPayload: Encodable, Equatable {
    let manifest: DonationManifest
    let glucose: [DonatedGlucoseRow]
    let heartDaily: [DonatedHeartDayRow]
    let sleep: [DonatedSleepRow]
    let workouts: [DonatedWorkoutRow]

    /// Total rows across every series — what the screen reports and the ledger
    /// records. Zero means there is nothing to donate and the export refuses.
    var rowCount: Int { glucose.count + heartDaily.count + sleep.count + workouts.count }

    var countsByStream: [String: Int] {
        ["glucose": glucose.count, "heart_daily": heartDaily.count,
         "sleep": sleep.count, "workouts": workouts.count]
    }
}

// MARK: - Source classification

/// HealthKit source names are user-editable strings. `classify` maps them to a
/// device class from a fixed allow-list; anything unrecognised becomes
/// `unknown-<6 hex>` where the hex is a salted digest of the raw name. Two
/// different unknown sources stay distinguishable (which is what the dedup and
/// arbitration defects need) while the name itself never leaves the phone.
enum DonationSourceClass {

    /// (needle, class) — first match wins, so put longer needles first.
    private static let table: [(needle: String, label: String)] = [
        ("apple watch", "apple-watch"),
        ("watch", "apple-watch"),
        ("iphone", "iphone"),
        ("ipad", "ipad"),
        ("health", "apple-health"),
        ("oura", "oura"),
        ("whoop", "whoop"),
        ("garmin", "garmin"),
        ("polar", "polar"),
        ("fitbit", "fitbit"),
        ("withings", "withings"),
        ("eight sleep", "eight-sleep"),
        ("bevel", "bevel"),
        ("dexcom", "dexcom"),
        ("freestyle", "libre"),
        ("libre", "libre"),
        ("nightscout", "nightscout"),
        ("inbody", "inbody"),
        ("strava", "strava"),
        ("zwift", "zwift"),
        ("peloton", "peloton"),
    ]

    /// - Parameter salt: stable per donor (the grant reference), so the same
    ///   device maps to the same discriminator across a donor's files.
    static func classify(_ raw: String, salt: String) -> String {
        let lower = raw.lowercased()
        for entry in table where lower.contains(entry.needle) { return entry.label }
        let digest = SHA256.hash(data: Data((salt + "|" + lower).utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(6)
        return "unknown-\(hex)"
    }
}

// MARK: - Date shift

/// Per-donor date shift (§3.2, OD-D6): a whole number of WEEKS in ±26, derived
/// deterministically from the grant reference. Whole weeks keep weekday
/// structure intact; carrying each row's original UTC offset keeps clock
/// changes analysable. This breaks naive calendar linkage. It is not, and is
/// never described as, anonymisation.
enum DonationDateShift {

    static func days(forGrantReference ref: String) -> Int {
        let digest = SHA256.hash(data: Data(("maude.donation.shift|" + ref).utf8))
        let byte = Array(digest).first ?? 0
        let weeks = Int(byte % 53) - 26        // −26 … +26
        return weeks * 7
    }

    static func shift(_ date: Date, byDays days: Int) -> Date {
        date.addingTimeInterval(Double(days) * 86_400)
    }
}

// MARK: - Assembler

/// Builds a payload from the on-device rows. Pure and synchronous: given the
/// same rows and the same grant it produces the same bytes, which is what makes
/// the manifest an honest description rather than a hope.
enum DonationAssembler {

    /// Scope keys the programme collects. A row whose stream is not in the
    /// grant's `scopeKeys` is not assembled at all.
    enum Scope: String, CaseIterable {
        case glucose, heartDaily = "heart_daily", sleep, workouts

        var label: String {
            switch self {
            case .glucose:    return String(localized: "Glucose readings")
            case .heartDaily: return String(localized: "Daily heart figures")
            case .sleep:      return String(localized: "Sleep segments")
            case .workouts:   return String(localized: "Workouts")
            }
        }
    }

    struct Inputs {
        var glucose: [GlucoseSample] = []
        var heart: [HeartDaily] = []
        var sleep: [SleepSegment] = []
        var workouts: [Workout] = []
        init(glucose: [GlucoseSample] = [], heart: [HeartDaily] = [],
             sleep: [SleepSegment] = [], workouts: [Workout] = []) {
            self.glucose = glucose; self.heart = heart
            self.sleep = sleep; self.workouts = workouts
        }
    }

    /// - Parameters:
    ///   - grantReference: from the signed consent form; salts the source
    ///     discriminator and the date shift, and names the donor in the manifest.
    ///   - scopes: the streams the donor consented to, as raw scope keys.
    ///   - window: the consented retrospective window (unshifted, device time).
    static func build(inputs: Inputs,
                      grantReference: String,
                      scopes: Set<String>,
                      window: DateInterval,
                      timeZone: TimeZone = .current,
                      appVersion: String,
                      appBuild: String,
                      sealedAt: Date = Date()) -> DonationPayload {

        let shiftDays = DonationDateShift.days(forGrantReference: grantReference)
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        iso.formatOptions = [.withInternetDateTime]
        let dayFmt = DateFormatter()
        dayFmt.calendar = Calendar(identifier: .gregorian)
        dayFmt.locale = Locale(identifier: "en_US_POSIX")
        dayFmt.timeZone = TimeZone(secondsFromGMT: 0)
        dayFmt.dateFormat = "yyyy-MM-dd"

        func stamp(_ d: Date) -> String { iso.string(from: DonationDateShift.shift(d, byDays: shiftDays)) }
        func day(_ d: Date) -> String { dayFmt.string(from: DonationDateShift.shift(d, byDays: shiftDays)) }
        func offset(_ d: Date) -> Int { timeZone.secondsFromGMT(for: d) }
        func klass(_ s: String) -> String { DonationSourceClass.classify(s, salt: grantReference) }
        func inWindow(_ d: Date) -> Bool { d >= window.start && d <= window.end }

        // REAL only. A `.simulated` or `.external` row is dropped here and has
        // no other way into the payload.
        let glucose: [DonatedGlucoseRow] = scopes.contains(Scope.glucose.rawValue)
            ? inputs.glucose
                .filter { $0.provenance == .real && inWindow($0.ts) }
                .sorted { $0.ts < $1.ts }
                .map { DonatedGlucoseRow(t: stamp($0.ts), tzOffsetSec: offset($0.ts),
                                         mmol: $0.mmol, source: klass($0.source)) }
            : []

        let heart: [DonatedHeartDayRow] = scopes.contains(Scope.heartDaily.rawValue)
            ? inputs.heart
                .filter { $0.provenance == .real && inWindow($0.date) }
                .sorted { $0.date < $1.date }
                .map { row in
                    DonatedHeartDayRow(day: day(row.date), tzOffsetSec: offset(row.date),
                                       hrMean: row.hrMean, hrMin: row.hrMin, hrMax: row.hrMax,
                                       hrvSDNN: row.hrvMean, restingHR: row.rhr,
                                       walkingHR: row.walkHr, hrRecovery: row.hrRecovery,
                                       respiratoryRate: row.resp, spo2: row.spo2,
                                       vo2max: row.vo2max, source: klass(row.source))
                }
            : []

        let sleep: [DonatedSleepRow] = scopes.contains(Scope.sleep.rawValue)
            ? inputs.sleep
                .filter { $0.provenance == .real && inWindow($0.date) }
                .sorted { $0.date < $1.date }
                .map { DonatedSleepRow(night: day($0.date), tzOffsetSec: offset($0.date),
                                       stage: $0.stage.rawValue, hours: $0.hours,
                                       source: klass($0.source)) }
            : []

        let workouts: [DonatedWorkoutRow] = scopes.contains(Scope.workouts.rawValue)
            ? inputs.workouts
                .filter { $0.provenance == .real && inWindow($0.start) }
                .sorted { $0.start < $1.start }
                .map { DonatedWorkoutRow(start: stamp($0.start), end: stamp($0.end),
                                         tzOffsetSec: offset($0.start), type: $0.type,
                                         durationMin: $0.durMin, kcal: $0.kcal,
                                         distanceKm: $0.distKm, source: klass($0.source)) }
            : []

        let counts = ["glucose": glucose.count, "heart_daily": heart.count,
                      "sleep": sleep.count, "workouts": workouts.count]

        let manifest = DonationManifest(
            schema: DonationProgramme.payloadSchema,
            programmeId: DonationProgramme.id,
            controller: DonationProgramme.controller,
            grantReference: grantReference,
            consentedScopes: scopes.sorted(),
            windowStart: stamp(window.start),
            windowEnd: stamp(window.end),
            windowDays: Int((window.duration / 86_400).rounded()),
            dateShiftDays: shiftDays,
            timeZoneIdentifier: timeZone.identifier,
            sealedAt: iso.string(from: sealedAt),
            appVersion: appVersion,
            appBuild: appBuild,
            counts: counts,
            included: DonationProgramme.includedItems,
            excluded: DonationProgramme.excludedItems,
            pseudonymityNotice: DonationProgramme.pseudonymityNotice,
            dateShiftNotice: DonationProgramme.dateShiftNotice)

        return DonationPayload(manifest: manifest, glucose: glucose,
                               heartDaily: heart, sleep: sleep, workouts: workouts)
    }

    /// Canonical bytes for sealing: sorted keys so two runs over the same rows
    /// produce the same file, which makes the recorded digest meaningful.
    static func encode(_ payload: DonationPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }
}
