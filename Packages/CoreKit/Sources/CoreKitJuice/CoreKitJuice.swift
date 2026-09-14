// Entry point and shared vocabulary for the feedback (juice) layer.

import Foundation

/// Namespace for the juice layer.
public enum CoreKitJuice {
    /// Bumped when the feedback contract changes in a way games must react to.
    public static let version = "0.1.0"
}

/// How strongly a feedback event should register with the player.
///
/// Games express intent with these cases rather than picking haptic styles or
/// volumes directly, so the whole portfolio stays consistent as the pipeline evolves.
public enum FeedbackWeight: Sendable, CaseIterable {
    /// A micro-step inside a sequence — one cell connected, one tick of a dial.
    case micro
    /// A milestone — a colour completed, a stage cleared.
    case milestone
    /// A rejection — an invalid move, a failed check.
    case error
}

/// A single step in an escalating action sequence.
///
/// `index` drives pitch: step 0 is the root note and each following step rises
/// by one scale degree. Sequences reset when the player starts a new action.
public struct JuiceStep: Sendable, Equatable {
    public let index: Int
    public let weight: FeedbackWeight

    public init(index: Int, weight: FeedbackWeight) {
        self.index = index
        self.weight = weight
    }
}
