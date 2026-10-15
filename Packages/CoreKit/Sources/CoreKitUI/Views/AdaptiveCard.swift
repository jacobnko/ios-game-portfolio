// Holds a secondary screen's content: full width on phones, a centred card on iPad.

import SwiftUI

public struct AdaptiveCard<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private let maxWidth: CGFloat
    private let content: Content

    public init(maxWidth: CGFloat = AdaptiveCardMetrics.defaultMaxWidth, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    public var body: some View {
        GeometryReader { proxy in
            let regular = sizeClass == .regular
            let width = AdaptiveCardMetrics.contentWidth(container: proxy.size.width, isRegular: regular, maxWidth: maxWidth)
            content
                .frame(width: width)
                .padding(regular ? 24 : 0)
                .background {
                    if regular {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(theme.palette.surface.resolved(for: colorScheme).opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 32)
                                .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.08), lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
