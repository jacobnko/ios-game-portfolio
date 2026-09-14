// Renders and plays ToneRecipe bursts through AVAudioEngine.

import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Plays the synthesised tones that make a repeated action sound like a run of notes.
///
/// Games call `play(_:stepIndex:)` and never touch AVFoundation. Buffers are
/// rendered once per pitch and cached, so a fast drag does not allocate per step.
@MainActor
public final class PitchedTonePlayer {
    public static let shared = PitchedTonePlayer()

    /// Player-facing switch, bound to the sound effects toggle in Settings.
    public var isEnabled: Bool = true

    /// Sound effect volume, 0...1. Kept separate from any future music volume
    /// so the two can be mixed — and muted — independently.
    public var volume: Float = 1.0 {
        didSet {
            volume = min(1, max(0, volume))
            #if canImport(AVFoundation)
            playerNode?.volume = volume
            #endif
        }
    }

    public var scale: MusicalScale = .pentatonicMajor
    public var root: Double = Pitch.c5

    #if canImport(AVFoundation)
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var bufferCache: [BufferKey: AVAudioPCMBuffer] = [:]
    private var configurationObserver: NSObjectProtocol?

    private struct BufferKey: Hashable {
        let weight: FeedbackWeight
        let stepIndex: Int
    }
    #endif

    private init() {}

    /// Warms up the engine. Call when a gameplay screen appears.
    public func prepare() {
        guard isEnabled else { return }
        JuiceAudioSession.activate()
        #if canImport(AVFoundation)
        startEngineIfNeeded()
        #endif
    }

    /// Releases audio resources. Call when leaving gameplay.
    public func teardown() {
        #if canImport(AVFoundation)
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
        bufferCache.removeAll()
        #endif
    }

    /// Plays the tone for one step of an escalating run.
    public func play(_ weight: FeedbackWeight, stepIndex: Int = 0) {
        guard isEnabled else { return }
        #if canImport(AVFoundation)
        startEngineIfNeeded()
        guard let playerNode, let buffer = buffer(for: weight, stepIndex: stepIndex) else { return }
        // `.interrupts` so a fast drag replaces the previous note instead of
        // stacking overlapping tones into mud.
        playerNode.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        if !playerNode.isPlaying { playerNode.play() }
        #endif
    }

    public func play(_ step: JuiceStep) {
        play(step.weight, stepIndex: step.index)
    }
}

#if canImport(AVFoundation)
private extension PitchedTonePlayer {
    func startEngineIfNeeded() {
        guard engine == nil else { return }

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.volume = volume

        do {
            try engine.start()
        } catch {
            return
        }

        // Route changes (headphones in or out) reset the engine. Without this the
        // game goes silent for the rest of the session — the audio twin of the
        // CoreHaptics stoppedHandler bug.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.teardown()
                self.startEngineIfNeeded()
            }
        }

        self.engine = engine
        self.playerNode = node
        self.format = format
        node.play()
    }

    func buffer(for weight: FeedbackWeight, stepIndex: Int) -> AVAudioPCMBuffer? {
        let key = BufferKey(weight: weight, stepIndex: stepIndex)
        if let cached = bufferCache[key] { return cached }
        guard let format else { return nil }

        let recipe = ToneRecipe.make(for: weight, stepIndex: stepIndex, scale: scale, root: root)
        let samples = recipe.renderSamples(sampleRate: format.sampleRate)
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }

        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        bufferCache[key] = buffer
        return buffer
    }
}
#endif
