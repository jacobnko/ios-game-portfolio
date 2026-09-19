// Connects a game's visual identity to the shared juice layer.

import SwiftUI
import CoreKitJuice

public extension GameTheme {
    /// A victory payoff drawn in this game's colours.
    ///
    /// Timing and physics stay shared so every game feels like the same hand made
    /// it; only the palette and the seed change, so no two bursts look alike.
    func victoryConfiguration(
        multiplier: Int = 1,
        origins: [CGPoint] = [CGPoint(x: 0.5, y: 0.55)],
        seed: UInt64 = 0x5EED,
        particleCount: Int = 90,
        // Defaults to the theme's three-colour burst; a game whose burst
        // origins map to something more specific (Chordline's own pipes, say)
        // can pass a palette ordered to match `origins` 1:1 instead.
        palette: [Color]? = nil,
        scrimColor: Color? = nil
    ) -> VictoryConfiguration {
        VictoryConfiguration(
            multiplier: multiplier,
            origins: origins,
            particleCount: particleCount,
            palette: palette ?? self.palette.burstColors,
            seed: seed,
            scrimColor: scrimColor ?? self.palette.background.resolved(for: .dark)
        )
    }
}
