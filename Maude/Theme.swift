// Theme.swift — Brand tokens v05 · PPCN "Day / Night" · 2026-09-07
//
// Replaces A7.2 "Electric Ink" (cool: electric paper, softened cobalt, fjord teal, marine night)
// with the PPCN Brand Design Manual v3 palette (warm: bone, ink, tan, terracotta, teal).
// Source of truth: ppcn-site/src/index.css, live in production. See design-system/PPCN_MAUDE_MANIFEST.md.
//
// THE RULE THIS FILE IS BUILT ON — the theme has TWO layers and only ONE was replaced:
//
//   BRAND    grounds, ink tiers, hairlines, accent, chrome, invert surface, typography  → PPCN v3
//   CLINICAL glucose TIR ramp, clinRed, deviation heatmap, per-domain data colours      → FROZEN
//
// The clinical layer encodes decisions recorded in qms/RISK.md, not taste:
//   · RK-ALARM-01 — red means clinical glucose and nothing else. accentHeart stays rose-punch
//     0xD9486B (CN 2026-08-12), NOT the package's 0xE62E3D, because a second saturated red
//     would collide with that lock. Unchanged here.
//   · Signals ship as shape + word + colour so meaning survives grayscale. Colour is never
//     the only channel. Unchanged here.
//   · Amber is a SIGNAL colour, never small text on a light ground (1.8:1). Unchanged here.
//   · ink4 was darkened one step from the A7.2 package value for a 3:1 floor. The PPCN value
//     below (0x8A97A5) is picked to hold ≥3:1 on the WARM ground, not the cool one.
//
// CONSEQUENCE OF THE GROUND MOVE, recorded so nobody has to rediscover it: the canvas went from
// cool 0xE9F1FA to warm 0xFAFAF8. Every clinical contrast ratio in this file was originally
// computed against the cool ground. The ratios noted inline on the CLINICAL tokens are the
// A7.2 figures and are NOT re-verified for the warm ground — that is an open task. Where one
// fails, darken the CLINICAL token; never lighten the ground.
//
// Mode raw values (`midnight`, `paper`) are PERSISTED in @AppStorage("maudeThemeMode").
// They are deliberately unchanged so no one's stored preference resets. Only the labels moved
// to the PPCN vocabulary: Night / Day.
//
// Every `MaudeTheme.*` call site recolours automatically — no per-view changes.
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
    /// Dynamic token: light = Day value, dark = Night value (with optional alphas).
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

// MARK: - MaudeTheme

enum MaudeTheme {

    // ─────────────────────────────────────────────────────────────────────
    // BRAND LAYER — PPCN v3
    // ─────────────────────────────────────────────────────────────────────

    /// Runtime theme. Resolved to a ColorScheme at the root; the dynamic tokens read that scheme.
    /// RAW VALUES ARE PERSISTED — do not rename the cases. Labels are PPCN vocabulary.
    enum Mode: String, CaseIterable, Identifiable {
        case midnight, paper
        var id: String { rawValue }
        var colorScheme: ColorScheme { self == .midnight ? .dark : .light }
        /// Day = warm-white ground · Night = graphite ground. Night is not a dimmed Day.
        var label: String { self == .midnight ? "Night" : "Day" }
    }

    // Backgrounds — warm bone by day, graphite by night
    static let paper   = Color.dyn(0xFAFAF8, 0x161B22)   // app canvas — warm-white / graphite
    static let paper2  = Color.dyn(0xFFFFFF, 0x21262D)   // card fill — white / raised graphite
    /// Sunk / grouped-row ground, one step below the canvas.
    static let surface = Color.dyn(0xF3F2EF, 0x1B2028)

    // Text / icons — PPCN ink by day, warm off-white stepped by opacity at night
    static let ink     = Color.dyn(0x0D1117, 0xFAFAF8)                 // 18.4:1 on warm-white
    static let ink2    = Color.dyn(0x2A2E33, 0xFAFAF8, 1, 0.68)        // graphite — 13.1:1
    static let ink3    = Color.dyn(0x6B7785, 0xFAFAF8, 1, 0.45)        // steel — 4.6:1, captions/kickers/inactive tabs
    /// Hint tier. 0x8A97A5 holds ≥3:1 on the warm ground (≈3.2:1) — large text and UI only.
    /// Body-size text belongs in ink3 or darker (iOS .tertiaryLabel convention).
    static let ink4    = Color.dyn(0x8A97A5, 0xFAFAF8, 1, 0.30)

