// LabReportOCR.swift — FR-REC-03 · getting text off a lab report, on device.
//
// The PLATFORM half of the any-lab import (the deterministic half is
// LabReportParser.swift, pure Foundation). Two ways in, one way out:
//
//   • a PDF with a real text layer → PDFKit reads it directly (exact, no OCR);
//   • a photo, a scan, or an image-only PDF page → Vision's
//     VNRecognizeTextRequest with `requiresOnDeviceRecognition = true`.
//
// CARDINAL (same rule as SundhedPDFText): the bytes and the recognised text are
// TRANSIENT. Nothing here writes to disk, logs contents, or opens a socket.
// `requiresOnDeviceRecognition` is not a preference — Vision may otherwise use
// Apple's servers for text recognition, which would break the on-device rail.
// The caller keeps the returned lines only until the citizen approves or
// cancels the import.
//
// Kept OUT of the parser so the recogniser stays Foundation-only and portable
// (NFR-PORT-01): an Android port replaces this file alone.
import Foundation
import PDFKit
#if canImport(Vision)
import Vision
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum LabReportOCR {

    /// What one read produced, with the honest provenance of the READ ITSELF
    /// (text layer vs. camera OCR) so the review screen can say which it was.
    /// This is about how the text was obtained — it is NOT the DataModel
    /// provenance field, which never renders.
    public struct Read: Sendable {
        public let lines: [LabReportLine]
        public let usedOCR: Bool
        public let pageCount: Int
    }

    public enum ReadError: Error, LocalizedError {
        case unreadableFile
        case noTextFound
        case recognitionUnavailable

        public var errorDescription: String? {
            switch self {
            case .unreadableFile:
                return String(localized: "That file couldn't be opened on this device.")
            case .noTextFound:
                return String(localized: "No readable text was found in that file. A sharper photo of the page usually fixes it.")
            case .recognitionUnavailable:
                return String(localized: "On-device text recognition isn't available on this device, so the file wasn't read.")
            }
        }
    }

    /// Read a picked file. PDFs use their text layer when they have one and
    /// fall back to OCR per page; anything else is treated as an image.
    /// Synchronous and CPU-bound — call it off the main actor.
    public static func read(data: Data, filename: String) throws -> Read {
        let looksPDF = filename.lowercased().hasSuffix(".pdf") || data.starts(with: Array("%PDF".utf8))
        if looksPDF {
            guard let doc = PDFDocument(data: data) else { throw ReadError.unreadableFile }
            return try readPDF(doc)
        }
        let lines = try recognise(imageData: data)
        guard !lines.isEmpty else { throw ReadError.noTextFound }
        return Read(lines: lines, usedOCR: true, pageCount: 1)
    }

    // MARK: - PDF

    private static func readPDF(_ doc: PDFDocument) throws -> Read {
        var lines: [LabReportLine] = []
        var usedOCR = false

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            if let text = page.string, hasUsableTextLayer(text) {
                // Exact text — confidence 1.0, nothing was recognised or guessed.
                lines += text.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { LabReportLine(text: $0, confidence: 1.0) }
            } else if let image = render(page) {
                usedOCR = true
                lines += (try? recognise(cgImage: image)) ?? []
            }
        }
        guard !lines.isEmpty else { throw ReadError.noTextFound }
        return Read(lines: lines, usedOCR: usedOCR, pageCount: doc.pageCount)
    }

    /// A page has a usable text layer when it carries real words AND digits.
    /// Scanned pages typically return nothing (or a few stray marks), and those
    /// go to OCR rather than being parsed as if they were complete.
    private static func hasUsableTextLayer(_ text: String) -> Bool {
        let letters = text.filter { $0.isLetter }.count
        let digits = text.filter { $0.isNumber }.count
        return letters >= 20 && digits >= 2
    }

    /// Rasterise a PDF page for OCR at 2× so small print survives.
    private static func render(_ page: PDFPage) -> CGImage? {
        #if canImport(UIKit)
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            ctx.cgContext.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return image.cgImage
        #else
        return nil
        #endif
    }

    // MARK: - Vision (on-device only)

    private static func recognise(imageData: Data) throws -> [LabReportLine] {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData), let cg = image.cgImage else {
            throw ReadError.unreadableFile
        }
        return try recognise(cgImage: cg)
        #else
        throw ReadError.recognitionUnavailable
        #endif
    }

    private static func recognise(cgImage: CGImage) throws -> [LabReportLine] {
        #if canImport(Vision)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Lab values are numbers and abbreviations; language correction would
        // "helpfully" rewrite them. Off.
        request.usesLanguageCorrection = false
        // THE RAIL — on-device only. `requiresOnDeviceRecognition` was a macOS
        // property and is not in the iOS SDK (checked against iPhoneSimulator
        // 26.5): VNRecognizeTextRequest on iOS recognises entirely on device,
        // with no server path to opt out of. Recorded here rather than claiming
        // a switch we did not set. If a future SDK reintroduces a network path,
        // this is the line that must disable it.
        if let supported = try? request.supportedRecognitionLanguages() {
            let wanted = ["en-US", "da-DK"].filter { supported.contains($0) }
            if !wanted.isEmpty { request.recognitionLanguages = wanted }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return rows(from: observations)
        #else
        throw ReadError.recognitionUnavailable
        #endif
    }

    #if canImport(Vision)
    /// Vision returns one observation per text fragment, so a table row arrives
    /// as separate pieces ("HbA1c" | "42" | "mmol/mol"). Group fragments that
    /// share a baseline back into ONE line, left to right — the parser needs the
    /// name, the value and the unit together to recognise anything at all.
    private static func rows(from observations: [VNRecognizedTextObservation]) -> [LabReportLine] {
        struct Fragment { let text: String; let confidence: Double; let box: CGRect }
        let fragments: [Fragment] = observations.compactMap { obs in
            guard let best = obs.topCandidates(1).first else { return nil }
            let t = best.string.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return nil }
            return Fragment(text: t, confidence: Double(best.confidence), box: obs.boundingBox)
        }
        guard !fragments.isEmpty else { return [] }

        // Vision's origin is bottom-left: a higher midY is higher on the page.
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Fragment]] = []
        for f in sorted {
            if var last = rows.last,
               let ref = last.first,
               abs(ref.box.midY - f.box.midY) < max(ref.box.height, f.box.height) * 0.6 {
                last.append(f)
                rows[rows.count - 1] = last
            } else {
                rows.append([f])
            }
        }
        return rows.map { row in
            let ordered = row.sorted { $0.box.minX < $1.box.minX }
            return LabReportLine(
                text: ordered.map(\.text).joined(separator: "  "),
                confidence: ordered.map(\.confidence).min() ?? 0
            )
        }
    }
    #endif
}
