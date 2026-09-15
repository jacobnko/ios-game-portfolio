// The screen after every attempt. Owns the victory catharsis; owns nothing about
// what comes next — that decision (which stage, or none) belongs to the app.

import SwiftUI
import CoreKitJuice
import CoreKitServices

/// Shown after every attempt, win or lose.
///
/// Deliberately takes closures rather than a `GameFlowCoordinator` reference: this
/// view has no business deciding what the next stage id is (a game-specific,
/// possibly branching question), only reporting that the player tapped continue.
/// The composing app resolves "next" and calls `coordinator.advanceFromResult` —
/// see `docs/architecture/new-game-setup.md`.
public struct ResultView: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isCelebrating = false

    private let outcome: StageOutcome
    private let onAdvance: () -> Void
    private let onRetry: () -> Void
    private let onShare: (() -> Void)?

    public init(
        outcome: StageOutcome,
        onAdvance: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onShare: (() -> Void)? = nil
    ) {
        self.outcome = outcome
        self.onAdvance = onAdvance
        self.onRetry = onRetry
        self.onShare = onShare
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.palette.background.resolved(for: colorScheme))
            .victorySequence(
                isPresented: $isCelebrating,
                configuration: theme.victoryConfiguration(multiplier: max(1, outcome.stars))
            )
            .onAppear {
                // Only a real clear earns the payoff. Playing it for a failed
                // attempt would teach the player that losing looks the same as
                // winning, which erases the one signal the reward is built on.
                if outcome.cleared { isCelebrating = true }
            }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(outcome.cleared ? CommonStrings.resultStageCleared.text : CommonStrings.resultStageFailed.text)
                .font(theme.typography.display)
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))

            if outcome.cleared {
                Text("\(outcome.score)")
                    .font(theme.typography.numeric)
                    .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.8))

                starsRow
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: outcome.cleared ? onAdvance : onRetry) {
                    Text((outcome.cleared ? CommonStrings.next : CommonStrings.retry).text)
                        .font(theme.typography.title)
                        .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                                .fill(theme.palette.accent.resolved(for: colorScheme))
                        )
                }

                if let onShare, outcome.cleared {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.palette.secondary.resolved(for: colorScheme))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private var starsRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < outcome.stars ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(theme.palette.accent.resolved(for: colorScheme))
            }
        }
    }
}
