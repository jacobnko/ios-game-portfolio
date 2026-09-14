// Exercises the store against a real SwiftData container, duplicates included.

import Testing
import Foundation
import SwiftData
@testable import CoreKitData

@MainActor
private func makeStore() throws -> ProgressStore {
    ProgressStore(container: try ProgressStore.inMemoryContainer())
}

@Test @MainActor func unknownStageHasNoProgress() throws {
    let store = try makeStore()
    #expect(try store.progress(forStage: "missing") == nil)
}

@Test @MainActor func savingThenReadingRoundTrips() throws {
    let store = try makeStore()
    let written = StageProgress(stageId: "s1", bestScore: 120, bestDurationSeconds: 31.5, starsEarned: 2, attemptCount: 4)
    try store.save(written)

    let read = try store.progress(forStage: "s1")
    #expect(read == written)
}

@Test @MainActor func recordingAttemptsAccumulates() throws {
    let store = try makeStore()
    try store.recordAttempt(stageId: "s1", score: 10, cleared: false)
    try store.recordAttempt(stageId: "s1", score: 40, durationSeconds: 22, stars: 2, cleared: true)
    let result = try store.recordAttempt(stageId: "s1", score: 20, durationSeconds: 18, stars: 3, cleared: true)

    #expect(result.attemptCount == 3)
    #expect(result.bestScore == 40)          // best, not latest
    #expect(result.bestDurationSeconds == 18)
    #expect(result.starsEarned == 3)
    #expect(result.isCleared)
}

@Test @MainActor func duplicateRowsAreMergedAndPruned() throws {
    // This is what CloudKit sync actually produces: two devices each created a row
    // for the same stage, and there is no unique constraint to stop them.
    let store = try makeStore()
    let context = store.container.mainContext
    context.insert(StageRecord(StageProgress(stageId: "s1", bestScore: 100, starsEarned: 1, attemptCount: 3)))
    context.insert(StageRecord(StageProgress(stageId: "s1", bestScore: 60, starsEarned: 3, attemptCount: 7)))
    try context.save()

    let merged = try store.progress(forStage: "s1")
    #expect(merged?.bestScore == 100)
    #expect(merged?.starsEarned == 3)
    #expect(merged?.attemptCount == 7)

    // The extra row must actually be gone, not just ignored on read.
    let remaining = try context.fetch(FetchDescriptor<StageRecord>())
    #expect(remaining.count == 1)
}

@Test @MainActor func savingOverADuplicateSetStillMerges() throws {
    let store = try makeStore()
    let context = store.container.mainContext
    context.insert(StageRecord(StageProgress(stageId: "s1", bestScore: 500)))
    context.insert(StageRecord(StageProgress(stageId: "s1", starsEarned: 3)))
    try context.save()

    // A weaker write must not destroy a better result that synced in.
    let saved = try store.save(StageProgress(stageId: "s1", bestScore: 10, starsEarned: 1))
    #expect(saved.bestScore == 500)
    #expect(saved.starsEarned == 3)
    #expect(try context.fetch(FetchDescriptor<StageRecord>()).count == 1)
}

@Test @MainActor func allProgressConsolidatesEveryStage() throws {
    let store = try makeStore()
    let context = store.container.mainContext
    context.insert(StageRecord(StageProgress(stageId: "s1", bestScore: 10)))
    context.insert(StageRecord(StageProgress(stageId: "s1", bestScore: 30)))
    context.insert(StageRecord(StageProgress(stageId: "s2", bestScore: 70)))
    try context.save()

    let all = try store.allProgress()
    #expect(all.count == 2)
    #expect(all.map(\.stageId) == ["s1", "s2"])   // sorted, stable for UI
    #expect(all[0].bestScore == 30)
}

@Test @MainActor func summaryReflectsStoredStages() throws {
    let store = try makeStore()
    try store.recordAttempt(stageId: "s1", score: 100, stars: 3, cleared: true)
    try store.recordAttempt(stageId: "s2", score: 20, stars: 0, cleared: false)

    let summary = try store.summary()
    #expect(summary.clearedCount == 1)
    #expect(summary.totalStars == 3)
    #expect(summary.totalScore == 120)
}

@Test @MainActor func deleteAllClearsTheStore() throws {
    let store = try makeStore()
    try store.recordAttempt(stageId: "s1", cleared: true)
    try store.deleteAll()
    #expect(try store.allProgress().isEmpty)
}

@Test @MainActor func inMemoryContainerLeavesNothingOnDisk() throws {
    // Guards the test setup itself: a disk- or CloudKit-backed container in tests
    // would leak state between runs and need an iCloud account on CI.
    let container = try ProgressStore.inMemoryContainer()
    #expect(container.configurations.first?.isStoredInMemoryOnly == true)
}
