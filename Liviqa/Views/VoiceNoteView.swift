// VoiceNoteView.swift — In-journal voice recording UI · v01 2026-05-22
// Demo mode: no AVAudioRecorder wired — waveform animates with mock data.
// Audio permission request is guarded behind #if os(iOS) throughout.
import SwiftUI

// MARK: - Recording state

private enum RecordingState: Equatable {
    case idle
    case recording(elapsed: TimeInterval)
    case reviewing(elapsed: TimeInterval)
    case saved
}

// MARK: - VoiceNoteView

struct VoiceNoteView: View {
    var onSave: (String) -> Void     // returns transcription placeholder
    var onDismiss: () -> Void

    @State private var state: RecordingState  = .idle
    @State private var elapsed: TimeInterval  = 0
    @State private var timer: Timer?          = nil
    @State private var bars: [CGFloat]        = Array(repeating: 0.15, count: 28)
    @State private var barTimer: Timer?       = nil
    @State private var transcription: String  =
        "Note recorded on device. Transcription available in a future update."

    // Contextual metrics shown below the waveform
    private let contextItems: [(String, String, String)] = [
        ("waveform.path.ecg", "HRV", "44 ms"),
        ("moon.fill",         "Sleep", "7h 12"),
        ("drop.fill",         "Glucose", "5.8 mmol/L"),
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── Handle bar ──
            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.line)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 20)

            // ── Header ──
            HStack {
                Text("Voice note")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
                Button {
                    stopAll()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(8)
                        .background(LiviqaTheme.line2)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 32)

            // ── Context metrics ──
            HStack(spacing: 0) {
                ForEach(contextItems, id: \.0) { item in
                    VStack(spacing: 3) {
                        Image(systemName: item.0)
                            .font(.system(size: 11))
                            .foregroundStyle(LiviqaTheme.ink4)
                        Text(item.2)
                            .font(.liviqaMono(13))
                            .monospacedDigit()
                            .foregroundStyle(LiviqaTheme.ink2)
                        Text(item.1)
                            .font(.liviqaKicker(8))
                            .tracking(0.5)
                            .foregroundStyle(LiviqaTheme.ink4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            .padding(.horizontal, 24)

            Spacer().frame(height: 36)

            // ── Waveform ──
            waveformView

            Spacer().frame(height: 16)

            // ── Elapsed or status ──
            elapsedLabel

            Spacer().frame(height: 32)

            // ── Controls ──
            controlRow

            Spacer().frame(height: 28)

            // ── Transcription preview (reviewing only) ──
            if case .reviewing = state {
                transcriptionPreview
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if case .saved = state {
                savedConfirmation
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.22), value: state)
        .onDisappear { stopAll() }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { idx, h in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(idx))
                    .frame(width: 5, height: max(4, h * 80))
                    .animation(.easeInOut(duration: 0.1), value: h)
            }
        }
        .frame(height: 80)
    }

    private func barColor(_ idx: Int) -> Color {
        switch state {
        case .idle:                  return LiviqaTheme.line
        case .recording:             return idx % 2 == 0 ? LiviqaTheme.moss : LiviqaTheme.moss3
        case .reviewing, .saved:     return LiviqaTheme.ink3
        }
    }

    // MARK: - Elapsed label

    private var elapsedLabel: some View {
        Group {
            switch state {
            case .idle:
                Text("Tap to record")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
            case .recording(let t), .reviewing(let t):
                Text(formatTime(t))
                    .font(.liviqaMono(16))
                    .monospacedDigit()
                    .foregroundStyle(state == .reviewing(elapsed: t) ? LiviqaTheme.ink3 : LiviqaTheme.moss)
            case .saved:
                Text("Saved to journal")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.moss)
            }
        }
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 36) {
            // Discard / restart
            Button {
                discardOrRestart()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: discardIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(width: 48, height: 48)
                        .background(LiviqaTheme.line2)
                        .clipShape(Circle())
                    Text(discardLabel)
                        .font(.liviqaKicker(8))
                        .tracking(0.4)
                        .foregroundStyle(LiviqaTheme.ink4)
                }
            }
            .opacity(state == .idle || state == .saved ? 0 : 1)

            // Main record / stop button
            Button {
                mainAction()
            } label: {
                ZStack {
                    Circle()
                        .fill(mainButtonFill)
                        .frame(width: 72, height: 72)
                        .shadow(color: mainButtonFill.opacity(0.3), radius: 12, y: 4)
                    Image(systemName: mainButtonIcon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .disabled(state == .saved)

            // Save
            Button {
                saveNote()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(LiviqaTheme.moss)
                        .clipShape(Circle())
                    Text("SAVE")
                        .font(.liviqaKicker(8))
                        .tracking(0.4)
                        .foregroundStyle(LiviqaTheme.ink4)
                }
            }
            .opacity(isReviewing ? 1 : 0)
            .disabled(!isReviewing)
        }
    }

    private var mainButtonFill: Color {
        switch state {
        case .idle, .saved: return LiviqaTheme.rust
        case .recording:    return LiviqaTheme.rust
        case .reviewing:    return LiviqaTheme.ink3
        }
    }

    private var mainButtonIcon: String {
        switch state {
        case .idle, .saved: return "mic.fill"
        case .recording:    return "stop.fill"
        case .reviewing:    return "play.fill"
        }
    }

    private var discardIcon: String {
        switch state {
        case .recording: return "arrow.counterclockwise"
        default:         return "trash"
        }
    }

    private var discardLabel: String {
        switch state {
        case .recording: return "RESTART"
        default:         return "DISCARD"
        }
    }

    private var isReviewing: Bool {
        if case .reviewing = state { return true }
        return false
    }

    // MARK: - Transcription preview

    private var transcriptionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                Text("TRANSCRIPTION")
                    .font(.liviqaKicker(9))
                    .tracking(0.8)
                    .foregroundStyle(LiviqaTheme.ink4)
                Text("preview")
                    .font(.liviqaKicker(9))
                    .tracking(0.4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LiviqaTheme.amber2)
                    .foregroundStyle(LiviqaTheme.amber)
                    .clipShape(Capsule())
            }
            Text(transcription)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    private var savedConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LiviqaTheme.moss)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text("Note saved")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text("Linked to today's metrics and stored on this device.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
        }
        .padding(14)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
    }

    // MARK: - State machine

    private func mainAction() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .reviewing:
            // play-back placeholder — no-op in demo
            break
        case .saved:
            break
        }
    }

    private func startRecording() {
        elapsed = 0
        state   = .recording(elapsed: 0)
        startElapsedTimer()
        startWaveformAnimation()
    }

    private func stopRecording() {
        timer?.invalidate();    timer    = nil
        barTimer?.invalidate(); barTimer = nil
        state = .reviewing(elapsed: elapsed)
        // Freeze bars at last animated values
    }

    private func discardOrRestart() {
        switch state {
        case .recording:
            timer?.invalidate()
            barTimer?.invalidate()
            elapsed = 0
            bars = Array(repeating: 0.15, count: 28)
            state = .idle
        case .reviewing:
            bars = Array(repeating: 0.15, count: 28)
            state = .idle
        default:
            break
        }
    }

    private func saveNote() {
        withAnimation {
            state = .saved
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            onSave(transcription)
        }
    }

    private func stopAll() {
        timer?.invalidate()
        barTimer?.invalidate()
    }

    // MARK: - Timer helpers

    private func startElapsedTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
            if case .recording = state {
                state = .recording(elapsed: elapsed)
            }
        }
    }

    private func startWaveformAnimation() {
        barTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            guard case .recording = state else { return }
            // Shift existing bars left and append a new random value
            var next = bars
            for i in 0..<(next.count - 1) { next[i] = next[i + 1] }
            next[next.count - 1] = CGFloat.random(in: 0.1...1.0)
            bars = next
        }
    }

    // MARK: - Formatting

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Preview

#Preview {
    VoiceNoteView(
        onSave: { _ in },
        onDismiss: {}
    )
    .frame(maxHeight: 600)
}
