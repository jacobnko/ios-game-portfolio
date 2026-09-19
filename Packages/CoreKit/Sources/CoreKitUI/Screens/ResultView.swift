// The screen after every attempt. Owns the victory catharsis; owns nothing about
// what comes next — that decision (which stage, or none) belongs to the app.

import SwiftUI
import CoreKitJuice
import CoreKitServices

/// How far through a ladder the player is.
public struct LadderProgress: Equatable, Sendable {
    public let cleared: Int
    public let total: Int

    public init(cleared: Int, total: Int) {
        self.cleared = max(0, cleared)
        self.total = max(0, total)
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(cleared) / Double(total))
    }
}

/// Shown after every attempt, win or lose.
///
/// Deliberately takes closures rather than a `GameFlowCoordinator` reference: this
/// view has no business deciding what the next stage id is (a game-specific,
/// possibly branching question), only reporting that the player tapped continue.
/// The composing app resolves "next" and calls `coordinator.advanceFromResult` —
/// see `docs/architecture/new-game-setup.md`.
///
/// Layout is built around the interstitial that runs immediately before it
/// (D4). The ad's close button sits top right, so that corner is left empty and
/// the stage-select control goes top left; the payoff — stars, score, records —
/// fills the band the player's eyes land on; and the first thing worth tapping
/// is far from where their thumb just was.
public struct ResultView: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var isCelebrating = false

    private let outcome: StageOutcome
    private let stageLabel: String?
    private let bestSeconds: Double?
    private let progress: LadderProgress?
    private let onAdvance: () -> Void
    private let onRetry: () -> Void
    private let onStageSelect: (() -> Void)?
    private let onShare: (() -> Void)?

    public init(
        outcome: StageOutcome,
        stageLabel: String? = nil,
        bestSeconds: Double? = nil,
        progress: LadderProgress? = nil,
        onAdvance: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onStageSelect: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil
    ) {
        self.outcome = outcome
        self.stageLabel = stageLabel
        self.bestSeconds = bestSeconds
        self.progress = progress
        self.onAdvance = onAdvance
        self.onRetry = onRetry
        self.onStageSelect = onStageSelect
        self.onShare = onShare
    }

    /// A clear counts as a record when there is no previous best, or it beat it.
    public var isNewRecord: Bool {
        guard outcome.cleared else { return false }
        guard let bestSeconds else { return true }
        return outcome.durationSeconds < bestSeconds
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    theme.palette.background.resolved(for: colorScheme)
                    RadialGradient(
                        colors: [theme.palette.accent.resolved(for: colorScheme).opacity(0.12), .clear],
                        center: UnitPoint(x: 0.5, y: 0.25),
                        startRadius: 0,
                        endRadius: 340
                    )
                }
                .ignoresSafeArea()
            }
            .victorySequence(
                isPresented: $isCelebrating,
                configuration: theme.victoryConfiguration(multiplier: max(1, outcome.stars))
            )
            .navigationBarBackButtonHidden()
            .onAppear {
                // Only a real clear earns the payoff. Playing it for a failed
                // attempt would teach the player that losing looks the same as
                // winning, which erases the one signal the reward is built on.
                if outcome.cleared { isCelebrating = true }
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Spacer(minLength: 16)

            if outcome.cleared {
                starsRow
                headline.padding(.top, 22)
            } else {
                Text(CommonStrings.resultStageFailed.text)
                    .font(theme.typography.display)
                    .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
                    // "Versuch es nochmal" is three times the width of "Try
                    // Again"; without these it runs off both edges.
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 24)

                if let stageLabel {
                    Text(stageLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .kerning(2.6)
                        .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.45))
                        .padding(.top, 10)
                }

                // How far they got. The number is already computed for the
                // abandon funnel, and "you were 80% there" is the difference
                // between a retry and a quit.
                if outcome.progressPercent > 0 {
                    Text(String(format: CommonStrings.resultAttemptProgress.text, outcome.progressPercent))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.palette.primary.resolved(for: colorScheme))
                        .padding(.top, 18)
                }
            }

            Spacer(minLength: 16)

            if outcome.cleared {
                statStrip.padding(.horizontal, 24)
            }

            Spacer(minLength: 16)

            actions.padding(.horizontal, 24)

            if let progress {
                progressBar(progress)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }

            Spacer(minLength: 16)
        }
    }

    // MARK: - Pieces

    /// Top left only. The interstitial that just closed had its dismiss button
    /// in the top right, and a control placed there collects the second tap of
    /// a double-tap meant for the ad — an accidental navigation the player did
    /// not ask for, and ad revenue they did not mean to generate.
    private var topRow: some View {
        HStack {
            if let onStageSelect {
                Button(action: onStageSelect) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.75))
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(theme.palette.surface.resolved(for: colorScheme).opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.1), lineWidth: 1)
                                )
                        )
                }
                .accessibilityLabel(CommonStrings.home.text)
            }
            Spacer()
        }
        .frame(height: 48)
    }

    /// Centre star is larger, so three stars read as a podium rather than a row.
    private var starsRow: some View {
        let amber = theme.palette.accent.resolved(for: colorScheme)
        return HStack(alignment: .bottom, spacing: 16) {
            ForEach(0..<3, id: \.self) { index in
                let earned = index < outcome.stars
                let size: CGFloat = index == 1 ? 62 : 50
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.9))
                    .foregroundStyle(earned ? amber : theme.palette.surface.resolved(for: colorScheme))
                    .opacity(earned ? 1 : 0.55)
                    .shadow(color: earned ? amber.opacity(0.9) : .clear, radius: 7)
                    .shadow(color: earned ? amber.opacity(0.45) : .clear, radius: 17)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(outcome.stars)")
    }

    private var headline: some View {
        let amber = theme.palette.accent.resolved(for: colorScheme)
        return VStack(spacing: 7) {
            Text(stageLabel ?? CommonStrings.resultStageCleared.text)
                .font(.system(size: 11, design: .monospaced))
                .kerning(2.6)
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.45))

            Text(outcome.score, format: .number)
                .font(.system(size: 58, weight: .bold, design: .monospaced))
                .foregroundStyle(amber)
                .shadow(color: amber.opacity(0.55), radius: 13)
                .shadow(color: amber.opacity(0.25), radius: 32)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if isNewRecord {
                Text(CommonStrings.resultNewRecord.text)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .kerning(1.6)
                    .foregroundStyle(amber)
            }
        }
    }

    private var statStrip: some View {
        // Two cells, where D4 had three. Its third was MOVES, which this game
        // does not count, and filling it with the score printed the hero
        // number again directly beneath itself.
        HStack(spacing: 0) {
            statCell(CommonStrings.resultStatTime.text, value: Self.formatted(outcome.durationSeconds), highlighted: true)
            divider
            statCell(
                CommonStrings.resultStatBest.text,
                value: bestSeconds.map(Self.formatted) ?? "—",
                highlighted: false
            )
        }
        .frame(height: 78)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.palette.surface.resolved(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.09), lineWidth: 1)
                )
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.08))
            .frame(width: 1, height: 38)
    }

    private func statCell(_ label: String, value: String, highlighted: Bool) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9.5, design: .monospaced))
                .kerning(1.9)
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.4))
                // MEILLEUR is twice the width of BEST. Left to wrap, the label
                // takes two lines and pushes the value out of the strip.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    highlighted
                        ? theme.palette.primary.resolved(for: colorScheme)
                        : theme.palette.onSurface.resolved(for: colorScheme)
                )
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return VStack(spacing: 13) {
            Button(action: outcome.cleared ? onAdvance : onRetry) {
                HStack(spacing: 15) {
                    Text((outcome.cleared ? CommonStrings.next : CommonStrings.retry).text)
                        .font(theme.typography.title)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                    Image(systemName: "play.fill").font(.system(size: 20, weight: .black))
                }
                .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 76)
                .background(RoundedRectangle(cornerRadius: 22).fill(tint))
                .shadow(color: tint.opacity(0.5), radius: 15)
                .shadow(color: tint.opacity(0.22), radius: 35)
            }

            if outcome.cleared {
                HStack(spacing: 13) {
                    ghostButton(
                        CommonStrings.retry.text,
                        systemImage: "arrow.counterclockwise",
                        tint: theme.palette.onSurface.resolved(for: colorScheme),
                        borderOpacity: 0.11,
                        action: onRetry
                    )
                    if let onShare {
                        ghostButton(
                            CommonStrings.resultShare.text,
                            systemImage: "square.and.arrow.up",
                            tint: tint,
                            borderOpacity: 0.35,
                            action: onShare
                        )
                    }
                }
            }
        }
    }

    private func ghostButton(
        _ label: String,
        systemImage: String,
        tint: Color,
        borderOpacity: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.palette.surface.resolved(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(tint.opacity(borderOpacity), lineWidth: 1)
                    )
            )
        }
    }

    private func progressBar(_ progress: LadderProgress) -> some View {
        let tint = theme.palette.primary.resolved(for: colorScheme)
        return HStack(spacing: 14) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.1))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progress.fraction)
                        .shadow(color: tint.opacity(0.7), radius: 5)
                }
            }
            .frame(height: 5)

            Text("\(progress.cleared)")
                .font(theme.typography.numeric)
                .foregroundStyle(tint)
            + Text(" / \(progress.total)")
                .font(theme.typography.numeric)
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.35))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.cleared) / \(progress.total)")
    }

    /// `m:ss.t` past a minute, `s.t` below it — a puzzle here takes seconds, and
    /// "0:07.4" buries the number that changed in punctuation.
    static func formatted(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        if clamped < 60 {
            return String(format: "%.1f", clamped)
        }
        let minutes = Int(clamped) / 60
        let rest = clamped - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, rest)
    }
}
