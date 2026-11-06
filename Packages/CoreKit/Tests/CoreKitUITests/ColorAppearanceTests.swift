// Checks an appearance-following colour resolves to its light half in light mode and its dark half otherwise.

import Testing
import SwiftUI
@testable import CoreKitUI

// AppKit resolves a dynamic colour on the main thread; off it the lookup stalls.
@MainActor
private func resolved(_ color: Color, _ scheme: ColorScheme) -> Color.Resolved {
    var environment = EnvironmentValues()
    environment.colorScheme = scheme
    return color.resolve(in: environment)
}

@MainActor
@Test func anAdaptiveColourFollowsTheAppearance() {
    let color = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x000000))
    #expect(resolved(color, .light).red > 0.99 && resolved(color, .light).blue > 0.99)
    #expect(resolved(color, .dark).red < 0.01 && resolved(color, .dark).green < 0.01)
}

@MainActor
@Test func aThemeColourPairBecomesOneAdaptiveColour() {
    let pair = ThemeColor(light: Color(hex: 0xFF0000), dark: Color(hex: 0x0000FF))
    #expect(resolved(pair.adaptive, .light).red > 0.99 && resolved(pair.adaptive, .light).blue < 0.01)
    #expect(resolved(pair.adaptive, .dark).blue > 0.99 && resolved(pair.adaptive, .dark).red < 0.01)
}
