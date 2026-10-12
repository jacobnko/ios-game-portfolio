// Verifies the beat timeline, its cue playhead, the slapstick curves and the performer.

import Testing
import Foundation
import CoreGraphics
@testable import CoreKitJuice

private enum Gag: Hashable, Sendable {
    case refuse, hold, sink, result
}

private let tap = HapticRecipe(intensity: 0.4, sharpness: 0.5, eventCount: 1, eventSpacing: 0)
private let thud = HapticRecipe(intensity: 1.0, sharpness: 0.4, eventCount: 1, eventSpacing: 0)

private func gag(total: TimeInterval = 0) -> BeatTimeline<Gag> {
    BeatTimeline(
        phases: [
            .refuse: JuicePhase(start: 0, duration: 0.4),
            .hold: JuicePhase(start: 1.2, duration: 0.5),
            .sink: JuicePhase(start: 2.55, duration: 0.9),
            .result: JuicePhase(start: 4.8, duration: 0.3),
        ],
        cues: [
            JuiceCue(at: 3.45, haptic: thud),
            JuiceCue(at: 0, haptic: tap),
            JuiceCue(at: 2.6, haptic: tap),
            JuiceCue(at: 3.0, haptic: tap),
        ],
        total: total
    )
}

// MARK: - Timeline

@Test func cuesAreSortedByTime() {
    #expect(gag().cues.map(\.time) == [0, 2.6, 3.0, 3.45])
}

@Test func cuesSharingATimeKeepTheirGivenOrder() {
    let low = ToneRecipe(frequency: 220, duration: 0.1, gain: 0.5)
    let high = ToneRecipe(frequency: 880, duration: 0.1, gain: 0.5)
    let timeline = BeatTimeline<Gag>(phases: [:], cues: [JuiceCue(at: 1, tone: high), JuiceCue(at: 1, tone: low)])
    #expect(timeline.cues.map(\.tone) == [high, low])
}

@Test func totalNeverCutsOffTheLastBeatOrCue() {
    #expect(gag(total: 1).total == 5.1)
    let cueOnly = BeatTimeline<Gag>(phases: [:], cues: [JuiceCue(at: 2)], total: 0)
    #expect(cueOnly.total == 2)
    #expect(gag(total: 6).total == 6)
}

@Test func beatProgressAndStartEndQueries() {
    let timeline = gag()
    #expect(timeline.progress(of: .hold, at: 1.0) == nil)
    #expect(abs(timeline.progress(of: .hold, at: 1.45)! - 0.5) < 1e-9)
    #expect(timeline.hasStarted(.sink, at: 2.55))
    #expect(!timeline.hasEnded(.sink, at: 3.44))
    #expect(timeline.hasEnded(.sink, at: 3.46))
}

@Test func unscheduledBeatsAreAbsentNotCrashing() {
    let timeline = BeatTimeline<Gag>(phases: [.refuse: JuicePhase(start: 0, duration: 1)])
    #expect(timeline.progress(of: .sink, at: 0.5) == nil)
    #expect(!timeline.hasStarted(.sink, at: 10))
    #expect(timeline.cues(during: .sink).isEmpty)
}

@Test func theComicPauseCanBeProvenSilent() {
    let timeline = gag()
    #expect(timeline.cues(during: .hold).isEmpty)
    #expect(timeline.cues(during: .sink).map(\.time) == [2.6, 3.0])
}

@Test func runningWindow() {
    let timeline = gag(total: 6)
    #expect(!timeline.isRunning(at: -0.01))
    #expect(timeline.isRunning(at: 0))
    #expect(!timeline.isRunning(at: 6))
}

// MARK: - Playhead

@Test func aCueAtZeroFiresOnTheFirstTick() {
    var playhead = gag().playhead()
    #expect(playhead.advance(to: 0).map(\.time) == [0])
}

@Test func aDroppedFrameDeliversEveryCueItCrossed() {
    var playhead = gag().playhead()
    _ = playhead.advance(to: 0)
    #expect(playhead.advance(to: 3.1).map(\.time) == [2.6, 3.0])
    #expect(playhead.nextCueTime == 3.45)
}

@Test func cuesNeverFireTwice() {
    var playhead = gag().playhead()
    _ = playhead.advance(to: 10)
    #expect(playhead.isExhausted)
    #expect(playhead.advance(to: 10).isEmpty)
}

