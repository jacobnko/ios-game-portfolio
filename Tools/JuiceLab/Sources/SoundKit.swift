// Starting-point synthesised sound effects built from ToneRecipe layers, for tuning by ear.

import Foundation
import CoreKitJuice

/// Eleven effect voices, each a single `ToneRecipe`, pitched in steps of two semitones
/// from a base note. These are sketches to be judged on a device — a game copies the
/// ones that work into its own constants rather than importing the lab.
enum SoundKit {
    enum Voice: String, CaseIterable, Identifiable {
        case tink, shimmer, crack, shatter, thump, chord, ping, tonk, thud, zap, sizzle
        var id: String { rawValue }
    }

    /// Base note candidates. A5 is the design spec's provisional choice.
    static let bases: [(name: String, hz: Double)] = [("E5 659", 659.26), ("A5 880", 880), ("C6 1047", 1046.5)]

    static func pitch(base: Double, step: Double) -> Double {
        base * pow(2, 2 * step / 12)
    }

    static func recipe(_ voice: Voice, step: Double = 0, base: Double = 880) -> ToneRecipe {
        let f = pitch(base: base, step: step)
        switch voice {
        case .tink:
            // A small glass strike: struck-bar partials, short.
            return ToneRecipe(frequency: f, duration: 0.18, gain: 0.5, attack: 0.004, release: 0.95)
                .withPartials(TonePartial.struckBar(decay: 0.09))
        case .shimmer:
            // A quick upward glissando with a little glass on top.
            return ToneRecipe(frequency: f, duration: 0.16, gain: 0.35, attack: 0.05, release: 0.6)
                .withPartials([TonePartial(ratio: 1, gain: 1), TonePartial(ratio: 2.76, gain: 0.25, decay: 0.05)])
                .gliding(to: f * 1.5)
        case .crack:
            // A dry tick: a narrow band of noise, almost no length.
            return ToneRecipe.noiseBurst(NoiseLayer(gain: 1.6, filter: .bandPass, cutoff: min(9_000, f * 4), q: 3, decay: 0.008, seed: 11),
                                         duration: 0.035, gain: 0.6)
        case .shatter:
            // Glass partials ringing under a hiss that dies faster than they do.
            return ToneRecipe(frequency: f, duration: 0.45, gain: 0.4, attack: 0.003, release: 0.97)
                .withPartials(TonePartial.struckBar(decay: 0.14))
                .withNoise(NoiseLayer(gain: 0.9, filter: .highPass, cutoff: 2_500, decay: 0.07, seed: 23))
        case .thump:
            // A soft low hit: a falling sine and a puff of low noise.
            return ToneRecipe(frequency: 95, duration: 0.24, gain: 0.8, attack: 0.004, release: 0.95)
                .withPartials([TonePartial(ratio: 1, gain: 1, decay: 0.09)])
                .gliding(to: 55)
                .withNoise(NoiseLayer(gain: 0.6, filter: .lowPass, cutoff: 220, decay: 0.04, seed: 31))
        case .chord:
            // A major triad on one note, long decay — the "everything cleared" ring.
            let third = pow(2, 4.0 / 12), fifth = pow(2, 7.0 / 12)
            return ToneRecipe(frequency: f, duration: 1.2, gain: 0.4, attack: 0.01, release: 0.9)
                .withPartials([
                    TonePartial(ratio: 1, gain: 1, decay: 0.6),
                    TonePartial(ratio: third, gain: 0.8, decay: 0.55),
                    TonePartial(ratio: fifth, gain: 0.7, decay: 0.5),
                    TonePartial(ratio: 2, gain: 0.25, decay: 0.3),
                ])
        case .ping:
            // A clean bell-ish ping for the combo label.
            return ToneRecipe(frequency: f, duration: 0.25, gain: 0.45, attack: 0.004, release: 0.95)
                .withPartials([TonePartial(ratio: 1, gain: 1, decay: 0.16), TonePartial(ratio: 2, gain: 0.3, decay: 0.08)])
        case .tonk:
            // A hollow knock, lower and duller than tink.
            return ToneRecipe(frequency: f / 4, duration: 0.12, gain: 0.6, attack: 0.003, release: 0.95)
                .withPartials(TonePartial.struckBar(decay: 0.04))
                .withNoise(NoiseLayer(gain: 0.3, filter: .lowPass, cutoff: 900, decay: 0.02, seed: 41))
        case .thud:
            // A landing: lower and longer than thump, more weight than pitch.
            return ToneRecipe(frequency: 70, duration: 0.32, gain: 0.9, attack: 0.004, release: 0.95)
                .withPartials([TonePartial(ratio: 1, gain: 1, decay: 0.12)])
                .gliding(to: 42)
                .withNoise(NoiseLayer(gain: 0.8, filter: .lowPass, cutoff: 160, decay: 0.07, seed: 53))
        case .zap:
            // A charging sweep: bright partials rising six semitones, a fizz underneath.
            return ToneRecipe(frequency: f, duration: 0.14, gain: 0.4, attack: 0.02, release: 0.5)
                .withPartials([TonePartial(ratio: 1, gain: 1), TonePartial(ratio: 2, gain: 0.5), TonePartial(ratio: 3, gain: 0.3)])
                .gliding(to: f * pow(2, 6.0 / 12))
                .withNoise(NoiseLayer(gain: 0.25, filter: .bandPass, cutoff: 4_000, q: 1.5, seed: 61))
        case .sizzle:
            // The tail after a burn: thin hiss fading out.
            return ToneRecipe.noiseBurst(NoiseLayer(gain: 0.9, filter: .highPass, cutoff: 5_000, decay: 0.12, seed: 71),
                                         duration: 0.35, gain: 0.45, attack: 0.01)
        }
    }
}
