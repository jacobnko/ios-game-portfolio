// Value type holding one stage's result, plus the merge rules sync depends on.

import Foundation

/// A player's best result on a single stage.
///
/// This is a plain value, separate from the SwiftData model, because the merge
/// rules below are the part that must be right and they need to be testable
/// without a store, a container, or an iCloud account.
public struct StageProgress: Sendable, Equatable {
    public var stageId: String
    public var bestScore: Int
    /// Best completion time in seconds. Zero means "never completed".
    public var bestDurationSeconds: Double
    public var starsEarned: Int
    public var attemptCount: Int
    public var firstClearedAt: Date?
    public var lastPlayedAt: Date?

    public init(
        stageId: String,
        bestScore: Int = 0,
        bestDurationSeconds: Double = 0,
        starsEarned: Int = 0,
        attemptCount: Int = 0,
        firstClearedAt: Date? = nil,
        lastPlayedAt: Date? = nil
    ) {
        self.stageId = stageId
        self.bestScore = max(0, bestScore)
        self.bestDurationSeconds = max(0, bestDurationSeconds)
        self.starsEarned = max(0, starsEarned)
        self.attemptCount = max(0, attemptCount)
        self.firstClearedAt = firstClearedAt
        self.lastPlayedAt = lastPlayedAt
    }

    public var isCleared: Bool { firstClearedAt != nil }
}

public extension StageProgress {
    /// Combines two records of the same stage into one, keeping the player's best.
    ///
    /// CloudKit-backed SwiftData cannot enforce uniqueness, so two devices can each
    /// create a row for the same stage and both will survive the sync. Merging is
    /// the only defence, and it has to be **idempotent**: sync settles over several
    /// passes and this runs again each time. That is why `attemptCount` takes the
    /// maximum rather than the sum — summing would inflate on every re-merge.
    static func merged(_ lhs: StageProgress, _ rhs: StageProgress) -> StageProgress {
        precondition(lhs.stageId == rhs.stageId, "merging records of different stages")

        return StageProgress(
            stageId: lhs.stageId,
            bestScore: max(lhs.bestScore, rhs.bestScore),
            bestDurationSeconds: bestDuration(lhs.bestDurationSeconds, rhs.bestDurationSeconds),
            starsEarned: max(lhs.starsEarned, rhs.starsEarned),
            attemptCount: max(lhs.attemptCount, rhs.attemptCount),
            firstClearedAt: earliest(lhs.firstClearedAt, rhs.firstClearedAt),
            lastPlayedAt: latest(lhs.lastPlayedAt, rhs.lastPlayedAt)
        )
    }

    /// Folds any number of records of one stage into a single canonical result.
    static func merged<S: Sequence>(_ records: S) -> StageProgress? where S.Element == StageProgress {
        var iterator = records.makeIterator()
        guard var result = iterator.next() else { return nil }
        while let next = iterator.next() { result = merged(result, next) }
        return result
    }

    /// Records one play attempt on top of an existing result.
    func recordingAttempt(
        score: Int,
        durationSeconds: Double,
        stars: Int,
        cleared: Bool,
        at date: Date
    ) -> StageProgress {
        StageProgress(
            stageId: stageId,
            bestScore: max(bestScore, score),
            bestDurationSeconds: cleared ? bestDuration(bestDurationSeconds, durationSeconds) : bestDurationSeconds,
            starsEarned: max(starsEarned, stars),
            attemptCount: attemptCount + 1,
            firstClearedAt: cleared ? earliest(firstClearedAt, date) : firstClearedAt,
            lastPlayedAt: latest(lastPlayedAt, date)
        )
    }
}

/// Zero means "no time recorded", so it must never win a "lowest is best" comparison.
private func bestDuration(_ lhs: Double, _ rhs: Double) -> Double {
    switch (lhs > 0, rhs > 0) {
    case (true, true): min(lhs, rhs)
    case (true, false): lhs
    case (false, true): rhs
    case (false, false): 0
    }
}

private func earliest(_ lhs: Date?, _ rhs: Date?) -> Date? {
    guard let lhs else { return rhs }
    guard let rhs else { return lhs }
    return min(lhs, rhs)
}

private func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
    guard let lhs else { return rhs }
    guard let rhs else { return lhs }
    return max(lhs, rhs)
}

/// Portfolio-wide totals, derived rather than stored.
///
/// Storing an aggregate alongside the records would mean two sources of truth that
/// sync independently and can disagree. Deriving it cannot drift.
public struct ProgressSummary: Sendable, Equatable {
    public let clearedCount: Int
    public let totalStars: Int
    public let totalScore: Int
    public let lastPlayedAt: Date?

    public init<S: Sequence>(stages: S) where S.Element == StageProgress {
        var cleared = 0, stars = 0, score = 0
        var last: Date?
        for stage in stages {
            if stage.isCleared { cleared += 1 }
            stars += stage.starsEarned
            score += stage.bestScore
            last = latest(last, stage.lastPlayedAt)
        }
        self.clearedCount = cleared
        self.totalStars = stars
        self.totalScore = score
        self.lastPlayedAt = last
    }
}
