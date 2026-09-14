// Lets a human watch the victory payoff and tune its parts against a real board.

import SwiftUI
import CoreKitJuice

struct VictoryLabView: View {
    @State private var isPlaying = false
    @State private var multiplier: Double = 4
    @State private var particleCount: Double = 90
    @State private var shakeAmplitude: Double = 9
    @State private var seed: Double = 1
    @State private var paletteIndex = 0
    @State private var playsFeedback = true
    @State private var finishedCount = 0

    private let palettes: [(name: String, colors: [Color])] = [
        ("Warm", [.yellow, .orange, .pink]),
        ("Neon", [.cyan, .mint, .purple]),
        ("Candy", [.pink, .teal, .indigo]),
    ]

    private var configuration: VictoryConfiguration {
        VictoryConfiguration(
            multiplier: Int(multiplier),
            // Four origins mimic a finished board: bursts come from where the
            // player's own work was, not from one point in the middle.
            origins: [
                CGPoint(x: 0.25, y: 0.35), CGPoint(x: 0.75, y: 0.35),
                CGPoint(x: 0.25, y: 0.65), CGPoint(x: 0.75, y: 0.65),
            ],
            particleCount: Int(particleCount),
            palette: palettes[paletteIndex].colors,
            seed: UInt64(seed),
            shake: ShakeCurve(amplitude: shakeAmplitude),
            playsFeedback: playsFeedback
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            mockBoard
                .victorySequence(isPresented: $isPlaying, configuration: configuration) {
                    finishedCount += 1
                }
                .frame(height: 320)
                .clipped()

            controls
        }
        .navigationTitle("Victory")
        .onAppear {
            PitchedTonePlayer.shared.prepare()
            HapticEngine.shared.prepare()
        }
    }

    /// Stands in for a finished puzzle board so the shake has something to move.
    private var mockBoard: some View {
        ZStack {
            Color(.systemGroupedBackground)
            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(palettes[paletteIndex].colors[(row + column) % palettes[paletteIndex].colors.count].opacity(0.65))
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
        }
    }

    private var controls: some View {
        Form {
            Section {
                Button("Play victory sequence") { isPlaying = true }
                    .disabled(isPlaying)
                LabeledContent("Completed", value: "\(finishedCount)")
            } footer: {
                Text("The binding resets itself when the sequence ends, so a game can advance on completion.")
            }

            Section("Tuning") {
                slider("Multiplier", value: $multiplier, range: 1...64, step: 1)
                slider("Particles", value: $particleCount, range: 0...300, step: 10)
                slider("Shake amplitude", value: $shakeAmplitude, range: 0...30, step: 1)
                slider("Seed", value: $seed, range: 1...20, step: 1)
                Picker("Palette", selection: $paletteIndex) {
                    ForEach(palettes.indices, id: \.self) { Text(palettes[$0].name).tag($0) }
                }
                Toggle("Plays sound and haptics", isOn: $playsFeedback)
            }

            Section {
                Text("Turn on Settings → Accessibility → Motion → Reduce Motion and replay. The shake should stop and the burst should thin out, but a payoff must still happen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            Text("\(title)  \(Int(value.wrappedValue))")
                .font(.caption.monospacedDigit())
            Slider(value: value, in: range, step: step)
        }
    }
}

#Preview {
    NavigationStack { VictoryLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
