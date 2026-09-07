// WatchTheme.swift — Maude watch palette · A7.2 "Evening Edition" (2026-08-12, PR-105).
// The wrist mirrors the phone's dark mode: marine ground, plate cards, warm off-white
// ink stepped by opacity, lifted fjord teal for in-range/positive. Replaces the A6
// "Daylight" navy/honeydew/Frosted-Blue block wholesale (§6 of the A7.2 migration).
// Self-contained (no UIKit dynamic provider) so it compiles cleanly on watchOS.
// Two-state colour like the phone: in-range = lifted fjord teal, "worth noticing" =
// amber 0xFFB703 (the dark amber — deliberately unchanged; amber is mode-split on
// the phone but the watch only has the dark face). Amber-on-marine ≥7:1; never text.
import SwiftUI

enum WatchTheme {
    static let bg     = Color(red: 0x0B/255, green: 0x1B/255, blue: 0x26/255) // Marine canvas (Theme.paper · dark)
    static let card   = Color(red: 0x13/255, green: 0x29/255, blue: 0x3B/255) // Plate card (Theme.paper2 · dark)
    static let ink    = Color(red: 0xF2/255, green: 0xED/255, blue: 0xE4/255) // Warm off-white — primary text
    static let ink2   = Color(red: 0xF2/255, green: 0xED/255, blue: 0xE4/255).opacity(0.72) // body
    static let ink3   = Color(red: 0xF2/255, green: 0xED/255, blue: 0xE4/255).opacity(0.48) // captions / kickers
    static let moss   = Color(red: 0x5F/255, green: 0xB3/255, blue: 0xAC/255) // Lifted fjord teal — in range / positive
    static let clay   = Color(red: 0xFF/255, green: 0xB7/255, blue: 0x03/255) // Amber — worth noticing (dark amber, unchanged)
    static let line   = Color.white.opacity(0.13)                             // hairline on marine
}
