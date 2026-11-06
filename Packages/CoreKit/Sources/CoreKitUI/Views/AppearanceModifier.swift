// Applies the player's appearance choice to the app's windows so every presented screen follows it.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension View {
    /// Applies the choice to every window, so sheets, full-screen covers and system alerts follow it too.
    /// `preferredColorScheme(nil)` does not reliably hand a presented sheet back to the device setting,
    /// which is why iOS sets the windows' style instead.
    func appearance(_ choice: AppearanceChoice) -> some View {
        modifier(AppearanceModifier(choice: choice))
    }
}

private struct AppearanceModifier: ViewModifier {
    let choice: AppearanceChoice

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .onAppear { apply(choice) }
            .onChange(of: choice) { _, new in apply(new) }
        #else
        content.preferredColorScheme(choice.colorScheme)
        #endif
    }

    #if canImport(UIKit)
    private func apply(_ choice: AppearanceChoice) {
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            for window in scene.windows { window.overrideUserInterfaceStyle = choice.interfaceStyle }
        }
    }
    #endif
}
