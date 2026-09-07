// VoiceNoteCapture.swift — REAL on-device voice-note capture · v01 2026-08-12
// (A7.2 Area ⑧, FR-JRN-04). Replaces the v01 demo theatre (mock waveform +
// hardcoded transcript placeholder) with:
//   • AVAudioEngine recording → audio file in the journal's protected storage
//     (Application Support/journal-audio/, NSFileProtectionComplete — the same
//     device-local, never-uploaded posture as JournalStore).
//   • SFSpeechRecognizer live transcription with requiresOnDeviceRecognition =
//     true — ALWAYS (set in `makeRequest()`, asserted by T-JRN-04). The claim
//     "Transcribed on this iPhone — the audio never leaves it." may only render
//     while `onDeviceTranscription` is true; when the device/locale can't
//     transcribe on-device, capture degrades HONESTLY to an audio-only note —
//     no server fallback exists in this file BY CONSTRUCTION.
//   • Real mic levels (tap-buffer RMS) driving the designed 15-bar waveform.
import Foundation
import AVFoundation
import Speech
import Observation

// MARK: - Protected audio storage (journal-adjacent, device-local only)

/// Voice-note audio lives beside the journal file — Application Support/
/// journal-audio/<uuid>.caf with complete file protection. There is no upload
/// path. Wiped whole by AppState.deleteAllData (GDPR erase).
enum VoiceNoteAudioStore {
    static func directoryURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return nil }
        let sub = dir.appendingPathComponent("journal-audio", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: sub, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        return sub
    }

    static func url(for filename: String) -> URL? {
        directoryURL()?.appendingPathComponent(filename)
    }

    static func delete(_ filename: String) {
        guard let url = url(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// GDPR erase: remove every recorded note.
    static func deleteAll() {
        guard let dir = directoryURL() else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}

// MARK: - Off-main audio plumbing

/// The engine/file/request bundle the mic tap thread touches. Deliberately
/// nonisolated (the tap fires off-main); state that the UI observes lives in
/// `VoiceNoteCapture` and is only updated via MainActor hops.
nonisolated final class VoiceAudioPipeline: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let audioFile: AVAudioFile?
    let request: SFSpeechAudioBufferRecognitionRequest
    private let onLevel: @Sendable (Double) -> Void

    init(fileURL: URL?,
         request: SFSpeechAudioBufferRecognitionRequest,
         onLevel: @escaping @Sendable (Double) -> Void) throws {
        self.request = request
        self.onLevel = onLevel
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        audioFile = fileURL.flatMap { try? AVAudioFile(forWriting: $0, settings: format.settings) }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request.append(buffer)
            try? self.audioFile?.write(from: buffer)
            self.onLevel(Self.rms(of: buffer))
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request.endAudio()
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Double {
        guard let ch = buffer.floatChannelData?.pointee else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        return Double(sqrt(sum / Float(n)))
    }
}

// MARK: - The capture view-model

@MainActor
@Observable
final class VoiceNoteCapture {

    enum Phase: Equatable {
        case idle           // not started
        case requesting     // permission prompts in flight
        case denied         // mic permission refused — honest dead end
        case recording
        case finished       // stopped; transcript/audio ready to save
        case failed         // engine couldn't start
    }

    private(set) var phase: Phase = .idle
    /// Live transcript (on-device only). Empty when transcription is unavailable.
    private(set) var transcript = ""
    /// Rolling mic levels (0…1), newest last — drives the designed 15-bar waveform.
    private(set) var levels: [Double] = Array(repeating: 0.08, count: 15)
    private(set) var elapsed: TimeInterval = 0
    /// TRUE only while a live SFSpeech task with requiresOnDeviceRecognition is
    /// running — the gate for the "audio never leaves it" footer (FR-JRN-04 rail).
    private(set) var onDeviceTranscription = false
    /// Filename (in VoiceNoteAudioStore) of the recording, once started.
    private(set) var audioFilename: String? = nil

    private var pipeline: VoiceAudioPipeline?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var ticker: Timer?

    /// The ONE place a recognition request is built: on-device recognition is
    /// hard-required here, so no code path can quietly fall back to a server
    /// (asserted by VoiceCaptureTests / T-JRN-04).
    nonisolated static func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        return request
    }

    // MARK: Lifecycle

    /// Request permissions and start recording (+ live transcription when the
    /// device supports it on-device). Honest degradation: mic denied → .denied;
    /// speech unavailable/denied → audio-only note, `onDeviceTranscription` false.
    func start() async {
        guard phase == .idle || phase == .denied || phase == .failed else { return }
        phase = .requesting

        guard await AVAudioApplication.requestRecordPermission() else {
            phase = .denied
            return
        }

        // On-device transcription is opportunistic, never faked.
        let recognizer = SFSpeechRecognizer()
        var canTranscribe = false
        if let recognizer, recognizer.supportsOnDeviceRecognition {
            let status = await Self.speechAuthorization()
            canTranscribe = (status == .authorized) && recognizer.isAvailable
        }

        let filename = UUID().uuidString + ".caf"
        let request = Self.makeRequest()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: [])
            pipeline = try VoiceAudioPipeline(
                fileURL: VoiceNoteAudioStore.url(for: filename),
                request: request
            ) { [weak self] level in
                Task { @MainActor [weak self] in self?.pushLevel(level) }
            }
        } catch {
            phase = .failed
            return
        }

        audioFilename = filename
        transcript = ""
        elapsed = 0
        onDeviceTranscription = canTranscribe

        if canTranscribe, let recognizer {
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
                guard let text = result?.bestTranscription.formattedString else { return }
                Task { @MainActor [weak self] in self?.transcript = text }
            }
        }

        phase = .recording
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .recording else { return }
                self.elapsed += 0.1
            }
        }
    }

    /// Stop and keep the recording (review → save).
    func finish() {
        guard phase == .recording else { return }
        teardown()
        // Belt & braces: the directory carries complete protection; stamp the
        // file too so the at-rest encryption claim holds per item.
        if let name = audioFilename, let url = VoiceNoteAudioStore.url(for: name) {
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        }
        phase = .finished
    }

    /// Stop and discard everything (Cancel).
    func cancelAndDiscard() {
        teardown()
        if let name = audioFilename { VoiceNoteAudioStore.delete(name) }
        audioFilename = nil
        transcript = ""
        elapsed = 0
        onDeviceTranscription = false
        phase = .idle
    }

    private func teardown() {
        ticker?.invalidate(); ticker = nil
        pipeline?.stop(); pipeline = nil
        recognitionTask?.finish(); recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Helpers

    private func pushLevel(_ raw: Double) {
        // Speech RMS sits around 0.01…0.3 — lift into the visible band.
        let scaled = min(1.0, max(0.08, raw * 6))
        levels.removeFirst()
        levels.append(scaled)
    }

    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
    }
}
