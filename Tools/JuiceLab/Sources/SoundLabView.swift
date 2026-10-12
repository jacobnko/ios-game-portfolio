// Lets a human audition the synthesised effect voices and pick the base note by ear.

import SwiftUI
import CoreKitJuice

struct SoundLabView: View {
    enum Beat: Hashable, Sendable { case clear }

    @State private var baseIndex = 1
    @State private var step: Double = 0
    @State private var performer = BeatPerformer()

    private var base: Double { SoundKit.bases[baseIndex].hz }

    var body: some View {
        Form {
            Section {
                Picker("Base note (step 0)", selection: $baseIndex) {
                    ForEach(SoundKit.bases.indices, id: \.self) { Text(SoundKit.bases[$0].name).tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("Step \(Int(step))  ·  \(Int(SoundKit.pitch(base: base, step: step))) Hz  ·  2 semitones per step")
                        .font(.caption.monospacedDigit())
                    Slider(value: $step, in: -6...7, step: 1)
                }
            } footer: {
                Text("The base note is provisional. Pick the one where tink at step 0 sounds like clean glass, not a test tone and not shrill.")
            }

            Section("Voices") {
                ForEach(SoundKit.Voice.allCases) { voice in
                    Button(voice.rawValue) {
                        PitchedTonePlayer.shared.play(SoundKit.recipe(voice, step: step, base: base))
                    }
                }
            }

            Section {
                Button("Line clear, in order") { performer.play(lineClear) }
                Button("Shatter + thump together") {
                    PitchedTonePlayer.shared.play(SoundKit.recipe(.shatter, step: 4, base: base))
                    PitchedTonePlayer.shared.play(SoundKit.recipe(.thump, base: base))
                }
            } footer: {
                Text("Layered sounds must both be heard — a shatter must not cut the thump off.")
            }
        }
        .navigationTitle("Sounds")
        .onAppear { PitchedTonePlayer.shared.prepare() }
        .onDisappear { performer.cancel() }
    }

    /// The clear's sound cues on their spec times: tink, shimmer, crack, shatter, then a falling three-tink tail.
    private var lineClear: BeatTimeline<Beat> {
        BeatTimeline(
            phases: [.clear: JuicePhase(start: 0, duration: 1)],
            cues: [
                JuiceCue(at: 0.00, tone: SoundKit.recipe(.tink, step: 0, base: base)),
                JuiceCue(at: 0.00, tone: SoundKit.recipe(.shimmer, step: 1, base: base)),
                JuiceCue(at: 0.10, tone: SoundKit.recipe(.crack, step: 2, base: base)),
                JuiceCue(at: 0.22, tone: SoundKit.recipe(.shatter, step: 2, base: base)),
                JuiceCue(at: 0.30, tone: SoundKit.recipe(.tink, step: 1, base: base)),
                JuiceCue(at: 0.34, tone: SoundKit.recipe(.tink, step: 0.5, base: base)),
                JuiceCue(at: 0.38, tone: SoundKit.recipe(.tink, step: 0, base: base)),
            ]
        )
    }
}

#Preview {
    NavigationStack { SoundLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
