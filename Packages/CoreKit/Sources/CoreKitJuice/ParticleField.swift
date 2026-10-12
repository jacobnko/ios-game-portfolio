// Deterministic particle burst maths, independent of any renderer.

import Foundation
import CoreGraphics

/// One particle of a burst — a victory spark, a glass shard, a puff of dust.
///
/// Positions are in unit space (0...1 across the view) so the same burst works at
/// any screen size without rescaling velocities.
public struct Particle: Sendable, Equatable {
    public let origin: CGPoint
    public let velocity: CGVector
    public let birth: TimeInterval
    public let lifetime: TimeInterval
    /// Points for the legacy `make` burst; unit space (like positions) for `emit`.
    public let size: CGFloat
    /// Index into the caller's palette, so colour choice stays a game decision.
    public let colorIndex: Int

    // Everything below defaults to "off", which is exactly the original victory
    // particle: a round dot that flies a pure gravity arc and fades on the legacy curve.
    // `legacyBurstIsBitIdentical` pins that.

    /// What to draw. The legacy burst draws every particle as a dot regardless.
    public var shape: ParticleShape = .dot
    /// Orientation at birth, in radians.
    public var rotation: Double = 0
    /// Spin in radians per second (signed).
    public var angularVelocity: Double = 0
    /// Air resistance, per second: velocity relaxes toward terminal velocity as
    /// `e^(−drag·t)`. A per-frame spec of `v·(1 − k·dt)` is `drag = k`, made frame-rate
    /// independent — the per-frame form flies further at 60Hz than at 120Hz.
    public var drag: Double = 0
    /// Size multiplier reached at death, ramped over the fade window.
    public var endScale: Double = 1
    /// Fraction of the lifetime after which the particle fades linearly to zero.
    /// `nil` keeps the legacy hold-then-ease curve.
    public var fadeStart: Double?
    /// A floor in unit space the particle bounces off once, or `nil` for none.
    public var floorY: Double?
    /// Fraction of vertical speed kept by that bounce.
    public var restitution: Double = 0
}

/// Outlines a particle can take. Paths are in `ParticleShape+Path.swift`.
public enum ParticleShape: Sendable, Hashable, CaseIterable {
    /// The legacy round spark.
    case dot
    /// A small square spark.
    case square
    /// A scalene triangle shard.
    case triangle
    /// A parallelogram shard, 1 : 0.7.
    case parallelogram
    /// A long thin shard, 4 : 1.
    case sliver
}

/// Everything that varies between bursts — shards from a broken tile, sparks, dust,
/// confetti — as one value, so a new effect is a new configuration, not new code.
///
/// Units are the field's unit space: positions and lengths as a fraction of the
/// reference size the caller renders into (a board side, say), speeds per second.
public struct ParticleEmitter: Sendable, Equatable {
    public var origins: [CGPoint]
    /// Each origin is offset by up to ± this much on both axes.
    public var originJitter: Double
    /// Launch directions in radians in y-down screen space (−π/2 is straight up).
    /// Particles take them in turn, so `[-π/2, π/2]` sprays both ways off a line.
    public var directions: [Double]
    /// ± this many radians around the chosen direction. `.pi` is a full circle.
    public var spread: Double
    public var speed: ClosedRange<Double>
    /// Spin magnitude in radians per second; the sign is random.
    public var angularSpeed: ClosedRange<Double>
    public var lifetime: ClosedRange<TimeInterval>
    public var size: ClosedRange<Double>
    public var drag: Double
    public var endScale: Double
    public var fadeStart: Double
    /// Shapes in the proportion wanted, e.g. 4 triangles, 3 parallelograms, 1 sliver.
    /// Every full run of this many particles gets exactly these proportions.
    public var shapes: [ParticleShape]
    /// Palette indices in the proportion wanted, used the same way as `shapes`.
    public var colors: [Int]
    /// Births are spread randomly over `0...stagger` after `delay`.
    public var stagger: TimeInterval
    /// Added to every birth, for chaining bursts on one clock (one line after another).
    public var delay: TimeInterval
    public var floorY: Double?
    public var restitution: Double

    public init(
        origins: [CGPoint],
        originJitter: Double = 0,
        directions: [Double] = [-Double.pi / 2],
        spread: Double = Double.pi,
        speed: ClosedRange<Double>,
        angularSpeed: ClosedRange<Double> = 0...0,
        lifetime: ClosedRange<TimeInterval>,
        size: ClosedRange<Double>,
        drag: Double = 0,
        endScale: Double = 1,
        fadeStart: Double = 0,
        shapes: [ParticleShape] = [.square],
        colors: [Int] = [0],
        stagger: TimeInterval = 0,
        delay: TimeInterval = 0,
        floorY: Double? = nil,
        restitution: Double = 0
    ) {
        self.origins = origins
        self.originJitter = max(0, originJitter)
        self.directions = directions.isEmpty ? [-Double.pi / 2] : directions
        self.spread = max(0, spread)
        self.speed = speed
        self.angularSpeed = angularSpeed
        self.lifetime = lifetime
        self.size = size
        self.drag = max(0, drag)
        self.endScale = max(0, endScale)
        self.fadeStart = min(1, max(0, fadeStart))
        self.shapes = shapes.isEmpty ? [.square] : shapes
        self.colors = colors.isEmpty ? [0] : colors
        self.stagger = max(0, stagger)
        self.delay = max(0, delay)
        self.floorY = floorY
        self.restitution = min(1, max(0, restitution))
    }

