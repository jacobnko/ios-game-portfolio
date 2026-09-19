// Composes shake, particles, score multiplier and sound into one felt payoff.

import SwiftUI

/// Everything a game chooses about its victory payoff.
///
/// The timing and physics are shared so every game in the portfolio feels like it
/// was built by the same hand; colour, multiplier and burst origins are per game.
public struct VictoryConfiguration: Sendable {
    public var multiplier: Int
    /// Where bursts originate, in unit space (0...1 across the view).
    public var origins: [CGPoint]
    public var particleCount: Int
    public var palette: [Color]
    public var seed: UInt64
    public var timeline: VictoryTimeline
    public var shake: ShakeCurve
    public var bloom: BloomCurve
    public var pop: PopCurve
    /// Fill behind the multiplier text — without it, a light multiplier colour
    /// (amber, say) washes out against a busy background of similar brightness.
    /// Defaults to black, which is right for every dark-first game so far; a
    /// light-background game should pass its own.
    public var scrimColor: Color
    /// Whether the sequence drives audio and haptics as well as pixels.
    public var playsFeedback: Bool

    public init(
        multiplier: Int = 1,
        origins: [CGPoint] = [CGPoint(x: 0.5, y: 0.55)],
        particleCount: Int = 90,
        palette: [Color] = [.yellow, .orange, .pink],
        seed: UInt64 = 0x5EED,
        timeline: VictoryTimeline = .standard,
        shake: ShakeCurve = ShakeCurve(),
        bloom: BloomCurve = .standard,
        pop: PopCurve = .standard,
        scrimColor: Color = .black,
        playsFeedback: Bool = true
    ) {
        self.multiplier = max(1, multiplier)
        self.origins = origins.isEmpty ? [CGPoint(x: 0.5, y: 0.55)] : origins
        self.particleCount = max(0, particleCount)
        self.palette = palette.isEmpty ? [.yellow] : palette
        self.seed = seed
        self.timeline = timeline
        self.shake = shake
        self.bloom = bloom
        self.pop = pop
        self.scrimColor = scrimColor
        self.playsFeedback = playsFeedback
    }
}

public extension View {
    /// Plays the portfolio's victory payoff over this view.
    ///
    /// The binding is set back to `false` when the sequence finishes, so a game can
    /// drive it from a single piece of state and advance on `onFinished`.
    func victorySequence(
        isPresented: Binding<Bool>,
        configuration: VictoryConfiguration = VictoryConfiguration(),
        onFinished: (() -> Void)? = nil
    ) -> some View {
        modifier(VictorySequenceModifier(isPresented: isPresented, configuration: configuration, onFinished: onFinished))
    }
}

private struct VictorySequenceModifier: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: VictoryConfiguration
    let onFinished: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?
    @State private var particles: [Particle] = []
    @State private var completionTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .modifier(VictoryStage(
                startDate: startDate,
                particles: particles,
                configuration: configuration,
                reduceMotion: reduceMotion
            ))
            .onChange(of: isPresented) { _, presented in
                if presented {
                    start()
                } else {
                    // Dismissed from outside; drop the pending completion too.
                    completionTask?.cancel()
                    completionTask = nil
                    startDate = nil
                }
            }
            .onDisappear {
                completionTask?.cancel()
                completionTask = nil
            }
    }

    private func start() {
        // Reduce Motion must still get a payoff — a quieter one, not a missing one.
        let count = reduceMotion ? configuration.particleCount / 3 : configuration.particleCount
        particles = ParticleField.make(
            count: count,
            origins: configuration.origins,
            seed: configuration.seed
        )
        startDate = Date()

        // Completion is driven by a timer, not by the render loop. Hanging it off
        // TimelineView meant that if the timeline ever stopped ticking — the view
        // scrolled away, the app was backgrounded at the wrong moment — the sequence
        // never reported finishing and the game sat on the victory overlay forever.
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(configuration.timeline.total))
            guard !Task.isCancelled else { return }
            finish()
        }

        if configuration.playsFeedback { playFeedback() }
    }

    private func finish() {
        guard startDate != nil else { return }
        completionTask?.cancel()
        completionTask = nil
        startDate = nil
        isPresented = false
        onFinished?()
    }

    private func playFeedback() {
        Task { @MainActor in
            // A short rising run, then the arrival. The ear hears the same shape the
            // eye sees: build, then payoff.
            for step in 0..<4 {
                PitchedTonePlayer.shared.play(.micro, stepIndex: step)
                HapticEngine.shared.play(.micro, stepIndex: step)
                try? await Task.sleep(for: .milliseconds(70))
            }
            PitchedTonePlayer.shared.play(.milestone)
            HapticEngine.shared.play(.milestone)
        }
    }
}

