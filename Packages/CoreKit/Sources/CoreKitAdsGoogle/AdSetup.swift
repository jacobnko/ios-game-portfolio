// App-launch sequence for tracking consent and SDK initialisation.

#if os(iOS)
import Foundation
import AppTrackingTransparency
import UIKit
import GoogleMobileAds

/// One-time setup every game runs at launch.
public enum AdSetup {
    /// Requests tracking permission, then starts the ads SDK.
    ///
    /// Order matters. The SDK reads the tracking authorisation when it initialises,
    /// so asking afterwards means the first session serves non-personalised ads even
    /// when the player said yes.
    ///
    /// Requires `NSUserTrackingUsageDescription` in the app's Info.plist. Without it
    /// the prompt never appears and the status stays `.notDetermined` forever.
    /// Deliberately not `@MainActor`. Only the tracking prompt needs the main
    /// actor, and it is isolated on its own. Google documents `start()` as
    /// completing "after the SDK and mediation adapters finish, or after 30
    /// seconds", and its initialisation does enough work that holding the main
    /// actor for it makes the first screen unresponsive to taps.
    public static func start() async {
        await requestTrackingAuthorization()
        await MobileAds.shared.start()
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
