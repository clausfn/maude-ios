// ConsultView.swift — citizen side of a secure video consultation. Joins the
// same deterministic EU-sovereign room as the console (`maude-consult-<id>`)
// and owns the recording consent (FR-WAL / Video_and_OAuth_Contract_v01).
//
// A7.2 (2026-08-12): rebuilt from a light card page into the designed full-bleed
// call stage (#0A0E12): live media fills the screen, the recording-consent
// banner floats OVER the stage, the summaries-only consent note is pinned above
// the controls, and mic/camera/hang-up stay Jitsi-toolbar-provided inside the
// webview (the room URL strips the toolbar to exactly those three) plus a native
// leave. The connecting shell keeps the FB 10.39 fix — who you're talking to
// (name · organisation) is always visible before media is up.
//
// The consented, derived data the recipient sees is summarised in the pinned
// note; raw HealthKit samples never leave the device. No US-parented video
// provider on this PII path (NFR-SEC-07): live media only when an EU Jitsi
// domain is set.
//
// 2026-08-13 (device sweep): the stage is never blank again. The room webview
// reports its real load state (WKNavigationDelegate) and anything short of
// loaded content is covered by `CallStagePlaceholder` — witness ring, who you're
// talking to, an honest line from `CallStageDeriver`, and a self tile that says
// why your own picture is missing. Copy is derived, so the stage can't claim a
// connection it doesn't have. The recording-consent banner and the summaries-only
// note are untouched (safety copy).
import SwiftUI
import WebKit
import AVFoundation

struct ConsultView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let consult: ConsultSummary

    @State private var recordingConsent: Bool
    @State private var working = false
    @State private var error: String?

    // Stage state — the real load state of the room, and this device's camera.
    @State private var loadPhase: CallStagePhase = .connecting
    @State private var cameraStatus: CallCameraStatus = .ready
    /// Bumped by "Try again" — a change re-issues the room request.
    @State private var reloadToken = 0

    // Call-surface palette (fixed — a call stage never follows the page theme).
    private let stage = Color(hex: 0x0A0E12)
    private let brass = Color(hex: 0xC9A96A)
    private let warmInk = Color(hex: 0xF0EAE0)

    init(consult: ConsultSummary) {
        self.consult = consult
        _recordingConsent = State(initialValue: consult.recordingConsent)
    }

    /// In-call display name: the pseudonymous alias (LV001) — never typed,
    /// never the real name. Jitsi stops asking for a name entirely.
    private var callName: String {
        let raw = appState.profile?.alias ?? appState.profile?.displayName ?? "Citizen"
        return raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "Citizen"
    }

    /// Initials for the self tile — the pseudonymous alias, never the real name.
    private var selfInitials: String {
        let raw = appState.profile?.alias ?? appState.profile?.displayName ?? "You"
        return String(raw.prefix(2)).uppercased()
    }

    /// What the stage knows: no room configured beats any load state.
    private var stagePhase: CallStagePhase {
        roomURL == nil ? .notConfigured : loadPhase
    }

    private var roomURL: URL? {
        guard Config.videoConsultEnabled,
              let domain = Config.jitsiDomain, !domain.isEmpty else { return nil }
        // Config overrides via URL hash keep the call inside the webview:
        //  · disableDeepLinking — never bounce out to the native Jitsi app
        //  · prejoinPageEnabled=false — join straight in (no extra tap)
        //  · startWithVideoMuted=false — camera on, this is a consult
        // Strip everything a citizen doesn't need: no chat/polls/invite/moderator,
        // no raw room-id title — just "Maude video call" + mic, camera, hang up.
        let frag = "#config.disableDeepLinking=true" +
                   "&config.prejoinPageEnabled=false" +
                   "&config.startWithVideoMuted=false" +
                   "&config.subject=%22Maude%20video%20call%22" +
                   "&config.hideConferenceTimer=false" +
                   "&config.disableInviteFunctions=true" +
                   "&config.disablePolls=true" +
                   "&config.toolbarButtons=%5B%22microphone%22,%22camera%22,%22hangup%22%5D" +
                   "&userInfo.displayName=%22\(callName)%22"
        return URL(string: "https://\(domain)/\(consult.roomName)\(frag)")
    }

    var body: some View {
        ZStack {
            stage.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── the stage: live media, or the secure connecting shell ──
                ZStack(alignment: .top) {
                    if let url = roomURL {
                        ConsultWebView(url: url, reloadToken: reloadToken) { phase in
                            loadPhase = phase
                        }
                        .ignoresSafeArea(edges: .top)
                    }

                    // Anything short of loaded room content is covered by an
                    // honest placeholder — never a blank rectangle.
                    if let stageCopy = CallStageDeriver.copy(phase: stagePhase, camera: cameraStatus) {
                        CallStagePlaceholder(recipientName: consult.recipientName,
                                             recipientOrg: consult.recipientOrg,
                                             selfInitials: selfInitials,
                                             copy: stageCopy) {
                            loadPhase = .connecting
                            reloadToken += 1
                        }
                        .transition(.opacity)
                    }

                    VStack(spacing: 8) {
                        if consult.recordingRequested || recordingConsent {
                            recordingBanner
                        }
                        if let error {
                            Text(error)
                                .font(.lato(12))
                                .foregroundStyle(warmInk.opacity(0.85))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x0B1B26).opacity(0.7)))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── consent note + controls, pinned on the stage floor ──
                VStack(spacing: 12) {
                    Text("\(consult.recipientName) can see only the summary you've consented to share — not your raw data, which stays on your device.")
                        .font(.lato(11)).lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(warmInk.opacity(0.5))
                        .padding(.horizontal, 20)

                    // Mic/camera/hang-up live in the Jitsi toolbar inside the
                    // webview; this native control leaves the consult screen.
                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(Color(hex: 0xC13B34)).frame(width: 54, height: 54)
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Leave consultation")
                }
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(stage)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stagePhase)
        .task {
            cameraStatus = Self.localCameraStatus()
            _ = try? await appState.careConnect?.joinConsult(id: consult.id)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .maudeDetail()
    }

    // MARK: - Local camera facts (never prompts)

    /// Whether this device can contribute a picture at all. Both calls are
    /// read-only: `default(for:)` reports hardware, `authorizationStatus` reports
    /// an answer already given — neither raises the OS permission dialog (that
    /// stays with the webview's own getUserMedia, as before).
    private static func localCameraStatus() -> CallCameraStatus {
        guard AVCaptureDevice.default(for: .video) != nil else { return .noDevice }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: return .notPermitted
        default: return .ready
        }
    }

    // MARK: - Recording consent (citizen-owned, floating over the stage)

    private var recordingBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: recordingConsent ? "record.circle.fill" : "record.circle")
                .font(.system(size: 14))
                .foregroundStyle(brass)
            Text(recordingConsent
                 ? "Recording on — you allowed it. You can stop any time; it's logged either way."
                 : "\(consult.recipientName) asked to record this call. Only you can allow it — and you can stop any time.")
                .font(.lato(11)).lineSpacing(2)
                .foregroundStyle(warmInk.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if working {
                ProgressView().tint(brass)
            } else {
                Button { Task { await toggleRecording() } } label: {
                    Text(recordingConsent ? "Stop" : "Allow")
                        .font(.lato(12, .bold))
                        .foregroundStyle(brass)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x0B1B26).opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(brass.opacity(0.4), lineWidth: 1))
    }

    private func toggleRecording() async {
        guard let care = appState.careConnect else { return }
        working = true; error = nil
        do {
            recordingConsent = try await care.setRecordingConsent(consultId: consult.id,
                                                                  consent: !recordingConsent)
        } catch {
            self.error = (error as? SupabaseError)?.errorDescription ?? "Couldn't update recording consent."
        }
        working = false
    }
}

