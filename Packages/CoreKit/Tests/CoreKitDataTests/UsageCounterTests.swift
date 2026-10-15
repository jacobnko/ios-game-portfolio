// Proves usage counters never lose a use across devices, duplicates, or reinstalls.

import Testing
import Foundation
import SwiftData
@testable import CoreKitData

// MARK: - Merge rules

@Test func twoDevicesUsingOfflineAreBothCounted() {
    // The failure a single max-merged counter has: both devices write 1, max keeps 1.
    var phone = UsageCounter()
    var pad = UsageCounter()
    phone.increment(deviceID: "phone")
    pad.increment(deviceID: "pad")
    #expect(phone.merged(with: pad).total == 2)
}

private let samples: [UsageCounter] = [
    UsageCounter(),
    UsageCounter(tallies: ["a": 1]),
    UsageCounter(tallies: ["a": 3, "b": 1]),
    UsageCounter(tallies: ["b": 2, "c": 5]),
    UsageCounter(tallies: ["a": 2, "c": 1]),
]

@Test func counterMergeIsCommutative() {
    for x in samples { for y in samples {
        #expect(x.merged(with: y) == y.merged(with: x))
    } }
}

@Test func counterMergeIsAssociative() {
    for x in samples { for y in samples { for z in samples {
        #expect(x.merged(with: y).merged(with: z) == x.merged(with: y.merged(with: z)))
    } } }
}

@Test func counterMergeIsIdempotent() {
    // Sync may deliver the same rows again; the total must not move.
    for x in samples { for y in samples {
        let once = x.merged(with: y)
        #expect(once.merged(with: y) == once)
        #expect(x.merged(with: x) == x)
    } }
}

@Test func counterMergeNeverLowersATotal() {
    for x in samples { for y in samples {
        let merged = x.merged(with: y)
        #expect(merged.total >= max(x.total, y.total))
    } }
}

@Test func duplicateRowsCollapseToTheLargestPerDevice() {
    let counter = UsageCounter.merged(rows: [
        (deviceID: "a", count: 1), (deviceID: "a", count: 3), (deviceID: "b", count: 2), (deviceID: "a", count: 2),
    ])
    #expect(counter.tallies == ["a": 3, "b": 2])
    #expect(counter.total == 5)
}

@Test func countersOnlyGoUp() {
    var counter = UsageCounter(tallies: ["a": 2])
    counter.increment(deviceID: "a", by: -5)
    counter.increment(deviceID: "a", by: 0)
    #expect(counter.total == 2)
    #expect(UsageCounter(tallies: ["a": 0, "b": -1]).tallies.isEmpty)
}

// MARK: - Day stamps

