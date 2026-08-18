// HealthSummaryPreviewView.swift — in-app preview of the exported health
// summary: the ACTUAL PDF the citizen is about to hand over, not a different
// text rendering. One artifact, seen before shared.
//
// Presented from the passport's "Share health summary" action (see
// INTEGRATION note in the PR): builds the `HealthSummaryDocument` from the
// on-device store, renders the A4 PDF (`HealthSummaryPDF`), previews it with
// PDFKit and shares the FILE via ShareLink. The plain-text rendering stays
// available as a secondary, accessibility-friendly share.
//
// Nothing here uploads: the share sheet is the citizen's own explicit exit.
import SwiftUI
import PDFKit

struct HealthSummaryPreviewView: View {
    // AppState is @Observable (not ObservableObject) — the codebase-wide
    // pattern is @Environment(AppState.self). (Mechanical unblock by the
    // FR-TOD-07 batch: @EnvironmentObject can never compile against it.)
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var pdfURL: URL?
    @State private var pdfDocument: PDFDocument?
    @State private var textFallback: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if let pdfDocument {
                    SummaryPDFView(document: pdfDocument)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    // Renderer unavailable (shouldn't happen on iOS) — show the
                    // text artifact rather than nothing.
                    ScrollView {
                        Text(textFallback)
                            .font(.liviqaMono(12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            }
            .background(LiviqaTheme.paper)
            .navigationTitle("Health summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ShareLink(item: textFallback) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: textFallback) {
                        Label("Share as text", systemImage: "doc.plaintext")
                    }
                }
            }
            .onAppear(perform: buildDocument)
        }
    }

    private func buildDocument() {
        guard let store = appState.healthStore else { return }
        // Declared name only (FR-ACC-NAME-01 resolution) — never an email.
        let doc = HealthSummaryDocument.build(
            store: store,
            personName: appState.profile?.displayName
        )
        textFallback = doc.plainText()
        if let url = HealthSummaryPDF.writeTemporaryFile(doc) {
            pdfURL = url
            pdfDocument = PDFDocument(url: url)
        }
    }
}

/// PDFKit preview wrapper — single-page-fit, paper-grey surround.
private struct SummaryPDFView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.pageShadowsEnabled = true
        v.backgroundColor = UIColor.secondarySystemBackground
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document { uiView.document = document }
    }
}
