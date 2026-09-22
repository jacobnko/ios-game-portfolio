// App-launch sequence for tracking consent and SDK initialisation.

#if os(iOS)
import Foundation
import AppTrackingTransparency
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// One-time setup every game runs at launch.
public enum AdSetup {
    /// Collects GDPR consent, asks for tracking permission, then starts the ads SDK.
    ///
    /// Order matters twice over.
    ///
    /// Consent comes first because it is the one that can refuse outright: a
    /// player in the EEA, the UK or Switzerland decides there whether their data
    /// may be used for advertising at all, and asking Apple's narrower tracking
    /// question before that would put the two dialogs in a confusing order.
    ///
    /// Tracking comes before the SDK starts because the SDK reads the
    /// authorisation when it initialises — asking afterwards means the first
    /// session serves non-personalised ads even when the player said yes.
    ///
    /// Requires `NSUserTrackingUsageDescription` in the app's Info.plist. Without it
    /// the prompt never appears and the status stays `.notDetermined` forever.
    /// Deliberately not `@MainActor`. Only the prompts need the main actor, and
    /// they are isolated on their own. Google documents `start()` as completing
    /// "after the SDK and mediation adapters finish, or after 30 seconds", and
    /// its initialisation does enough work that holding the main actor for it
    /// makes the first screen unresponsive to taps.
    public static func start() async {
        await requestConsent()
        await requestTrackingAuthorization()
        await MobileAds.shared.start()
    }

    // MARK: - GDPR consent (Google's User Messaging Platform)

    /// Runs Google's consent flow, showing the form only where one is required.
    ///
    /// Outside the regions the AdMob message targets this reaches Google, learns
    /// no form is needed and returns — so it is not conditional on a region
    /// check of our own, which would be a second, divergent source of truth.
    ///
    /// Errors are swallowed on purpose. Google's guidance is to carry on using
    /// the previous session's consent state and let `canRequestAds` decide;
    /// failing the launch because a consent server was unreachable would trade a
    /// missed ad for an unusable game.
    @MainActor
    public static func requestConsent() async {
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { _ in
                continuation.resume()
            }
        }
        await withCheckedContinuation { continuation in
            ConsentForm.loadAndPresentIfRequired(from: nil) { _ in
                continuation.resume()
            }
        }
    }

    /// Whether Google's consent state currently permits requesting ads.
    ///
    /// False until `requestConsent()` has run at least once, which is why the
    /// presenter checks it rather than assuming.
    public static var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    /// Whether the app must offer a way back into the consent choices.
    ///
    /// Some messages require it, and then the app has to render a visible,
    /// reachable control — a Settings row here. Games read this to decide
    /// whether to show that row at all.
    public static var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Re-opens the consent choices, for the control `isPrivacyOptionsRequired`
    /// asks for.
    @MainActor
    public static func presentPrivacyOptions() async {
        await withCheckedContinuation { continuation in
            ConsentForm.presentPrivacyOptionsForm(from: nil) { _ in
                continuation.resume()
            }
        }
    }

    @MainActor
    private static func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            return
        }
    }

    /// Current tracking authorisation, for the App Privacy questionnaire and analytics.
    public static var trackingStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    @discardableResult
    @MainActor
    public static func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        // Asking again once answered is a no-op, so this is safe to call on launch.
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return ATTrackingManager.trackingAuthorizationStatus
        }
        // The prompt only appears while the app is active. Asking during launch,
        // before the scene is foregrounded, returns `.denied` without ever showing
        // anything — and the answer cannot be revisited, so that single mistimed
        // call permanently halves what the ad units are worth.
        await waitUntilActive()
        return await ATTrackingManager.requestTrackingAuthorization()
    }
}
#endif
