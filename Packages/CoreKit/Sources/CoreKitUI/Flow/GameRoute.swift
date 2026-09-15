// The five screens every game shares, and how they chain together.

import Foundation

/// One screen in the shared flow.
///
/// `.game` carries a stage id but no content — every game's gameplay view is
/// completely bespoke (a SwiftUI grid, a SpriteKit scene), so `CoreKitUI` cannot
/// render it. The app's own `navigationDestination` switches on this case and
/// inserts its own view; `CoreKitUI` owns the other four.
public enum GameRoute: Hashable, Sendable {
    case stageSelect
    case game(stageID: String)
    case result(stageID: String, outcome: StageOutcome)
    case settings
}

/// What happened at the end of one attempt.
///
/// Carries enough for the result screen, the progress store, and the analytics
/// funnel — the three things that consume it — without carrying UI state.
public struct StageOutcome: Sendable, Hashable {
    public let cleared: Bool
    public let score: Int
    public let stars: Int
    public let durationSeconds: Double
    /// 0...100. Only meaningful when `cleared` is false — it is what turns
    /// "stage_abandon" from a count into a signal that tells apart "gave up
    /// immediately" from "lost right at the end", which call for different fixes.
    public let progressPercent: Int

    public init(cleared: Bool, score: Int = 0, stars: Int = 0, durationSeconds: Double = 0, progressPercent: Int = 0) {
        self.cleared = cleared
        self.score = max(0, score)
        self.stars = max(0, min(3, stars))
        self.durationSeconds = max(0, durationSeconds)
        self.progressPercent = max(0, min(100, progressPercent))
    }
}
