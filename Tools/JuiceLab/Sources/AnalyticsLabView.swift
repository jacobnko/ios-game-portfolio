// Shows exactly what each canonical event looks like before it reaches a backend.

import SwiftUI
import CoreKitServices

struct AnalyticsLabView: View {
    @State private var hub = AnalyticsHub()
    @State private var reporter = ConsoleAnalyticsReporter()
    @State private var isRegistered = false
    @State private var isEnabled = true
    @State private var refresh = 0

    private var events: [AnalyticsEvent] { _ = refresh; return reporter.events.reversed() }

    var body: some View {
        Form {
            Section("Collection") {
                Toggle("Analytics enabled", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, on in hub.isEnabled = on }
                Button("Clear log") { reporter.clear(); refresh += 1 }
            }

            Section("Stage funnel") {
                button("stage_start") { GameEvent.stageStarted(stageID: "stage-4", attempt: 2) }
                button("stage_clear") { GameEvent.stageCleared(stageID: "stage-4", attempt: 2, durationSeconds: 23.4, stars: 3) }
                button("stage_abandon") { GameEvent.stageAbandoned(stageID: "stage-4", attempt: 2, durationSeconds: 8, progressPercent: 35) }
                button("hint_used") { GameEvent.hintUsed(stageID: "stage-4", source: .rewardedAd) }
            }

            Section("Monetization") {
                button("ad_shown") { GameEvent.adShown(placement: .interstitial) }
                button("ad_suppressed") { GameEvent.adSuppressed(verdict: .onboardingGrace) }
                button("reward_earned") { GameEvent.rewardEarned(placement: "hint") }
                button("remove_ads_purchase") { GameEvent.removeAdsPurchased(priceDisplay: "$2.99") }
                button("purchases_restore") { GameEvent.purchasesRestored(didRestore: true) }
            }

            Section("Virality") {
                button("share_trigger") { GameEvent.shareTriggered(surface: "result", stageID: "stage-4") }
            }

            Section("Sanitization") {
                // Proves the guard rail: a malformed name would otherwise be dropped
                // by the backend with no error anywhere.
                button("messy name → sanitized") { AnalyticsEvent(name: "Firebase_Stage Clear!!") }
                button("long value → truncated") {
                    AnalyticsEvent(name: "long_value", parameters: ["note": .string(String(repeating: "x", count: 250))])
                }
            }

            Section("Logged (\(events.count))") {
                if events.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    ForEach(events.indices, id: \.self) { index in
                        let event = events[index]
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.name).font(.subheadline.bold().monospaced())
                            Text(describe(event))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Analytics")
        .onAppear {
            guard !isRegistered else { return }
            hub.register(reporter)
            isRegistered = true
        }
    }

    private func button(_ title: String, _ make: @escaping () -> AnalyticsEvent) -> some View {
        Button(title) {
            hub.log(make())
            refresh += 1
        }
    }

    private func describe(_ event: AnalyticsEvent) -> String {
        guard !event.parameters.isEmpty else { return "no parameters" }
        return event.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.described)" }
            .joined(separator: "  ")
    }
}

#Preview {
    NavigationStack { AnalyticsLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
