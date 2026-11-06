// Builds one colour that follows the system appearance, so a palette of static tokens needs no environment lookup.

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension Color {
    /// A colour that is `light` under the light appearance and `dark` otherwise.
    ///
    /// `ThemeColor.resolved(for:)` needs the view's `colorScheme`; a game that reads its
    /// palette as static tokens from a hundred call sites uses this instead. An unspecified
    /// appearance counts as dark, so a game drawn dark until now keeps its look there.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        let light = UIColor(light), dark = UIColor(dark)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .light ? light : dark })
        #elseif canImport(AppKit)
        let light = NSColor(light), dark = NSColor(dark)
        self.init(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .aqua ? light : dark })
        #endif
    }
}

public extension ThemeColor {
    /// The pair as one colour that follows the system appearance (`Color(light:dark:)`).
    var adaptive: Color { Color(light: light, dark: dark) }
}
