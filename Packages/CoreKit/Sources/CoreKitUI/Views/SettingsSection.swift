// Settings building blocks — a titled card and its rows — matching the shared Settings look.

import SwiftUI

/// A titled group of rows in one rounded card, as the shared Settings screen draws them.
public struct SettingsSection<Content: View>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        let ink = theme.palette.onSurface.resolved(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(1.6)
                    .foregroundStyle(ink.opacity(0.5))
                    .padding(.leading, 18)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.palette.surface.resolved(for: colorScheme))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(ink.opacity(0.09), lineWidth: 1))
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

/// One settings row: an icon well, a label, and a trailing accessory.
public struct SettingsRow<Accessory: View>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let label: String
    private let systemImage: String?
    private let detail: String?
    private let showsDivider: Bool
    private let accessory: Accessory

    public init(_ label: String, systemImage: String? = nil, detail: String? = nil, showsDivider: Bool = true,
                @ViewBuilder accessory: () -> Accessory) {
        self.label = label
        self.systemImage = systemImage
        self.detail = detail
        self.showsDivider = showsDivider
        self.accessory = accessory()
    }

    public var body: some View {
        let ink = theme.palette.onSurface.resolved(for: colorScheme)
        HStack(spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.palette.primary.resolved(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(ink.opacity(0.06)))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 16)).foregroundStyle(ink).lineLimit(1)
                if let detail {
                    Text(detail).font(.system(size: 13)).foregroundStyle(ink.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 14)
            accessory
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(ink.opacity(0.06)).frame(height: 1).padding(.leading, 18) }
        }
        .accessibilityElement(children: .combine)
    }
}

public extension SettingsRow where Accessory == EmptyView {
    init(_ label: String, systemImage: String? = nil, detail: String? = nil, showsDivider: Bool = true) {
        self.init(label, systemImage: systemImage, detail: detail, showsDivider: showsDivider) { EmptyView() }
    }
}

/// A small rounded status label for a row's trailing side ("On", "Unlocked").
public struct StatusPill: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let text: String
    private let isPositive: Bool

    public init(_ text: String, isPositive: Bool) {
        self.text = text
        self.isPositive = isPositive
    }

    public var body: some View {
        let tint = isPositive ? theme.palette.primary.resolved(for: colorScheme)
                              : theme.palette.onSurface.resolved(for: colorScheme).opacity(0.55)
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 20) {
        SettingsSection("Sync") {
            ICloudStatusRow(status: .on, showsDivider: true)
            ICloudStatusRow(status: .off)
        }
        SettingsSection("Purchase") {
            PurchaseRow("Full Game", systemImage: "star.fill", state: .available(price: "$3.99")) {}
            PurchaseRow("Full Game", systemImage: "star.fill", state: .owned) {}
            PurchaseRow("Full Game", systemImage: "star.fill", state: .unavailable) {}
        }
    }
    .frame(width: 380)
    .padding()
    .frame(width: 400, height: 600)
    .preferredColorScheme(.light)
}
