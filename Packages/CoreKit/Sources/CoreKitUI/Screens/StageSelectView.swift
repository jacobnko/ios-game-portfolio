// A grid of stages, generic over whatever stage type a game defines.

import SwiftUI
import CoreKitData
import CoreKitServices

/// What a tile is showing. Deliberately three states, not two.
///
/// D4's rule is that the states differ by *fill*, not hue: a cleared tile is
/// outlined and check-marked, the current one is ringed and numbered, a locked
/// one is a sunken padlock. Colour reinforces each, but a player who cannot
/// separate cyan from amber still reads the grid — the same contract the board's
/// glyphs and textures carry.
public enum StageTileState: Sendable, Equatable {
    case cleared
    case current
    case locked
    /// Unlocked and not yet cleared, but not the stage the player is up to —
    /// a stage they skipped past or came back from.
    case open
}

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
    private let title: String?

    public init(
        stages: [Stage],
        progress: [String: StageProgress],
        isUnlocked: @escaping (Stage) -> Bool,
        onSelect: @escaping (Stage) -> Void,
        onBack: @escaping () -> Void,
        title: String? = nil
    ) {
        self.stages = stages
        self.progress = progress
        self.isUnlocked = isUnlocked
        self.onSelect = onSelect
        self.onBack = onBack
        self.title = title
    }

    /// The first unlocked stage the player has not cleared — the one tile that
    /// gets the amber treatment, so opening this screen answers "where was I"
    /// without reading any numbers.
    private var currentStageID: String? {
        stages.first { isUnlocked($0) && !(progress[$0.id]?.isCleared ?? false) }?.id
    }

    private var clearedCount: Int {
        stages.count { progress[$0.id]?.isCleared ?? false }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 12)

            ScrollViewReader { scroller in
                ScrollView {
                    StageGrid(
                        stages: stages,
                        progress: progress,
                        isUnlocked: isUnlocked,
                        currentStageID: currentStageID,
                        onSelect: onSelect
                    )
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
                .onAppear {
                    // D4 pages the grid and marks the page with dots, which
                    // works for its 60 stages. These ladders run past a hundred,
                    // where five or six identical dots stop being a position
                    // cue — scrolling straight to the live stage answers the
                    // same question directly.
                    guard let currentStageID else { return }
                    scroller.scrollTo(currentStageID, anchor: .center)
                }
            }

            legend
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                theme.palette.background.resolved(for: colorScheme)
                RadialGradient(
                    colors: [theme.palette.secondary.resolved(for: colorScheme).opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.44),
                    startRadius: 0,
                    endRadius: 340
                )
            }
            .ignoresSafeArea()
        }
        // This screen draws its own back button above, so the stack's built-in
        // one would be a second, differently-styled control doing the same job
        // — which is exactly how it shipped until a device build showed two
        // chevrons stacked on the stage grid. JuiceLab's FlowLabView already
        // did this; the shared screen did not.
        .navigationBarBackButtonHidden()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme))
                    .frame(width: 48, height: 48)
                    .background(surfaceTile(radius: 15, borderOpacity: 0.1))
            }
            .accessibilityLabel(CommonStrings.back.text)

            VStack(alignment: .leading, spacing: 7) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.1))
                        Capsule()
                            .fill(theme.palette.primary.resolved(for: colorScheme))
                            .frame(width: proxy.size.width * fraction)
                            .shadow(color: theme.palette.primary.resolved(for: colorScheme).opacity(0.7), radius: 5)
                    }
                }
                .frame(height: 5)

                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(2)
                            .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.4))
                    }
                    Spacer()
                    Text("\(clearedCount)")
                        .font(theme.typography.numeric)
                        .foregroundStyle(theme.palette.primary.resolved(for: colorScheme))
                    + Text(" / \(stages.count)")
                        .font(theme.typography.numeric)
                        .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.35))
                }
            }
        }
        .frame(height: 48)
    }

    private var fraction: Double {
        guard !stages.isEmpty else { return 0 }
        return min(1, Double(clearedCount) / Double(stages.count))
    }

    // MARK: - Legend

    /// Repeats the three marks with their names, because a shape only teaches
    /// itself once it is labelled.
    private var legend: some View {
        HStack {
            legendItem(
                CommonStrings.stageLegendClear.text,
                systemImage: "checkmark",
                colour: theme.palette.primary.resolved(for: colorScheme)
            )
            Spacer()
            legendItem(
                CommonStrings.stageLegendCurrent.text,
                systemImage: "circle",
                colour: theme.palette.accent.resolved(for: colorScheme)
            )
            Spacer()
            legendItem(
                CommonStrings.stageLegendLocked.text,
                systemImage: "lock.fill",
                colour: theme.palette.onSurface.resolved(for: colorScheme).opacity(0.4)
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(surfaceTile(radius: 14, borderOpacity: 0.08, fillOpacity: 0.7))
        .accessibilityHidden(true)
    }

    private func legendItem(_ label: String, systemImage: String, colour: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(colour)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(theme.palette.onSurface.resolved(for: colorScheme).opacity(0.7))
        }
    }

    private func surfaceTile(radius: CGFloat, borderOpacity: Double, fillOpacity: Double = 1) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(theme.palette.surface.resolved(for: colorScheme).opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.palette.onSurface.resolved(for: colorScheme).opacity(borderOpacity), lineWidth: 1)
            )
    }
}

