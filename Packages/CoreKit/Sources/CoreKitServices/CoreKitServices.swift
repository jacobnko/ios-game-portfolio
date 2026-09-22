// Entry point for third-party services: ads, purchases and analytics.

import Foundation

/// Namespace for the services layer.
public enum CoreKitServices {
    public static let version = "0.1.0"

    /// Whether this build is allowed to request production ad units.
    ///
    /// True for an App Store install and nothing else. Debug builds and
    /// TestFlight both serve test inventory: repeatedly loading or tapping your
    /// own live units is invalid traffic, and a beta tester's taps count.
    ///
    /// The receipt's filename is what distinguishes them — the App Store writes
    /// `receipt`, TestFlight writes `sandboxReceipt`. A missing receipt (a
    /// Release build run straight from Xcode, or a first launch before the
    /// receipt lands) reads as not allowed, which is the safe direction: test
    /// ads earn nothing, whereas guessing the other way risks the account.
    ///
    /// This deliberately does *not* read an environment variable. It used to,
    /// and that cannot work in a shipped app: `ProcessInfo.environment` only
    /// carries what the launching process set, so an app the user starts from
    /// the home screen never sees it. The flag was therefore always false in
    /// exactly the build that needed it to be true, and every real user would
    /// have been served Google's test ads.
    public static var allowsProductionAdUnits: Bool {
        #if DEBUG
        false
        #else
        allows(receiptNamed: Bundle.main.appStoreReceiptURL?.lastPathComponent)
        #endif
    }

    /// The rule above, separated from the build it runs in so it can be tested.
    /// The property alone can only ever report the configuration it was compiled
    /// into, which is how the environment-variable version stayed broken.
    static func allows(receiptNamed name: String?) -> Bool {
        name == "receipt"
    }
}
