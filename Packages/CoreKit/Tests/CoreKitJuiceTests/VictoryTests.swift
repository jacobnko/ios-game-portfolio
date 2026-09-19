// Verifies the timing and motion maths behind the victory payoff.

import Testing
import Foundation
import CoreGraphics
@testable import CoreKitJuice

// MARK: - Timeline

@Test func phaseProgressIsNilOutsideItsWindow() {
    let phase = VictoryTimeline.Phase(start: 0.2, duration: 0.5)
    #expect(phase.progress(at: 0.1) == nil)
    #expect(phase.progress(at: 0.8) == nil)
}

@Test func phaseProgressSpansZeroToOne() {
    let phase = VictoryTimeline.Phase(start: 0.2, duration: 0.5)
    #expect(phase.progress(at: 0.2) == 0)
    #expect(abs(phase.progress(at: 0.7)! - 1) < 0.0001)
    #expect(abs(phase.progress(at: 0.45)! - 0.5) < 0.0001)
}

@Test func timelineNeverEndsBeforeItsLongestPhase() {
    // A total shorter than a phase would cut the payoff off mid-animation.
    let timeline = VictoryTimeline(
        shake: .init(start: 0, duration: 0.3),
        burst: .init(start: 0, duration: 2.0),
        multiplier: .init(start: 0, duration: 0.5),
        total: 0.1
    )
    #expect(timeline.total == 2.0)
}

@Test func standardTimelineStaggersItsLayers() {
    // Firing everything on one frame reads as a single flash instead of a sequence.
    let t = VictoryTimeline.standard
    #expect(t.shake.start < t.multiplier.start)
    #expect(t.burst.start < t.multiplier.start)
    #expect(t.total > t.burst.end)  // a beat of quiet before the next screen
}

@Test func timelineReportsWhenItIsDone() {
    let t = VictoryTimeline.standard
    #expect(t.isRunning(at: 0) == true)
    #expect(t.isRunning(at: t.total) == false)
    #expect(t.isRunning(at: -1) == false)
}

// MARK: - ShakeCurve

@Test func shakeIsZeroOutsideItsWindow() {
    let curve = ShakeCurve()
    #expect(curve.offset(at: -0.1) == .zero)
    #expect(curve.offset(at: 10) == .zero)
}

@Test func shakeReturnsToExactlyZero() {
    // Exponential decay never truly reaches zero, which leaves the view permanently
    // offset by a fraction of a point. The curve must land on zero.
    let curve = ShakeCurve()
    #expect(curve.offset(at: curve.duration) == .zero)
}

@Test func shakeNeverExceedsItsAmplitude() {
    let curve = ShakeCurve(amplitude: 9, duration: 0.35, frequency: 11)
    for i in 0...350 {
        let offset = curve.offset(at: Double(i) / 1000)
        #expect(abs(offset.width) <= curve.amplitude + 0.0001)
        #expect(abs(offset.height) <= curve.amplitude + 0.0001)
    }
}

@Test func shakeEnergyDecays() {
    let curve = ShakeCurve(amplitude: 10, duration: 1.0, frequency: 10)
    func peak(from: Double, to: Double) -> Double {
        stride(from: from, to: to, by: 0.002)
            .map { max(abs(curve.offset(at: $0).width), abs(curve.offset(at: $0).height)) }
            .max() ?? 0
    }
    #expect(peak(from: 0.0, to: 0.25) > peak(from: 0.5, to: 0.75))
}

@Test func shakeAxesAreNotLockedTogether() {
    // Identical X and Y motion reads as a diagonal glitch rather than an impact.
    let curve = ShakeCurve()
    let samples = stride(from: 0.0, to: 0.3, by: 0.01).map { curve.offset(at: $0) }
    #expect(samples.contains { abs($0.width - $0.height) > 0.5 })
}

@Test func degenerateShakeIsInert() {
    #expect(ShakeCurve(amplitude: 0).offset(at: 0.1) == .zero)
    #expect(ShakeCurve(duration: 0).offset(at: 0) == .zero)
}

