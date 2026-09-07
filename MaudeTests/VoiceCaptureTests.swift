import Testing
import Foundation
import Speech
@testable import Maude

// FR-JRN-04 — voice-note journaling (T-JRN-04). The DESIGNATED claim gate:
// "Transcribed on this iPhone — the audio never leaves it." may only ship while
// recognition is provably on-device. The whole guarantee hangs on the single
// request factory, so the assertion is structural:
struct VoiceCaptureTests {

    // MARK: 1 · On-device recognition is hard-required (designated — never skip)

    @Test func recognitionRequestRequiresOnDeviceRecognition() {
        let request = VoiceNoteCapture.makeRequest()
        #expect(request.requiresOnDeviceRecognition,
                "FR-JRN-04 rail: the recognition request MUST set requiresOnDeviceRecognition — the footer claim depends on it")
    }

    // MARK: 2 · Audio stays in the journal's protected store location

    @Test func audioStoreLivesInApplicationSupport() throws {
        let dir = try #require(VoiceNoteAudioStore.directoryURL())
        #expect(dir.lastPathComponent == "journal-audio")
        #expect(dir.path.contains("Application Support"))

        let fileURL = try #require(VoiceNoteAudioStore.url(for: "test.caf"))
        #expect(fileURL.deletingLastPathComponent() == dir)
    }

    // MARK: 3 · The transcript+audio pointer round-trips through the journal store

    @Test func journalEntryCarriesAudioFilenameThroughPersistence() throws {
        var entry = JournalEntry(body: "Slept well, woke once around two.", tags: ["Voice"])
        entry.audioFilename = "abc123.caf"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-voice-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        JournalStore.save([entry], to: url)
        let loaded = try #require(JournalStore.load(from: url))
        #expect(loaded.count == 1)
        #expect(loaded[0].audioFilename == "abc123.caf")
        #expect(loaded[0].tags == ["Voice"])
    }

    /// Old journal files (no audio_filename key) must keep decoding — the field
    /// is optional by construction.
    @Test func legacyEntriesWithoutAudioStillDecode() throws {
        let entry = JournalEntry(body: "Plain text note", tags: [])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-legacy-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        JournalStore.save([entry], to: url)
        let loaded = try #require(JournalStore.load(from: url))
        #expect(loaded[0].audioFilename == nil)
    }
}
