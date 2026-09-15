// Verifies the musical and envelope maths that the audio feel depends on.

import Testing
import Foundation
@testable import CoreKitJuice

// MARK: - MusicalScale

@Test func pentatonicStartsAtRoot() {
    #expect(MusicalScale.pentatonicMajor.semitoneOffset(forStep: 0) == 0)
}

@Test func scaleContinuesIntoTheNextOctave() {
    let scale = MusicalScale.pentatonicMajor
    // Five degrees per octave, so step 5 is the root one octave up.
    #expect(scale.semitoneOffset(forStep: 5) == 12)
    #expect(scale.semitoneOffset(forStep: 10) == 24)
}

@Test func scaleRisesMonotonically() {
    let offsets = (0...20).map { MusicalScale.pentatonicMajor.semitoneOffset(forStep: $0) }
    #expect(zip(offsets, offsets.dropFirst()).allSatisfy { $0 <= $1 })
}

@Test func scaleStopsClimbingAtTheCeiling() {
    // Past roughly two octaves the tone turns shrill and stops reading as reward.
    let scale = MusicalScale.pentatonicMajor
    let ceiling = scale.semitoneOffset(forStep: scale.ceilingStep())
    #expect(scale.semitoneOffset(forStep: 999) == ceiling)
    #expect(ceiling == 24)
}

@Test func negativeStepsAreTreatedAsTheRoot() {
    #expect(MusicalScale.pentatonicMajor.semitoneOffset(forStep: -5) == 0)
}

@Test(arguments: MusicalScale.allCases)
func everyScaleBeginsOnTheRoot(scale: MusicalScale) {
    #expect(scale.degrees.first == 0)
    #expect(scale.semitoneOffset(forStep: 0) == 0)
}

@Test func anOctaveDoublesTheFrequency() {
    let base = Pitch.frequency(root: Pitch.c5, semitones: 0)
    let octave = Pitch.frequency(root: Pitch.c5, semitones: 12)
    #expect(abs(octave - base * 2) < 0.001)
}

// MARK: - ToneRecipe

@Test func microTonesRiseWithTheStep() {
    let frequencies = (0...8).map { ToneRecipe.make(for: .micro, stepIndex: $0).frequency }
    #expect(zip(frequencies, frequencies.dropFirst()).allSatisfy { $0 < $1 })
}

@Test func milestoneIsDistinctFromEveryMicroStep() {
    // Arrival must be audibly distinct from progress, the same rule the haptics keep.
    // It is set apart by weight rather than by height: a run that has climbed two
    // octaves would have to go higher still to win on pitch, and that is shrill.
    // So the milestone drops back to the octave and wins on length and volume.
    let micro = ToneRecipe.make(for: .micro, stepIndex: 4)
    let milestone = ToneRecipe.make(for: .milestone)
    #expect(milestone.duration > micro.duration)
    #expect(milestone.gain > micro.gain)
    #expect(milestone.frequency != micro.frequency)
}

@Test func errorSitsBelowTheRoot() {
    let root = ToneRecipe.make(for: .micro, stepIndex: 0).frequency
    #expect(ToneRecipe.make(for: .error).frequency < root)
}

@Test func envelopeFractionsCannotOverlap() {
    let r = ToneRecipe(frequency: 440, duration: 0.1, gain: 1, attack: 0.8, release: 0.9)
    #expect(r.attack + r.release <= 1.0)
}

@Test func recipeClampsOutOfRangeInput() {
    let r = ToneRecipe(frequency: -10, duration: -1, gain: 5, attack: -1, release: 9)
    #expect(r.frequency == 0)
    #expect(r.duration == 0)
    #expect(r.gain == 1)
    #expect(r.attack == 0)
}

// MARK: - Rendering

@Test func renderedLengthMatchesDuration() {
    let r = ToneRecipe.make(for: .micro)
    let samples = r.renderSamples(sampleRate: 44_100)
    #expect(samples.count == Int((r.duration * 44_100).rounded()))
}

@Test func renderedToneNeverClips() {
    // Clipping is audible as a crackle and is the most common synthesis mistake.
    for weight in FeedbackWeight.allCases {
        let samples = ToneRecipe.make(for: weight, stepIndex: 4).renderSamples(sampleRate: 44_100)
        #expect(samples.allSatisfy { abs($0) <= 1.0 })
    }
}

@Test func envelopeRemovesStartAndEndClicks() {
    // A tone that starts or ends at full amplitude pops. The envelope must taper both ends.
    let samples = ToneRecipe.make(for: .milestone).renderSamples(sampleRate: 44_100)
    #expect(samples.count > 100)
    #expect(abs(samples.first!) < 0.01)
    #expect(abs(samples.last!) < 0.01)
}

