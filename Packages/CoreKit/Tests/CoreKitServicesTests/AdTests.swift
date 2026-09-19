// Verifies ad pacing and the single entitlement gate in front of every placement.

import Testing
import Foundation
@testable import CoreKitServices

// MARK: - Ad unit ids

@Test func defaultInventoryIsGooglesTestUnits() {
    // A build that forgets to configure ids must never serve real ones.
    #expect(AdUnitIDs.test.isTestInventory)
    #expect(AdUnitIDs.test.banner.hasPrefix("ca-app-pub-3940256099942544/"))
}

@Test func productionUnitsFallBackToTestUnlessExplicitlyAllowed() {
    // In a debug build `allowsProductionAdUnits` is false, so this must degrade
    // to test inventory rather than burn real impressions during development.
    let ids = AdUnitIDs.production(banner: "real/1", interstitial: "real/2", rewarded: "real/3")
    if CoreKitServices.allowsProductionAdUnits {
        #expect(ids.isTestInventory == false)
        #expect(ids.banner == "real/1")
    } else {
        #expect(ids == .test)
    }
}

@Test func placementLookupMatchesTheStoredIDs() {
    let ids = AdUnitIDs.test
    #expect(ids.id(for: .banner) == ids.banner)
    #expect(ids.id(for: .interstitial) == ids.interstitial)
    #expect(ids.id(for: .rewarded) == ids.rewarded)
}

// MARK: - Activity

@Test func clearsAccumulateUntilAnInterstitialResetsThem() {
    var activity = AdActivity()
    activity.recordClear()
    activity.recordClear()
    #expect(activity.totalClears == 2)
    #expect(activity.clearsSinceInterstitial == 2)

    activity.recordInterstitial(at: 100)
    #expect(activity.totalClears == 2)          // lifetime count is not reset
    #expect(activity.clearsSinceInterstitial == 0)
}

// MARK: - Policy

private func activity(clears: Int, lastInterstitial: TimeInterval? = nil, lastRewarded: TimeInterval? = nil, clearsSince: Int? = nil) -> AdActivity {
    var a = AdActivity()
    for _ in 0..<clears { a.recordClear() }
    if let lastInterstitial {
        a.recordInterstitial(at: lastInterstitial)
        for _ in 0..<(clearsSince ?? 0) { a.recordClear() }
    }
    if let lastRewarded { a.recordRewarded(at: lastRewarded) }
    return a
}

@Test func entitlementBeatsEveryPacingRule() {
    // Even a player who has cleared a hundred stages and waited an hour sees nothing.
    let verdict = AdPolicy.standard.verdict(
        for: activity(clears: 100, lastInterstitial: 0, clearsSince: 50),
        adsRemoved: true,
        now: 100_000
    )
    #expect(verdict == .adsRemoved)
}

@Test func openingStagesAreNeverInterrupted() {
    let policy = AdPolicy.standard
    for clears in 1...policy.onboardingGraceClears {
        #expect(policy.verdict(for: activity(clears: clears), adsRemoved: false, now: 1000) == .onboardingGrace)
    }
    #expect(policy.verdict(for: activity(clears: policy.onboardingGraceClears + 1), adsRemoved: false, now: 1000) == .allowed)
}

@Test func theFirstEligibleInterstitialNeedsNoWait() {
    // With no previous interstitial there is nothing to pace against.
    #expect(AdPolicy.standard.verdict(for: activity(clears: 4), adsRemoved: false, now: 0) == .allowed)
}

@Test func interstitialsRespectTheMinimumInterval() {
    let policy = AdPolicy.standard
    let a = activity(clears: 4, lastInterstitial: 1000, clearsSince: 5)
    #expect(policy.verdict(for: a, adsRemoved: false, now: 1000 + policy.minimumInterval - 1) == .tooSoon)
    #expect(policy.verdict(for: a, adsRemoved: false, now: 1000 + policy.minimumInterval) == .allowed)
}

@Test func interstitialsRespectTheMinimumClearGap() {
    // Enough time has passed, but the player has only finished one stage since.
    let policy = AdPolicy.standard
    let a = activity(clears: 4, lastInterstitial: 0, clearsSince: 1)
    #expect(policy.verdict(for: a, adsRemoved: false, now: 10_000) == .notEnoughClears)
}

@Test func aRewardedAdBuysQuietTime() {
    // Watching a rewarded ad and then immediately being shown an interstitial
    // reads as a punishment for opting in.
    let policy = AdPolicy.standard
    let a = activity(clears: 10, lastRewarded: 5000)
    #expect(policy.verdict(for: a, adsRemoved: false, now: 5000 + policy.rewardedCooldown - 1) == .rewardedCooldown)
    #expect(policy.verdict(for: a, adsRemoved: false, now: 5000 + policy.rewardedCooldown) == .allowed)
}