// MARK: - ParticleField

@Test func burstIsDeterministicForASeed() {
    // A burst that differs every run cannot be tuned or reproduced in a bug report.
    let a = ParticleField.make(count: 40, origins: [CGPoint(x: 0.5, y: 0.5)], seed: 99)
    let b = ParticleField.make(count: 40, origins: [CGPoint(x: 0.5, y: 0.5)], seed: 99)
    #expect(a == b)
}

@Test func differentSeedsProduceDifferentBursts() {
    let a = ParticleField.make(count: 40, origins: [CGPoint(x: 0.5, y: 0.5)], seed: 1)
    let b = ParticleField.make(count: 40, origins: [CGPoint(x: 0.5, y: 0.5)], seed: 2)
    #expect(a != b)
}

@Test func burstHonoursCountAndOrigins() {
    let origins = [CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.8, y: 0.3)]
    let particles = ParticleField.make(count: 10, origins: origins)
    #expect(particles.count == 10)
    #expect(Set(particles.map(\.origin.x)) == Set(origins.map(\.x)))
}

@Test func degenerateBurstsAreEmpty() {
    #expect(ParticleField.make(count: 0, origins: [.zero]).isEmpty)
    #expect(ParticleField.make(count: 10, origins: []).isEmpty)
}

@Test func particlesLaunchUpward() {
    // A burst that only sprays sideways reads as a leak.
    let particles = ParticleField.make(count: 60, origins: [CGPoint(x: 0.5, y: 0.5)])
    #expect(particles.allSatisfy { $0.velocity.dy < 0 })
}

@Test func particlesExpireAfterTheirLifetime() {
    let particles = ParticleField.make(count: 5, origins: [CGPoint(x: 0.5, y: 0.5)])
    for particle in particles {
        let afterDeath = particle.birth + particle.lifetime + 0.01
        #expect(ParticleField.position(of: particle, at: afterDeath) == nil)
        #expect(ParticleField.opacity(of: particle, at: afterDeath) == 0)
    }
}

@Test func particlesAreInvisibleBeforeBirth() {
    let particles = ParticleField.make(count: 20, origins: [CGPoint(x: 0.5, y: 0.5)], staggerWindow: 0.2)
    let staggered = particles.filter { $0.birth > 0.01 }
    #expect(staggered.isEmpty == false)
    for particle in staggered {
        #expect(ParticleField.position(of: particle, at: 0) == nil)
        #expect(ParticleField.opacity(of: particle, at: 0) == 0)
    }
}

@Test func particlesHoldFullBrightnessBeforeFading() {
    // Fading from the first frame makes the burst look weak.
    let particles = ParticleField.make(count: 5, origins: [CGPoint(x: 0.5, y: 0.5)])
    for particle in particles {
        #expect(ParticleField.opacity(of: particle, at: particle.birth) == 1)
        let late = particle.birth + particle.lifetime * 0.9
        #expect(ParticleField.opacity(of: particle, at: late) < 0.5)
    }
}

@Test func gravityPullsParticlesBackDown() {
    let particle = Particle(
        origin: CGPoint(x: 0.5, y: 0.5),
        velocity: CGVector(dx: 0, dy: -0.5),
        birth: 0, lifetime: 5, size: 4, colorIndex: 0
    )
    let rising = ParticleField.position(of: particle, at: 0.2)!
    let falling = ParticleField.position(of: particle, at: 3.0)!
    #expect(rising.y < particle.origin.y)   // up first
    #expect(falling.y > rising.y)           // then back down
}

// MARK: - PopCurve

@Test func popOvershootsThenSettlesToExactlyOne() {
    let curve = PopCurve.standard
    let peak = stride(from: 0.0, through: 1.0, by: 0.005).map { curve.scale(at: $0) }.max()!
    #expect(peak > 1.1)
    #expect(curve.scale(at: 1.0) == 1)
}

