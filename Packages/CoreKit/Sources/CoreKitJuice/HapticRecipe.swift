// Pure description of one haptic burst, independent of any platform API.

import Foundation

/// A platform-agnostic recipe for a single haptic burst.
///
/// This type holds no CoreHaptics references on purpose: the mapping from game
/// intent to physical feedback is the part worth testing, and keeping it pure
/// means it runs on any host without a device or simulator.
public struct HapticRecipe: Sendable, Equatable {
    /// How hard the burst feels, 0...1.
    public let intensity: Float
    /// How crisp the burst feels, 0...1. Higher reads as a click, lower as a thud.
    public let sharpness: Float
    /// Number of transient events in the burst.
    public let eventCount: Int
    /// Gap between transient events when `eventCount` is greater than one.
    public let eventSpacing: TimeInterval

    public init(intensity: Float, sharpness: Float, eventCount: Int, eventSpacing: TimeInterval) {
        self.intensity = intensity.clampedToUnitRange
        self.sharpness = sharpness.clampedToUnitRange
        self.eventCount = max(1, eventCount)
        self.eventSpacing = max(0, eventSpacing)
    }
}

extension HapticRecipe {
    /// How many steps a `micro` sequence takes to reach full intensity.
    ///
    /// Chosen to match a typical puzzle action length — a pipe run or a dial turn
    /// is usually finished inside this many steps, so the escalation lands with it.
    public static let defaultEscalationSpan = 8

    /// Builds the recipe for a feedback intent.
    ///
    /// - Parameters:
    ///   - weight: what the event means to the player.
    ///   - stepIndex: position inside an escalating sequence. Only `micro` uses it;
    ///     milestones and errors must feel identical every time so they stay readable.
    ///   - escalationSpan: how many steps `micro` takes to climb from base to peak.
    public static func make(
        for weight: FeedbackWeight,
        stepIndex: Int = 0,
        escalationSpan: Int = defaultEscalationSpan
    ) -> HapticRecipe {
        switch weight {
        case .micro:
            // Rises alongside the audio pitch so the hand and the ear agree.
            let span = max(1, escalationSpan)
            let progress = min(1, max(0, Float(stepIndex) / Float(span)))
            return HapticRecipe(
                intensity: 0.35 + 0.35 * progress,
                sharpness: 0.45 + 0.20 * progress,
                eventCount: 1,
                eventSpacing: 0
            )

        case .milestone:
            // Two events read as a "thump-thump" — heavier than any micro step can get.
            return HapticRecipe(intensity: 1.0, sharpness: 0.55, eventCount: 2, eventSpacing: 0.07)

        case .error:
            // Tight and sharp. Deliberately unlike the milestone so it is never mistaken for success.
            return HapticRecipe(intensity: 0.8, sharpness: 1.0, eventCount: 2, eventSpacing: 0.04)
        }
    }

    /// Convenience for the common case of feeding a sequence step straight through.
    public static func make(for step: JuiceStep, escalationSpan: Int = defaultEscalationSpan) -> HapticRecipe {
        make(for: step.weight, stepIndex: step.index, escalationSpan: escalationSpan)
    }

    /// Total wall-clock length of the burst.
    public var duration: TimeInterval {
        eventSpacing * TimeInterval(eventCount - 1)
    }
}

private extension Float {
    var clampedToUnitRange: Float { min(1, max(0, self)) }
}
