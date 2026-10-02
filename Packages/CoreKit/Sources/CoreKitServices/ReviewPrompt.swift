// Decides when a game may ask the player for an App Store rating.

import Foundation

/// Why a review request is or is not allowed right now.
///
/// A reason rather than a `Bool`, for the same reason `InterstitialVerdict` is one:
/// "it didn't ask" has six different causes, and a test or a debug readout that
/// can only see `false` cannot tell them apart.
public enum ReviewVerdict: Sendable, Equatable {
    case allowed
    /// This app version already asked once. Apple's own sample enforces exactly
    /// this, so a player is never asked twice about the same build.
    case alreadyAskedThisVersion
    /// The device clock is behind the last recorded request. Treated as "no":
    /// the safe direction for a prompt is not to show it.
    case clockMovedBackwards
    /// Too little time since the last request, across versions.
    case tooSoonSinceLastRequest
    /// Not enough clears yet to have an informed opinion.
    case notEnoughClears
    /// Every clear so far happened on one day — a single sitting, not a habit.
    case notEnoughDays
    /// An ad was on screen moments ago. Asking someone to rate the app right after
    /// they sat through an ad is the quickest route to a low score.
    case tooSoonAfterAd

    public var isAllowed: Bool { self == .allowed }
}

/// The rules for asking. Pure — every input that changes over time is a parameter.
///
/// Pure because the alternative already failed once in this codebase: the
/// production-ad gate read its condition from the environment, could not be
/// tested, and sat permanently false in the only build where it mattered. A rule
/// that takes `now` and the app version as arguments can be pinned by tests at
/// every boundary instead.
///
/// The system shows the prompt at most three times in 365 days and may show it
/// zero times even when asked. These rules are deliberately stricter than that cap,
/// so the requests that do get through land on players who have actually played.
public struct ReviewPolicy: Sendable, Equatable {
    /// Lifetime clears before the first ask. A round here is 10–30 seconds, so a
    /// single-digit number would be minutes of play, not an opinion.
    public var minimumClears: Int
    /// Distinct calendar days with a clear. Two means the player came back.
    public var minimumDistinctDays: Int
    /// Minimum gap between requests, even across new versions.
    ///
    /// Must exceed a third of a year, not merely equal it: at 120 days, requests on
    /// days 0, 120, 240 and 360 all fall inside one 365-day window, and the
    /// system's three-per-year cap silently drops the fourth. 125 days allows at
    /// most three in any window.
    public var minimumIntervalBetweenRequests: TimeInterval
    /// How long after the last ad finished before asking is acceptable.
    public var quietPeriodAfterAd: TimeInterval
    /// How long the result screen must stay up before the request is made.
    ///
    /// Apple's sample waits two seconds on its "completed" scene. It doubles as
    /// the guard against asking as a reaction to a tap: a player who taps Next
    /// within the delay has left the screen, and the request is dropped.
    public var presentationDelay: TimeInterval

    public init(
        minimumClears: Int = 10,
        minimumDistinctDays: Int = 2,
        minimumIntervalBetweenRequests: TimeInterval = 125 * 24 * 60 * 60,
        quietPeriodAfterAd: TimeInterval = 60,
        presentationDelay: TimeInterval = 2
    ) {
        self.minimumClears = max(0, minimumClears)
        self.minimumDistinctDays = max(0, minimumDistinctDays)
        self.minimumIntervalBetweenRequests = max(0, minimumIntervalBetweenRequests)
        self.quietPeriodAfterAd = max(0, quietPeriodAfterAd)
        self.presentationDelay = max(0, presentationDelay)
    }

    public static let standard = ReviewPolicy()

    public func verdict(
        for activity: ReviewActivity,
        appVersion: String,
        now: Date,
        lastAdShownAt: Date?
    ) -> ReviewVerdict {
        if activity.lastRequestedVersion == appVersion {
            return .alreadyAskedThisVersion
        }
        if let last = activity.lastRequestedAt {
            if now < last { return .clockMovedBackwards }
            if now.timeIntervalSince(last) < minimumIntervalBetweenRequests { return .tooSoonSinceLastRequest }
        }
        if activity.clearCount < minimumClears {
            return .notEnoughClears
        }
        if activity.distinctPlayDays < minimumDistinctDays {
            return .notEnoughDays
        }
        if let adShownAt = lastAdShownAt, now.timeIntervalSince(adShownAt) < quietPeriodAfterAd {
            return .tooSoonAfterAd
        }
        return .allowed
    }
}

