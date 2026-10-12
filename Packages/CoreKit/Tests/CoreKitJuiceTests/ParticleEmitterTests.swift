// Verifies emitted particles: proportions, directions, drag, bounce, spin, scale and fade.

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import CoreKitJuice

private func shards(
    count: Int = 8,
    seed: UInt64 = 7,
    directions: [Double] = [-Double.pi / 2],
    spread: Double = Double.pi / 3,
    shapes: [ParticleShape] = [.triangle, .triangle, .triangle, .triangle, .parallelogram, .parallelogram, .parallelogram, .sliver],
    colors: [Int] = [0],
    drag: Double = 1.8
) -> [Particle] {
    ParticleField.emit(
        ParticleEmitter(
            origins: [CGPoint(x: 0.5, y: 0.5)],
            originJitter: 0.01,
            directions: directions,
            spread: spread,
            speed: 0.35...0.75,
            angularSpeed: (Double.pi)...(4 * Double.pi),
            lifetime: 0.55...0.78,
            size: 0.012...0.04,
            drag: drag,
            endScale: 0.7,
            fadeStart: 0.6,
            shapes: shapes,
            colors: colors,
            stagger: 0.02,
            delay: 0.22
        ),
        count: count,
        seed: seed
    )
}

// MARK: - Generation

@Test func emitIsDeterministicPerSeed() {
    #expect(shards(count: 40, seed: 3) == shards(count: 40, seed: 3))
    #expect(shards(count: 40, seed: 3) != shards(count: 40, seed: 4))
}

@Test func emitWithNothingToDoIsEmpty() {
    #expect(shards(count: 0).isEmpty)
    let noOrigins = ParticleEmitter(origins: [], speed: 0...1, lifetime: 1...1, size: 0.1...0.1)
    #expect(ParticleField.emit(noOrigins, count: 5, seed: 1).isEmpty)
}

@Test func shapeProportionsAreExactPerPattern() {
    // L5: 8 shards per tile = 4 triangles, 3 parallelograms, 1 sliver — exactly, every seed.
    for seed in UInt64(1)...20 {
        let shapes = shards(count: 8, seed: seed).map(\.shape)
        #expect(shapes.filter { $0 == .triangle }.count == 4)
        #expect(shapes.filter { $0 == .parallelogram }.count == 3)
        #expect(shapes.filter { $0 == .sliver }.count == 1)
    }
}

@Test func colorProportionsAreExactPerPattern() {
    let pattern = ParticleEmitter.pattern(weights: [5, 3, 2])
    #expect(pattern == [0, 0, 0, 0, 0, 1, 1, 1, 2, 2])
    let colors = shards(count: 20, colors: pattern).map(\.colorIndex)
    #expect(colors.filter { $0 == 0 }.count == 10)
    #expect(colors.filter { $0 == 1 }.count == 6)
    #expect(colors.filter { $0 == 2 }.count == 4)
}

@Test func directionsAlternateSoALineSpraysBothWays() {
    let particles = shards(count: 20, directions: [-Double.pi / 2, Double.pi / 2], spread: 0)
    for (index, particle) in particles.enumerated() {
        #expect(index.isMultiple(of: 2) ? particle.velocity.dy < 0 : particle.velocity.dy > 0)
    }
}

@Test func launchAnglesStayInsideTheSpread() {
    for particle in shards(count: 200) {
        let angle = atan2(Double(particle.velocity.dy), Double(particle.velocity.dx))
        #expect(abs(angle - (-Double.pi / 2)) <= Double.pi / 3 + 1e-9)
    }
}

@Test func spinHasRandomSignAndBoundedMagnitude() {
    let spins = shards(count: 200).map(\.angularVelocity)
    #expect(spins.allSatisfy { abs($0) >= Double.pi - 1e-9 && abs($0) <= 4 * Double.pi + 1e-9 })
    #expect(spins.contains { $0 < 0 } && spins.contains { $0 > 0 })
}

