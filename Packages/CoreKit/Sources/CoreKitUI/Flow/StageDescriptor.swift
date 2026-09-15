// What StageSelectView needs to know about one stage. Games supply their own type.

import Foundation

/// Minimal shape a game's stage list must have to render in `StageSelectView`.
///
/// Deliberately thin. Difficulty curve, chapter grouping, unlock rules — all of
/// that is game-specific and stays out of `CoreKitUI`. Unlock logic in particular
/// varies too much to standardize: some games unlock linearly, some by star count,
/// some by chapter, so it is supplied by the caller as a closure, not a protocol
/// requirement here.
public protocol StageDescriptor: Sendable {
    var id: String { get }
    /// 1-based position shown to the player. Not necessarily the array index —
    /// a game can renumber without reordering its data.
    var displayNumber: Int { get }
}
