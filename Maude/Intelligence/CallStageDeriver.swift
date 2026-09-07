// CallStageDeriver.swift — what the consult stage is allowed to SAY about the
// media it is (not) showing. Pure Foundation, no SwiftUI, no I/O.
//
// The device sweep (2026-08-12) caught the in-call stage as a fully black
// rectangle: the room webview had not produced a frame and nothing else was
// drawn, so the screen said nothing at all about why. A black rectangle is not
// an honest state — and on a phone with no camera, or a room that never loads,
// it is the state a real citizen lands in.
//
// RAIL: the stage may never imply a connection that does not exist. Every line
// below is written from what the app actually knows locally — the room URL was
// configured or not, the room content finished loading or failed, this device
// has a camera or does not — and nothing more. `CallStagePhase.live` is the
// only state where the video provider owns the surface, and it deliberately
// returns NO copy: with media up, Maude has nothing left to claim.
import Foundation

/// What the stage actually knows about the room it was asked to show.
enum CallStagePhase: String, Equatable, Sendable {
    /// No EU room is configured for this clinic — there is nothing to connect to.
    case notConfigured
    /// The room URL is loading. Nothing has arrived yet.
    case connecting
    /// The room content loaded — the video provider owns the stage from here.
    case live
    /// The room failed to load. We are NOT connected.
    case unreachable
}

/// What this device can contribute. Read from local, prompt-free facts only
/// (a camera exists / the user already answered the OS permission) — asking
/// this question must never trigger a permission dialog.
enum CallCameraStatus: String, Equatable, Sendable {
    case ready
    case noDevice
    case notPermitted
}

/// The lines the placeholder prints. `nil` from the deriver means "draw nothing".
struct CallStageCopy: Equatable, Sendable {
    /// Short state line under the participant's name.
    let status: String
    /// One supporting sentence — what is happening, honestly.
    let detail: String
    /// Caption on the small self tile.
    let selfCaption: String
    /// Only a genuinely retryable failure offers a retry.
    let showsRetry: Bool
}

enum CallStageDeriver {

    /// The stage copy for a phase, or nil when live media owns the surface.
    static func copy(phase: CallStagePhase, camera: CallCameraStatus) -> CallStageCopy? {
        guard phase != .live else { return nil }
        return CallStageCopy(status: status(phase),
                             detail: detail(phase),
                             selfCaption: selfCaption(phase: phase, camera: camera),
                             showsRetry: phase == .unreachable)
    }

    private static func status(_ phase: CallStagePhase) -> String {
        switch phase {
        case .notConfigured: return String(localized: "Secure EU room · not set up yet")
        case .connecting:    return String(localized: "Connecting · secure EU room")
        case .unreachable:   return String(localized: "Not connected")
        case .live:          return ""
        }
    }

    private static func detail(_ phase: CallStagePhase) -> String {
        switch phase {
        case .notConfigured:
            return String(localized: "Live video starts once your clinic's EU video room is configured.")
        case .connecting:
            return String(localized: "Waiting for their camera — it appears here once the call is up.")
        case .unreachable:
            return String(localized: "We couldn't reach the secure room. Check your connection and try again.")
        case .live:
            return ""
        }
    }

    /// The self tile never claims your camera is on: it reports the device fact.
    private static func selfCaption(phase: CallStagePhase, camera: CallCameraStatus) -> String {
        switch camera {
        case .noDevice:     return String(localized: "No camera on this device")
        case .notPermitted: return String(localized: "Camera off")
        case .ready:
            return phase == .connecting
                ? String(localized: "Waiting for your camera")
                : String(localized: "Camera off")
        }
    }
}
