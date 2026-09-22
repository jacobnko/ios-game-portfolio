// Ad unit identifiers, defaulting to Google's test units so real ones cannot leak in.

import Foundation

/// The three ad placements every game in the portfolio uses.
public enum AdPlacement: String, Sendable, CaseIterable {
    case banner
    case interstitial
    case rewarded
}

/// Ad unit ids for one app.
///
/// The default is Google's official test inventory. Production ids must be passed
/// in explicitly *and* pass `CoreKitServices.allowsProductionAdUnits`, because
/// repeatedly loading or tapping your own live units is invalid traffic and gets
/// AdMob accounts suspended.
public struct AdUnitIDs: Sendable, Equatable {
    public let banner: String
    public let interstitial: String
    public let rewarded: String
    /// True when these are Google's test units rather than the app's own.
    public let isTestInventory: Bool

    private init(banner: String, interstitial: String, rewarded: String, isTestInventory: Bool) {
        self.banner = banner
        self.interstitial = interstitial
        self.rewarded = rewarded
        self.isTestInventory = isTestInventory
    }

    /// Google's official iOS test ad units. Always safe, in any build.
    public static let test = AdUnitIDs(
        banner: "ca-app-pub-3940256099942544/2934735716",
        interstitial: "ca-app-pub-3940256099942544/4411468910",
        rewarded: "ca-app-pub-3940256099942544/1712485313",
        isTestInventory: true
    )

    /// Real ad units, used only when the build is explicitly allowed to serve them.
    ///
    /// Falls back to `.test` otherwise — so a debug build, a TestFlight build, or a
    /// release build that forgot the flag all serve test ads instead of burning
    /// real impressions. The failure mode points the safe direction.
    public static func production(banner: String, interstitial: String, rewarded: String) -> AdUnitIDs {
        guard CoreKitServices.allowsProductionAdUnits else { return .test }
        return AdUnitIDs(banner: banner, interstitial: interstitial, rewarded: rewarded, isTestInventory: false)
    }

    /// Info.plist keys a game sets from its own build configuration, so that
    /// real ad unit ids never have to be written into source.
    public enum InfoPlistKey {
        public static let banner = "CoreKitAdUnitBanner"
        public static let interstitial = "CoreKitAdUnitInterstitial"
        public static let rewarded = "CoreKitAdUnitRewarded"
    }

    /// Reads the three ids from the app's Info.plist, falling back to `.test`
    /// when any of them is absent or blank.
    ///
    /// That fallback is the point: the values arrive from a build configuration
    /// file that is deliberately not in source control, so a fresh clone builds
    /// and runs with test inventory instead of failing — and a release that
    /// forgot to supply them shows test ads rather than mis-attributing real
    /// impressions.
    public static func fromInfoPlist(_ bundle: Bundle = .main) -> AdUnitIDs {
        func value(_ key: String) -> String? {
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String,
                  !raw.trimmingCharacters(in: .whitespaces).isEmpty
            else { return nil }
            return raw
        }
        guard let banner = value(InfoPlistKey.banner),
              let interstitial = value(InfoPlistKey.interstitial),
              let rewarded = value(InfoPlistKey.rewarded)
        else { return .test }
        return production(banner: banner, interstitial: interstitial, rewarded: rewarded)
    }

    public func id(for placement: AdPlacement) -> String {
        switch placement {
        case .banner: banner
        case .interstitial: interstitial
        case .rewarded: rewarded
        }
    }
}
