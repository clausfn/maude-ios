// PreVisitCheckView.swift — Stage E of the video-consult spec.
// Pre-visit check-in + device & connection test (Epic eCheck-in pattern, billing
// stripped): a per-visit share-consent gate plus a camera / microphone / connection
// test with green / amber / red status, so the citizen arrives ready and isn't
// surprised at the start. Addresses FB-AOUGIncO ("confusing start on video") and is
// the entry gate for the waiting room (FB-AOIWoD6l).
import SwiftUI
import AVFoundation
import Network

struct PreVisitCheckView: View {
    var recipientName: String
    var recipientId: String? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("consultShareConsent") private var shareConsent = false

    enum Check { case checking, ok, warn, fail }
    @State private var cam: Check = .checking
    @State private var mic: Check = .checking
    @State private var net: Check = .checking

    // FR-PRO-01: ticking the box on the sovereign backend ARMS a real per-consult
    // expiring grant + derived summary (the payload Liviqa PRO renders).
    @State private var arming = false
    @State private var armed = false
    @State private var armError: String?
    @State private var enterWaiting: ScheduledConsult?

    private var ready: Bool { shareConsent && cam == .ok && mic == .ok }

    /// A consult inside the join window (−15…+30 min) this check can flow into —
    /// the designed "Enter waiting room" CTA only appears when this is real.
    private var joinable: ScheduledConsult? {
        let window = appState.scheduledConsults.filter {
            let t = $0.at.timeIntervalSinceNow
            return t < 15 * 60 && t > -30 * 60 && $0.status == "scheduled"
        }
        return window.first(where: { $0.recipientName == recipientName }) ?? window.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) {
                    Text("Get ready").font(.lato(15, .black)).foregroundStyle(LiviqaTheme.ink)
                }
                .padding(.top, 6)

                Text("Before your consult")
                    .font(.liviqaSerif(22)).kerning(-0.2).foregroundStyle(LiviqaTheme.ink)
                Text("A quick check so your video call with \(recipientName) starts smoothly.")
                    .font(.lato(13)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3)

