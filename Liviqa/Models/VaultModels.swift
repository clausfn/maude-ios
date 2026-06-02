// VaultModels.swift — Health vault document model v01 · 2026-05-22
// The vault is a file container, not a clinical system.
// Liviqa never parses document content to produce clinical conclusions.
import Foundation

enum VaultDocType: String, Codable, CaseIterable {
    case lab        = "Lab results"
    case medication = "Medication"
    case imaging    = "Imaging"
    case export     = "EHDS export"
    case other      = "Document"

    var icon: String {
        switch self {
        case .lab:        return "testtube.2"
        case .medication: return "pill.fill"
        case .imaging:    return "waveform.path.ecg.rectangle"
        case .export:     return "arrow.down.doc.fill"
        case .other:      return "doc.fill"
        }
    }

    // Colour token name — resolved in VaultCard
    var colorKey: VaultColor {
        switch self {
        case .lab:        return .amber
        case .medication: return .moss
        case .imaging:    return .ink
        case .export:     return .blue
        case .other:      return .ink3
        }
    }

    enum VaultColor { case amber, moss, ink, blue, ink3 }
}

struct VaultDocument: Identifiable {
    let id: UUID
    var name: String
    var type: VaultDocType
    var source: String       // "Sundhed.dk export", "Manual upload", etc.
    var sizeLabel: String    // "124 KB"
    var date: Date
    var isEncrypted: Bool    // always true in production; false for demo placeholders

    init(name: String, type: VaultDocType, source: String,
         sizeLabel: String = "—", date: Date = Date(), isEncrypted: Bool = true) {
        self.id          = UUID()
        self.name        = name
        self.type        = type
        self.source      = source
        self.sizeLabel   = sizeLabel
        self.date        = date
        self.isEncrypted = isEncrypted
    }
}

// MARK: - Demo vault

extension VaultDocument {
    static let demo: [VaultDocument] = [
        VaultDocument(
            name: "Lab results — HbA1c panel",
            type: .lab,
            source: "Sundhed.dk export",
            sizeLabel: "84 KB",
            date: Date().addingTimeInterval(-86400 * 4)
        ),
        VaultDocument(
            name: "FMK medication list",
            type: .medication,
            source: "Sundhed.dk export",
            sizeLabel: "32 KB",
            date: Date().addingTimeInterval(-86400 * 9)
        ),
        VaultDocument(
            name: "Cardiology referral letter",
            type: .other,
            source: "Manual upload",
            sizeLabel: "210 KB",
            date: Date().addingTimeInterval(-86400 * 14)
        ),
        VaultDocument(
            name: "Patient summary — EHDS",
            type: .export,
            source: "MyHealth@EU",
            sizeLabel: "56 KB",
            date: Date().addingTimeInterval(-86400 * 21)
        ),
    ]
}
