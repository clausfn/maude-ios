// Theme.swift — Brand tokens v02 · Paper + Midnight (dynamic) · 2026-06-04
// Source: Liviqa_Design_Tokens_v01 (Paper) + Midnight extension (locked tokens).
// Colours are dynamic: light = Paper, dark = Midnight. The whole app flips via a
// single `.preferredColorScheme` at the root (LiviqaApp), so every existing
// `LiviqaTheme.*` call site recolours automatically — no per-view changes.
import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
    /// Initialise from a 0xRRGGBB literal (no alpha).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    /// Dynamic token: light = Paper value, dark = Midnight value (with optional alphas).
    static func dyn(_ light: UInt32, _ dark: UInt32, _ la: Double = 1, _ da: Double = 1) -> Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(rgb: dark, a: da) : UIColor(rgb: light, a: la)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32, a: Double = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: CGFloat(a))
    }
}

// MARK: - LiviqaTheme

enum LiviqaTheme {

    /// Runtime theme. Default = midnight. Resolved to a ColorScheme at the root;
    /// the dynamic tokens above read that scheme.
    enum Mode: String, CaseIterable, Identifiable {
        case midnight, paper
        var id: String { rawValue }
        var colorScheme: ColorScheme { self == .midnight ? .dark : .light }
        var label: String { self == .midnight ? "Midnight" : "Paper" }
    }

    // Backgrounds
    static let paper   = Color.dyn(0xF7F5F1, 0x0B1320)   // app canvas (never pure white)
    static let paper2  = Color.dyn(0xFCFAF5, 0x14202E)   // card fill

    // Text / icons
    static let ink     = Color.dyn(0x0E1A2B, 0xF5F2EA)
    static let ink2    = Color.dyn(0x1F2D42, 0xCCD5E0)
    static let ink3    = Color.dyn(0x54627A, 0x8A98AD)   // captions, kickers
    static let ink4    = Color.dyn(0x8896AA, 0x5C6B80)

    // Borders / dividers
    static let line    = Color.dyn(0xDFD9CE, 0xFFFFFF, 1, 0.09)
    static let line2   = Color.dyn(0xEAE5DB, 0xFFFFFF, 1, 0.055)

    // Moss — citizen · consent · active grant (the one accent)
    static let moss    = Color.dyn(0x3D7A5A, 0x5CB389)
    static let moss2   = Color.dyn(0xE5EFE8, 0x5CB389, 1, 0.16)
    static let moss3   = Color.dyn(0xC7DCCD, 0x5CB389, 1, 0.34)
    static let mossRev = Color.dyn(0x5BAE86, 0x5CB389)

    // Amber — engine / middle layer (sparing)
    static let amber   = Color.dyn(0xC47D11, 0xE2A847)
    static let amber2  = Color.dyn(0xF5E9D2, 0xE2A847, 1, 0.16)

    // Rust — refusals / boundary events
    static let rust    = Color.dyn(0xA33A2A, 0xDB6A54)
    static let rust2   = Color.dyn(0xF2DCD7, 0xDB6A54, 1, 0.18)

    // Clay — the single patient "worth noticing" attention tone (Design System v2,
    // signals.css, tuned candidate 4). Deliberately NOT amber: clay says "worth a
    // look", never "alarm" — right for an app pitched below the medical-device line.
    // The patient two-state logic is moss = in-range · clay = worth noticing.
    static let clay     = Color.dyn(0xBD7A33, 0xD9A765)            // the attention tone
    static let clay2    = Color.dyn(0xEFE8DB, 0xD9A765, 1, 0.16)   // calm tint fill
    static let clay3    = Color.dyn(0xE0D4BC, 0xD9A765, 1, 0.34)   // border tint
    static let clayText = Color.dyn(0x6B461B, 0xD9A765)            // AA on paper
    static let clayRev  = Color.dyn(0xD9A765, 0xD9A765)            // clay on ink/dark

    // Confidence ramp — qualifies every insight (the evidence/trust mechanism).
    // high = gated (passes r/p) · emerging = directional · learning = baseline building.
    static let confHigh     = moss
    static let confEmerging = clay
    static let confLearning = ink4

    // Hooks (Oura pass)
    static let gridEmpty     = Color.dyn(0xEAE5DB, 0xFFFFFF, 1, 0.06)   // correlation "no data"
    static let heroGlow      = Color.dyn(0x3D7A5A, 0x5CB389, 0.18, 0.30) // radial halo
    static let homeIndicator = Color.dyn(0x0E1A2B, 0xF7F5F1, 0.26, 0.34)
    static let cardShadow    = Color.dyn(0x0E1A2B, 0x000000, 0.06, 0.40)

    // Invert surface (dark chip/button/summary on light; warm-light on dark)
    static let invertBG   = Color.dyn(0x0E1A2B, 0xECE7DC)
    static let invertFG   = Color.dyn(0xFCFAF5, 0x0E1A2B)
    static let invertSub  = Color.dyn(0x9FB0C2, 0x5C6B80)
    static let invertLine = Color.dyn(0xFFFFFF, 0x0E1A2B, 0.12, 0.12)

    enum Radius { static let card: CGFloat = 20; static let hero: CGFloat = 26; static let vitals: CGFloat = 24 }

    /// Letter-spacing from the design type scale. Apply with `.tracking(_:)`.
    /// H1 −0.5 · H2 −0.2 · kicker +1.5 (mono, uppercase) · wordmark −0.4.
    enum Tracking { static let h1: CGFloat = -0.5; static let h2: CGFloat = -0.2; static let kicker: CGFloat = 1.5; static let wordmark: CGFloat = -0.4 }
}

// MARK: - Font helpers — brand type (Lato + IBM Plex Mono, bundled OFL fonts)

extension Font {
    /// Mono kicker — uppercase, spaced. IBM Plex Mono Medium.
    static func liviqaKicker(_ size: CGFloat = 10) -> Font { .custom("IBMPlexMono-Medium", size: size) }
    /// Mono number — tabular. IBM Plex Mono Medium.
    static func liviqaMono(_ size: CGFloat = 14) -> Font { .custom("IBMPlexMono-Medium", size: size) }
    /// Lato (headlines/body). weight maps to Regular/Bold/Black faces.
    static func lato(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .black, .heavy:   face = "Lato-Black"
        case .bold, .semibold: face = "Lato-Bold"
        default:               face = "Lato-Regular"
        }
        return .custom(face, size: size)
    }

    // Semantic type scale (Design System v2 typography.css). Lato for headline/
    // body; mono (liviqaKicker/liviqaMono) for kickers, numbers, timestamps.
    // Apply tracking at the call site via `.tracking(LiviqaTheme.Tracking.*)`.
    static var liviqaH1: Font { lato(32, .heavy) }         // screen headline — 800
    static var liviqaH2: Font { lato(20, .bold) }          // section / card title — 700
    static var liviqaBody: Font { lato(15, .regular) }     // body — 15 / 1.4
    static var liviqaCaption: Font { lato(12, .regular) }  // caption — 12 / 1.4
}
