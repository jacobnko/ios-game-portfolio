// Turns the hex values a design handoff produces into SwiftUI colours.

import SwiftUI

public extension Color {
    /// Builds an opaque sRGB colour from a `0xRRGGBB` literal.
    ///
    /// Every D1 design card hands back hex, so this is the one conversion each
    /// game's palette needs. It takes an integer rather than a string on purpose:
    /// `Color(hex: 0x1FE3CF)` cannot be malformed, so there is no parse failure to
    /// swallow and no silently-black fallback to debug later.
    init(hex: UInt32) {
        let components = Color.sRGBComponents(hex: hex)
        self.init(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: 1
        )
    }

    /// Splits `0xRRGGBB` into unit sRGB components.
    ///
    /// Separate from the initialiser so the bit arithmetic — the only part that can
    /// actually be wrong — is reachable from a test. `Color` exposes no way to read
    /// its components back on every platform, so testing through the initialiser
    /// would test nothing.
    internal static func sRGBComponents(hex: UInt32) -> (red: Double, green: Double, blue: Double) {
        (
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