@Test func originsBirthsAndJitterStayInBounds() {
    for particle in shards(count: 200) {
        #expect(abs(particle.origin.x - 0.5) <= 0.01 + 1e-12 && abs(particle.origin.y - 0.5) <= 0.01 + 1e-12)
        #expect(particle.birth >= 0.22 && particle.birth <= 0.24 + 1e-12)
    }
}

// MARK: - Drag

@Test func dragMatchesAFinelyIntegratedFlight() {
    // The closed form must agree with brute-force integration at a tiny step —
    // i.e. it is the continuous version of the spec's per-frame damping.
    var particle = Particle(origin: CGPoint(x: 0.5, y: 0.5), velocity: CGVector(dx: 0.6, dy: -0.5), birth: 0, lifetime: 1, size: 0.02, colorIndex: 0)
    particle.drag = 1.8
    let gravity = 1.2
    var x = 0.5, y = 0.5, vx = 0.6, vy = -0.5
    let dt = 1.0 / 20_000
    for _ in 0..<Int(0.7 / dt) {
        vx += -1.8 * vx * dt
        vy += (gravity - 1.8 * vy) * dt
        x += vx * dt
        y += vy * dt
    }
    let closed = ParticleField.position(of: particle, at: 0.7, gravity: gravity)!
    #expect(abs(Double(closed.x) - x) < 1e-4)
    #expect(abs(Double(closed.y) - y) < 1e-4)
}

@Test func dragShortensTheFlight() {
    let base = Particle(origin: .zero, velocity: CGVector(dx: 1, dy: 0), birth: 0, lifetime: 2, size: 0.02, colorIndex: 0)
    var dragged = base
    dragged.drag = 1.8
    let free = ParticleField.position(of: base, at: 1, gravity: 0)!
    let slowed = ParticleField.position(of: dragged, at: 1, gravity: 0)!
    #expect(slowed.x < free.x)
    #expect(abs(Double(slowed.x) - (1 - exp(-1.8)) / 1.8) < 1e-12)
}

// MARK: - Bounce

private func dropped(restitution: Double = 0.35, floorY: Double? = 0.5, from y: Double = 0.2, lifetime: TimeInterval = 3) -> Particle {
    var particle = Particle(origin: CGPoint(x: 0.5, y: y), velocity: CGVector(dx: 0.1, dy: 0), birth: 0, lifetime: lifetime, size: 0.05, colorIndex: 0)
    particle.floorY = floorY
    particle.restitution = restitution
    return particle
}

@Test func bounceReversesAtTheFloorThenRisesToTheRestitutionHeight() {
    let gravity = 1.4
    let particle = dropped()
    // No drag: falling 0.3 takes sqrt(2·0.3/g); the bounce peaks at e²·0.3 above the floor.
    let hit = (2 * 0.3 / gravity).squareRoot()
    let before = ParticleField.position(of: particle, at: hit - 0.01, gravity: gravity)!
    let after = ParticleField.position(of: particle, at: hit + 0.01, gravity: gravity)!
    #expect(before.y < 0.5 && after.y < 0.5)

    let peakTime = hit + 0.35 * gravity * hit / gravity
    let peak = ParticleField.position(of: particle, at: peakTime, gravity: gravity)!
    #expect(abs((0.5 - Double(peak.y)) - 0.35 * 0.35 * 0.3) < 1e-6)
}

@Test func itBouncesOnlyOnce() {
    let particle = dropped()
    // Long after the single bounce it falls through the floor and keeps going.
    let late = ParticleField.position(of: particle, at: 2.5, gravity: 1.4)!
    #expect(late.y > 0.6)
}

@Test func aFloorItNeverReachesChangesNothing() {
    let withFloor = dropped(floorY: 50)
    let without = dropped(floorY: nil)
    for time in stride(from: 0.0, through: 3.0, by: 0.25) {
        #expect(ParticleField.position(of: withFloor, at: time, gravity: 1.4) == ParticleField.position(of: without, at: time, gravity: 1.4))
    }
}