@Test func unrestrictedPolicyStillHonoursEntitlement() {
    #expect(AdPolicy.unrestricted.verdict(for: activity(clears: 1), adsRemoved: false, now: 0) == .allowed)
    #expect(AdPolicy.unrestricted.verdict(for: activity(clears: 1), adsRemoved: true, now: 0) == .adsRemoved)
}

@Test func policyClampsNegativeConfiguration() {
    let policy = AdPolicy(onboardingGraceClears: -5, minimumInterval: -10, minimumClearsBetween: -2, rewardedCooldown: -1)
    #expect(policy.onboardingGraceClears == 0)
    #expect(policy.minimumInterval == 0)
    #expect(policy.rewardedCooldown == 0)
}

// MARK: - Coordinator

@MainActor
private func makeCoordinator(
    adsRemoved: Bool = false,
    policy: AdPolicy = .unrestricted,
    presenter: FakeAdPresenter = FakeAdPresenter(),
    clock: @escaping @Sendable () -> TimeInterval = { 0 }
) async -> (AdCoordinator, FakeAdPresenter, PurchaseManager) {
    let productID = "com.jacobkostudio.testgame.removeads"
    let client = FakeStoreClient(entitlements: adsRemoved ? [productID] : [])
    client.products = [.removeAds(id: productID)]
    let purchases = PurchaseManager(client: client, removeAdsProductID: productID)
    await purchases.refresh()
    return (AdCoordinator(purchases: purchases, presenter: presenter, policy: policy, now: clock), presenter, purchases)
}

@Test @MainActor func removingAdsSilencesEveryPlacement() async {
    let (ads, presenter, _) = await makeCoordinator(adsRemoved: true)
    ads.recordStageClear()

    #expect(ads.showsBanner == false)
    #expect(await ads.showInterstitialIfAllowed() == false)
    #expect(presenter.interstitialShowCount == 0)   // the SDK is never even asked
    #expect(ads.lastVerdict == .adsRemoved)
}

@Test @MainActor func bannerIsVisibleForFreePlayers() async {
    let (ads, _, _) = await makeCoordinator()
    #expect(ads.showsBanner)
}

@Test @MainActor func anAllowedInterstitialIsShownAndRecorded() async {
    let (ads, presenter, _) = await makeCoordinator(clock: { 500 })
    ads.recordStageClear()

    #expect(await ads.showInterstitialIfAllowed())
    #expect(presenter.interstitialShowCount == 1)
    #expect(ads.activity.lastInterstitialAt == 500)
    #expect(ads.activity.clearsSinceInterstitial == 0)
}

@Test @MainActor func anInterstitialThatFailsToShowIsNotRecorded() async {
    // Counting a failed load as an impression would suppress the next several
    // legitimate chances for no reason.
    let presenter = FakeAdPresenter()
    presenter.interstitialShows = false
    let (ads, _, _) = await makeCoordinator(presenter: presenter)
    ads.recordStageClear()

    #expect(await ads.showInterstitialIfAllowed() == false)
    #expect(ads.activity.lastInterstitialAt == nil)
}

@Test @MainActor func nothingIsShownWhenInventoryIsEmpty() async {
    let presenter = FakeAdPresenter()
    presenter.isInterstitialReady = false
    let (ads, _, _) = await makeCoordinator(presenter: presenter)
    ads.recordStageClear()

    #expect(await ads.showInterstitialIfAllowed() == false)
    #expect(presenter.interstitialShowCount == 0)
}

@Test @MainActor func rewardedAdsGrantTheirReward() async {
    let (ads, presenter, _) = await makeCoordinator(clock: { 900 })
    #expect(await ads.showRewarded() == .earned)
    #expect(presenter.rewardedShowCount == 1)
    #expect(ads.activity.lastRewardedAt == 900)
}

@Test @MainActor func dismissingARewardedAdGrantsNothing() async {
    let presenter = FakeAdPresenter()
    presenter.rewardOutcome = .dismissed
    let (ads, _, _) = await makeCoordinator(presenter: presenter)

    #expect(await ads.showRewarded() == .dismissed)
    #expect(ads.activity.lastRewardedAt == nil)   // no cooldown earned
}

@Test @MainActor func playersWhoRemovedAdsGetRewardsForFree() async {
    // Refusing the hint because there is no ad to show would punish the person
    // who paid. They asked for the reward; give it.
    let (ads, presenter, _) = await makeCoordinator(adsRemoved: true)
    #expect(await ads.showRewarded() == .earned)
    #expect(presenter.rewardedShowCount == 0)
}

@Test @MainActor func anEmptyRewardedSlotReportsUnavailableAndRefills() async {
    let presenter = FakeAdPresenter()
    presenter.isRewardedReady = false
    let (ads, _, _) = await makeCoordinator(presenter: presenter)

    #expect(await ads.showRewarded() == .unavailable)
    #expect(presenter.preloadCount > 0)
}

