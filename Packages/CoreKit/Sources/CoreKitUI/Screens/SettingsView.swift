// Settings shared by every game: audio/haptics toggles, purchases, language, reset.

import SwiftUI
import CoreKitJuice
import CoreKitServices

/// Settings shared by every game.
///
/// Sound and haptics toggles read and write `PitchedTonePlayer.shared` /
/// `HapticEngine.shared` directly rather than through a binding the app supplies,
/// because every game's audio and haptics genuinely are those two singletons —
/// there is nothing game-specific to inject here, unlike purchases or progress.
///
/// Layout follows D4's budget (`screen-spec.js`). One rule in it is not
/// cosmetic: **Restore Purchases sits directly under the purchase button and
/// above the fold**, separated from the link list. App Review rejects builds
/// where it cannot be found, so that order is not free to rearrange.
public struct SettingsView: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let purchases: PurchaseManager
    private let notifications: NotificationScheduler?
    private let privacyPolicyURL: URL?
    private let onResetProgress: () -> Void
    private let onBack: () -> Void

    public init(
        purchases: PurchaseManager,
        notifications: NotificationScheduler? = nil,
        privacyPolicyURL: URL? = nil,
        onResetProgress: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.purchases = purchases
        self.notifications = notifications
        self.privacyPolicyURL = privacyPolicyURL
        self.onResetProgress = onResetProgress
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 12)

            ScrollView {
                SettingsContent(
                    purchases: purchases,
                    notifications: notifications,
                    privacyPolicyURL: privacyPolicyURL,
                    onResetProgress: onResetProgress
                )
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                theme.palette.background.resolved(for: colorScheme)
                RadialGradient(
                    colors: [theme.palette.secondary.resolved(for: colorScheme).opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 0,
                    endRadius: 340
                )
            }
            .ignoresSafeArea()
        }
        // This screen draws its own back button, so the stack's would be a
        // second control doing the same job.
        .navigationBarBackButtonHidden()
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
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
            .accessibilityLabel(CommonStrings.back.text)

            Text(CommonStrings.settings.text)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))

            Spacer()
        }
        .frame(height: 48)
    }
}

