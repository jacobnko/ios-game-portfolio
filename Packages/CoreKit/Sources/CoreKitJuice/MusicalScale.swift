// Maps a sequence step to a musical pitch, so repeated actions never sound flat.

import Foundation

/// A scale used to turn "the Nth step of an action" into a note.
///
/// Pentatonic is the default because every note in it is consonant with every
/// other one. A player can hit steps in any order, at any speed, and the result
/// still sounds intentional — which a major scale does not guarantee.
public enum MusicalScale: Sendable, CaseIterable {
    case pentatonicMajor
    case pentatonicMinor
    case major

    /// Semitone offsets from the root, one octave's worth.
    public var degrees: [Int] {
        switch self {
        case .pentatonicMajor: [0, 2, 4, 7, 9]
        case .pentatonicMinor: [0, 3, 5, 7, 10]
        case .major: [0, 2, 4, 5, 7, 9, 11]
        }
    }

    /// Semitones above the root for a given step of an ascending run.
    ///
    /// Steps past the end of the scale continue into the next octave. Past
    /// `octaveCeiling` the pitch stops climbing: beyond roughly two octaves the
    /// tone turns shrill and stops reading as reward.
    public func semitoneOffset(forStep step: Int, octaveCeiling: Int = 2) -> Int {
        let degrees = degrees
        let clampedStep = max(0, step)
        let ceilingStep = degrees.count * max(0, octaveCeiling)
        let effectiveStep = min(clampedStep, ceilingStep)

        let octave = effectiveStep / degrees.count
        let degree = effectiveStep % degrees.count
        return degrees[degree] + 12 * octave
    }

    /// The step at which this scale stops rising.
    public func ceilingStep(octaveCeiling: Int = 2) -> Int {
        degrees.count * max(0, octaveCeiling)
    }
}

/// Standard reference pitches, named so call sites read musically.
public enum Pitch {
    /// 523.25 Hz. Bright enough to cut through gameplay without being piercing.
    public static let c5: Double = 523.251
    public static let a4: Double = 440.0

    /// Converts a semitone offset from a root frequency into hertz.
    public static func frequency(root: Double, semitones: Int) -> Double {
        root * pow(2.0, Double(semitones) / 12.0)
    }
}
