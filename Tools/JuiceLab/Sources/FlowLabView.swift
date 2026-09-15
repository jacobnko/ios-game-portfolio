// Assembles Home → StageSelect → Game (stub) → Result → back, wiring
// GameFlowCoordinator to real (local) CoreKit services. This is the shape every
// game's own App struct will follow — see docs/architecture/new-game-setup.md.

import SwiftUI
import CoreKitData
import CoreKitServices
import CoreKitAdsGoogle
import CoreKitUI

private struct DemoStage: StageDescriptor {
    let id: String
    let displayNumber: Int
}

private let demoStages: [DemoStage] = (1...8).map { DemoStage(id: "flow-demo-\($0)", displayNumber: $0) }

struct FlowLabView: View {
    @State private var coordinator: GameFlowCoordinator?
    @State private var progressSnapshot: [String: StageProgress] = [:]
    @State private var errorText: String?

    var body: some View {
        Group {
            if let coordinator {
                FlowLabRouter(coordinator: coordinator, progressSnapshot: $progressSnapshot)
            } else if let errorText {
                Text(errorText).foregroundStyle(.red).padding()
            } else {
                ProgressView().task { await setUp() }
            }
        }
        // Stands in for a game's own brand theme — see ThemeLabView for three
        // contrasting examples. Any real game supplies its own here.
        .gameTheme(.placeholder)
    }

    private func setUp() async {
        do {
            let store = ProgressStore(container: try ProgressStore.makeContainer(cloudKitEnabled: false))
            let purchases = PurchaseManager()
            purchases.start()
            let presenter = GoogleAdPresenter(adUnitIDs: .test)
            let ads = AdCoordinator(purchases: purchases, presenter: presenter, policy: .unrestricted)
            let flow = GameFlowCoordinator(progress: store, purchases: purchases, ads: ads)
            coordinator = flow
            progressSnapshot = Dictionary(uniqueKeysWithValues: (try store.allProgress()).map { ($0.stageId, $0) })
        } catch {
            errorText = "\(error)"
        }
    }
}

/// Owns the `NavigationStack` and the `.navigationDestination` switch — exactly
/// the piece `docs/architecture/new-game-setup.md` asks every game to write for
/// itself, with `.game` filled in by a stub here and by real gameplay there.
private struct FlowLabRouter: View {
    @Bindable var coordinator: GameFlowCoordinator
    @Binding var progressSnapshot: [String: StageProgress]

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                onPlay: { coordinator.showStageSelect() },
                onSettings: { coordinator.openSettings() },
                logo: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 56))
                        Text("Flow Demo").font(.headline)
                    }
                },
                banner: {
                    AdBannerSlot(adUnitID: AdUnitIDs.test.banner, isVisible: coordinator.ads.showsBanner)
                }
            )
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .stageSelect:
                    StageSelectView(
                        stages: demoStages,
                        progress: progressSnapshot,
                        isUnlocked: isUnlocked,
                        onSelect: { stage in
                            let attempt = (progressSnapshot[stage.id]?.attemptCount ?? 0) + 1
                            coordinator.startStage(stage.id, attempt: attempt)
                        },
                        onBack: { coordinator.goHome() }
                    )

                case .game(let stageID):
                    // A real game replaces this entirely with its own gameplay
                    // view. This stub only proves the handoff: it calls
                    // `coordinator.completeStage` exactly the way a finished
                    // board or a game-over screen would.
                    StubGameView(stageID: stageID) { outcome in
                        Task {
                            let saved = await coordinator.completeStage(stageID, outcome: outcome)
                            progressSnapshot[stageID] = saved
                        }
                    }

                case .result(let stageID, let outcome):
                    ResultView(
                        outcome: outcome,
                        onAdvance: {
                            let next = nextStage(after: stageID)
                            Task { await coordinator.advanceFromResult(nextStageID: next?.id) }
                        },
                        onRetry: {
                            let attempt = (progressSnapshot[stageID]?.attemptCount ?? 0) + 1
                            coordinator.retryStage(stageID, attempt: attempt)
                        }
                    )

                case .settings:
                    SettingsView(
                        purchases: coordinator.purchases,
                        privacyPolicyURL: URL(string: "https://example.com/privacy"),
                        onResetProgress: {
                            try? coordinator.progress.deleteAll()
                            progressSnapshot = [:]
                            coordinator.goHome()
                        },
                        onBack: { coordinator.pop() }
                    )
                }
            }
        }
    }

    private func isUnlocked(_ stage: DemoStage) -> Bool {
        guard stage.displayNumber > 1 else { return true }
        let previous = demoStages[stage.displayNumber - 2]
        return progressSnapshot[previous.id]?.isCleared ?? false
    }

    private func nextStage(after stageID: String) -> DemoStage? {
        guard let index = demoStages.firstIndex(where: { $0.id == stageID }) else { return nil }
        let nextIndex = index + 1
        return nextIndex < demoStages.count ? demoStages[nextIndex] : nil
    }
}

/// Stands in for a real gameplay screen. A real game never ships this — it is
/// only here so the flow can be exercised without a finished puzzle to play.
private struct StubGameView: View {
    let stageID: String
    let onComplete: (StageOutcome) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Gameplay stub — \(stageID)")
                .font(.title2.bold())
            Text("A real game replaces this entire screen.")
                .foregroundStyle(.secondary)

            Button("Clear (3 stars)") {
                onComplete(StageOutcome(cleared: true, score: 250, stars: 3, durationSeconds: 18))
            }
            .buttonStyle(.borderedProminent)

            Button("Clear (1 star)") {
                onComplete(StageOutcome(cleared: true, score: 60, stars: 1, durationSeconds: 55))
            }
            .buttonStyle(.bordered)

            Button("Fail") {
                onComplete(StageOutcome(cleared: false, progressPercent: 40))
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    FlowLabView()
}
