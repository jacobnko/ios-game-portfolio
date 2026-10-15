// Checks the shared settings parts' decisions: card width, purchase-row state, iCloud wording.

import Testing
import CoreGraphics
import Foundation
@testable import CoreKitUI
@testable import CoreKitServices

@Test func phonesUseTheFullWidthAndTabletsACappedCard() {
    #expect(AdaptiveCardMetrics.contentWidth(container: 393, isRegular: false) == 361)
    #expect(AdaptiveCardMetrics.contentWidth(container: 744, isRegular: true) == 560)
    #expect(AdaptiveCardMetrics.contentWidth(container: 500, isRegular: true) == 468, "never wider than the container")
    #expect(AdaptiveCardMetrics.contentWidth(container: 10, isRegular: false) == 0)
}

@Test func aPurchaseRowShowsOneOfFourFaces() {
    let product = StoreProduct(id: "x.fullgame", displayName: "Full Game", description: "", displayPrice: "NZ$6.99", price: 6.99)
    #expect(PurchaseRowState.make(isEntitled: true, product: product, isBusy: true, hasPending: true) == .owned, "owned wins")
    #expect(PurchaseRowState.make(isEntitled: false, product: product, isBusy: false, hasPending: true) == .busy(pending: true))
    #expect(PurchaseRowState.make(isEntitled: false, product: product, isBusy: true, hasPending: false) == .busy(pending: false))
    #expect(PurchaseRowState.make(isEntitled: false, product: nil, isBusy: false, hasPending: false) == .unavailable)
    let forSale = PurchaseRowState.make(isEntitled: false, product: product, isBusy: false, hasPending: false)
    #expect(forSale == .available(price: "NZ$6.99"), "the storefront price, never formatted by hand")
    #expect(forSale.isTappable)
    #expect(!PurchaseRowState.owned.isTappable && !PurchaseRowState.unavailable.isTappable)
}

@MainActor
@Test func aPurchaseRowReadsTheManager() async {
    let client = FakeStoreClient()
    let manager = PurchaseManager(client: client, productIDs: ["x.fullgame"])
    #expect(PurchaseRowState.make(for: "x.fullgame", in: manager) == .unavailable)
}

#if canImport(CloudKit)
import CloudKit

@Test func iCloudAccountStatesMapToWhatTheRowSays() {
    #expect(ICloudStatus(CKAccountStatus.available) == .on)
    #expect(ICloudStatus(CKAccountStatus.noAccount) == .off)
    #expect(ICloudStatus(CKAccountStatus.restricted) == .restricted)
    #expect(ICloudStatus(CKAccountStatus.temporarilyUnavailable) == .unavailable)
    #expect(ICloudStatus(CKAccountStatus.couldNotDetermine) == .unavailable)
    #expect(ICloudStatus.on.isSyncing && !ICloudStatus.off.isSyncing)
}
#endif

@Test func newSharedStringsHaveEveryLanguage() throws {
    // The host never compiles .xcstrings, so read the catalog file itself.
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../Sources/CoreKitUI/Resources/Common.xcstrings").standardized
    let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    let strings = catalog?["strings"] as? [String: Any] ?? [:]
    let languages: Set<String> = ["en", "ko", "ja", "de", "fr", "es-MX", "pt-BR"]
    for key in [CommonStrings.purchaseOwned, .purchaseUnavailable, .settingsOn, .settingsOff, .settingsICloudSync,
                .settingsICloudOffHint, .settingsICloudRestricted, .settingsICloudUnavailable] {
        let entry = strings[key.rawValue] as? [String: Any]
        let localized = Set((entry?["localizations"] as? [String: Any] ?? [:]).keys)
        #expect(localized == languages, "\(key.rawValue)")
    }
}
