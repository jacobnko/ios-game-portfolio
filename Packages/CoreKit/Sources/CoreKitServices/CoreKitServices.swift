// Entry point for third-party services: ads, purchases and analytics.

import Foundation

/// Namespace for the services layer.
public enum CoreKitServices {
    public static let version = "0.1.0"

    /// Whether this build is allowed to request production ad units.
    ///
    /// Defaults to `false` so a misconfigured build serves test ads rather than
    /// generating invalid traffic against the real AdMob account.
    public static var allowsProductionAdUnits: Bool {
        #if DEBUG
        false
        #else
        ProcessInfo.processInfo.environment["COREKIT_PRODUCTION_ADS"] == "1"
        #endif
    }
}
