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

    // MARK: Sprint-2 visual system (PR-99 proposal · signed off 2026-06-16, Option B)
    // Clinical glucose Time-in-Range scale — AGP convention (Battelino 2019). Scoped
    // to GLUCOSE charts ONLY — the sanctioned exception to the no-green rule; these
    // never appear elsewhere in the app.
    static let tirVeryLow  = Color.dyn(0x8E1B26, 0xD06470)   // < 3.0 mmol/L  L2 hypo (dark red)
    static let tirLow      = Color.dyn(0xC2242F, 0xF59FA6)   // 3.0–3.8       L1 hypo (red)
    static let tirTarget   = Color.dyn(0x2F9E5E, 0x57D295)   // 3.9–10.0      TARGET (clinical green)
    static let tirHigh     = Color.dyn(0xE8B007, 0xF0C84B)   // 10.1–13.9     L1 hyper (yellow)
    static let tirVeryHigh = Color.dyn(0xF07A12, 0xF7A23B)   // > 13.9        L2 hyper (orange)

    // Graded deviation-heatmap ramp — sequential cool→warm, CAPPED at deep amber
    // (never red; the single strongest outlier carries a non-colour ring). Blue↔amber
    // is deutan/protan-safe.
    static let devMed     = Color.dyn(0xDCE3EA, 0xFFFFFF, 1, 0.10)  // a little off
    static let devHigh    = Color.dyn(0xFCE3A0, 0xFFB703, 1, 0.30)  // clearly off your usual
    static let devOutlier = Color.dyn(0xE0820C, 0xFFC53D)           // worth noticing (+ ring)

    // Per-domain category accents (Option B) — two new calm hues so the "Apple can't"
    // sources read as their own thing. Contrast-tuned starting points.
    static let accentSleep   = Color.dyn(0x4C4FB0, 0x9AA0F0)   // indigo  (sleep)
    static let accentFinance = Color.dyn(0x566472, 0x9FB0BE)   // slate   (financial / context)

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
    static func liviqaKicker(_ size: CGFloat = 10) -> Font {
        .custom("IBMPlexMono-Medium", size: size, relativeTo: .caption2)
    }
    static func liviqaMono(_ size: CGFloat = 14) -> Font {
        .custom("IBMPlexMono-Medium", size: size, relativeTo: .footnote)
    }
    /// Headlines/body use the system face (SF Pro), scaled with the user's iOS
    /// text-size setting via UIFontMetrics. `.system(size:)` / `.custom(_:size:)`
    /// WITHOUT `relativeTo:` never scale — that omission was FB-AEkAWxal ("changed
    /// text size and it did not change"). All ~566 call sites scale from here.
    static func lato(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        scaledSystem(size, weight, .body)
    }
    static var liviqaH1: Font { scaledSystem(32, .bold, .largeTitle) }
    static var liviqaH2: Font { scaledSystem(20, .semibold, .title3) }
    static var liviqaBody: Font { scaledSystem(15, .regular, .subheadline) }
    static var liviqaCaption: Font { scaledSystem(12, .regular, .caption1) }

    /// A system font at `size`/`weight` that grows/shrinks with Dynamic Type,
    /// anchored to `style`. UIFontMetrics scales from the Large default, so the
    /// default text size looks identical to before — only non-default sizes change.
    private static func scaledSystem(_ size: CGFloat, _ weight: Font.Weight,
                                     _ style: UIFont.TextStyle = .body) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight.uiKit)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }
}

private extension Font.Weight {
    /// SwiftUI weight → UIKit weight, for the UIFontMetrics-scaled system face.
    var uiKit: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        default:          return .regular
        }
    }
}
