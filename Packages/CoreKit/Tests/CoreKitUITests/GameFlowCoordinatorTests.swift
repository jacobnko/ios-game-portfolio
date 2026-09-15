// Verifies navigation, save timing, and — critically — that ads never interrupt
// the victory payoff.

import Testing
import Foundation
import CoreKitData
@testable import CoreKitServices
@testable import CoreKitUI

@MainActor
private func makeCoordinator() throws -> (GameFlowCoordinator, FakeAdPresenter, ConsoleAnalyticsReporter) {
    let progress = ProgressStore(container: try ProgressStore.inMemoryContainer())
    let purchases = PurchaseManager(client: FakeStoreClient(), removeAdsProductID: "com.jacobkostudio.testgame.removeads")
    let presenter = FakeAdPresenter()
    let ads = AdCoordinator(purchases: purchases, presenter: presenter, policy: .unrestricted)
    let analytics = AnalyticsHub()
    let reporter = ConsoleAnalyticsReporter()
    analytics.register(reporter)
    let coordinator = GameFlowCoordinator(progress: progress, purchases: purchases, ads: ads, analytics: analytics)
    return (coordinator, presenter, reporter)
}

// MARK: - Basic navigation

@Test @MainActor func startsEmpty() throws {
    let (coordinator, _, _) = try makeCoordinator()
    #expect(coordinator.path.isEmpty)
}

@Test @MainActor func showStageSelectResetsToOneScreen() throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    coordinator.showStageSelect()
    #expect(coordinator.path == [.stageSelect])
}

@Test @MainActor func goHomeClearsEverything() throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.showStageSelect()
    coordinator.openSettings()
    coordinator.goHome()
    #expect(coordinator.path.isEmpty)
}

@Test @MainActor func popRemovesTheTopScreenOnly() throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.showStageSelect()
    coordinator.openSettings()
    coordinator.pop()
    #expect(coordinator.path == [.stageSelect])
}

@Test @MainActor func poppingAnEmptyPathIsHarmless() throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.pop()
    #expect(coordinator.path.isEmpty)
}

@Test @MainActor func startStageAppendsAGameScreen() throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.showStageSelect()
    coordinator.startStage("s7", attempt: 2)
    #expect(coordinator.path == [.stageSelect, .game(stageID: "s7")])
}

@Test @MainActor func startingAStageLogsTheFunnelEvent() throws {
    let (coordinator, _, reporter) = try makeCoordinator()
    coordinator.startStage("s7", attempt: 3)
    let event = try #require(reporter.events.first)
    #expect(event.name == "stage_start")
    #expect(event.parameters["stage_id"] == .string("s7"))
    #expect(event.parameters["attempt"] == .int(3))
}

// MARK: - Completion

@Test @MainActor func completingAClearedStageReplacesGameWithResult() async throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    let outcome = StageOutcome(cleared: true, score: 100, stars: 3, durationSeconds: 20)
    _ = await coordinator.completeStage("s1", outcome: outcome)
    #expect(coordinator.path == [.result(stageID: "s1", outcome: outcome)])
}

@Test @MainActor func completingSavesProgress() async throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    let saved = await coordinator.completeStage(
        "s1", outcome: StageOutcome(cleared: true, score: 80, stars: 2, durationSeconds: 15)
    )
    #expect(saved.bestScore == 80)
    #expect(saved.starsEarned == 2)
    #expect(saved.isCleared)

    let reread = try coordinator.progress.progress(forStage: "s1")
    #expect(reread?.bestScore == 80)
}

@Test @MainActor func clearingFeedsTheAdPacer() async throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true))
    #expect(coordinator.ads.activity.totalClears == 1)
}

@Test @MainActor func failingDoesNotFeedTheAdPacer() async throws {
    // Only real clears count toward pacing — an abandoned attempt is not progress
    // and must not push the interstitial cadence forward.
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: false, progressPercent: 40))
    #expect(coordinator.ads.activity.totalClears == 0)
}

@Test @MainActor func clearingLogsStageClearWithAttemptCount() async throws {
    let (coordinator, _, reporter) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true, stars: 3, durationSeconds: 12))
    let event = try #require(reporter.events.last)
    #expect(event.name == "stage_clear")
    #expect(event.parameters["stars"] == .int(3))
}

@Test @MainActor func failingLogsStageAbandonWithProgress() async throws {
    let (coordinator, _, reporter) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: false, progressPercent: 65))
    let event = try #require(reporter.events.last)
    #expect(event.name == "stage_abandon")
    #expect(event.parameters["progress_pct"] == .int(65))
}

