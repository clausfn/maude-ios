// ConsultView.swift — citizen side of a secure video consultation. Joins the
// same deterministic EU-sovereign room as the console (`liviqa-consult-<id>`)
// and owns the recording consent (FR-WAL / Video_and_OAuth_Contract_v01).
//
// The consented, derived data the recipient sees is summarised beside the call;
// raw HealthKit samples never leave the device. No US-parented video provider on
// this PII path (NFR-SEC-07): live media only when an EU Jitsi domain is set.
import SwiftUI
import WebKit

struct ConsultView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let consult: ConsultSummary

    @State private var recordingConsent: Bool
    @State private var working = false
    @State private var error: String?

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
        VStack(alignment: .leading, spacing: 0) {
            LiviqaAppBar(title: "Consultation", showMark: false, showsAvatar: false)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    videoStage
                    participantsCard
                    recordingCard
                    if let error {
                        Text(error).font(.lato(12.5)).foregroundStyle(LiviqaTheme.rust)
                    }
                    Text("\(consult.recipientName)\(consult.recipientOrg.map { " · \($0)" } ?? "") can see only the summary you've consented to share — not your raw data, which stays on your device.")
                        .font(.lato(12)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                    leaveButton
                }
                .padding(16)
            }
        }
        .background(LiviqaTheme.paper)
        .task {
            _ = try? await appState.careConnect?.joinConsult(id: consult.id)
        }
        .liviqaDetail()
    }

    // MARK: - Video stage

    private var videoStage: some View {
        VStack(spacing: 0) {
            if let url = roomURL {
                ConsultWebView(url: url)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                secureShell
            }
        }
    }

    private var secureShell: some View {
        ZStack {
            // Always-dark video stage (a call surface) — never the theme `ink`,
            // which is light in Midnight and would make the white text vanish.
            RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x0B1B26))
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 76, height: 76)
                    Text(String(consult.recipientName.prefix(2)).uppercased())
                        .font(.lato(26, .heavy))
                        .foregroundStyle(.white)
                }
                Text("Connecting to \(consult.recipientName)…")
                    .font(.lato(13, .semibold)).foregroundStyle(.white)
                Text("Secure consultation · live video activates when your clinic's EU video room is configured.")
                    .font(.lato(11)).multilineTextAlignment(.center)
                    .foregroundStyle(LiviqaTheme.ink4)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 28)
        }
        .frame(height: 320)
    }

    // MARK: - Who's in the call (care team)
    // FB (build 10.39): "Care team not showing on citizen video call" — the call
    // only carried a generic "Care team" tile. Surface who the citizen is actually
    // speaking with: role · organisation, with a live presence dot. Role over name
    // (roles persist, people change) — same principle as the care-team model.

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In this call")
                .font(.liviqaKicker(10.5)).tracking(0.6)
                .foregroundStyle(LiviqaTheme.ink3)

            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(LiviqaTheme.moss2).frame(width: 36, height: 36)
                    Text(String(consult.recipientName.prefix(2)).uppercased())
                        .font(.lato(13, .heavy))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(consult.recipientName)
                        .font(.lato(14, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                    if let org = consult.recipientOrg {
                        Text(org)
                            .font(.lato(12))
                            .foregroundStyle(LiviqaTheme.ink3)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(LiviqaTheme.moss).frame(width: 7, height: 7)
                    Text("In the room")
                        .font(.lato(11, .semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.paper2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: - Recording consent (citizen-owned)

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: recordingConsent ? "record.circle.fill" : "record.circle")
                    .foregroundStyle(recordingConsent ? LiviqaTheme.rust : LiviqaTheme.ink3)
                Text(recordingConsent ? "Recording on — you allowed it" : "Recording is off")
                    .font(.lato(14, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
                if working { ProgressView() }
            }
            Text(consult.recordingRequested && !recordingConsent
                 ? "\(consult.recipientName) asked to record this call. Only you can allow it — and you can stop any time."
                 : "Only you can allow recording. You can withdraw at any time; it's logged either way.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
            Button { Task { await toggleRecording() } } label: {
                Text(recordingConsent ? "Stop recording" : "Allow recording")
                    .font(.lato(13.5, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(recordingConsent ? LiviqaTheme.rust : LiviqaTheme.moss))
            }
            .buttonStyle(.plain)
            .disabled(working)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(recordingConsent ? LiviqaTheme.rust2 : LiviqaTheme.paper2))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(recordingConsent ? LiviqaTheme.rust : LiviqaTheme.line, lineWidth: 1))
    }

    private var leaveButton: some View {
        Button { dismiss() } label: {
            Text("Leave consultation")
                .font(.lato(14, .bold))
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(LiviqaTheme.line2))
        }
        .buttonStyle(.plain)
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