    // Borders / dividers — warm hairlines
    static let line    = Color.dyn(0xE4E2DE, 0xFAFAF8, 1, 0.14)
    static let line2   = Color.dyn(0xEFEDE9, 0xFAFAF8, 1, 0.08)

    /// THE accent — PPCN teal as TEXT/BUTTONS (links, primary, positive, consent, chip label).
    /// 0x2E6E6A is 5.9:1 on white cards and 5.5:1 on the warm canvas — passes AA in both,
    /// which the A7.2 fjord teal did not (4.33:1 on canvas, cards only).
    /// Night value lifted for the graphite ground (≥4.5:1 on 0x161B22).
    static let moss    = Color.dyn(0x2E6E6A, 0x6FB5AF)
    static let moss2   = Color.dyn(0xE6EFEE, 0x2E6E6A, 1, 0.22)   // quiet fills
    static let moss3   = Color.dyn(0xC5D9D7, 0x6FB5AF, 1, 0.34)   // border tint
    static let mossRev = Color.dyn(0x6FB5AF, 0x6FB5AF)

    /// THE signature as GRAPHIC — rings, chart strokes, chip ring, solid icon squares.
    /// Tan is PPCN's most-used non-neutral and is deliberately low-contrast:
    /// NEVER text (≈1.9:1 by design). Text and buttons keep using `moss`.
    /// Solid squares in this colour REQUIRE an adjacent text label.
    static let fjordBright = Color.dyn(0xC8B59A, 0xC8B59A)
    /// Alias under the PPCN name. Prefer this at new call sites.
    static let tan = fjordBright
    /// Deep tan, for marks and borders sitting on a tan fill.
    static let bronze = Color.dyn(0x8A6A45, 0xC0A075)

    // MARK: Primary action — ONE filled treatment per mode
    //
    // THE RULE (carried over from A7.2): a primary action is a solid fill whose label is the
    // ground colour. Day = PPCN teal + white (5.9:1). Night = the warm off-white plate + ink
    // (≈15:1) — the night primary is a LIGHT fill with a dark label, which is what
    // `Done`/`Continue` already do. Filling `moss` with white at night would be 2.5:1 and
    // read as DISABLED beside a cream `Done` on a sibling sheet (design-QA 2026-08-13).
    // Treatment, not palette. Disabled primaries use primaryOffFill/primaryOffLabel so
    // "unavailable" stays visibly a different thing from "available".
    static let primaryFill     = Color.dyn(0x2E6E6A, 0xFAFAF8)
    static let primaryLabel    = invertFG                       // white · graphite
    static let primaryOffFill  = line                           // flat hairline wash
    static let primaryOffLabel = ink3
    /// Lift under a primary CTA: a teal glow by day, a plain shadow at night.
    static let primaryGlow     = Color.dyn(0x2E6E6A, 0x000000, 0.30, 0.55)

    /// Terracotta — PPCN's "this is late or breached" colour. SPARING, and never near a
    /// clinical surface: it is the deliberate stand-in for a brand red, so that red can
    /// stay locked to glucose (RK-ALARM-01). Overdue day-counts, cap breaches, expiries.
    static let terracotta  = Color.dyn(0xD4622F, 0xE8834F)
    static let terracotta2 = Color.dyn(0xF9EDE6, 0xD4622F, 1, 0.18)

    /// Blue — links and the personal lane / commitment markers.
    static let personalBlue = Color.dyn(0x3563E9, 0x8BA3FF)
    /// Slate — muted informational chrome.
    static let slateBlue    = Color.dyn(0x46586B, 0x9FB0BE)
    /// Infrastructure and system-state labels. NOT clinical green — never a health signal.
    static let infraGreen   = Color.dyn(0x5A6E55, 0x9CB396)

    // ─────────────────────────────────────────────────────────────────────
    // SIGNAL LAYER — unchanged. Amber is a signal colour, never small text.
    // ─────────────────────────────────────────────────────────────────────

    // Amber — ONLY the earned attention card (fill/border/dot; words stay ink).
    // DELIBERATELY MODE-SPLIT: light = 0xFFC533, dark/watch stays 0xFFB703 — a grep seeing
    // "inconsistent" amber is seeing the spec, not a bug. Light amber aliases tirHigh exactly
    // — accepted with the RISK renewal (PR-105).
    static let amber   = Color.dyn(0xFFC533, 0xFFB703)
    static let amber2  = Color.dyn(0xFFF3D1, 0xFFB703, 1, 0.16)

