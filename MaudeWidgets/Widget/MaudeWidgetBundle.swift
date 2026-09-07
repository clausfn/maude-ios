// MaudeWidgetBundle.swift — the iOS Widget Extension entry point.
//
// TARGET MEMBERSHIP: the **Maude Widgets** iOS Widget Extension target only.
// This carries the `@main`, so the Xcode-generated template widget file MUST be
// deleted or the extension will have two entry points (SETUP.md §3).
import WidgetKit
import SwiftUI

@main
struct MaudeWidgetBundle: WidgetBundle {
    var body: some Widget {
        MaudeEditionWidget()
    }
}
