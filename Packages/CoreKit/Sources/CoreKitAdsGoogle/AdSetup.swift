// App-launch sequence for tracking consent and SDK initialisation.

#if os(iOS)
import Foundation
import AppTrackingTransparency
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
    public static func start() async {
        await requestTrackingAuthorization()
        await MobileAds.shared.start()
    }

    /// Current tracking authorisation, for the App Privacy questionnaire and analytics.
    public static var trackingStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    @discardableResult
    public static func requestTrackingAuthorization() async -> ATTrackingManager.AuthorizationStatus {
        // Asking again once answered is a no-op, so this is safe to call on launch.
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return ATTrackingManager.trackingAuthorizationStatus
        }
        return await ATTrackingManager.requestTrackingAuthorization()
    }
}
#endif
