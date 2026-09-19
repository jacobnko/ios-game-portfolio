// The first screen a player sees. Branding and the ad slot are entirely the
// game's own content — CoreKitUI must not depend on CoreKitAdsGoogle, so the
// banner is injected the same way the logo is.

import SwiftUI
import CoreKitJuice
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

/// How far through the game the player is, shown as a bar plus a count.
public struct HomeProgress: Equatable, Sendable {
    public let cleared: Int
    public let total: Int

    public init(cleared: Int, total: Int) {
        self.cleared = max(0, cleared)
        self.total = max(0, total)
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(cleared) / Double(total))
    }
}

/// The home screen shared by every game.
///
/// `logo` and `banner` are slots rather than fixed views because ten games ship
/// ten different visual identities (§6 of the design handoff), and CoreKitUI has
/// no dependency on any ad SDK — this view only owns the layout and the
/// Play/Settings affordances.
///
/// Layout follows the D4 budget (`screen-spec.js`): a 48pt settings control top
/// right, branding in the upper third, one glowing primary CTA, a secondary row,
/// then progress above the reserved banner strip. Every colour comes from the
/// theme, so the shape is shared while each game still reads as its own app —
/// the Guideline 4.3 requirement in CLAUDE.md §0.3.
public struct HomeView<Logo: View, Banner: View>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let logo: Logo
    private let banner: Banner
    private let onPlay: () -> Void
    private let onSettings: () -> Void
    private let playTitle: String?
    private let secondaryMode: HomeSecondaryMode?
    private let progress: HomeProgress?

    @State private var soundEnabled = PitchedTonePlayer.shared.isEnabled

    public init(
        onPlay: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        playTitle: String? = nil,
        secondaryMode: HomeSecondaryMode? = nil,
        progress: HomeProgress? = nil,
        @ViewBuilder logo: () -> Logo,
        @ViewBuilder banner: () -> Banner
    ) {
        self.onPlay = onPlay
        self.onSettings = onSettings
        self.playTitle = playTitle
        self.secondaryMode = secondaryMode
        self.progress = progress
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

            VStack(spacing: 14) {
                playButton
                if let secondaryMode {
                    HStack(spacing: 14) {
                        secondaryButton(secondaryMode)
                        soundButton
                    }
                }
            }
            .padding(.horizontal, 24)

            if let progress {
                progressBar(progress)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 4)
            }

            Spacer(minLength: 12)

            banner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Two soft pools of brand colour behind everything, so the screen
            // is not a flat rectangle of background. Drawn behind the grid, and
            // never over content — the CTA's own glow has to stay the
            // brightest thing on the screen.
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

    // MARK: - Pieces

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

    /// The only filled, glowing control on the screen.
    ///
    /// `minHeight` rather than a fixed height: a translated label is often half
    /// again as long, and a fixed height truncates it instead of growing.
    private var playButton: some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return Button(action: onPlay) {
            HStack(spacing: 15) {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                Text(playTitle ?? CommonStrings.play.text)
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
    }

    /// Outlined rather than filled, so the primary CTA stays the only solid
    /// block of colour on the screen even once a second mode is unlocked.
    private func secondaryButton(_ mode: HomeSecondaryMode) -> some View {
        Button(action: mode.isLocked ? {} : mode.action) {
            HStack(spacing: 8) {
                Image(systemName: mode.isLocked ? "lock.fill" : "square.grid.2x2.fill")
                    .font(.footnote)
                Text(mode.isLocked ? mode.lockedTitle : mode.title)
                    .font(theme.typography.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(
                theme.palette.onSurface.resolved(for: colorScheme)
                    .opacity(mode.isLocked ? 0.45 : 1)
            )
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(surfaceTile(radius: 18))
        }
        .disabled(mode.isLocked)
        .accessibilityLabel(mode.isLocked ? mode.lockedTitle : mode.title)
    }

    /// Reaches `PitchedTonePlayer.shared` directly, the same way `SettingsView`
    /// does — every game's audio genuinely is that one singleton, so there is
    /// nothing game-specific to inject.
    private var soundButton: some View {
        Button {
            soundEnabled.toggle()
            PitchedTonePlayer.shared.isEnabled = soundEnabled
            AnalyticsHub.shared.log(GameEvent.settingToggled(name: "sound", isOn: soundEnabled))
        } label: {
            Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    soundEnabled
                        ? theme.palette.primary.resolved(for: colorScheme)
                        : theme.palette.onSurface.resolved(for: colorScheme).opacity(0.4)
                )
                .frame(width: 60, height: 60)
                .background(surfaceTile(radius: 18))
        }
        .accessibilityLabel(CommonStrings.settingsSound.text)
    }

    private func progressBar(_ progress: HomeProgress) -> some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return HStack(spacing: 14) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.1))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progress.fraction)
                        .shadow(color: tint.opacity(0.7), radius: 5)
                }
            }
            .frame(height: 5)

            Text("\(progress.cleared)")
                .font(theme.typography.numeric)
                .foregroundStyle(tint)
            + Text("/\(progress.total)")
                .font(theme.typography.numeric)
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.35))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.cleared) / \(progress.total)")
    }

    private func surfaceTile(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(theme.palette.surface.resolved(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.11), lineWidth: 1)
            )
    }
}

public extension HomeView where Banner == EmptyView {
    init(
        onPlay: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        playTitle: String? = nil,
        secondaryMode: HomeSecondaryMode? = nil,
        progress: HomeProgress? = nil,
        @ViewBuilder logo: () -> Logo
    ) {
        self.init(
            onPlay: onPlay, onSettings: onSettings, playTitle: playTitle,
            secondaryMode: secondaryMode, progress: progress,
            logo: logo, banner: { EmptyView() }
        )
    }
}
