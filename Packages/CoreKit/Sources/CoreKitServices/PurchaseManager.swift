// Owns the game's non-consumable entitlements and the purchase flow behind them.

import Foundation
import Observation

/// Conventions for the portfolio's in-app purchase identifiers.
public enum ProductID {
    /// The non-consumable an ad-supported game sells: `<bundle id>.removeads`.
    public static func removeAds(bundleID: String) -> String {
        bundleID + ".removeads"
    }

    public static func removeAds(for bundle: Bundle = .main) -> String {
        removeAds(bundleID: bundle.bundleIdentifier ?? "")
    }

    /// The non-consumable a paid-unlock game sells: `<bundle id>.fullgame`.
    public static func fullGame(bundleID: String) -> String {
        bundleID + ".fullgame"
    }

    public static func fullGame(for bundle: Bundle = .main) -> String {
        fullGame(bundleID: bundle.bundleIdentifier ?? "")
    }
}

/// The single authority on what this player has bought.
///
/// Every entitlement is derived from `Transaction.currentEntitlements` and nothing
/// else — never from a local flag, a Keychain value, a UserDefaults key, or CloudKit.
/// A cached flag breaks in both directions: a paying player can lose what they
/// bought, and a synced value can be forged to take it for free. StoreKit already
/// keeps signed transactions on the device, so this works offline without a cache.
///
/// A manager tracks a fixed set of non-consumable product ids. Ad-supported games
/// use the `removeAdsProductID` initialiser and read `adsRemoved`; other games pass
/// their own ids and read `isEntitled(_:)`.
@MainActor
@Observable
public final class PurchaseManager {
    /// Product ids this player currently owns, limited to the ids this manager tracks.
    public private(set) var entitledProductIDs: Set<String> = []
    /// Store metadata for the tracked products that have loaded, keyed by product id.
    public private(set) var products: [String: StoreProduct] = [:]
    /// True while a purchase or restore is in flight, for disabling buttons.
    public private(set) var isBusy: Bool = false
    public private(set) var lastError: StoreError?
    /// Set when a purchase is waiting on approval, so the UI can say so.
    public private(set) var hasPendingPurchase: Bool = false

    /// Every non-consumable this manager asks the App Store about.
    public let productIDs: Set<String>

    private let client: StoreClient
    /// The id behind `adsRemoved`, or `nil` for a game that sells no ad removal.
    private let removeAdsProductID: String?
    private var updatesTask: Task<Void, Never>?
    /// The product behind `hasPendingPurchase`, so owning a *different* product
    /// does not clear a pending approval for this one.
    private var pendingProductID: String?

    /// An ad-supported game's manager, tracking the single "remove ads" product.
    public init(client: StoreClient = StoreKitClient(), removeAdsProductID: String = ProductID.removeAds()) {
        self.client = client
        self.productIDs = [removeAdsProductID]
        self.removeAdsProductID = removeAdsProductID
    }

    /// A manager for an arbitrary set of non-consumables. `adsRemoved` stays `false`.
    public init(client: StoreClient = StoreKitClient(), productIDs: Set<String>) {
        self.client = client
        self.productIDs = productIDs
        self.removeAdsProductID = nil
    }

    // MARK: - Reading entitlements

    /// Whether the player owns `productID`. Untracked ids are always `false`.
    public func isEntitled(_ productID: String) -> Bool {
        entitledProductIDs.contains(productID)
    }

    /// Store metadata for `productID`, once loaded.
    public func product(_ productID: String) -> StoreProduct? {
        products[productID]
    }

    /// Gate every ad call site on this. One check, one place.
    public var adsRemoved: Bool {
        guard let removeAdsProductID else { return false }
        return isEntitled(removeAdsProductID)
    }

    public var removeAdsProduct: StoreProduct? {
        removeAdsProductID.flatMap { products[$0] }
    }

    // MARK: - Lifecycle

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
        await loadProducts()
    }

    /// Loads metadata for every tracked product.
    ///
    /// A product that fails to load is reported through `lastError` but never
    /// touches entitlements: store metadata being unreachable must not take away
    /// something the player already owns.
    public func loadProducts() async {
        do {
            let loaded = try await client.products(for: productIDs)
            products = Dictionary(
                loaded.filter { productIDs.contains($0.id) }.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            // Sorted so the reported id is the same on every run.
            if let missing = productIDs.sorted().first(where: { products[$0] == nil }) {
                lastError = .productNotFound(missing)
            }
        } catch let error as StoreError {
            lastError = error
        } catch {
            lastError = .unknown("\(error)")
        }
    }

    /// Kept for ad-supported games; identical to `loadProducts()`.
    public func loadProduct() async {
        await loadProducts()
    }

    // MARK: - Purchasing

    @discardableResult
    public func purchase(_ productID: String) async -> PurchaseResult {
        guard productIDs.contains(productID) else {
            // A typo'd id must fail loudly here rather than reach the App Store
            // and come back as an unexplained "not found".
            lastError = .productNotFound(productID)
            return .cancelled
        }
        guard !isBusy else { return .cancelled }
        isBusy = true
        hasPendingPurchase = false
        pendingProductID = nil
        lastError = nil
        defer { isBusy = false }

        do {
            let result = try await client.purchase(productID: productID)
            switch result {
            case .purchased:
                // Deliberately not inserting the id here. Re-reading entitlements
                // keeps one source of truth even on the happy path.
                apply(entitlements: await client.currentEntitlementIDs())
            case .pending:
                pendingProductID = productID
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

    @discardableResult
    public func purchaseRemoveAds() async -> PurchaseResult {
        guard let removeAdsProductID else {
            lastError = .productNotFound(ProductID.removeAds())
            return .cancelled
        }
        return await purchase(removeAdsProductID)
    }

    /// Backs the "Restore Purchases" button. Returns whether the player owns any
    /// tracked product afterwards.
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
        return !entitledProductIDs.isEmpty
    }

    private func apply(entitlements ids: Set<String>) {
        entitledProductIDs = ids.intersection(productIDs)
        if let pendingProductID, entitledProductIDs.contains(pendingProductID) {
            self.pendingProductID = nil
            hasPendingPurchase = false
        }
    }
}
