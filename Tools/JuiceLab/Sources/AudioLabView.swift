// Lets a human hear the pitch escalation and confirm the sequence reset rules.

import SwiftUI
import CoreKitJuice

struct AudioLabView: View {
    @State private var stepIndex: Double = 0
    @State private var soundEnabled = true
    @State private var volume: Double = 1.0
    @State private var scale: MusicalScale = .pentatonicMajor
    @State private var isRunningSequence = false

    // Mirrors how a game would drive the run: one sequence, advanced per action.
    @State private var sequence = JuiceSequence()
    @State private var liveStep: Int = 0

    private var recipe: ToneRecipe {
        ToneRecipe.make(for: .micro, stepIndex: Int(stepIndex), scale: scale)
    }

    var body: some View {
        Form {
            Section("Output") {
                Toggle("Sound enabled", isOn: $soundEnabled)
                    .onChange(of: soundEnabled) { _, new in PitchedTonePlayer.shared.isEnabled = new }
                VStack(alignment: .leading) {
                    Text("Volume \(String(format: "%.2f", volume))").font(.caption.monospaced())
                    Slider(value: $volume, in: 0...1)
                        .onChange(of: volume) { _, new in PitchedTonePlayer.shared.volume = Float(new) }
                }
                LabeledContent("Other app playing", value: JuiceAudioSession.shouldSuppressBackgroundMusic ? "yes" : "no")
            }

            Section("Scale") {
                Picker("Scale", selection: $scale) {
                    Text("Pentatonic major").tag(MusicalScale.pentatonicMajor)
                    Text("Pentatonic minor").tag(MusicalScale.pentatonicMinor)
                    Text("Major").tag(MusicalScale.major)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: scale) { _, new in PitchedTonePlayer.shared.scale = new }
            }

            Section("Micro — single step") {
                VStack(alignment: .leading) {
                    Text("Step \(Int(stepIndex))").font(.subheadline.monospacedDigit())
                    Slider(value: $stepIndex, in: 0...15, step: 1)
                    Text(String(format: "%.1f Hz   %.0f ms", recipe.frequency, recipe.duration * 1000))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button("Play this step") {
                    PitchedTonePlayer.shared.play(.micro, stepIndex: Int(stepIndex))
                }
                Button(isRunningSequence ? "Running…" : "Play ascending run 0 → 10") {
                    playRun()
                }
                .disabled(isRunningSequence)
            }

            Section("Sequence reset — tap repeatedly, then pause") {
                // Tapping fast should climb. Waiting past the reset interval should
                // drop back to the root, so a new pipe never continues the old melody.
                Button("Tap me  (step \(liveStep))") {
                    let step = sequence.advance(at: Date.timeIntervalSinceReferenceDate)
                    liveStep = step
                    PitchedTonePlayer.shared.play(.micro, stepIndex: step)
                    HapticEngine.shared.play(.micro, stepIndex: step)
                }
                Button("Reset run") {
                    sequence.reset()
                    liveStep = 0
                }
            }

            Section("Milestone and error") {
                Button("Milestone") {
                    PitchedTonePlayer.shared.play(.milestone)
                    HapticEngine.shared.play(.milestone)
                }
                Button("Error") {
                    PitchedTonePlayer.shared.play(.error)
                    HapticEngine.shared.play(.error)
                }
            }
        }
        .navigationTitle("Audio")
        .onAppear {
            PitchedTonePlayer.shared.prepare()
            HapticEngine.shared.prepare()
        }
        .onDisappear { PitchedTonePlayer.shared.teardown() }
    }

    private func playRun() {
        isRunningSequence = true
        Task {
            for step in 0...10 {
                PitchedTonePlayer.shared.play(.micro, stepIndex: step)
                HapticEngine.shared.play(.micro, stepIndex: step)
                try? await Task.sleep(for: .milliseconds(160))
            }
            try? await Task.sleep(for: .milliseconds(220))
            PitchedTonePlayer.shared.play(.milestone)
            HapticEngine.shared.play(.milestone)
            isRunningSequence = false
        }
    }
}

#Preview {
    NavigationStack { AudioLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
