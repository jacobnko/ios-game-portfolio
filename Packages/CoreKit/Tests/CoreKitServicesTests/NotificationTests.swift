// Verifies the notification cadence — the part that decides whether a player stays.

import Testing
import Foundation
@testable import CoreKitServices

private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

// MARK: - Cadence

@Test func theLadderIsSparseNotDaily() {
    // The whole design rests on this: five touches over a month, never daily.
    // A daily reminder trains players to dismiss, then to delete.
    let policy = NotificationPolicy.standard
    #expect(policy.ladderDays == [1, 3, 7, 14, 30])
    #expect(policy.ladderDays.count == 5)
}

@Test func planProducesOneNotificationPerRung() {
    let plan = NotificationPlanner.plan(
        lastPlayed: date(2026, 9, 15, 20),
        now: date(2026, 9, 15, 20),
        calendar: calendar
    )
    #expect(plan.count == 5)
    #expect(Set(plan.map(\.id)).count == 5)   // ids unique, so none overwrites another
}

@Test func planStaysFarBelowTheSystemLimit() {
    // iOS silently drops pending local notifications past 64 per app.
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15), calendar: calendar)
    #expect(plan.count < 64)
    #expect(plan.count <= NotificationPolicy.standard.maxPending)
}

@Test func maxPendingIsEnforcedEvenWithALongLadder() {
    let policy = NotificationPolicy(ladderDays: Array(1...50), maxPending: 6)
    let plan = NotificationPlanner.plan(
        lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15), policy: policy, calendar: calendar
    )
    #expect(plan.count == 6)
}

@Test func notificationsAreOrderedInTime() {
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15), calendar: calendar)
    let dates = plan.map(\.fireDate)
    #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 })
}

// MARK: - Quiet hours

@Test func everyNotificationLandsInTheEvening() {
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15, 3), now: date(2026, 9, 15, 3), calendar: calendar)
    for item in plan {
        #expect(calendar.component(.hour, from: item.fireDate) == NotificationPolicy.standard.preferredHour)
    }
}

@Test func nothingEverFiresInsideQuietHours() {
    // Firing at 3am is an uninstall, not a re-engagement.
    let policy = NotificationPolicy.standard
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15, 2), now: date(2026, 9, 15, 2), policy: policy, calendar: calendar)
    for item in plan {
        #expect(policy.isQuiet(hour: calendar.component(.hour, from: item.fireDate)) == false)
    }
}

@Test func quietWindowWrapsAroundMidnight() {
    let policy = NotificationPolicy(quietStartHour: 21, quietEndHour: 9)
    #expect(policy.isQuiet(hour: 23))
    #expect(policy.isQuiet(hour: 3))
    #expect(policy.isQuiet(hour: 8))
    #expect(policy.isQuiet(hour: 9) == false)
    #expect(policy.isQuiet(hour: 19) == false)
}

@Test func nothingIsScheduledInThePast() {
    // A past trigger fires the instant it is registered, which reads as a bug
    // and burns the player's tolerance immediately.
    let now = date(2026, 9, 20, 22)
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15), now: now, calendar: calendar)
    #expect(plan.allSatisfy { $0.fireDate > now })
}

@Test func aReturningPlayerRestartsTheLadder() {
    // Re-planning from a later "last played" must push everything out, so someone
    // who came back yesterday is not hit by a plan made two weeks ago.
    let now = date(2026, 9, 20, 10)
    let stale = NotificationPlanner.plan(lastPlayed: date(2026, 9, 1), now: now, calendar: calendar)
    let fresh = NotificationPlanner.plan(lastPlayed: date(2026, 9, 20), now: now, calendar: calendar)
    #expect(fresh.first!.fireDate > stale.first!.fireDate)
}

// MARK: - Themes and copy

