// Value type for a count that only grows, merged across devices without losing uses.

import Foundation

/// How many times something has been used, summed over every device the player owns.
///
/// Stored as one tally per device rather than one shared number, because the
/// obvious shared design is wrong. If a single counter is merged by "keep the larger
/// value", two devices that each use one item offline both write 1, the merge keeps
/// 1, and the player has had two for the price of one. Storing "remaining" instead is
/// worse: reinstalling resets it.
///
/// Here each device only ever raises its own tally, and the total is the sum of the
/// per-device tallies. Merging takes the larger tally *per device*, which makes the
/// merge commutative, associative and idempotent — sync can deliver the same rows
/// any number of times in any order and the total comes out the same. (This is a
/// grow-only counter, the textbook CRDT for exactly this problem.)
public struct UsageCounter: Sendable, Equatable {
    /// Each device's own tally, keyed by device id.
    public private(set) var tallies: [String: Int]

    public init(tallies: [String: Int] = [:]) {
        self.tallies = tallies.filter { $0.value > 0 }
    }

    public var total: Int {
        tallies.values.reduce(0, +)
    }

    public func tally(for deviceID: String) -> Int {
        tallies[deviceID] ?? 0
    }

    /// Records `amount` more uses on `deviceID`. Negative amounts are ignored:
    /// a counter that can go down can no longer be merged safely.
    public mutating func increment(deviceID: String, by amount: Int = 1) {
        guard amount > 0 else { return }
        tallies[deviceID, default: 0] += amount
    }

    public func merged(with other: UsageCounter) -> UsageCounter {
        UsageCounter(tallies: tallies.merging(other.tallies, uniquingKeysWith: max))
    }

    /// Folds any number of `(deviceID, tally)` rows — duplicates included — into one counter.
    public static func merged<S: Sequence>(rows: S) -> UsageCounter where S.Element == (deviceID: String, count: Int) {
        var tallies: [String: Int] = [:]
        for row in rows {
            tallies[row.deviceID] = max(tallies[row.deviceID] ?? 0, row.count)
        }
        return UsageCounter(tallies: tallies)
    }
}

/// A calendar day as a stable string, for counters that reset daily ("uses today").
///
/// Built from calendar components rather than a `DateFormatter`, whose output can
/// change with the user's locale and calendar settings — a key that changes spelling
/// would silently reset the day's count. The day boundary is the given calendar's
/// local midnight; the date is an argument so the boundary can be tested.
public enum DayStamp {
    /// Gregorian in the device's time zone. Not `Calendar.current`: a player whose
    /// iPad uses the Buddhist calendar and whose iPhone does not would otherwise write
    /// two different keys for the same day and get the daily allowance twice.
    public static var localGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    public static func string(for date: Date, calendar: Calendar = localGregorian) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0, month = parts.month ?? 0, day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
