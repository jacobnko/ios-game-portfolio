// The schedule that turns a win into a sequence of felt events rather than a popup.

import Foundation

/// When each layer of the victory payoff starts and ends.
///
/// The layers are deliberately staggered. Firing shake, particles and the score
/// multiplier on the same frame reads as a single flash; spreading them over about
/// a second lets the player register each one, which is what makes it feel earned.
public struct VictoryTimeline: Sendable, Equatable {
    public struct Phase: Sendable, Equatable {
        public let start: TimeInterval
        public let duration: TimeInterval
        public var end: TimeInterval { start + duration }

        public init(start: TimeInterval, duration: TimeInterval) {
            self.start = max(0, start)
            self.duration = max(0, duration)
        }

        /// Progress through this phase, 0...1, or `nil` before it starts and after it ends.
        public func progress(at time: TimeInterval) -> Double? {
            guard duration > 0 else { return time >= start ? 1 : nil }
            guard time >= start, time <= end else { return nil }
            return (time - start) / duration
        }
    }

    public let shake: Phase
    public let burst: Phase
    public let multiplier: Phase

    /// Total length of the sequence, including the beat of quiet at the end.
    ///
    /// That trailing quiet matters: cutting to the next screen the instant the last
    /// particle dies makes the payoff feel clipped.
    public let total: TimeInterval

    /// The default payoff, tuned for a 10–30 second puzzle. Start times follow
    /// D5's beat: everything fires at ignite (~80ms after the board finishes),
    /// and the multiplier waits until 240ms so it does not land on the same
    /// frame as the bloom flash — two payoffs on one frame read as one.
    public static let standard = VictoryTimeline(
        shake: Phase(start: 0.080, duration: 0.42),
        burst: Phase(start: 0.080, duration: 1.0),
        multiplier: Phase(start: 0.240, duration: 0.85),
        total: 1.25
    )

    public init(shake: Phase, burst: Phase, multiplier: Phase, total: TimeInterval) {
        self.shake = shake
        self.burst = burst
        self.multiplier = multiplier
        // The sequence can never end before its longest phase does.
        self.total = max(total, max(shake.end, max(burst.end, multiplier.end)))
    }

    /// Whether the sequence is still running at the given elapsed time.
    public func isRunning(at time: TimeInterval) -> Bool {
        time >= 0 && time < total
    }
}

/// Scale and fade curve for a value that pops into view and settles.
///
/// Used for the score multiplier. The overshoot is the point: a label that simply
/// fades in reads as information, while one that punches past its size and settles
/// reads as a reward.
public struct PopCurve: Sendable, Equatable {
    public let overshoot: Double
    /// Fraction of the phase spent growing past full size.
    public let riseFraction: Double
    /// Fraction of the phase spent settling back.
    public let settleFraction: Double
    /// Fraction of the phase spent fading out at the end.
    public let fadeFraction: Double

    public init(overshoot: Double = 1.28, riseFraction: Double = 0.22, settleFraction: Double = 0.18, fadeFraction: Double = 0.25) {
        self.overshoot = max(1, overshoot)
        self.riseFraction = min(1, max(0.01, riseFraction))
        self.settleFraction = min(1 - self.riseFraction, max(0, settleFraction))
        self.fadeFraction = min(1, max(0, fadeFraction))
    }

    public static let standard = PopCurve()

    /// Scale factor for a phase progress of 0...1.
    public func scale(at progress: Double) -> Double {
        let p = min(1, max(0, progress))
        if p < riseFraction {
            // Ease out so it arrives fast and decelerates into the overshoot.
            let local = p / riseFraction
            return 0.35 + (overshoot - 0.35) * (1 - pow(1 - local, 3))
        }
        let settleEnd = riseFraction + settleFraction
        if p < settleEnd, settleFraction > 0 {
            let local = (p - riseFraction) / settleFraction
            return overshoot + (1 - overshoot) * (1 - pow(1 - local, 2))
        }
        return 1
    }

    /// Opacity for a phase progress of 0...1.
    public func opacity(at progress: Double) -> Double {
        let p = min(1, max(0, progress))
        let fadeStart = 1 - fadeFraction
        guard fadeFraction > 0, p > fadeStart else { return 1 }
        return 1 - (p - fadeStart) / fadeFraction
    }
}
