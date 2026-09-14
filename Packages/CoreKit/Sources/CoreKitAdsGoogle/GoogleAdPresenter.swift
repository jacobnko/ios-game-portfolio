// AdPresenting implemented against the Google Mobile Ads SDK.

#if os(iOS)
import Foundation
import UIKit
import GoogleMobileAds
import CoreKitServices

/// Loads and presents AdMob full-screen ads.
///
/// Holds no policy: whether an ad *should* appear is decided by `AdCoordinator`
/// and `AdPolicy`, which are testable. This type only knows how to fetch and show.
@MainActor
public final class GoogleAdPresenter: NSObject, AdPresenting {
    private let adUnitIDs: AdUnitIDs

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var isLoadingInterstitial = false
    private var isLoadingRewarded = false

    private var interstitialContinuation: CheckedContinuation<Bool, Never>?
    private var rewardedContinuation: CheckedContinuation<RewardOutcome, Never>?
    private var didEarnReward = false

    /// Fires if the SDK never reports the presentation ending.
    private var watchdog: Task<Void, Never>?

    /// Only one full-screen ad can be on screen at a time.
    ///
    /// Without this, an interstitial and a rewarded ad could both be awaiting a
    /// continuation, and the single delegate callback would resolve both with the
    /// same outcome — handing out a reward nobody watched, or swallowing one
    /// somebody did.
    private var isPresenting = false

    public init(adUnitIDs: AdUnitIDs = .test) {
        self.adUnitIDs = adUnitIDs
        super.init()
    }

    public var isInterstitialReady: Bool { interstitial != nil }
    public var isRewardedReady: Bool { rewarded != nil }

    public func preload() {
        loadInterstitialIfNeeded()
        loadRewardedIfNeeded()
    }

    public func showInterstitial() async -> Bool {
        guard !isPresenting else { return false }
        guard let ad = interstitial, let root = Self.currentRootViewController() else { return false }
        isPresenting = true
        // Consume immediately. A full-screen ad object is single use, and leaving it
        // in place would let a second call present an already-spent ad.
        interstitial = nil

        return await withCheckedContinuation { continuation in
            interstitialContinuation = continuation
            startWatchdog()
            ad.fullScreenContentDelegate = self
            ad.present(from: root)
        }
    }

    public func showRewarded() async -> RewardOutcome {
        guard !isPresenting else { return .unavailable }
        guard let ad = rewarded, let root = Self.currentRootViewController() else { return .unavailable }
        isPresenting = true
        rewarded = nil
        didEarnReward = false

        return await withCheckedContinuation { continuation in
            rewardedContinuation = continuation
            startWatchdog()
            ad.fullScreenContentDelegate = self
            ad.present(from: root) { [weak self] in
                // Fires when the player has watched enough. Dismissal is reported
                // separately, so the reward is recorded here and resolved there.
                self?.didEarnReward = true
            }
        }
    }

    // MARK: - Loading

    private func loadInterstitialIfNeeded() {
        guard interstitial == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        Task { [adUnitIDs] in
            defer { isLoadingInterstitial = false }
            interstitial = try? await InterstitialAd.load(with: adUnitIDs.interstitial, request: Request())
        }
    }

    private func loadRewardedIfNeeded() {
        guard rewarded == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        Task { [adUnitIDs] in
            defer { isLoadingRewarded = false }
            rewarded = try? await RewardedAd.load(with: adUnitIDs.rewarded, request: Request())
        }
    }

    private static func currentRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
    }

    /// Resolves the presentation if the SDK never does.
    ///
    /// A continuation that is never resumed does not crash — it simply never
    /// returns, so a game awaiting an interstitial before advancing to the next
    /// stage would hang there permanently. That is a far worse failure than a
    /// missed impression, so it gets an explicit deadline.
    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(90))
            guard !Task.isCancelled else { return }
            self?.finishPresentation(shown: false)
        }
    }

    /// Resolves whichever presentation is in flight, exactly once.
    ///
    /// A continuation resumed twice traps, and one never resumed hangs the caller
    /// forever — so both delegate paths funnel through here.
    private func finishPresentation(shown: Bool) {
        watchdog?.cancel()
        watchdog = nil
        isPresenting = false
        if let continuation = interstitialContinuation {
            interstitialContinuation = nil
            continuation.resume(returning: shown)
        }
        if let continuation = rewardedContinuation {
            rewardedContinuation = nil
            continuation.resume(returning: shown && didEarnReward ? .earned : .dismissed)
        }
        preload()
    }
}

extension GoogleAdPresenter: FullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation(shown: true)
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finishPresentation(shown: false)
    }
}
#endif
