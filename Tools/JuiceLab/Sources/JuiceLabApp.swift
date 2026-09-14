// Host app that exists only so CoreKit's feedback layer can be felt on a real device.

import SwiftUI

@main
struct JuiceLabApp: App {
    var body: some Scene {
        WindowGroup {
            JuiceLabRootView()
        }
    }
}

struct JuiceLabRootView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Haptics") { HapticLabView() }
                Section {
                    Text("Audio and victory sequence labs land here as CoreKit grows.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("JuiceLab")
        }
    }
}
