// The player's System / Light / Dark choice; `View.appearance(_:)` (Views/AppearanceModifier.swift) applies it.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Stored by its raw value, so the cases' names are a persistence format: never rename them.
public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system, light, dark

    /// `nil` follows the device.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    #if canImport(UIKit)
    public var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
    #endif
}
