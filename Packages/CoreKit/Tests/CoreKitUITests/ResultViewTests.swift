// Result's own logic: what counts as a record, and how a duration reads.

import Testing
import CoreKitServices
@testable import CoreKitUI

private func view(cleared: Bool, seconds: Double, best: Double?) -> ResultView {
    ResultView(
        outcome: StageOutcome(cleared: cleared, score: 100, stars: 3, durationSeconds: seconds),
        bestSeconds: best,
        onAdvance: {},
        onRetry: {}
    )
}

@Test func aFirstClearIsAlwaysARecord() {
    // No previous best means nothing to beat, not "no record".
    #expect(view(cleared: true, seconds: 30, best: nil).isNewRecord)
}

@Test func beatingThePreviousBestIsARecord() {
    #expect(view(cleared: true, seconds: 20, best: 30).isNewRecord)
}

@Test func matchingThePreviousBestIsNotARecord() {
    // Strictly faster, or the banner fires on every replay of a stage the
    // player has already perfected.
    #expect(!view(cleared: true, seconds: 30, best: 30).isNewRecord)
}

@Test func aSlowerRunIsNotARecord() {
    #expect(!view(cleared: true, seconds: 45, best: 30).isNewRecord)
}

@Test func aFailedAttemptIsNeverARecord() {
    // A fail carries durationSeconds too, and with no previous best it would
    // otherwise be announced as a record for giving up quickly.
    #expect(!view(cleared: false, seconds: 5, best: nil).isNewRecord)
    #expect(!view(cleared: false, seconds: 1, best: 30).isNewRecord)
}

// MARK: - Duration formatting

@Test func secondsReadAsPlainSeconds() {
    #expect(ResultView.formatted(7.42) == "7.4")
    #expect(ResultView.formatted(0) == "0.0")
}

@Test func pastAMinuteItSwitchesToMinutesAndSeconds() {
    #expect(ResultView.formatted(61.5) == "1:01.5")
    #expect(ResultView.formatted(125) == "2:05.0")
}

@Test func secondsAreZeroPaddedPastAMinute() {
    // "1:5.0" would read as five seconds past the minute at a glance.
    #expect(ResultView.formatted(65) == "1:05.0")
}

@Test func aNegativeDurationDoesNotRenderAsNegative() {
    // Clock skew between start and finish has produced negatives before.
    #expect(ResultView.formatted(-10) == "0.0")
}

// MARK: - Ladder progress

@Test func ladderFractionIsClearedOverTotal() {
    #expect(LadderProgress(cleared: 24, total: 60).fraction == 24.0 / 60.0)
}

@Test func anEmptyLadderDoesNotDivideByZero() {
    // NaN would be handed straight to a frame width, which crashes rather than
    // drawing an empty bar.
    #expect(LadderProgress(cleared: 0, total: 0).fraction == 0)
}

@Test func theLadderBarNeverOverfills() {
    #expect(LadderProgress(cleared: 99, total: 60).fraction == 1)
}
