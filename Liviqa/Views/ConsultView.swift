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

    private var roomURL: URL? {
        guard let domain = Config.jitsiDomain, !domain.isEmpty else { return nil }
        return URL(string: "https://\(domain)/\(consult.roomName)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LiviqaAppBar(title: "Consultation", showMark: false)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    videoStage
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
            RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.ink)
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(LiviqaTheme.ink2).frame(width: 76, height: 76)
                    Text(String(consult.recipientName.prefix(2)).uppercased())
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
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

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.scrollView.isScrollEnabled = false
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