/// What has happened on this device that bears on asking for a review.
///
/// Device-local on purpose, never synced. The system's own limits are per device,
/// so a count carried over from another device would argue for a prompt that
/// device's StoreKit is about to refuse anyway.
public struct ReviewActivity: Codable, Sendable, Equatable {
    public private(set) var clearCount: Int
    public private(set) var distinctPlayDays: Int
    /// Start of the most recent day that had a clear, in the calendar it was
    /// recorded with. Only ever moves forward.
    public private(set) var lastPlayDay: Date?
    public private(set) var lastRequestedVersion: String?
    public private(set) var lastRequestedAt: Date?
    /// Whether earlier history has been folded in — see `seed(priorClears:now:calendar:)`.
    public private(set) var isSeeded: Bool

    public init() {
        clearCount = 0
        distinctPlayDays = 0
        lastPlayDay = nil
        lastRequestedVersion = nil
        lastRequestedAt = nil
        isSeeded = false
    }

    public mutating func recordClear(now: Date, calendar: Calendar = .current) {
        clearCount += 1
        countDay(of: now, calendar: calendar)
    }

    public mutating func recordRequested(appVersion: String, now: Date) {
        lastRequestedVersion = appVersion
        lastRequestedAt = now
    }

    /// Credits clears made before this activity existed, once.
    ///
    /// Without it, every player who installed a version that did not track this
    /// would restart at zero, and the most experienced players — exactly the ones
    /// worth asking — would be the last to qualify. Prior clears count today as a
    /// play day, so one more day of play is still required.
    public mutating func seed(priorClears: Int, now: Date, calendar: Calendar = .current) {
        guard !isSeeded else { return }
        isSeeded = true
        guard priorClears > 0 else { return }
        clearCount = max(clearCount, priorClears)
        countDay(of: now, calendar: calendar)
    }

    /// A day counts only if it is later than the last one counted, so turning the
    /// clock back cannot manufacture a second day.
    private mutating func countDay(of date: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: date)
        guard let last = lastPlayDay else {
            lastPlayDay = day
            distinctPlayDays = max(distinctPlayDays, 1)
            return
        }
        if day > last {
            lastPlayDay = day
            distinctPlayDays += 1
        }
    }
}

/// Keeps `ReviewActivity` on disk and answers "may we ask now?".
///
/// The decision is `ReviewPolicy`'s; this only stores the history it needs. Games
/// call it at three points: `recordClear` on every clear, `verdict` when a result
/// screen has been up for `policy.presentationDelay`, and `recordRequested`
/// immediately before calling SwiftUI's `requestReview`.
@MainActor
public final class ReviewPrompter {
    private static let storageKey = "corekit.review.activity"

    public let policy: ReviewPolicy
    private let defaults: UserDefaults
    private let calendar: Calendar
    public private(set) var activity: ReviewActivity

    public init(policy: ReviewPolicy = .standard, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.policy = policy
        self.defaults = defaults
        self.calendar = calendar
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(ReviewActivity.self, from: data) {
            activity = stored
        } else {
            activity = ReviewActivity()
        }
    }

    public func seedIfNeeded(priorClears: Int, now: Date = Date()) {
        guard !activity.isSeeded else { return }
        activity.seed(priorClears: priorClears, now: now, calendar: calendar)
        save()
    }

    public func recordClear(now: Date = Date()) {
        activity.recordClear(now: now, calendar: calendar)
        save()
    }

    public func verdict(appVersion: String, now: Date = Date(), lastAdShownAt: Date?) -> ReviewVerdict {
        policy.verdict(for: activity, appVersion: appVersion, now: now, lastAdShownAt: lastAdShownAt)
    }

    /// Record *before* calling `requestReview`. The system may decline to show
    /// anything and never says so, so "we asked" is the only fact there is.
    public func recordRequested(appVersion: String, now: Date = Date()) {
        activity.recordRequested(appVersion: appVersion, now: now)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(activity) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