@Test func aParticleBornBelowItsFloorDoesNotBounce() {
    let below = dropped(floorY: 0.1)
    let free = dropped(floorY: nil)
    #expect(ParticleField.position(of: below, at: 1, gravity: 1.4) == ParticleField.position(of: free, at: 1, gravity: 1.4))
}

// MARK: - Spin, scale, fade

@Test func rotationAdvancesLinearlyFromBirth() {
    var particle = Particle(origin: .zero, velocity: CGVector(dx: 0, dy: 0), birth: 1, lifetime: 1, size: 0.02, colorIndex: 0)
    particle.rotation = 0.5
    particle.angularVelocity = 2
    #expect(ParticleField.rotation(of: particle, at: 0.5) == 0.5)
    #expect(ParticleField.rotation(of: particle, at: 1.5) == 1.5)
}

@Test func scaleAndOpacityRampOnlyInsideTheFadeWindow() {
    var particle = Particle(origin: .zero, velocity: CGVector(dx: 0, dy: 0), birth: 0, lifetime: 1, size: 0.02, colorIndex: 0)
    particle.endScale = 0.7
    particle.fadeStart = 0.6
    #expect(ParticleField.scale(of: particle, at: 0.5) == 1)
    #expect(ParticleField.opacity(of: particle, at: 0.5) == 1)
    #expect(abs(ParticleField.scale(of: particle, at: 0.8) - 0.85) < 1e-9)
    #expect(abs(ParticleField.opacity(of: particle, at: 0.8) - 0.5) < 1e-9)
    #expect(abs(ParticleField.scale(of: particle, at: 1) - 0.7) < 1e-9)
    #expect(ParticleField.opacity(of: particle, at: 1) == 0)
}

@Test func fadeStartZeroFadesOverTheWholeLife() {
    var spark = Particle(origin: .zero, velocity: CGVector(dx: 0, dy: 0), birth: 0, lifetime: 0.2, size: 0.006, colorIndex: 0)
    spark.fadeStart = 0
    #expect(ParticleField.opacity(of: spark, at: 0) == 1)
    #expect(abs(ParticleField.opacity(of: spark, at: 0.1) - 0.5) < 1e-9)
}

@Test func legacyParticlesKeepScaleOneAndNoSpin() {
    for particle in ParticleField.make(count: 10, origins: [CGPoint(x: 0.5, y: 0.5)]) {
        #expect(particle.shape == .dot)
        #expect(ParticleField.scale(of: particle, at: particle.birth + particle.lifetime) == 1)
        #expect(ParticleField.rotation(of: particle, at: 3) == 0)
    }
}

// MARK: - Budget

@Test func budgetThinsEachSourceToStayUnderTheCap() {
    #expect(ParticleBudget.perSource(8, sources: 6, cap: 400) == 8)
    // Four lines at once: 24 tiles, 14 shards each would be 336 — fine; 16 each for 30 tiles is not.
    #expect(ParticleBudget.perSource(16, sources: 30, cap: 400) == 13)
    #expect(ParticleBudget.perSource(8, sources: 0, cap: 400) == 8)
    #expect(ParticleBudget.perSource(8, sources: 500, cap: 400) == 0)
}

// MARK: - Shapes

@Test func shardOutlinesHaveTheirSpecifiedProportions() {
    let length: CGFloat = 100
    func box(_ shape: ParticleShape) -> CGRect { shape.path(length: length).boundingRect }
    for shape in ParticleShape.allCases {
        #expect(abs(max(box(shape).width, box(shape).height) - length) < 1e-9)
    }
    #expect(abs(box(.parallelogram).height / box(.parallelogram).width - 0.7) < 1e-9)
    #expect(abs(box(.sliver).width / box(.sliver).height - 4) < 1e-9)
    #expect(ParticleShape.dot.highlightEdge(length: length) == nil)
    #expect(ParticleShape.triangle.highlightEdge(length: length) != nil)
}
