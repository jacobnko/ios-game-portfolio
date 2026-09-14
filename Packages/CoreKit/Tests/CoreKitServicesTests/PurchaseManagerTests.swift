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
