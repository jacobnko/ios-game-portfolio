// Verifies the theme contract and that every shared string actually resolves.

import Testing
import Foundation
import SwiftUI
@testable import CoreKitUI

// MARK: - Localization
//
// These read the String Catalog as data rather than resolving strings at runtime.
// `swift build` copies an .xcstrings file verbatim; only Xcode runs the catalog
// compiler that turns it into .lproj/.strings. So on the host every key would
// resolve to itself no matter how complete the catalog is, and a runtime assertion
// would be testing the build system rather than the translations.
// Runtime resolution is verified by the iOS build and by JuiceLab.

private struct Catalog {
    let strings: [String: [String: String]]   // key -> language -> value

    init() throws {
        let url = try #require(Bundle.module.url(forResource: "Common", withExtension: "xcstrings"))
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
        let entries = root["strings"] as? [String: Any] ?? [:]

        strings = entries.reduce(into: [:]) { result, entry in
            let localizations = (entry.value as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            result[entry.key] = localizations.reduce(into: [:]) { languages, localization in
                let unit = (localization.value as? [String: Any])?["stringUnit"] as? [String: Any]
                if let value = unit?["value"] as? String, !value.isEmpty {
                    languages[localization.key] = value
                }
            }
        }
    }
}

@Test func everySharedStringExistsInTheCatalog() throws {
    // A key missing from the catalog resolves to the key itself at runtime, so the
    // UI shows "settings.removeAds" to a real player. Nobody reads every screen in
    // every language before shipping, so it is checked here instead.
    let catalog = try Catalog()
    for key in CommonStrings.allCases {
        #expect(catalog.strings[key.rawValue] != nil, "missing catalog entry for \(key.rawValue)")
    }
}

@Test func everySharedStringIsTranslatedIntoTheLaunchLanguages() throws {
    let catalog = try Catalog()
    for key in CommonStrings.allCases {
        let translations = catalog.strings[key.rawValue] ?? [:]
        for language in SupportedLanguage.launchSet {
            #expect(translations[language.rawValue] != nil, "\(key.rawValue) has no \(language.rawValue)")
        }
    }
}

@Test func theCatalogHasNoOrphanKeys() throws {
    // An entry nothing references is dead weight translators still pay to translate.
    let catalog = try Catalog()
    let declared = Set(CommonStrings.allCases.map(\.rawValue))
    for key in catalog.strings.keys {
        #expect(declared.contains(key), "\(key) is in the catalog but not in CommonStrings")
    }
}

@Test func stringKeysAreNamespaced() {
    // Keys collide across catalogs otherwise, and the winner is undefined.
    for key in CommonStrings.allCases {
        #expect(key.rawValue.contains("."), "\(key.rawValue) has no namespace")
    }
}

@Test func keysAreUnique() {
    let keys = CommonStrings.allCases.map(\.rawValue)
    #expect(Set(keys).count == keys.count)
}

@Test func restorePurchasesIsAlwaysAvailable() {
    // Required by App Store review; a game cannot ship without this label existing.
    #expect(CommonStrings.allCases.contains(.settingsRestorePurchases))
    #expect(CommonStrings.allCases.contains(.settingsPrivacyPolicy))
}

// MARK: - Languages

@Test func theLaunchSetIsKoreanAndEnglish() {
    #expect(SupportedLanguage.launchSet == [.english, .korean])
}

@Test func sevenLanguagesAreSupported() {
    #expect(SupportedLanguage.allCases.count == 7)
}

@Test func everyLanguageNamesItselfInItsOwnScript() {
    // A picker listing "Korean" to a Korean speaker is a picker they cannot use.
    #expect(SupportedLanguage.korean.endonym == "한국어")
    #expect(SupportedLanguage.japanese.endonym == "日本語")
    for language in SupportedLanguage.allCases {
        #expect(language.endonym.isEmpty == false)
    }
}

@Test func regionalVariantsTargetTheLargerMarkets() {
    // Latin American Spanish and Brazilian Portuguese carry the casual game volume.
    #expect(SupportedLanguage.spanish.rawValue == "es-MX")
    #expect(SupportedLanguage.portuguese.rawValue == "pt-BR")
}

// MARK: - Theme

@Test func themeColorsResolvePerAppearance() {
    let color = ThemeColor(light: .white, dark: .black)
    #expect(color.resolved(for: .light) == .white)
    #expect(color.resolved(for: .dark) == .black)
}

@Test func burstColoursComeFromThePalette() {
    // The victory burst must be in the game's own colours, or every game's payoff
    // looks identical — which is the Guideline 4.3 problem in miniature.
    let theme = GameTheme.placeholder
    #expect(theme.palette.burstColors.count == 3)
    #expect(theme.palette.burstColors.first == theme.palette.accent.light)
}

@Test func victoryConfigurationInheritsTheTheme() {
    let theme = GameTheme.placeholder
    let configuration = theme.victoryConfiguration(multiplier: 4, seed: 99)
    #expect(configuration.palette == theme.palette.burstColors)
    #expect(configuration.multiplier == 4)
    #expect(configuration.seed == 99)
}

@Test func metricsClampNegativeInput() {
    let metrics = ThemeMetrics(cornerRadius: -5, tileSpacing: -1, shadowRadius: -3)
    #expect(metrics.cornerRadius == 0)
    #expect(metrics.tileSpacing == 0)
    #expect(metrics.shadowRadius == 0)
}

@Test func typographyFallsBackToTheSystemFont() {
    let typography = ThemeTypography()
    #expect(typography.displayFamily == nil)
    #expect(typography.bodyFamily == nil)
}

@Test func themesAreValuesSoSwappingOneChangesEverything() {
    var a = GameTheme.placeholder
    let b = GameTheme.placeholder
    a.metrics.cornerRadius = 30
    #expect(a != b)
}
