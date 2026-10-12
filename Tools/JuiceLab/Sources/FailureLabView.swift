// Lets a human feel a slapstick failure gag built from BeatTimeline and the slapstick curves.

import SwiftUI
import CoreKitJuice

/// A six-second failure gag on a mock board: the pieces refuse, the board cracks,
/// freezes, sighs, sinks, lands, and a stray chip rolls in and tips over.
///
/// The beats are the lab's own — a real game names and draws its own. What is being
/// judged here is the shared part: does the timing read as a joke, do the cues land
/// on the motion, and does everything come back to rest exactly.
struct FailureLabView: View {
    enum Beat: Hashable, Sendable {
        case refuse, crack, spread, hold, escape, sigh, sink, land, punchline, result
    }

    @State private var performer = BeatPerformer()
    @State private var playsFeedback = true
    @State private var finishedCount = 0
    /// When on, the stage is frozen at `scrubTime` instead of following the performer.
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0

    // Everything below is in fractions of the board side B, scaled at draw time.
    private let columns = 5
    private let wobble = WobbleCurve(amplitude: 0.012, swings: 3, duration: 0.28)
    private let squash = SquashCurve(squashX: 1.03, squashY: 0.94)
    private let sink = SinkCurve(drop: 0.22, tiltDegrees: -2.5, bounceHeight: 0.015, bounceDuration: 0.15)
    private let roll = RollInCurve(travel: 0.075, rollDuration: 0.5, radius: 0.008, toppleDegrees: 90, toppleDuration: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let side = min(proxy.size.width - 48, proxy.size.height - 120)
                TimelineView(.animation(paused: !performer.isPlaying)) { context in
                    stage(side: side, time: isScrubbing ? scrubTime : performer.elapsed(at: context.date))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(height: 420)
            .clipped()
            .background(Color(white: 0.06))
            .contentShape(Rectangle())
            // Tap through to the result: the cues in between must be dropped, not fired at once.
            .onTapGesture {
                if let start = Self.timeline.phase(.result)?.start { performer.skip(to: start) }
            }

            controls
        }
        .navigationTitle("Failure")
        .onAppear {
            PitchedTonePlayer.shared.prepare()
            HapticEngine.shared.prepare()
        }
        .onDisappear { performer.cancel() }
    }

    // MARK: - Drawing

    private func stage(side: CGFloat, time: TimeInterval?) -> some View {
        let t = time ?? 0
        let timeline = Self.timeline
        let sinking = timeline.hasStarted(.sink, at: t)
        let sinkProgress = timeline.progress(of: .sink, at: t) ?? (sinking ? 1 : 0)
        let landTime = t - (timeline.phase(.land)?.start ?? 0)
        let shake = ShakeCurve(amplitude: 0.006 * side, duration: 0.14, frequency: 22, lateralRatio: 0.6)
            .offset(at: landTime)

        let boardScale: CGSize = {
            if let p = timeline.progress(of: .sigh, at: t) { return squash.squashing(progress: p) }
            if sinking { return squash.releasing(progress: sinkProgress) }
            return CGSize(width: 1, height: 1)
        }()
        let boardY = (sink.offset(progress: sinkProgress) + sink.bounce(at: landTime)) * side

        return ZStack {
            VStack(spacing: side * 0.06) {
                board(side: side, time: t)
                    .scaleEffect(boardScale, anchor: .bottom)
                    .rotationEffect(.degrees(sink.rotationDegrees(progress: sinkProgress)), anchor: .bottom)
                    .saturation(sinking ? 1 - 0.8 * sinkProgress : 1)
                    .opacity(sinking ? 1 - 0.4 * sinkProgress : 1)
                    .offset(y: boardY)
                waitingPieces(side: side, time: t)
            }
            escapee(side: side, time: t)
            chip(side: side, time: t)
            resultCard(side: side, time: t)
        }
        .offset(x: shake.width, y: shake.height)
    }

