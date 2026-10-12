// Lets a human judge glass shards and sparks from ParticleEmitter on a real screen.

import SwiftUI
import CoreKitJuice

/// A row of six tiles shatters into shards (spinning, slowing, shrinking) and sparks.
///
/// Everything is in fractions of the stage side, so the same numbers are judged on
/// an iPhone and an iPad mini. The question here is feel: does it read as glass
/// breaking, is it too busy, does the frame rate hold.
struct ShardLabView: View {
    @State private var startDate: Date?
    @State private var shards: [Particle] = []
    @State private var sparks: [Particle] = []
    @State private var shardsPerTile: Double = 8
    @State private var seed: Double = 1
    @State private var showsHighlight = true
    @State private var groundBounce = false
    @State private var runID = 0
    @State private var slowMotion = false
    private var timeScale: Double { slowMotion ? 0.25 : 1 }

    private let tiles = 6
    private let lineY = 0.45
    private let shardPalette: [Color] = [Color(white: 0.16).opacity(0.85), Color(red: 0.72, green: 1, blue: 0.18), .yellow]
    private let sparkPalette: [Color] = [.white, .yellow]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let side = min(proxy.size.width - 32, proxy.size.height)
                let reference = CGRect(x: (proxy.size.width - side) / 2, y: (proxy.size.height - side) / 2, width: side, height: side)
                TimelineView(.animation(paused: startDate == nil)) { context in
                    let time = startDate.map { context.date.timeIntervalSince($0) * timeScale } ?? 0
                    ZStack {
                        if startDate == nil { tileRow(reference: reference) }
                        Canvas { canvas, _ in
                            ParticleField.draw(shards, in: canvas, reference: reference, at: time, gravity: 1.2,
                                               palette: shardPalette, minimumLength: 3, highlight: showsHighlight ? .white.opacity(0.5) : nil)
                            ParticleField.draw(sparks, in: canvas, reference: reference, at: time, gravity: 0.6, palette: sparkPalette)
                        }
                    }
                }
            }
            .frame(height: 360)
            .background(Color(white: 0.05))
            .clipped()

            Form {
                Section {
                    Button("Shatter the row", action: shatter)
                } footer: {
                    Text("Shards should spin, slow down and shrink as they fade. Sparks are short and bright. Nothing should look like it is sliding on ice.")
                }
                Section("Tuning") {
                    VStack(alignment: .leading) {
                        Text("Shards per tile  \(Int(shardsPerTile))").font(.caption.monospacedDigit())
                        Slider(value: $shardsPerTile, in: 4...16, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Seed  \(Int(seed))").font(.caption.monospacedDigit())
                        Slider(value: $seed, in: 1...20, step: 1)
                    }
                    Toggle("One-sided white edge", isOn: $showsHighlight)
                    Toggle("Bounce once off a floor", isOn: $groundBounce)
                    Toggle("Slow motion ×¼", isOn: $slowMotion)
                }
            }
        }
        .navigationTitle("Shards")
    }

    private func tileRow(reference: CGRect) -> some View {
        let cell = reference.width / CGFloat(tiles) * 0.86
        return HStack(spacing: reference.width / CGFloat(tiles) * 0.14) {
            ForEach(0..<tiles, id: \.self) { _ in
                RoundedRectangle(cornerRadius: cell * 0.2).fill(Color(white: 0.2)).frame(width: cell, height: cell)
            }
        }
        .position(x: reference.midX, y: reference.minY + reference.height * lineY)
    }

    private func shatter() {
        // Four emission points per tile (its 2×2 grid centres), as the clear spec asks.
        let origins: [CGPoint] = (0..<tiles).flatMap { tile -> [CGPoint] in
            let centre = (Double(tile) + 0.5) / Double(tiles)
            let quarter = 0.25 / Double(tiles)
            return [(-1.0, -1.0), (1, -1), (-1, 1), (1, 1)].map { CGPoint(x: centre + $0.0 * quarter, y: lineY + $0.1 * quarter) }
        }
        let perTile = ParticleBudget.perSource(Int(shardsPerTile), sources: tiles, cap: 400)

        shards = ParticleField.emit(
            ParticleEmitter(
                origins: origins, originJitter: 0.1 / Double(tiles),
                directions: [-Double.pi / 2, Double.pi / 2], spread: Double.pi / 3,
                speed: 0.35...0.75, angularSpeed: (Double.pi)...(4 * Double.pi),
                lifetime: 0.55...0.78, size: 0.012...0.04, drag: 1.8,
                endScale: 0.7, fadeStart: 0.6,
                shapes: [.triangle, .triangle, .triangle, .triangle, .parallelogram, .parallelogram, .parallelogram, .sliver],
                colors: ParticleEmitter.pattern(weights: [5, 3, 2]),
                floorY: groundBounce ? 0.85 : nil, restitution: 0.35
            ),
            count: perTile * tiles, seed: UInt64(seed)
        )
        sparks = ParticleField.emit(
            ParticleEmitter(
                origins: origins, spread: Double.pi,
                speed: 0.6...1.1, lifetime: 0.2...0.3, size: 0.004...0.008,
                fadeStart: 0, shapes: [.square], colors: ParticleEmitter.pattern(weights: [3, 2])
            ),
            count: 6 * tiles, seed: UInt64(seed) &+ 1
        )
        startDate = Date()
        runID += 1
        let run = runID
        HapticEngine.shared.play(HapticRecipe(intensity: 0.7, sharpness: 0.9, eventCount: 1, eventSpacing: 0))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2 / timeScale))
            // A newer shatter owns the clock; an older one must not stop it early.
            if runID == run { startDate = nil }
        }
    }
}

#Preview {
    NavigationStack { ShardLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
