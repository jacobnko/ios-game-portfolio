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
public struct SettingsView: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let purchases: PurchaseManager
    private let notifications: NotificationScheduler?
    private let privacyPolicyURL: URL?
    private let onResetProgress: () -> Void
    private let onBack: () -> Void

    @State private var soundEnabled = PitchedTonePlayer.shared.isEnabled
    @State private var hapticsEnabled = HapticEngine.shared.isEnabled
    @State private var notificationsEnabled: Bool
    @State private var isConfirmingReset = false

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
        self._notificationsEnabled = State(initialValue: notifications?.isEnabled ?? false)
    }

    public var body: some View {
        Form {
            Section {
                Toggle(CommonStrings.settingsSound.text, isOn: $soundEnabled)
                    .onChange(of: soundEnabled) { _, on in
                        PitchedTonePlayer.shared.isEnabled = on
                        AnalyticsHub.shared.log(GameEvent.settingToggled(name: "sound", isOn: on))
                    }
                Toggle(CommonStrings.settingsHaptics.text, isOn: $hapticsEnabled)
                    .onChange(of: hapticsEnabled) { _, on in
                        HapticEngine.shared.isEnabled = on
                        AnalyticsHub.shared.log(GameEvent.settingToggled(name: "haptics", isOn: on))
                    }
                if let notifications {
                    Toggle(CommonStrings.settingsNotifications.text, isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, on in
                            notifications.isEnabled = on
                            AnalyticsHub.shared.log(GameEvent.settingToggled(name: "notifications", isOn: on))
                        }
                }
            }

            Section {
                if !purchases.adsRemoved {
                    Button {
                        Task { await purchases.purchaseRemoveAds() }
                    } label: {
                        HStack {
                            Text(CommonStrings.settingsRemoveAds.text)
                            Spacer()
                            if let price = purchases.removeAdsProduct?.displayPrice {
                                Text(price).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(purchases.isBusy)
                }

                // Required by App Store review even though non-consumables
                // auto-restore — see docs/architecture/iap-setup.md §4.
                Button(CommonStrings.settingsRestorePurchases.text) {
                    Task { await purchases.restore() }
                }
                .disabled(purchases.isBusy)
            }

            Section {
                Button(CommonStrings.settingsLanguage.text) {
                    LanguageSettings.openSystemLanguageSettings()
                }
                Text(CommonStrings.settingsLanguageHint.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let privacyPolicyURL {
                    Link(CommonStrings.settingsPrivacyPolicy.text, destination: privacyPolicyURL)
                }
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Text(CommonStrings.settingsResetProgress.text)
                }
            }
        }
        .navigationTitle(CommonStrings.settings.text)
        .confirmationDialog(
            CommonStrings.settingsResetProgress.text,
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(CommonStrings.settingsResetProgress.text, role: .destructive, action: onResetProgress)
            Button(CommonStrings.cancel.text, role: .cancel) {}
        }
    }
}