    private func board(side: CGFloat, time: TimeInterval) -> some View {
        let gap = side * 0.02
        let cell = (side - gap * CGFloat(columns + 1)) / CGFloat(columns)
        return VStack(spacing: gap) {
            ForEach(0..<columns, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<columns, id: \.self) { column in
                        tile(row: row, column: column, cell: cell, time: time)
                    }
                }
            }
        }
        .padding(gap)
        .background(RoundedRectangle(cornerRadius: side * 0.06).fill(Color(white: 0.12)))
    }

    private func tile(row: Int, column: Int, cell: CGFloat, time: TimeInterval) -> some View {
        let escaped = row == 0 && column == columns - 1 && Self.timeline.hasStarted(.escape, at: time)
        let cracked = time >= crackTime(row: row, column: column)
        // A fixed per-tile tilt: same every run, so a reviewer can compare runs.
        let tilt = cracked ? Double((row * 7 + column * 3) % 5 - 2) : 0
        return RoundedRectangle(cornerRadius: cell * 0.2)
            .fill(Color(white: 0.24))
            .overlay {
                if cracked {
                    Path { path in
                        path.move(to: CGPoint(x: cell * 0.2, y: cell * 0.3))
                        path.addLine(to: CGPoint(x: cell * 0.55, y: cell * 0.5))
                        path.addLine(to: CGPoint(x: cell * 0.45, y: cell * 0.85))
                    }
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
            }
            .frame(width: cell, height: cell)
            .rotationEffect(.degrees(tilt))
            .opacity(escaped ? 0 : 1)
    }

    /// The crack reaches the centre first and spreads out ring by ring (Chebyshev distance).
    private func crackTime(row: Int, column: Int) -> TimeInterval {
        let centre = columns / 2
        let ring = max(abs(row - centre), abs(column - centre))
        return ring == 0 ? 0.4 : 0.6 + 0.2 * TimeInterval(ring - 1)
    }

    private func waitingPieces(side: CGFloat, time: TimeInterval) -> some View {
        HStack(spacing: side * 0.08) {
            ForEach(0..<3, id: \.self) { index in
                let local = time - WobbleCurve.startTime(forIndex: index, stagger: 0.06)
                RoundedRectangle(cornerRadius: side * 0.03)
                    .fill(Color(white: 0.32))
                    .frame(width: side * 0.16, height: side * 0.16)
                    .offset(x: wobble.offset(at: local) * side)
            }
        }
    }

    /// One tile pops out of the top-right corner and falls off-screen (ballistic).
    @ViewBuilder
    private func escapee(side: CGFloat, time: TimeInterval) -> some View {
        if let start = Self.timeline.phase(.escape)?.start, time >= start {
            let local = time - start
            let x = (-0.10 * local) * side
            let y = (-0.25 * local + 0.5 * 1.40 * local * local) * side
            RoundedRectangle(cornerRadius: side * 0.03)
                .fill(Color(white: 0.24))
                .frame(width: side * 0.17, height: side * 0.17)
                .rotationEffect(.degrees(240 * local))
                .offset(x: side * 0.4 + x, y: -side * 0.45 + y)
        }
    }

    /// The button on the gag: rolls in from the right edge, stops beside the board, tips over.
    @ViewBuilder
    private func chip(side: CGFloat, time: TimeInterval) -> some View {
        if let start = Self.timeline.phase(.punchline)?.start, time >= start {
            let local = time - start
            let rest = side * 0.56
            Triangle()
                .fill(Color(white: 0.3))
                .overlay(Triangle().stroke(Color.green.opacity(0.9), lineWidth: 1))
                .frame(width: side * 0.032, height: side * 0.032)
                .rotationEffect(.degrees(roll.rotationDegrees(at: local)))
                .offset(x: rest + (roll.travel - roll.distance(at: local)) * side, y: side * 0.32)
        }
    }

    @ViewBuilder
    private func resultCard(side: CGFloat, time: TimeInterval) -> some View {
        if let p = Self.timeline.progress(of: .result, at: time) ?? (Self.timeline.hasEnded(.result, at: time) ? 1 : nil) {
            Text("Result card")
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.18)))
                .foregroundStyle(.white)
                .opacity(p)
                .offset(y: (1 - p) * 0.04 * side)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        Form {
            Section {
                Button("Play failure gag") {
                    performer.playsFeedback = playsFeedback
                    performer.play(Self.timeline) { finishedCount += 1 }
                }
                LabeledContent("Completed", value: "\(finishedCount)")
                Toggle("Plays sound and haptics", isOn: $playsFeedback)
            } footer: {
                Text("Tap the stage while it plays to skip to the result. Nothing in between should fire.")
            }

            Section {
                Toggle("Freeze at a time", isOn: $isScrubbing)
                if isScrubbing {
                    VStack(alignment: .leading) {
                        Text(String(format: "t = %.2fs", scrubTime))
                            .font(.caption.monospacedDigit())
                        Slider(value: $scrubTime, in: 0...Self.timeline.total)
                    }
                }
            } footer: {
                Text("Inspect one beat at a time. Every value must be back at rest at 0 and at the end.")
            }

            Section {
                Text("Sounds come from the Sounds page's kit. Dust on landing and the escaping tile's bounce are not drawn here — the game adds them with particle emitters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - The gag

    /// G0 is A5; each step is two semitones.
    private static func tone(step: Int, duration: TimeInterval = 0.18, gain: Float = 0.5) -> ToneRecipe {
        ToneRecipe(frequency: Pitch.frequency(root: 880, semitones: 2 * step), duration: duration, gain: gain)
    }

    private static let light = HapticRecipe(intensity: 0.4, sharpness: 0.5, eventCount: 1, eventSpacing: 0)
    private static let rigid = HapticRecipe(intensity: 0.7, sharpness: 0.9, eventCount: 1, eventSpacing: 0)
    private static let heavy = HapticRecipe(intensity: 1.0, sharpness: 0.4, eventCount: 1, eventSpacing: 0)

    static let timeline = BeatTimeline<Beat>(
        phases: [
            .refuse: JuicePhase(start: 0.0, duration: 0.4),
            .crack: JuicePhase(start: 0.4, duration: 0.2),
            .spread: JuicePhase(start: 0.6, duration: 0.6),
            .hold: JuicePhase(start: 1.2, duration: 0.5),
            .escape: JuicePhase(start: 1.7, duration: 0.6),
            .sigh: JuicePhase(start: 2.3, duration: 0.25),
            .sink: JuicePhase(start: 2.55, duration: 0.9),
            .land: JuicePhase(start: 3.45, duration: 0.15),
            .punchline: JuicePhase(start: 3.9, duration: 0.7),
            .result: JuicePhase(start: 4.8, duration: 0.3),
        ],
        cues: [
            JuiceCue(at: 0.0, haptic: light, tone: tone(step: -2)),
            JuiceCue(at: 0.4, haptic: rigid, tone: SoundKit.recipe(.crack, step: -1)),
            JuiceCue(at: 0.6, tone: SoundKit.recipe(.crack, step: -2)),
            JuiceCue(at: 0.8, tone: SoundKit.recipe(.crack, step: -3)),
            JuiceCue(at: 1.0, tone: SoundKit.recipe(.crack, step: -4)),
            // 1.2–1.7 is the comic pause: no cue at all.
            JuiceCue(at: 2.05, tone: SoundKit.recipe(.tonk, step: -1)),
            JuiceCue(at: 2.30, tone: tone(step: -2, duration: 0.22)),
            JuiceCue(at: 2.55, tone: tone(step: -4, duration: 0.22)),
            JuiceCue(at: 2.60, haptic: light),
            JuiceCue(at: 2.80, tone: tone(step: -6, duration: 0.3)),
            JuiceCue(at: 3.00, haptic: light),
            JuiceCue(at: 3.45, haptic: heavy, tone: SoundKit.recipe(.thud)),
            JuiceCue(at: 4.40, haptic: light, tone: SoundKit.recipe(.tink, step: 0)),
        ],
        total: 6.0
    )
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY))
            path.closeSubpath()
        }
    }
}

#Preview {
    NavigationStack { FailureLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
