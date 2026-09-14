// The seam between purchase logic and StoreKit, so the money path can be tested.

import Foundation

/// A purchasable item, reduced to what the UI and the logic actually need.
public struct StoreProduct: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    /// Pre-formatted for the player's storefront and currency. Never format prices by hand.
    public let displayPrice: String
    public let price: Decimal

    public init(id: String, displayName: String, description: String, displayPrice: String, price: Decimal) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.price = price
    }
}

/// What came back from attempting a purchase.
public enum PurchaseResult: Sendable, Equatable {
    /// Verified and finished. The product id is now entitled.
    case purchased(productID: String)
    case cancelled
    /// Ask to Buy, or a payment awaiting approval. The transaction arrives later
    /// through the updates listener, so the UI must not treat this as a failure.
    case pending
    /// The signature did not verify. Treat as not purchased, never as purchased.
    case unverified
}

public enum StoreError: Error, Sendable, Equatable {
    case productNotFound(String)
    case network
    case unknown(String)
}

/// Everything `PurchaseManager` needs from the App Store.
///
/// This exists so the manager's logic can run against a fake. StoreKit cannot be
/// driven from a package test target, and the entitlement rules are exactly the
/// code where a silent mistake either loses a paying customer's purchase or gives
/// the product away.
public protocol StoreClient: Sendable {
    func products(for ids: Set<String>) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseResult
    /// Product ids the player is currently entitled to. Revoked and refunded
    /// purchases must not appear here.
    func currentEntitlementIDs() async -> Set<String>
    /// Restores purchases made on another device or before a reinstall.
    func restore() async throws
    /// Fires whenever entitlements change outside a purchase the app initiated.
    func entitlementUpdates() -> AsyncStream<Set<String>>
}
