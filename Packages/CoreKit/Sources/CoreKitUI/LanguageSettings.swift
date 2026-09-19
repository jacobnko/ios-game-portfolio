// Language switching that works, which means handing the job to iOS.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The languages this portfolio ships.
public enum SupportedLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    case german = "de"
    case spanish = "es-MX"
    case portuguese = "pt-BR"
    case french = "fr"

    /// Name written in the language itself, which is how a language picker should read.
    public var endonym: String {
        switch self {
        case .english: "English"
        case .korean: "한국어"
        case .japanese: "日本語"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .french: "Français"
        }
    }

    /// The languages every game ships translated on day one.
    ///
    /// All of them. Translating as the strings are written costs a line per
    /// key; going back for five languages after the fact means re-reading every
    /// screen to work out what each string meant. The tests hold the catalogs
    /// to this list, so a new key cannot ship translated into some of it.
    public static let launchSet: [SupportedLanguage] = SupportedLanguage.allCases
}

/// Language selection.
///
/// There is deliberately no "set language" function. Overwriting the `AppleLanguages`
/// UserDefaults key has been unreliable since iOS 13 — it can leave the app and the
/// system disagreeing until the next launch. The supported path is the per-app
/// language picker in Settings, so that is where the button goes.
public enum LanguageSettings {
    /// Language the app is actually rendering in.
    public static var current: SupportedLanguage? {
        guard let identifier = Bundle.main.preferredLocalizations.first else { return nil }
        return language(matching: identifier)
    }

    /// Maps a BCP-47 identifier onto a shipped language.
    ///
    /// Split out from `current` so it can be tested. It reads as three lines but
    /// covers three different shapes of input — an exact tag, a bare language for a
    /// regional variant we ship (`es` → `es-MX`), and a regional variant of a bare
    /// language we ship (`en-GB` → `en`) — and getting any of them wrong silently
    /// falls back to English for a whole market.
    static func language(matching identifier: String) -> SupportedLanguage? {
        guard !identifier.isEmpty else { return nil }
        if let exact = SupportedLanguage(rawValue: identifier) { return exact }
        if let regional = SupportedLanguage.allCases.first(where: { $0.rawValue.hasPrefix(identifier + "-") }) {
            return regional
        }
        let base = identifier.prefix(while: { $0 != "-" })
        return SupportedLanguage.allCases.first { $0.rawValue.prefix(while: { $0 != "-" }) == base }
    }

    /// Opens this app's own page in Settings, where the language picker lives.
    @MainActor
    public static func openSystemLanguageSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
