// WatchTheme.swift — Liviqa watch palette. Tokens lifted verbatim from the Liviqa
// design system (design-system/tokens/colors.css + signals.css, A6 "Daylight") at
// the DARK / Midnight resolution — the wrist mirrors the phone's dark mode.
// Self-contained (no UIKit dynamic provider) so it compiles cleanly on watchOS.
// Two-state colour like the phone: in-range = Frosted Blue (NO green hue),
// "worth noticing" = Amber Flame. Amber-on-navy is sanctioned (7:1); never on white.
import SwiftUI

enum WatchTheme {
    static let bg     = Color(red: 0x15/255, green: 0x24/255, blue: 0x3D/255) // Navy canvas (Theme.paper · dark)
    static let card   = Color(red: 0x1D/255, green: 0x35/255, blue: 0x57/255) // Oxford Navy card (Theme.paper2 · dark)
    static let ink    = Color(red: 0xF1/255, green: 0xFA/255, blue: 0xEE/255) // Honeydew — primary text
    static let ink2   = Color(red: 0xC9/255, green: 0xD8/255, blue: 0xE5/255) // body
    static let ink3   = Color(red: 0x8D/255, green: 0xA4/255, blue: 0xBC/255) // captions / kickers
    static let moss   = Color(red: 0xA8/255, green: 0xDA/255, blue: 0xDC/255) // Frosted Blue — in range (NOT green)
    static let clay   = Color(red: 0xFF/255, green: 0xB7/255, blue: 0x03/255) // Amber Flame — worth noticing
    static let line   = Color.white.opacity(0.10)                             // hairline on navy
}
