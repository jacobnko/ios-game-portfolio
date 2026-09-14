// Proves that swapping one value changes a game's entire look.

import SwiftUI
import CoreKitUI
import CoreKitJuice

/// Three deliberately unlike themes, standing in for three games in the portfolio.
enum SampleThemes {
    static let all: [(name: String, theme: GameTheme)] = [
        ("Neon night", neonNight),
        ("Paper", paper),
        ("Metal", metal),
    ]

    static let neonNight = GameTheme(
        palette: ThemePalette(
            primary: ThemeColor(light: Color(red: 0.2, green: 0.9, blue: 0.95), dark: Color(red: 0.25, green: 0.95, blue: 1.0)),
            secondary: ThemeColor(light: Color(red: 0.95, green: 0.25, blue: 0.75), dark: Color(red: 1.0, green: 0.35, blue: 0.8)),
            accent: ThemeColor(light: Color(red: 0.75, green: 1.0, blue: 0.3), dark: Color(red: 0.8, green: 1.0, blue: 0.4)),
            background: ThemeColor(light: Color(red: 0.08, green: 0.09, blue: 0.18), dark: Color(red: 0.05, green: 0.06, blue: 0.13)),
            surface: ThemeColor(light: Color(red: 0.14, green: 0.16, blue: 0.28), dark: Color(red: 0.11, green: 0.13, blue: 0.24)),
            onSurface: ThemeColor(Color(white: 0.95))
        ),
        typography: ThemeTypography(systemDesign: .default, displaySize: 46, titleSize: 24, bodySize: 15),
        metrics: ThemeMetrics(cornerRadius: 4, tileSpacing: 10, shadowRadius: 12)
    )

    static let paper = GameTheme(
        palette: ThemePalette(
            primary: ThemeColor(light: Color(white: 0.15), dark: Color(white: 0.9)),
            secondary: ThemeColor(light: Color(red: 0.85, green: 0.35, blue: 0.3), dark: Color(red: 0.9, green: 0.45, blue: 0.4)),
            accent: ThemeColor(light: Color(red: 0.95, green: 0.75, blue: 0.2), dark: Color(red: 1.0, green: 0.8, blue: 0.3)),
            background: ThemeColor(light: Color(red: 0.96, green: 0.94, blue: 0.88), dark: Color(white: 0.12)),
            surface: ThemeColor(light: Color(red: 0.99, green: 0.98, blue: 0.94), dark: Color(white: 0.18)),
            onSurface: ThemeColor(light: Color(white: 0.12), dark: Color(white: 0.92))
        ),
        typography: ThemeTypography(systemDesign: .serif, displaySize: 40, titleSize: 22, bodySize: 16),
        metrics: ThemeMetrics(cornerRadius: 2, tileSpacing: 6, shadowRadius: 0)
    )

    static let metal = GameTheme(
        palette: ThemePalette(
            primary: ThemeColor(light: Color(red: 0.45, green: 0.48, blue: 0.52), dark: Color(red: 0.6, green: 0.63, blue: 0.67)),
            secondary: ThemeColor(light: Color(red: 0.72, green: 0.58, blue: 0.28), dark: Color(red: 0.85, green: 0.7, blue: 0.35)),
            accent: ThemeColor(light: Color(red: 0.88, green: 0.72, blue: 0.3), dark: Color(red: 0.95, green: 0.8, blue: 0.4)),
            background: ThemeColor(light: Color(white: 0.85), dark: Color(white: 0.11)),
            surface: ThemeColor(light: Color(white: 0.93), dark: Color(white: 0.17)),
            onSurface: ThemeColor(light: Color(white: 0.15), dark: Color(white: 0.9))
        ),
        typography: ThemeTypography(systemDesign: .monospaced, displaySize: 38, titleSize: 20, bodySize: 14),
        metrics: ThemeMetrics(cornerRadius: 22, tileSpacing: 12, shadowRadius: 2)
    )
}

struct ThemeLabView: View {
    @State private var index = 0
    @State private var isCelebrating = false
    @Environment(\.colorScheme) private var colorScheme

    private var theme: GameTheme { SampleThemes.all[index].theme }
    private var palette: ThemePalette { theme.palette }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Theme", selection: $index) {
                ForEach(SampleThemes.all.indices, id: \.self) { Text(SampleThemes.all[$0].name).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            // Nothing below reads a literal colour or font. Everything comes from the
            // theme, which is what makes ten apps on one architecture look unrelated.
            mockScreen
                .gameTheme(theme)
                .victorySequence(
                    isPresented: $isCelebrating,
                    configuration: theme.victoryConfiguration(multiplier: 8, origins: [
                        CGPoint(x: 0.25, y: 0.4), CGPoint(x: 0.75, y: 0.4),
                        CGPoint(x: 0.5, y: 0.7),
                    ])
                )
        }
        .navigationTitle("Theme")
    }

    private var mockScreen: some View {
        VStack(spacing: theme.metrics.tileSpacing * 2) {
            Text(CommonStrings.resultStageCleared.text)
                .font(theme.typography.display)
                .foregroundStyle(palette.primary.resolved(for: colorScheme))

            Text("12,480")
                .font(theme.typography.numeric)
                .foregroundStyle(palette.onSurface.resolved(for: colorScheme))

            HStack(spacing: theme.metrics.tileSpacing) {
                ForEach(0..<4, id: \.self) { column in
                    RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                        .fill([palette.primary, palette.secondary, palette.accent, palette.surface][column].resolved(for: colorScheme))
                        .frame(width: 52, height: 52)
                        .shadow(radius: theme.metrics.shadowRadius)
                }
            }

            Button {
                isCelebrating = true
            } label: {
                Text(CommonStrings.play.text)
                    .font(theme.typography.title)
                    .foregroundStyle(palette.background.resolved(for: colorScheme))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                            .fill(palette.accent.resolved(for: colorScheme))
                    )
            }

            VStack(spacing: 4) {
                Text(CommonStrings.settingsRestorePurchases.text)
                Text(CommonStrings.settingsLanguageHint.text)
            }
            .font(theme.typography.body)
            .foregroundStyle(palette.onSurface.resolved(for: colorScheme).opacity(0.7))

            Button(CommonStrings.settingsLanguage.text) {
                LanguageSettings.openSystemLanguageSettings()
            }
            .font(theme.typography.body)
            .foregroundStyle(palette.secondary.resolved(for: colorScheme))

            Text("current: \(LanguageSettings.current?.endonym ?? "—")")
                .font(.caption.monospaced())
                .foregroundStyle(palette.onSurface.resolved(for: colorScheme).opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.resolved(for: colorScheme))
    }
}

#Preview {
    NavigationStack { ThemeLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
