import Testing
import Foundation
@testable import Maude

// Terminology governance (localization/TERMS.json) — T-TERM-01..03.
// The glossary is canonical and machine-checked: a broken file or banned
// advice-voice in citizen-facing copy fails the build.
struct TerminologyTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)             // …/MaudeTests/TerminologyTests.swift
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func terms() throws -> [String: Any] {
        let url = repoRoot.appendingPathComponent("localization/TERMS.json")
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // T-TERM-01 — the glossary parses and has the required shape.
    @Test func glossaryParses() throws {
        let t = try terms()
        let locked = t["locked"] as? [[String: Any]]
        #expect(locked != nil && locked!.count >= 8)
        #expect((t["neverTranslate"] as? [String])?.contains("Maude") == true)
        for entry in locked ?? [] {
            #expect(entry["en"] is String)
            let translations = entry["translations"] as? [String: [String: String]]
            #expect(translations?["da"]?["term"] != nil)
            for (_, tr) in translations ?? [:] {
                #expect(["proposed", "approved"].contains(tr["status"] ?? ""))
            }
        }
    }

    // T-TERM-02 — no advice-voice in citizen-facing copy (Views + Intelligence).
    // Patterns come from the glossary itself, so Claus can tune them there.
    @Test func noAdviceVoiceInCitizenCopy() throws {
        let t = try terms()
        let patterns = ((t["forbiddenVoice"] as? [String: Any])?["patterns"] as? [String]) ?? []
        #expect(!patterns.isEmpty)
        let dirs = ["Maude/Views", "Maude/Intelligence"]
        let fm = FileManager.default
        var violations: [String] = []
        for dir in dirs {
            let base = repoRoot.appendingPathComponent(dir)
            guard let files = fm.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    // Only check string literals; code/comments mention these
                    // phrases legitimately (e.g. the chat guard's own regex).
                    guard line.contains("\""), !line.contains("terms-guard-allow"),
                          !line.trimmingCharacters(in: .whitespaces).hasPrefix("//"),
                          !line.contains("#\"") else { continue }
                    for pat in patterns {
                        if (try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]))?
                            .firstMatch(in: String(line), range: NSRange(line.startIndex..., in: line)) != nil {
                            violations.append("\(url.lastPathComponent):\(n + 1) [\(pat)]")
                        }
                    }
                }
            }
        }
        #expect(violations.isEmpty, "advice-voice in citizen copy: \(violations.joined(separator: ", "))")
    }

    // T-TERM-03 — the String Catalog exists and declares English source.
    @Test func stringCatalogPresent() throws {
        let url = repoRoot.appendingPathComponent("Maude/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(obj?["sourceLanguage"] as? String == "en")
    }
}