/// Everything below the settings header.
///
/// A separate view rather than a computed property so its `@Environment` is
/// actually populated, and so it can be rendered outside a `ScrollView` —
/// `ImageRenderer` produces a blank image for anything inside one on macOS.
/// See `StageGrid` for the same pair of reasons.
public struct SettingsContent: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let purchases: PurchaseManager
    private let notifications: NotificationScheduler?
    private let privacyPolicyURL: URL?
    private let onResetProgress: () -> Void

    @State private var soundEnabled = PitchedTonePlayer.shared.isEnabled
    @State private var hapticsEnabled = HapticEngine.shared.isEnabled
    @State private var notificationsEnabled: Bool
    @State private var isConfirmingReset = false

    public init(
        purchases: PurchaseManager,
        notifications: NotificationScheduler? = nil,
        privacyPolicyURL: URL? = nil,
        onResetProgress: @escaping () -> Void
    ) {
        self.purchases = purchases
        self.notifications = notifications
        self.privacyPolicyURL = privacyPolicyURL
        self.onResetProgress = onResetProgress
        self._notificationsEnabled = State(initialValue: notifications?.isEnabled ?? false)
    }

    public var body: some View {
        VStack(spacing: 12) {
            togglesCard

            if !purchases.adsRemoved {
                removeAdsButton
            }
            // Required by App Store review even though non-consumables
            // auto-restore — see docs/architecture/iap-setup.md §4. Kept
            // directly under the purchase button and out of the link list
            // below, which is where a reviewer looks for it.
            restoreButton

            linksCard

            resetButton

            if let versionString {
                Text(versionString)
                    .font(.system(size: 10.5, design: .monospaced))
                    .kerning(1.7)
                    .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.28))
                    .padding(.top, 8)
            }
        }
        // An alert, not a confirmation dialog. The dialog slides up from the
        // button as a popover and says only "Reset Progress" twice, which does
        // not tell the player that every star and best time goes with it.
        // Wiping progress deserves a centred, modal warning that says what is
        // lost and cannot be dismissed by tapping past it.
        .alert(
            CommonStrings.settingsResetProgress.text,
            isPresented: $isConfirmingReset
        ) {
            Button(CommonStrings.cancel.text, role: .cancel) {}
            Button(CommonStrings.settingsResetProgressConfirm.text, role: .destructive, action: onResetProgress)
        } message: {
            Text(CommonStrings.settingsResetProgressMessage.text)
        }
    }

    // MARK: - Cards

    private var togglesCard: some View {
        card {
            toggleRow(
                CommonStrings.settingsSound.text,
                systemImage: "speaker.wave.2.fill",
                isOn: $soundEnabled,
                // Never last: haptics always follows it.
                isLast: false
            ) { on in
                PitchedTonePlayer.shared.isEnabled = on
                AnalyticsHub.shared.log(GameEvent.settingToggled(name: "sound", isOn: on))
            }

            toggleRow(
                CommonStrings.settingsHaptics.text,
                systemImage: "hand.tap.fill",
                isOn: $hapticsEnabled,
                isLast: notifications == nil
            ) { on in
                HapticEngine.shared.isEnabled = on
                AnalyticsHub.shared.log(GameEvent.settingToggled(name: "haptics", isOn: on))
            }

            if let notifications {
                toggleRow(
                    CommonStrings.settingsNotifications.text,
                    systemImage: "bell.fill",
                    isOn: $notificationsEnabled,
                    isLast: true
                ) { on in
                    notifications.isEnabled = on
                    AnalyticsHub.shared.log(GameEvent.settingToggled(name: "notifications", isOn: on))
                }
            }
        }
    }

    private var linksCard: some View {
        card {
            linkRow(
                CommonStrings.settingsLanguage.text,
                subtitle: "\(CommonStrings.settingsSystemSettings.text) ↗",
                systemImage: "globe",
                isLast: privacyPolicyURL == nil
            ) {
                LanguageSettings.openSystemLanguageSettings()
            }

            if let privacyPolicyURL {
                Link(destination: privacyPolicyURL) {
                    linkRowLabel(
                        CommonStrings.settingsPrivacyPolicy.text,
                        subtitle: nil,
                        systemImage: "doc.text.fill",
                        isLast: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Buttons

    /// Amber. D1 budgets amber to three places in the standing UI and the
    /// purchase is one of them, so the colour itself marks this as the
    /// screen's one commercial action.
    private var removeAdsButton: some View {
        let amber = theme.palette.accent.resolved(for: colorScheme)
        return Button {
            Task { await purchases.purchaseRemoveAds() }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "rectangle.slash")
                    .font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(CommonStrings.settingsRemoveAds.text)
                        .font(.system(size: 17, weight: .heavy))
                        .lineLimit(1)
                    Text(CommonStrings.settingsOneTime.text)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .opacity(0.62)
                }
                Spacer(minLength: 8)
                // No price on the face of the button. App Store screenshots are
                // shared across every storefront, so a price baked into this row
                // ships a US figure to readers of every other currency, and goes
                // stale the moment the tier changes. StoreKit's own sheet states
                // the localized price before anything is charged.
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .bold))
                    .opacity(0.55)
            }
            .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(RoundedRectangle(cornerRadius: 22).fill(amber))
            .shadow(color: amber.opacity(0.45), radius: 14)
            .shadow(color: amber.opacity(0.20), radius: 33)
        }
        .disabled(purchases.isBusy)
    }

    private var restoreButton: some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return Button {
            Task { await purchases.restore() }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                Text(CommonStrings.settingsRestorePurchases.text)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tint.opacity(0.55), lineWidth: 1.5)
            )
        }
        .disabled(purchases.isBusy)
    }

    /// Not in D4, which never drew one — but the game has to offer it, and a
    /// destructive action belongs at the bottom, past everything a player came
    /// here to do.
    private var resetButton: some View {
        Button {
            isConfirmingReset = true
        } label: {
            Text(CommonStrings.settingsResetProgress.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red.opacity(0.85))
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
        }
        // Plain, not `role: .destructive`: the role paints its own filled
        // background here, which put a card behind a row that is meant to read
        // as the quietest thing on the screen.
        .buttonStyle(.plain)
    }

    // MARK: - Rows

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.palette.surface.resolved(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.09), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func toggleRow(
        _ label: String,
        systemImage: String,
        isOn: Binding<Bool>,
        isLast: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        let ink = theme.palette.onSurface.resolved(for: colorScheme)
        return HStack(spacing: 14) {
            iconWell(systemImage, tint: isOn.wrappedValue ? tint : ink.opacity(0.5), lit: isOn.wrappedValue)
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 14)
            SettingsToggle(isOn: isOn, tint: tint, ink: ink, background: theme.palette.background.resolved(for: colorScheme))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(ink.opacity(0.06)).frame(height: 1).padding(.leading, 18)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
        .onChange(of: isOn.wrappedValue) { _, on in onChange(on) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn.wrappedValue ? "1" : "0")
        .accessibilityAddTraits(.isButton)
    }

    private func linkRow(
        _ label: String,
        subtitle: String?,
        systemImage: String,
        isLast: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            linkRowLabel(label, subtitle: subtitle, systemImage: systemImage, isLast: isLast)
        }
        .buttonStyle(.plain)
    }

    private func linkRowLabel(
        _ label: String,
        subtitle: String?,
        systemImage: String,
        isLast: Bool
    ) -> some View {
        let ink = theme.palette.onSurface.resolved(for: colorScheme)
        return HStack(spacing: 14) {
            iconWell(systemImage, tint: ink.opacity(0.6), lit: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.4))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 14)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink.opacity(0.35))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(ink.opacity(0.06)).frame(height: 1).padding(.leading, 18)
            }
        }
        .contentShape(Rectangle())
    }

    private func iconWell(_ systemImage: String, tint: Color, lit: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        lit
                            ? theme.palette.primary.resolved(for: colorScheme).opacity(0.12)
                            : theme.palette.onSurface.resolved(for: colorScheme).opacity(0.05)
                    )
            )
    }

    /// Marketing version and build, straight from the bundle so it cannot
    /// disagree with what was actually shipped.
    ///
    /// Nil rather than a row of placeholders when the bundle has no version —
    /// which is every context that is not the app itself, previews and the
    /// snapshot tool included. "— · BUILD —" looks like a bug on a screen a
    /// reviewer reads.
    private var versionString: String? {
        let info = Bundle.main.infoDictionary
        guard
            let version = info?["CFBundleShortVersionString"] as? String,
            let build = info?["CFBundleVersion"] as? String
        else { return nil }
        let name = (info?["CFBundleName"] as? String ?? "").uppercased()
        return "\(name) \(version) · BUILD \(build)".trimmingCharacters(in: .whitespaces)
    }
}

/// D4's pill toggle: a 52x32 track with a 26pt knob, lit in the game's primary.
private struct SettingsToggle: View {
    @Binding var isOn: Bool
    let tint: Color
    let ink: Color
    let background: Color

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? tint : ink.opacity(0.14))
                .overlay(
                    Capsule().stroke(ink.opacity(isOn ? 0 : 0.1), lineWidth: 1)
                )
                .shadow(color: isOn ? tint.opacity(0.45) : .clear, radius: 8)

            Circle()
                .fill(isOn ? background : ink.opacity(0.55))
                .frame(width: 26, height: 26)
                .padding(3)
        }
        .frame(width: 52, height: 32)
        .animation(.spring(duration: 0.25), value: isOn)
    }
}
