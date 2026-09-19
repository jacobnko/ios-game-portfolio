// The first screen a player sees. Branding and the ad slot are entirely the
// game's own content — CoreKitUI must not depend on CoreKitAdsGoogle, so the
// banner is injected the same way the logo is.

import SwiftUI
import CoreKitJuice
import CoreKitServices

/// Where a player stands in one ladder.
public enum HomeModeState: Sendable, Equatable {
    /// Every stage cleared. Steps back so the live ladder can take the focus.
    case cleared
    /// The ladder to play now — the one glowing control on the screen.
    case current
    /// Not open yet. Visible on purpose: the ladder ahead is the reason to
    /// finish the one in hand.
    case locked
}

/// One play mode offered on the home screen.
public struct HomeMode: Identifiable {
    public let id: String
    public let title: String
    /// Shown instead of `title` while locked — says what opens it.
    public let lockedTitle: String
    public let state: HomeModeState
    public let action: () -> Void

    public init(
        id: String,
        title: String,
        lockedTitle: String,
        state: HomeModeState,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.lockedTitle = lockedTitle
        self.state = state
        self.action = action
    }
}

/// The home screen shared by every game.
///
/// `logo` and `banner` are slots rather than fixed views because ten games ship
/// ten different visual identities (§6 of the design handoff), and CoreKitUI has
/// no dependency on any ad SDK — this view only owns the layout and the
/// mode/settings affordances.
///
/// Modes are a list rather than a primary CTA plus extras so that the screen
/// reads at a glance: exactly one of them is `current` and it is the only
/// filled, glowing control, finished ladders shrink to a checked row, and
/// locked ones stay visible but dim. Every colour comes from the theme, so the
/// ten games share the shape and not the look — the Guideline 4.3 point in
/// CLAUDE.md §0.3.
public struct HomeView<Logo: View, Banner: View>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let logo: Logo
    private let banner: Banner
    private let modes: [HomeMode]
    private let onSettings: () -> Void

    @State private var soundEnabled = PitchedTonePlayer.shared.isEnabled

    public init(
        modes: [HomeMode],
        onSettings: @escaping () -> Void,
        @ViewBuilder logo: () -> Logo,
        @ViewBuilder banner: () -> Banner
    ) {
        self.modes = modes
        self.onSettings = onSettings
        self.logo = logo()
        self.banner = banner()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                settingsButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 24)

            logo

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                ForEach(modes) { mode in
                    modeRow(mode)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            banner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Two soft pools of brand colour behind everything, so the screen
            // is not a flat rectangle of background — never over content, since
            // the current mode's glow has to stay the brightest thing here.
            ZStack {
                theme.palette.background.resolved(for: colorScheme)
                RadialGradient(
                    colors: [theme.palette.primary.resolved(for: colorScheme).opacity(0.13), .clear],
                    center: UnitPoint(x: 0.5, y: 0.27),
                    startRadius: 0,
                    endRadius: 360
                )
                RadialGradient(
                    colors: [theme.palette.secondary.resolved(for: colorScheme).opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.62),
                    startRadius: 0,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Modes

    @ViewBuilder
    private func modeRow(_ mode: HomeMode) -> some View {
        switch mode.state {
        case .current: currentRow(mode)
        case .cleared: clearedRow(mode)
        case .locked: lockedRow(mode)
        }
    }

    /// Filled and glowing, at full height. Replayable, so it stays tappable
    /// even once it is the finished ladder's turn to be `cleared`.
    private func currentRow(_ mode: HomeMode) -> some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return Button(action: mode.action) {
            HStack(spacing: 15) {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                Text(mode.title)
                    .font(theme.typography.title)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 22).fill(tint))
            .shadow(color: tint.opacity(0.5), radius: 15)
            .shadow(color: tint.opacity(0.22), radius: 35)
        }
        .accessibilityLabel(mode.title)
    }

    /// Shorter, outlined, check-marked. Still tappable — a finished ladder is
    /// the one a player goes back to for stars.
    private func clearedRow(_ mode: HomeMode) -> some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return Button(action: mode.action) {
            HStack(spacing: 9) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(tint)
                Text(mode.title)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.75))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.palette.surface.resolved(for: colorScheme))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.3), lineWidth: 1))
            )
        }
        .accessibilityLabel(mode.title)
    }

    private func lockedRow(_ mode: HomeMode) -> some View {
        let ink = theme.palette.onSurface.resolved(for: colorScheme)
        return HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.footnote)
            Text(mode.lockedTitle)
                .font(theme.typography.body)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(ink.opacity(0.4))
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.palette.background.resolved(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.1), lineWidth: 1))
        )
        .accessibilityLabel(mode.lockedTitle)
    }

    // MARK: - Chrome

    /// 48pt, the floor `screen-spec.js` sets for every touch target — above
    /// Apple's 44 so a label or icon can grow without eating into it.
    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(theme.palette.surface.resolved(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.1), lineWidth: 1)
                        )
                )
        }
        .accessibilityLabel(CommonStrings.settings.text)
    }
}

public extension HomeView where Banner == EmptyView {
    init(
        modes: [HomeMode],
        onSettings: @escaping () -> Void,
        @ViewBuilder logo: () -> Logo
    ) {
        self.init(modes: modes, onSettings: onSettings, logo: logo, banner: { EmptyView() })
    }
}
