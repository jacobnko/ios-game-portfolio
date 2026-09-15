// Posts the planned notifications, and decides when it is fair to ask permission.

import Foundation

#if os(iOS)
import UserNotifications
#endif

/// Localized wording for one notification.
public struct NotificationCopy: Sendable, Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Supplies each game's own wording.
///
/// Only the words are per game. Cadence, permission timing and quiet hours are
/// shared, because getting those wrong costs an uninstall regardless of the copy.
public protocol NotificationCopyProviding: Sendable {
    /// How many variants exist for a theme, so the planner can rotate through them.
    func poolSize(for theme: NotificationTheme) -> Int
    func copy(for theme: NotificationTheme, index: Int) -> NotificationCopy
}

/// Schedules re-engagement notifications.
@MainActor
public final class NotificationScheduler {
    private enum Keys {
        static let enabled = "corekit.notifications.enabled"
        static let didAsk = "corekit.notifications.didAsk"
    }

    private let copyProvider: NotificationCopyProviding
    private let policy: NotificationPolicy
    private let defaults: UserDefaults

    public init(
        copyProvider: NotificationCopyProviding,
        policy: NotificationPolicy = .standard,
        defaults: UserDefaults = .standard
    ) {
        self.copyProvider = copyProvider
        self.policy = policy
        self.defaults = defaults
        if defaults.object(forKey: Keys.enabled) == nil {
            defaults.set(true, forKey: Keys.enabled)
        }
    }

    /// The player's own switch, independent of the system permission.
    public var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.enabled) }
        set {
            defaults.set(newValue, forKey: Keys.enabled)
            if !newValue { Task { await cancelAll() } }
        }
    }

    /// Whether permission has ever been requested.
    public private(set) var hasRequestedAuthorization: Bool {
        get { defaults.bool(forKey: Keys.didAsk) }
        set { defaults.set(newValue, forKey: Keys.didAsk) }
    }

    /// Asks for permission, but only once the player has something to come back to.
    ///
    /// Asking on first launch is the single biggest mistake here. A prompt with no
    /// context is refused most of the time, and **a refusal cannot be retried inside
    /// the app** — the only path back is the Settings app, which almost nobody walks.
    /// So the ask is spent after the player has cleared something and has a reason
    /// to want a reminder.
    @discardableResult
    public func requestAuthorizationAfterFirstClear() async -> Bool {
        guard !hasRequestedAuthorization else { return await isAuthorized() }
        hasRequestedAuthorization = true
        #if os(iOS)
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
        #else
        return false
        #endif
    }

    public func isAuthorized() async -> Bool {
        #if os(iOS)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        #else
        return false
        #endif
    }

    /// Rebuilds the whole schedule.
    ///
    /// Call on every launch and on every background transition. Rebuilding from
    /// scratch is what stops a returning player from being chased by a ladder that
    /// was planned before they came back.
    @discardableResult
    public func refresh(lastPlayed: Date = Date(), streakExpiresAt: Date? = nil, now: Date = Date()) async -> [PlannedNotification] {
        await cancelAll()
        guard isEnabled, await isAuthorized() else { return [] }

        var poolSizes: [NotificationTheme: Int] = [:]
        for theme in NotificationTheme.allCases {
            poolSizes[theme] = copyProvider.poolSize(for: theme)
        }

        let plan = NotificationPlanner.plan(
            lastPlayed: lastPlayed,
            now: now,
            policy: policy,
            copyPoolSizes: poolSizes,
            streakExpiresAt: streakExpiresAt
        )
        schedule(plan, now: now)
        return plan
    }

    /// Cancels only the notifications this scheduler owns.
    ///
    /// Never `removeAllPendingNotificationRequests()`: that is app-wide, and a
    /// shared component has no business deleting notifications a game scheduled
    /// for its own purposes.
    ///
    /// Async because the pending list has to be read first. Doing that on a
    /// completion handler and returning immediately would let the cancellation land
    /// *after* the following schedule and delete the notifications it just made.
    #if DEBUG
    /// Fires one notification shortly, so delivery can actually be observed.
    ///
    /// The real ladder starts a day out, which makes delivery impossible to verify
    /// inside a testing session — and "it was scheduled" is not the same claim as
    /// "it arrived, with the right words, and did not arrive during quiet hours".
    /// Debug builds only; it has no place in a shipping game.
    public func fireTestNotification(after seconds: TimeInterval = 10, theme: NotificationTheme = .progress) async -> Bool {
        #if os(iOS)
        guard await isAuthorized() else { return false }
        let copy = copyProvider.copy(for: theme, index: 0)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: NotificationPlanner.identifierPrefix + "debug",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
        return true
        #else
        return false
        #endif
    }
    #endif

    public func cancelAll() async {
        #if os(iOS)
        let center = UNUserNotificationCenter.current()
        let owned = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
        guard !owned.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: owned)
        #endif
    }

    private func schedule(_ plan: [PlannedNotification], now: Date) {
        #if os(iOS)
        let center = UNUserNotificationCenter.current()
        for item in plan {
            let copy = copyProvider.copy(for: item.theme, index: item.copyIndex)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default

            // An interval trigger rather than a calendar one: the plan already
            // resolved the exact moment, and a calendar trigger would re-interpret
            // the components if the device changes time zone before it fires.
            let interval = max(1, item.fireDate.timeIntervalSince(now))
            let request = UNNotificationRequest(
                identifier: item.id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            center.add(request)
        }
        #endif
    }
}
