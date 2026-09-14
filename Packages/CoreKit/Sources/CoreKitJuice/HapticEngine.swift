// Plays HapticRecipe bursts on device, with graceful degradation everywhere else.

import Foundation

#if canImport(CoreHaptics) && canImport(UIKit)
import CoreHaptics
import UIKit
#endif

/// Single entry point for haptic feedback across the portfolio.
///
/// Games never talk to CoreHaptics directly. They describe intent with
/// `FeedbackWeight` and this type decides how it feels.
@MainActor
public final class HapticEngine {
    public static let shared = HapticEngine()

    /// Player-facing switch. Games bind this to the haptics toggle in Settings.
    public var isEnabled: Bool = true

    /// Whether real CoreHaptics playback is available on this device.
    ///
    /// `false` means bursts fall back to the simpler impact generators, or become
    /// no-ops on platforms without haptics at all. Callers do not need to check this.
    public private(set) var supportsRichHaptics: Bool = false

    #if canImport(CoreHaptics) && canImport(UIKit)
    private var engine: CHHapticEngine?
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var heavyGenerator: UIImpactFeedbackGenerator?
    private var rigidGenerator: UIImpactFeedbackGenerator?
    #endif

    private init() {
        #if canImport(CoreHaptics) && canImport(UIKit)
        supportsRichHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #endif
    }

    /// Warms the hardware up. Call when a gameplay screen appears.
    ///
    /// Without this the very first burst of a session arrives late, which is exactly
    /// the burst that sets the player's expectation for how responsive the game feels.
    public func prepare() {
        guard isEnabled else { return }
        #if canImport(CoreHaptics) && canImport(UIKit)
        if supportsRichHaptics {
            startEngineIfNeeded()
        } else {
            prepareFallbackGenerators()
        }
        #endif
    }

    /// Releases hardware resources. Call when leaving gameplay or on backgrounding.
    public func teardown() {
        #if canImport(CoreHaptics) && canImport(UIKit)
        engine?.stop(completionHandler: nil)
        engine = nil
        lightGenerator = nil
        heavyGenerator = nil
        rigidGenerator = nil
        #endif
    }

    /// Plays the feedback for one intent.
    public func play(_ weight: FeedbackWeight, stepIndex: Int = 0) {
        play(HapticRecipe.make(for: weight, stepIndex: stepIndex), weight: weight)
    }

    /// Plays the feedback for one step of an escalating sequence.
    public func play(_ step: JuiceStep) {
        play(HapticRecipe.make(for: step), weight: step.weight)
    }

    private func play(_ recipe: HapticRecipe, weight: FeedbackWeight) {
        guard isEnabled else { return }
        #if canImport(CoreHaptics) && canImport(UIKit)
        guard supportsRichHaptics else {
            playFallback(for: weight)
            return
        }
        do {
            try playPattern(recipe)
        } catch {
            // A burst is never worth failing a frame over. Drop to the simple
            // generator and let the engine restart handlers recover in the background.
            playFallback(for: weight)
        }
        #endif
    }
}

#if canImport(CoreHaptics) && canImport(UIKit)
private extension HapticEngine {
    func startEngineIfNeeded() {
        guard engine == nil else { return }
        do {
            let engine = try CHHapticEngine()

            // The system stops the engine on backgrounding, audio interruption and
            // thermal pressure. Without these handlers haptics silently stay dead
            // for the rest of the session, which is the classic CoreHaptics bug.
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engine = nil }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.engine = nil
                    self?.startEngineIfNeeded()
                }
            }

            engine.playsHapticsOnly = true
            // Auto shutdown is deliberately off. With it on, the engine idles out
            // between taps and has to be rebuilt, and rebuilding costs enough that
            // the first tap of every burst arrives late — which is exactly what the
            // escalating sequences depend on not happening. `teardown()` owns the
            // lifecycle instead, and backgrounding stops the engine anyway.
            engine.isAutoShutdownEnabled = false

            try engine.start()
            self.engine = engine
        } catch {
            // Treat an unstartable engine as an unsupported device from here on.
            supportsRichHaptics = false
            prepareFallbackGenerators()
        }
    }

    func playPattern(_ recipe: HapticRecipe) throws {
        startEngineIfNeeded()
        guard let engine else { throw HapticFailure.engineUnavailable }

        let events = (0..<recipe.eventCount).map { index in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: recipe.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: recipe.sharpness),
                ],
                relativeTime: recipe.eventSpacing * TimeInterval(index)
            )
        }

        let pattern = try CHHapticPattern(events: events, parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: CHHapticTimeImmediate)
    }

    func prepareFallbackGenerators() {
        if lightGenerator == nil { lightGenerator = UIImpactFeedbackGenerator(style: .light) }
        if heavyGenerator == nil { heavyGenerator = UIImpactFeedbackGenerator(style: .heavy) }
        if rigidGenerator == nil { rigidGenerator = UIImpactFeedbackGenerator(style: .rigid) }
        lightGenerator?.prepare()
        heavyGenerator?.prepare()
        rigidGenerator?.prepare()
    }

    func playFallback(for weight: FeedbackWeight) {
        prepareFallbackGenerators()
        switch weight {
        case .micro: lightGenerator?.impactOccurred()
        case .milestone: heavyGenerator?.impactOccurred()
        case .error: rigidGenerator?.impactOccurred()
        }
    }
}

private enum HapticFailure: Error {
    case engineUnavailable
}
#endif
