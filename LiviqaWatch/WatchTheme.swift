// WatchTheme.swift — Liviqa watch palette (locked brand, Midnight on the wrist).
// Self-contained (no UIKit dynamic-provider) so it compiles cleanly on watchOS.
// Two-state colour like the phone: moss = in your range, clay = worth noticing.
import SwiftUI

enum WatchTheme {
    static let bg     = Color(red: 0x0B/255, green: 0x13/255, blue: 0x20/255) // ink/Midnight
    static let card   = Color(red: 0x14/255, green: 0x20/255, blue: 0x2E/255)
    static let ink    = Color(red: 0xF5/255, green: 0xF2/255, blue: 0xEA/255) // paper text
    static let ink2   = Color(red: 0xCC/255, green: 0xD5/255, blue: 0xE0/255)
    static let ink3   = Color(red: 0x8A/255, green: 0x98/255, blue: 0xAD/255)
    static let moss   = Color(red: 0x5C/255, green: 0xB3/255, blue: 0x89/255) // in range
    static let clay   = Color(red: 0xD0/255, green: 0x8A/255, blue: 0x3E/255) // worth noticing
    static let line   = Color.white.opacity(0.09)
}