                // 1 — per-visit share consent
                kicker("What you'll share").padding(.top, 6)
                Button { Task { await toggleShare() } } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(shareConsent ? LiviqaTheme.moss : Color.clear)
                            RoundedRectangle(cornerRadius: 6).stroke(shareConsent ? LiviqaTheme.moss : LiviqaTheme.line, lineWidth: 1.5)
                            if shareConsent { Image(systemName: "checkmark").font(.lato(12, .bold)).foregroundStyle(.white) }
                        }
                        .frame(width: 22, height: 22).padding(.top, 1)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Share my consented metrics for this consult")
                                .font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
                                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                            Text("\(recipientName) sees only the derived summary you've consented to — never your raw data, which stays on this device.")
                                .font(.lato(12.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3)
                                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(shareConsent ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(shareConsent ? LiviqaTheme.moss3 : LiviqaTheme.line, lineWidth: shareConsent ? 1 : 0.5))
                }
                .buttonStyle(.plain)
                .disabled(arming)

                // Honest status of the per-consult grant (sovereign backend only —
                // in demo mode the tick stays local and nothing is transmitted).
                if arming {
                    shareStatus("Preparing your consented summary…")
                } else if armed {
                    shareStatus("Shared for this consult · expires automatically in 24 hours · listed in your consent record.")
                } else if let armError {
                    Text(armError).font(.lato(11.5)).foregroundStyle(LiviqaTheme.rust)
                }

                // 2 — device & connection test
                kicker("Your camera, mic & connection").padding(.top, 6)
                VStack(spacing: 0) {
                    checkRow("Camera", "video.fill", cam, fix: "Enable camera access for Liviqa in Settings.")
                    Divider().background(LiviqaTheme.line2).padding(.leading, 46)
                    checkRow("Microphone", "mic.fill", mic, fix: "Enable microphone access for Liviqa in Settings.")
                    Divider().background(LiviqaTheme.line2).padding(.leading, 46)
                    checkRow("Connection", "wifi", net, fix: "You appear offline — reconnect to Wi-Fi or mobile data.")
                }
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))

                // ready banner — "You're ready to join." only when there is a
                // genuinely joinable consult; otherwise the honest waiting phrasing.
                HStack(spacing: 9) {
                    Image(systemName: ready ? "checkmark.circle.fill" : "hourglass")
                        .font(.system(size: 15)).foregroundStyle(ready ? LiviqaTheme.moss : LiviqaTheme.ink4)
                    Text(ready ? (joinable != nil ? "You're ready to join."
                                                  : "You're ready — we'll bring you in when your clinician starts.")
                               : "Tick the share box and allow camera & mic to be ready.")
                        .font(.lato(12.5, .bold)).foregroundStyle(ready ? LiviqaTheme.ink : LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ready ? LiviqaTheme.moss2 : LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ready ? LiviqaTheme.moss3 : LiviqaTheme.line, lineWidth: ready ? 1 : 0.5))
                .padding(.top, 4)

                if ready, let sc = joinable {
                    // A7 canvas CTA — flows straight into the waiting room.
                    Button { enterWaiting = sc } label: {
                        Text("Enter waiting room").font(.lato(15, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(LiviqaTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain).padding(.top, 8)
                } else {
                    Button { dismiss() } label: {
                        Text("Done").font(.lato(15, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(LiviqaTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain).padding(.top, 8)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .task { await runChecks() }
        .fullScreenCover(item: $enterWaiting) { sc in
            WaitingRoomView(scheduled: sc)
        }
    }

    // MARK: - Per-consult share gate (FR-PRO-01)

    private func shareStatus(_ text: String) -> some View {
        Text(text)
            .font(.lato(11.5)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Consent-first: the tick IS the consent. On the sovereign backend it arms a
    /// short-lived summaries-only grant + derived summary push; un-ticking before
    /// the call revokes the grant this screen created. Off the sovereign backend
    /// (demo/mock) the tick stays local and nothing leaves the device.
    private func toggleShare() async {
        if shareConsent {
            shareConsent = false
            armed = false
            armError = nil
            if let rid = recipientId { await appState.disarmConsultShare(recipientId: rid) }
            return
        }
        shareConsent = true
        armError = nil
        guard let rid = recipientId, appState.sovereign != nil else { return }
        arming = true
        armed = await appState.armConsultShare(recipientId: rid)
        if !armed {
            // Never claim a share that didn't happen — revert the tick honestly.
            shareConsent = false
            armError = appState.lastError ?? "Couldn't prepare the consult share — please try again."
        }
        arming = false
    }

    // MARK: - Rows & helpers

    private func kicker(_ t: String) -> some View {
        Text(t.uppercased()).font(.liviqaKicker(10)).tracking(1.2).foregroundStyle(LiviqaTheme.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checkRow(_ label: String, _ icon: String, _ status: Check, fix: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(LiviqaTheme.ink3)
                .frame(width: 22).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
                Text(statusLabel(status)).font(.lato(12)).foregroundStyle(statusColor(status))
                if status == .fail || status == .warn {
                    Text(fix).font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
            Circle().fill(statusColor(status)).frame(width: 9, height: 9).padding(.top, 5)
        }
        .padding(14)
    }

    private func statusColor(_ s: Check) -> Color {
        switch s {
        case .ok: return LiviqaTheme.moss
        case .warn: return LiviqaTheme.clay
        case .fail: return LiviqaTheme.rust
        case .checking: return LiviqaTheme.ink4
        }
    }
    private func statusLabel(_ s: Check) -> String {
        switch s {
        case .ok: return "Ready"
        case .warn: return "Needs attention"
        case .fail: return "Blocked"
        case .checking: return "Checking…"
        }
    }

    private func runChecks() async {
        cam = await deviceCheck(.video)
        mic = await deviceCheck(.audio)
        net = await netCheck()
    }

    private func deviceCheck(_ type: AVMediaType) async -> Check {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return .ok
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type) ? .ok : .warn
        case .denied, .restricted: return .fail
        @unknown default: return .warn
        }
    }

    private func netCheck() async -> Check {
        // NWPathMonitor delivers the current path shortly after start; take the
        // first value via an AsyncStream (no shared mutable flag → concurrency-clean).
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "liviqa.previsit.net")
        let stream = AsyncStream<Bool> { cont in
            monitor.pathUpdateHandler = { cont.yield($0.status == .satisfied); cont.finish() }
            monitor.start(queue: queue)
        }
        defer { monitor.cancel() }
        for await satisfied in stream { return satisfied ? .ok : .warn }
        return .warn
    }
}
