// The seam between ad policy and whichever SDK actually renders the ads.

import Foundation

/// Result of showing a rewarded ad.
public enum RewardOutcome: Sendable, Equatable {
    /// The player watched enough to earn the reward. Grant it.
    case earned
    /// Closed early, or the ad failed. Grant nothing.
    case dismissed
    /// Nothing was loaded to show.
    case unavailable
}

/// What `AdCoordinator` needs from an ad SDK.
///
/// Keeping this a protocol means the pacing and entitlement rules are testable
/// without the AdMob SDK, which cannot run on the host or in a package test target.
@MainActor
public protocol AdPresenting: AnyObject {
    var isInterstitialReady: Bool { get }
    var isRewardedReady: Bool { get }
    /// Starts loading whatever is not ready. Safe to call often.
    func preload()
    /// Returns true once the ad has been shown and dismissed.
    func showInterstitial() async -> Bool
    func showRewarded() async -> RewardOutcome
}
