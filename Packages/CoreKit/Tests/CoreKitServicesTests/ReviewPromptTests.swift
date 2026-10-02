// Pins every boundary of when a game may ask for an App Store rating.

import Testing
import Foundation
@testable import CoreKitServices

/// A fixed calendar, so "same day" does not depend on the machine running the tests.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private let day1 = Date(timeIntervalSince1970: 1_790_000_000) // a fixed instant
private let hour: TimeInterval = 60 * 60
private let dayLength: TimeInterval = 24 * hour

/// Ten clears spread over two days — the shortest history the standard policy accepts.
private func qualifiedActivity() -> ReviewActivity {
    var activity = ReviewActivity()
    for _ in 0..<5 { activity.recordClear(now: day1, calendar: utc) }
    for _ in 0..<5 { activity.recordClear(now: day1 + dayLength, calendar: utc) }
    return activity
}

private let policy = ReviewPolicy.standard

// MARK: - The happy path

@Test func aPlayerWithEnoughClearsOverTwoDaysMayBeAsked() {
    let verdict = policy.verdict(for: qualifiedActivity(), appVersion: "1.2.0", now: day1 + dayLength, lastAdShownAt: nil)
    #expect(verdict == .allowed)
}

// MARK: - Not enough history

@Test func aNewPlayerIsNeverAsked() {
    #expect(policy.verdict(for: ReviewActivity(), appVersion: "1.2.0", now: day1, lastAdShownAt: nil) == .notEnoughClears)
}

@Test func nineClearsIsOneTooFew() {
    var activity = ReviewActivity()
    for _ in 0..<5 { activity.recordClear(now: day1, calendar: utc) }
    for _ in 0..<4 { activity.recordClear(now: day1 + dayLength, calendar: utc) }
    #expect(policy.verdict(for: activity, appVersion: "1.2.0", now: day1 + dayLength, lastAdShownAt: nil) == .notEnoughClears)
}

@Test func manyClearsInOneSittingIsNotEnough() {
    // A binge on day one is one sitting, not a habit — the player has not come back yet.
    var activity = ReviewActivity()
    for _ in 0..<50 { activity.recordClear(now: day1, calendar: utc) }
    #expect(activity.distinctPlayDays == 1)
    #expect(policy.verdict(for: activity, appVersion: "1.2.0", now: day1, lastAdShownAt: nil) == .notEnoughDays)
}

// MARK: - Not asking twice

@Test func theSameVersionIsNeverAskedTwice() {
    var activity = qualifiedActivity()
    activity.recordRequested(appVersion: "1.2.0", now: day1 + dayLength)
    let muchLater = day1 + 400 * dayLength
    #expect(policy.verdict(for: activity, appVersion: "1.2.0", now: muchLater, lastAdShownAt: nil) == .alreadyAskedThisVersion)
}

@Test func aNewVersionStillWaitsOutTheInterval() {
    var activity = qualifiedActivity()
    activity.recordRequested(appVersion: "1.2.0", now: day1)
    let justShort = day1 + policy.minimumIntervalBetweenRequests - 1
    #expect(policy.verdict(for: activity, appVersion: "1.3.0", now: justShort, lastAdShownAt: nil) == .tooSoonSinceLastRequest)
}

@Test func aNewVersionPastTheIntervalMayBeAsked() {
    var activity = qualifiedActivity()
    activity.recordRequested(appVersion: "1.2.0", now: day1)
    let exactly = day1 + policy.minimumIntervalBetweenRequests
    #expect(policy.verdict(for: activity, appVersion: "1.3.0", now: exactly, lastAdShownAt: nil) == .allowed)
}

@Test func theOwnLimitStaysWithinTheSystemsThreePerYear() {
    // Apple shows the prompt at most three times in 365 days. Asking more often than
    // that wastes requests the system will silently drop.
    let maxPerYear = Int((365 * dayLength) / policy.minimumIntervalBetweenRequests) + 1
    #expect(maxPerYear <= 3)
}

