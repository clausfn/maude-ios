// SourceLint.swift — shared source-reading helpers for the QMS source-lint suites.
//
// Some guarantees are structural rather than behavioural: "this call site does
// not exist", "the terminal write in this function is the local store", "the
// lock policy is always .deviceOwnerAuthentication". They cannot be observed by
// running the app (the regression is the ADDITION of a call, and unit tests
// can't evaluate LocalAuthentication or drive a WKWebView). The established
// pattern here — ReleasePostureTests, scripts/guard_provenance.sh — is to read
// the SOURCE and fail the test run on regression. These helpers are that
// pattern, factored out so several suites share one implementation.
import Foundation

enum SourceLint {

    /// Repo root, derived from this file's location (LiviqaTests/SourceLint.swift).
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // LiviqaTests/
        .deletingLastPathComponent()   // repo root

    static func text(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Every `*.swift` under `relativeDir`, recursively, as (repo-relative path, source).
    static func swiftFiles(in relativeDir: String) -> [(path: String, source: String)] {
        let base = root.appendingPathComponent(relativeDir)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
        else { return [] }
        var out: [(path: String, source: String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let src = try? String(contentsOf: url, encoding: .utf8) else { continue }
            out.append((url.path.replacingOccurrences(of: root.path + "/", with: ""), src))
        }
        return out.sorted { $0.path < $1.path }
    }

    /// True when the trimmed line is a comment. Comments carry the *history* of
    /// removed behaviour ("the automatic upload was removed"), so every lint that
    /// hunts for CODE must skip them or it will match its own documentation.
    static func isComment(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("//") || t.hasPrefix("*") || t.hasPrefix("/*")
    }

    /// Non-comment lines with their 1-based line numbers.
    static func codeLines(_ source: String) -> [(n: Int, line: String)] {
        source.components(separatedBy: "\n").enumerated()
            .map { (n: $0.offset + 1, line: $0.element) }
            .filter { !isComment($0.line) }
    }

    /// Code lines (comments skipped) matching `pattern` as a regular expression.
    static func matches(_ pattern: String, in source: String) -> [(n: Int, line: String)] {
        codeLines(source).filter { $0.line.range(of: pattern, options: .regularExpression) != nil }
    }

    /// The brace-balanced `{ … }` body of the first declaration whose line
    /// contains `signature` — so nested closures are included and the following
    /// declaration is not. Returns nil when the signature is absent, which the
    /// caller must treat as a FAILURE (a lint that no longer finds its target
    /// silently stops guarding anything).
    static func body(ofDeclarationContaining signature: String, in source: String) -> String? {
        let lines = source.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { !isComment($0) && $0.contains(signature) })
        else { return nil }
        var depth = 0
        var opened = false
        var out: [String] = []
        for line in lines[start...] {
            for ch in line {
                if ch == "{" { depth += 1; opened = true } else if ch == "}" { depth -= 1 }
            }
            out.append(line)
            if opened && depth <= 0 { return out.joined(separator: "\n") }
        }
        return nil
    }

    /// The chain of enclosing block-opener lines above `lineIndex` (0-based),
    /// innermost first. Walks backwards tracking brace balance, so
    /// `openersAbove` for a call inside `Button { Task { … } }` yields
    /// ["Task {", "Button {", …]. Used to prove WHAT invokes a call site.
    static func openersAbove(lineIndex: Int, in source: String) -> [String] {
        let lines = source.components(separatedBy: "\n")
        var balance = 0
        var openers: [String] = []
        var i = lineIndex - 1
        while i >= 0 {
            let line = lines[i]
            if !isComment(line) {
                // Scan right-to-left: a `}` deepens the skipped region, a `{`
                // closes it — and when it closes past zero, this line opened the
                // block that contains our call.
                for ch in line.reversed() {
                    if ch == "}" { balance += 1 } else if ch == "{" {
                        if balance == 0 {
                            openers.append(line.trimmingCharacters(in: .whitespaces))
                        } else {
                            balance -= 1
                        }
                    }
                }
            }
            i -= 1
        }
        return openers
    }
}
