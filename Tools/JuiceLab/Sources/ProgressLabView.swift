// Exercises the progress store, including the duplicate rows CloudKit sync creates.

import SwiftUI
import SwiftData
import CoreKitData

struct ProgressLabView: View {
    @State private var store: ProgressStore?
    @State private var stages: [StageProgress] = []
    @State private var summary: ProgressSummary?
    @State private var errorText: String?

    var body: some View {
        Form {
            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }

            Section("Record an attempt") {
                Button("Clear a random stage") { record(cleared: true) }
                Button("Fail a random stage") { record(cleared: false) }
            }

            Section {
                Button("Inject duplicate rows for stage-1") { injectDuplicates() }
                Button("Read stage-1 (merges and prunes)") { refresh() }
            } header: {
                Text("Duplicate repair")
            } footer: {
                Text("CloudKit cannot enforce uniqueness, so two devices can each create a row for the same stage. Injecting duplicates then reading should leave exactly one row holding the best of both.")
            }

            if let summary {
                Section("Summary") {
                    LabeledContent("Cleared", value: "\(summary.clearedCount)")
                    LabeledContent("Stars", value: "\(summary.totalStars)")
                    LabeledContent("Score", value: "\(summary.totalScore)")
                    LabeledContent("Rows", value: "\(rowCount)")
                }
            }

            Section("Stages") {
                if stages.isEmpty {
                    Text("No progress yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(stages, id: \.stageId) { stage in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.stageId).font(.subheadline.bold())
                            Text("score \(stage.bestScore)   stars \(stage.starsEarned)   attempts \(stage.attemptCount)   \(stage.isCleared ? "cleared" : "open")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Reset all progress", role: .destructive) {
                    perform { try $0.deleteAll() }
                }
            }
        }
        .navigationTitle("Progress")
        .onAppear(perform: setUp)
    }

    private var rowCount: Int {
        // `try?` over an optional chain yields Int??; the old `as? Int` on that
        // always failed, so this row displayed 0 no matter how many rows existed —
        // which is the one number the duplicate-repair check depends on.
        guard let store, let count = try? store.container.mainContext.fetch(FetchDescriptor<StageRecord>()).count else {
            return 0
        }
        return count
    }

    private func setUp() {
        guard store == nil else { return }
        do {
            // Local only. CloudKit round-trip is verified in game #1, where the
            // container actually exists — see docs/architecture/cloudkit-setup.md.
            store = ProgressStore(container: try ProgressStore.makeContainer(cloudKitEnabled: false))
            refresh()
        } catch {
            errorText = "\(error)"
        }
    }

    private func record(cleared: Bool) {
        let stage = "stage-\(Int.random(in: 1...5))"
        perform {
            try $0.recordAttempt(
                stageId: stage,
                score: Int.random(in: 10...200),
                durationSeconds: Double.random(in: 8...60),
                stars: Int.random(in: 0...3),
                cleared: cleared
            )
        }
    }

    private func injectDuplicates() {
        perform { store in
            let context = store.container.mainContext
            context.insert(StageRecord(StageProgress(stageId: "stage-1", bestScore: 999, starsEarned: 1, attemptCount: 2)))
            context.insert(StageRecord(StageProgress(stageId: "stage-1", bestScore: 10, starsEarned: 3, attemptCount: 8)))
            try context.save()
        }
    }

    private func refresh() {
        perform { _ in }
    }

    private func perform(_ work: (ProgressStore) throws -> Void) {
        guard let store else { return }
        do {
            try work(store)
            stages = try store.allProgress()
            summary = try store.summary()
            errorText = nil
        } catch {
            errorText = "\(error)"
        }
    }
}

#Preview {
    NavigationStack { ProgressLabView() }
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
