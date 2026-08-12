// ConsultView.swift — citizen side of a secure video consultation. Joins the
// same deterministic EU-sovereign room as the console (`liviqa-consult-<id>`)
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
import SwiftUI
import WebKit

struct ConsultView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let consult: ConsultSummary

    @State private var recordingConsent: Bool
    @State private var working = false
    @State private var error: String?

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

    private var roomURL: URL? {
        guard Config.videoConsultEnabled,
              let domain = Config.jitsiDomain, !domain.isEmpty else { return nil }
        // Config overrides via URL hash keep the call inside the webview:
        //  · disableDeepLinking — never bounce out to the native Jitsi app
        //  · prejoinPageEnabled=false — join straight in (no extra tap)
        //  · startWithVideoMuted=false — camera on, this is a consult
        // Strip everything a citizen doesn't need: no chat/polls/invite/moderator,
        // no raw room-id title — just "Liviqa video call" + mic, camera, hang up.
        let frag = "#config.disableDeepLinking=true" +
                   "&config.prejoinPageEnabled=false" +
                   "&config.startWithVideoMuted=false" +
                   "&config.subject=%22Liviqa%20video%20call%22" +
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
                        ConsultWebView(url: url)
                            .ignoresSafeArea(edges: .top)
                    } else {
                        secureShell
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
        .task {
            _ = try? await appState.careConnect?.joinConsult(id: consult.id)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .liviqaDetail()
    }

    // MARK: - Connecting shell (no EU room configured yet — honest, secure)

    private var secureShell: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x1A2733), stage],
                           center: .init(x: 0.5, y: 0.3), startRadius: 40, endRadius: 420)
                .ignoresSafeArea(edges: .top)
            // Who you're talking to — name · organisation (FB 10.39), before media.
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(brass.opacity(0.2)).frame(width: 74, height: 74)
                    Circle().stroke(brass.opacity(0.5), lineWidth: 1.5).frame(width: 74, height: 74)
                    Text(String(consult.recipientName.prefix(2)).uppercased())
                        .font(.liviqaSerif(26))
                        .foregroundStyle(brass)
                }
                Text(consult.recipientName)
                    .font(.liviqaSerif(18))
                    .foregroundStyle(warmInk)
                    .padding(.top, 12)
                if let org = consult.recipientOrg {
                    Text(org)
                        .font(.lato(12))
                        .foregroundStyle(warmInk.opacity(0.5))
                        .padding(.top, 3)
                }
                Text("Connecting · secure EU room")
                    .font(.lato(12))
                    .foregroundStyle(warmInk.opacity(0.5))
                    .padding(.top, 3)
                Text("Live video activates when your clinic's EU video room is configured.")
                    .font(.lato(11)).multilineTextAlignment(.center)
                    .foregroundStyle(warmInk.opacity(0.35))
                    .padding(.top, 14).padding(.horizontal, 40)
            }
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(rgb: 0x0A0E12)
        web.scrollView.isScrollEnabled = false
        web.uiDelegate = context.coordinator        // grants getUserMedia (camera/mic)
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // WKWebView denies camera/mic by default; the citizen already opted into this
    // consult and owns the call, so grant capture here. The OS still shows the
    // one-time system camera/mic permission prompt (Info.plist usage strings).
    final class Coordinator: NSObject, WKUIDelegate {
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
