// Theme.swift — Brand tokens v03 · "Morning Edition" (light) + "Evening Edition" (dark) · 2026-07-07
// Source: Liviqa Redesign (Claude Design) — LIVIQA-DESIGN-SYSTEM.md + liviqa/tokens.css + shared.jsx T.
// Deployed per CN 2026-07-07 ("deploy the new design on all screens"): skin only — IA, structure and
// copy unchanged. Departures from A6 Daylight: warm plaster ground, Charter serif verdicts, ONE accent
// (deep fjord teal), amber reserved for the single earned attention card, brass only at consent/witness
// moments. Colours stay dynamic: light = Morning, dark = Evening. Every existing `LiviqaTheme.*` call
// site recolours automatically — no per-view changes.
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
    /// Dynamic token: light = Morning value, dark = Evening value (with optional alphas).
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
    /// the dynamic tokens above read that scheme. (Labels are shipped copy — unchanged.)
    enum Mode: String, CaseIterable, Identifiable {
        case midnight, paper
        var id: String { rawValue }
        var colorScheme: ColorScheme { self == .midnight ? .dark : .light }
        var label: String { self == .midnight ? "Midnight" : "Paper" }
    }

    // Backgrounds  (light = warm plaster · dark = marine)
    static let paper   = Color.dyn(0xF5F2EE, 0x0B1B26)   // app canvas — plaster / marine
    static let paper2  = Color.dyn(0xFFFFFF, 0x13293B)   // card fill — white / plate

    // Text / icons  (dark = warm off-white, stepped by opacity per the evening spec)
    static let ink     = Color.dyn(0x1D3557, 0xF0EAE0)
    static let ink2    = Color.dyn(0x4E5A66, 0xF0EAE0, 1, 0.68)
    static let ink3    = Color.dyn(0x6E6A63, 0xF0EAE0, 1, 0.45)   // datelines, captions, kickers
    static let ink4    = Color.dyn(0x9C968B, 0xF0EAE0, 1, 0.30)

    // Borders / dividers — warm hairlines
    static let line    = Color.dyn(0xE7E2DA, 0xF0EAE0, 1, 0.14)
    static let line2   = Color.dyn(0xEFEBE4, 0xF0EAE0, 1, 0.08)

    // THE accent — deep fjord teal (links, primary, positive, consent, on-device chip).
    // Dark value is fjord lifted for contrast on marine (derived, ≥4.5:1 on 0x0B1B26).
    static let moss    = Color.dyn(0x0F6B66, 0x5FB3AC)
    static let moss2   = Color.dyn(0xE3F0EE, 0x0F6B66, 1, 0.22)   // quiet fills
    static let moss3   = Color.dyn(0xC7E0DC, 0x5FB3AC, 1, 0.34)   // border tint
    static let mossRev = Color.dyn(0x5FB3AC, 0x5FB3AC)

    // Amber — ONLY the earned attention card (fill/border/dot; words stay ink)
    static let amber   = Color.dyn(0xFFB703, 0xFFB703)
    static let amber2  = Color.dyn(0xFFF6E0, 0xFFB703, 1, 0.16)

    // Refusals / boundary events — the clinical red family (text-safe on light)
    static let rust    = Color.dyn(0xC13B34, 0xEE9089)
    static let rust2   = Color.dyn(0xF8E7E5, 0xC13B34, 1, 0.20)

    // “Worth noticing” attention tone — amber (Morning Edition earned-attention card).
    static let clay     = Color.dyn(0xFFB703, 0xFFB703)            // amber signal
    static let clay2    = Color.dyn(0xFFF6E0, 0xFFB703, 1, 0.16)   // tint fill
    static let clay3    = Color.dyn(0xF2DFA9, 0xFFB703, 1, 0.34)   // border tint
    static let clayText = Color.dyn(0x1D3557, 0xFFB703)            // words are ink on light
    static let clayRev  = Color.dyn(0xFFB703, 0xFFB703)

    // Brass — consent / witness moments ONLY (evening palette; quiet frame + text on dark)
    static let brass   = Color.dyn(0xA98B4F, 0xC9A96A)
    static let brass2  = Color.dyn(0xF4EDDF, 0xC9A96A, 1, 0.16)

    // Confidence ramp
    static let confHigh     = moss
    static let confEmerging = clay
    static let confLearning = ink4

    // Hooks
    static let gridEmpty     = Color.dyn(0xEFEBE4, 0xF0EAE0, 1, 0.08)
    static let heroGlow      = Color.dyn(0x0F6B66, 0x5FB3AC, 0.16, 0.28)
    static let homeIndicator = Color.dyn(0x1D3557, 0xF0EAE0, 0.26, 0.34)
    static let cardShadow    = Color.dyn(0x132030, 0x000000, 0.07, 0.40)

    // Clinical glucose Time-in-Range scale — AGP convention (Battelino 2019). Scoped
    // to GLUCOSE charts ONLY (the one place clinical green/red exist in the app).
    static let tirVeryLow  = Color.dyn(0x8E1B26, 0xD06470)   // < 3.0 mmol/L  L2 hypo (dark red)
    static let tirLow      = Color.dyn(0xC13B34, 0xEE9089)   // 3.0–3.8       L1 hypo (red)
    static let tirTarget   = Color.dyn(0x2F8A57, 0x57C08A)   // 3.9–10.0      TARGET (clinical green)
    static let tirHigh     = Color.dyn(0xE8B007, 0xF0C84B)   // 10.1–13.9     L1 hyper (yellow)
    static let tirVeryHigh = Color.dyn(0xF07A12, 0xF7A23B)   // > 13.9        L2 hyper (orange)

    // Graded deviation-heatmap ramp — sequential warm-neutral → amber, CAPPED at deep
    // amber (never red; the single strongest outlier carries a non-colour ring).
    static let devMed     = Color.dyn(0xE8E2D8, 0xF0EAE0, 1, 0.10)  // a little off
    static let devHigh    = Color.dyn(0xFCE3A0, 0xFFB703, 1, 0.30)  // clearly off your usual
    static let devOutlier = Color.dyn(0xE0820C, 0xFFC53D)           // worth noticing (+ ring)

    // Per-domain data colours (charts, rules, icon tints — never page chrome).
    // Values = Morning Edition `T` (shared.jsx); dark variants lifted for marine ground.
    static let accentSleep    = Color.dyn(0x5B5FC7, 0x9AA0F0)   // sleep indigo
    static let accentGlucose  = Color.dyn(0x0E8177, 0x53B3A9)   // glucose teal
    static let accentRecovery = Color.dyn(0x2E86AB, 0x6FB4D4)   // recovery sea blue
    static let accentHeart    = Color.dyn(0xC0566B, 0xD98A99)   // heart rose
    static let accentFinance  = Color.dyn(0x566472, 0x9FB0BE)   // slate (financial / context)

    // Fixed DfG navy
    static let dfgNavy = Color(hex: 0x1D3557)

    // Invert surface
    static let invertBG   = Color.dyn(0x1D3557, 0xF0EAE0)
    static let invertFG   = Color.dyn(0xFFFFFF, 0x0B1B26)
    static let invertSub  = Color.dyn(0x9C968B, 0x4E5A66)
    static let invertLine = Color.dyn(0xFFFFFF, 0x0B1B26, 0.12, 0.12)

    enum Radius { static let card: CGFloat = 18; static let hero: CGFloat = 22; static let vitals: CGFloat = 22 }

    /// Letter-spacing from the design type scale. Apply with `.tracking(_:)`.
    /// Serif verdicts sit near-natural (−0.2) · kicker +1.5 (≈0.14em, uppercase).
    enum Tracking { static let h1: CGFloat = -0.2; static let h2: CGFloat = -0.1; static let kicker: CGFloat = 1.5; static let wordmark: CGFloat = -0.4 }
}