/// Drives one frame of the sequence. Split out so the timeline only ticks while running.
private struct VictoryStage: ViewModifier {
    let startDate: Date?
    let particles: [Particle]
    let configuration: VictoryConfiguration
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        guard let startDate else {
            return AnyView(content)
        }

        return AnyView(
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startDate)
                let shakeOffset = reduceMotion ? .zero : configuration.shake.offset(at: elapsed)

                // Reduce Motion drops the scale punch (a transform reads as
                // motion) but keeps the flash — D5 calls for "brightness fade
                // only" under Reduce Motion, not no bloom at all.
                let whiteness = configuration.bloom.whiteness(at: elapsed)
                let scale = reduceMotion ? 1 : configuration.bloom.scale(at: elapsed)

                content
                    .scaleEffect(scale)
                    .overlay {
                        // Approximates D5's "core replaced by white" without any
                        // board-specific knowledge: `.screen` pushes toward white
                        // in proportion to opacity, which reads as a flash on a
                        // dark board without this view needing to know it is one.
                        Color.white
                            .opacity(whiteness)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                    .offset(x: shakeOffset.width, y: shakeOffset.height)
                    .overlay { burstLayer(elapsed: elapsed) }
                    .overlay { multiplierLayer(elapsed: elapsed) }
            }
        )
    }

    private func burstLayer(elapsed: TimeInterval) -> some View {
        // One Canvas draws every particle. Rendering each as its own View collapses
        // the frame rate once the count passes a few dozen.
        Canvas { canvasContext, size in
            guard let burstProgress = configuration.timeline.burst.progress(at: elapsed) else { return }
            let burstTime = burstProgress * configuration.timeline.burst.duration

            for particle in particles {
                guard let unitPoint = ParticleField.position(of: particle, at: burstTime) else { continue }
                let opacity = ParticleField.opacity(of: particle, at: burstTime)
                guard opacity > 0.01 else { continue }

                let rect = CGRect(
                    x: unitPoint.x * size.width - particle.size / 2,
                    y: unitPoint.y * size.height - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )
                let color = configuration.palette[particle.colorIndex % configuration.palette.count]
                canvasContext.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func multiplierLayer(elapsed: TimeInterval) -> some View {
        if let progress = configuration.timeline.multiplier.progress(at: elapsed) {
            let opacity = configuration.pop.opacity(at: progress)
            let scale = configuration.pop.scale(at: progress)

            ZStack {
                // D5 calls this out as required, not decorative: a light
                // multiplier colour (amber, say) sits directly on top of
                // whatever the board's own colours are doing at that moment,
                // and without a scrim behind it the number can lose contrast
                // against a similarly bright pipe.
                Ellipse()
                    .fill(configuration.scrimColor)
                    .frame(width: 240, height: 120)
                    .blur(radius: 24)
                    .opacity(0.72 * opacity)

                Text("×\(configuration.multiplier)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(configuration.palette.first ?? .yellow)
                    .shadow(radius: 8, y: 2)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .allowsHitTesting(false)
        }
    }
}
