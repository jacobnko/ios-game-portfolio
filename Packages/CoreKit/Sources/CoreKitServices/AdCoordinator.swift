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

    /// Whether a banner should currently be on screen.
    ///
    /// Games bind their banner container's visibility to this rather than checking
    /// entitlement themselves.
    public var showsBanner: Bool { !purchases.adsRemoved }

    public init(
        purchases: PurchaseManager,
        presenter: AdPresenting,
        policy: AdPolicy = .standard,
        now: @escaping @Sendable () -> TimeInterval = { Date.timeIntervalSinceReferenceDate }
    ) {
        self.purchases = purchases
        self.presenter = presenter
        self.policy = policy
        self.now = now
    }

    /// Call after every stage clear, whether or not an ad follows.
    public func recordStageClear() {
        activity.recordClear()
        if !purchases.adsRemoved { presenter.preload() }
    }

    /// Shows an interstitial if the policy and the entitlement both allow it.
    ///
    /// Returns whether one was actually shown, so the caller can delay a transition.
    @discardableResult
    public func showInterstitialIfAllowed() async -> Bool {
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
        guard !purchases.adsRemoved else { return }
        presenter.preload()
    }
}
