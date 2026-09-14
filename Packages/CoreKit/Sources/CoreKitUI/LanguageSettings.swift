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

    /// Launch languages. The rest are added per game once Analytics shows traction.
    public static let launchSet: [SupportedLanguage] = [.english, .korean]
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
        return SupportedLanguage(rawValue: identifier)
            ?? SupportedLanguage.allCases.first { $0.rawValue.hasPrefix(identifier) }
            ?? SupportedLanguage.allCases.first { identifier.hasPrefix($0.rawValue.prefix(2)) }
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
