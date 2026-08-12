// LiviqaWidgetSnapshot.swift — the ONLY thing that crosses from the app into a
// widget / complication process (FR-WID-01, Bevel absorb ①).
//
// WHY A SNAPSHOT AT ALL
// A WidgetKit extension is a separate process with its own sandbox. It cannot
// open the app's protected local store (AES-256 + Secure Enclave, unlocked only
// inside the app), and it must never hold a second copy of the health record.
// So the app derives as it always does, then publishes a TINY, already-rendered
// snapshot into the shared App Group container. The widget reads that and
// nothing else. No HealthKit in the extension, no store, no network.
//
// WHAT MAY TRAVEL — a hard allow-list, enforced by review + T-WID-01:
//   • `verdict`  — ONE already-FR-NDG-06-clean sentence (the same sentence Home
//                  shows; the publisher re-checks it through NudgeGuard before
//                  it is ever written).
//   • `chips`    — the DECOMPOSED signals behind that sentence: label, the
//                  user's own value, and a personal-baseline-relative word.
//                  This is the structural answer to score opacity: the widget
//                  shows the parts, never a composite score.
//   • `timeInRange` — a two-state read (inside / outside YOUR range) plus the
//                  reading count that backs it. Never the clinical 5-band ramp,
//                  never clinical red — a widget is not a clinical surface.
//   • `derivedAt` — so the widget can say honestly WHEN this was true.
//
// WHAT MAY NEVER TRAVEL:
//   • `provenance{REAL,SIMULATED,EXTERNAL}` — a DATA field. It is not in this
//     type, has no encoding key, and must never be added. (T-PROV-01 guards the
//     view layer; T-WID-01 asserts the encoded key set here.)
//   • raw samples, identifiers, names, clinician data, any population or
//     clinical reference range.
//
// Pure Foundation (NFR-PORT-01) — no SwiftUI, no WidgetKit, no HealthKit — so it
// compiles unchanged into the iOS app, the iOS widget extension, and the watchOS
// complication extension, and is unit-testable in isolation.
import Foundation

// MARK: - Edition

/// Which edition produced the snapshot. Mirrors `TodayView.isEveningEdition`
/// (evening runs 21:00 → 04:00) so wrist, widget and screen never disagree.
public nonisolated enum WidgetEdition: String, Codable, Sendable {
    case morning, evening

    /// The app's edition rule, kept in ONE place so the surfaces cannot drift.
    /// NOTE: thresholds mirror `TodayView.isEveningEdition` — change together.
    public static func current(at date: Date = Date(),
                               calendar: Calendar = Calendar(identifier: .gregorian)) -> WidgetEdition {
        let h = calendar.component(.hour, from: date)
        return (h >= 21 || h < 4) ? .evening : .morning
    }
}

// MARK: - Decomposed signal chip

/// One decomposed signal — a part of the shown work, never a score component
/// with a hidden weight. `value` is the user's OWN number, already formatted by
/// the app exactly as Home formats it.
public nonisolated struct WidgetSignalChip: Codable, Equatable, Sendable {
    /// Domain name, e.g. "Sleep". Already localised by the app.
    public let label: String
    /// The user's own value, e.g. "6h52", "48 ms", "58".
    public let value: String
    /// Personal-baseline-relative word, e.g. "As usual" / "Worth a look".
    /// nil while calibrating — the widget then prints nothing rather than guess.
    public let note: String?
    /// The locked two-state flag: false = in your usual place, true = worth
    /// noticing. Renders as the amber clay dot. NEVER red.
    public let needsAttention: Bool

    public init(label: String, value: String, note: String? = nil, needsAttention: Bool = false) {
        self.label = label
        self.value = value
        self.note = note
        self.needsAttention = needsAttention
    }
}

// MARK: - Compact time-in-range

/// The compact TIR read for a widget: TWO states only — inside your range and
/// outside it. The clinical five-band ramp and `clinRed` stay on the Glucose
/// detail screen (Area ③), which is the app's only clinical-red surface.
///
/// HONESTY NOTE on the window. `inRangePct` is the SAME figure the Home glucose
/// chip shows, which `PassportStatsDeriver` computes across the app's whole
/// loaded sample window (30 days steady state, 90 on first backfill) — a window
/// no Liviqa surface currently states. So this type deliberately does NOT claim
/// a window for the percentage. What it can state exactly is COVERAGE: how many
/// of the user's last 7 days actually carry glucose readings
/// (`TodaySignals.inRangeWeek.count`). That is the shown work — it tells you how
/// much data is behind the picture — without asserting anything untrue.
public nonisolated struct WidgetTimeInRange: Codable, Equatable, Sendable {
    /// % of readings inside the user's OWN target band, 0…100.
    public let inRangePct: Int
    /// Days within `coverageWindowDays` that carry glucose readings.
    /// 0 ⇒ unknown → the coverage line is omitted rather than guessed.
    public let daysWithReadings: Int
    /// The coverage window the count is taken over (7 — the Home chip's week).
    public let coverageWindowDays: Int

    public init(inRangePct: Int, daysWithReadings: Int, coverageWindowDays: Int = 7) {
        self.inRangePct = inRangePct
        self.daysWithReadings = daysWithReadings
        self.coverageWindowDays = coverageWindowDays
    }

    /// Defensive clamp — a widget must never draw a bar past its track.
    public var insidePct: Int { min(100, max(0, inRangePct)) }
    public var outsidePct: Int { 100 - insidePct }
    /// 0…1 fill fraction for the two-state bar.
    public var insideFraction: Double { Double(insidePct) / 100.0 }
}

