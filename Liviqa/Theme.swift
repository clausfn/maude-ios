// Theme.swift — Brand tokens v01 · 2026-05-21
// Source: Liviqa_Design_Tokens_v01_20260521.md
// Note: Lato + IBM Plex Mono require font assets in project; using system equivalents for Phase 1.
import SwiftUI

// MARK: - Color(hex:) initialiser

extension Color {
    /// Initialise from a 0xRRGGBB literal (no alpha).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - LiviqaTheme

enum LiviqaTheme {

    // Backgrounds
    static let paper   = Color(hex: 0xF7F5F1)   // app background (never pure white)
    static let paper2  = Color(hex: 0xFCFAF5)   // card fill on paper

    // Text / icons
    static let ink     = Color(hex: 0x0E1A2B)   // headlines, body, primary
    static let ink2    = Color(hex: 0x1F2D42)   // secondary body
    static let ink3    = Color(hex: 0x54627A)   // captions, kickers
    static let ink4    = Color(hex: 0x8896AA)   // disabled, footer-secondary

    // Borders / dividers
    static let line    = Color(hex: 0xDFD9CE)
    static let line2   = Color(hex: 0xEAE5DB)

    // Moss — citizen · consent · active grant (the one accent)
    static let moss    = Color(hex: 0x3D7A5A)
    static let moss2   = Color(hex: 0xE5EFE8)   // consent panel fill
    static let moss3   = Color(hex: 0xC7DCCD)   // consent border tint
    static let mossRev = Color(hex: 0x5BAE86)   // moss on dark backgrounds

    // Amber — engine / middle layer (sparing)
    static let amber   = Color(hex: 0xC47D11)
    static let amber2  = Color(hex: 0xF5E9D2)

    // Rust — refusals / boundary events
    static let rust    = Color(hex: 0xA33A2A)
    static let rust2   = Color(hex: 0xF2DCD7)

    // Elevation
    static let cardShadow = Color.black.opacity(0.04)
}

// MARK: - Font helpers — brand type (Lato + IBM Plex Mono), same as liviqa.app
// Bundled OFL fonts (Liviqa/Fonts, UIAppFonts). Kickers/numbers/timestamps use
// IBM Plex Mono Medium; headlines/body use Lato. Falls back to system if a face
// fails to load.

extension Font {
    /// Mono kicker — 10–11 pt, uppercase, spaced. IBM Plex Mono Medium.
    static func liviqaKicker(_ size: CGFloat = 10) -> Font {
        .custom("IBMPlexMono-Medium", size: size)
    }
    /// Mono number — tabular. IBM Plex Mono Medium.
    static func liviqaMono(_ size: CGFloat = 14) -> Font {
        .custom("IBMPlexMono-Medium", size: size)
    }
    /// Lato (headlines/body). weight maps to Regular/Bold/Black faces.
    static func lato(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .black, .heavy:           face = "Lato-Black"
        case .bold, .semibold:         face = "Lato-Bold"
        default:                       face = "Lato-Regular"
        }
        return .custom(face, size: size)
    }
}