    // Refusals / boundary events — the clinical red family (text-safe on light)
    static let rust    = Color.dyn(0xC13B34, 0xEE9089)
    static let rust2   = Color.dyn(0xF8E7E5, 0xC13B34, 1, 0.20)

    // "Worth noticing" attention tone — amber (earned-attention card; same mode-split as `amber`).
    static let clay     = Color.dyn(0xFFC533, 0xFFB703)            // amber signal
    static let clay2    = Color.dyn(0xFFF3D1, 0xFFB703, 1, 0.16)   // tint fill
    static let clay3    = Color.dyn(0xF5E5AC, 0xFFB703, 1, 0.34)   // border tint
    static let clayText = Color.dyn(0x0D1117, 0xFFB703)            // words are ink on light (PPCN ink on amber2 ≈ 15:1)
    static let clayRev  = Color.dyn(0xFFC533, 0xFFB703)

    /// Brass — consent / witness moments ONLY. Now PPCN bronze, which is the same idea in
    /// the house palette: a quiet frame that reads as ceremony rather than alarm.
    static let brass   = Color.dyn(0x8A6A45, 0xC0A075)
    static let brass2  = Color.dyn(0xF4EDDF, 0xC0A075, 1, 0.16)

    // Confidence ramp — the trust mechanism. Derives from the accent, so it follows the brand.
    static let confHigh     = moss
    static let confEmerging = clay
    static let confLearning = ink4

    // Chrome hooks
    static let gridEmpty     = Color.dyn(0xEFEDE9, 0xFAFAF8, 1, 0.08)
    static let heroGlow      = Color.dyn(0xC8B59A, 0x6FB5AF, 0.22, 0.24)
    static let homeIndicator = Color.dyn(0x0D1117, 0xFAFAF8, 0.26, 0.34)
    static let cardShadow    = Color.dyn(0x0D1117, 0x000000, 0.08, 0.44)

    // ─────────────────────────────────────────────────────────────────────
    // CLINICAL LAYER — FROZEN. Do not retune for the brand.
    // Contrast figures below are the A7.2 values, computed against the COOL ground and the
    // marine plate. They are NOT re-verified for the warm ground / graphite plate. Open task.
    // ─────────────────────────────────────────────────────────────────────

    // Clinical glucose Time-in-Range scale — colour-safety ramp (CN-approved 2026-08-12,
    // qms/RISK.md PR-105). Scoped to GLUCOSE charts ONLY. Bands are NEVER colour-alone:
    // very-low renders with a HATCH overlay, very-high with DOTS, and every band carries an
    // in-chart text label (chart-side, OuraComponents).
    static let tirVeryLow  = Color.dyn(0x6A1B4D, 0xA85E93)   // < 3.0 mmol/L  L2 hypo (plum + hatch)
    static let tirLow      = Color.dyn(0xE8556D, 0xF08CA0)   // 3.0–3.8       L1 hypo (warm red-rose)
    static let tirTarget   = Color.dyn(0x00CC63, 0x4FE08F)   // 3.9–10.0      TARGET (clinical green)
    static let tirHigh     = Color.dyn(0xFFC533, 0xFFD76B)   // 10.1–13.9     L1 hyper (amber)
    static let tirVeryHigh = Color.dyn(0xB5561E, 0xD97E45)   // > 13.9        L2 hyper (sienna + dots)
    /// Clinical out-of-range MARK — glucose charts ONLY (RK-ALARM-01): the out-of-range
    /// re-stroke + peak annotation on the day curve and the excursion caps on the week bars.
    /// NEVER an accent, border, or text outside the glucose clinical charts. Always paired
    /// with a non-colour signal (position outside the labelled band + worded annotation).
    static let clinRed     = Color.dyn(0xDA2F46, 0xF0637A)

    // Graded deviation-heatmap ramp — sequential neutral → amber, CAPPED at deep amber
    // (never red; the single strongest outlier carries a non-colour ring). Severity must read
    // the same in both modes: the dark outlier is the SAME orange lifted one step, not a
    // brighter yellow, so a cell never reads as a milder concern at night.
    static let devMed     = Color.dyn(0xEAE8E3, 0xFAFAF8, 1, 0.10)  // a little off
    static let devHigh    = Color.dyn(0xFFE9AC, 0xFFB703, 1, 0.30)  // clearly off your usual
    static let devOutlier = Color.dyn(0xE0820C, 0xF08C1E)           // worth noticing (+ ring)

