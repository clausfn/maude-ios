import Testing
import Foundation
@testable import Liviqa

// FR-JRNL-SEED-01 — the demo journal seed must not be able to reach a Release
// build by ANY path.
//
// The `#if DEBUG` gate around `JournalView.demoSeed` is correct, but it was
// added AFTER a June build had already written the three seed entries into the
// device journal, where they read as the citizen's own words. A gate that is
// only checked by review is a gate that can be moved. These are source-level
// lints (unit tests always compile in Debug, so a Release-only value cannot be
// observed at runtime) plus the two behavioural invariants that make the gate
// unnecessary: the seed cannot be PERSISTED, and it cannot be READ back.
//
// Same pattern and the same conditional-compilation walker idea as
// `ReleasePostureTests`; kept self-contained so the two suites can be edited
// independently.
@MainActor
struct JournalSeedPostureTests {

    // MARK: - Source access

    private func source(_ relative: String) throws -> String { try SourceLint.text(relative) }

    /// Per-line flag: this line is compiled ONLY in DEBUG builds.
    private func debugOnlyLineFlags(_ src: String) -> [Bool] {
        enum Branch { case debugOnly, releaseOnly, other }
        var stack: [Branch] = []
        var flags: [Bool] = []
        for raw in src.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#if") {
                let cond = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                if cond == "DEBUG" { stack.append(.debugOnly) }
                else if cond == "!DEBUG" { stack.append(.releaseOnly) }
                else { stack.append(.other) }
            } else if line.hasPrefix("#elseif") {
                if !stack.isEmpty { stack[stack.count - 1] = .other }
            } else if line.hasPrefix("#else") {
                if let top = stack.last {
                    stack[stack.count - 1] = top == .debugOnly ? .releaseOnly
                                           : top == .releaseOnly ? .debugOnly : .other
                }
            } else if line.hasPrefix("#endif") {
                _ = stack.popLast()
            }
            flags.append(stack.contains(.debugOnly))
        }
        return flags
    }

    /// The `body: "…"` literals inside a source block.
    private func bodyLiterals(in block: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"body:\s*"([^"]*)""#) else { return [] }
        let ns = block as NSString
        return re.matches(in: block, range: NSRange(location: 0, length: ns.length))
            .compactMap { $0.numberOfRanges > 1 ? ns.substring(with: $0.range(at: 1)) : nil }
    }

    // MARK: - The seed exists in exactly one place, and only in DEBUG

    @Test func theSeedIsOnlyEverCONSTRUCTEDInsideIfDEBUG() throws {
        // The purge denylist is the ONE non-DEBUG place these strings may appear:
        // it removes entries, it never builds them (proved below).
        let denylistFile = "Liviqa/Security/JournalStore.swift"
        var seenInDebug = false
        for file in SourceLint.swiftFiles(in: "Liviqa") {
            let flags = debugOnlyLineFlags(file.source)
            for (i, line) in file.source.components(separatedBy: "\n").enumerated() {
                guard JournalStore.legacyDemoSeedBodies.contains(where: { line.contains($0) })
                else { continue }
                if file.path == denylistFile { continue }
                #expect(flags[i],
                        "\(file.path):\(i + 1) — a demo journal seed body is compiled into RELEASE")
                if flags[i] { seenInDebug = true }
            }
        }
        #expect(seenInDebug, "no DEBUG seed found at all — this lint has gone stale")
    }

    @Test func theDenylistIsTheSeedVerbatim() throws {
        let src = try source("Liviqa/Views/JournalView.swift")
        let block = try #require(SourceLint.body(ofDeclarationContaining: "let demoSeed",
                                                 in: src),
                                 "JournalView.demoSeed not found — this lint has gone stale")
        let seedBodies = bodyLiterals(in: block)
        #expect(seedBodies.count == 3)
        // Every seed body must be purgeable, and the denylist must not have drifted.
        for body in seedBodies {
            #expect(JournalStore.legacyDemoSeedBodies.contains(body),
                    "JournalView.demoSeed carries a body the purge denylist doesn't know: \(body.prefix(40))…")
        }
        #expect(Set(JournalStore.legacyDemoSeedBodies) == Set(seedBodies),
                "JournalStore.legacyDemoSeedBodies and JournalView.demoSeed have diverged")
    }

    @Test func everyDemoSeedReferenceIsDebugGated() throws {
        let src = try source("Liviqa/Views/JournalView.swift")
        let flags = debugOnlyLineFlags(src)
        var found = false
        for (i, line) in src.components(separatedBy: "\n").enumerated() {
            guard !SourceLint.isComment(line), line.contains("demoSeed") else { continue }
            found = true
            #expect(flags[i], "Liviqa/Views/JournalView.swift:\(i + 1) — demoSeed must sit inside #if DEBUG")
        }
        #expect(found, "demoSeed reference not found — this lint has gone stale")
    }

    @Test func theJournalStateStartsEmptyNotSeeded() throws {
        let src = try source("Liviqa/Views/JournalView.swift")
        // The @State declaration itself must not reach for a seed (or for the
        // store: the account isn't known yet at initialisation).
        let decl = try #require(SourceLint.matches(#"@State private var journalEntries"#, in: src).first,
                                "journalEntries state not found — this lint has gone stale")
        #expect(decl.line.contains("= []"),
                "JournalView.journalEntries must start EMPTY, not from a seed or an unscoped store")
    }

    // MARK: - The denylist can never become a seeder

    @Test func theStoreNeverConstructsAJournalEntry() throws {
        let src = try source("Liviqa/Security/JournalStore.swift")
        let constructions = SourceLint.matches(#"JournalEntry\("#, in: src)
        #expect(constructions.isEmpty,
                "JournalStore must only ever REMOVE seed bodies, never build entries from them")
    }

    // MARK: - Behavioural half: the seed cannot be persisted or read back

    @Test func savingFiltersTheSeedInEveryConfiguration() throws {
        let src = try source("Liviqa/Security/JournalStore.swift")
        let body = try #require(SourceLint.body(ofDeclarationContaining: "static func save(_ entries: [JournalEntry], to url:",
                                                in: src),
                                "JournalStore.save(_:to:) not found — this lint has gone stale")
        #expect(body.contains("purgingLegacyDemoSeeds"),
                "the write path must strip the app's own demo bodies — that is how they became 'the citizen's words'")
        // …and prove it, rather than trusting the source read.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("seed-posture-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let seeds = JournalStore.legacyDemoSeedBodies.map { JournalEntry(body: $0) }
        JournalStore.save(seeds, to: tmp)
        #expect(JournalStore.load(from: tmp)?.isEmpty == true)
        let onDisk = try #require(try? Data(contentsOf: tmp))
        for seed in JournalStore.legacyDemoSeedBodies {
            #expect(!String(decoding: onDisk, as: UTF8.self).contains(seed),
                    "a demo seed body reached the file")
        }
    }

    // MARK: - No unscoped journal path survives

    @Test func noDeviceScopedJournalPathRemains() {
        for file in SourceLint.swiftFiles(in: "Liviqa") {
            for hit in SourceLint.matches(#"JournalStore\.defaultURL"#, in: file.source) {
                Issue.record("\(file.path):\(hit.n) — the device-scoped journal path is back")
            }
            // Every read/write must name an account (or an explicit URL in tests).
            for hit in SourceLint.matches(#"JournalStore\.(load|save)\(\)"#, in: file.source) {
                Issue.record("\(file.path):\(hit.n) — unscoped journal access")
            }
        }
    }
}
