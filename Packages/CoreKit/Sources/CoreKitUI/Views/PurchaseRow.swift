// A purchase row that shows one of four store states and buys or does nothing accordingly.

import SwiftUI

public struct PurchaseRow: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let title: String
    private let systemImage: String?
    private let state: PurchaseRowState
    private let onBuy: () -> Void

    public init(_ title: String, systemImage: String? = nil, state: PurchaseRowState, onBuy: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.state = state
        self.onBuy = onBuy
    }

    public var body: some View {
        SettingsRow(title, systemImage: systemImage, detail: state == .unavailable ? CommonStrings.purchaseUnavailable.text : nil) {
            switch state {
            case .owned:
                StatusPill(CommonStrings.purchaseOwned.text, isPositive: true)
            case .available(let price):
                Button(action: onBuy) {
                    Text(price)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(theme.palette.primary.resolved(for: colorScheme)))
                }
                .buttonStyle(.plain)
            case .busy(let pending):
                if pending {
                    StatusPill(CommonStrings.purchasePending.text, isPositive: false)
                } else {
                    ProgressView().frame(minWidth: 44, minHeight: 44)
                }
            case .unavailable:
                StatusPill("—", isPositive: false).accessibilityHidden(true)
            }
        }
    }
}