@Test func promotionalThemesDoNotExist() {
    // Guideline 4.5.4 rejects notifications used for advertising.
    #expect(NotificationTheme.allCases.count == 3)
    #expect(NotificationTheme.allCases.contains(.progress))
    #expect(NotificationTheme.allCases.contains(.curiosity))
    #expect(NotificationTheme.allCases.contains(.lossAversion))
}

@Test func ladderAlternatesThemes() {
    // One repeated message reads as a nag; alternating keeps the tone varied.
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15), calendar: calendar)
    let themes = plan.map(\.theme)
    #expect(Set(themes).count > 1)
}

@Test func copyRotatesWithinATheme() {
    let plan = NotificationPlanner.plan(
        lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15),
        copyPoolSizes: [.progress: 3, .curiosity: 3], calendar: calendar
    )
    let progressIndices = plan.filter { $0.theme == .progress }.map(\.copyIndex)
    #expect(Set(progressIndices).count > 1)
}

@Test func aSingleCopyVariantStillWorks() {
    // A game that only wrote one line per theme must not index out of its pool.
    let plan = NotificationPlanner.plan(
        lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15),
        copyPoolSizes: [.progress: 1, .curiosity: 1], calendar: calendar
    )
    #expect(plan.allSatisfy { $0.copyIndex == 0 })
}

// MARK: - Streaks

@Test func anExpiringStreakIsWarnedAboutFirst() {
    let now = date(2026, 9, 15, 10)
    let expiry = date(2026, 9, 15, 20)
    let plan = NotificationPlanner.plan(
        lastPlayed: now, now: now, streakExpiresAt: expiry, calendar: calendar
    )
    #expect(plan.first?.theme == .lossAversion)
    #expect(plan.first?.fireDate == expiry.addingTimeInterval(-NotificationPolicy.standard.streakWarningLead))
}

@Test func anAlreadyLapsedStreakIsNotWarnedAbout() {
    let now = date(2026, 9, 15, 22)
    let plan = NotificationPlanner.plan(
        lastPlayed: now, now: now, streakExpiresAt: date(2026, 9, 15, 23), calendar: calendar
    )
    #expect(plan.contains { $0.theme == .lossAversion } == false)
}

@Test func aStreakWarningInQuietHoursIsDropped() {
    // Better to lose the streak silently than to wake someone at 4am about it.
    let now = date(2026, 9, 15, 1)
    let plan = NotificationPlanner.plan(
        lastPlayed: now, now: now, streakExpiresAt: date(2026, 9, 15, 7), calendar: calendar
    )
    #expect(plan.contains { $0.theme == .lossAversion } == false)
}

@Test func gamesWithoutStreaksGetNoLossAversion() {
    let plan = NotificationPlanner.plan(lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15), calendar: calendar)
    #expect(plan.contains { $0.theme == .lossAversion } == false)
}

// MARK: - Configuration

@Test func policyRejectsNonsenseConfiguration() {
    let policy = NotificationPolicy(ladderDays: [0, -3, 7, 1], preferredHour: 99, maxPending: 0)
    #expect(policy.ladderDays == [1, 7])   // non-positive dropped, sorted
    #expect(policy.preferredHour == 23)
    #expect(policy.maxPending == 1)
}

@Test func maxPendingCannotExceedWhatTheSystemAccepts() {
    #expect(NotificationPolicy(maxPending: 500).maxPending <= 60)
}

// MARK: - Regression: cancellation must be scoped

@Test func everyPlannedIdentifierCarriesTheOwnershipPrefix() {
    // Cancellation removes pending requests by identifier prefix. A plan item
    // without the prefix would survive a cancel and fire after the player returned;
    // an app-wide removeAll would instead delete notifications the game itself owns.
    let plan = NotificationPlanner.plan(
        lastPlayed: date(2026, 9, 15), now: date(2026, 9, 15),
        streakExpiresAt: date(2026, 9, 15, 20), calendar: calendar
    )
    #expect(plan.isEmpty == false)
    for item in plan {
        #expect(item.id.hasPrefix(NotificationPlanner.identifierPrefix), "\(item.id) is not namespaced")
    }
}
