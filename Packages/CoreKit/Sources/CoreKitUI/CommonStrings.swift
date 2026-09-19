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
    case settingsResetProgressMessage = "settings.resetProgressMessage"
    case settingsResetProgressConfirm = "settings.resetProgressConfirm"
    case settingsOneTime = "settings.oneTime"
    case settingsSystemSettings = "settings.systemSettings"

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
    case stageLegendClear = "stage.legendClear"
    case stageLegendCurrent = "stage.legendCurrent"
    case stageLegendLocked = "stage.legendLocked"

    /// Resolved through the package's own catalog.
    ///
    /// `table:` has to name the catalog file (`Common.xcstrings` compiles to a
    /// `Common` table) — leaving it out defaults to a table named
    /// "Localizable", which does not exist here, and both `String(localized:)`
    /// and `LocalizedStringResource` fail that lookup by returning the raw key
    /// rather than throwing. That is exactly what shipped: every screen using
    /// `CommonStrings` showed literal keys like "common.play" instead of real
    /// text, in every build, since S1.9 — invisible on the host (where an
    /// .xcstrings file is never compiled at all, so the fallback looks
    /// identical to the bug) and never actually looked at running until a
    /// device build's Home screen was.
    public var resource: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(rawValue), table: "Common", bundle: .atURL(Bundle.module.bundleURL))
    }

    /// Plain string, for places that cannot take a `LocalizedStringResource`.
    public var text: String {
        String(localized: String.LocalizationValue(rawValue), table: "Common", bundle: .module)
    }
}
