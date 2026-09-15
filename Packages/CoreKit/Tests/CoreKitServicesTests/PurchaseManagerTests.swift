// Verifies the entitlement rules that decide whether a player sees ads.

import Testing
import Foundation
@testable import CoreKitServices

private let removeAdsID = "com.jacobkostudio.testgame.removeads"

@MainActor
private func makeManager(_ client: FakeStoreClient) -> PurchaseManager {
    client.products = [.removeAds(id: removeAdsID)]
    return PurchaseManager(client: client, removeAdsProductID: removeAdsID)
}

// MARK: - Product identifiers

@Test func productIDFollowsTheBundleConvention() {
    #expect(ProductID.removeAds(bundleID: "com.jacobkostudio.chordline") == "com.jacobkostudio.chordline.removeads")
}

// MARK: - Entitlement derivation

@Test @MainActor func adsAreShownUntilProvenOtherwise() async {
    // The safe default is "not entitled". A manager that starts optimistic would
    // briefly hide ads for everyone on every launch.
    let manager = makeManager(FakeStoreClient())
    #expect(manager.adsRemoved == false)
}

@Test @MainActor func existingEntitlementIsPickedUpOnRefresh() async {
    let client = FakeStoreClient(entitlements: [removeAdsID])
    let manager = makeManager(client)
    await manager.refresh()
    #expect(manager.adsRemoved)
}

@Test @MainActor func anUnrelatedEntitlementGrantsNothing() async {
    // Owning some other product must never remove ads.
    let client = FakeStoreClient(entitlements: ["com.jacobkostudio.othergame.removeads"])
    let manager = makeManager(client)
    await manager.refresh()
    #expect(manager.adsRemoved == false)
}

@Test @MainActor func losingTheEntitlementRestoresAds() async {
    // Refunds and revocations drop out of currentEntitlements. The flag must follow
    // it back down, which a cached local boolean would not do.
    let client = FakeStoreClient(entitlements: [removeAdsID])
    let manager = makeManager(client)
    await manager.refresh()
    #expect(manager.adsRemoved)

    client.setEntitlements([])
    await manager.refresh()
    #expect(manager.adsRemoved == false)
}

// MARK: - Purchasing

@Test @MainActor func successfulPurchaseRemovesAds() async {
    let client = FakeStoreClient()
    client.purchaseOutcome = .success(.purchased(productID: removeAdsID))
    let manager = makeManager(client)

    let result = await manager.purchaseRemoveAds()
    #expect(result == .purchased(productID: removeAdsID))
    #expect(manager.adsRemoved)
    #expect(manager.lastError == nil)
}

@Test @MainActor func cancellingChangesNothing() async {
    let client = FakeStoreClient()
    client.purchaseOutcome = .success(.cancelled)
    let manager = makeManager(client)

    #expect(await manager.purchaseRemoveAds() == .cancelled)
    #expect(manager.adsRemoved == false)
    #expect(manager.lastError == nil)  // cancelling is not an error
}

@Test @MainActor func unverifiedPurchaseGrantsNothing() async {
    // A signature that does not verify must be treated as no purchase at all.
    let client = FakeStoreClient()
    client.purchaseOutcome = .success(.unverified)
    let manager = makeManager(client)

    #expect(await manager.purchaseRemoveAds() == .unverified)
    #expect(manager.adsRemoved == false)
    #expect(manager.lastError != nil)
}

@Test @MainActor func pendingPurchaseIsNotAFailure() async {
    // Ask to Buy: the parent has not approved yet. The UI must say "waiting",
    // not "failed", and the entitlement arrives later through the updates stream.
    let client = FakeStoreClient()
    client.purchaseOutcome = .success(.pending)
    let manager = makeManager(client)

    #expect(await manager.purchaseRemoveAds() == .pending)
    #expect(manager.hasPendingPurchase)
    #expect(manager.adsRemoved == false)
    #expect(manager.lastError == nil)
}

@Test @MainActor func purchaseErrorsSurfaceWithoutGranting() async {
    let client = FakeStoreClient()
    client.purchaseOutcome = .failure(.network)
    let manager = makeManager(client)

    _ = await manager.purchaseRemoveAds()
    #expect(manager.adsRemoved == false)
    #expect(manager.lastError == .network)
}

// MARK: - Restore

