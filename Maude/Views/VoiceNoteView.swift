// VoiceNoteView.swift — the focused full-screen voice recorder · v02 2026-08-12
// (A7.2 Area ⑧, FR-JRN-04). Anatomy from b-extra.jsx VoiceNote: header
// (back='Journal' / 'Voice note') → centered 15-bar waveform → serif
// "Recording on this phone…" + tabular timer → LIVE transcript card →
// Cancel / 66pt stop circle / Save → lock footer. Replaces the v01 bottom
// sheet (mock waveform, hardcoded transcript, context-metric strip — the strip
// is DROPPED per the census: the designed screen doesn't carry it).
//
// REAL capture now (VoiceNoteCapture): AVAudioEngine → protected audio file,
// SFSpeechRecognizer with requiresOnDeviceRecognition = true. HONESTY GATE:
// the footer claim "Transcribed on this iPhone — the audio never leaves it."
// renders ONLY while on-device transcription is actually running; otherwise
// the note degrades to audio-only with plain-words fallback copy — never a
// fake transcript.
import SwiftUI

struct VoiceNoteView: View {
    /// (transcript — empty when transcription was unavailable, audio filename in
    /// VoiceNoteAudioStore — nil if the file couldn't be created).
    var onSave: (String, String?) -> Void
    var onDismiss: () -> Void

    @State private var capture = VoiceNoteCapture()
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header (back='Journal' · title 'Voice note') ──
            ZStack {
                Text("Voice note")
                    .font(.lato(15, .bold))
                    .foregroundStyle(MaudeTheme.ink)
                HStack {
                    Button {
                        capture.cancelAndDiscard()
                        onDismiss()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.lato(14, .semibold))
                            Text("Journal")
                                .font(.lato(15))
                        }
                        .foregroundStyle(MaudeTheme.moss)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()

            // ── Centre block ──
            VStack(spacing: 0) {
                waveform
                    .padding(.bottom, 26)

                Text(headline)
                    .font(.maudeSerif(19))
                    .foregroundStyle(MaudeTheme.ink)

                Text(formatTime(capture.elapsed))
                    .font(.maudeMono(13))
                    .monospacedDigit()
                    .foregroundStyle(MaudeTheme.ink3)
                    .padding(.top, 4)

                // Live transcript (only ever real, on-device text)
                if capture.onDeviceTranscription && !capture.transcript.isEmpty {
                    Text("\u{201C}\(capture.transcript)\u{201D}")
                        .font(.lato(14)).lineSpacing(3)
                        .foregroundStyle(MaudeTheme.ink2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(MaudeTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
                        .padding(.top, 22)
                        .transition(.opacity)
                }

                if capture.phase == .denied {
                    Text("Maude needs microphone access for voice notes. You can allow it in iOS Settings → Maude.")
                        .font(.lato(12.5)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink3)
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                }
                if capture.phase == .failed {
                    Text("The microphone couldn't start. Close other audio apps and try again.")
                        .font(.lato(12.5)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink3)
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                }
            }
            .padding(.horizontal, 26)
            .animation(.easeInOut(duration: 0.2), value: capture.transcript)

            Spacer()

            // ── Control row: Cancel · stop circle · Save ──
            HStack(spacing: 30) {
                Button {
                    capture.cancelAndDiscard()
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.lato(13.5, .semibold))
                        .foregroundStyle(MaudeTheme.ink3)
                        .frame(minWidth: 56)
                }
                .buttonStyle(.plain)

                mainButton

                Button { save() } label: {
                    if isSaving {
                        ProgressView().controlSize(.small).frame(minWidth: 56)
                    } else {
                        Text("Save")
                            .font(.lato(13.5, .semibold))
                            .foregroundStyle(canSave ? MaudeTheme.moss : MaudeTheme.ink4)
                            .frame(minWidth: 56)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)
            }

            // ── Honest lock footer (FR-JRN-04 claim gate) ──
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(MaudeTheme.ink4)
                Text(footerClaim)
                    .font(.lato(11))
                    .foregroundStyle(MaudeTheme.ink4)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            .padding(.horizontal, 26)
            .padding(.bottom, 24)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
        .task { await capture.start() }
        .onDisappear {
            if capture.phase == .recording { capture.cancelAndDiscard() }
        }
    }

    // MARK: — Pieces

    /// The designed 15-bar waveform — driven by REAL mic levels while recording.
    private var waveform: some View {
        HStack(spacing: 4) {
            ForEach(Array(capture.levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(MaudeTheme.accentSleep.opacity(capture.phase == .recording ? 1 : 0.35))
                    .frame(width: 4, height: max(6, level * 56))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
        .frame(height: 60)
    }

    private var mainButton: some View {
        Button {
            switch capture.phase {
            case .recording: capture.finish()
            case .finished:
                // Re-record: discard and start over.
                capture.cancelAndDiscard()
                Task { await capture.start() }
            case .denied, .failed, .idle:
                Task { await capture.start() }
            case .requesting: break
            }
        } label: {
            ZStack {
                Circle()
                    .fill(MaudeTheme.accentHeart)
                    .frame(width: 66, height: 66)
                    .shadow(color: MaudeTheme.accentHeart.opacity(0.4), radius: 10, y: 5)
                switch capture.phase {
                case .recording:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                case .finished:
                    Image(systemName: "arrow.counterclockwise")
                        .font(.lato(24, .medium))
                        .foregroundStyle(.white)
                default:
                    Image(systemName: "mic.fill")
                        .font(.lato(24, .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(capture.phase == .requesting)
    }

    private var headline: String {
        switch capture.phase {
        case .recording:  return String(localized: "Recording on this phone…")
        case .finished:   return String(localized: "Recorded — ready to save.")
        case .denied:     return String(localized: "Microphone access needed.")
        case .failed:     return String(localized: "Couldn't start recording.")
        case .idle, .requesting: return String(localized: "Getting ready…")
        }
    }

    /// The claim is gated on what is actually happening (FR-JRN-04 rail):
    /// on-device transcription live → the designed footer; otherwise the honest
    /// audio-only wording. Both "never leaves" claims are structurally true —
    /// there is no upload path in the capture code.
    private var footerClaim: String {
        capture.onDeviceTranscription
            ? String(localized: "Transcribed on this iPhone — the audio never leaves it.")
            : String(localized: "Recorded on this phone — the audio never leaves it. On-device transcription isn't available on this device.")
    }

    private var canSave: Bool {
        capture.phase == .finished ||
        (capture.phase == .recording && capture.elapsed >= 1)
    }

    // MARK: — Actions

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        if capture.phase == .recording { capture.finish() }
        // Give the recognizer a beat to deliver the final on-device result.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onSave(capture.transcript, capture.audioFilename)
        }
    }

    // MARK: — Formatting

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Preview

#Preview {
    VoiceNoteView(
        onSave: { _, _ in },
        onDismiss: {}
    )
}