    // Per-domain data colours (charts, rules, solid icon squares — never page chrome).
    // APPROVED DEVIATION: heart = rose-punch 0xD9486B (CN 2026-08-12), NOT 0xE62E3D — a second
    // saturated red would collide with the red-is-clinical-glucose-only lock (RK-ALARM-01).
    static let accentSleep    = Color.dyn(0x7466E1, 0x9AA0F0)   // sleep indigo
    static let accentGlucose  = Color.dyn(0x12A599, 0x53B3A9)   // glucose teal
    static let accentRecovery = Color.dyn(0x3EA1CC, 0x6FB4D4)   // recovery sea blue (solid squares need labels)
    static let accentHeart    = Color.dyn(0xD9486B, 0xF07E9B)   // heart rose-punch (approved substitute)
    static let accentFinance  = Color.dyn(0x46586B, 0x9FB0BE)   // PPCN slate-blue (financial / context)

    // ─────────────────────────────────────────────────────────────────────

    /// Neutral tile colour for partner/wallet letterform tiles.
    /// Was `dfgNavy` (A7.2 DfG cobalt) — renamed because a PPCN app must not carry a token
    /// named for another organisation. See DFG_SEPARATION.md.
    static let partnerTile = Color(hex: 0x2A2E33)

    // Invert surface
    static let invertBG   = Color.dyn(0x0D1117, 0xFAFAF8)
    static let invertFG   = Color.dyn(0xFFFFFF, 0x161B22)
    static let invertSub  = Color.dyn(0x8A97A5, 0x5A636D)
    static let invertLine = Color.dyn(0xFFFFFF, 0x161B22, 0.12, 0.12)

    enum Radius { static let card: CGFloat = 18; static let hero: CGFloat = 22; static let vitals: CGFloat = 22 }

    /// Letter-spacing. Apply with `.tracking(_:)`.
    ///
    /// SwiftUI tracking is absolute points, the web's is em — so a fixed constant only looks
    /// right at one size. The `display(_:)` / `heading(_:)` helpers take the point size and
    /// return the site's em value scaled to it. The bare constants are kept because ~120 call
    /// sites already pass them; they are the correct values at the sizes those sites use.
    enum Tracking {
        /// ppcn.xyz h1: −0.028em. Tight. At 30pt = −0.84, at 56pt = −1.57.
        static func display(_ size: CGFloat) -> CGFloat { -0.028 * size }
        /// ppcn.xyz pull-quote: −0.015em.
        static func heading(_ size: CGFloat) -> CGFloat { -0.015 * size }
        /// Terracotta kicker rail: +0.18em uppercase. At 10pt = +1.8.
        static func kickerAt(_ size: CGFloat) -> CGFloat { 0.18 * size }
        /// Mono meta column (§ numbers, dates): +0.14em uppercase.
        static func metaAt(_ size: CGFloat) -> CGFloat { 0.14 * size }

        static let h1: CGFloat = -0.84      // display(30)
        static let h2: CGFloat = -0.30      // heading(20)
        static let kicker: CGFloat = 1.8    // kickerAt(10)
        static let meta: CGFloat = 1.4      // metaAt(10)
        static let wordmark: CGFloat = -0.4
    }

    /// Editorial furniture from ppcn.xyz. These are the site's signatures, not decoration:
    /// a kicker is a short terracotta hairline followed by mono uppercase; a section opens
    /// with a § number in the meta tier; a pull-quote sits under a short thick terracotta rule.
    enum Rule {
        /// Hairline before a kicker — 1pt × 32pt, terracotta.
        static let kickerWidth: CGFloat = 32
        static let kickerHeight: CGFloat = 1
        /// Emphasis rule above a verdict — 2pt × 56pt, terracotta.
        static let verdictWidth: CGFloat = 56
        static let verdictHeight: CGFloat = 2
    }