/// The tile grid, as its own view.
///
/// A real `View` type rather than a computed property on `StageSelectView`,
/// because environment values are injected when SwiftUI renders a view — not
/// when something reads a property off the struct. Pulling a sub-view out
/// through a computed property hands back a tree whose `@Environment` was never
/// populated, so it silently renders with the default theme in light mode. That
/// is precisely what the first snapshot of this grid showed: correct shapes,
/// entirely wrong colours.
///
/// Being separate also means the grid can be rendered outside a scroll
/// container, which `ImageRenderer` requires — it produces a blank image for
/// anything inside a `ScrollView` on macOS.
public struct StageGrid<Stage: StageDescriptor>: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private let stages: [Stage]
    private let progress: [String: StageProgress]
    private let isUnlocked: (Stage) -> Bool
    private let currentStageID: String?
    private let onSelect: (Stage) -> Void

    public init(
        stages: [Stage],
        progress: [String: StageProgress],
        isUnlocked: @escaping (Stage) -> Bool,
        currentStageID: String?,
        onSelect: @escaping (Stage) -> Void
    ) {
        self.stages = stages
        self.progress = progress
        self.isUnlocked = isUnlocked
        self.currentStageID = currentStageID
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 13), count: 4), spacing: 13) {
            ForEach(stages, id: \.id) { stage in
                tile(for: stage).id(stage.id)
            }
        }
    }


    func state(for stage: Stage) -> StageTileState {
        if progress[stage.id]?.isCleared ?? false { return .cleared }
        guard isUnlocked(stage) else { return .locked }
        return stage.id == currentStageID ? .current : .open
    }

    @ViewBuilder
    private func tile(for stage: Stage) -> some View {
        let tileState = state(for: stage)
        let cyan = theme.palette.primary.resolved(for: colorScheme)
        let amber = theme.palette.accent.resolved(for: colorScheme)
        let ink = theme.palette.onSurface.resolved(for: colorScheme)

        Button {
            onSelect(stage)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        tileState == .locked
                            ? theme.palette.background.resolved(for: colorScheme)
                            : theme.palette.surface.resolved(for: colorScheme)
                    )

                switch tileState {
                case .cleared:
                    RoundedRectangle(cornerRadius: 18).stroke(cyan.opacity(0.35), lineWidth: 1)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(cyan)
                        .shadow(color: cyan.opacity(0.85), radius: 4)

                case .current:
                    RoundedRectangle(cornerRadius: 18).stroke(amber, lineWidth: 2.5)
                    Circle()
                        .stroke(amber.opacity(0.95), lineWidth: 3)
                        .frame(width: 34, height: 34)
                        .shadow(color: amber.opacity(0.7), radius: 6)
                    Text("\(stage.displayNumber)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(amber)
                    // The outer ring reads as a pulse even standing still: it
                    // is the only tile with anything outside its own bounds.
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(amber.opacity(0.35), lineWidth: 1.5)
                        .padding(-7)

                case .open:
                    RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.11), lineWidth: 1)
                    Text("\(stage.displayNumber)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.75))

                case .locked:
                    RoundedRectangle(cornerRadius: 18).stroke(ink.opacity(0.07), lineWidth: 1)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ink.opacity(0.26))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(minHeight: 78)
            .shadow(color: glowColour(tileState, cyan: cyan, amber: amber), radius: glowRadius(tileState))
        }
        // A locked stage is dimmed, not hidden — the player should see the ladder
        // ahead, which is itself part of the "progress" theme's re-engagement pull.
        .disabled(tileState == .locked)
        .accessibilityLabel(accessibilityLabel(stage, state: tileState))
    }

    private func glowColour(_ state: StageTileState, cyan: Color, amber: Color) -> Color {
        switch state {
        case .cleared: cyan.opacity(0.14)
        case .current: amber.opacity(0.45)
        case .open, .locked: .clear
        }
    }

    private func glowRadius(_ state: StageTileState) -> CGFloat {
        switch state {
        case .cleared: 7
        case .current: 11
        case .open, .locked: 0
        }
    }

    private func accessibilityLabel(_ stage: Stage, state: StageTileState) -> String {
        switch state {
        case .locked: CommonStrings.stageLocked.text
        case .cleared: "\(stage.displayNumber), \(CommonStrings.stageLegendClear.text)"
        case .current: "\(stage.displayNumber), \(CommonStrings.stageLegendCurrent.text)"
        case .open: "\(stage.displayNumber)"
        }
    }

}
