// The one place ads are allowed to appear from.

import Foundation
import Observation

/// Single entry point for showing ads.
///
/// Games call this and never an SDK directly. That is what makes the entitlement
/// check one check rather than a condition copied to every call site, where one
/// missed copy means a paying player still sees an ad.
@MainActor
@Observable
public final class AdCoordinator {
    public private(set) var activity = AdActivity()
    public private(set) var lastVerdict: InterstitialVerdict = .allowed
    public var policy: AdPolicy

    private let purchases: PurchaseManager
    private let presenter: AdPresenting
    private let now: @Sendable () -> TimeInterval
    /// Whole-app kill switch, set once at construction — see `init(adsEnabled:)`.
    private let adsEnabled: Bool
    /// Narrower switch for the banner alone — see `init(bannerEnabled:)`.
    private let bannerEnabled: Bool

    /// Whether a banner should currently be on screen.
    ///
    /// Games bind their banner container's visibility to this rather than checking
    /// entitlement themselves.
    public var showsBanner: Bool { adsEnabled && bannerEnabled && !purchases.adsRemoved }

    /// Whether the next rewarded-ad action (a hint, say) will actually show an ad,
    /// as opposed to being granted for free. A button that promises "watch an ad
    /// for X" should check this before badging itself that way — badging one that
    /// will not show an ad promises something the tap does not deliver.
    public var showsRewardedBadge: Bool { adsEnabled && !purchases.adsRemoved }

    public init(
        purchases: PurchaseManager,
        presenter: AdPresenting,
        policy: AdPolicy = .standard,
        // Launch-time kill switch for every placement — banners, interstitials,
        // and the rewarded-ad prompt (rewarded actions still grant their reward
        // for free when this is off, same as a player who removed ads). Meant
        // for a game's first App Store submission: ship ad-free to keep the
        // first review's surface area small — no ad content for a reviewer to
        // flag, no ATT friction, no invalid-traffic risk from review-team
        // impressions — then flip this one argument to `true` in a follow-up
        // update once the app has a review history. Nothing else in the ad
        // pipeline needs touching either way.
        adsEnabled: Bool = true,
        // Independent of `adsEnabled`: interstitials, rewarded ads, and the
        // purchase UI all stay live with this off — only the banner hides.
        // The usual reason is screenshots/first impression rather than review
        // risk: a banner is the one placement that sits in every screen's
        // frame the whole time, so it is what a marketing screenshot or a
        // reviewer's very first glance shows regardless of what the player
        // actually does.
        bannerEnabled: Bool = true,
        now: @escaping @Sendable () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    ) {
        self.purchases = purchases
        self.presenter = presenter
        self.policy = policy
        self.adsEnabled = adsEnabled
        self.bannerEnabled = bannerEnabled
        self.now = now
    }

    /// Call after every stage clear, whether or not an ad follows.
    public func recordStageClear() {
        activity.recordClear()
        if adsEnabled, !purchases.adsRemoved { presenter.preload() }
    }

    /// Shows an interstitial if the policy and the entitlement both allow it.
    ///
    /// Returns whether one was actually shown, so the caller can delay a transition.
    @discardableResult
    public func showInterstitialIfAllowed() async -> Bool {
        guard adsEnabled else { return false }
        let verdict = policy.verdict(for: activity, adsRemoved: purchases.adsRemoved, now: now())
        lastVerdict = verdict
        guard verdict.isAllowed, presenter.isInterstitialReady else { return false }

        let shown = await presenter.showInterstitial()
        if shown {
            // Recorded only on a real impression. Counting a failed load as a shown
            // ad would silently suppress the next several legitimate chances.
            activity.recordInterstitial(at: now())
        }
        presenter.preload()
        return shown
    }

    /// Shows a rewarded ad in response to a player action, such as asking for a hint.
    ///
    /// Deliberately not paced: the player asked for this one, and refusing it would
    /// mean refusing them the hint they chose to earn. Entitlement still applies —
    /// a player who removed ads gets the reward without watching anything.
    public func showRewarded() async -> RewardOutcome {
        guard adsEnabled else { return .earned }
        if purchases.adsRemoved { return .earned }
        guard presenter.isRewardedReady else {
            presenter.preload()
            return .unavailable
        }

        let outcome = await presenter.showRewarded()
        if outcome == .earned { activity.recordRewarded(at: now()) }
        presenter.preload()
        return outcome
    }

    /// Warms up inventory. Call when gameplay begins.
    public func preload() {
        guard adsEnabled, !purchases.adsRemoved else { return }
        presenter.preload()
    }
}
