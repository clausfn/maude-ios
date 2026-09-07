import Testing
import Foundation
@testable import Maude

// Care + sharing fixes from the 2026-08-12 device sweep.
//
// Two rails are locked here:
//  · the consult stage may never IMPLY a connection it does not have (the sweep
//    caught it as a blank black rectangle, which says nothing at all);
//  · the share consent surface states its detail level EXPLICITLY, and the copy
//    it prints is derived from that same value — so a widened detail level
//    cannot leave the promise on screen unchanged.

struct ShareGranularityTests {

    /// Every consented group is requested at summary level — no group can be
    /// left out of the map and pick up a looser server-side default.
    @Test func everyConsentedGroupIsRequestedAtSummaryLevel() {
        let groups: Set<String> = ["glucose", "sleep", "recovery", "activity"]
        let map = ShareGranularity.summariesOnly(for: groups)

        #expect(Set(map.keys) == groups, "a missing key is a group with no stated detail level")
        #expect(map.values.allSatisfy { $0 == ShareGranularity.summary })
        #expect(ShareGranularity.isSummariesOnly(map))
    }

    @Test func nothingConsentedRequestsNothing() {
        let map = ShareGranularity.summariesOnly(for: [])
        #expect(map.isEmpty)
        // An empty map promises nothing, so it is not a summaries-only promise.
        #expect(!ShareGranularity.isSummariesOnly(map))
    }

    /// The guard that makes the consent copy self-correcting: one non-summary
    /// entry and the screen stops printing the summaries-only line.
    @Test func oneWiderEntryBreaksThePromiseAndTheCopy() {
        var map = ShareGranularity.summariesOnly(for: ["glucose", "sleep"])
        map["glucose"] = "raw"

        #expect(!ShareGranularity.isSummariesOnly(map))
        #expect(!ShareGranularity.areaSuffix(map).lowercased().contains("summaries only"),
                "the area suffix must stop claiming summaries-only, got \(ShareGranularity.areaSuffix(map))")
        #expect(!ShareGranularity.label(map).lowercased().contains("never your individual readings"),
                "the detail-level label must stop making the individual-readings promise")
    }

    @Test func theSummariesOnlyCopyIsDerivedNotTyped() {
        let map = ShareGranularity.summariesOnly(for: ["glucose"])
        #expect(ShareGranularity.areaSuffix(map).lowercased().contains("summaries only"))
        #expect(ShareGranularity.label(map).lowercased().contains("summary"))
    }
}

struct CallStageDeriverTests {

    /// With media up, the video provider owns the surface and Maude says nothing.
    @Test func liveMediaDrawsNoPlaceholder() {
        #expect(CallStageDeriver.copy(phase: .live, camera: .ready) == nil)
        #expect(CallStageDeriver.copy(phase: .live, camera: .noDevice) == nil)
    }

    /// The sweep's failure mode: a stage with no picture must still say something.
    @Test func everyNonLivePhaseHasCopyForBothHalvesOfTheStage() {
        for phase in [CallStagePhase.notConfigured, .connecting, .unreachable] {
            let copy = CallStageDeriver.copy(phase: phase, camera: .ready)
            #expect(copy != nil, "\(phase) would render a blank stage")
            #expect(copy?.status.isEmpty == false, "\(phase) has no status line")
            #expect(copy?.detail.isEmpty == false, "\(phase) has no explanation")
            #expect(copy?.selfCaption.isEmpty == false, "\(phase) has no self-tile caption")
        }
    }

    /// The rail: never imply a connection that does not exist.
    @Test func aStageWithNoRoomNeverClaimsToBeConnecting() {
        let copy = CallStageDeriver.copy(phase: .notConfigured, camera: .ready)
        let text = ((copy?.status ?? "") + " " + (copy?.detail ?? "")).lowercased()
        #expect(!text.contains("connecting"), "nothing is being connected to: \(text)")
        #expect(copy?.showsRetry == false, "there is nothing to retry without a room")
    }

    @Test func anUnreachableRoomSaysSoAndOffersARetry() {
        let copy = CallStageDeriver.copy(phase: .unreachable, camera: .ready)
        #expect(copy?.showsRetry == true)
        #expect(copy?.status.lowercased().contains("not connected") == true,
                "got \(copy?.status ?? "nil")")
    }

    /// Only `.connecting` may say we are waiting for a camera — in every other
    /// phase there is no call in progress to wait inside of.
    @Test func waitingForYourCameraIsOnlySaidWhileConnecting() {
        #expect(CallStageDeriver.copy(phase: .connecting, camera: .ready)?.selfCaption
                == String(localized: "Waiting for your camera"))
        for phase in [CallStagePhase.notConfigured, .unreachable] {
            let caption = CallStageDeriver.copy(phase: phase, camera: .ready)?.selfCaption ?? ""
            #expect(!caption.lowercased().contains("waiting"), "\(phase) said: \(caption)")
        }
    }

    /// A device fact beats the phase: no camera is no camera, whatever the room
    /// is doing — the corner never pretends a picture is on its way.
    @Test func theSelfTileReportsTheDeviceFactInEveryPhase() {
        for phase in [CallStagePhase.notConfigured, .connecting, .unreachable] {
            #expect(CallStageDeriver.copy(phase: phase, camera: .noDevice)?.selfCaption
                    == String(localized: "No camera on this device"))
            #expect(CallStageDeriver.copy(phase: phase, camera: .notPermitted)?.selfCaption
                    == String(localized: "Camera off"))
        }
    }
}