// MARK: - Jitsi room (EU-sovereign; provider-agnostic)

private struct ConsultWebView: UIViewRepresentable {
    let url: URL
    /// Changing this re-issues the room request ("Try again").
    var reloadToken: Int = 0
    /// Reports the room's REAL load state so the stage can stop guessing.
    var onPhase: (CallStagePhase) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onPhase: onPhase) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(rgb: 0x0A0E12)
        web.scrollView.isScrollEnabled = false
        web.uiDelegate = context.coordinator          // grants getUserMedia (camera/mic)
        web.navigationDelegate = context.coordinator  // loaded / failed → stage state
        context.coordinator.token = reloadToken
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPhase = onPhase
        guard context.coordinator.token != reloadToken else { return }
        context.coordinator.token = reloadToken
        uiView.load(URLRequest(url: url))
    }

    // WKWebView denies camera/mic by default; the citizen already opted into this
    // consult and owns the call, so grant capture here. The OS still shows the
    // one-time system camera/mic permission prompt (Info.plist usage strings).
    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var onPhase: (CallStagePhase) -> Void
        var token = 0

        init(onPhase: @escaping (CallStagePhase) -> Void) { self.onPhase = onPhase }

        /// Never mutate SwiftUI state inside a view update.
        private func report(_ phase: CallStagePhase) {
            DispatchQueue.main.async { [weak self] in self?.onPhase(phase) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            report(.live)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            reportFailure(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            reportFailure(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            report(.unreachable)
        }

        /// A cancelled load is a redirect/replacement, not a failure to reach the room.
        private func reportFailure(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            report(.unreachable)
        }

        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
    }
}
