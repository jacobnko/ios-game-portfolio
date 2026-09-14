// SwiftData storage for StageProgress, shaped to satisfy CloudKit's constraints.

import Foundation
import SwiftData

/// Persisted stage result.
///
/// Every property has a default value and none is marked `@Attribute(.unique)`.
/// Both are hard requirements of `ModelConfiguration(cloudKitDatabase:)`: CloudKit
/// has no non-null columns and no unique indexes, so a model that relies on either
/// fails to build its schema at runtime rather than at compile time.
@Model
public final class StageRecord {
    public var stageId: String = ""
    public var bestScore: Int = 0
    public var bestDurationSeconds: Double = 0
    public var starsEarned: Int = 0
    public var attemptCount: Int = 0
    public var firstClearedAt: Date?
    public var lastPlayedAt: Date?

    public init(_ progress: StageProgress) {
        apply(progress)
    }

    /// Value view of this row.
    public var progress: StageProgress {
        StageProgress(
            stageId: stageId,
            bestScore: bestScore,
            bestDurationSeconds: bestDurationSeconds,
            starsEarned: starsEarned,
            attemptCount: attemptCount,
            firstClearedAt: firstClearedAt,
            lastPlayedAt: lastPlayedAt
        )
    }

    public func apply(_ progress: StageProgress) {
        stageId = progress.stageId
        bestScore = progress.bestScore
        bestDurationSeconds = progress.bestDurationSeconds
        starsEarned = progress.starsEarned
        attemptCount = progress.attemptCount
        firstClearedAt = progress.firstClearedAt
        lastPlayedAt = progress.lastPlayedAt
    }
}
