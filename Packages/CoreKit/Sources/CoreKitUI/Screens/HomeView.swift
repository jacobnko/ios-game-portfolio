// The first screen a player sees. Branding and the ad slot are entirely the
// game's own content — CoreKitUI must not depend on CoreKitAdsGoogle, so the
// banner is injected the same way the logo is.

import SwiftUI
import CoreKitServices

/// A second play mode offered next to the primary one.
///
/// Separate from the primary `onPlay` rather than a generic list of buttons:
/// the second mode is almost always gated on finishing the first, and the
/// locked state (dimmed, non-tappable, with its own label) is the part games
/// would otherwise each reimplement slightly differently.
public struct HomeSecondaryMode {
    public let title: String
    public let lockedTitle: String
    public let isLocked: Bool
    public let action: () -> Void

    public init(title: String, lockedTitle: String, isLocked: Bool, action: @escaping () -> Void) {
        self.title = title
        self.lockedTitle = lockedTitle
        self.isLocked = isLocked
        self.action = action
    }
}

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
    private let secondaryMode: HomeSecondaryMode?

    public init(
        onPlay: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        secondaryMode: HomeSecondaryMode? = nil,
        @ViewBuilder logo: () -> Logo,
        @ViewBuilder banner: () -> Banner
    ) {
        self.onPlay = onPlay
        self.onSettings = onSettings
        self.secondaryMode = secondaryMode
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
            .padding(.bottom, secondaryMode == nil ? 32 : 12)

            if let secondaryMode {
                secondaryButton(secondaryMode)
                    .padding(.bottom, 32)
            }

            banner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background.resolved(for: colorScheme))
    }

    /// Outlined rather than filled, so the primary CTA stays the only solid
    /// block of colour on the screen even once a second mode is unlocked.
    private func secondaryButton(_ mode: HomeSecondaryMode) -> some View {
        Button(action: mode.isLocked ? {} : mode.action) {
            HStack(spacing: 8) {
                if mode.isLocked {
                    Image(systemName: "lock.fill").font(.footnote)
                }
                Text(mode.isLocked ? mode.lockedTitle : mode.title)
                    .font(theme.typography.body)
            }
            .foregroundStyle(
                theme.palette.onSurface.resolved(for: colorScheme)
                    .opacity(mode.isLocked ? 0.45 : 1)
            )
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                    .stroke(
                        theme.palette.secondary.resolved(for: colorScheme)
                            .opacity(mode.isLocked ? 0.25 : 1),
                        lineWidth: 1.5
                    )
            )
        }
        .disabled(mode.isLocked)
        .accessibilityLabel(mode.isLocked ? mode.lockedTitle : mode.title)
    }
}

public extension HomeView where Banner == EmptyView {
    init(
        onPlay: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        secondaryMode: HomeSecondaryMode? = nil,
        @ViewBuilder logo: () -> Logo
    ) {
        self.init(
            onPlay: onPlay, onSettings: onSettings, secondaryMode: secondaryMode,
            logo: logo, banner: { EmptyView() }
        )
    }
}
