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

    // Everything below defaults to "off", which renders exactly the original mallet
    // tone; `legacyTonesAreBitIdentical` pins that. Textured sounds — glass cracking,
    // a thud, a charging zap — are these layers, still synthesised, still zero bytes.

    /// Pitch at the end of the tone. The glide is exponential, so it moves by equal
    /// musical intervals per unit time — a linear glide sounds like it rushes at the top.
    public var endFrequency: Double?
    /// Replaces the default sine-plus-third timbre when non-empty. Non-integer ratios
    /// with fast-decaying upper partials are what make a tone read as glass or metal.
    public var partials: [TonePartial] = []
    /// A filtered noise layer, for everything with no pitch: cracks, impacts, sizzle.
    public var noise: NoiseLayer?

    /// This tone gliding to `endFrequency`.
    public func gliding(to endFrequency: Double) -> ToneRecipe {
        var copy = self
        copy.endFrequency = max(0, endFrequency)
        return copy
    }

    public func withPartials(_ partials: [TonePartial]) -> ToneRecipe {
        var copy = self
        copy.partials = partials
        return copy
    }

    public func withNoise(_ noise: NoiseLayer) -> ToneRecipe {
        var copy = self
        copy.noise = noise
        return copy
    }

    /// A pitchless burst: just the noise layer under the envelope.
    public static func noiseBurst(_ noise: NoiseLayer, duration: TimeInterval, gain: Float, attack: Double = 0.005, release: Double = 0.95) -> ToneRecipe {
        ToneRecipe(frequency: 0, duration: duration, gain: gain, attack: attack, release: release).withNoise(noise)
    }
}

/// One sine component of a tone, relative to the tone's (possibly gliding) pitch.
public struct TonePartial: Sendable, Hashable {
    /// Frequency as a multiple of the tone's pitch. Need not be an integer.
    public let ratio: Double
    public let gain: Double
    /// Time constant of this partial's own exponential decay, in seconds; 0 sustains.
    /// Higher partials dying first is most of what makes a strike sound real.
    public let decay: TimeInterval

    public init(ratio: Double, gain: Double, decay: TimeInterval = 0) {
        self.ratio = max(0, ratio)
        self.gain = gain
        self.decay = max(0, decay)
    }

    /// Partials of a struck free bar (glass, a xylophone key): inharmonic ratios
    /// 1 : 2.76 : 5.40 : 8.93, each quieter and shorter than the one below.
    public static func struckBar(decay: TimeInterval) -> [TonePartial] {
        [
            TonePartial(ratio: 1, gain: 1, decay: decay),
            TonePartial(ratio: 2.76, gain: 0.5, decay: decay * 0.55),
            TonePartial(ratio: 5.40, gain: 0.28, decay: decay * 0.3),
            TonePartial(ratio: 8.93, gain: 0.15, decay: decay * 0.18),
        ]
    }
}

/// Filtered white noise. Seeded, so a recipe always renders the same samples — it is a
/// cache key, and a cached buffer must be the sound the recipe describes.
public struct NoiseLayer: Sendable, Hashable {
    public enum Filter: Sendable, Hashable {
        /// Keeps the rumble: thuds and landings.
        case lowPass
        /// Keeps the hiss: shatter tails, sizzle.
        case highPass
        /// Keeps a band around the cutoff: cracks and ticks.
        case bandPass
    }

    public let gain: Double
    public let filter: Filter
    /// Filter frequency in Hz.
    public let cutoff: Double
    /// Filter resonance. 0.707 is flat; higher rings at the cutoff.
    public let q: Double
    /// Time constant of the layer's own exponential decay, in seconds; 0 sustains.
    public let decay: TimeInterval
    public let seed: UInt64

