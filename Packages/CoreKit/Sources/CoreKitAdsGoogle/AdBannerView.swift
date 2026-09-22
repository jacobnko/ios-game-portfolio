// SwiftUI banner that survives parent re-renders without reloading.

#if os(iOS)
import SwiftUI
import UIKit
import GoogleMobileAds
import CoreKitServices

/// An AdMob banner for SwiftUI.
///
/// The whole point of this type is what it does *not* do. The naive
/// `UIViewRepresentable` creates a `BannerView` inside `makeUIView` or, worse,
/// `updateUIView` — and SwiftUI calls `updateUIView` on every parent state change.
/// In a game that is every frame of a timer or a score. The banner then reloads
/// constantly: it flickers, impressions are wasted, and AdMob can flag the traffic.
///
/// Here the `BannerView` is created once by the coordinator and reused for the life
/// of the view. `updateUIView` only ever adjusts the width, and only when the width
/// actually changed.
public struct AdBannerView: UIViewRepresentable {
    private let adUnitID: String
    private let width: CGFloat

    public init(adUnitID: String, width: CGFloat) {
        self.adUnitID = adUnitID
        self.width = width
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(adUnitID: adUnitID)
    }

    public func makeUIView(context: Context) -> UIView {
        context.coordinator.containerView
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.apply(width: width)
    }

    /// Owns the single `BannerView` instance.
    @MainActor
    public final class Coordinator: NSObject, BannerViewDelegate {
        public let containerView = UIView()
        private let bannerView: BannerView
        private var loadedWidth: CGFloat = 0
        private var hasRequestedAd = false

        init(adUnitID: String) {
            bannerView = BannerView(adSize: AdSizeBanner)
            super.init()

            bannerView.adUnitID = adUnitID
            bannerView.delegate = self
            bannerView.translatesAutoresizingMaskIntoConstraints = false

            containerView.addSubview(bannerView)
            NSLayoutConstraint.activate([
                bannerView.topAnchor.constraint(equalTo: containerView.topAnchor),
                bannerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            ])
        }

        func apply(width: CGFloat) {
            guard width > 0 else { return }
            // Third load path in this module, and it needs the same consent gate
            // the interstitial and rewarded loads have. Returning here leaves
            // `hasRequestedAd` false, so the next layout pass retries once
            // consent has resolved rather than leaving the slot permanently empty.
            guard AdSetup.canRequestAds else { return }

            // A sub-point width wobble during layout must not trigger a reload.
            let widthChangedMeaningfully = abs(width - loadedWidth) > 1
            guard !hasRequestedAd || widthChangedMeaningfully else { return }

            loadedWidth = width
            bannerView.adSize = largeAnchoredAdaptiveBanner(width: width)
            bannerView.rootViewController = Self.currentRootViewController()
            bannerView.load(Request())
            hasRequestedAd = true
        }

        /// Height the banner wants at a given width, so SwiftUI can reserve space
        /// before an ad arrives. Reserving it up front stops the board jumping when
        /// the first impression lands.
        public static func height(forWidth width: CGFloat) -> CGFloat {
            guard width > 0 else { return 50 }
            return largeAnchoredAdaptiveBanner(width: width).size.height
        }

        private static func currentRootViewController() -> UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .keyWindow?
                .rootViewController
        }
    }
}

/// Drop-in banner slot that measures itself and respects the ad entitlement.
///
/// Games place this and nothing else. It reserves its height whether or not an ad
/// has loaded, so gameplay never shifts underneath the player's finger — which is
/// also what keeps the layout clear of Guideline 2.3.1 (ads must not cause
/// accidental taps on interactive UI).
public struct AdBannerSlot: View {
    private let adUnitID: String
    private let isVisible: Bool

    /// Width of the slot itself, which is not always the width of the screen.
    @State private var width: CGFloat = 0

    public init(adUnitID: String, isVisible: Bool) {
        self.adUnitID = adUnitID
        self.isVisible = isVisible
    }

    public var body: some View {
        if isVisible {
            Color.clear
                .frame(height: reservedHeight)
                // The banner's height depends on the width it is actually given.
                // Measuring the screen instead would be wrong in Split View, Slide
                // Over, or any container narrower than the window — the reserved
                // space and the real banner would disagree and the layout would
                // clip or gap. `UIScreen.main` is also deprecated and meaningless
                // in a multi-scene app.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .overlay {
                    // Held back until the width is known, so the banner is not
                    // loaded once at a placeholder width and again at the real one.
                    if width > 0 {
                        AdBannerView(adUnitID: adUnitID, width: width)
                    }
                }
        }
    }

    /// Standard banner height until the real width is known.
    private var reservedHeight: CGFloat {
        width > 0 ? AdBannerView.Coordinator.height(forWidth: width) : 50
    }
}
#endif
