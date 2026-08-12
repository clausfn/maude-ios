// Theme.swift — Brand tokens v04 · "A7.2 Electric Ink" (light) + "Evening Edition" (dark) · 2026-08-12
// Source: design_handoff_liviqa_a7 (A7.2) — "Migrate to A7.2 - Coding Prompt.md" + tokens.css.
// A7.2 replaces the v03 warm-plaster light palette (review rounds 3–4, CN-approved 2026-08-12):
// near-white cool paper, softened-cobalt ink, ONE brighter fjord teal (text/buttons) + a graphic-only
// bright variant, saturated domain colours, colour-safe TIR ramp. DARK (Evening) args untouched —
// with exactly two exceptions noted inline (accentHeart lift; amber stays 0xFFB703 in dark, so amber
// is deliberately mode-split). APPROVED DEVIATIONS from the package (CN 2026-08-12): accentHeart is
// rose-punch 0xD9486B, NOT the package's 0xE62E3D — a second saturated red would collide with the
// red-is-clinical-glucose-only lock (RK-ALARM-01); see qms/RISK.md PR-105. Every `LiviqaTheme.*`
// call site recolours automatically — no per-view changes.
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

    // Backgrounds  (light = cool near-white paper · dark = marine)
    static let paper   = Color.dyn(0xE9F1FA, 0x0B1B26)   // app canvas — electric paper / marine
    static let paper2  = Color.dyn(0xFFFFFF, 0x13293B)   // card fill — white / plate

    // Text / icons  (light = softened cobalt · dark = warm off-white, stepped by opacity)
    static let ink     = Color.dyn(0x2A4FAE, 0xF0EAE0)
    static let ink2    = Color.dyn(0x48598E, 0xF0EAE0, 1, 0.68)
    static let ink3    = Color.dyn(0x535F8C, 0xF0EAE0, 1, 0.45)   // datelines, captions, kickers; tab-bar inactive (5.45:1 on paper)
    // APPROVED DEVIATION (a11y): the package's ink4 0x8C96BB fails even the 3:1
    // large-text floor on both grounds (2.56/2.92:1). Darkened one step to 0x7E88B0
    // (≥3.0:1) so the hint tier is at least large-text/UI legible; body-size text
    // still belongs in ink3 or darker (iOS .tertiaryLabel convention).
    static let ink4    = Color.dyn(0x7E88B0, 0xF0EAE0, 1, 0.30)

    // Borders / dividers — cool hairlines
    static let line    = Color.dyn(0xD9E4F2, 0xF0EAE0, 1, 0.14)
    static let line2   = Color.dyn(0xEAF1F9, 0xF0EAE0, 1, 0.08)

    // THE accent — fjord teal as TEXT/BUTTONS (links, primary, positive, consent, chip label).
    // 4.93:1 on white cards (AA) but 4.33:1 on the paper canvas — teal TEXT belongs on cards.
    // Dark value lifted for contrast on marine (≥4.5:1 on 0x0B1B26).
    static let moss    = Color.dyn(0x077E77, 0x5FB3AC)
    static let moss2   = Color.dyn(0xD9F4F1, 0x0F6B66, 1, 0.22)   // quiet fills
    static let moss3   = Color.dyn(0xC7DCF5, 0x5FB3AC, 1, 0.34)   // border tint
    static let mossRev = Color.dyn(0x5FB3AC, 0x5FB3AC)

    /// THE accent as GRAPHIC — rings, chart strokes, chip ring, solid icon squares.
    /// NEVER text (~2.3–2.6:1 by design); text and buttons keep using `moss`.
    /// Solid squares in this colour REQUIRE an adjacent text label (fails 3:1 alone).
    static let fjordBright = Color.dyn(0x00B5AC, 0x5FB3AC)

    // Amber — ONLY the earned attention card (fill/border/dot; words stay ink).
    // DELIBERATELY MODE-SPLIT (A7.2): light = 0xFFC533, dark/watch stays 0xFFB703 —
    // a grep seeing "inconsistent" amber is seeing the spec, not a bug. NOTE: light
    // amber now aliases tirHigh exactly — accepted with the RISK renewal (PR-105).
    static let amber   = Color.dyn(0xFFC533, 0xFFB703)
    static let amber2  = Color.dyn(0xFFF3D1, 0xFFB703, 1, 0.16)

    // Refusals / boundary events — the clinical red family (text-safe on light)
    static let rust    = Color.dyn(0xC13B34, 0xEE9089)
    static let rust2   = Color.dyn(0xF8E7E5, 0xC13B34, 1, 0.20)

    // “Worth noticing” attention tone — amber (earned-attention card; same mode-split as `amber`).
    static let clay     = Color.dyn(0xFFC533, 0xFFB703)            // amber signal
    static let clay2    = Color.dyn(0xFFF3D1, 0xFFB703, 1, 0.16)   // tint fill
    static let clay3    = Color.dyn(0xF5E5AC, 0xFFB703, 1, 0.34)   // border tint
    static let clayText = Color.dyn(0x2A4FAE, 0xFFB703)            // words are ink on light (6.72:1 on amber2)
    static let clayRev  = Color.dyn(0xFFC533, 0xFFB703)

    // Brass — consent / witness moments ONLY (evening palette; quiet frame + text on dark)
    static let brass   = Color.dyn(0xA98B4F, 0xC9A96A)
    static let brass2  = Color.dyn(0xF4EDDF, 0xC9A96A, 1, 0.16)

    // Confidence ramp
    static let confHigh     = moss
    static let confEmerging = clay
    static let confLearning = ink4

    // Hooks
    static let gridEmpty     = Color.dyn(0xEAF1F9, 0xF0EAE0, 1, 0.08)
    static let heroGlow      = Color.dyn(0x00B5AC, 0x5FB3AC, 0.16, 0.28)
    static let homeIndicator = Color.dyn(0x2A4FAE, 0xF0EAE0, 0.26, 0.34)
    static let cardShadow    = Color.dyn(0x2A4FAE, 0x000000, 0.10, 0.40)

    // Clinical glucose Time-in-Range scale — A7.2 FROZEN colour-safety ramp (CN-approved
    // 2026-08-12, qms/RISK.md PR-105). Scoped to GLUCOSE charts ONLY. Bands are NEVER
    // colour-alone: very-low renders with a HATCH overlay, very-high with DOTS, and every
    // band carries an in-chart text label (chart-side, OuraComponents). All dark lifts
    // verified ≥3:1 on plate 0x13293B (3.33/6.37/8.80/10.78/4.99).
    static let tirVeryLow  = Color.dyn(0x6A1B4D, 0xA85E93)   // < 3.0 mmol/L  L2 hypo (plum + hatch)
    static let tirLow      = Color.dyn(0xE8556D, 0xF08CA0)   // 3.0–3.8       L1 hypo (warm red-rose)
    static let tirTarget   = Color.dyn(0x00CC63, 0x4FE08F)   // 3.9–10.0      TARGET (clinical green)
    static let tirHigh     = Color.dyn(0xFFC533, 0xFFD76B)   // 10.1–13.9     L1 hyper (amber)
    static let tirVeryHigh = Color.dyn(0xB5561E, 0xD97E45)   // > 13.9        L2 hyper (sienna + dots)
    /// Clinical out-of-range MARK — glucose charts ONLY (RK-ALARM-01, package token
    /// `clinRed` 0xDA2F46): the out-of-range re-stroke + peak annotation on the day
    /// curve and the excursion caps on the week bars. NEVER an accent, border, or
    /// text outside the glucose clinical charts. Always paired with a non-colour
    /// signal (position outside the labelled band + worded/numeric annotation).
    /// Dark lifted 0xF0637A, ≥3:1 on plate 0x13293B (≈4.8:1).
    static let clinRed     = Color.dyn(0xDA2F46, 0xF0637A)

    // Graded deviation-heatmap ramp — sequential cool-neutral → amber, CAPPED at deep
    // amber (never red; the single strongest outlier carries a non-colour ring).
    static let devMed     = Color.dyn(0xDEE7F3, 0xF0EAE0, 1, 0.10)  // a little off
    static let devHigh    = Color.dyn(0xFFE9AC, 0xFFB703, 1, 0.30)  // clearly off your usual
    static let devOutlier = Color.dyn(0xE0820C, 0xFFC53D)           // worth noticing (+ ring)

    // Per-domain data colours (charts, rules, solid icon squares — never page chrome).
    // A7.2 saturated set; dark variants lifted for marine ground. APPROVED DEVIATION:
    // heart = rose-punch 0xD9486B (CN 2026-08-12), NOT the package's 0xE62E3D — a second
    // saturated red would collide with the red-is-clinical-glucose-only lock (RK-ALARM-01).
    // Dark rose lift 0xF07E9B verified ≥3:1 on plate (≈5.9:1).
    static let accentSleep    = Color.dyn(0x7466E1, 0x9AA0F0)   // sleep indigo
    static let accentGlucose  = Color.dyn(0x12A599, 0x53B3A9)   // glucose teal
    static let accentRecovery = Color.dyn(0x3EA1CC, 0x6FB4D4)   // recovery sea blue (solid squares need labels — 2.93:1)
    static let accentHeart    = Color.dyn(0xD9486B, 0xF07E9B)   // heart rose-punch (approved substitute)
    static let accentFinance  = Color.dyn(0x566472, 0x9FB0BE)   // slate (financial / context)

    // Fixed DfG cobalt (A7.2 letterform colour)
    static let dfgNavy = Color(hex: 0x2A4FAE)

    // Invert surface
    static let invertBG   = Color.dyn(0x2A4FAE, 0xF0EAE0)
    static let invertFG   = Color.dyn(0xFFFFFF, 0x0B1B26)
    static let invertSub  = Color.dyn(0x8C96BB, 0x4E5A66)
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