@Test func degenerateRecipesRenderNothing() {
    #expect(ToneRecipe(frequency: 0, duration: 0.1, gain: 1).renderSamples(sampleRate: 44_100).isEmpty)
    #expect(ToneRecipe.make(for: .micro).renderSamples(sampleRate: 0).isEmpty)
}

// MARK: - JuiceSequence

@Test func sequenceStartsAtZero() {
    var s = JuiceSequence()
    #expect(s.advance(at: 0) == 0)
}

@Test func sequenceClimbsWhileActionsAreContinuous() {
    var s = JuiceSequence(resetInterval: 1.0)
    #expect(s.advance(at: 0.0) == 0)
    #expect(s.advance(at: 0.3) == 1)
    #expect(s.advance(at: 0.6) == 2)
}

@Test func sequenceResetsAfterAPause() {
    var s = JuiceSequence(resetInterval: 0.5)
    s.advance(at: 0.0)
    s.advance(at: 0.2)
    // A gap longer than the reset interval means a new run, so a new pipe starts
    // back at the root note instead of continuing someone else's melody.
    #expect(s.advance(at: 1.5) == 0)
}

@Test func gapExactlyAtTheIntervalStillCounts() {
    var s = JuiceSequence(resetInterval: 0.5)
    s.advance(at: 0.0)
    #expect(s.advance(at: 0.5) == 1)
}

@Test func explicitResetEndsTheRunImmediately() {
    var s = JuiceSequence(resetInterval: 10)
    s.advance(at: 0.0)
    s.advance(at: 0.1)
    s.reset()
    #expect(s.currentStep == 0)
    #expect(s.advance(at: 0.2) == 0)
}

@Test func sequenceReportsActivityCorrectly() {
    var s = JuiceSequence(resetInterval: 0.5)
    #expect(s.isActive(at: 0) == false)
    s.advance(at: 1.0)
    #expect(s.isActive(at: 1.2) == true)
    #expect(s.isActive(at: 2.0) == false)
}

// MARK: - Regression: pitch depends on more than the step

@Test func differentScalesProduceDifferentPitches() {
    // The tone player caches rendered buffers. Caching them by step alone meant a
    // game that switched scale kept hearing the old scale's notes with no way to
    // tell why, so the cache key has to cover everything this depends on.
    //
    // Compared across a run rather than at one step: individual degrees coincide
    // between scales (step 3 is 7 semitones in both pentatonics), so a single-step
    // check would pass for the wrong reason.
    let steps = 0...5
    let major = steps.map { ToneRecipe.make(for: .micro, stepIndex: $0, scale: .pentatonicMajor).frequency }
    let minor = steps.map { ToneRecipe.make(for: .micro, stepIndex: $0, scale: .pentatonicMinor).frequency }
    #expect(major != minor)
}

@Test func differentRootsProduceDifferentPitchesForTheSameStep() {
    let step = 2
    let c5 = ToneRecipe.make(for: .micro, stepIndex: step, root: Pitch.c5).frequency
    let a4 = ToneRecipe.make(for: .micro, stepIndex: step, root: Pitch.a4).frequency
    #expect(c5 != a4)
}

@Test func identicalTonesBeyondTheCeilingShareOneRecipe() {
    // The tone player caches by recipe. Steps past the pitch ceiling all render the
    // same waveform, so they must compare equal — otherwise a long drag mints a
    // fresh ~19 KB buffer per step for audio that never changes.
    let ceiling = MusicalScale.pentatonicMajor.ceilingStep()
    let atCeiling = ToneRecipe.make(for: .micro, stepIndex: ceiling)
    let farBeyond = ToneRecipe.make(for: .micro, stepIndex: 5_000)
    #expect(atCeiling == farBeyond)
    #expect(atCeiling.hashValue == farBeyond.hashValue)
}

@Test func milestoneAndErrorIgnoreTheStepEntirely() {
    // Same reason: these do not vary by step, so they must not key separately.
    #expect(ToneRecipe.make(for: .milestone, stepIndex: 0) == ToneRecipe.make(for: .milestone, stepIndex: 40))
    #expect(ToneRecipe.make(for: .error, stepIndex: 0) == ToneRecipe.make(for: .error, stepIndex: 40))
}

@Test func theStepConvenienceMatchesTheExplicitToneCall() {
    let step = JuiceStep(index: 4, weight: .micro)
    #expect(ToneRecipe.make(for: step) == ToneRecipe.make(for: .micro, stepIndex: 4))
    #expect(ToneRecipe.make(for: step, scale: .major) == ToneRecipe.make(for: .micro, stepIndex: 4, scale: .major))
}
