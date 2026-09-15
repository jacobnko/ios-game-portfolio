// Previews the notification ladder without waiting days for it to fire.

import SwiftUI
import CoreKitServices

/// Stand-in copy. Real games supply localized strings from their own catalog.
struct SampleCopyProvider: NotificationCopyProviding {
    private let pools: [NotificationTheme: [NotificationCopy]] = [
        .progress: [
            NotificationCopy(title: "Stage 12 is waiting", body: "You were two moves from clearing it."),
            NotificationCopy(title: "Pick up where you left off", body: "Your board is exactly as you left it."),
            NotificationCopy(title: "One stage to go", body: "Chapter 2 unlocks after the next clear."),
        ],
        .curiosity: [
            NotificationCopy(title: "Today's puzzle is ready", body: "A new board, every day."),
            NotificationCopy(title: "Something new to solve", body: "Fresh stages just landed."),
        ],
        .lossAversion: [
            NotificationCopy(title: "Your streak ends in 3 hours", body: "One clear keeps it alive."),
        ],
    ]

    func poolSize(for theme: NotificationTheme) -> Int { pools[theme]?.count ?? 1 }

    func copy(for theme: NotificationTheme, index: Int) -> NotificationCopy {
        let pool = pools[theme] ?? []
        guard !pool.isEmpty else { return NotificationCopy(title: "—", body: "—") }
        return pool[index % pool.count]
    }
}

struct NotificationLabView: View {
    private let provider = SampleCopyProvider()
    @State private var scheduler = NotificationScheduler(copyProvider: SampleCopyProvider())
    @State private var daysSinceLastPlay: Double = 0
    @State private var hasStreak = false
    @State private var isAuthorized = false
    @State private var enabled = true
    @State private var scheduledCount = 0

    private var lastPlayed: Date {
        Date().addingTimeInterval(-daysSinceLastPlay * 86_400)
    }

    private var plan: [PlannedNotification] {
        NotificationPlanner.plan(
            lastPlayed: lastPlayed,
            now: Date(),
            copyPoolSizes: Dictionary(uniqueKeysWithValues: NotificationTheme.allCases.map { ($0, provider.poolSize(for: $0)) }),
            streakExpiresAt: hasStreak ? Date().addingTimeInterval(8 * 3600) : nil
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Authorized", value: isAuthorized ? "yes" : "no")
                LabeledContent("Already asked", value: scheduler.hasRequestedAuthorization ? "yes" : "no")
                Button("Request (as if after first clear)") {
                    Task {
                        isAuthorized = await scheduler.requestAuthorizationAfterFirstClear()
                    }
                }
                Toggle("Notifications enabled", isOn: $enabled)
                    .onChange(of: enabled) { _, on in scheduler.isEnabled = on }
            } header: {
                Text("Permission")
            } footer: {
                Text("A game must not ask on first launch. A refusal cannot be retried in-app — only through the Settings app, which almost nobody opens.")
            }

            Section("Simulate") {
                VStack(alignment: .leading) {
                    Text("Last played \(Int(daysSinceLastPlay)) days ago")
                        .font(.caption.monospacedDigit())
                    Slider(value: $daysSinceLastPlay, in: 0...30, step: 1)
                }
                Toggle("Streak expires in 8h", isOn: $hasStreak)
            }

            Section {
                ForEach(plan) { item in
                    let copy = provider.copy(for: item.theme, index: item.copyIndex)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.theme.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(color(for: item.theme).opacity(0.2))
                                .clipShape(Capsule())
                            Spacer()
                            Text(item.fireDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Text(copy.title).font(.subheadline.bold())
                        Text(copy.body).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Planned (\(plan.count))")
            } footer: {
                Text("Five touches over a month, never daily, always early evening. Opening the app cancels the whole ladder and rebuilds it from today.")
            }

            Section {
                Button("Schedule for real") {
                    Task { scheduledCount = await scheduler.refresh(lastPlayed: lastPlayed, streakExpiresAt: hasStreak ? Date().addingTimeInterval(8 * 3600) : nil).count }
                }
                Button("Fire a test notification in 10s") {
                    Task {
                        let ok = await scheduler.fireTestNotification(after: 10)
                        scheduledCount = ok ? scheduledCount + 1 : scheduledCount
                    }
                }
                Button("Cancel all", role: .destructive) {
                    Task {
                        await scheduler.cancelAll()
                        scheduledCount = 0
                    }
                }
                LabeledContent("Scheduled", value: "\(scheduledCount)")
            }
        }
        .navigationTitle("Notifications")
        .task {
            isAuthorized = await scheduler.isAuthorized()
            enabled = scheduler.isEnabled
        }
    }

    private func color(for theme: NotificationTheme) -> Color {
        switch theme {
        case .progress: .blue
        case .curiosity: .green
        case .lossAversion: .orange
        }
    }
}

#Preview {
    NavigationStack { NotificationLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
