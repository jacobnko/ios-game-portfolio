// The visual identity one game swaps in, and the only thing that should differ.

import SwiftUI

/// A colour that resolves differently in light and dark appearance.
public struct ThemeColor: Sendable, Equatable {
    public let light: Color
    public let dark: Color

    public init(light: Color, dark: Color) {
        self.light = light
        self.dark = dark
    }

    /// Same colour in both appearances. Use sparingly — a palette that ignores dark
    /// mode looks broken on half the devices in circulation.
    public init(_ color: Color) {
        self.init(light: color, dark: color)
    }

    public func resolved(for scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }
}

/// The colours one game uses.
public struct ThemePalette: Sendable, Equatable {
    public var primary: ThemeColor
    public var secondary: ThemeColor
    public var accent: ThemeColor
    public var background: ThemeColor
    public var surface: ThemeColor
    public var onSurface: ThemeColor

    public init(primary: ThemeColor, secondary: ThemeColor, accent: ThemeColor, background: ThemeColor, surface: ThemeColor, onSurface: ThemeColor) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.background = background
        self.surface = surface
        self.onSurface = onSurface
    }

    /// Colours a victory burst draws from.
    public var burstColors: [Color] { [accent.light, primary.light, secondary.light] }
}

/// Type treatment.
///
/// Font *family* is part of the differentiation, not just size. Ten games in one
/// system font all read as the same app to a reviewer, which is the shape Guideline
/// 4.3 rejections take.
public struct ThemeTypography: Sendable, Equatable {
    /// Family name, or nil for the system font.
    public var displayFamily: String?
    public var bodyFamily: String?
    /// Rounded, serif or monospaced system design, used when no family is supplied.
    public var systemDesign: Font.Design
    public var displaySize: CGFloat
    public var titleSize: CGFloat
    public var bodySize: CGFloat

    public init(
        displayFamily: String? = nil,
        bodyFamily: String? = nil,
        systemDesign: Font.Design = .default,
        displaySize: CGFloat = 44,
        titleSize: CGFloat = 24,
        bodySize: CGFloat = 16
    ) {
        self.displayFamily = displayFamily
        self.bodyFamily = bodyFamily
        self.systemDesign = systemDesign
        self.displaySize = displaySize
        self.titleSize = titleSize
        self.bodySize = bodySize
    }

    public var display: Font { font(family: displayFamily, size: displaySize, weight: .heavy) }
    public var title: Font { font(family: displayFamily, size: titleSize, weight: .bold) }
    public var body: Font { font(family: bodyFamily, size: bodySize, weight: .regular) }
    /// Tabular figures, so scores and timers do not jitter as digits change.
    public var numeric: Font { font(family: bodyFamily, size: bodySize, weight: .semibold).monospacedDigit() }

    private func font(family: String?, size: CGFloat, weight: Font.Weight) -> Font {
        guard let family else { return .system(size: size, weight: weight, design: systemDesign) }
        return .custom(family, size: size)
    }
}

/// Shape language. Cheap to vary, and it changes the feel more than colour alone.
public struct ThemeMetrics: Sendable, Equatable {
    public var cornerRadius: CGFloat
    public var tileSpacing: CGFloat
    public var shadowRadius: CGFloat

    public init(cornerRadius: CGFloat = 12, tileSpacing: CGFloat = 8, shadowRadius: CGFloat = 4) {
        self.cornerRadius = max(0, cornerRadius)
        self.tileSpacing = max(0, tileSpacing)
        self.shadowRadius = max(0, shadowRadius)
    }
}

/// Everything that should differ between two games in this portfolio.
///
/// The gameplay code reads the theme from the environment and never hard-codes a
/// colour or a font. Swapping this value is what makes ten apps built on one
/// architecture look like ten different apps — which is the mitigation for
/// Guideline 4.3 (design spam), not a nicety.
public struct GameTheme: Sendable, Equatable {
    public var palette: ThemePalette
    public var typography: ThemeTypography
    public var metrics: ThemeMetrics

    public init(palette: ThemePalette, typography: ThemeTypography = ThemeTypography(), metrics: ThemeMetrics = ThemeMetrics()) {
        self.palette = palette
        self.typography = typography
        self.metrics = metrics
    }

    /// Neutral fallback. Every real game replaces this — shipping it would be the
    /// exact "all the apps look the same" problem.
    public static let placeholder = GameTheme(
        palette: ThemePalette(
            primary: ThemeColor(light: .blue, dark: Color(red: 0.45, green: 0.62, blue: 1.0)),
            secondary: ThemeColor(light: .teal, dark: Color(red: 0.35, green: 0.78, blue: 0.78)),
            accent: ThemeColor(light: .orange, dark: Color(red: 1.0, green: 0.65, blue: 0.3)),
            background: ThemeColor(light: Color(white: 0.97), dark: Color(white: 0.08)),
            surface: ThemeColor(light: .white, dark: Color(white: 0.15)),
            onSurface: ThemeColor(light: Color(white: 0.1), dark: Color(white: 0.95))
        )
    )
}

// MARK: - Environment

private struct GameThemeKey: EnvironmentKey {
    static let defaultValue = GameTheme.placeholder
}

public extension EnvironmentValues {
    var gameTheme: GameTheme {
        get { self[GameThemeKey.self] }
        set { self[GameThemeKey.self] = newValue }
    }
}

public extension View {
    /// Applies a theme to this view and everything below it.
    func gameTheme(_ theme: GameTheme) -> some View {
        environment(\.gameTheme, theme)
    }
}
