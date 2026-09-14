// Translates CoreKit's analytics protocols onto Firebase.

import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import CoreKitServices

/// Sends events to Firebase Analytics.
///
/// Holds no policy. Event naming and sanitization already happened in
/// `AnalyticsEvent`, so this only converts types and forwards.
public final class FirebaseAnalyticsReporter: AnalyticsReporting, @unchecked Sendable {
    public init() {}

    public func log(_ event: AnalyticsEvent) {
        FirebaseAnalytics.Analytics.logEvent(event.name, parameters: event.parameters.firebaseParameters)
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        FirebaseAnalytics.Analytics.setUserProperty(value, forName: name)
    }
}

/// Sends non-fatal errors and breadcrumbs to Crashlytics.
public final class FirebaseCrashReporter: CrashReporting, @unchecked Sendable {
    public init() {}

    public func record(_ error: Error, context: [String: String]) {
        // userInfo is what makes a non-fatal actionable. Without it the dashboard
        // shows a stack trace and no way to tell which stage or product it was.
        let enriched = NSError(
            domain: (error as NSError).domain,
            code: (error as NSError).code,
            userInfo: (error as NSError).userInfo.merging(context) { _, new in new }
        )
        Crashlytics.crashlytics().record(error: enriched)
    }

    public func leaveBreadcrumb(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    public func setKey(_ value: String, forName name: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: name)
    }
}

/// One-time Firebase setup.
public enum FirebaseSetup {
    /// Configures Firebase and wires both reporters into the hub.
    ///
    /// Call once at launch, before any event is logged. Requires
    /// `GoogleService-Info.plist` in the app bundle — without it `configure()` traps.
    @MainActor
    public static func start(hub: AnalyticsHub = .shared) {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        hub.register(FirebaseAnalyticsReporter())
        hub.register(crashReporter: FirebaseCrashReporter())
    }
}

private extension Dictionary where Key == String, Value == AnalyticsValue {
    var firebaseParameters: [String: Any] {
        reduce(into: [:]) { result, pair in
            switch pair.value {
            case .string(let value): result[pair.key] = value
            case .int(let value): result[pair.key] = value
            case .double(let value): result[pair.key] = value
            // Firebase has no boolean parameter type; it stores them as 0/1 ints
            // anyway, so converting here keeps the dashboards readable.
            case .bool(let value): result[pair.key] = value ? 1 : 0
            }
        }
    }
}