@Test @MainActor func paidPlayersNeverTriggerAdLoads() async {
    // Preloading for someone who will never see an ad wastes bandwidth and battery.
    let (ads, presenter, _) = await makeCoordinator(adsRemoved: true)
    ads.preload()
    ads.recordStageClear()
    #expect(presenter.preloadCount == 0)
}

// MARK: - Launch-time ad kill switch

@MainActor
private func makeDisabledCoordinator(
    presenter: FakeAdPresenter = FakeAdPresenter(),
    clock: @escaping @Sendable () -> TimeInterval = { 0 }
) async -> (AdCoordinator, FakeAdPresenter) {
    let productID = "com.jacobkostudio.testgame.removeads"
    let client = FakeStoreClient(entitlements: [])
    client.products = [.removeAds(id: productID)]
    let purchases = PurchaseManager(client: client, removeAdsProductID: productID)
    await purchases.refresh()
    let ads = AdCoordinator(
        purchases: purchases, presenter: presenter, policy: .unrestricted,
        adsEnabled: false, now: clock
    )
    return (ads, presenter)
}

@Test @MainActor func disablingAdsHidesTheBannerForAnUnpaidPlayer() async {
    // The launch switch is not the same thing as the entitlement — a free
    // player normally sees a banner, but not in a build with ads off.
    let (ads, _) = await makeDisabledCoordinator()
    #expect(ads.showsBanner == false)
}

@Test @MainActor func disablingAdsSkipsTheInterstitialWithoutAskingTheSDK() async {
    let (ads, presenter) = await makeDisabledCoordinator()
    ads.recordStageClear()
    #expect(await ads.showInterstitialIfAllowed() == false)
    #expect(presenter.interstitialShowCount == 0)
    #expect(presenter.preloadCount == 0)  // never even warmed up
}

@Test @MainActor func disablingAdsStillGrantsTheRewardedAction() async {
    // A hint must keep working with ads off — it just stops costing a watch.
    let (ads, presenter) = await makeDisabledCoordinator()
    #expect(await ads.showRewarded() == .earned)
    #expect(presenter.rewardedShowCount == 0)
}

@Test @MainActor func disablingAdsHidesTheRewardedBadge() async {
    let (ads, _) = await makeDisabledCoordinator()
    #expect(ads.showsRewardedBadge == false)
}

@Test @MainActor func aPlayerWhoRemovedAdsStillHidesTheBadgeRegardlessOfTheLaunchSwitch() async {
    // Two independent reasons to hide the same badge; either alone is enough.
    let (ads, _, _) = await makeCoordinator(adsRemoved: true)
    #expect(ads.showsRewardedBadge == false)
}

@Test @MainActor func theBadgeShowsOnlyWhenAdsAreOnAndNotRemoved() async {
    let (ads, _, _) = await makeCoordinator()
    #expect(ads.showsRewardedBadge)
}

@Test @MainActor func enablingAdsIsTheDefault() async {
    // The parameter defaults to on, so every existing call site (and every
    // test above that never mentions it) keeps its current behaviour.
    let (ads, _, _) = await makeCoordinator()
    #expect(ads.showsBanner)
}

// MARK: - Banner-only switch

@MainActor
private func makeBannerlessCoordinator(
    presenter: FakeAdPresenter = FakeAdPresenter(),
    clock: @escaping @Sendable () -> TimeInterval = { 0 }
) async -> (AdCoordinator, FakeAdPresenter) {
    let productID = "com.jacobkostudio.testgame.removeads"
    let client = FakeStoreClient(entitlements: [])
    client.products = [.removeAds(id: productID)]
    let purchases = PurchaseManager(client: client, removeAdsProductID: productID)
    await purchases.refresh()
    let ads = AdCoordinator(
        purchases: purchases, presenter: presenter, policy: .unrestricted,
        bannerEnabled: false, now: clock
    )
    return (ads, presenter)
}

@Test @MainActor func hidingOnlyTheBannerLeavesEverythingElseLive() async {
    // The whole point of the separate switch: an interstitial, a rewarded ad,
    // and the badge that announces it must all still fire with the banner off.
    let (ads, presenter) = await makeBannerlessCoordinator(clock: { 500 })
    ads.recordStageClear()

    #expect(ads.showsBanner == false)
    #expect(await ads.showInterstitialIfAllowed())
    #expect(presenter.interstitialShowCount == 1)
    #expect(ads.showsRewardedBadge)
}

@Test @MainActor func bannerEnabledIsTheDefault() async {
    let (ads, _, _) = await makeCoordinator()
    #expect(ads.showsBanner)
}

@Test @MainActor func removingAdsHidesTheBannerEvenWithTheBannerSwitchOn() async {
    // Two independent reasons to hide a banner; the entitlement still wins
    // regardless of which launch switch is set.
    let (ads, _, _) = await makeCoordinator(adsRemoved: true)
    #expect(ads.showsBanner == false)
}
