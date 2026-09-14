// Test double standing in for an ad SDK.

import Foundation
@testable import CoreKitServices

@MainActor
final class FakeAdPresenter: AdPresenting {
    var isInterstitialReady = true
    var isRewardedReady = true
    /// What `showInterstitial()` reports back.
    var interstitialShows = true
    var rewardOutcome: RewardOutcome = .earned

    private(set) var preloadCount = 0
    private(set) var interstitialShowCount = 0
    private(set) var rewardedShowCount = 0

    func preload() { preloadCount += 1 }

    func showInterstitial() async -> Bool {
        interstitialShowCount += 1
        return interstitialShows
    }

    func showRewarded() async -> RewardOutcome {
        rewardedShowCount += 1
        return rewardOutcome
    }
}