@Test func aClockRunningBackwardsFiresNothing() {
    var playhead = gag().playhead()
    _ = playhead.advance(to: 2.7)
    #expect(playhead.advance(to: 1.0).isEmpty)
}

@Test func skippingDropsTheCuesItJumpsOver() {
    var playhead = gag().playhead()
    _ = playhead.advance(to: 0)
    playhead.jump(to: 3.45)
    // The landing cue at exactly the target still plays; the two before it do not.
    #expect(playhead.advance(to: 3.45).map(\.time) == [3.45])
}

// MARK: - Slapstick curves

@Test func wobbleRestsExactlyAtBothEnds() {
    let wobble = WobbleCurve(amplitude: 4.2, swings: 3, duration: 0.28)
    #expect(wobble.offset(at: 0) == 0)
    #expect(wobble.offset(at: 0.28) == 0)
    #expect(wobble.offset(at: 5) == 0)
    #expect(wobble.offset(at: -1) == 0)
}

@Test func wobbleDecaysAndStaysInsideItsAmplitude() {
    let wobble = WobbleCurve(amplitude: 4.2, swings: 3, duration: 0.3)
    let samples = stride(from: 0.0, through: 0.3, by: 0.001).map { abs(wobble.offset(at: $0)) }
    #expect(samples.allSatisfy { $0 <= 4.2 })
    // The first swing must be the biggest — a wobble that grows reads as a malfunction.
    let firstThird = samples.prefix(100).max()!
    let lastThird = samples.suffix(100).max()!
    #expect(firstThird > lastThird * 2)
}

