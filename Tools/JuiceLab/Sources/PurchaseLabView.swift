// Drives the real purchase flow against the local StoreKit configuration file.

import SwiftUI
import CoreKitServices

struct PurchaseLabView: View {
    @State private var manager = PurchaseManager()
    @State private var lastResult: String = "—"

    var body: some View {
        Form {
            Section("Entitlement") {
                LabeledContent("Ads removed") {
                    Text(manager.adsRemoved ? "YES" : "no")
                        .font(.headline)
                        .foregroundStyle(manager.adsRemoved ? .green : .secondary)
                }
                LabeledContent("Product", value: manager.removeAdsProduct?.displayPrice ?? "not loaded")
                if manager.hasPendingPurchase {
                    Label("Waiting for approval", systemImage: "clock")
                        .foregroundStyle(.orange)
                }
                if let error = manager.lastError {
                    Text("\(error)").font(.caption).foregroundStyle(.red)
                }
            }

            Section("Actions") {
                Button("Buy \(manager.removeAdsProduct?.displayName ?? "Remove Ads")") {
                    Task { lastResult = "\(await manager.purchaseRemoveAds())" }
                }
                .disabled(manager.isBusy || manager.adsRemoved)

                Button("Restore Purchases") {
                    Task { lastResult = "restored: \(await manager.restore())" }
                }
                .disabled(manager.isBusy)

                Button("Refresh entitlements") {
                    Task { await manager.refresh(); lastResult = "refreshed" }
                }
                .disabled(manager.isBusy)

                LabeledContent("Last result", value: lastResult)
            }

            Section {
                Text("""
                Xcode → Debug → StoreKit → Manage Transactions lets you refund or revoke the purchase. \
                Doing so must flip "Ads removed" back to no on the next refresh — that is the whole point \
                of deriving it from currentEntitlements instead of caching a flag.
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Purchases")
        .task { manager.start() }
    }
}

#Preview {
    NavigationStack { PurchaseLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
