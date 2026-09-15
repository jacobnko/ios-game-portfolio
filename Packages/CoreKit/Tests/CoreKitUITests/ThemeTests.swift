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

// MARK: - Language matching
//
// Untouched by any test until the third audit pass. A wrong match here silently
// serves English to an entire market, and nothing about it would ever throw.

@Test func exactLanguageTagsMatch() {
    #expect(LanguageSettings.language(matching: "en") == .english)
    #expect(LanguageSettings.language(matching: "ko") == .korean)
    #expect(LanguageSettings.language(matching: "es-MX") == .spanish)
    #expect(LanguageSettings.language(matching: "pt-BR") == .portuguese)
}

@Test func aBareLanguageFindsTheRegionalVariantWeShip() {
    // The device reports "es"; we ship "es-MX".
    #expect(LanguageSettings.language(matching: "es") == .spanish)
    #expect(LanguageSettings.language(matching: "pt") == .portuguese)
}

@Test func aRegionalVariantFindsTheBaseLanguageWeShip() {
    // The device reports "en-GB"; we ship "en".
    #expect(LanguageSettings.language(matching: "en-GB") == .english)
    #expect(LanguageSettings.language(matching: "ko-KR") == .korean)
    #expect(LanguageSettings.language(matching: "de-AT") == .german)
    #expect(LanguageSettings.language(matching: "fr-CA") == .french)
    #expect(LanguageSettings.language(matching: "ja-JP") == .japanese)
}

@Test func otherRegionsOfAShippedLanguageStillMatch() {
    // Spain and Portugal fall back to the Latin American and Brazilian catalogs
    // rather than to English, which is much closer to right.
    #expect(LanguageSettings.language(matching: "es-ES") == .spanish)
    #expect(LanguageSettings.language(matching: "pt-PT") == .portuguese)
    #expect(LanguageSettings.language(matching: "es-419") == .spanish)
}

@Test func unshippedLanguagesMatchNothing() {
    // Must be nil, not a wrong guess: Chinese and Russian are deliberately excluded.
    #expect(LanguageSettings.language(matching: "zh-Hans") == nil)
    #expect(LanguageSettings.language(matching: "ru") == nil)
    #expect(LanguageSettings.language(matching: "it") == nil)
}

@Test func malformedIdentifiersMatchNothing() {
    #expect(LanguageSettings.language(matching: "") == nil)
    #expect(LanguageSettings.language(matching: "-") == nil)
    #expect(LanguageSettings.language(matching: "e") == nil)
}

// MARK: - Theme values that had never been evaluated

@Test func typographyProducesEveryRole() {
    let typography = ThemeTypography(displaySize: 40, titleSize: 20, bodySize: 14)
    #expect(typography.display != typography.body)
    #expect(typography.title != typography.body)
    #expect(typography.numeric != typography.body)
}

@Test func customFontFamiliesAreUsedWhenSupplied() {
    let system = ThemeTypography()
    let custom = ThemeTypography(displayFamily: "Georgia", bodyFamily: "Menlo")
    #expect(custom.display != system.display)
    #expect(custom.body != system.body)
}

@Test func aSingleColourResolvesTheSameInBothAppearances() {
    let color = ThemeColor(.red)
    #expect(color.resolved(for: .light) == color.resolved(for: .dark))
}

@Test func theEnvironmentCarriesTheTheme() {
    var environment = EnvironmentValues()
    #expect(environment.gameTheme == .placeholder)
    var custom = GameTheme.placeholder
    custom.metrics.cornerRadius = 28
    environment.gameTheme = custom
    #expect(environment.gameTheme.metrics.cornerRadius == 28)
}

@Test func sharedStringsResolveWithoutCrashing() {
    // On the host these return the key itself because SwiftPM does not compile
    // String Catalogs. The point here is only that the lookup path is exercised.
    for key in CommonStrings.allCases {
        #expect(key.text.isEmpty == false)
        _ = key.resource
    }
}
