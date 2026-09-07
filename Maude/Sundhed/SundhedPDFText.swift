// SundhedPDFText.swift — Transient text extraction for Sundhed.dk exports.
//
// PATH B: the picked file's BYTES (fixes the old filename-only import gap) are
// turned into flat text here, entirely on-device, then handed to SundhedParsers.
//
// CARDINAL (rule 3): raw bytes/text are processed TRANSIENTLY and discarded.
// Nothing in this file persists, uploads, or logs the document contents — the
// returned String is the caller's short-lived local value.
//
// PDFKit for .pdf; UTF-8/Latin-1 passthrough for .txt. No external deps.
import Foundation
import PDFKit

public enum SundhedPDFText {

    public enum ExtractError: Error, LocalizedError {
        case unreadablePDF
        case undecodableText
        case empty

        public var errorDescription: String? {
            switch self {
            case .unreadablePDF:   return String(localized: "That PDF couldn't be read on this device.")
            case .undecodableText: return String(localized: "That file's text couldn't be read.")
            case .empty:           return String(localized: "No readable text was found in that file.")
            }
        }
    }

    /// Extract flat text from in-memory bytes. `filename` (or the %PDF magic)
    /// decides PDF vs. plain-text. The returned string is transient — the caller
    /// parses it and lets it fall out of scope.
    public static func text(fromData data: Data, filename: String) throws -> String {
        let lower = filename.lowercased()
        let looksPDF = lower.hasSuffix(".pdf") || data.starts(with: Array("%PDF".utf8))

        let text: String
        if looksPDF {
            guard let doc = PDFDocument(data: data) else { throw ExtractError.unreadablePDF }
            text = concatenatedPages(of: doc)
        } else {
            guard let decoded = decodeText(data) else { throw ExtractError.undecodableText }
            text = decoded
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ExtractError.empty }
        return text
    }

    /// Convenience for a security-scoped file URL (reads bytes, then delegates).
    /// The caller is responsible for `startAccessingSecurityScopedResource()`.
    public static func text(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try text(fromData: data, filename: url.lastPathComponent)
    }

    /// Concatenate every page's string with newlines so line-oriented parsing
    /// sees section headers, analyte declarations and value rows in order.
    private static func concatenatedPages(of doc: PDFDocument) -> String {
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let s = doc.page(at: i)?.string { pages.append(s) }
        }
        return pages.joined(separator: "\n")
    }

    /// UTF-8 first (the modern default), then Latin-1 (older DK exports), then a
    /// lossy UTF-8 fallback so a stray byte doesn't sink an otherwise-good file.
    private static func decodeText(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return String(decoding: data, as: UTF8.self)
    }
}
