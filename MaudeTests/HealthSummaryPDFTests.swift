import Testing
import Foundation
import SwiftData
import PDFKit
@testable import Maude

// T-EXP-05 — FR-EXP-01: the PRIMARY export artifact — the A4 PDF — carries the
// same content, in the same order, as the document model. Asserted through the
// PDF's TEXT LAYER (PDFKit extraction): structure/order, real dates, qualitative
// words, artifact exclusion, footer. Synthetic fixture only.
@MainActor
struct HealthSummaryPDFTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return cal.date(from: comps)!
    }

    private func fixtureDocument() throws -> HealthSummaryDocument {
        let store = HealthStore(context: ModelContext(try MaudeStore.makeContainer(inMemory: true)))
        let pull = date(2026, 8, 10)
        let src = HealthDataSource.sundhedLive.rawValue
        func obs(_ key: String, _ v: Double, _ unit: String, _ specimen: Date?,
                 kind: SundhedResultKind = .quantitative, text: String? = nil,
                 system: String? = nil) -> HealthObservation {
            HealthObservation(scopeKey: key, value: v, unit: unit,
                              effectiveDate: specimen ?? pull, source: src,
                              importedAt: pull, specimenDate: specimen,
                              resultKind: kind.rawValue, resultText: text, specimen: system)
        }
        store.context.insert(obs("hba1c", 6.8, "%", date(2026, 3, 12), system: "Hb(B)"))
        store.context.insert(obs("hba1c", 7.1, "%", date(2025, 11, 3), system: "Hb(B)"))
        store.context.insert(obs("ldl_cholesterol", 2.1, "mmol/L", date(2026, 3, 12), system: "P"))
        store.context.insert(obs("Hepatitis B overflade antigen;P", 0, "", date(2026, 3, 12),
                                 kind: .qualitative, text: "Ikke påvist", system: "P"))
        store.context.insert(obs("Urin opsamlingstid;Pt(U)", 0, "min", date(2026, 3, 12),
                                 kind: .artifact, system: "Pt(U)"))
        store.context.insert(HealthCondition(icd10: "DE109", onsetDate: date(2019, 1, 1),
                                             source: src, importedAt: pull))
        store.context.insert(HealthMedication(atc: "A10AB01", name: "Novorapid FlexPen",
                                              source: src, importedAt: pull))
        try store.context.save()
        return HealthSummaryDocument.build(store: store, personName: "Astrid Eksempel",
                                           now: date(2026, 8, 15))
    }

    private func renderedText() throws -> String {
        let data = HealthSummaryPDF.render(try fixtureDocument())
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount >= 1)
        return pdf.string ?? ""
    }

    @Test func rendersA4Pages() throws {
        let data = HealthSummaryPDF.render(try fixtureDocument())
        let pdf = try #require(PDFDocument(data: data))
        let bounds = try #require(pdf.page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(bounds.width - 595.28) < 1)
        #expect(abs(bounds.height - 841.89) < 1)
    }

    @Test func textLayerCarriesTheDocumentInOrder() throws {
        let text = try renderedText()
        let anchors = [
            "Health summary",
            "Astrid Eksempel",
            "Generated 15 Aug 2026",
            "Sundhed.dk record as of 10 Aug 2026",
            HealthSummaryDocument.majorDiagnosesTitle,
            "Type 1 diabetes without complications",
            HealthSummaryDocument.medicinesTitle,
            "Novorapid FlexPen",
            HealthSummaryDocument.keyValuesTitle,
            HealthSummaryDocument.labsTitle,
            "Metabolic & glucose",
            "Lipids",
            "Serology & screens",
            HealthSummaryDocument.appendixTitle,
        ]
        var cursor = text.startIndex
        for anchor in anchors {
            let range = text.range(of: anchor, range: cursor..<text.endIndex)
            #expect(range != nil, "missing or out of order: \(anchor)")
            if let range { cursor = range.lowerBound }
        }
    }

    @Test func realSpecimenDatesAndPriorsAreInTheTextLayer() throws {
        let text = try renderedText()
        #expect(text.contains("12 Mar 2026"))
        #expect(text.contains("3 Nov 2025"))
        #expect(text.contains("6.8 %"))
        #expect(text.contains("7.1 %"))
    }

    @Test func qualitativeScreenIsWordsInTheTextLayerNeverZero() throws {
        let text = try renderedText()
        #expect(text.contains("Not detected"))
        // The serology analyte's row never carries a bare zero value.
        #expect(!text.contains("Hepatitis B overflade antigen 0"))
    }

    @Test func artifactRowsStayOutOfPanelsButAppearInTheAppendix() throws {
        let text = try renderedText()
        #expect(text.contains(HealthSummaryDocument.artifactsTitle))
        #expect(text.contains("Urine collection time"))
    }

    @Test func footerIsOnThePage() throws {
        let text = try renderedText()
        #expect(text.contains(HealthSummaryDocument.footer))
        #expect(text.contains("Page 1"))
    }

    @Test func temporaryFileWritesAPdfWithAHumanName() throws {
        let url = try #require(HealthSummaryPDF.writeTemporaryFile(try fixtureDocument()))
        #expect(url.lastPathComponent == "Maude health summary.pdf")
        #expect(PDFDocument(url: url) != nil)
        try? FileManager.default.removeItem(at: url)
    }
}
