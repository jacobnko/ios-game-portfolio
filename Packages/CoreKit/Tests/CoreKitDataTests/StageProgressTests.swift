// Verifies the merge rules that keep CloudKit duplicates from corrupting progress.

import Testing
import Foundation
@testable import CoreKitData

private let t0 = Date(timeIntervalSince1970: 1_000_000)
private let t1 = Date(timeIntervalSince1970: 2_000_000)

@Test func mergeKeepsTheBestOfEachField() {
    let a = StageProgress(stageId: "1", bestScore: 100, bestDurationSeconds: 30, starsEarned: 2, attemptCount: 5, firstClearedAt: t1, lastPlayedAt: t0)
    let b = StageProgress(stageId: "1", bestScore: 80, bestDurationSeconds: 20, starsEarned: 3, attemptCount: 9, firstClearedAt: t0, lastPlayedAt: t1)

    let merged = StageProgress.merged(a, b)
    #expect(merged.bestScore == 100)
    #expect(merged.bestDurationSeconds == 20)   // lower time is better
    #expect(merged.starsEarned == 3)
    #expect(merged.firstClearedAt == t0)        // earliest clear
    #expect(merged.lastPlayedAt == t1)          // latest activity
}

@Test func mergeIsIdempotent() {
    // Sync settles over several passes and re-merges the same rows each time.
    // A non-idempotent rule (summing attempts, say) would inflate on every pass.
    let a = StageProgress(stageId: "1", bestScore: 100, attemptCount: 5, lastPlayedAt: t0)
    let b = StageProgress(stageId: "1", bestScore: 80, attemptCount: 9, lastPlayedAt: t1)

    let once = StageProgress.merged(a, b)
    let twice = StageProgress.merged(once, b)
    let thrice = StageProgress.merged(twice, a)
    #expect(once == twice)
    #expect(twice == thrice)
}

@Test func mergeIsCommutative() {
    let a = StageProgress(stageId: "1", bestScore: 10, bestDurationSeconds: 55, starsEarned: 1, firstClearedAt: t1)
    let b = StageProgress(stageId: "1", bestScore: 40, bestDurationSeconds: 12, starsEarned: 3, lastPlayedAt: t1)
    #expect(StageProgress.merged(a, b) == StageProgress.merged(b, a))
}

@Test func unsetDurationNeverWins() {
    // Zero means "never completed". A naive min() would make it the best time.
    let played = StageProgress(stageId: "1", bestDurationSeconds: 42)
    let untouched = StageProgress(stageId: "1", bestDurationSeconds: 0)
    #expect(StageProgress.merged(played, untouched).bestDurationSeconds == 42)
    #expect(StageProgress.merged(untouched, played).bestDurationSeconds == 42)
    #expect(StageProgress.merged(untouched, untouched).bestDurationSeconds == 0)
}

@Test func mergingASequenceFoldsEverything() {
    let records = (1...5).map { StageProgress(stageId: "1", bestScore: $0 * 10, attemptCount: $0) }
    let merged = StageProgress.merged(records)
    #expect(merged?.bestScore == 50)
    #expect(merged?.attemptCount == 5)
}

@Test func mergingAnEmptySequenceYieldsNothing() {
    #expect(StageProgress.merged([StageProgress]()) == nil)
}

@Test func recordingAnAttemptAlwaysCountsIt() {
    let start = StageProgress(stageId: "1")
    let failed = start.recordingAttempt(score: 0, durationSeconds: 9, stars: 0, cleared: false, at: t0)
    #expect(failed.attemptCount == 1)
    #expect(failed.isCleared == false)
    // A failed run must not register a best time.
    #expect(failed.bestDurationSeconds == 0)
}

@Test func clearingSetsTheFirstClearDateOnce() {
    let first = StageProgress(stageId: "1").recordingAttempt(score: 10, durationSeconds: 40, stars: 1, cleared: true, at: t1)
    let again = first.recordingAttempt(score: 90, durationSeconds: 20, stars: 3, cleared: true, at: t0)
    #expect(first.firstClearedAt == t1)
    #expect(again.firstClearedAt == t0)  // an earlier clear synced in from another device
    #expect(again.bestDurationSeconds == 20)
    #expect(again.attemptCount == 2)
}

@Test func progressClampsNegativeInput() {
    let p = StageProgress(stageId: "1", bestScore: -5, bestDurationSeconds: -1, starsEarned: -3, attemptCount: -9)
    #expect(p.bestScore == 0)
    #expect(p.bestDurationSeconds == 0)
    #expect(p.starsEarned == 0)
    #expect(p.attemptCount == 0)
}

@Test func summaryDerivesTotals() {
    let stages = [
        StageProgress(stageId: "1", bestScore: 100, starsEarned: 3, firstClearedAt: t0, lastPlayedAt: t0),
        StageProgress(stageId: "2", bestScore: 50, starsEarned: 1, firstClearedAt: t1, lastPlayedAt: t1),
        StageProgress(stageId: "3", bestScore: 10, starsEarned: 0, lastPlayedAt: t0),  // attempted, not cleared
    ]
    let summary = ProgressSummary(stages: stages)
    #expect(summary.clearedCount == 2)
    #expect(summary.totalStars == 4)
    #expect(summary.totalScore == 160)
    #expect(summary.lastPlayedAt == t1)
}

@Test func emptySummaryIsZero() {
    let summary = ProgressSummary(stages: [StageProgress]())
    #expect(summary.clearedCount == 0)
    #expect(summary.totalStars == 0)
    #expect(summary.lastPlayedAt == nil)
}
