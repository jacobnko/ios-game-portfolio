// Owns the "ads removed" entitlement and the purchase flow behind it.

import Foundation
import Observation

/// Conventions for the portfolio's in-app purchase identifiers.
public enum ProductID {
    /// The single non-consumable every game sells: `<bundle id>.removeads`.
    public static func removeAds(bundleID: String) -> String {
        bundleID + ".removeads"
    }

    public static func removeAds(for bundle: Bundle = .main) -> String {
        removeAds(bundleID: bundle.bundleIdentifier ?? "")
    }
}

/// The single authority on whether this player sees ads.
///
/// `adsRemoved` is derived from `Transaction.currentEntitlements` and nothing else —
/// never from a local flag, a UserDefaults key, or CloudKit. A cached flag breaks in
/// both directions: a paying player can lose what they bought, and a synced value can
/// be forged to take it for free.
@MainActor
@Observable
public final class PurchaseManager {
    /// Gate every ad call site on this. One check, one place.
    public private(set) var adsRemoved: Bool = false
    public private(set) var removeAdsProduct: StoreProduct?
    /// True while a purchase or restore is in flight, for disabling buttons.
    public private(set) var isBusy: Bool = false
    public private(set) var lastError: StoreError?
    /// Set when a purchase is waiting on approval, so the UI can say so.
    public private(set) var hasPendingPurchase: Bool = false

    private let client: StoreClient
    private let removeAdsProductID: String
    private var updatesTask: Task<Void, Never>?

    public init(client: StoreClient = StoreKitClient(), removeAdsProductID: String = ProductID.removeAds()) {
        self.client = client
        self.removeAdsProductID = removeAdsProductID
    }

    /// Call once at app launch.
    ///
    /// Starts listening for entitlement changes *before* the first query, so a
    /// transaction that lands during startup is not missed.
    public func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self, client] in
            for await ids in client.entitlementUpdates() {
                self?.apply(entitlements: ids)
            }
        }
        Task { await refresh() }
    }

    /// Stops listening. Call when tearing the app's object graph down.
    ///
    /// There is no `deinit` cleanup because the task is main-actor isolated and
    /// `deinit` is not; the listener holds `self` weakly, so a forgotten `stop()`
    /// leaks only the task, not the manager.
    public func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    /// Re-reads entitlements and product metadata. Safe to call on every launch
    /// and every return to the foreground.
    public func refresh() async {
        apply(entitlements: await client.currentEntitlementIDs())
        await loadProduct()
    }

    public func loadProduct() async {
        do {
            let products = try await client.products(for: [removeAdsProductID])
            removeAdsProduct = products.first { $0.id == removeAdsProductID }
            if removeAdsProduct == nil { lastError = .productNotFound(removeAdsProductID) }
        } catch let error as StoreError {
            lastError = error
        } catch {
            lastError = .unknown("\(error)")
        }
    }

    @discardableResult
    public func purchaseRemoveAds() async -> PurchaseResult {
        guard !isBusy else { return .cancelled }
        isBusy = true
        hasPendingPurchase = false
        lastError = nil
        defer { isBusy = false }

        do {
            let result = try await client.purchase(productID: removeAdsProductID)
            switch result {
            case .purchased:
                // Deliberately not setting `adsRemoved = true` here. Re-reading
                // entitlements keeps one source of truth even on the happy path.
                apply(entitlements: await client.currentEntitlementIDs())
            case .pending:
                hasPendingPurchase = true
            case .unverified:
                lastError = .unknown("unverified transaction")
            case .cancelled:
                break
            }
            return result
        } catch let error as StoreError {
            lastError = error
            return .cancelled
        } catch {
            lastError = .unknown("\(error)")
            return .cancelled
        }
    }

    /// Backs the "Restore Purchases" button.
    ///
    /// Non-consumables restore themselves through `currentEntitlements`, but the
    /// button is required by App Store review and must genuinely work.
    @discardableResult
    public func restore() async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            try await client.restore()
        } catch let error as StoreError {
            lastError = error
        } catch {
            lastError = .unknown("\(error)")
        }

        // Re-read regardless of whether sync threw: the entitlement may already be
        // present locally, and reporting failure then would be wrong.
        apply(entitlements: await client.currentEntitlementIDs())
        return adsRemoved
    }

    private func apply(entitlements ids: Set<String>) {
        adsRemoved = ids.contains(removeAdsProductID)
        if adsRemoved { hasPendingPurchase = false }
    }
}
