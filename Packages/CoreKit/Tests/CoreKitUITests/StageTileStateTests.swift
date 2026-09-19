// Which of the three fills a tile gets. The rule the player actually reads.

import Testing
import Foundation
import CoreKitData
import CoreKitServices
@testable import CoreKitUI

private struct TestStage: StageDescriptor {
    let id: String
    let displayNumber: Int
}

private let ladder = (1...5).map { TestStage(id: "s\($0)", displayNumber: $0) }

private func cleared(_ id: String) -> StageProgress {
    StageProgress(stageId: id, starsEarned: 3, attemptCount: 1, firstClearedAt: Date())
}

/// Mirrors the linear unlock every game in the portfolio uses so far.
private func unlockedThrough(_ count: Int) -> (TestStage) -> Bool {
    { stage in (ladder.firstIndex(where: { $0.id == stage.id }) ?? .max) < count }
}

private func grid(
    clearedThrough: Int,
    unlockedThrough count: Int,
    current: String?
) -> StageGrid<TestStage> {
    var progress: [String: StageProgress] = [:]
    for stage in ladder.prefix(clearedThrough) { progress[stage.id] = cleared(stage.id) }
    return StageGrid(
        stages: ladder,
        progress: progress,
        isUnlocked: unlockedThrough(count),
        currentStageID: current,
        onSelect: { _ in }
    )
}

@Test func aClearedStageReadsAsCleared() {
    let subject = grid(clearedThrough: 2, unlockedThrough: 3, current: "s3")
    #expect(subject.state(for: ladder[0]) == .cleared)
    #expect(subject.state(for: ladder[1]) == .cleared)
}

@Test func theFirstUncleatedUnlockedStageIsTheCurrentOne() {
    let subject = grid(clearedThrough: 2, unlockedThrough: 3, current: "s3")
    #expect(subject.state(for: ladder[2]) == .current)
}

@Test func aStageBeyondTheUnlockPointIsLocked() {
    let subject = grid(clearedThrough: 2, unlockedThrough: 3, current: "s3")
    #expect(subject.state(for: ladder[3]) == .locked)
    #expect(subject.state(for: ladder[4]) == .locked)
}

@Test func clearedBeatsLocked() {
    // A stage can be cleared and then fall outside a narrowed unlock window —
    // a reset that only cleared part of the progress, say. It must still read
    // as cleared rather than reverting to a padlock the player already opened.
    let subject = grid(clearedThrough: 3, unlockedThrough: 1, current: nil)
    #expect(subject.state(for: ladder[2]) == .cleared)
}

@Test func anUnlockedUncleatedStageThatIsNotCurrentReadsAsOpen() {
    // Only one tile may wear the amber treatment. Without a distinct `.open`
    // state, every unlocked-but-uncleared stage would claim to be "where you
    // are", which is the whole signal the amber tile carries.
    let subject = grid(clearedThrough: 1, unlockedThrough: 5, current: "s2")
    #expect(subject.state(for: ladder[1]) == .current)
    #expect(subject.state(for: ladder[2]) == .open)
    #expect(subject.state(for: ladder[3]) == .open)
}

@Test func noTileIsCurrentWhenThereIsNoCurrentStage() {
    // Every stage cleared: the ladder is finished and nothing should pulse.
    let subject = grid(clearedThrough: 5, unlockedThrough: 5, current: nil)
    for stage in ladder {
        #expect(subject.state(for: stage) == .cleared)
    }
}