@Test func wobbleSwingsTheRequestedNumberOfTimes() {
    let wobble = WobbleCurve(amplitude: 1, swings: 3, duration: 1)
    let values = stride(from: 0.0005, to: 1, by: 0.001).map { wobble.offset(at: $0) }
    let signChanges = zip(values, values.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
    #expect(signChanges == 5)
}

@Test func wobbleStaggerIsLinear() {
    #expect(WobbleCurve.startTime(forIndex: 2, stagger: 0.06) == 0.12)
    #expect(WobbleCurve.startTime(forIndex: -1, stagger: 0.06) == 0)
}

@Test func squashReachesItsTargetAndReleasesExactly() {
    let squash = SquashCurve(squashX: 1.03, squashY: 0.94)
    #expect(squash.squashing(progress: 0) == CGSize(width: 1, height: 1))
    let full = squash.squashing(progress: 1)
    #expect(abs(full.width - 1.03) < 1e-9 && abs(full.height - 0.94) < 1e-9)
    #expect(squash.releasing(progress: 0) == full)
    #expect(squash.releasing(progress: 1) == CGSize(width: 1, height: 1))
    #expect(squash.releasing(progress: 7) == CGSize(width: 1, height: 1))
}

@Test func sinkStartsReluctantlyAndLandsOnItsDrop() {
    let sink = SinkCurve(drop: 77.88, tiltDegrees: -2.5, bounceHeight: 5.31, bounceDuration: 0.15)
    #expect(sink.offset(progress: 0) == 0)
    #expect(sink.offset(progress: 1) == 77.88)
    // Ease-in: the first half covers a quarter of the distance.
    #expect(abs(sink.offset(progress: 0.5) - 77.88 / 4) < 1e-9)
    #expect(sink.rotationDegrees(progress: 1) == -2.5)
}

@Test func landingBounceGoesUpAndSettlesToZero() {
    let sink = SinkCurve(drop: 10, tiltDegrees: 0, bounceHeight: 5.31, bounceDuration: 0.15)
    #expect(sink.bounce(at: 0) == 0)
    #expect(abs(sink.bounce(at: 0.075) + 5.31) < 1e-9)
    #expect(sink.bounce(at: 0.15) == 0)
    #expect(sink.bounce(at: 1) == 0)
}

@Test func rollInDeceleratesToRestAndExposesItsEntrySpeed() {
    let roll = RollInCurve(travel: 10.62, rollDuration: 0.5, radius: 2.8)
    #expect(roll.distance(at: 0) == 0)
    #expect(roll.distance(at: 0.5) == 10.62)
    #expect(roll.distance(at: 2) == 10.62)
    // Uniform deceleration: distance = v0·t − ½·a·t², with v0 = 2·travel/T.
    #expect(abs(roll.entrySpeed - 42.48) < 1e-9)
    // Slowing down: the second half covers a third as much as the first.
    let firstHalf = roll.distance(at: 0.25)
    #expect(abs((roll.distance(at: 0.5) - firstHalf) * 3 - firstHalf) < 1e-9)
}

@Test func rollInRollsWithoutSlippingThenTopples() {
    let roll = RollInCurve(travel: .pi * 2, rollDuration: 0.5, radius: 1, toppleDegrees: 90, toppleDuration: 0.2)
    // One circumference of travel is one full turn, counter-clockwise.
    #expect(abs(roll.rotationDegrees(at: 0.5) + 360) < 1e-9)
    #expect(abs(roll.rotationDegrees(at: 0.7) + 450) < 1e-9)
    #expect(abs(roll.rotationDegrees(at: 3) + 450) < 1e-9)
    #expect(roll.totalDuration == 0.7)
}

// MARK: - Playback

@Test func existingRecipesFallBackToTheirOwnGenerator() {
    #expect(HapticRecipe.make(for: .micro, stepIndex: 8).fallbackWeight == .micro)
    #expect(HapticRecipe.make(for: .milestone).fallbackWeight == .milestone)
    #expect(HapticRecipe.make(for: .error).fallbackWeight == .error)
}

@Test func explicitRecipesPickTheClosestGenerator() {
    #expect(tap.fallbackWeight == .micro)
    #expect(HapticRecipe(intensity: 0.7, sharpness: 0.9, eventCount: 1, eventSpacing: 0).fallbackWeight == .error)
    #expect(thud.fallbackWeight == .milestone)
}

@MainActor
private func eventually(timeout: TimeInterval = 2, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

@Test @MainActor func performerFiresEveryCueAndFinishes() async {
    let performer = BeatPerformer()
    performer.playsFeedback = false
    var finished = 0
    let timeline = BeatTimeline<Gag>(
        phases: [.refuse: JuicePhase(start: 0, duration: 0.05)],
        cues: [JuiceCue(at: 0, haptic: tap), JuiceCue(at: 0.03, haptic: thud)],
        total: 0.08
    )
    performer.play(timeline) { finished += 1 }
    #expect(performer.isPlaying)
    #expect(await eventually { finished == 1 })
    #expect(performer.firedCues.map(\.time) == [0, 0.03])
    #expect(!performer.isPlaying)
    #expect(performer.elapsed() == nil)
}

@Test @MainActor func performerSkipDropsTheCuesInBetween() async {
    let performer = BeatPerformer()
    performer.playsFeedback = false
    var finished = false
    let timeline = BeatTimeline<Gag>(
        phases: [.result: JuicePhase(start: 5, duration: 0.05)],
        cues: [JuiceCue(at: 0, haptic: tap), JuiceCue(at: 2, haptic: tap), JuiceCue(at: 5, haptic: thud)]
    )
    performer.play(timeline) { finished = true }
    #expect(await eventually { performer.firedCues.count == 1 })
    performer.skip(to: 5)
    #expect(performer.elapsed()! >= 4.99)
    #expect(await eventually { finished })
    #expect(performer.firedCues.map(\.time) == [0, 5])
}

@Test @MainActor func performerCancelNeverReportsFinishing() async {
    let performer = BeatPerformer()
    performer.playsFeedback = false
    var finished = false
    performer.play(BeatTimeline<Gag>(phases: [.sink: JuicePhase(start: 0, duration: 0.05)])) { finished = true }
    performer.cancel()
    try? await Task.sleep(for: .milliseconds(120))
    #expect(!finished)
    #expect(!performer.isPlaying)
}

@Test @MainActor func replayingStartsOverWithoutFinishingTheFirstRun() async {
    let performer = BeatPerformer()
    performer.playsFeedback = false
    var finishes: [String] = []
    let timeline = BeatTimeline<Gag>(phases: [.sink: JuicePhase(start: 0, duration: 0.05)])
    performer.play(timeline) { finishes.append("first") }
    performer.play(timeline) { finishes.append("second") }
    #expect(await eventually { !finishes.isEmpty })
    try? await Task.sleep(for: .milliseconds(80))
    #expect(finishes == ["second"])
}
