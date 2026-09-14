// Proves the banner does not reload on parent re-render, and exercises ad pacing.

import SwiftUI
import CoreKitServices
import CoreKitAdsGoogle

struct AdsLabView: View {
    @State private var purchases = PurchaseManager()
    @State private var presenter = GoogleAdPresenter(adUnitIDs: .test)
    @State private var coordinator: AdCoordinator?
    @State private var tick = 0
    @State private var log: [String] = []
    @State private var usePacing = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    // This counter re-renders the parent several times a second.
                    // The naive UIViewRepresentable would reload the banner on every
                    // one of these; the coordinator-held instance must not blink.
                    LabeledContent("Parent re-renders", value: "\(tick)")
                    Text("The banner below must not flicker or reload while this counts up.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Text("Banner reload check")
                }

                Section("State") {
                    LabeledContent("Ads removed", value: purchases.adsRemoved ? "YES" : "no")
                    LabeledContent("Interstitial ready", value: presenter.isInterstitialReady ? "yes" : "loading")
                    LabeledContent("Rewarded ready", value: presenter.isRewardedReady ? "yes" : "loading")
                    LabeledContent("Clears", value: "\(coordinator?.activity.totalClears ?? 0)")
                    LabeledContent("Last verdict", value: coordinator.map { "\($0.lastVerdict)" } ?? "—")
                    Toggle("Apply pacing policy", isOn: $usePacing)
                        .onChange(of: usePacing) { _, on in
                            coordinator?.policy = on ? .standard : .unrestricted
                        }
                }

                Section("Actions") {
                    Button("Stage cleared") {
                        coordinator?.recordStageClear()
                        append("clear → \(coordinator?.activity.totalClears ?? 0)")
                    }
                    Button("Try interstitial") {
                        Task {
                            let shown = await coordinator?.showInterstitialIfAllowed() ?? false
                            append("interstitial shown=\(shown) verdict=" + (coordinator.map { "\($0.lastVerdict)" } ?? "?"))
                        }
                    }
                    Button("Watch rewarded (hint)") {
                        Task { append("rewarded → \(await coordinator?.showRewarded() ?? .unavailable)") }
                    }
                }

                Section("Log") {
                    if log.isEmpty {
                        Text("—").foregroundStyle(.secondary)
                    } else {
                        ForEach(log.indices, id: \.self) { Text(log[$0]).font(.caption.monospaced()) }
                    }
                }
            }

            AdBannerSlot(adUnitID: AdUnitIDs.test.banner, isVisible: coordinator?.showsBanner ?? true)
                .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("Ads")
        .task {
            if coordinator == nil {
                purchases.start()
                coordinator = AdCoordinator(purchases: purchases, presenter: presenter, policy: .unrestricted)
                coordinator?.preload()
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                tick += 1
            }
        }
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 12 { log.removeLast() }
    }
}

#Preview {
    NavigationStack { AdsLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
