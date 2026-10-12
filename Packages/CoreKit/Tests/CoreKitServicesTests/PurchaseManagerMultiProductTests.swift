// Verifies entitlement rules for games that sell non-consumables other than ad removal.

import Testing
import Foundation
@testable import CoreKitServices

private let fullGameID = "com.jacobkostudio.testgame.fullgame"
private let bonusID = "com.jacobkostudio.testgame.bonuspack"
private let otherGameID = "com.jacobkostudio.othergame.fullgame"

private extension StoreProduct {
    static func fullGame(id: String) -> StoreProduct {
        StoreProduct(id: id, displayName: "Full Game", description: "Every stage.", displayPrice: "$3.99", price: 3.99)
    }
}

@MainActor
private func makeManager(_ client: FakeStoreClient, ids: Set<String> = [fullGameID]) -> PurchaseManager {
    client.products = ids.map { StoreProduct.fullGame(id: $0) }
    return PurchaseManager(client: client, productIDs: ids)
}

@MainActor
private func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

// MARK: - Identifiers

@Test func fullGameIDFollowsTheBundleConvention() {
    #expect(ProductID.fullGame(bundleID: "com.jacobkostudio.testgame") == fullGameID)
}

// MARK: - Entitlement derivation

@Test @MainActor func nothingIsOwnedUntilProvenOtherwise() {
    let manager = makeManager(FakeStoreClient())
    #expect(manager.isEntitled(fullGameID) == false)
    #expect(manager.entitledProductIDs.isEmpty)
}

@Test @MainActor func ownedProductIsPickedUpOnRefresh() async {
    let manager = makeManager(FakeStoreClient(entitlements: [fullGameID]))
    await manager.refresh()
    #expect(manager.isEntitled(fullGameID))
}

@Test @MainActor func untrackedEntitlementsAreIgnored() async {
    // Entitlements for a product this manager does not sell (another app sharing a
    // family, a retired product) must never unlock anything here.
    let manager = makeManager(FakeStoreClient(entitlements: [otherGameID]))
    await manager.refresh()
    #expect(manager.entitledProductIDs.isEmpty)
    #expect(manager.isEntitled(otherGameID) == false)
}

@Test @MainActor func aGameWithoutAdRemovalNeverReportsAdsRemoved() async {
    let manager = makeManager(FakeStoreClient(entitlements: [fullGameID]))
    await manager.refresh()
    #expect(manager.adsRemoved == false)
    #expect(manager.removeAdsProduct == nil)
}

@Test @MainActor func eachProductIsTrackedSeparately() async {
    let manager = makeManager(FakeStoreClient(entitlements: [bonusID]), ids: [fullGameID, bonusID])
    await manager.refresh()
    #expect(manager.isEntitled(bonusID))
    #expect(manager.isEntitled(fullGameID) == false)
}

// MARK: - Offline

@Test @MainActor func ownershipSurvivesTheStoreBeingUnreachable() async {
    // Airplane mode: product metadata cannot load, but the signed transaction is
    // on the device. The player must keep what they bought, with no local cache.
    let client = FakeStoreClient(entitlements: [fullGameID])
    client.productsError = .network
    let manager = makeManager(client)
    client.productsError = .network

    await manager.refresh()
    #expect(manager.isEntitled(fullGameID))
    #expect(manager.product(fullGameID) == nil)
    #expect(manager.lastError == .network)
}

// MARK: - Purchasing

@Test @MainActor func purchaseEntitlesOnlyAfterReReading() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    client.purchaseOutcome = .success(.purchased(productID: fullGameID))

    #expect(await manager.purchase(fullGameID) == .purchased(productID: fullGameID))
    #expect(manager.isEntitled(fullGameID))
}

@Test @MainActor func purchasingAnUntrackedIDNeverReachesTheStore() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)

    #expect(await manager.purchase(otherGameID) == .cancelled)
    #expect(client.purchaseCallCount == 0)
    #expect(manager.lastError == .productNotFound(otherGameID))
}

@Test @MainActor func removeAdsPurchaseFailsCleanlyWhenNotSold() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)

    #expect(await manager.purchaseRemoveAds() == .cancelled)
    #expect(client.purchaseCallCount == 0)
    #expect(manager.lastError != nil)
}

@Test @MainActor func pendingIsNotClearedByOwningADifferentProduct() async {
    // The player already owns the bonus pack and asks a parent to buy the full
    // game. Re-reading entitlements must not erase "waiting for approval".
    let client = FakeStoreClient(entitlements: [bonusID])
    let manager = makeManager(client, ids: [fullGameID, bonusID])
    await manager.refresh()
    client.purchaseOutcome = .success(.pending)

    #expect(await manager.purchase(fullGameID) == .pending)
    await manager.refresh()
    #expect(manager.hasPendingPurchase)
}

@Test @MainActor func pendingClearsWhenThatProductArrives() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    manager.start()
    client.purchaseOutcome = .success(.pending)
    _ = await manager.purchase(fullGameID)
    #expect(manager.hasPendingPurchase)

    client.setEntitlements([fullGameID])
    #expect(await eventually { manager.isEntitled(fullGameID) && !manager.hasPendingPurchase })
    manager.stop()
}

// MARK: - Restore and revocation

@Test @MainActor func restoreReportsWhetherAnythingIsOwned() async {
    let client = FakeStoreClient()
    let manager = makeManager(client)
    #expect(await manager.restore() == false)

    client.setEntitlements([fullGameID])
    #expect(await manager.restore())
    #expect(client.restoreCallCount == 2)
}

@Test @MainActor func aRefundTakesTheUnlockAway() async {
    let client = FakeStoreClient(entitlements: [fullGameID])
    let manager = makeManager(client)
    manager.start()
    #expect(await eventually { manager.isEntitled(fullGameID) })

    client.setEntitlements([])
    #expect(await eventually { manager.isEntitled(fullGameID) == false })
    manager.stop()
}

// MARK: - Metadata

@Test @MainActor func everyTrackedProductLoads() async {
    let manager = makeManager(FakeStoreClient(), ids: [fullGameID, bonusID])
    await manager.loadProducts()
    #expect(manager.product(fullGameID)?.displayPrice == "$3.99")
    #expect(manager.product(bonusID) != nil)
    #expect(manager.lastError == nil)
}

@Test @MainActor func theMissingProductIsNamedDeterministically() async {
    let client = FakeStoreClient()
    let manager = PurchaseManager(client: client, productIDs: [fullGameID, bonusID])
    client.products = [.fullGame(id: fullGameID)]
    await manager.loadProducts()
    #expect(manager.lastError == .productNotFound(bonusID))
}
