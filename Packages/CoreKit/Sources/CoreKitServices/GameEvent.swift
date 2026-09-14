// The event vocabulary every game in the portfolio shares.

import Foundation

/// Canonical events.
///
/// Every game emits these under the same names, so funnels and retention can be
/// compared across the portfolio. Per-game differences belong in parameters, never
/// in the event name — ten games with ten spellings of "stage cleared" cannot be
/// compared, and comparing them is the entire reason this data is collected.
public enum GameEvent {
    // MARK: - Stage funnel

    public static func stageStarted(stageID: String, attempt: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "stage_start", parameters: [
            "stage_id": .string(stageID),
            "attempt": .int(attempt),
        ])
    }

    public static func stageCleared(stageID: String, attempt: Int, durationSeconds: Double, stars: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "stage_clear", parameters: [
            "stage_id": .string(stageID),
            "attempt": .int(attempt),
            "duration_s": .double(durationSeconds.rounded()),
            "stars": .int(stars),
        ])
    }

    /// Left without finishing. This is the signal that finds difficulty spikes.
    public static func stageAbandoned(stageID: String, attempt: Int, durationSeconds: Double, progressPercent: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "stage_abandon", parameters: [
            "stage_id": .string(stageID),
            "attempt": .int(attempt),
            "duration_s": .double(durationSeconds.rounded()),
            "progress_pct": .int(progressPercent),
        ])
    }

    public static func hintUsed(stageID: String, source: HintSource) -> AnalyticsEvent {
        AnalyticsEvent(name: "hint_used", parameters: [
            "stage_id": .string(stageID),
            "source": .string(source.rawValue),
        ])
    }

    public enum HintSource: String, Sendable {
        case rewardedAd = "rewarded_ad"
        case free
        case purchased
    }

    // MARK: - Monetization

    public static func adShown(placement: AdPlacement) -> AnalyticsEvent {
        AnalyticsEvent(name: "ad_shown", parameters: ["placement": .string(placement.rawValue)])
    }

    /// Logged when an interstitial was eligible but the policy held it back.
    ///
    /// The distribution of verdicts is what tells you whether the pacing is too
    /// aggressive or too timid, which is impossible to see from impressions alone.
    public static func adSuppressed(verdict: InterstitialVerdict) -> AnalyticsEvent {
        AnalyticsEvent(name: "ad_suppressed", parameters: ["verdict": .string("\(verdict)")])
    }

    public static func rewardEarned(placement: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "reward_earned", parameters: ["placement": .string(placement)])
    }

    public static func removeAdsViewed(source: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "remove_ads_view", parameters: ["source": .string(source)])
    }

    public static func removeAdsPurchased(priceDisplay: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "remove_ads_purchase", parameters: ["price": .string(priceDisplay)])
    }

    public static func purchasesRestored(didRestore: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchases_restore", parameters: ["restored": .bool(didRestore)])
    }

    // MARK: - Virality

    /// The share sheet was opened, or a replay was exported.
    ///
    /// Short-form video is a third growth lever alongside retention and ASO, and it
    /// is invisible unless the trigger is logged here.
    public static func shareTriggered(surface: String, stageID: String?) -> AnalyticsEvent {
        var parameters: [String: AnalyticsValue] = ["surface": .string(surface)]
        if let stageID { parameters["stage_id"] = .string(stageID) }
        return AnalyticsEvent(name: "share_trigger", parameters: parameters)
    }

    // MARK: - Settings

    public static func settingToggled(name: String, isOn: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "setting_toggle", parameters: [
            "setting": .string(name),
            "enabled": .bool(isOn),
        ])
    }
}