    public init(gain: Double, filter: Filter, cutoff: Double, q: Double = 0.707, decay: TimeInterval = 0, seed: UInt64 = 0x5EED) {
        self.gain = gain
        self.filter = filter
        self.cutoff = max(1, cutoff)
        self.q = max(0.1, q)
        self.decay = max(0, decay)
        self.seed = seed
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
        if endFrequency != nil || !partials.isEmpty || noise != nil {
            return renderLayered(sampleRate: sampleRate)
        }
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

// MARK: - Layered synthesis

extension ToneRecipe {
    /// The path for any recipe that uses a glide, partials or noise. The legacy path
    /// above is left untouched so existing tones stay bit-identical.
    func renderLayered(sampleRate: Double) -> [Float] {
        guard sampleRate > 0, duration > 0 else { return [] }
        let frameCount = Int((duration * sampleRate).rounded())
        guard frameCount > 0 else { return [] }

        let attackFrames = Int(Double(frameCount) * attack)
        let releaseFrames = Int(Double(frameCount) * release)
        let sustainEnd = frameCount - releaseFrames
        let hasTone = frequency > 0
        let glideRatio = (endFrequency.map { $0 > 0 && frequency > 0 ? $0 / frequency : 1 }) ?? 1
        let components = partials.isEmpty
            ? [TonePartial(ratio: 1, gain: 1), TonePartial(ratio: 3, gain: 0.18)]
            : partials

        var noiseSource = noise.map { NoiseVoice(layer: $0, sampleRate: sampleRate) }
        var phase = 0.0
        var samples = [Float](repeating: 0, count: frameCount)

        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            var value = 0.0

            if hasTone {
                for component in components {
                    var partial = component.gain * sin(component.ratio * phase)
                    if component.decay > 0 { partial *= exp(-t / component.decay) }
                    value += partial
                }
                // Accumulate phase rather than computing sin(2πf(t)t): with a moving
                // pitch, the latter jumps and clicks.
                let pitch = frequency * pow(glideRatio, Double(frame) / Double(frameCount))
                phase += 2 * Double.pi * pitch / sampleRate
            }
            if noiseSource != nil {
                value += noiseSource!.next(at: t)
            }

            let envelope: Double
            if frame < attackFrames {
                envelope = Double(frame) / Double(max(1, attackFrames))
            } else if frame >= sustainEnd, releaseFrames > 0 {
                let progress = Double(frame - sustainEnd) / Double(releaseFrames)
                envelope = pow(1.0 - progress, 2.2)
            } else {
                envelope = 1.0
            }

            // Hard limit: stacked layers must never wrap into a loud digital click.
            let sample = Float(value * envelope) * gain * 0.85
            samples[frame] = min(1, max(-1, sample))
        }
        return samples
    }
}

/// White noise through one biquad filter (RBJ cookbook), with its own decay.
private struct NoiseVoice {
    let gain: Double
    let decay: TimeInterval
    var rng: SplitMix64
    let b0, b1, b2, a1, a2: Double
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    init(layer: NoiseLayer, sampleRate: Double) {
        gain = layer.gain
        decay = layer.decay
        rng = SplitMix64(seed: layer.seed)
        // Keep the cutoff under Nyquist or the coefficients go unstable.
        let cutoff = min(layer.cutoff, sampleRate * 0.45)
        let w0 = 2 * Double.pi * cutoff / sampleRate
        let cosW = cos(w0)
        let alpha = sin(w0) / (2 * layer.q)
        let a0 = 1 + alpha
        let (n0, n1, n2): (Double, Double, Double)
        switch layer.filter {
        case .lowPass: (n0, n1, n2) = ((1 - cosW) / 2, 1 - cosW, (1 - cosW) / 2)
        case .highPass: (n0, n1, n2) = ((1 + cosW) / 2, -(1 + cosW), (1 + cosW) / 2)
        case .bandPass: (n0, n1, n2) = (alpha, 0, -alpha)
        }
        b0 = n0 / a0; b1 = n1 / a0; b2 = n2 / a0
        a1 = -2 * cosW / a0; a2 = (1 - alpha) / a0
    }

    mutating func next(at t: Double) -> Double {
        let x = rng.next(in: -1...1)
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        let envelope = decay > 0 ? exp(-t / decay) : 1
        return y * gain * envelope
    }
}