@Test @MainActor func completingWithoutAPriorGameScreenStillAppendsResult() async throws {
    // Defensive: a game that calls completeStage without having gone through
    // startStage (a bug elsewhere) should not corrupt the stack, just append.
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.showStageSelect()
    let outcome = StageOutcome(cleared: true)
    _ = await coordinator.completeStage("s1", outcome: outcome)
    #expect(coordinator.path == [.stageSelect, .result(stageID: "s1", outcome: outcome)])
}

// MARK: - The ad-timing guarantee

@Test @MainActor func completingAStageNeverTriggersAnInterstitial() async throws {
    // This is the guarantee the whole design hinges on: the victory sequence plays
    // uninterrupted on the result screen. If completeStage tried an interstitial,
    // an ad could land on top of the payoff JuiceManager was built to deliver.
    let (coordinator, presenter, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true))
    #expect(presenter.interstitialShowCount == 0)
}

@Test @MainActor func advancingFromResultAttemptsAnInterstitial() async throws {
    let (coordinator, presenter, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true))
    await coordinator.advanceFromResult(nextStageID: "s2")
    #expect(presenter.interstitialShowCount == 1)
}

@Test @MainActor func advancingToANextStageReplacesTheResultScreen() async throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true))
    await coordinator.advanceFromResult(nextStageID: "s2")
    #expect(coordinator.path == [.game(stageID: "s2")])
}

@Test @MainActor func advancingWithNoNextStageReturnsToStageSelect() async throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: false))
    await coordinator.advanceFromResult(nextStageID: nil)
    #expect(coordinator.path == [.stageSelect])
}

// MARK: - StageOutcome

@Test func stageOutcomeClampsOutOfRangeInput() {
    let outcome = StageOutcome(cleared: true, score: -5, stars: 9, durationSeconds: -2, progressPercent: 250)
    #expect(outcome.score == 0)
    #expect(outcome.stars == 3)
    #expect(outcome.durationSeconds == 0)
    #expect(outcome.progressPercent == 100)
}

// MARK: - Retry

@Test @MainActor func retryingReplacesResultWithGameForTheSameStage() async throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: false, progressPercent: 30))
    coordinator.retryStage("s1", attempt: 2)
    #expect(coordinator.path == [.game(stageID: "s1")])
}

@Test @MainActor func retryingLogsAFreshStageStart() async throws {
    let (coordinator, _, reporter) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: false))
    coordinator.retryStage("s1", attempt: 2)
    let event = try #require(reporter.events.last)
    #expect(event.name == "stage_start")
    #expect(event.parameters["attempt"] == .int(2))
}

@Test @MainActor func retryingWithoutAResultScreenStillAppendsGame() throws {
    let (coordinator, _, _) = try makeCoordinator()
    coordinator.showStageSelect()
    coordinator.retryStage("s1", attempt: 1)
    #expect(coordinator.path == [.stageSelect, .game(stageID: "s1")])
}

// MARK: - Regression: double-tapping "Next" must not race

@Test @MainActor func rapidDoubleTapOnAdvanceOnlyAdvancesOnce() async throws {
    // The interstitial attempt suspends on `await`, and the button that triggers
    // it has no built-in double-tap protection. Without a reentrancy guard, a
    // second tap firing while the first is mid-flight races a second path
    // mutation against the first.
    let (coordinator, presenter, _) = try makeCoordinator()
    presenter.interstitialDelayNanoseconds = 20_000_000 // 20ms — enough for both calls to overlap
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true))

    async let first: Void = coordinator.advanceFromResult(nextStageID: "s2")
    async let second: Void = coordinator.advanceFromResult(nextStageID: "s3")
    _ = await (first, second)

    #expect(presenter.interstitialShowCount == 1)
    #expect(coordinator.path == [.game(stageID: "s2")])
}

@Test @MainActor func advanceIsAvailableAgainAfterCompleting() async throws {
    // The guard must release once the first call finishes — otherwise every
    // stage after the first would silently refuse to advance.
    let (coordinator, presenter, _) = try makeCoordinator()
    coordinator.startStage("s1", attempt: 1)
    _ = await coordinator.completeStage("s1", outcome: StageOutcome(cleared: true))
    await coordinator.advanceFromResult(nextStageID: "s2")

    _ = await coordinator.completeStage("s2", outcome: StageOutcome(cleared: true))
    await coordinator.advanceFromResult(nextStageID: "s3")

    #expect(presenter.interstitialShowCount == 2)
    #expect(coordinator.path == [.game(stageID: "s3")])
}
