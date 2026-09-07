// HealthSummaryPDF.swift — the PRIMARY artifact of the health summary export:
// an A4, print-first PDF in the A7.2 print identity.
//
// Register (paper-first — no theme dependence, this will be printed):
//  • Charter serif for the title and section headings (bundled with iOS;
//    system-serif fallback), sentence case;
//  • SF Pro for body/labels;
//  • IBM Plex Mono (bundled, Info.plist-registered) for VALUES so figures
//    align; monospaced-digit SF fallback;
//  • the PPCN mark ("MaudeMark") small in the header;
//  • fjord ink on paper white, hairline rules, generous margins;
//  • NO colour-as-verdict, no judgements — values, dates, names only.
//
// Composition (same structure & order as `HealthSummaryDocument.plainText()`):
//  Page 1, the 90-second read: identity block (declared name, generated date,
//  source freshness) → major diagnoses in plain language → current medicines →
//  the "latest key values" band. Then the lab panels in aligned columns
//  (analyte · value · date · previous), qualitative results as words. Appendix:
//  secondary diagnosis entries + excluded collection artifacts + the source
//  citation. Footer on every page.
//
// UIKit only for drawing (UIGraphicsPDFRenderer); the document MODEL stays in
// HealthSummaryDocument (pure Foundation), so content is golden-tested there
// and the PDF's text layer is asserted separately.
import Foundation
#if canImport(UIKit)
import UIKit

enum HealthSummaryPDF {

    // MARK: - Page metrics (A4, points)

    private static let pageSize = CGSize(width: 595.28, height: 841.89)
    private static let marginL: CGFloat = 56
    private static let marginR: CGFloat = 56
    private static let marginTop: CGFloat = 54
    private static let marginBottom: CGFloat = 58
    private static var contentWidth: CGFloat { pageSize.width - marginL - marginR }

    // MARK: - Ink (print palette — fixed, theme-free)

    private static let ink = UIColor(red: 0x0B/255.0, green: 0x1B/255.0, blue: 0x26/255.0, alpha: 1)
    private static let sub = UIColor(red: 0x4E/255.0, green: 0x5A/255.0, blue: 0x66/255.0, alpha: 1)
    private static let faint = UIColor(red: 0x8A/255.0, green: 0x94/255.0, blue: 0xA3/255.0, alpha: 1)
    private static let rule = UIColor(red: 0xD8/255.0, green: 0xDD/255.0, blue: 0xE2/255.0, alpha: 1)

    // MARK: - Type (print register)

