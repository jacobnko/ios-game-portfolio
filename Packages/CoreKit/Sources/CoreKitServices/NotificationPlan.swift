// Decides when re-engagement notifications fire. Pure, so the cadence can be proven.

import Foundation

/// What a notification is about.
///
/// Promotional themes are deliberately absent. Guideline 4.5.4 rejects notifications
/// used for advertising, and beyond the rule they are the fastest way to get deleted.
public enum NotificationTheme: String, Sendable, CaseIterable {
    /// Where the player stopped. "Stage 12 is waiting."
    case progress
    /// Something they built is about to lapse. Only for games that have streaks.
    case lossAversion
    /// Something new to look at. "Today's puzzle is ready."
    case curiosity
}

/// One notification the app intends to post.
public struct PlannedNotification: Sendable, Equatable, Identifiable {
    public let id: String
    public let fireDate: Date
    public let theme: NotificationTheme
    /// Index into the game's localized copy pool, so wording varies between sends.
    public let copyIndex: Int

    public init(id: String, fireDate: Date, theme: NotificationTheme, copyIndex: Int) {
        self.id = id
        self.fireDate = fireDate
        self.theme = theme
        self.copyIndex = copyIndex
    }
}

/// Cadence rules shared by every game.
public struct NotificationPolicy: Sendable, Equatable {
    /// Days after the last play session at which to reach out.
    ///
    /// This is a decaying ladder, not a daily reminder. Five touches spread over a
    /// month is the whole budget. Daily notifications train players to swipe them
    /// away, and then to delete the app — which costs more than every impression
    /// those notifications would ever have earned back.
    public var ladderDays: [Int]
    /// Local hour notifications aim for. Early evening beats morning for casual games.
    public var preferredHour: Int
    /// No notification may fire at or after this hour.
    public var quietStartHour: Int
    /// No notification may fire before this hour.
    public var quietEndHour: Int
    /// Defensive cap. iOS silently drops pending local notifications past 64 per app.
    public var maxPending: Int
    /// How long before a streak lapses to warn about it.
    public var streakWarningLead: TimeInterval

    public init(
        ladderDays: [Int] = [1, 3, 7, 14, 30],
        preferredHour: Int = 19,
        quietStartHour: Int = 21,
        quietEndHour: Int = 9,
        maxPending: Int = 16,
        streakWarningLead: TimeInterval = 3 * 3600
    ) {
        self.ladderDays = ladderDays.filter { $0 > 0 }.sorted()
        self.preferredHour = min(23, max(0, preferredHour))
        self.quietStartHour = min(23, max(0, quietStartHour))
        self.quietEndHour = min(23, max(0, quietEndHour))
        self.maxPending = min(60, max(1, maxPending))
        self.streakWarningLead = max(0, streakWarningLead)
    }

    public static let standard = NotificationPolicy()

    /// Whether an hour falls inside the do-not-disturb window.
    public func isQuiet(hour: Int) -> Bool {
        // The window wraps past midnight, so the two halves are checked separately.
        quietStartHour > quietEndHour
            ? (hour >= quietStartHour || hour < quietEndHour)
            : (hour >= quietStartHour && hour < quietEndHour)
    }
}

/// Builds the notification schedule.
///
/// Recomputed from scratch every time the app opens, which is also what keeps a
/// player who came back from being nagged: opening the app cancels the whole ladder
/// and starts a new one from today.
public enum NotificationPlanner {
    /// Prefix on every identifier this planner owns.
    ///
    /// Cancelling is scoped to these. `removeAllPendingNotificationRequests()` is
    /// app-wide, so a shared library using it would silently delete notifications a
    /// game scheduled for its own reasons.
    public static let identifierPrefix = "corekit.reengagement."

    /// Themes assigned to each rung of the ladder, cycling.
    ///
    /// Alternating keeps the tone from becoming one repeated nag.
    static let ladderThemes: [NotificationTheme] = [.progress, .curiosity]

    public static func plan(
        lastPlayed: Date,
        now: Date,
        policy: NotificationPolicy = .standard,
        copyPoolSizes: [NotificationTheme: Int] = [:],
        streakExpiresAt: Date? = nil,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []

        // A streak about to lapse is the one genuinely time-critical message, so it
        // is scheduled first and is allowed to sit outside the ladder.
        if let expiry = streakExpiresAt {
            let warnAt = expiry.addingTimeInterval(-policy.streakWarningLead)
            if warnAt > now, !policy.isQuiet(hour: calendar.component(.hour, from: warnAt)) {
                planned.append(PlannedNotification(
                    id: identifierPrefix + "streak",
                    fireDate: warnAt,
                    theme: .lossAversion,
                    copyIndex: 0
                ))
            }
        }

        for (rung, days) in policy.ladderDays.enumerated() {
            guard let candidate = calendar.date(byAdding: .day, value: days, to: lastPlayed),
                  let fireDate = snapToPreferredHour(candidate, after: now, policy: policy, calendar: calendar)
            else { continue }

            let theme = ladderThemes[rung % ladderThemes.count]
            let poolSize = max(1, copyPoolSizes[theme] ?? 1)
            planned.append(PlannedNotification(
                id: identifierPrefix + "ladder_\(days)",
                fireDate: fireDate,
                theme: theme,
                // Walks the pool so two consecutive sends of the same theme differ.
                copyIndex: (rung / ladderThemes.count) % poolSize
            ))
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(policy.maxPending))
    }

    /// Moves a date to the preferred local hour, pushing to the next day if that
    /// moment has already passed.
    ///
    /// Returns nil only if the calendar cannot produce the date at all.
    static func snapToPreferredHour(
        _ date: Date,
        after now: Date,
        policy: NotificationPolicy,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = policy.preferredHour
        components.minute = 0
        components.second = 0
        guard var snapped = calendar.date(from: components) else { return nil }

        // Anything in the past would fire immediately, which reads as a bug.
        while snapped <= now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: snapped) else { return nil }
            snapped = next
        }
        return snapped
    }
}
