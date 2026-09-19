// Decaying oscillation used to shake the screen on impact.

import Foundation
import CoreGraphics

/// Screen shake as a pure function of time.
///
/// Kept separate from any view so the curve can be verified — in particular that it
/// returns to exactly zero, which a naive `exp` decay never does. A view left with a
/// fraction of a point of offset stays subtly misaligned for the rest of the session.
///
/// Follows D5's `offset(t) = A · e^(−t/τ) · cos(2πft)`: exponential decay rather
/// than the quadratic falloff this used before, which reads as a softer, slower
/// settle than a real impact. `amplitude` is the primary (vertical) axis; the
/// horizontal one rides at `lateralRatio` of it on a different phase, so the two
/// axes don't collapse into one straight diagonal line — an impact reads as a
/// jolt, a perfectly correlated X/Y reads as a glitch.
public struct ShakeCurve: Sendable, Equatable {
    /// Peak displacement in points, on the primary (vertical) axis.
    public let amplitude: CGFloat
    public let duration: TimeInterval
    /// Oscillations per second.
    public let frequency: Double
    /// Exponential decay constant, in seconds — smaller decays faster.
    public let tau: TimeInterval
    /// Horizontal amplitude as a fraction of `amplitude`. D5: 40%.
    public let lateralRatio: Double

    public init(
        amplitude: CGFloat = 6,
        duration: TimeInterval = 0.42,
        frequency: Double = 26,
        tau: TimeInterval = 0.11,
        lateralRatio: Double = 0.4
    ) {
        self.amplitude = max(0, amplitude)
        self.duration = max(0, duration)
        self.frequency = max(0, frequency)
        self.tau = max(0.001, tau)
        self.lateralRatio = max(0, lateralRatio)
    }

    /// Offset to apply at `time` seconds after the shake began.
    public func offset(at time: TimeInterval) -> CGSize {
        guard duration > 0, time >= 0, time < duration else { return .zero }

        let envelope = exp(-time / tau)
        let angle = 2 * Double.pi * frequency * time

        let y = Double(amplitude) * envelope * cos(angle)
        // A different frequency multiplier and phase on X keeps the motion from
        // collapsing into a straight line through the origin, which a shared
        // phase would produce even with a smaller X amplitude.
        let x = Double(amplitude) * lateralRatio * envelope * cos(angle * 1.37 + 1.1)

        return CGSize(width: x, height: y)
    }
}
