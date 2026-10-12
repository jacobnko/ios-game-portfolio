// Persists UsageCounter tallies so consumable uses survive sync, offline play and reinstalls.

import Foundation
import SwiftData

/// One device's tally for one counter.
///
/// Every property defaulted and nothing unique, as CloudKit requires (see `StageRecord`).
/// A device only ever writes rows carrying its own `deviceID`, so two devices never
/// edit the same row and CloudKit never has a write conflict to resolve. Duplicates
/// can still appear (a save retried around a sync); reading collapses them by `max`.
@Model
public final class CounterRecord {
    public var key: String = ""
    public var deviceID: String = ""
    public var count: Int = 0
    public var updatedAt: Date?

    public init(key: String, deviceID: String, count: Int, updatedAt: Date?) {
        self.key = key
        self.deviceID = deviceID
        self.count = count
        self.updatedAt = updatedAt
    }
}

/// Reads and raises grow-only usage counters, such as "free boosters used" or "uses today".
///
/// Games store *uses*, never *remaining*: remaining is derived (`allowance - total`)
/// at the moment it is shown. That keeps a reinstall from handing the allowance back —
/// the old install's tally is still in iCloud under its old device id and still counts.
@MainActor
public final class CounterStore {
    public let container: ModelContainer
    /// This install's id. Every write goes to rows carrying it.
    public let deviceID: String
    private var context: ModelContext { container.mainContext }

    /// The container must include `CounterRecord` — pass `includesCounters: true` to
    /// `ProgressStore.makeContainer` / `inMemoryContainer`, and share that one container
    /// with the game's `ProgressStore`.
    public init(container: ModelContainer, deviceID: String) {
        self.container = container
        self.deviceID = deviceID
    }

    /// A random id for this install, created on first use and kept in `defaults`.
    ///
    /// Deliberately not `identifierForVendor` or anything hardware-derived: it only
    /// has to be distinct per install, it is never sent anywhere but the player's own
    /// private iCloud database, and a new id after a reinstall is correct behaviour —
    /// the old id's tally stays and keeps counting.
    public static func installID(defaults: UserDefaults = .standard) -> String {
        let key = "corekit.counterStore.installID"
        if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: key)
        return fresh
    }

    // MARK: - Reading

    public func counter(_ key: String) throws -> UsageCounter {
        UsageCounter.merged(rows: try records(for: key).map { (deviceID: $0.deviceID, count: $0.count) })
    }

    /// Uses summed over every device.
    public func total(_ key: String) throws -> Int {
        try counter(key).total
    }

    // MARK: - Writing

    /// Records `amount` more uses on this device and returns the new total.
    @discardableResult
    public func increment(_ key: String, by amount: Int = 1, at date: Date = Date()) throws -> Int {
        let all = try records(for: key)
        guard amount > 0 else {
            return UsageCounter.merged(rows: all.map { (deviceID: $0.deviceID, count: $0.count) }).total
        }

        let own = all.filter { $0.deviceID == deviceID }
        // Start from the largest of this device's own rows: a duplicate must never
        // make the tally go backwards.
        let next = (own.map(\.count).max() ?? 0) + amount
        if let first = own.first {
            first.count = next
            first.updatedAt = date
            own.dropFirst().forEach(context.delete)
        } else {
            context.insert(CounterRecord(key: key, deviceID: deviceID, count: next, updatedAt: date))
        }
        try context.save()
        return try total(key)
    }

    /// Deletes every counter whose key matches — for pruning past days of a daily
    /// counter. Never use it on a lifetime allowance: deleting uses gives them back.
    public func deleteCounters(where shouldDelete: (String) -> Bool) throws {
        let all = try context.fetch(FetchDescriptor<CounterRecord>())
        all.filter { shouldDelete($0.key) }.forEach(context.delete)
        try context.save()
    }

    private func records(for key: String) throws -> [CounterRecord] {
        try context.fetch(FetchDescriptor<CounterRecord>(predicate: #Predicate { $0.key == key }))
    }
}
