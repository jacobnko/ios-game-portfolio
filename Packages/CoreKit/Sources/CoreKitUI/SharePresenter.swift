// Shows the system share sheet from a SwiftUI action, for any game's result screen.

#if canImport(UIKit)
import UIKit

/// Presents `UIActivityViewController` directly from UIKit.
///
/// SwiftUI has `ShareLink`, but it is a view that *is* the button — it cannot be
/// opened from a closure, and `ResultView` takes an `onShare` closure because the
/// button is drawn by the shared screen, not by the game. The alternative is to
/// host the activity controller inside a `.sheet`, which wraps the native sheet in
/// a second, half-height SwiftUI one. Presenting it from the top view controller
/// gives the sheet iOS draws everywhere else.
@MainActor
public enum SharePresenter {
    /// Opens the share sheet with a message and, optionally, a link.
    ///
    /// The link is a separate item rather than part of the text so that apps which
    /// understand links (Messages, Mail) can show a preview of it, while the text
    /// stays a sentence a person wrote.
    ///
    /// Returns `false` when there was no foreground window to present from, so a
    /// caller can tell "nothing happened" from "the sheet is up".
    @discardableResult
    public static func present(text: String, url: URL? = nil) -> Bool {
        guard let host = topViewController() else { return false }

        var items: [Any] = [text]
        if let url { items.append(url) }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // A popover with no anchor throws on iPad. Nothing here targets iPad today,
        // but a crash is the wrong way to find out that changed.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        host.present(controller, animated: true)
        return true
    }

    /// Walks down to whatever is on top, because presenting from a view controller
    /// that is already presenting something is silently ignored.
    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
