// A brief message over the current screen, used for teaching rather than errors.

import SwiftUI

/// A short message that appears over a screen and leaves on its own.
///
/// Games need a way to say one sentence — "a line can turn a corner" — without
/// a modal, because a modal stops play and has to be dismissed before the
/// player can try the thing it just described. This floats above the board and
/// expires, so the player reads it while already dragging.
///
/// Accessibility: the message is announced to VoiceOver, since a control that
/// vanishes on a timer is otherwise invisible to it.
public struct ToastMessage: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let seconds: Double

    public init(id: UUID = UUID(), text: String, seconds: Double = 3.2) {
        self.id = id
        self.text = text
        self.seconds = max(0.5, seconds)
    }
}
