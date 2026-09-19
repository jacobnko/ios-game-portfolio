// The white flash and scale punch that fire the instant a board is solved.

import Foundation

/// D5's "ignite" moment: the board's own colour is replaced by white for a beat,
/// then eases back, while the board itself punches slightly larger and settles.
///
/// A payoff that only shakes and sprays particles is missing the part a player
/// actually reads as "something happened right now" — the flash is what makes
/// the shake and the burst feel like they were caused by something, rather than
/// simply starting.
public struct BloomCurve: Sendable, Equatable {
    /// Window where the flash sits at full white, before it starts decaying.
    public let igniteStart: TimeInterval
    public let igniteEnd: TimeInterval
    /// How long the ease back to the board's own colour takes, after `igniteEnd`.
    public let decay: TimeInterval
    /// Peak scale at `igniteStart`.
    public let scalePunch: Double
    /// Absolute time the scale is back to 1.0.
    public let scaleSettle: TimeInterval

    public init(
        igniteStart: TimeInterval = 0.080,
        igniteEnd: TimeInterval = 0.120,
        decay: TimeInterval = 0.220,
        scalePunch: Double = 1.03,
        scaleSettle: TimeInterval = 0.240
    ) {
        self.igniteStart = max(0, igniteStart)
        self.igniteEnd = max(self.igniteStart, igniteEnd)
        self.decay = max(0, decay)
        self.scalePunch = max(1, scalePunch)
        self.scaleSettle = max(self.igniteStart, scaleSettle)
    }

    public static let standard = BloomCurve()

    /// Strength of the white overlay at `time`, 0...1. Full white through the
    /// ignite window, then an ease-out cubic fade back to nothing.
    public func whiteness(at time: TimeInterval) -> Double {
        if time < igniteStart { return 0 }
        if time <= igniteEnd { return 1 }
        guard decay > 0 else { return 0 }
        let progress = (time - igniteEnd) / decay
        guard progress < 1 else { return 0 }
        return pow(1 - progress, 3)
    }

    /// Scale factor at `time` — jumps to `scalePunch` the instant the flash
    /// starts, then eases back down to 1 by `scaleSettle`.
    public func scale(at time: TimeInterval) -> Double {
        if time < igniteStart || time >= scaleSettle { return 1 }
        let span = scaleSettle - igniteStart
        guard span > 0 else { return 1 }
        let progress = (time - igniteStart) / span
        return 1 + (scalePunch - 1) * pow(1 - progress, 2)
    }
}
