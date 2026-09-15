// The first screen a player sees. Branding and the ad slot are entirely the
// game's own content — CoreKitUI must not depend on CoreKitAdsGoogle, so the
// banner is injected the same way the logo is.

import SwiftUI
import CoreKitServices

/// The home screen shared by every game.
///
/// `logo` and `banner` are slots rather than fixed views because ten games ship
/// ten different visual identities (§6 of the design handoff), and CoreKitUI has
/// no dependency on any ad SDK — this view only owns the layout and the
/// Play/Settings affordances.
public struct HomeView<Logo: View, Banner: View>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let logo: Logo
    private let banner: Banner
    private let onPlay: () -> Void
    private let onSettings: () -> Void

    public init(
        onPlay: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        @ViewBuilder logo: () -> Logo,
        @ViewBuilder banner: () -> Banner
    ) {
        self.onPlay = onPlay
        self.onSettings = onSettings
        self.logo = logo()
        self.banner = banner()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
                }
                .accessibilityLabel(CommonStrings.settings.text)
            }
            .padding()

            Spacer()

            logo

            Spacer()

            Button(action: onPlay) {
                Text(CommonStrings.play.text)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                            .fill(theme.palette.accent.resolved(for: colorScheme))
                    )
            }
            .padding(.bottom, 32)

            banner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background.resolved(for: colorScheme))
    }
}

public extension HomeView where Banner == EmptyView {
    init(onPlay: @escaping () -> Void, onSettings: @escaping () -> Void, @ViewBuilder logo: () -> Logo) {
        self.init(onPlay: onPlay, onSettings: onSettings, logo: logo, banner: { EmptyView() })
    }
}
