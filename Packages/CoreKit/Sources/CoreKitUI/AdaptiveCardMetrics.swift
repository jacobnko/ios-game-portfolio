// Width rule for secondary screens: full width on phones, a centred card on iPad.

import CoreGraphics

/// How wide a secondary screen's content should be.
///
/// Phones (compact width) use the whole width minus the side margin. A regular-width
/// container — an iPad in portrait, say — gets a card no wider than `maxWidth`,
/// centred, so a settings list or a result does not stretch into a 700-point line.
public enum AdaptiveCardMetrics {
    public static let defaultMaxWidth: CGFloat = 560

    public static func contentWidth(container: CGFloat, isRegular: Bool,
                                    maxWidth: CGFloat = defaultMaxWidth, margin: CGFloat = 16) -> CGFloat {
        let available = max(0, container - 2 * margin)
        return isRegular ? min(available, maxWidth) : available
    }
}
