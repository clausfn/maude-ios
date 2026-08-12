// LiviqaWidgetBundle.swift — the iOS Widget Extension entry point.
//
// TARGET MEMBERSHIP: the **Liviqa Widgets** iOS Widget Extension target only.
// This carries the `@main`, so the Xcode-generated template widget file MUST be
// deleted or the extension will have two entry points (SETUP.md §3).
import WidgetKit
import SwiftUI

@main
struct LiviqaWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiviqaEditionWidget()
    }
}
