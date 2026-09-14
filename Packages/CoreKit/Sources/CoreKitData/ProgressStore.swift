// Reads and writes stage progress, repairing the duplicates CloudKit sync can create.

import Foundation
import SwiftData

/// The persistence entry point every game uses.
///
/// Games never touch `ModelContext` directly. That keeps the duplicate repair in
/// one place — without it, a stage silently reports whichever of its rows happened
/// to come back first.
@MainActor
public final class ProgressStore {
    public let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Containers

    /// Container backed by the player's private CloudKit database.
    ///
    /// Requires the iCloud capability with CloudKit enabled on the app target.
    /// Sync is silent and needs no login screen — it rides the Apple ID already on
    /// the device — and survives deleting and reinstalling the app.
    public static func makeContainer(cloudKitEnabled: Bool = true) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            cloudKitDatabase: cloudKitEnabled ? .automatic : .none
        )
        return try ModelContainer(for: StageRecord.self, configurations: configuration)
    }

    /// Throwaway container for tests and SwiftUI previews.
    public static func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: StageRecord.self, configurations: configuration)
    }

    // MARK: - Reading

    /// Canonical progress for one stage, merging and pruning duplicates on the way.
    public func progress(forStage stageId: String) throws -> StageProgress? {
        let records = try records(forStage: stageId)
        guard let canonical = try consolidate(records, stageId: stageId) else { return nil }
        return canonical
    }

    /// Canonical progress for every stage the player has touched.
    public func allProgress() throws -> [StageProgress] {
        let all = try context.fetch(FetchDescriptor<StageRecord>())
        let grouped = Dictionary(grouping: all, by: \.stageId)

        var result: [StageProgress] = []
        for (stageId, records) in grouped {
            if let canonical = try consolidate(records, stageId: stageId) {
                result.append(canonical)
            }
        }
        return result.sorted { $0.stageId < $1.stageId }
    }

    public func summary() throws -> ProgressSummary {
        ProgressSummary(stages: try allProgress())
    }

    // MARK: - Writing

    /// Records one play attempt and returns the updated result.
    @discardableResult
    public func recordAttempt(
        stageId: String,
        score: Int = 0,
        durationSeconds: Double = 0,
        stars: Int = 0,
        cleared: Bool,
        at date: Date = Date()
    ) throws -> StageProgress {
        let existing = try progress(forStage: stageId) ?? StageProgress(stageId: stageId)
        let updated = existing.recordingAttempt(
            score: score,
            durationSeconds: durationSeconds,
            stars: stars,
            cleared: cleared,
            at: date
        )
        return try save(updated)
    }

    /// Writes a result, merging it with anything already stored for that stage.
    @discardableResult
    public func save(_ progress: StageProgress) throws -> StageProgress {
        let records = try records(forStage: progress.stageId)

        guard let first = records.first else {
            context.insert(StageRecord(progress))
            try context.save()
            return progress
        }

        // Never overwrite blindly: a sync may have landed a better result from
        // another device between the read and this write.
        let merged = StageProgress.merged([progress] + records.map(\.progress)) ?? progress
        first.apply(merged)
        records.dropFirst().forEach(context.delete)
        try context.save()
        return merged
    }

    /// Removes everything. Intended for a "reset progress" action, not for sync repair.
    public func deleteAll() throws {
        try context.delete(model: StageRecord.self)
        try context.save()
    }

    // MARK: - Duplicate repair

    private func records(forStage stageId: String) throws -> [StageRecord] {
        let descriptor = FetchDescriptor<StageRecord>(
            predicate: #Predicate { $0.stageId == stageId }
        )
        return try context.fetch(descriptor)
    }

    /// Collapses duplicate rows for a stage down to one, and returns its value.
    private func consolidate(_ records: [StageRecord], stageId: String) throws -> StageProgress? {
        guard let first = records.first else { return nil }
        guard records.count > 1 else { return first.progress }

        guard let merged = StageProgress.merged(records.map(\.progress)) else { return nil }
        first.apply(merged)
        records.dropFirst().forEach(context.delete)
        try context.save()
        return merged
    }
}
