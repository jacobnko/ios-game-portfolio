// A grid of stages, generic over whatever stage type a game defines.

import SwiftUI
import CoreKitData
import CoreKitServices

/// Stage select shared by every game.
///
/// Unlock logic is intentionally a closure, not something this view decides —
/// some games unlock linearly, some by star total, some by chapter. Progress is
/// looked up by `stage.id`, matching `ProgressStore`'s keying.
public struct StageSelectView<Stage: StageDescriptor>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let stages: [Stage]
    private let progress: [String: StageProgress]
    private let isUnlocked: (Stage) -> Bool
    private let onSelect: (Stage) -> Void
    private let onBack: () -> Void

    public init(
        stages: [Stage],
        progress: [String: StageProgress],
        isUnlocked: @escaping (Stage) -> Bool,
        onSelect: @escaping (Stage) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.stages = stages
        self.progress = progress
        self.isUnlocked = isUnlocked
        self.onSelect = onSelect
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
                }
                .accessibilityLabel(CommonStrings.back.text)
                Spacer()
            }
            .padding()

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 64), spacing: theme.metrics.tileSpacing)],
                    spacing: theme.metrics.tileSpacing
                ) {
                    ForEach(stages, id: \.id) { stage in
                        tile(for: stage)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background.resolved(for: colorScheme))
    }

    @ViewBuilder
    private func tile(for stage: Stage) -> some View {
        let unlocked = isUnlocked(stage)
        let stageProgress = progress[stage.id]
        let cleared = stageProgress?.isCleared ?? false

        Button {
            onSelect(stage)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: theme.metrics.cornerRadius)
                    .fill(tileColor(unlocked: unlocked, cleared: cleared))

                if unlocked {
                    VStack(spacing: 2) {
                        Text("\(stage.displayNumber)")
                            .font(theme.typography.numeric)
                            .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
                        if cleared {
                            starsRow(stageProgress?.starsEarned ?? 0)
                        }
                    }
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.4))
                }
            }
            .frame(width: 64, height: 64)
        }
        // A locked stage is dimmed, not hidden — the player should see the ladder
        // ahead, which is itself part of the "progress" theme's re-engagement pull.
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "\(stage.displayNumber)" : CommonStrings.stageLocked.text)
    }

    private func tileColor(unlocked: Bool, cleared: Bool) -> Color {
        guard unlocked else { return theme.palette.surface.resolved(for: colorScheme).opacity(0.5) }
        return cleared
            ? theme.palette.secondary.resolved(for: colorScheme)
            : theme.palette.surface.resolved(for: colorScheme)
    }

    private func starsRow(_ count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.palette.accent.resolved(for: colorScheme))
            }
        }
    }
}
