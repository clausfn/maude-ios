// ContextFlag.swift — FR-CTX-04: the citizen's own "life explains this" marker.
//
// Bevel absorb ③, expressed in Liviqa's voice. The user marks a stretch of days
// as travelling / unwell / off-routine. The marker is DECLARED DATA — the user
// says it, Liviqa never infers it — and its ONLY effect on the intelligence
// layer is SUPPRESSION: while a day is marked, baseline-comparison nudges are
// not emitted for it (see `ContextFlagDeriver` + `NudgeEngine`). A flag can
// never create a nudge, raise a priority, or change a number. That direction is
// the FR-NDG-06 interaction rule and it is unit-tested (T-CTX-04).
//
// Nothing here fabricates data: readings on marked days are still recorded,
// still counted, still shown. Marking changes how a day is READ, never what it
// contains. Charts render marked days neutral (dimmed + hatched), never as
// deviations and never with alarm colour.
//
// Pure Foundation, Codable, tiny — device-local only (ContextFlagStore).
import Foundation

/// The three kinds the user can pick. Deliberately closed: a free-text "reason"
/// would become an inference surface, and there is no fourth honest bucket.
public nonisolated enum ContextFlagKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case travelling
    case unwell
    case offRoutine

    public var id: String { rawValue }

    /// Chip / picker label.
    var label: String {
        switch self {
        case .travelling: return String(localized: "Travelling")
        case .unwell:     return String(localized: "Unwell")
        case .offRoutine: return String(localized: "Off routine")
        }
    }

    /// One quiet line under the label in the picker — what the user is saying.
    var explainer: String {
        switch self {
        case .travelling: return String(localized: "Another time zone, another bed, meals at odd hours.")
        case .unwell:     return String(localized: "A cold, a bug, or a few rough days.")
        case .offRoutine: return String(localized: "A stretch that just doesn't look like your usual week.")
        }
    }

    /// The Today verdict register while this flag is active. FIXED template text
    /// — never assembled from readings, never from the user's note.
    var todayHeadline: String {
        switch self {
        case .travelling: return String(localized: "Calibrating around your trip.")
        case .unwell:     return String(localized: "Calibrating around a rough patch.")
        case .offRoutine: return String(localized: "Calibrating around your off-routine days.")
        }
    }

    /// The sentence under the register. Says exactly what marking does — and
    /// what it does not do. No claim beyond the truth.
    var todayDetail: String {
        switch self {
        case .travelling:
            return String(localized: "You've marked these days as travelling. Your readings are still recorded and still yours — Liviqa just won't read them as drifting from your usual.")
        case .unwell:
            return String(localized: "You've marked these days as unwell. Your readings are still recorded and still yours — Liviqa just won't read them as drifting from your usual.")
        case .offRoutine:
            return String(localized: "You've marked these days as off routine. Your readings are still recorded and still yours — Liviqa just won't read them as drifting from your usual.")
        }
    }

    /// The calm line that stands in for the attention slot while marked.
    var quietNote: String {
        String(localized: "Nothing is being flagged while these days are marked. Your numbers are all still here — open any signal to see them.")
    }

    var systemImage: String {
        switch self {
        case .travelling: return "airplane"
        case .unwell:     return "bandage"
        case .offRoutine: return "calendar.badge.clock"
        }
    }
}

/// One marked stretch of days. `startedOn`/`endedOn` are day-start instants and
/// BOTH ends are inclusive; `endedOn == nil` means the stretch is still open.
///
/// `note` is the user's own words, kept for the user's own eyes on the review
/// screen. It is DISPLAY-ONLY: it is never parsed, never derived from, and by
/// construction never crosses into `Liviqa/Intelligence` — the engine is handed
/// `ContextWindow` values, which have no note field at all.
nonisolated struct ContextFlag: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let kind: ContextFlagKind
    let startedOn: Date
    var endedOn: Date?
    var note: String?

    init(id: UUID = UUID(), kind: ContextFlagKind,
         startedOn: Date, endedOn: Date? = nil, note: String? = nil) {
        self.id = id
        self.kind = kind
        self.startedOn = startedOn
        self.endedOn = endedOn
        self.note = note
    }

    /// Still open — no end day recorded.
    var isOpen: Bool { endedOn == nil }

    /// The engine-facing projection: kind + dates, nothing else.
    var window: ContextWindow {
        ContextWindow(kind: kind, start: startedOn, end: endedOn)
    }

    /// True when this flag covers the given instant's day.
    func covers(_ instant: Date, calendar: Calendar = ContextWindow.calendar) -> Bool {
        window.covers(instant, calendar: calendar)
    }
}