// MARK: - Clock and ads

@Test func aClockTurnedBackRefusesRatherThanGuesses() {
    var activity = qualifiedActivity()
    activity.recordRequested(appVersion: "1.2.0", now: day1 + 200 * dayLength)
    #expect(policy.verdict(for: activity, appVersion: "1.3.0", now: day1 + 100 * dayLength, lastAdShownAt: nil) == .clockMovedBackwards)
}

@Test func aClockTurnedBackCannotManufactureASecondDay() {
    var activity = ReviewActivity()
    activity.recordClear(now: day1 + dayLength, calendar: utc)
    activity.recordClear(now: day1, calendar: utc) // the day before
    #expect(activity.distinctPlayDays == 1)
}

@Test func anAdMomentsAgoBlocksTheRequest() {
    let now = day1 + dayLength
    let verdict = policy.verdict(for: qualifiedActivity(), appVersion: "1.2.0", now: now, lastAdShownAt: now - 30)
    #expect(verdict == .tooSoonAfterAd)
}

@Test func anAdOutsideTheQuietPeriodDoesNot() {
    let now = day1 + dayLength
    let verdict = policy.verdict(for: qualifiedActivity(), appVersion: "1.2.0", now: now, lastAdShownAt: now - policy.quietPeriodAfterAd)
    #expect(verdict == .allowed)
}

@Test func theLatestOfEitherAdKindCounts() {
    var ads = AdActivity()
    #expect(ads.lastAdShownAt == nil)
    ads.recordInterstitial(at: 100)
    #expect(ads.lastAdShownAt == 100)
    ads.recordRewarded(at: 250)
    #expect(ads.lastAdShownAt == 250)
    ads.recordInterstitial(at: 200)
    #expect(ads.lastAdShownAt == 250)
}

// MARK: - Players who installed before this existed

@Test func priorClearsAreCreditedOnceAndStillRequireAnotherDay() {
    var activity = ReviewActivity()
    activity.seed(priorClears: 120, now: day1, calendar: utc)
    #expect(activity.clearCount == 120)
    #expect(activity.distinctPlayDays == 1)
    #expect(policy.verdict(for: activity, appVersion: "1.2.0", now: day1, lastAdShownAt: nil) == .notEnoughDays)

    activity.recordClear(now: day1 + dayLength, calendar: utc)
    #expect(policy.verdict(for: activity, appVersion: "1.2.0", now: day1 + dayLength, lastAdShownAt: nil) == .allowed)
}

@Test func seedingHappensOnlyOnce() {
    var activity = ReviewActivity()
    activity.seed(priorClears: 0, now: day1, calendar: utc)
    activity.seed(priorClears: 500, now: day1, calendar: utc)
    #expect(activity.clearCount == 0)
    #expect(activity.isSeeded)
}

// MARK: - Persistence

@MainActor
@Test func historySurvivesARelaunch() throws {
    let suite = "review-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = ReviewPrompter(defaults: defaults, calendar: utc)
    first.recordClear(now: day1)
    first.recordRequested(appVersion: "1.2.0", now: day1)

    let relaunched = ReviewPrompter(defaults: defaults, calendar: utc)
    #expect(relaunched.activity.clearCount == 1)
    #expect(relaunched.activity.lastRequestedVersion == "1.2.0")
    #expect(relaunched.verdict(appVersion: "1.2.0", now: day1 + 999 * dayLength, lastAdShownAt: nil) == .alreadyAskedThisVersion)
}

@MainActor
@Test func seedingIsSkippedOnceAlreadyDoneEvenAcrossLaunches() throws {
    let suite = "review-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    ReviewPrompter(defaults: defaults, calendar: utc).seedIfNeeded(priorClears: 7, now: day1)
    let relaunched = ReviewPrompter(defaults: defaults, calendar: utc)
    relaunched.seedIfNeeded(priorClears: 300, now: day1)
    #expect(relaunched.activity.clearCount == 7)
}