@Test func popStartsSmall() {
    #expect(PopCurve.standard.scale(at: 0) < 0.5)
}

@Test func popIsOpaqueBeforeItFades() {
    let curve = PopCurve.standard
    #expect(curve.opacity(at: 0) == 1)
    #expect(curve.opacity(at: 0.5) == 1)
    #expect(curve.opacity(at: 1.0) < 0.01)
}

@Test func popFractionsCannotOverlap() {
    let curve = PopCurve(overshoot: 2, riseFraction: 0.9, settleFraction: 0.9)
    #expect(curve.riseFraction + curve.settleFraction <= 1.0)
}

// MARK: - ShakeCurve, D5 formula

@Test func shakeDecaysExponentiallyNotQuadratically() {
    // Exponential decay drops off much faster near t=0 than the old quadratic
    // envelope did — this pins the shape, not just "it decays".
    let curve = ShakeCurve(amplitude: 10, duration: 1.0, frequency: 1, tau: 0.11)
    let early = abs(curve.offset(at: 0.01).height)
    let late = abs(curve.offset(at: 0.5).height)
    #expect(early > late * 50)
}

@Test func lateralAmplitudeIsAFractionOfThePrimaryOne() {
    let curve = ShakeCurve(amplitude: 6, lateralRatio: 0.4)
    for t in stride(from: 0.0, to: curve.duration, by: 0.01) {
        let offset = curve.offset(at: t)
        #expect(abs(offset.width) <= abs(curve.amplitude) * 0.4 + 0.0001)
    }
}

// MARK: - BloomCurve

@Test func bloomIsFullWhiteThroughTheIgniteWindow() {
    let bloom = BloomCurve.standard
    #expect(bloom.whiteness(at: bloom.igniteStart) == 1)
    #expect(bloom.whiteness(at: bloom.igniteEnd) == 1)
}

@Test func bloomIsZeroBeforeIgniting() {
    #expect(BloomCurve.standard.whiteness(at: 0) == 0)
}

@Test func bloomDecaysToZeroAfterTheWindow() {
    // Floating-point division can leave `progress` a hair under 1 rather than
    // exactly 1, so the curve is checked against a tolerance here rather than
    // exact zero — the same shape ShakeCurve's own "never truly reaches zero"
    // comment describes for exponential decay generally.
    let bloom = BloomCurve.standard
    #expect(bloom.whiteness(at: bloom.igniteEnd + bloom.decay) < 0.0001)
    let mid = bloom.whiteness(at: bloom.igniteEnd + bloom.decay / 2)
    #expect(mid > 0 && mid < 1)
}

@Test func bloomScalePunchesThenSettlesToExactlyOne() {
    let bloom = BloomCurve.standard
    #expect(bloom.scale(at: bloom.igniteStart) == bloom.scalePunch)
    #expect(bloom.scale(at: bloom.scaleSettle) == 1)
    #expect(bloom.scale(at: 0) == 1)
}

@Test func bloomScaleNeverExceedsThePunch() {
    let bloom = BloomCurve.standard
    for t in stride(from: 0.0, through: bloom.scaleSettle, by: 0.01) {
        #expect(bloom.scale(at: t) <= bloom.scalePunch + 0.0001)
        #expect(bloom.scale(at: t) >= 1 - 0.0001)
    }
}

// MARK: - ParticleField colour follows origin

@Test func eachParticlesColourMatchesItsSpawnOrigin() {
    // A spark must carry the colour of the endpoint it came from, not a random
    // pick — this is what lets a caller pass a palette ordered to match
    // origins (Chordline's own pipe colours) and have it actually line up.
    let origins = [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.9), CGPoint(x: 0.5, y: 0.5)]
    let particles = ParticleField.make(count: 30, origins: origins)
    for particle in particles {
        let expectedOrigin = origins[particle.colorIndex]
        #expect(particle.origin == expectedOrigin)
    }
}
