// Test double standing in for the App Store.

import Foundation
@testable import CoreKitServices

/// Scriptable `StoreClient` so purchase and entitlement rules can be tested.
final class FakeStoreClient: StoreClient, @unchecked Sendable {
    private let lock = NSLock()
    private var entitlements: Set<String> = []
    private var continuation: AsyncStream<Set<String>>.Continuation?

    var products: [StoreProduct] = []
    var productsError: StoreError?
    var purchaseOutcome: Result<PurchaseResult, StoreError> = .success(.cancelled)
    var restoreError: StoreError?
    /// Entitlements granted as a side effect of a successful purchase.
    var grantsOnPurchase: Set<String> = []

    private(set) var restoreCallCount = 0
    private(set) var purchaseCallCount = 0

    init(entitlements: Set<String> = []) {
        self.entitlements = entitlements
    }

    func setEntitlements(_ ids: Set<String>) {
        lock.withLock { entitlements = ids }
        continuation?.yield(ids)
    }

    // MARK: - StoreClient

    func products(for ids: Set<String>) async throws -> [StoreProduct] {
        if let productsError { throw productsError }
        return products.filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseResult {
        lock.withLock { purchaseCallCount += 1 }
        switch purchaseOutcome {
        case .failure(let error):
            throw error
        case .success(let result):
            if case .purchased = result {
                lock.withLock { entitlements.formUnion(grantsOnPurchase.isEmpty ? [productID] : grantsOnPurchase) }
            }
            return result
        }
    }

    func currentEntitlementIDs() async -> Set<String> {
        lock.withLock { entitlements }
    }

    func restore() async throws {
        lock.withLock { restoreCallCount += 1 }
        if let restoreError { throw restoreError }
    }

    func entitlementUpdates() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
}

extension StoreProduct {
    static func removeAds(id: String) -> StoreProduct {
        StoreProduct(id: id, displayName: "Remove Ads", description: "Play without ads.", displayPrice: "$2.99", price: 2.99)
    }
}
