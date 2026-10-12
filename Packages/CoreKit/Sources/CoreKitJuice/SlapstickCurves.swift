// Cartoon motion curves for failure gags: refuse, sigh, sink, land, roll in, tip over.

import Foundation
import CoreGraphics

// Every curve here is a pure function of progress (0...1) or elapsed time, unit-agnostic
// (pass points, or a fraction of the board and scale afterwards), and returns *exactly*
// its rest value at both ends. A failure gag that leaves a view 0.3pt off or 0.1° tilted
// shows up as a misaligned board on the next attempt — the same reason `ShakeCurve`
// lands on zero.
//
// The register is slapstick on purpose (CLAUDE.md §6): things wobble, deflate, flop and
// bounce. Nothing here models breaking apart violently, and nothing flashes.

/// A decaying side-to-side "no" — a piece shaking its head because it has nowhere to go.
///
/// Slower and wider than `ShakeCurve`: a screen shake is an impact, this is a gesture,
/// so it must be slow enough to read as a number of distinct swings.
public struct WobbleCurve: Sendable, Equatable {
    /// Peak displacement on the first swing.
    public let amplitude: CGFloat
    /// Full left-right cycles across the duration.
    public let swings: Int
    public let duration: TimeInterval

    public init(amplitude: CGFloat, swings: Int = 3, duration: TimeInterval) {
        self.amplitude = max(0, amplitude)
        self.swings = max(1, swings)
        self.duration = max(0, duration)
    }

    /// Horizontal offset `time` seconds after this wobble began.
    public func offset(at time: TimeInterval) -> CGFloat {
        guard duration > 0, time > 0, time < duration else { return 0 }
        let p = time / duration
        // A linear envelope reaches exactly zero at the end, where an exponential never does.
        return amplitude * CGFloat((1 - p) * sin(2 * .pi * Double(swings) * p))
    }

    /// Start time of item `index` when several wobble in a ripple, `stagger` seconds apart.
    public static func startTime(forIndex index: Int, stagger: TimeInterval) -> TimeInterval {
        TimeInterval(max(0, index)) * max(0, stagger)
    }
}

/// A sigh: the object squashes down and spreads, then lets the squash go.
///
/// Apply with `scaleEffect(_, anchor: .bottom)` so it slumps onto whatever it sits on
/// rather than shrinking toward its own centre.
public struct SquashCurve: Sendable, Equatable {
    /// Horizontal scale at full squash, typically a little above 1.
    public let squashX: CGFloat
    /// Vertical scale at full squash, typically a little below 1.
    public let squashY: CGFloat

    public init(squashX: CGFloat, squashY: CGFloat) {
        self.squashX = max(0, squashX)
        self.squashY = max(0, squashY)
    }

    /// Scale while squashing; `progress` 0 is at rest, 1 is fully squashed.
    public func squashing(progress: Double) -> CGSize {
        // Ease out: the air leaves fast and the last of it slowly, like a sigh.
        scale(amount: 1 - pow(1 - clampUnit(progress), 2))
    }

    /// Scale while releasing; `progress` 0 is fully squashed, 1 is back at rest.
    public func releasing(progress: Double) -> CGSize {
        let p = clampUnit(progress)
        // Smoothstep so the release has no visible kink at either end.
        return scale(amount: 1 - p * p * (3 - 2 * p))
    }

    private func scale(amount: Double) -> CGSize {
        CGSize(
            width: 1 + (squashX - 1) * CGFloat(amount),
            height: 1 + (squashY - 1) * CGFloat(amount)
        )
    }
}

/// A limp collapse: the object drops and tilts, gathering speed like something giving up,
/// then bounces once where it lands.
public struct SinkCurve: Sendable, Equatable {
    /// How far it drops by the end of the sink (positive is down).
    public let drop: CGFloat
    /// Rotation reached at the end of the sink, in degrees.
    public let tiltDegrees: Double
    /// Height of the single bounce after landing.
    public let bounceHeight: CGFloat
    public let bounceDuration: TimeInterval

    public init(drop: CGFloat, tiltDegrees: Double, bounceHeight: CGFloat = 0, bounceDuration: TimeInterval = 0) {
        self.drop = drop
        self.tiltDegrees = tiltDegrees
        self.bounceHeight = max(0, bounceHeight)
        self.bounceDuration = max(0, bounceDuration)
    }

    /// Vertical offset during the sink. Ease-in quad: it starts reluctantly and ends falling.
    public func offset(progress: Double) -> CGFloat {
        drop * CGFloat(easeInQuad(progress))
    }

    public func rotationDegrees(progress: Double) -> Double {
        tiltDegrees * easeInQuad(progress)
    }

    /// Extra vertical offset `time` seconds after landing — up (negative) and back down.
    ///
    /// Added on top of the final `offset(progress: 1)`, so the object rests exactly
    /// where it landed once the bounce ends.
    public func bounce(at time: TimeInterval) -> CGFloat {
        guard bounceDuration > 0, time > 0, time < bounceDuration else { return 0 }
        return -bounceHeight * CGFloat(sin(.pi * time / bounceDuration))
    }

    private func easeInQuad(_ progress: Double) -> Double {
        let p = clampUnit(progress)
        return p * p
    }
}

/// The button on the gag: a small piece rolls in, slows to a stop, and tips over.
///
/// Decelerates uniformly, so the entry speed follows from distance and time — expose
/// it so a spec that states a speed can be checked against the numbers actually used.
public struct RollInCurve: Sendable, Equatable {
    /// Distance covered from entry to rest (positive is toward the rest point).
    public let travel: CGFloat
    public let rollDuration: TimeInterval
    /// The piece's radius, which turns distance into roll angle.
    public let radius: CGFloat
    /// How far it tips once stopped, in degrees.
    public let toppleDegrees: Double
    public let toppleDuration: TimeInterval

    public init(travel: CGFloat, rollDuration: TimeInterval, radius: CGFloat, toppleDegrees: Double = 90, toppleDuration: TimeInterval = 0.15) {
        self.travel = travel
        self.rollDuration = max(0.001, rollDuration)
        self.radius = max(0.001, radius)
        self.toppleDegrees = toppleDegrees
        self.toppleDuration = max(0, toppleDuration)
    }

    /// Speed on entry, in travel units per second, for uniform deceleration to zero.
    public var entrySpeed: CGFloat {
        2 * travel / CGFloat(rollDuration)
    }

    public var totalDuration: TimeInterval { rollDuration + toppleDuration }

    /// Distance covered from the entry point `time` seconds in. Reaches `travel` and stays.
    public func distance(at time: TimeInterval) -> CGFloat {
        let p = clampUnit(time / rollDuration)
        return travel * CGFloat(1 - (1 - p) * (1 - p))
    }

    /// Rotation in degrees: rolling without slipping, then the tip-over on top.
    ///
    /// Rolling toward negative x (entering from the right) turns counter-clockwise,
    /// which in SwiftUI's y-down space is a negative angle.
    public func rotationDegrees(at time: TimeInterval) -> Double {
        let rolled = -Double(distance(at: time) / radius) * 180 / .pi
        guard time > rollDuration, toppleDuration > 0 else { return rolled }
        // Ease in: it teeters, then flops.
        let p = clampUnit((time - rollDuration) / toppleDuration)
        return rolled - toppleDegrees * p * p
    }
}

private func clampUnit(_ value: Double) -> Double {
    min(1, max(0, value))
}
