// Owns navigation and ties progress, purchases, ads and analytics to it.

import Foundation
import CoreKitData
import CoreKitServices

/// Drives the shared screens.
///
/// Games own their own `NavigationStack(path:)` bound to `path` and their own
/// `.navigationDestination(for: GameRoute.self)` switch; this type only decides
/// *what* the path should be and *when* side effects (saving, ad pacing,
/// analytics) happen around a navigation change. It never touches SwiftUI itself.
@MainActor
@Observable
public final class GameFlowCoordinator {
    /// Navigation stack. Plain (not `private(set)`) so a `NavigationStack`'s
    /// binding can write to it directly — swipe-to-back needs a real two-way
    /// binding, and a swipe-driven pop has no side effects to protect anyway,
    /// the same as `pop()` below. Controlled transitions (`startStage`,
    /// `completeStage`, `advanceFromResult`) remain the primary API; this exists
    /// for `NavigationStack(path: $coordinator.path)` in the composing app.
    public var path: [GameRoute] = []

    public let progress: ProgressStore
    public let purchases: PurchaseManager
    public let ads: AdCoordinator
    public let analytics: AnalyticsHub

    /// Guards `advanceFromResult` against re-entrant calls.
    ///
    /// The interstitial attempt is an `await`, and the button that triggers it
    /// has no built-in double-tap protection — a second tap while the first ad
    /// attempt is still in flight would race a second `path` mutation against
    /// the first, and whichever finished last would silently win. This is the
    /// same class of bug as the overlapping full-screen ad presentations fixed
    /// in Phase 1 (docs/AUDIT.md catalogue item G) — one shared piece of
    /// in-flight state, two callers.
    private var isAdvancing = false

    public init(
        progress: ProgressStore,
        purchases: PurchaseManager,
        ads: AdCoordinator,
        analytics: AnalyticsHub = .shared
    ) {
        self.progress = progress
        self.purchases = purchases
        self.ads = ads
        self.analytics = analytics
    }

    // MARK: - Navigation

    public func showStageSelect() {
        path = [.stageSelect]
    }

    public func openSettings() {
        path.append(.settings)
    }

    public func goHome() {
        path.removeAll()
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Enters gameplay for one stage.
    public func startStage(_ stageID: String, attempt: Int) {
        path.append(.game(stageID: stageID))
        analytics.log(GameEvent.stageStarted(stageID: stageID, attempt: attempt))
    }

    /// Called when the player taps "Retry" on a failed result screen.
    ///
    /// Replaces `.result` with `.game` for the same stage and logs a fresh
    /// `stage_start` — a retry is a new attempt, and the funnel needs to see it
    /// as one to make `stage_abandon` rates per attempt number meaningful.
    public func retryStage(_ stageID: String, attempt: Int) {
        if case .result(let current, _) = path.last, current == stageID {
            path[path.count - 1] = .game(stageID: stageID)
        } else {
            path.append(.game(stageID: stageID))
        }
        analytics.log(GameEvent.stageStarted(stageID: stageID, attempt: attempt))
    }

    // MARK: - Completion

    /// Called by the game the moment an attempt ends, win or lose.
    ///
    /// Saves progress, feeds the ad pacer, logs the funnel event, and swaps the
    /// `.game` entry for `.result` so the back gesture returns to stage select
    /// rather than mid-play. Does **not** touch ads beyond recording the clear —
    /// see `advanceFromResult`.
    @discardableResult
    public func completeStage(_ stageID: String, outcome: StageOutcome) async -> StageProgress {
        let saved: StageProgress
        do {
            saved = try progress.recordAttempt(
                stageId: stageID,
                score: outcome.score,
                durationSeconds: outcome.durationSeconds,
                stars: outcome.stars,
                cleared: outcome.cleared
            )
        } catch {
            // A save failure here is exactly the kind of survivable bug that stays
            // invisible for months if swallowed with `try?` — see
            // docs/architecture/analytics-events.md. The player still sees their
            // result; the miss only becomes visible on the next launch when the
            // stage looks uncleared, so it has to be reported now.
            analytics.record(error, context: ["stage_id": stageID, "cleared": "\(outcome.cleared)"])
            saved = StageProgress(stageId: stageID)
        }

        if outcome.cleared {
            ads.recordStageClear()
            analytics.log(GameEvent.stageCleared(
                stageID: stageID, attempt: saved.attemptCount,
                durationSeconds: outcome.durationSeconds, stars: outcome.stars
            ))
        } else {
            analytics.log(GameEvent.stageAbandoned(
                stageID: stageID, attempt: saved.attemptCount,
                durationSeconds: outcome.durationSeconds, progressPercent: outcome.progressPercent
            ))
        }

        if case .game(let current) = path.last, current == stageID {
            path[path.count - 1] = .result(stageID: stageID, outcome: outcome)
        } else {
            path.append(.result(stageID: stageID, outcome: outcome))
        }

        return saved
    }

    /// Called when the player taps "Next" (or equivalent) on the result screen.
    ///
    /// The interstitial attempt lives here rather than inside `completeStage` on
    /// purpose: `completeStage` runs the instant the stage ends, which is exactly
    /// when the victory sequence needs the screen to itself. An ad dropped on top
    /// of that payoff — the one moment `JuiceManager` was built to make feel
    /// earned — would step on it. Waiting for an explicit "continue" tap means the
    /// catharsis always finishes uninterrupted, ad or no ad.
    ///
    /// - Parameter nextStageID: the stage to enter next, or `nil` to return to
    ///   stage select (a fail, or the last stage of the game).
    public func advanceFromResult(nextStageID: String?) async {
        guard !isAdvancing else { return }
        isAdvancing = true
        defer { isAdvancing = false }

        await ads.showInterstitialIfAllowed()

        if let nextStageID {
            path[path.count - 1] = .game(stageID: nextStageID)
        } else {
            showStageSelect()
        }
    }
}
