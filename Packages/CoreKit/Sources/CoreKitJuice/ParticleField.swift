// Deterministic particle burst maths, independent of any renderer.

import Foundation
import CoreGraphics

/// One particle of a victory burst.
///
/// Positions are in unit space (0...1 across the view) so the same burst works at
/// any screen size without rescaling velocities.
public struct Particle: Sendable, Equatable {
    public let origin: CGPoint
    public let velocity: CGVector
    public let birth: TimeInterval
    public let lifetime: TimeInterval
    public let size: CGFloat
    /// Index into the caller's palette, so colour choice stays a game decision.
    public let colorIndex: Int
}

/// Generates and advances a burst.
///
/// Deterministic for a given seed on purpose: a burst that looks different every run
/// cannot be reviewed, tuned, or reproduced in a bug report.
public enum ParticleField {
    /// Downward pull in unit-space per second squared.
    public static let defaultGravity: Double = 0.85

    public static func make(
        count: Int,
        origins: [CGPoint],
        seed: UInt64 = 0x5EED,
        paletteSize: Int = 3,
        speedRange: ClosedRange<Double> = 0.25...0.95,
        lifetimeRange: ClosedRange<TimeInterval> = 0.45...0.95,
        sizeRange: ClosedRange<CGFloat> = 2.5...7.0,
        staggerWindow: TimeInterval = 0.12
    ) -> [Particle] {
        guard count > 0, !origins.isEmpty, paletteSize > 0 else { return [] }
        var rng = SplitMix64(seed: seed)

        return (0..<count).map { index in
            let origin = origins[index % origins.count]

            // Bias upward: particles that spray sideways or downward read as a leak.
            // The jitter is clamped back into the upper half, otherwise it pushes
            // angles near the ends past horizontal and those particles launch down.
            let jittered = rng.next(in: -Double.pi ... 0) + rng.next(in: -0.35...0.35)
            let angle = min(-0.06, max(-Double.pi + 0.06, jittered))
            let speed = rng.next(in: speedRange)

            return Particle(
                origin: origin,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                birth: rng.next(in: 0...max(0, staggerWindow)),
                lifetime: rng.next(in: lifetimeRange),
                size: CGFloat(rng.next(in: Double(sizeRange.lowerBound)...Double(sizeRange.upperBound))),
                colorIndex: Int(rng.next(upperBound: UInt64(paletteSize)))
            )
        }
    }

    /// Position at `time`, in unit space, or `nil` once the particle is dead.
    public static func position(of particle: Particle, at time: TimeInterval, gravity: Double = defaultGravity) -> CGPoint? {
        let age = time - particle.birth
        guard age >= 0, age <= particle.lifetime else { return nil }

        let x = particle.origin.x + particle.velocity.dx * age
        // Screen space grows downward, so gravity adds to y.
        let y = particle.origin.y + particle.velocity.dy * age + 0.5 * gravity * age * age
        return CGPoint(x: x, y: y)
    }

    /// Fade factor at `time`, 0...1. Zero once dead.
    public static func opacity(of particle: Particle, at time: TimeInterval) -> Double {
        let age = time - particle.birth
        guard age >= 0, particle.lifetime > 0, age <= particle.lifetime else { return 0 }
        // Hold full brightness briefly, then fade. Fading from frame one looks weak.
        let progress = age / particle.lifetime
        return progress < 0.35 ? 1 : pow(1 - (progress - 0.35) / 0.65, 1.6)
    }
}

/// Small, fast, reproducible RNG. Not for anything security related.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) * (1.0 / 9007199254740992.0)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
