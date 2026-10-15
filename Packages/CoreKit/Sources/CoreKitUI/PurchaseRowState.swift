// What a single purchase row shows, decided from the store's state alone.

import CoreKitServices

/// The four faces a purchase row can have, whatever the product is.
public enum PurchaseRowState: Equatable, Sendable {
    /// Already owned — show a badge, nothing to tap.
    case owned
    /// For sale at this storefront price (`displayPrice`, never formatted by hand).
    case available(price: String)
    /// A purchase is running or waiting for Ask to Buy / SCA approval.
    case busy(pending: Bool)
    /// The product did not load (offline, misconfigured) — the button stays disabled.
    case unavailable

    public static func make(isEntitled: Bool, product: StoreProduct?, isBusy: Bool, hasPending: Bool) -> PurchaseRowState {
        if isEntitled { return .owned }
        if hasPending { return .busy(pending: true) }
        if isBusy { return .busy(pending: false) }
        guard let product else { return .unavailable }
        return .available(price: product.displayPrice)
    }

    @MainActor
    public static func make(for productID: String, in purchases: PurchaseManager) -> PurchaseRowState {
        make(isEntitled: purchases.isEntitled(productID), product: purchases.product(productID),
             isBusy: purchases.isBusy, hasPending: purchases.hasPendingPurchase)
    }

    public var isTappable: Bool {
        if case .available = self { return true }
        return false
    }
}