    /// Expands weights into a pattern: `[4, 3, 1]` → `[0,0,0,0,1,1,1,2]`.
    public static func pattern(weights: [Int]) -> [Int] {
        weights.enumerated().flatMap { index, weight in Array(repeating: index, count: max(0, weight)) }
    }
}

/// How many particles each source may emit so one event stays under its cap.
///
/// `min(perSource, floor(cap / sources))`: four lines clearing at once thin out each
/// tile's shards instead of blowing the frame budget.
public enum ParticleBudget {
    public static func perSource(_ perSource: Int, sources: Int, cap: Int) -> Int {
        guard sources > 0 else { return max(0, perSource) }
        return max(0, min(perSource, cap / sources))
    }
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
        speedRange: ClosedRange<Double> = 0.25...0.95,
        lifetimeRange: ClosedRange<TimeInterval> = 0.45...0.95,
        sizeRange: ClosedRange<CGFloat> = 2.5...7.0,
        staggerWindow: TimeInterval = 0.12
    ) -> [Particle] {
        guard count > 0, !origins.isEmpty else { return [] }
        var rng = SplitMix64(seed: seed)

        return (0..<count).map { index in
            // Same modulo as the origin pick below, on purpose: a particle's
            // colour is tied to the endpoint it spawns from, not chosen at
            // random, so a caller whose palette is ordered to match `origins`
            // (one colour per endpoint) gets sparks that actually match the
            // pipe they came from. A caller with a shorter, generic palette
            // still gets a colour — `colorIndex % palette.count` at render
            // time wraps it — just not a 1:1 one.
            let originIndex = index % origins.count
            let origin = origins[originIndex]

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
                colorIndex: originIndex
            )
        }
    }

    /// Generates `count` particles from `emitter`. Deterministic for a given seed.
    public static func emit(_ emitter: ParticleEmitter, count: Int, seed: UInt64) -> [Particle] {
        guard count > 0, !emitter.origins.isEmpty else { return [] }
        var rng = SplitMix64(seed: seed)
        // Shuffle each proportion pattern once, so a burst of exactly one pattern's
        // length gets exact proportions without the same shape always coming first.
        let shapes = shuffled(emitter.shapes, using: &rng)
        let colors = shuffled(emitter.colors, using: &rng)

        return (0..<count).map { index in
            let base = emitter.origins[index % emitter.origins.count]
            let jitter = emitter.originJitter
            let origin = CGPoint(
                x: base.x + rng.next(in: -jitter...jitter),
                y: base.y + rng.next(in: -jitter...jitter)
            )
            let direction = emitter.directions[index % emitter.directions.count]
            let angle = direction + rng.next(in: -emitter.spread...emitter.spread)
            let speed = rng.next(in: emitter.speed)
            let spin = rng.next(in: emitter.angularSpeed) * (rng.next(in: 0...1) < 0.5 ? -1 : 1)

            var particle = Particle(
                origin: origin,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                birth: emitter.delay + rng.next(in: 0...emitter.stagger),
                lifetime: rng.next(in: emitter.lifetime),
                size: CGFloat(rng.next(in: emitter.size)),
                colorIndex: colors[index % colors.count]
            )
            particle.shape = shapes[index % shapes.count]
            particle.rotation = rng.next(in: 0...(2 * Double.pi))
            particle.angularVelocity = spin
            particle.drag = emitter.drag
            particle.endScale = emitter.endScale
            particle.fadeStart = emitter.fadeStart
            particle.floorY = emitter.floorY
            particle.restitution = emitter.restitution
            return particle
        }
    }

    /// Position at `time`, in unit space, or `nil` once the particle is dead.
    public static func position(of particle: Particle, at time: TimeInterval, gravity: Double = defaultGravity) -> CGPoint? {
        let age = time - particle.birth
        guard age >= 0, age <= particle.lifetime else { return nil }

        if let floorY = particle.floorY, let hit = impactAge(of: particle, floorY: floorY, gravity: gravity), age > hit {
            // One bounce: restart the flight from the impact point with the vertical
            // speed reversed and reduced. No second bounce — a shard that keeps
            // bouncing reads as rubber, not glass.
            let impact = flight(origin: particle.origin, velocity: particle.velocity, age: hit, drag: particle.drag, gravity: gravity)
            let incoming = velocity(particle.velocity, age: hit, drag: particle.drag, gravity: gravity)
            let outgoing = CGVector(dx: incoming.dx, dy: -incoming.dy * particle.restitution)
            return flight(origin: impact, velocity: outgoing, age: age - hit, drag: particle.drag, gravity: gravity)
        }
        return flight(origin: particle.origin, velocity: particle.velocity, age: age, drag: particle.drag, gravity: gravity)
    }

    /// Orientation in radians at `time`.
    public static func rotation(of particle: Particle, at time: TimeInterval) -> Double {
        particle.rotation + particle.angularVelocity * max(0, time - particle.birth)
    }

    /// Size multiplier at `time`: 1 until the fade starts, then toward `endScale`.
    public static func scale(of particle: Particle, at time: TimeInterval) -> Double {
        guard particle.endScale != 1 else { return 1 }
        return 1 + (particle.endScale - 1) * fadeProgress(of: particle, at: time)
    }

    /// Fade factor at `time`, 0...1. Zero once dead.
    public static func opacity(of particle: Particle, at time: TimeInterval) -> Double {
        let age = time - particle.birth
        guard age >= 0, particle.lifetime > 0, age <= particle.lifetime else { return 0 }
        if particle.fadeStart != nil {
            return 1 - fadeProgress(of: particle, at: time)
        }
        // Hold full brightness briefly, then fade. Fading from frame one looks weak.
        let progress = age / particle.lifetime
        return progress < 0.35 ? 1 : pow(1 - (progress - 0.35) / 0.65, 1.6)
    }

    // MARK: - Motion

    /// 0 before the fade window, 1 at death.
    private static func fadeProgress(of particle: Particle, at time: TimeInterval) -> Double {
        guard particle.lifetime > 0 else { return 1 }
        let progress = min(1, max(0, (time - particle.birth) / particle.lifetime))
        let start = particle.fadeStart ?? 1
        guard start < 1 else { return progress >= 1 ? 1 : 0 }
        return max(0, (progress - start) / (1 - start))
    }

    /// Closed-form flight under gravity and linear drag, so it is exact at any frame rate.
    private static func flight(origin: CGPoint, velocity: CGVector, age: Double, drag: Double, gravity: Double) -> CGPoint {
        guard drag > 0 else {
            // The original formula, expression for expression: the legacy burst
            // must stay bit-identical.
            let x = origin.x + velocity.dx * age
            // Screen space grows downward, so gravity adds to y.
            let y = origin.y + velocity.dy * age + 0.5 * gravity * age * age
            return CGPoint(x: x, y: y)
        }
        // dv/dt = g − k·v  ⇒  v(t) = g/k + (v₀ − g/k)·e^(−kt)
        let decay = (1 - exp(-drag * age)) / drag
        let terminal = gravity / drag
        let x = origin.x + velocity.dx * decay
        let y = origin.y + terminal * age + (velocity.dy - terminal) * decay
        return CGPoint(x: x, y: y)
    }

    private static func velocity(_ initial: CGVector, age: Double, drag: Double, gravity: Double) -> CGVector {
        guard drag > 0 else { return CGVector(dx: initial.dx, dy: initial.dy + gravity * age) }
        let falloff = exp(-drag * age)
        let terminal = gravity / drag
        return CGVector(dx: initial.dx * falloff, dy: terminal + (initial.dy - terminal) * falloff)
    }

    /// Age at which the particle first falls through `floorY`, or `nil` if it never does
    /// within its life. Vertical speed only ever increases (gravity, drag toward a
    /// downward terminal speed), so height has a single turning point and the
    /// descending crossing is unique — bisection finds it without missing it.
    private static func impactAge(of particle: Particle, floorY: Double, gravity: Double) -> Double? {
        let height = { (age: Double) -> Double in
            Double(flight(origin: particle.origin, velocity: particle.velocity, age: age, drag: particle.drag, gravity: gravity).y)
        }
        guard Double(particle.origin.y) < floorY, height(particle.lifetime) >= floorY else { return nil }
        var low = 0.0, high = particle.lifetime
        for _ in 0..<40 {
            let mid = (low + high) / 2
            if height(mid) < floorY { low = mid } else { high = mid }
        }
        return high
    }

    private static func shuffled<Element>(_ elements: [Element], using rng: inout SplitMix64) -> [Element] {
        var copy = elements
        guard copy.count > 1 else { return copy }
        for index in stride(from: copy.count - 1, to: 0, by: -1) {
            let other = min(index, Int(rng.next(in: 0...1) * Double(index + 1)))
            copy.swapAt(index, other)
        }
        return copy
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