// MARK: - The snapshot

public nonisolated struct LiviqaWidgetSnapshot: Codable, Equatable, Sendable {

    /// Bumped whenever the shape changes. A widget that reads a snapshot it does
    /// not understand shows the honest empty state rather than a wrong one.
    public static let currentSchema = 1

    public let schema: Int
    /// When the app DERIVED this — the widget renders "as of HH:MM" from it.
    /// A widget always shows cached state; saying when is the honest thing.
    public let derivedAt: Date
    public let edition: WidgetEdition
    /// One allow-listed sentence. Already NudgeGuard-clean when written.
    public let verdict: String
    /// The decomposed parts behind the sentence. May be empty (honest).
    public let chips: [WidgetSignalChip]
    /// nil ⇒ no glucose readings → the widget says so; it never invents a bar.
    public let timeInRange: WidgetTimeInRange?

    public init(schema: Int = LiviqaWidgetSnapshot.currentSchema,
                derivedAt: Date,
                edition: WidgetEdition,
                verdict: String,
                chips: [WidgetSignalChip],
                timeInRange: WidgetTimeInRange?) {
        self.schema = schema
        self.derivedAt = derivedAt
        self.edition = edition
        self.verdict = verdict
        self.chips = chips
        self.timeInRange = timeInRange
    }

    /// Explicit keys so an accidental new stored property cannot silently start
    /// crossing the process boundary — adding one here is a deliberate act that
    /// a reviewer sees. `provenance` is not here and must never be added.
    public enum CodingKeys: String, CodingKey {
        case schema, derivedAt, edition, verdict, chips, timeInRange
    }

    public var isSchemaSupported: Bool { schema == Self.currentSchema }
}

// MARK: - Staleness copy

public nonisolated enum WidgetStaleness {

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    /// "as of 07:12" for a same-day snapshot, "as of 07:12, 12 Aug" once it is
    /// older than today. 24-hour clock, matching the app (DayReplayDeriver).
    /// A widget shows cached state — this line is what makes that honest.
    public static func asOfText(_ derivedAt: Date,
                                now: Date = Date(),
                                calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let time = formatter("HH:mm", calendar).string(from: derivedAt)
        if calendar.isDate(derivedAt, inSameDayAs: now) {
            return String(localized: "as of \(time)")
        }
        let day = formatter("d MMM", calendar).string(from: derivedAt)
        return String(localized: "as of \(time), \(day)")
    }

    /// Bare "07:12" — for the accessory families where a full phrase will not fit.
    public static func timeText(_ derivedAt: Date,
                                calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        formatter("HH:mm", calendar).string(from: derivedAt)
    }
}

// MARK: - Shared-container store

/// Reads/writes the snapshot in the App Group container shared by the app, the
/// iOS widget extension and the watchOS complication extension.
///
/// The App Group identifier is NEVER hard-coded. It comes from each target's
/// Info.plist key `LiviqaAppGroup`, which is set to `$(APP_GROUP)` — the single
/// value defined in `Config/Signing.xcconfig`. If that key is missing the store
/// fails CLOSED: reads return nil (widget shows its honest empty state) and
/// writes return false. It never falls back to a guessed group name.
public nonisolated enum LiviqaWidgetSnapshotStore {

    /// Info.plist key carrying `$(APP_GROUP)`. See LiviqaWidgets/SETUP.md §5.
    public static let appGroupInfoKey = "LiviqaAppGroup"
    /// UserDefaults key inside the shared suite. Versioned with the schema.
    public static let defaultsKey = "liviqa.widget.snapshot.v1"

    /// The configured App Group id, or nil when the target was not set up.
    public static func appGroupIdentifier(bundle: Bundle = .main) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: appGroupInfoKey) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Reject an unexpanded build setting or a value that is not a group id.
        guard value.hasPrefix("group."), !value.contains("$(") else { return nil }
        return value
    }

    public static func defaults(bundle: Bundle = .main) -> UserDefaults? {
        guard let id = appGroupIdentifier(bundle: bundle) else {
            #if DEBUG
            // Loud in development, silent-and-empty in production.
            print("[LiviqaWidgets] Info.plist key '\(appGroupInfoKey)' missing or "
                  + "unexpanded — snapshot sharing is OFF. See LiviqaWidgets/SETUP.md §5.")
            #endif
            return nil
        }
        return UserDefaults(suiteName: id)
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private static var decoder: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    /// nil ⇒ nothing published yet, or an unreadable/unsupported payload. Every
    /// nil path is an HONEST EMPTY STATE on screen, never a placeholder number.
    public static func load(from store: UserDefaults? = defaults()) -> LiviqaWidgetSnapshot? {
        guard let store, let data = store.data(forKey: defaultsKey) else { return nil }
        guard let snap = try? decoder.decode(LiviqaWidgetSnapshot.self, from: data) else { return nil }
        return snap.isSchemaSupported ? snap : nil
    }

    /// Returns false when the App Group is not configured — the caller may log,
    /// but the app must keep working exactly as before.
    @discardableResult
    public static func save(_ snapshot: LiviqaWidgetSnapshot,
                            to store: UserDefaults? = defaults()) -> Bool {
        guard let store, let data = try? encoder.encode(snapshot) else { return false }
        store.set(data, forKey: defaultsKey)
        return true
    }

    /// Remove the snapshot — used when the app has nothing honest to show
    /// (signed out, data disconnected, no readings). The widget then falls back
    /// to its empty state instead of showing a stale figure forever.
    public static func clear(in store: UserDefaults? = defaults()) {
        store?.removeObject(forKey: defaultsKey)
    }
}