// MARK: - Font helpers — Charter serif verdicts + SF Pro everything else + tabular numbers

extension Font {
    /// Kicker — 11px-class sans, bold, tracked uppercase (the only all-caps). SF Pro now
    /// (Morning Edition retires the mono kicker); call sites keep applying Tracking.kicker.
    static func liviqaKicker(_ size: CGFloat = 10) -> Font {
        scaledSystem(size, .bold, .caption2)
    }
    /// Numeric face — SF with tabular (monospaced) digits so figures align. Replaces the
    /// former IBM Plex Mono at every call site; text set in it remains legible SF.
    static func liviqaMono(_ size: CGFloat = 14) -> Font {
        scaledSystem(size, .medium, .footnote).monospacedDigit()
    }
    /// Verdicts / headlines — Charter (bundled with iOS; falls back to the system serif).
    /// Sentence case, bold. The Morning Edition signature voice.
    static func liviqaSerif(_ size: CGFloat, _ weight: Font.Weight = .bold,
                            relativeTo style: UIFont.TextStyle = .title3) -> Font {
        scaledSerif(size, weight, style)
    }
    /// Headlines/body use the system face (SF Pro), scaled with the user's iOS
    /// text-size setting via UIFontMetrics. `.system(size:)` / `.custom(_:size:)`
    /// WITHOUT `relativeTo:` never scale — that omission was FB-AEkAWxal ("changed
    /// text size and it did not change"). All ~566 call sites scale from here.
    static func lato(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        scaledSystem(size, weight, .body)
    }
    static var liviqaH1: Font { scaledSerif(30, .bold, .largeTitle) }
    static var liviqaH2: Font { scaledSerif(20, .bold, .title3) }
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

    /// Charter, Dynamic-Type-scaled. Charter ships with iOS (Roman/Bold/Italic/Black);
    /// if ever unavailable, falls back to the system serif design (New York).
    private static func scaledSerif(_ size: CGFloat, _ weight: Font.Weight,
                                    _ style: UIFont.TextStyle) -> Font {
        let name: String
        switch weight {
        case .black, .heavy: name = "Charter-Black"
        case .bold, .semibold: name = "Charter-Bold"
        default: name = "Charter-Roman"
        }
        let base: UIFont
        if let charter = UIFont(name: name, size: size) {
            base = charter
        } else if let desc = UIFont.systemFont(ofSize: size, weight: weight.uiKit)
                    .fontDescriptor.withDesign(.serif) {
            base = UIFont(descriptor: desc, size: size)
        } else {
            base = UIFont.systemFont(ofSize: size, weight: weight.uiKit)
        }
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
