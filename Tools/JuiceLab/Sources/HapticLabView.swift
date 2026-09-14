// Lets a human feel every haptic intent and the escalation curve between them.

import SwiftUI
import CoreKitJuice

struct HapticLabView: View {
    @State private var engine = HapticEngine.shared
    @State private var stepIndex: Double = 0
    @State private var hapticsEnabled = true
    @State private var isRunningSequence = false

    private var recipe: HapticRecipe {
        HapticRecipe.make(for: .micro, stepIndex: Int(stepIndex))
    }

    var body: some View {
        Form {
            Section("Support") {
                LabeledContent("Rich haptics", value: engine.supportsRichHaptics ? "CoreHaptics" : "Fallback")
                Toggle("Haptics enabled", isOn: $hapticsEnabled)
                    .onChange(of: hapticsEnabled) { _, new in engine.isEnabled = new }
            }

            Section("Micro — escalating step") {
                // The whole point of the micro curve is that it climbs. Slide through
                // it and the taps should get firmer without ever reaching milestone weight.
                VStack(alignment: .leading) {
                    Text("Step \(Int(stepIndex))")
                        .font(.subheadline.monospacedDigit())
                    Slider(value: $stepIndex, in: 0...12, step: 1)
                    Text(String(format: "intensity %.2f   sharpness %.2f", recipe.intensity, recipe.sharpness))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button("Play this step") {
                    HapticEngine.shared.play(.micro, stepIndex: Int(stepIndex))
                }
                Button(isRunningSequence ? "Running…" : "Play full sequence 0 → 8") {
                    playSequence()
                }
                .disabled(isRunningSequence)
            }

            Section("Milestone and error") {
                Button("Milestone — should feel heavier than any micro step") {
                    HapticEngine.shared.play(.milestone)
                }
                Button("Error — should feel sharper, never like success") {
                    HapticEngine.shared.play(.error)
                }
            }

            Section("A/B check") {
                // Back to back is the only honest way to confirm the two rules the
                // unit tests encode: micro never reaches milestone, error never reads as success.
                Button("Micro peak, then milestone") {
                    Task {
                        HapticEngine.shared.play(.micro, stepIndex: 12)
                        try? await Task.sleep(for: .milliseconds(500))
                        HapticEngine.shared.play(.milestone)
                    }
                }
                Button("Milestone, then error") {
                    Task {
                        HapticEngine.shared.play(.milestone)
                        try? await Task.sleep(for: .milliseconds(500))
                        HapticEngine.shared.play(.error)
                    }
                }
            }
        }
        .navigationTitle("Haptics")
        .onAppear { HapticEngine.shared.prepare() }
    }

    private func playSequence() {
        isRunningSequence = true
        Task {
            for step in 0...8 {
                HapticEngine.shared.play(.micro, stepIndex: step)
                try? await Task.sleep(for: .milliseconds(180))
            }
            try? await Task.sleep(for: .milliseconds(250))
            HapticEngine.shared.play(.milestone)
            isRunningSequence = false
        }
    }
}

#Preview {
    NavigationStack { HapticLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
