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

private struct ToastModifier: ViewModifier {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    label(toast)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity)
                        )
                        // Keyed on the toast's id, not on the optional: two tips
                        // in a row would otherwise share one task, and the
                        // second would inherit the first's remaining time.
                        .id(toast.id)
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(toast.seconds))
                            guard !Task.isCancelled else { return }
                            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
                        }
                }
            }
            .animation(.spring(duration: 0.35), value: toast)
    }

    private func label(_ toast: ToastMessage) -> some View {
        Text(toast.text)
            .font(theme.typography.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                    .fill(theme.palette.surface.resolved(for: colorScheme))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                    .stroke(theme.palette.primary.resolved(for: colorScheme).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(toast.text)
    }
}

public extension View {
    /// Shows `toast` over this view until it expires, then clears the binding.
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}
