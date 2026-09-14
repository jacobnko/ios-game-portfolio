// Real StoreClient backed by StoreKit 2.

import Foundation
import StoreKit

/// Production implementation. Nothing in here decides policy — it only translates.
public struct StoreKitClient: StoreClient {
    public init() {}

    public func products(for ids: Set<String>) async throws -> [StoreProduct] {
        do {
            return try await Product.products(for: ids).map(StoreProduct.init(_:))
        } catch {
            throw StoreError.network
        }
    }

    public func purchase(productID: String) async throws -> PurchaseResult {
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreError.productNotFound(productID)
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw StoreError.unknown("\(error)")
        }

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                // An unverified signature means the receipt cannot be trusted.
                // Do not finish it and do not grant anything.
                return .unverified
            }
            // Finishing is mandatory. An unfinished transaction is redelivered on
            // every launch forever, and the App Store treats it as undelivered.
            await transaction.finish()
            return .purchased(productID: transaction.productID)

        case .userCancelled:
            return .cancelled

        case .pending:
            return .pending

        @unknown default:
            return .cancelled
        }
    }

    public func currentEntitlementIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // currentEntitlements already filters revoked purchases, but a refund
            // that has not propagated yet can still surface here.
            guard transaction.revocationDate == nil else { continue }
            ids.insert(transaction.productID)
        }
        return ids
    }

    public func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw StoreError.unknown("\(error)")
        }
    }

    public func entitlementUpdates() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let task = Task {
                // Catches purchases the app did not initiate: Ask to Buy approvals,
                // a purchase made on another device, an interrupted payment that
                // completed later. Without this the player pays and sees no change.
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                    continuation.yield(await currentEntitlementIDs())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension StoreProduct {
    init(_ product: Product) {
        self.init(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            price: product.price
        )
    }
}
