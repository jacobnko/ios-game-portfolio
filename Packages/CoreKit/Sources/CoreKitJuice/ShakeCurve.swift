// Decaying oscillation used to shake the screen on impact.

import Foundation
import CoreGraphics

/// Screen shake as a pure function of time.
///
/// Kept separate from any view so the curve can be verified — in particular that it
/// returns to exactly zero, which a naive `exp` decay never does. A view left with a
/// fraction of a point of offset stays subtly misaligned for the rest of the session.
public struct ShakeCurve: Sendable, Equatable {
    /// Peak displacement in points.
    public let amplitude: CGFloat
    public let duration: TimeInterval
    /// Oscillations per second.
    public let frequency: Double

    public init(amplitude: CGFloat = 9, duration: TimeInterval = 0.35, frequency: Double = 11) {
        self.amplitude = max(0, amplitude)
        self.duration = max(0, duration)
        self.frequency = max(0, frequency)
    }

    /// Offset to apply at `time` seconds after the shake began.
    public func offset(at time: TimeInterval) -> CGSize {
        guard duration > 0, time >= 0, time < duration else { return .zero }

        // Quadratic falloff reaches exactly zero at the end, unlike exponential decay.
        let progress = time / duration
        let envelope = pow(1 - progress, 2)

        let angle = 2 * Double.pi * frequency * time
        let x = Double(amplitude) * envelope * sin(angle)
        // A different frequency and phase on Y keeps the motion from collapsing
        // into a straight diagonal line, which reads as a glitch rather than an impact.
        let y = Double(amplitude) * envelope * 0.6 * sin(angle * 1.37 + 1.1)

        return CGSize(width: x, height: y)
    }
}