    private static func serif(_ size: CGFloat, bold: Bool = true) -> UIFont {
        if let f = UIFont(name: bold ? "Charter-Bold" : "Charter-Roman", size: size) { return f }
        let base = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        if let desc = base.fontDescriptor.withDesign(.serif) { return UIFont(descriptor: desc, size: size) }
        return base
    }
    private static func body(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
    private static func mono(_ size: CGFloat, medium: Bool = false) -> UIFont {
        UIFont(name: medium ? "IBMPlexMono-Medium" : "IBMPlexMono-Regular", size: size)
            ?? UIFont.monospacedDigitSystemFont(ofSize: size, weight: medium ? .medium : .regular)
    }

    // MARK: - Render

    /// Render the document to PDF data. Deterministic layout from the model.
    static func render(_ doc: HealthSummaryDocument) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Maude \(HealthSummaryDocument.title)",
            kCGPDFContextCreator as String: "Maude",
        ]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize), format: format)
        return renderer.pdfData { ctx in
            let c = Composer(ctx: ctx)
            c.beginPage()
            drawHeader(doc, c)
            drawDiagnoses(doc, c)
            drawMedicines(doc, c)
            drawKeyValues(doc, c)
            drawPanels(doc, c)
            drawAppendix(doc, c)
        }
    }

    /// Write the PDF to a shareable temporary file with a human filename.
    static func writeTemporaryFile(_ doc: HealthSummaryDocument) -> URL? {
        let data = render(doc)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Maude health summary.pdf")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    // MARK: - Sections

    private static func drawHeader(_ doc: HealthSummaryDocument, _ c: Composer) {
        // Mark + kicker row.
        var kickerX = marginL
        if let mark = UIImage(named: "MaudeMark") {
            let h: CGFloat = 15
            let w = mark.size.height > 0 ? mark.size.width * (h / mark.size.height) : h
            mark.draw(in: CGRect(x: marginL, y: c.y, width: w, height: h))
            kickerX += w + 7
        }
        c.drawText("MAUDE", font: body(9, weight: .bold), color: sub,
                   x: kickerX, width: contentWidth, kern: 1.6, advance: false)
        c.space(24)

        // Title + identity block.
        c.drawText(HealthSummaryDocument.title, font: serif(29), color: ink,
                   x: marginL, width: contentWidth)
        c.space(6)
        if let name = doc.personName {
            c.drawText(name, font: body(13, weight: .semibold), color: ink,
                       x: marginL, width: contentWidth)
            c.space(5)
        }
        c.drawText(doc.generatedText, font: body(9.5), color: sub,
                   x: marginL, width: contentWidth)
        c.space(2.5)
        for s in doc.sources {
            c.drawText(s.label, font: body(9.5), color: sub, x: marginL, width: contentWidth)
            c.space(2.5)
        }
        c.drawText(doc.includedText, font: body(9.5), color: faint,
                   x: marginL, width: contentWidth)
        c.space(12)
        c.drawRule(weight: 1.0)
        c.space(14)
    }

    private static func sectionHeading(_ title: String, _ c: Composer) {
        c.ensureRoom(46)
        c.drawText(title, font: serif(15), color: ink, x: marginL, width: contentWidth)
        c.space(4)
        c.drawRule()
        c.space(8)
    }

    private static func drawDiagnoses(_ doc: HealthSummaryDocument, _ c: Composer) {
        guard !doc.majorDiagnoses.isEmpty else { return }
        sectionHeading(HealthSummaryDocument.majorDiagnosesTitle, c)
        for d in doc.majorDiagnoses {
            c.ensureRoom(18)
            let detail = [d.code, d.sinceText, d.sourceLabel].compactMap { $0 }.joined(separator: " · ")
            c.drawColumns([
                Col(d.name, font: body(10.5, weight: .semibold), color: ink, width: 300),
                Col(detail, font: body(9), color: sub, width: contentWidth - 312, x: 312),
            ])
            c.space(4.5)
        }
        c.space(2)
        c.drawText("Note: \(HealthSummaryDocument.diagnosesNote)",
                   font: body(8), color: faint, x: marginL, width: contentWidth)
        c.space(14)
    }

    private static func drawMedicines(_ doc: HealthSummaryDocument, _ c: Composer) {
        guard !doc.medicines.isEmpty else { return }
        sectionHeading(HealthSummaryDocument.medicinesTitle, c)
        columnHeaders([("Medicine", 0, 226), ("Form", 226, 138), ("ATC", 372, 62), ("Source", 434, contentWidth - 434)], c)
        for m in doc.medicines {
            c.ensureRoom(18)
            c.drawColumns([
                Col(m.name, font: body(10, weight: .semibold), color: ink, width: 218),
                Col(m.form ?? "", font: body(9), color: sub, width: 138, x: 226),
                Col(m.atc ?? "—", font: mono(9), color: sub, width: 62, x: 372),
                Col(m.sourceLabel, font: body(8.5), color: faint, width: contentWidth - 434, x: 434),
            ])
            c.space(4.5)
        }
        c.space(12)
    }

    private static func drawKeyValues(_ doc: HealthSummaryDocument, _ c: Composer) {
        guard !doc.keyValues.isEmpty else { return }
        sectionHeading(HealthSummaryDocument.keyValuesTitle, c)
        for k in doc.keyValues {
            c.ensureRoom(20)
            c.drawColumns([
                Col(k.name, font: body(10.5, weight: .semibold), color: ink, width: 128),
                Col(k.valueText, font: mono(11.5, medium: true), color: ink, width: 96, x: 132),
                Col(k.dateText, font: body(9), color: sub, width: 78, x: 232),
                Col(k.priorText ?? "", font: body(9), color: faint, width: contentWidth - 314, x: 314),
            ])
            c.space(5.5)
        }
        c.space(12)
    }

    private static func drawPanels(_ doc: HealthSummaryDocument, _ c: Composer) {
        guard !doc.panels.isEmpty else { return }
        sectionHeading(HealthSummaryDocument.labsTitle, c)
        for panel in doc.panels {
            c.ensureRoom(52)
            c.drawText(panel.title, font: serif(12), color: ink, x: marginL, width: contentWidth)
            c.space(5)
            columnHeaders([("Result", 0, 178), ("Value", 178, 104), ("Date", 286, 84), ("Previous", 374, contentWidth - 374)], c)
            for lab in panel.lines {
                drawLabLine(lab, c)
            }
            c.space(9)
        }
        c.space(3)
    }

    private static func drawLabLine(_ lab: HealthSummaryDocument.LabLine, _ c: Composer) {
        c.ensureRoom(20)
        let latest = lab.entries.first
        let prior = lab.entries.dropFirst().first
        let nameText = NSMutableAttributedString(
            string: lab.name, attributes: [.font: body(9.5, weight: .semibold), .foregroundColor: ink])
        if let spec = lab.specimenLabel {
            nameText.append(NSAttributedString(
                string: "  \(spec)", attributes: [.font: body(7.5), .foregroundColor: faint]))
        }
        let valueFont: UIFont = (latest?.isQualitative == true) ? body(9.5, weight: .medium) : mono(9.5, medium: true)
        let priorText = prior.map { "\($0.valueText) — \($0.dateText)" } ?? "—"
        c.drawColumns([
            Col(attributed: nameText, width: 172),
            Col(latest?.valueText ?? "—", font: valueFont, color: ink, width: 104, x: 178),
            Col(latest?.dateText ?? "—", font: body(8.5), color: sub, width: 84, x: 286),
            Col(priorText, font: body(8.5), color: faint, width: contentWidth - 374, x: 374),
        ])
        // The SOURCE's own reference interval, when captured — labelled as such.
        if let ref = latest?.sourceReference, !ref.isEmpty {
            c.space(1)
            c.drawText("\(HealthSummaryDocument.sourceReferencePrefix) \(ref)",
                       font: body(7.5), color: faint, x: marginL + 178, width: contentWidth - 178)
        }
        c.space(4)
    }

    private static func drawAppendix(_ doc: HealthSummaryDocument, _ c: Composer) {
        guard !doc.appendixDiagnoses.isEmpty || !doc.excludedArtifactLines.isEmpty else { return }
        sectionHeading(HealthSummaryDocument.appendixTitle, c)
        for d in doc.appendixDiagnoses {
            c.ensureRoom(16)
            let detail = [d.code, d.sinceText, d.sourceLabel].compactMap { $0 }.joined(separator: " · ")
            c.drawColumns([
                Col(d.name, font: body(9.5), color: ink, width: 300),
                Col(detail, font: body(8.5), color: sub, width: contentWidth - 312, x: 312),
            ])
            c.space(4)
        }
        if !doc.appendixDiagnoses.isEmpty {
            c.space(2)
            c.drawText("Note: \(HealthSummaryDocument.diagnosesNote)",
                       font: body(8), color: faint, x: marginL, width: contentWidth)
            c.space(8)
        }
        if !doc.excludedArtifactLines.isEmpty {
            c.ensureRoom(24)
            c.drawText("\(HealthSummaryDocument.artifactsTitle):",
                       font: body(9, weight: .semibold), color: sub, x: marginL, width: contentWidth)
            c.space(3)
            for a in doc.excludedArtifactLines {
                c.ensureRoom(14)
                c.drawText(a, font: body(8.5), color: faint, x: marginL + 10, width: contentWidth - 10)
                c.space(3)
            }
        }
    }

    private static func columnHeaders(_ cols: [(String, CGFloat, CGFloat)], _ c: Composer) {
        c.ensureRoom(16)
        c.drawColumns(cols.map { (title, x, w) in
            Col(title.uppercased(), font: body(7, weight: .semibold), color: faint, width: w, x: x, kern: 0.8)
        })
        c.space(2.5)
        c.drawRule()
        c.space(5)
    }

    // MARK: - Composer (cursor + page breaks + footer)

    private struct Col {
        let attributed: NSAttributedString
        let width: CGFloat
        let x: CGFloat      // offset from the left margin

        init(_ text: String, font: UIFont, color: UIColor, width: CGFloat,
             x: CGFloat = 0, kern: CGFloat = 0) {
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            if kern != 0 { attrs[.kern] = kern }
            self.attributed = NSAttributedString(string: text, attributes: attrs)
            self.width = width
            self.x = x
        }
        init(attributed: NSAttributedString, width: CGFloat, x: CGFloat = 0) {
            self.attributed = attributed
            self.width = width
            self.x = x
        }
    }

    private final class Composer {
        let ctx: UIGraphicsPDFRendererContext
        var y: CGFloat = HealthSummaryPDF.marginTop
        private var page = 0

        init(ctx: UIGraphicsPDFRendererContext) { self.ctx = ctx }

        func beginPage() {
            ctx.beginPage()
            page += 1
            y = HealthSummaryPDF.marginTop
            drawFooter()
        }

        /// Start a new page when fewer than `height` points remain.
        func ensureRoom(_ height: CGFloat) {
            if y + height > HealthSummaryPDF.pageSize.height - HealthSummaryPDF.marginBottom {
                beginPage()
            }
        }

        func space(_ h: CGFloat) { y += h }

        /// Draw wrapped text at `x` (absolute), advancing the cursor by its height.
        func drawText(_ text: String, font: UIFont, color: UIColor,
                      x: CGFloat, width: CGFloat, kern: CGFloat = 0, advance: Bool = true) {
            var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            if kern != 0 { attrs[.kern] = kern }
            let a = NSAttributedString(string: text, attributes: attrs)
            let h = measure(a, width: width)
            ensureRoom(h)
            a.draw(with: CGRect(x: x, y: y, width: width, height: h),
                   options: [.usesLineFragmentOrigin], context: nil)
            if advance { y += h }
        }

        /// Draw one ROW of columns (offsets relative to the left margin);
        /// advances by the tallest cell.
        func drawColumns(_ cols: [Col]) {
            let heights = cols.map { measure($0.attributed, width: $0.width) }
            let rowH = heights.max() ?? 0
            ensureRoom(rowH)
            for (i, col) in cols.enumerated() {
                col.attributed.draw(
                    with: CGRect(x: HealthSummaryPDF.marginL + col.x, y: y,
                                 width: col.width, height: heights[i]),
                    options: [.usesLineFragmentOrigin], context: nil)
            }
            y += rowH
        }

        func drawRule(weight: CGFloat = 0.5) {
            let g = ctx.cgContext
            g.setStrokeColor(HealthSummaryPDF.rule.cgColor)
            g.setLineWidth(weight)
            g.move(to: CGPoint(x: HealthSummaryPDF.marginL, y: y))
            g.addLine(to: CGPoint(x: HealthSummaryPDF.pageSize.width - HealthSummaryPDF.marginR, y: y))
            g.strokePath()
            y += weight
        }

        private func drawFooter() {
            let fy = HealthSummaryPDF.pageSize.height - HealthSummaryPDF.marginBottom + 18
            let left = NSAttributedString(
                string: HealthSummaryDocument.footer,
                attributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: HealthSummaryPDF.faint])
            left.draw(at: CGPoint(x: HealthSummaryPDF.marginL, y: fy))
            let right = NSAttributedString(
                string: "Page \(page)",
                attributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: HealthSummaryPDF.faint])
            let w = right.size().width
            right.draw(at: CGPoint(x: HealthSummaryPDF.pageSize.width - HealthSummaryPDF.marginR - w, y: fy))
        }

        private func measure(_ a: NSAttributedString, width: CGFloat) -> CGFloat {
            ceil(a.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin], context: nil).height)
        }
    }
}
#endif
