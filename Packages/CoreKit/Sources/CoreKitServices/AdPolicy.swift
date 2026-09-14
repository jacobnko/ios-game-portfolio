// Decides when an interstitial is allowed. Pure, so the rules can be tuned safely.

import Foundation

/// Why an interstitial was or was not shown.
///
/// Worth carrying around: "ads are not showing" is otherwise very hard to debug,
/// and the distribution of these reasons is what tells you whether the policy is
/// too aggressive or too timid once real players are in it.
public enum InterstitialVerdict: Sendable, Equatable {
    case allowed
    /// The player owns the ad removal purchase.
    case adsRemoved
    /// Still inside the opening run of stages that stays uninterrupted.
    case onboardingGrace
    /// Not enough time since the last interstitial.
    case tooSoon
    /// Not enough stages cleared since the last interstitial.
    case notEnoughClears
    /// A rewarded ad just played; showing another ad now reads as punishment.
    case rewardedCooldown

    public var isAllowed: Bool { self == .allowed }
}

/// Frequency rules for interstitials, shared by every game.
///
/// The defaults deliberately under-show. A casual puzzle session is short, and an
/// interstitial after every single clear is the fastest way to lose day-two
/// retention — which costs far more than the impressions gained.
public struct AdPolicy: Sendable, Equatable {
    /// Stage clears at the start of a fresh install that never get interrupted.
    public var onboardingGraceClears: Int
    /// Minimum wall-clock gap between two interstitials.
    public var minimumInterval: TimeInterval
    /// Minimum stage clears between two interstitials.
    public var minimumClearsBetween: Int
    /// Quiet period after a rewarded ad finishes.
    public var rewardedCooldown: TimeInterval

    public init(
        onboardingGraceClears: Int = 3,
        minimumInterval: TimeInterval = 120,
        minimumClearsBetween: Int = 2,
        rewardedCooldown: TimeInterval = 45
    ) {
        self.onboardingGraceClears = max(0, onboardingGraceClears)
        self.minimumInterval = max(0, minimumInterval)
        self.minimumClearsBetween = max(0, minimumClearsBetween)
        self.rewardedCooldown = max(0, rewardedCooldown)
    }

    public static let standard = AdPolicy()

    /// No pacing at all. For manual testing only.
    public static let unrestricted = AdPolicy(
        onboardingGraceClears: 0, minimumInterval: 0, minimumClearsBetween: 0, rewardedCooldown: 0
    )

    public func verdict(for activity: AdActivity, adsRemoved: Bool, now: TimeInterval) -> InterstitialVerdict {
        // The single gate. Everything else is pacing; this one is an entitlement.
        if adsRemoved { return .adsRemoved }
        if activity.totalClears <= onboardingGraceClears { return .onboardingGrace }

        if let last = activity.lastRewardedAt, now - last < rewardedCooldown {
            return .rewardedCooldown
        }
        if let last = activity.lastInterstitialAt {
            if now - last < minimumInterval { return .tooSoon }
            if activity.clearsSinceInterstitial < minimumClearsBetween { return .notEnoughClears }
        }
        return .allowed
    }
}

/// What the player has done, as far as ad pacing is concerned.
///
/// Session-scoped by design: this is not persisted. Carrying interstitial history
/// across launches would let a player who quits and returns be interrupted on their
/// very first clear back, which is precisely when they are most likely to leave.
public struct AdActivity: Sendable, Equatable {
    public private(set) var totalClears: Int = 0
    public private(set) var clearsSinceInterstitial: Int = 0
    public private(set) var lastInterstitialAt: TimeInterval?
    public private(set) var lastRewardedAt: TimeInterval?

    public init() {}

    public mutating func recordClear() {
        totalClears += 1
        clearsSinceInterstitial += 1
    }

    public mutating func recordInterstitial(at time: TimeInterval) {
        lastInterstitialAt = time
        clearsSinceInterstitial = 0
    }

    public mutating func recordRewarded(at time: TimeInterval) {
        lastRewardedAt = time
    }
}
