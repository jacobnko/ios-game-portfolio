// Plays a BeatTimeline: owns its clock, fires its cues on time, and reports the end.

import Foundation
import Observation

/// Runs one `BeatTimeline` at a time against the wall clock.
///
/// The game draws its own beats — it reads `elapsed(at:)` inside a `TimelineView` and
/// asks the timeline for each beat's progress. This type owns the parts that must not
/// depend on rendering: cues and completion are driven by a task, not by frames, for
/// the same reason the victory payoff's completion is. If the timeline view stops
/// ticking (scrolled away, backgrounded at the wrong moment), the haptics still land on
/// time and the game still gets `onFinished`, instead of sitting on the gag forever.
@MainActor
@Observable
public final class BeatPerformer {
    /// When the current sequence's time zero was, or `nil` while idle.
    /// Moved earlier by `skip(to:)`, so `elapsed(at:)` stays the single source of time.
    public private(set) var startDate: Date?
    public private(set) var total: TimeInterval = 0
    /// Whether cues are sent to `HapticEngine` and `PitchedTonePlayer`.
    public var playsFeedback: Bool = true

    @ObservationIgnored private var playhead = BeatPlayhead(cues: [])
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var onFinished: (() -> Void)?
    /// Every cue that has fired in the current run, in order. For tests and the lab.
    @ObservationIgnored public private(set) var firedCues: [JuiceCue] = []

    public init() {}

    public var isPlaying: Bool { startDate != nil }

    /// Seconds since time zero, or `nil` while idle. Never past `total`.
    public func elapsed(at date: Date = Date()) -> TimeInterval? {
        guard let startDate else { return nil }
        return min(total, max(0, date.timeIntervalSince(startDate)))
    }

    /// Starts `timeline` from zero, replacing whatever was playing without finishing it.
    public func play<Beat>(_ timeline: BeatTimeline<Beat>, onFinished: (() -> Void)? = nil) {
        cancel()
        playhead = timeline.playhead()
        total = timeline.total
        firedCues = []
        self.onFinished = onFinished
        startDate = Date()
        schedule()
    }

    /// Jumps to `time` — typically the start of the beat that shows the result, when
    /// the player taps through. Cues in between are dropped, not fired in a burst.
    public func skip(to time: TimeInterval) {
        guard let startDate else { return }
        let target = min(total, max(0, time))
        let now = Date()
        // Only ever forward: a skip that rewinds would replay the cues it re-arms.
        guard target > now.timeIntervalSince(startDate) else { return }
        self.startDate = now.addingTimeInterval(-target)
        playhead.jump(to: target)
        schedule()
    }

    /// Stops without calling `onFinished`.
    public func cancel() {
        task?.cancel()
        task = nil
        startDate = nil
        onFinished = nil
    }

    private func schedule() {
        task?.cancel()
        task = Task { [weak self] in
            await self?.run()
        }
    }

    private func run() async {
        while !Task.isCancelled, let now = elapsed() {
            fire(playhead.advance(to: now))
            let wakeAt = playhead.nextCueTime ?? total
            if now >= total, playhead.isExhausted { break }
            try? await Task.sleep(for: .seconds(max(0, wakeAt - now)))
        }
        guard !Task.isCancelled, startDate != nil else { return }
        finish()
    }

    private func fire(_ cues: [JuiceCue]) {
        firedCues.append(contentsOf: cues)
        guard playsFeedback else { return }
        for cue in cues {
            if let haptic = cue.haptic { HapticEngine.shared.play(haptic) }
            if let tone = cue.tone { PitchedTonePlayer.shared.play(tone) }
        }
    }

    private func finish() {
        let completion = onFinished
        task = nil
        startDate = nil
        onFinished = nil
        completion?()
    }
}
