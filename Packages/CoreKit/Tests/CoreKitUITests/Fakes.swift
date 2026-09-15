// Minimal test doubles for GameFlowCoordinator. Deliberately duplicated rather
// than shared with CoreKitServicesTests — each test target stays free to depend
// only on the module it actually tests.

import Foundation
@testable import CoreKitServices

final class FakeStoreClient: StoreClient, @unchecked Sendable {
    private let lock = NSLock()
    private var entitlements: Set<String>
    var products: [StoreProduct] = []

    init(entitlements: Set<String> = []) { self.entitlements = entitlements }

    func products(for ids: Set<String>) async throws -> [StoreProduct] {
        products.filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseResult { .cancelled }

    func currentEntitlementIDs() async -> Set<String> {
        lock.withLock { entitlements }
    }

    func restore() async throws {}

    func entitlementUpdates() -> AsyncStream<Set<String>> {
        AsyncStream { _ in }
    }
}

@MainActor
final class FakeAdPresenter: AdPresenting {
    var isInterstitialReady = true
    var isRewardedReady = true
    /// Artificial suspension so tests can force two concurrent presentation
    /// attempts to actually overlap in time, rather than one completing before
    /// the second's call frame even starts.
    var interstitialDelayNanoseconds: UInt64 = 0
    private(set) var interstitialShowCount = 0

    func preload() {}

    func showInterstitial() async -> Bool {
        interstitialShowCount += 1
        if interstitialDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: interstitialDelayNanoseconds)
        }
        return true
    }

    func showRewarded() async -> RewardOutcome { .earned }
}
