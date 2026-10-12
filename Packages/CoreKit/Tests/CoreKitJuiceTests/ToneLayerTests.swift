// Verifies glides, partials and filtered noise by measuring the samples they render.

import Testing
import Foundation
@testable import CoreKitJuice

private let rate = 44_100.0

/// Frequency estimated from upward zero crossings, over a slice of the samples.
private func pitch(_ samples: [Float], from start: Int, count: Int) -> Double {
    let slice = Array(samples[start..<min(samples.count, start + count)])
    let crossings = zip(slice, slice.dropFirst()).filter { $0 < 0 && $1 >= 0 }.count
    return Double(crossings) * rate / Double(slice.count)
}

/// Crossings per second in either direction — a rough brightness measure for noise.
private func crossingRate(_ samples: [Float]) -> Double {
    let crossings = zip(samples, samples.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
    return Double(crossings) * rate / Double(samples.count)
}

/// Signal power at one frequency (Goertzel), averaged over the whole buffer.
private func power(_ samples: [Float], at frequency: Double) -> Double {
    let coefficient = 2 * cos(2 * Double.pi * frequency / rate)
    var s1 = 0.0, s2 = 0.0
    for sample in samples {
        let s0 = Double(sample) + coefficient * s1 - s2
        s2 = s1; s1 = s0
    }
    return (s1 * s1 + s2 * s2 - coefficient * s1 * s2) / Double(samples.count)
}

private func rms(_ samples: ArraySlice<Float>) -> Double {
    (samples.reduce(0) { $0 + Double($1 * $1) } / Double(max(1, samples.count))).squareRoot()
}

// MARK: - Glide

@Test func aGlideStartsAtItsPitchAndEndsAtItsTarget() {
    let tone = ToneRecipe(frequency: 440, duration: 0.5, gain: 0.8, attack: 0, release: 0)
        .withPartials([TonePartial(ratio: 1, gain: 1)])
        .gliding(to: 880)
    let samples = tone.renderSamples(sampleRate: rate)
    let window = Int(rate * 0.04)
    #expect(abs(pitch(samples, from: 0, count: window) - 450) < 40)
    #expect(abs(pitch(samples, from: samples.count - window, count: window) - 870) < 60)
}

@Test func aFallingGlideFalls() {
    let tone = ToneRecipe(frequency: 880, duration: 0.4, gain: 0.8, attack: 0, release: 0)
        .withPartials([TonePartial(ratio: 1, gain: 1)])
        .gliding(to: 220)
    let samples = tone.renderSamples(sampleRate: rate)
    let window = Int(rate * 0.05)
    #expect(pitch(samples, from: 0, count: window) > pitch(samples, from: samples.count - window, count: window) * 2.5)
}

// MARK: - Partials

@Test func anInharmonicPartialSoundsAtItsRatio() {
    let tone = ToneRecipe(frequency: 400, duration: 0.3, gain: 0.8, attack: 0, release: 0)
        .withPartials([TonePartial(ratio: 2.76, gain: 1)])
    let samples = tone.renderSamples(sampleRate: rate)
    #expect(abs(pitch(samples, from: 0, count: samples.count) - 1104) < 20)
}

@Test func aPartialsOwnDecayFadesIt() {
    let tone = ToneRecipe(frequency: 600, duration: 0.5, gain: 0.8, attack: 0, release: 0)
        .withPartials([TonePartial(ratio: 1, gain: 1, decay: 0.08)])
    let samples = tone.renderSamples(sampleRate: rate)
    let tenth = samples.count / 10
    #expect(rms(samples[0..<tenth]) > rms(samples[(samples.count - tenth)...]) * 20)
}

@Test func struckBarPartialsDieFastestAtTheTop() {
    let bar = TonePartial.struckBar(decay: 0.4)
    #expect(bar.map(\.ratio) == [1, 2.76, 5.40, 8.93])
    #expect(zip(bar, bar.dropFirst()).allSatisfy { $0.decay > $1.decay && $0.gain > $1.gain })
}

// MARK: - Noise

private func noise(_ filter: NoiseLayer.Filter, cutoff: Double, q: Double = 0.707, seed: UInt64 = 1) -> [Float] {
    ToneRecipe.noiseBurst(NoiseLayer(gain: 1, filter: filter, cutoff: cutoff, q: q, seed: seed), duration: 0.3, gain: 0.8, attack: 0, release: 0)
        .renderSamples(sampleRate: rate)
}

@Test func noiseNeedsNoPitch() {
    let samples = noise(.highPass, cutoff: 2_000)
    #expect(samples.count == Int(rate * 0.3))
    #expect(rms(samples[...]) > 0.01)
}

@Test func noiseIsDeterministicPerSeed() {
    #expect(noise(.bandPass, cutoff: 3_000, seed: 7) == noise(.bandPass, cutoff: 3_000, seed: 7))
    #expect(noise(.bandPass, cutoff: 3_000, seed: 7) != noise(.bandPass, cutoff: 3_000, seed: 8))
}

@Test func filtersShapeTheNoise() {
    // A low-passed rumble crosses zero far less often than a high-passed hiss.
    let rumble = crossingRate(noise(.lowPass, cutoff: 200))
    let hiss = crossingRate(noise(.highPass, cutoff: 6_000))
    #expect(hiss > rumble * 8)
    // A band keeps its centre and drops what is an octave and more either side.
    let band = noise(.bandPass, cutoff: 2_000, q: 4)
    let centre = power(band, at: 2_000)
    #expect(centre > power(band, at: 500) * 10)
    #expect(centre > power(band, at: 8_000) * 10)
}

@Test func aCutoffAboveNyquistStaysStable() {
    let samples = noise(.lowPass, cutoff: 40_000)
    #expect(samples.allSatisfy { $0.isFinite })
}

@Test func noiseDecays() {
    let samples = ToneRecipe.noiseBurst(NoiseLayer(gain: 1, filter: .highPass, cutoff: 2_000, decay: 0.05), duration: 0.4, gain: 0.8, attack: 0, release: 0)
        .renderSamples(sampleRate: rate)
    let tenth = samples.count / 10
    #expect(rms(samples[0..<tenth]) > rms(samples[(samples.count - tenth)...]) * 20)
}

// MARK: - Safety

@Test func stackedLayersNeverClip() {
    let loud = ToneRecipe(frequency: 300, duration: 0.2, gain: 1, attack: 0, release: 0)
        .withPartials([TonePartial(ratio: 1, gain: 3), TonePartial(ratio: 2, gain: 3)])
        .withNoise(NoiseLayer(gain: 4, filter: .bandPass, cutoff: 1_000, q: 8))
    #expect(loud.renderSamples(sampleRate: rate).allSatisfy { abs($0) <= 1 })
}

@Test func layeredTonesEndInSilence() {
    // A sound that stops on a non-zero sample clicks.
    let tone = ToneRecipe(frequency: 880, duration: 0.2, gain: 0.8).gliding(to: 1_200)
        .withNoise(NoiseLayer(gain: 0.5, filter: .highPass, cutoff: 3_000))
    let samples = tone.renderSamples(sampleRate: rate)
    #expect(abs(samples.last ?? 1) < 0.01)
    #expect(abs(samples.first ?? 1) < 0.01)
}

@Test func everyLayerIsPartOfTheCacheKey() {
    // The player caches buffers by recipe; two different sounds must never share one.
    let base = ToneRecipe(frequency: 440, duration: 0.2, gain: 0.5)
    let variants: Set<ToneRecipe> = [
        base,
        base.gliding(to: 880),
        base.withPartials(TonePartial.struckBar(decay: 0.2)),
        base.withNoise(NoiseLayer(gain: 0.5, filter: .highPass, cutoff: 2_000, seed: 1)),
        base.withNoise(NoiseLayer(gain: 0.5, filter: .highPass, cutoff: 2_000, seed: 2)),
    ]
    #expect(variants.count == 5)
}

@Test func aSilentRecipeRendersNothing() {
    #expect(ToneRecipe(frequency: 0, duration: 0.2, gain: 0.5).renderSamples(sampleRate: rate).isEmpty)
    #expect(ToneRecipe(frequency: 440, duration: 0, gain: 0.5).gliding(to: 880).renderSamples(sampleRate: rate).isEmpty)
}