@Test @MainActor func restoreRecoversAPreviousPurchase() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    #expect(manager.adsRemoved == false)

    // Simulates the App Store handing the entitlement back during sync.
    client.setEntitlements([removeAdsID])
    let restored = await manager.restore()

    #expect(restored)
    #expect(manager.adsRemoved)
    #expect(client.restoreCallCount == 1)
}

@Test @MainActor func restoreStillReadsEntitlementsWhenSyncFails() async {
    // The entitlement can already be present locally. Reporting failure because
    // the network sync threw would tell a paying player they own nothing.
    let client = FakeStoreClient(entitlements: [removeAdsID])
    client.restoreError = .network
    let manager = makeManager(client)

    #expect(await manager.restore())
    #expect(manager.adsRemoved)
    #expect(manager.lastError == .network)  // reported, but not fatal to the outcome
}

@Test @MainActor func restoreWithNothingToRestoreReportsFalse() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    #expect(await manager.restore() == false)
    #expect(manager.adsRemoved == false)
}

// MARK: - Product metadata

@Test @MainActor func productMetadataLoadsForTheUI() async {
    let manager = makeManager(FakeStoreClient())
    await manager.loadProduct()
    #expect(manager.removeAdsProduct?.displayPrice == "$2.99")
}

@Test @MainActor func missingProductIsReportedNotCrashed() async {
    let client = FakeStoreClient()
    client.products = []
    let manager = PurchaseManager(client: client, removeAdsProductID: removeAdsID)
    await manager.loadProduct()

    #expect(manager.removeAdsProduct == nil)
    #expect(manager.lastError == .productNotFound(removeAdsID))
}

@Test @MainActor func productLoadFailureDoesNotAffectEntitlement() async {
    // Store metadata being unreachable must not make a paying player see ads.
    let client = FakeStoreClient(entitlements: [removeAdsID])
    client.productsError = .network
    let manager = PurchaseManager(client: client, removeAdsProductID: removeAdsID)

    await manager.refresh()
    #expect(manager.adsRemoved)
    #expect(manager.removeAdsProduct == nil)
}

// MARK: - The updates listener
//
// Never executed by any test until the third audit pass, despite being the path
// that delivers Ask to Buy approvals, purchases made on another device, and
// payments that completed after being interrupted. If it is broken the player
// pays and nothing happens, which is the worst outcome this file can produce.

/// Waits for a condition, so an async listener can be observed without sleeping blindly.
@MainActor
private func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

@Test @MainActor func startPicksUpEntitlementsAlreadyOwned() async {
    let client = FakeStoreClient(entitlements: [removeAdsID])
    let manager = makeManager(client)

    manager.start()
    #expect(await eventually { manager.adsRemoved })
    manager.stop()
}

@Test @MainActor func anEntitlementArrivingLaterIsPickedUp() async {
    // Ask to Buy: the parent approves minutes after the child tapped Buy. Nothing
    // in the app asked for this; it arrives through the updates stream.
    let client = FakeStoreClient()
    let manager = makeManager(client)
    manager.start()
    #expect(await eventually { manager.removeAdsProduct != nil })
    #expect(manager.adsRemoved == false)

    client.setEntitlements([removeAdsID])
    #expect(await eventually { manager.adsRemoved })
    manager.stop()
}

@Test @MainActor func aRevokedEntitlementArrivingLaterRestoresAds() async {
    let client = FakeStoreClient(entitlements: [removeAdsID])
    let manager = makeManager(client)
    manager.start()
    #expect(await eventually { manager.adsRemoved })

    client.setEntitlements([])
    #expect(await eventually { manager.adsRemoved == false })
    manager.stop()
}

@Test @MainActor func stoppingEndsTheSubscription() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    manager.start()
    #expect(await eventually { manager.removeAdsProduct != nil })

    manager.stop()
    client.setEntitlements([removeAdsID])
    // Not observed any more, so the flag must not move on its own.
    for _ in 0..<50 { await Task.yield() }
    #expect(manager.adsRemoved == false)
}

@Test @MainActor func startingTwiceDoesNotStackListeners() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    manager.start()
    manager.start()
    client.setEntitlements([removeAdsID])
    #expect(await eventually { manager.adsRemoved })
    manager.stop()
}

@Test func theProductIDComesFromTheBundleByDefault() {
    // Guards the convention itself: a game that forgets to pass an id must still
    // end up asking the App Store for its own product, not a placeholder.
    let bundle = Bundle(for: FakeStoreClient.self)
    let derived = ProductID.removeAds(for: bundle)
    #expect(derived.hasSuffix(".removeads"))
}
