// Pure description of one synthesised tone, including the samples it renders to.

import Foundation

/// A short synthesised tone — the audio half of a juice step.
///
/// Synthesis is used instead of pitch-shifting a sample on purpose: it gives exact
/// musical intervals with no stretching artefacts, costs zero bytes in the bundle,
/// and carries no licence obligations across ten apps.
public struct ToneRecipe: Sendable, Hashable {
    public let frequency: Double
    public let duration: TimeInterval
    /// Linear gain, 0...1.
    public let gain: Float
    /// Fraction of `duration` spent fading in. Prevents the click of a hard start.
    public let attack: Double
    /// Fraction of `duration` spent fading out.
    public let release: Double

    public init(frequency: Double, duration: TimeInterval, gain: Float, attack: Double = 0.02, release: Double = 0.6) {
        self.frequency = max(0, frequency)
        self.duration = max(0, duration)
        self.gain = min(1, max(0, gain))
        // Attack and release must leave room for each other or the envelope inverts.
        let a = min(1, max(0, attack))
        let r = min(1 - a, max(0, release))
        self.attack = a
        self.release = r
    }
}

extension ToneRecipe {
    /// Builds the tone for one step of an escalating sequence.
    public static func make(
        for weight: FeedbackWeight,
        stepIndex: Int = 0,
        scale: MusicalScale = .pentatonicMajor,
        root: Double = Pitch.c5
    ) -> ToneRecipe {
        switch weight {
        case .micro:
            let semitones = scale.semitoneOffset(forStep: stepIndex)
            return ToneRecipe(
                frequency: Pitch.frequency(root: root, semitones: semitones),
                duration: 0.11,
                gain: 0.45
            )

        case .milestone:
            // An octave above the root, longer and louder — unmistakably an arrival.
            return ToneRecipe(
                frequency: Pitch.frequency(root: root, semitones: 12),
                duration: 0.35,
                gain: 0.7,
                release: 0.75
            )

        case .error:
            // Below the root and dissonant with it. Never sounds like part of the run.
            return ToneRecipe(
                frequency: Pitch.frequency(root: root, semitones: -5),
                duration: 0.16,
                gain: 0.5,
                release: 0.5
            )
        }
    }

    public static func make(for step: JuiceStep, scale: MusicalScale = .pentatonicMajor, root: Double = Pitch.c5) -> ToneRecipe {
        make(for: step.weight, stepIndex: step.index, scale: scale, root: root)
    }

    /// Renders the tone to mono float samples.
    ///
    /// Kept pure and separate from AVAudioEngine so the waveform and envelope can be
    /// verified without audio hardware.
    public func renderSamples(sampleRate: Double) -> [Float] {
        guard sampleRate > 0, duration > 0, frequency > 0 else { return [] }
        let frameCount = Int((duration * sampleRate).rounded())
        guard frameCount > 0 else { return [] }

        let attackFrames = Int(Double(frameCount) * attack)
        let releaseFrames = Int(Double(frameCount) * release)
        let sustainEnd = frameCount - releaseFrames
        let angularStep = 2.0 * Double.pi * frequency / sampleRate

        return (0..<frameCount).map { frame in
            // A triangle-ish blend: a sine plus a quiet third harmonic. Reads as a
            // soft mallet rather than a test-tone beep, without needing a sample.
            let phase = angularStep * Double(frame)
            let wave = sin(phase) + 0.18 * sin(3 * phase)

            let envelope: Double
            if frame < attackFrames {
                envelope = Double(frame) / Double(max(1, attackFrames))
            } else if frame >= sustainEnd, releaseFrames > 0 {
                let progress = Double(frame - sustainEnd) / Double(releaseFrames)
                // Exponential decay sounds natural where a linear ramp sounds mechanical.
                envelope = pow(1.0 - progress, 2.2)
            } else {
                envelope = 1.0
            }

            return Float(wave * envelope) * gain * 0.85
        }
    }
}
