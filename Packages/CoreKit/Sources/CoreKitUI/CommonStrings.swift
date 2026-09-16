// Shared UI strings, so every game spells the same button the same way.

import Foundation

/// Strings every game in the portfolio needs.
///
/// Games add their own catalog for gameplay wording, but these are shared so that
/// "Restore Purchases" does not end up translated three different ways across ten
/// apps — and so a missing translation shows up here once rather than ten times.
public enum CommonStrings: String, CaseIterable, Sendable {
    case play = "common.play"
    case resume = "common.resume"
    case retry = "common.retry"
    case next = "common.next"
    case close = "common.close"
    case cancel = "common.cancel"
    case back = "common.back"
    case home = "common.home"
    case settings = "common.settings"

    case settingsSound = "settings.sound"
    case settingsHaptics = "settings.haptics"
    case settingsNotifications = "settings.notifications"
    case settingsLanguage = "settings.language"
    case settingsLanguageHint = "settings.languageHint"
    case settingsRemoveAds = "settings.removeAds"
    case settingsRestorePurchases = "settings.restorePurchases"
    case settingsPrivacyPolicy = "settings.privacyPolicy"
    case settingsResetProgress = "settings.resetProgress"

    case resultStageCleared = "result.stageCleared"
    case resultBestTime = "result.bestTime"
    case resultNewRecord = "result.newRecord"
    case resultStageFailed = "result.stageFailed"
    case resultShare = "result.share"

    case hintTitle = "hint.title"
    case hintWatchAd = "hint.watchAd"

    case purchasePending = "purchase.pending"
    case purchaseRestored = "purchase.restored"
    case purchaseNothingToRestore = "purchase.nothingToRestore"

    case stageLocked = "stage.locked"

    /// Resolved through the package's own catalog.
    public var resource: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(rawValue), bundle: .atURL(Bundle.module.bundleURL))
    }

    /// Plain string, for places that cannot take a `LocalizedStringResource`.
    public var text: String {
        String(localized: String.LocalizationValue(rawValue), bundle: .module)
    }
}
