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

    // Backgrounds  (light = Daylight, dark = Navy)
    static let paper   = Color.dyn(0xF5F6F8, 0x15243D)   // app canvas — off-white / deep navy
    static let paper2  = Color.dyn(0xFFFFFF, 0x1D3557)   // card fill

    // Text / icons
    static let ink     = Color.dyn(0x1D3557, 0xF1FAEE)
    static let ink2    = Color.dyn(0x456079, 0xC9D8E5)
    static let ink3    = Color.dyn(0x51697E, 0x8DA4BC)   // captions, kickers
    static let ink4    = Color.dyn(0x8DA0AC, 0x5C6B80)

    // Borders / dividers
    static let line    = Color.dyn(0xE6E9EE, 0xFFFFFF, 1, 0.10)
    static let line2   = Color.dyn(0xEEF1F4, 0xFFFFFF, 1, 0.06)

    // Positive — consent · in-range (Cerulean + Frosted Blue; NO green hue)
    static let moss    = Color.dyn(0x457B9D, 0xA8DADC)
    static let moss2   = Color.dyn(0xE6F0F2, 0xA8DADC, 1, 0.16)
    static let moss3   = Color.dyn(0xBBD0DE, 0xA8DADC, 1, 0.34)
    static let mossRev = Color.dyn(0xA8DADC, 0xA8DADC)

    // Amber Flame — watch / engine (sparing; fill+navy text)
    static let amber   = Color.dyn(0xFFB703, 0xFFB703)
    static let amber2  = Color.dyn(0xFFF4D6, 0xFFB703, 1, 0.16)

    // Punch Red — refusals / boundary events
    static let rust    = Color.dyn(0xC2242F, 0xF59FA6)
    static let rust2   = Color.dyn(0xFBE3E0, 0xF59FA6, 1, 0.18)

    // “Worth noticing” attention tone — now AMBER FLAME (the old brown clay is retired).
    static let clay     = Color.dyn(0xFFB703, 0xFFB703)            // amber signal
    static let clay2    = Color.dyn(0xFFF4D6, 0xFFB703, 1, 0.16)   // tint fill
    static let clay3    = Color.dyn(0xF2D58C, 0xFFB703, 1, 0.34)   // border tint
    static let clayText = Color.dyn(0x1D3557, 0xFFB703)            // NAVY on light (amber never text)
    static let clayRev  = Color.dyn(0xFFB703, 0xFFB703)

    // Confidence ramp
    static let confHigh     = moss
    static let confEmerging = clay
    static let confLearning = ink4

    // Hooks
    static let gridEmpty     = Color.dyn(0xEEF1F4, 0xFFFFFF, 1, 0.06)
    static let heroGlow      = Color.dyn(0x457B9D, 0xA8DADC, 0.18, 0.30)
    static let homeIndicator = Color.dyn(0x1D3557, 0xF1FAEE, 0.26, 0.34)
    static let cardShadow    = Color.dyn(0x10243B, 0x000000, 0.06, 0.40)

    // Fixed DfG navy
    static let dfgNavy = Color(hex: 0x1D3557)

    // Invert surface
    static let invertBG   = Color.dyn(0x1D3557, 0xF1FAEE)
    static let invertFG   = Color.dyn(0xFFFFFF, 0x1D3557)
    static let invertSub  = Color.dyn(0x8DA0AC, 0x5C6B80)
    static let invertLine = Color.dyn(0xFFFFFF, 0x1D3557, 0.12, 0.12)

    enum Radius { static let card: CGFloat = 20; static let hero: CGFloat = 26; static let vitals: CGFloat = 24 }

    /// Letter-spacing from the design type scale. Apply with `.tracking(_:)`.
    /// H1 −0.5 · H2 −0.2 · kicker +1.5 (mono, uppercase) · wordmark −0.4.
    enum Tracking { static let h1: CGFloat = -0.5; static let h2: CGFloat = -0.2; static let kicker: CGFloat = 1.5; static let wordmark: CGFloat = -0.4 }
}

// MARK: - Font helpers — SF Pro (Dynamic Type) for headlines/body + IBM Plex Mono for numbers

extension Font {
    static func liviqaKicker(_ size: CGFloat = 10) -> Font { .custom("IBMPlexMono-Medium", size: size) }
    static func liviqaMono(_ size: CGFloat = 14) -> Font { .custom("IBMPlexMono-Medium", size: size) }
    /// Headlines/body now use the system face (SF Pro) — Dynamic-Type friendly.
    static func lato(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static var liviqaH1: Font { .system(size: 32, weight: .bold) }
    static var liviqaH2: Font { .system(size: 20, weight: .semibold) }
    static var liviqaBody: Font { .system(size: 15) }
    static var liviqaCaption: Font { .system(size: 12) }
}