private func calendar(_ zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

@Test func dayStampTurnsOverAtLocalMidnight() {
    let seoul = calendar("Asia/Seoul")
    let midnight = seoul.date(from: DateComponents(year: 2026, month: 10, day: 13))!
    #expect(DayStamp.string(for: midnight.addingTimeInterval(-1), calendar: seoul) == "2026-10-12")
    #expect(DayStamp.string(for: midnight, calendar: seoul) == "2026-10-13")
}

@Test func dayStampIsZeroPaddedAndLocaleFree() {
    let utc = calendar("UTC")
    let date = utc.date(from: DateComponents(year: 2027, month: 1, day: 5, hour: 12))!
    #expect(DayStamp.string(for: date, calendar: utc) == "2027-01-05")
}

@Test func defaultDayStampIgnoresTheUsersCalendarSystem() {
    // Two devices on different calendar systems must agree on today's key.
    #expect(DayStamp.localGregorian.identifier == .gregorian)
    #expect(DayStamp.localGregorian.timeZone == .current)
}

// MARK: - Store

@MainActor
private func makeStores(_ ids: String...) throws -> [CounterStore] {
    let container = try ProgressStore.inMemoryContainer(includesCounters: true)
    return ids.map { CounterStore(container: container, deviceID: $0) }
}

@Test @MainActor func incrementReturnsTheNewTotal() throws {
    let store = try makeStores("phone")[0]
    #expect(try store.total("boosters.free") == 0)
    #expect(try store.increment("boosters.free") == 1)
    #expect(try store.increment("boosters.free", by: 2) == 3)
}

@Test @MainActor func usesFromEveryDeviceAreSummed() throws {
    // Two stores on one container stand in for rows another device synced in.
    let stores = try makeStores("phone", "pad")
    try stores[0].increment("boosters.free")
    try stores[1].increment("boosters.free")
    #expect(try stores[0].total("boosters.free") == 2)
    #expect(try stores[1].counter("boosters.free").tallies == ["phone": 1, "pad": 1])
}

@Test @MainActor func aReinstallDoesNotHandTheAllowanceBack() throws {
    let stores = try makeStores("first-install", "after-reinstall")
    try stores[0].increment("boosters.free", by: 2)
    // The reinstalled app has a new id and has used nothing itself, yet the total stays.
    #expect(try stores[1].total("boosters.free") == 2)
    #expect(try stores[1].increment("boosters.free") == 3)
}

@Test @MainActor func countersAreIndependentByKey() throws {
    let store = try makeStores("phone")[0]
    try store.increment("boosters.day.2026-10-12", by: 3)
    try store.increment("boosters.day.2026-10-13")
    #expect(try store.total("boosters.day.2026-10-12") == 3)
    #expect(try store.total("boosters.day.2026-10-13") == 1)
}

@Test @MainActor func aDuplicateOwnRowNeverMakesTheTallyGoBackwards() throws {
    let store = try makeStores("phone")[0]
    let context = store.container.mainContext
    context.insert(CounterRecord(key: "k", deviceID: "phone", count: 1, updatedAt: nil))
    context.insert(CounterRecord(key: "k", deviceID: "phone", count: 3, updatedAt: nil))
    try context.save()

    #expect(try store.total("k") == 3)
    #expect(try store.increment("k") == 4)
    let rows = try context.fetch(FetchDescriptor<CounterRecord>())
    #expect(rows.count == 1)
}

@Test @MainActor func zeroIncrementWritesNothing() throws {
    let store = try makeStores("phone")[0]
    #expect(try store.increment("k", by: 0) == 0)
    #expect(try store.container.mainContext.fetch(FetchDescriptor<CounterRecord>()).isEmpty)
}

@Test @MainActor func pruningRemovesOnlyMatchingKeys() throws {
    let store = try makeStores("phone")[0]
    try store.increment("boosters.day.2026-10-11")
    try store.increment("boosters.day.2026-10-12")
    try store.increment("boosters.free")
    try store.deleteCounters { $0.hasPrefix("boosters.day.") && $0 != "boosters.day.2026-10-12" }
    #expect(try store.total("boosters.day.2026-10-11") == 0)
    #expect(try store.total("boosters.day.2026-10-12") == 1)
    #expect(try store.total("boosters.free") == 1)
}

@Test @MainActor func installIDIsCreatedOnceAndKept() throws {
    let suite = "corekit.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = CounterStore.installID(defaults: defaults)
    #expect(!first.isEmpty)
    #expect(CounterStore.installID(defaults: defaults) == first)
}

// MARK: - Schema

@Test @MainActor func countersAreOptInSoShippedSchemasDoNotChange() throws {
    let plain = try ProgressStore.inMemoryContainer()
    let withCounters = try ProgressStore.inMemoryContainer(includesCounters: true)
    #expect(Set(plain.schema.entities.map(\.name)) == ["StageRecord"])
    #expect(Set(withCounters.schema.entities.map(\.name)) == ["StageRecord", "CounterRecord"])
}

@Test @MainActor func progressAndCountersShareOneContainer() throws {
    let container = try ProgressStore.inMemoryContainer(includesCounters: true)
    let progress = ProgressStore(container: container)
    let counters = CounterStore(container: container, deviceID: "phone")
    try progress.recordAttempt(stageId: "s1", cleared: true)
    try counters.increment("boosters.free")
    #expect(try progress.progress(forStage: "s1")?.isCleared == true)
    #expect(try counters.total("boosters.free") == 1)
}

@Test func aDevicesOwnTallyIsReadable() {
    var counter = UsageCounter()
    counter.increment(deviceID: "phone", by: 2)
    counter.increment(deviceID: "pad")
    #expect(counter.tally(for: "phone") == 2)
    #expect(counter.tally(for: "pad") == 1)
    #expect(counter.tally(for: "watch") == 0, "a device that never used it reads as zero")
}
