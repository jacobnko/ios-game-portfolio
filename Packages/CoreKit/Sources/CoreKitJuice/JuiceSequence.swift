// Tracks where the player is inside an escalating run, and when that run is over.

import Foundation

/// Counts steps of a continuous action so pitch and haptic intensity can climb together.
///
/// The hard part is not counting up, it is deciding when to start over. A run that
/// never resets climbs to the ceiling and stays there, and the escalation stops
/// meaning anything. Time is passed in rather than read internally so the reset
/// rules can be tested without waiting.
public struct JuiceSequence: Sendable, Equatable {
    /// How long a gap between actions ends the current run.
    ///
    /// Long enough to survive a moment's hesitation mid-drag, short enough that
    /// starting a new pipe or a new word begins at the root note again.
    public static let defaultResetInterval: TimeInterval = 0.9

    public let resetInterval: TimeInterval
    public private(set) var currentStep: Int
    private var lastAdvanceTime: TimeInterval?

    public init(resetInterval: TimeInterval = defaultResetInterval) {
        self.resetInterval = max(0, resetInterval)
        self.currentStep = 0
        self.lastAdvanceTime = nil
    }

    /// Advances the run and returns the step to play.
    ///
    /// - Parameter time: a monotonically increasing timestamp, in seconds.
    @discardableResult
    public mutating func advance(at time: TimeInterval) -> Int {
        if let last = lastAdvanceTime, time - last <= resetInterval {
            currentStep += 1
        } else {
            // Either the first step, or the previous run timed out.
            currentStep = 0
        }
        lastAdvanceTime = time
        return currentStep
    }

    /// Ends the run immediately. Call when an action completes or is cancelled.
    ///
    /// Games should call this on an explicit boundary rather than relying on the
    /// timeout — a fast player can start a new pipe inside the reset window.
    public mutating func reset() {
        currentStep = 0
        lastAdvanceTime = nil
    }

    /// Whether a run is currently in progress at the given time.
    public func isActive(at time: TimeInterval) -> Bool {
        guard let last = lastAdvanceTime else { return false }
        return time - last <= resetInterval
    }
}