    /// The hero ground: warm-white with a soft tan bloom off-centre.
    /// ppcn.xyz — radial-gradient(circle at 78% 22%, rgba(200,181,154,0.18), transparent 55%).
    static var heroGround: RadialGradient {
        RadialGradient(
            colors: [Color(hex: 0xC8B59A).opacity(0.18), Color(hex: 0xC8B59A).opacity(0)],
            center: UnitPoint(x: 0.78, y: 0.22),
            startRadius: 0,
            endRadius: 420
        )
    }
}

// MARK: - Font helpers — Outfit display · SF Pro body · JetBrains Mono numerals
//
// PPCN v3 type stack. Outfit and JetBrains Mono ship as static instances in Maude/Fonts/,
// generated from the Google Fonts variable masters at fixed weights — the variable master's
// default instance is Thin, so loading it directly would render every headline hairline.
// Both are registered in Info.plist ▸ UIAppFonts.
//
// Every face resolves through `scaledCustom`, which falls back to the system face if the font
// is missing from the bundle. A missing Outfit degrades to SF Pro semibold — still the PPCN
// direction (sans display), just without the personality. Charter serif verdicts are RETIRED:
// PPCN's display voice is sans.

extension Font {
    /// Kicker — 11px-class sans, bold, tracked uppercase (the only all-caps).
    /// Call sites keep applying Tracking.kicker.
    static func maudeKicker(_ size: CGFloat = 10) -> Font {
        scaledSystem(size, .bold, .caption2)
    }
    /// Numeric face — JetBrains Mono, tabular by construction so figures align in a column.
    /// Falls back to SF with monospaced digits.
    static func maudeMono(_ size: CGFloat = 14) -> Font {
        scaledCustom("JetBrainsMono-Medium", size, .medium, .footnote)
            ?? scaledSystem(size, .medium, .footnote).monospacedDigit()
    }
    /// Verdicts / headlines — Outfit. Sentence case. The PPCN display voice.
    /// Name kept as `maudeSerif` so all 115 call sites keep compiling; it is no longer a serif.
    static func maudeSerif(_ size: CGFloat, _ weight: Font.Weight = .bold,
                            relativeTo style: UIFont.TextStyle = .title3) -> Font {
        scaledDisplay(size, weight, style)
    }
    /// Headlines/body use the system face (SF Pro), scaled with the user's iOS text-size
    /// setting via UIFontMetrics. `.system(size:)` / `.custom(_:size:)` WITHOUT `relativeTo:`
    /// never scale — that omission was FB-AEkAWxal ("changed text size and it did not
    /// change"). All ~566 call sites scale from here.
    static func lato(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        scaledSystem(size, weight, .body)
    }
    static var maudeH1: Font { scaledDisplay(30, .bold, .largeTitle) }
    static var maudeH2: Font { scaledDisplay(20, .bold, .title3) }
    static var maudeBody: Font { scaledSystem(15, .regular, .subheadline) }
    static var maudeCaption: Font { scaledSystem(12, .regular, .caption1) }

    /// A system font at `size`/`weight` that grows/shrinks with Dynamic Type, anchored to
    /// `style`. UIFontMetrics scales from the Large default, so the default text size looks
    /// identical to before — only non-default sizes change.
    private static func scaledSystem(_ size: CGFloat, _ weight: Font.Weight,
                                     _ style: UIFont.TextStyle = .body) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight.uiKit)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    /// A bundled face by PostScript name, Dynamic-Type-scaled. Returns nil when the font is
    /// not in the bundle so callers can fall back rather than silently rendering the system
    /// face at the wrong weight.
    private static func scaledCustom(_ name: String, _ size: CGFloat, _ weight: Font.Weight,
                                     _ style: UIFont.TextStyle) -> Font? {
        guard let f = UIFont(name: name, size: size) else { return nil }
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: f))
    }

    /// Outfit at the nearest shipped weight, Dynamic-Type-scaled, falling back to SF Pro.
    /// Only three weights are bundled — Medium 500, SemiBold 600, Bold 700 — because those
    /// are the only ones the display scale uses. Anything lighter belongs in the body face.
    private static func scaledDisplay(_ size: CGFloat, _ weight: Font.Weight,
                                      _ style: UIFont.TextStyle) -> Font {
        let name: String
        switch weight {
        case .black, .heavy, .bold: name = "Outfit-Bold"
        case .semibold:             name = "Outfit-SemiBold"
        default:                    name = "Outfit-Medium"
        }
        return scaledCustom(name, size, weight, style)
            ?? scaledSystem(size, weight == .regular ? .semibold : weight, style)
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
