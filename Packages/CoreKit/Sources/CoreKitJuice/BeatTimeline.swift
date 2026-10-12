// A choreography of named beats and timed feedback cues on one absolute clock.

import Foundation

/// One window of time inside a choreographed sequence.
///
/// The same shape the victory payoff already uses; aliased so sequences that are
/// not victories do not have to spell `VictoryTimeline` to describe themselves.
public typealias JuicePhase = VictoryTimeline.Phase

/// A haptic and/or tone that fires once at a fixed time inside a sequence.
public struct JuiceCue: Sendable, Equatable {
    public let time: TimeInterval
    public let haptic: HapticRecipe?
    public let tone: ToneRecipe?

    public init(at time: TimeInterval, haptic: HapticRecipe? = nil, tone: ToneRecipe? = nil) {
        self.time = max(0, time)
        self.haptic = haptic
        self.tone = tone
    }
}

/// A multi-beat sequence — a failure gag, a cutscene, a long payoff — described as data.
///
/// `VictoryTimeline` has three fixed layers because every victory in the portfolio
/// has the same three. Longer sequences do not share a shape: one game's failure is
/// a board that cracks and sinks, another's is a character that slips and lands.
/// Fixing the beat names here would freeze the first game's shape into shared code,
/// which is exactly the mistake the shared Home screen made. So the game names its
/// own beats and this type supplies what every such sequence needs: absolute time
/// (independent of frame rate), progress per beat, cues that fire exactly once, and
/// a total that can never cut a beat off.
public struct BeatTimeline<Beat: Hashable & Sendable>: Sendable, Equatable {
    public let phases: [Beat: JuicePhase]
    /// Sorted by time; cues that share a time keep the order they were given in.
    public let cues: [JuiceCue]
    /// Length of the whole sequence, never shorter than its last beat or cue.
    public let total: TimeInterval

    public init(phases: [Beat: JuicePhase], cues: [JuiceCue] = [], total: TimeInterval = 0) {
        self.phases = phases
        self.cues = cues.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
        let lastPhase = phases.values.map(\.end).max() ?? 0
        let lastCue = self.cues.last?.time ?? 0
        self.total = max(total, max(lastPhase, lastCue))
    }

    public func phase(_ beat: Beat) -> JuicePhase? {
        phases[beat]
    }

    /// Progress through `beat`, 0...1, or `nil` outside it (or if the beat is not scheduled).
    public func progress(of beat: Beat, at time: TimeInterval) -> Double? {
        phases[beat]?.progress(at: time)
    }

    /// Whether `beat` has started by `time`. Useful for state that holds after a beat ends.
    public func hasStarted(_ beat: Beat, at time: TimeInterval) -> Bool {
        guard let phase = phases[beat] else { return false }
        return time >= phase.start
    }

    /// Whether `beat` has finished by `time`.
    public func hasEnded(_ beat: Beat, at time: TimeInterval) -> Bool {
        guard let phase = phases[beat] else { return false }
        return time > phase.end
    }

    /// The cues that fall inside `beat`, start inclusive and end exclusive.
    ///
    /// Lets a test state a rule like "the comic pause is silent" directly.
    public func cues(during beat: Beat) -> [JuiceCue] {
        guard let phase = phases[beat] else { return [] }
        return cues.filter { $0.time >= phase.start && $0.time < phase.end }
    }

    public func isRunning(at time: TimeInterval) -> Bool {
        time >= 0 && time < total
    }

    public func playhead() -> BeatPlayhead {
        BeatPlayhead(cues: cues)
    }
}

/// Tracks which cues of a sequence have already fired.
///
/// Cues fire when the clock reaches them, not on a particular frame. A dropped
/// frame therefore delivers its cues late but never loses them, and a skip ahead
/// drops the cues it jumped over instead of firing them all at once — a burst of
/// five haptics on one frame reads as a malfunction, not as a gag.
public struct BeatPlayhead: Sendable, Equatable {
    public let cues: [JuiceCue]
    private var nextIndex: Int = 0

    /// `cues` must already be sorted by time; `BeatTimeline` guarantees it.
    init(cues: [JuiceCue]) {
        self.cues = cues
    }

    /// Time of the next cue that has not fired, or `nil` when all have.
    public var nextCueTime: TimeInterval? {
        nextIndex < cues.count ? cues[nextIndex].time : nil
    }

    public var isExhausted: Bool { nextIndex >= cues.count }

    /// Returns every not-yet-fired cue at or before `time`, and marks them fired.
    ///
    /// A clock that runs backwards fires nothing; cues never fire twice.
    public mutating func advance(to time: TimeInterval) -> [JuiceCue] {
        var due: [JuiceCue] = []
        while nextIndex < cues.count, cues[nextIndex].time <= time {
            due.append(cues[nextIndex])
            nextIndex += 1
        }
        return due
    }

    /// Moves the playhead to `time` without firing anything before it.
    ///
    /// Cues exactly at `time` stay pending, so skipping to a beat still plays that
    /// beat's opening cue. Jumping backwards re-arms the cues after `time`.
    public mutating func jump(to time: TimeInterval) {
        nextIndex = cues.firstIndex { $0.time >= time } ?? cues.count
    }
}
